# Web 仪表盘服务（只读伴生前端的数据后端）。
# 设计约束：对既有代码零侵入——只读取以下已有全局，不修改任何采集/界面逻辑：
#   SYNCSTATES / PROGRESSLIST / DATABUF / INSTRBUFFERVIEWERS / WORKPATH / SAVEPATH / RUNNINGTASK / OLDI / CONF
# 生命周期模仿 QICServer：startwebdashboard! / stopwebdashboard!，服务在独立任务里运行。
# 端点：
#   GET  /                静态页面（Assets/web/）
#   GET  /api/status      任务状态快照
#   GET  /api/files       工作区目录浏览（限定 WORKPATH 之内）
#   GET  /api/file/data   选择性读取 .qdt（data/daqtask/valid），服务端解析为数值列
#   WS   /ws              1 Hz 推送：status / progress / channels / streams / deltas

using HTTP
using Sockets
using SHA
using Base64
import JSON

const WD_SERVER = Ref{Any}(nothing)      # REST + 静态资源（Request 模式）
const WD_WSSERVER = Ref{Any}(nothing)    # WebSocket（独立端口，手工实现握手与帧协议）
const WD_PORT = Ref{Int}(8088)
const WD_BIND = Ref{String}("127.0.0.1")
const WD_STARTEDAT = Ref{Float64}(0.0)
const WD_WASRUNNING = Ref{Bool}(false)
const WD_COUNTS = Dict{String,Int}()   # 各数据 key 已通过 WS 推送的点数

webdashboardurl() = WD_SERVER[] === nothing ? "" : "http://$(WD_BIND[]):$(WD_PORT[])"
wd_wsport() = WD_PORT[] + 1

"""
    startwebdashboard!(; port=CONF.WebDashboard.port, bind="127.0.0.1")

启动 Web 仪表盘服务（幂等）。HTTP 在 `port`，WebSocket 在 `port+1`。返回服务地址，失败返回 ""。
"""
function startwebdashboard!(; port=Cint(CONF.WebDashboard.port), bind="127.0.0.1")
    WD_SERVER[] !== nothing && return webdashboardurl()
    WD_PORT[] = Int(port)
    WD_BIND[] = String(bind)
    local server, wsserver
    try
        server = HTTP.serve!(handle_web, bind, Int(port))
    catch e
        @error "[$(now())]\n$(mlstr("web dashboard failed to start"))" exception = e
        return ""
    end
    try
        wsserver = wd_ws_listen!(bind, wd_wsport())
    catch e
        close(server)
        @error "[$(now())]\n$(mlstr("web dashboard failed to start"))" exception = e
        return ""
    end
    WD_SERVER[] = server
    WD_WSSERVER[] = wsserver
    @spawn_record "webdashboard" begin
        try
            wait(server)
        catch e
            WD_SERVER[] === nothing || @error "[$(now())]\nweb dashboard server error" exception = e
        finally
            WD_SERVER[] = nothing
            empty!(WD_COUNTS)
        end
    end
    @info "[$(now())]\n$(mlstr("web dashboard started"))" url = webdashboardurl()
    webdashboardurl()
end

stopwebdashboard!() = begin
    WD_SERVER[] !== nothing && close(WD_SERVER[])
    WD_WSSERVER[] !== nothing && close(WD_WSSERVER[])
    WD_SERVER[] = nothing
    WD_WSSERVER[] = nothing
    nothing
end

###### JSON 编码（极简，避免新增 JSON 依赖） ######
function wd_jstr(io::IOBuffer, s::AbstractString)
    write(io, '"')
    for c in s
        if c == '"'
            write(io, "\\\"")
        elseif c == '\\'
            write(io, "\\\\")
        elseif c == '\n'
            write(io, "\\n")
        elseif c == '\r'
            write(io, "\\r")
        elseif c == '\t'
            write(io, "\\t")
        elseif c < ' '
            write(io, "\\u", lpad(string(UInt16(c); base = 16), 4, '0'))
        else
            write(io, c)
        end
    end
    write(io, '"')
end
wd_json(io::IOBuffer, x::Union{Bool,Int,Integer}) = print(io, x)
function wd_json(io::IOBuffer, x::AbstractFloat)
    isnan(x) || isinf(x) ? print(io, "null") : print(io, x)
end
function wd_json(io::IOBuffer, a::Vector{Float64})
    write(io, '[')
    for (i, x) in enumerate(a)
        i > 1 && write(io, ',')
        if isnan(x) || isinf(x)
            print(io, "null")
        else
            print(io, x)
        end
    end
    write(io, ']')
end
function wd_json(io::IOBuffer, s::AbstractString)
    wd_jstr(io, s)
end
function wd_json(io::IOBuffer, v::Vector)
    write(io, '[')
    for (i, x) in enumerate(v)
        i > 1 && write(io, ',')
        wd_json(io, x)
    end
    write(io, ']')
end
function wd_json(io::IOBuffer, d::AbstractDict)
    write(io, '{')
    first = true
    for (k, v) in d
        first || write(io, ',')
        first = false
        wd_jstr(io, string(k))
        write(io, ':')
        wd_json(io, v)
    end
    write(io, '}')
end
function wd_json(io::IOBuffer, nt::NamedTuple)
    wd_json(io, Dict(pairs(nt)))
end
wd_json(io::IOBuffer, ::Nothing) = print(io, "null")
wd_json(io::IOBuffer, ::Missing) = print(io, "null")
wd_json(x) = sprint(io -> wd_json(io, x))

###### 工具 ######
wd_parse(s::AbstractString) = (x = tryparse(Float64, s); x === nothing ? NaN : x)

function wd_webdir()
    candidates = (
        joinpath(get(ENV, "QInsControlAssets", ""), "web"),
        joinpath(@__DIR__, "..", "..", "Assets", "web")
    )
    for c in candidates
        isdir(c) && return c
    end
    return ""
end

function wd_workspace()
    p = WORKPATH
    return isdir(p) ? p : ""
end

# 限制在 WORKPATH 内（防目录穿越），返回绝对路径或 nothing
function wd_safejoin(rel::AbstractString)
    root = wd_workspace()
    isdir(root) || return nothing
    segs = filter(!isempty, split(rel, ('/', '\\')))
    any(s in ("..", ".") || occursin(':', s) for s in segs) && return nothing
    f = normpath(joinpath(root, segs...))
    startswith(abspath(f), abspath(root)) || return nothing
    return f
end

function wd_channels()
    out = Vector{Any}()
    try
        for instrnm in collect(keys(INSTRBUFFERVIEWERS))
            for addr in collect(keys(INSTRBUFFERVIEWERS[instrnm]))
                insbuf = INSTRBUFFERVIEWERS[instrnm][addr].insbuf
                for qt in collect(keys(insbuf.quantities))
                    read = insbuf.quantities[qt].read
                    push!(out, Dict(
                        "key" => string(instrnm, '/', qt, '/', addr),
                        "instr" => instrnm, "addr" => addr, "qt" => qt,
                        "value" => read, "v" => wd_parse(read),
                        "digits" => 4, "si" => false, "unit" => ""
                    ))
                end
            end
        end
    catch e
        # 仪器列表被并发修改时跳过本轮
    end
    return out
end

function wd_status()
    running = SYNCSTATES[IsDAQTaskRunning]
    if running && !WD_WASRUNNING[]
        WD_STARTEDAT[] = time()
    end
    WD_WASRUNNING[] = running
    return Dict(
        "running" => running,
        "blocked" => SYNCSTATES[IsBlocked],
        "interrupted" => SYNCSTATES[IsInterrupted],
        "task" => RUNNINGTASK,
        "taskIndex" => OLDI + 1,
        "oldi" => OLDI,
        "savepath" => SAVEPATH,
        "startedAt" => WD_STARTEDAT[],
        "totalPoints" => lock(DATABUF) do db
            sum(length(v) for v in values(db); init = 0)
        end
    )
end

function wd_progress()
    lock(PROGRESSLIST) do pl
        [Dict("name" => string(k)[1:8], "cur" => v[2], "total" => v[3]) for (k, v) in pl]
    end
end

# 1 Hz tick：全量状态 + 增量数据点
function wd_tick!()
    counts = WD_COUNTS
    deltas = Dict{String,Vector{Float64}}()
    streams = Vector{String}()
    lock(DATABUF) do db
        for (k, v) in db
            push!(streams, k)
            n = length(v)
            n0 = get(counts, k, 0)
            n > n0 || continue
            from = n - n0 > 4000 ? n - 3999 : n0 + 1   # 防止单帧过大
            deltas[k] = Float64[wd_parse(s) for s in v[from:n]]
            counts[k] = n
        end
        for k in keys(counts)
            haskey(db, k) || delete!(counts, k)
        end
    end
    return Dict(
        "t" => "tick",
        "ts" => time(),
        "status" => wd_status(),
        "progress" => wd_progress(),
        "channels" => wd_channels(),
        "streams" => streams,
        "deltas" => deltas
    )
end

###### 数据文件解析 ######
function wd_cols(data::AbstractDict)
    cols = Vector{Any}()
    nmax = 0
    for k in keys(data)
        v = data[k]
        arr = if v isa Vector{String}
            Float64[wd_parse(s) for s in v]
        elseif v isa Vector{<:Real}
            Float64.(v)
        else
            continue
        end
        nmax = max(nmax, length(arr))
        parts = split(k, "/")
        label = length(parts) >= 3 ? join(parts[(end - 1):end], "·") : k
        push!(cols, Dict("key" => k, "label" => label, "unit" => "", "data" => arr))
    end
    return cols, nmax
end

function api_file_data(params)
    f = wd_safejoin(get(params, "path", ""))
    (f === nothing || !isfile(f)) && return Dict("error" => "file not found")
    endswith(f, ".cache") && return Dict("error" => "cache file, use desktop to recover")
    data = @trypass JLD2.load(f, "data") Dict{String,Any}()
    task = @trypass JLD2.load(f, "daqtask") nothing
    valid = @trypass Bool(JLD2.load(f, "valid")) false
    cols, n = wd_cols(data)
    st = stat(f)
    return Dict(
        "file" => basename(f),
        "path" => get(params, "path", ""),
        "task" => (task === nothing || isempty(task.name)) ? splitext(basename(f))[1] : task.name,
        "valid" => valid,
        "size" => st.size,
        "mtime" => Dates.format(unix2datetime(st.mtime), "MM-dd HH:mm"),
        "explog" => task === nothing ? "" : String(task.explog),
        "savetype" => CONF.DAQ.savetype,
        "cols" => cols,
        "n" => n,
        "map2d" => nothing
    )
end

function api_files(params)
    root = wd_workspace()
    isempty(root) && return Dict("segs" => String[], "dirs" => Vector{Any}(), "files" => Vector{Any}())
    segs = filter(!isempty, split(get(params, "dir", ""), '/'))
    f = wd_safejoin(join(segs, '/'))
    f === nothing && return Dict("segs" => String[], "dirs" => Vector{Any}(), "files" => Vector{Any}())
    dirs = Vector{Any}()
    files = Vector{Any}()
    for p in sort!(readdir(f, join = true); by = mtime, rev = true)
        st = try stat(p) catch; continue end
        if isdir(p)
            push!(dirs, Dict("name" => basename(p)))
        else
            bnm = basename(p)
            ext = lowercase(splitext(bnm)[2])
            ext in (".qdt", ".daq", ".cfg", ".cache") || continue
            push!(files, Dict(
                "file" => bnm,
                "path" => replace(relpath(p, root), '\\' => '/'),
                "cache" => endswith(bnm, ".cache"),
                "valid" => nothing,
                "size" => st.size,
                "mtime" => Dates.format(unix2datetime(st.mtime), "MM-dd HH:mm")
            ))
        end
    end
    return Dict("segs" => String[k for k in segs], "dirs" => dirs, "files" => files)
end

###### AI 助手（复用 QInsControlAI 的会话状态与 sendchat! 入口；桌面与网页共享同一对话） ######
function api_ai_state()
    ai = QInsControlAI
    conf = try ai.aiconf() catch nothing end
    conf === nothing && return Dict("enable" => false, "busy" => false, "provider" => "",
        "conversations" => Any[], "messages" => Any[], "inflight" => "", "reasoning" => "", "toolsteps" => Any[])
    convs = Vector{Any}()
    msgs = Vector{Any}()
    steps = Vector{Any}()
    inflight = ""; reasoning = ""; busy = false; provider = ""
    lock(ai.CHATLOCK) do
        busy = ai.CHAT.busy
        inflight = ai.CHAT.inflight
        reasoning = ai.CHAT.reasoning
        cur = ai.currentconv()
        provider = cur.provider
        for c in ai.CHAT.conversations
            push!(convs, Dict("title" => c.title, "current" => c === cur, "n" => length(c.messages)))
        end
        for m in cur.messages
            m.role == "system" && continue
            push!(msgs, Dict("role" => m.role, "content" => m.content, "reasoning" => m.reasoning))
        end
        for (nm, arg, res) in ai.CHAT.toolsteps
            push!(steps, Dict("name" => nm, "arguments" => arg, "result" => first(res, 400)))
        end
    end
    return Dict("enable" => conf.enable, "busy" => busy, "provider" => provider,
        "conversations" => convs, "messages" => msgs, "inflight" => inflight,
        "reasoning" => reasoning, "toolsteps" => steps)
end

function api_ai_chat(body::AbstractDict)
    ai = QInsControlAI
    ai.aiconf().enable || return Dict("error" => "AI disabled")
    text = strip(String(get(body, "text", "")))
    isempty(text) && return Dict("error" => "empty text")
    ai.CHAT.busy && return Dict("error" => "busy")
    agent = get(body, "agent", false) == true
    ai.sendchat!(text; agent)
    return Dict("ok" => true)
end

api_ai_stop() = (QInsControlAI.stopchat!(); Dict("ok" => true))
api_ai_new() = (QInsControlAI.newconversation!(); Dict("ok" => true))

###### HTTP 路由 ######
const WD_MIME = Dict(
    ".html" => "text/html; charset=utf-8",
    ".js" => "text/javascript; charset=utf-8",
    ".css" => "text/css; charset=utf-8",
    ".svg" => "image/svg+xml",
    ".png" => "image/png",
    ".ico" => "image/x-icon"
)

function wd_static(path::AbstractString)
    dir = wd_webdir()
    isempty(dir) && return HTTP.Response(500, body = "web assets not found")
    rel = path == "/" ? "index.html" : lstrip(path, '/')
    f = normpath(abspath(joinpath(dir, rel)))
    root = normpath(abspath(dir))
    #前缀比较必须带分隔符:裸 startswith 可被同级目录绕过(web 目录旁的 web_backup 等同样命中前缀)
    (f == root || startswith(f, root * Base.Filesystem.path_separator)) || return HTTP.Response(403, body = "forbidden")
    isfile(f) || return HTTP.Response(404, body = "not found")
    ext = lowercase(splitext(f)[2])
    return HTTP.Response(200, ["Content-Type" => get(WD_MIME, ext, "application/octet-stream"),
        "Cache-Control" => "no-store"], body = read(f))
end

function handle_web(req::HTTP.Request)
    try
        target = String(req.target)
        qidx = findfirst('?', target)
        path = qidx === nothing ? target : String(target[1:prevind(target, qidx)])
        params = Dict{String,String}()
        query = qidx === nothing ? "" : String(target[nextind(target, qidx):end])
        isempty(query) || for pair in split(query, '&')
            kv = split(pair, '='; limit = 2)
            length(kv) == 2 && (params[wd_urldecode(kv[1])] = wd_urldecode(kv[2]))
        end
        # AI 端点：state 只读；chat/stop/new 是对既有 AI 入口的安全调用（无仪器写权限，agent 模式同桌面端开关）
        if startswith(path, "/api/ai/")
            resp = if req.method == "GET" && path == "/api/ai/state"
                wd_json(api_ai_state())
            elseif req.method == "POST" && path == "/api/ai/chat"
                # HTTP 2.x：请求体在 req.body（BytesBody），payload API 已移除
                body = try JSON.parse(String(req.body)) catch; Dict{String,Any}() end
                body isa AbstractDict || (body = Dict{String,Any}())
                wd_json(api_ai_chat(body))
            elseif req.method == "POST" && path == "/api/ai/stop"
                wd_json(api_ai_stop())
            elseif req.method == "POST" && path == "/api/ai/new"
                wd_json(api_ai_new())
            else
                Dict("error" => "method not allowed")
            end
            return HTTP.Response(200, ["Content-Type" => "application/json; charset=utf-8",
                "Cache-Control" => "no-store"], body = resp isa String ? resp : wd_json(resp))
        end
        req.method == "GET" || return HTTP.Response(405, body = "method not allowed")
        if startswith(path, "/api/")
            resp = if path == "/api/status"
                wd_json(wd_status())
            elseif path == "/api/files"
                wd_json(api_files(params))
            elseif path == "/api/file/data"
                wd_json(api_file_data(params))
            else
                Dict("error" => "unknown endpoint")
            end
            return HTTP.Response(200, ["Content-Type" => "application/json; charset=utf-8",
                "Cache-Control" => "no-store"], body = resp isa String ? resp : wd_json(resp))
        end
        return wd_static(path)
    catch e
        @error "[$(now())]\nweb dashboard request error" exception = e
        return HTTP.Response(500, body = sprint(showerror, e))
    end
end

function wd_urldecode(s::AbstractString)
    io = IOBuffer()
    i = firstindex(s)
    while i <= lastindex(s)
        c = s[i]
        if c == '%' && i + 2 <= lastindex(s)
            v = tryparse(UInt8, s[nextind(s, i):nextind(s, i, 2)]; base = 16)
            if v !== nothing
                write(io, v)
                i = nextind(s, i, 3)
                continue
            end
        elseif c == '+'
            write(io, ' ')
            i = nextind(s, i)
            continue
        end
        write(io, c)
        i = nextind(s, i)
    end
    return String(take!(io))
end

###### WebSocket 推送 ######
# 手工实现握手与服务端帧协议：本工具只需服务端单向推帧（浏览器端为标准实现），
# 服务端帧不掩码，客户端帧（仅 close/ping）只用于检测断开，读侧直接丢弃。
const WD_WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

function wd_ws_listen!(bind::AbstractString, port::Integer)
    addr = Sockets.InetAddr(parse(Sockets.IPv4, bind), Int(port))
    sock = Sockets.listen(addr)
    @spawn_record "webdashboard-ws" begin
        while isopen(sock)
            client = try Sockets.accept(sock) catch; break end
            Threads.@spawn wd_ws_conn(client)
        end
    end
    return sock
end

function wd_ws_write(io, s::String)
    data = codeunits(s)
    n = sizeof(s)
    head = UInt8[0x81]   # FIN + 文本帧
    if n < 126
        push!(head, UInt8(n))
    elseif n <= 0xFFFF
        push!(head, UInt8(126), UInt8(n >> 8), UInt8(n & 0xff))
    else
        push!(head, UInt8(127))
        for sh in (56, 48, 40, 32, 24, 16, 8, 0)
            push!(head, UInt8((n >> sh) & 0xff))
        end
    end
    write(io, head)
    write(io, data)
    flush(io)
    return nothing
end

function wd_ws_conn(io)
    key = ""
    #握手看门狗:对端连上后不发/发半截头的连接会让 readline 永久阻塞,socket 与任务一起泄漏
    handshakedone = Ref(false)
    errormonitor(Threads.@spawn begin
        sleep(10)
        handshakedone[] || (try close(io) catch; end)
    end)
    try
        while true
            line = readline(io)
            isempty(line) && break
            i = findfirst("Sec-WebSocket-Key:", line)
            i !== nothing && (key = strip(String(line[nextind(line, i[end]):end])))
        end
    catch e
        close(io)
        return
    end
    handshakedone[] = true
    isempty(key) && (close(io); return)
    try
        accept = base64encode(sha1(string(key, WD_WS_GUID)))
        write(io, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n",
            "Connection: Upgrade\r\nSec-WebSocket-Accept: ", accept, "\r\n\r\n")
        flush(io)
    catch e
        close(io)
        return
    end
    # 读丢弃任务：对端断开时 EOF → 关闭 socket，让写循环感知
    Threads.@spawn begin
        try
            while isopen(io)
                eof(io) && break
                readavailable(io)
            end
        catch
        end
        try close(io) catch end
    end
    try
        wd_ws_write(io, wd_json(Dict(
            "t" => "hello",
            "ts" => time(),
            "status" => wd_status(),
            "progress" => wd_progress(),
            "channels" => wd_channels(),
            "streams" => lock(DATABUF) do db
                String[k for k in keys(db)]
            end
        )))
        while isopen(io)
            t0 = time()
            wd_ws_write(io, wd_json(wd_tick!()))
            el = time() - t0
            el < 1.0 && sleep(1.0 - el)
        end
    catch e
        # 写失败 = 客户端断开，属正常退出
    finally
        try close(io) catch end
    end
    return nothing
end
