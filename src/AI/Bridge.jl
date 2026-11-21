# ============ Bridge.jl —— AI 模块与 QInsControl 其余部分的唯一边界 ============
# 强隔离规则(见 ai/ai-integration/03-architecture.md §4):
#   1. 本文件之外的 AI 代码禁止直接引用 QInsControl 的任何符号——逻辑层只调下面的
#      ai_* 适配函数(AI 无 UI 代码:前端视图在 src/Frontend/Windows/AIAssistant.jl,
#      经 QInsControlAI. 限定名调用后端,不属于本模块)。
#   2. 白名单变化必须体现在本文件的 import/注释中,评审时一目了然。
# ==============================================================================

import ..QInsControlCore: remote_write, remote_query, remote_qtread, remote_qtset, remote_include,
    remote_getcpuinfo,
    remote_write_ex, remote_query_ex, remote_read_ex, remote_qtread_ex, remote_qtset_ex,
    remote_call_driver, remote_driver_probe
import Sockets: Sockets, @ip_str, IPv4, IPv6, IPAddr, getalladdrinfo   # 本地/链路本地地址判定(Bridge.jl 尾部)

const qc = parentmodule(QInsControlAI)   # 主模块 QInsControl(动态限定访问,const/非 const 通吃)

# —— 跨线程 UI 封送:AI 任务线程 → 渲染线程(MainWindow 每帧调 drain_ui!) ——
const UIQUEUE = Channel{Function}(256)

function ai_ui_enqueue(f::Function)
    put!(UIQUEUE, f)
    return
end

function drain_ui!()
    while isready(UIQUEUE)
        f = take!(UIQUEUE)
        catchlog(f, "queued AI UI action failed!!!")
    end
    return
end

# —— 写操作确认门:AI 任务线程发起,AIAssistant 窗口内弹模态应答(120s 超时=拒绝) ——
mutable struct ConfirmRequest
    title::String
    detail::String
    answer::Ref{Union{Nothing,Bool}}
end
const CONFIRMREQS = Channel{ConfirmRequest}(32)

function ai_confirm(title::AbstractString, detail::AbstractString)
    if aiconf().confirmwrites
        #队满=渲染端无人消费(模态由 MainWindow 每帧经 RenderAIConfirm 消费,正常不会发生):
        #直接拒绝,防止 put! 在满 Channel 上永久挂起、AI 任务卡死不复位
        isfull(CONFIRMREQS) && return false
        req = ConfirmRequest(String(title), String(detail), Ref{Union{Nothing,Bool}}(nothing))
        put!(CONFIRMREQS, req)
        timedwait(() -> req.answer[] !== nothing, 120)
        return req.answer[] === true
    end
    #自动行动模式:免确认直接执行,但必须给出可见通知(toast 上限 8 条自动过期,不会堆积)
    qc.toast(:warn, "[AI] " * title, first(detail, 160))
    return true
end

takedisplaysreq() = isready(CONFIRMREQS) ? take!(CONFIRMREQS) : nothing

const AIINJECT = Ref{String}("")              #testcmd "发给 AI"按钮 → 聊天输入框的中转
const AIATTACH = Ref{Vector{NTuple{3,String}}}(NTuple{3,String}[])  #桌面端附件/绘图截图 → 聊天输入的中转(mime, b64, name)
const DEBUGSESSIONS = Dict{String,Float64}()  #addr → debug 会话到期时刻:窗口内免逐条确认,自动过期

"本地图片文件 → (mime, base64, name);非 png/jpeg 或超 4MB 返回 nothing"
function ai_encodefile(path::AbstractString)
    ext = lowercase(splitext(String(path))[2])
    ext in (".png", ".jpg", ".jpeg") || return nothing
    isfile(path) || return nothing
    filesize(path) > 4 * 1024 * 1024 && (@warn "[AI] image dropped: larger than 4MB" file = String(path); return nothing)
    mime = ext == ".png" ? "image/png" : "image/jpeg"
    return (mime, Base64.base64encode(read(String(path))), basename(String(path)))
end

"addr 是否处于 debug 会话窗口内(过期条目顺手清理);全部操作仍进工具步留档"
function indebugsession(addr::AbstractString)
    t = time()
    for k in keys(DEBUGSESSIONS)
        DEBUGSESSIONS[k] < t && delete!(DEBUGSESSIONS, k)
    end
    return get(DEBUGSESSIONS, String(addr), 0.0) > t
end

# ============ 上下文快照(只读) ============

ai_language() =
    try
        String(qc.CONF.Basic.language)
    catch
        "English"
    end

function ai_alias_table()
    out = Tuple{String,String,String}[]
    for (alias, a) in qc.INSTRALIASLIST
        push!(out, (String(alias), String(a.instrnm), String(a.addr)))
    end
    return out
end

function ai_instrument_summary(withhelp::Bool)
    buf = IOBuffer()
    for (insnm, oneins) in qc.INSTRCONF
        println(buf, "  instrument \"", insnm, "\":")
        for (qtnm, qtc) in oneins.quantities
            units = haskey(qc.CONF.U, qtc.U) ? join(string.(qc.CONF.U[qtc.U]), ", ") : ""
            extra = qtc.separator == "" ? "" : " (multi-value response, separator \"$(qtc.separator)\")"
            header = qtc.cmdheader == "" ? "" : " cmdheader=\"$(qtc.cmdheader)\""
            helpnote = withhelp && qtc.help != "" ? " | help: " * qtc.help : ""
            println(buf, "    quantity \"", qtnm, "\" [", qtc.type, "]", header, " units {", units, "}", extra, helpnote)
        end
    end
    return String(take!(buf))
end

ai_instrument_names() = String[k for k in keys(qc.INSTRCONF)]

"仪器面板实况:来自 INSTRBUFFERVIEWERS(GUI 仪器面板实际添加过的仪器)。
非 Others 条目 = 可用仪器(可能已连接,也可能连接后断开);Others = 未注册/连接有误的仪器
——新仪器驱动流程的起点:AI 可对它的 addr 直接发原始命令探测(query_command/driver_probe)。
withothers=true 时两段输出(可用段 + Others 待注册段);均交叉标注别名。
snapshot 与 get_instruments 工具共用"
function ai_usable_instruments(withothers::Bool = false)
    buf = IOBuffer()
    n = 0
    aliasrows = ai_alias_table()
    for pass in 1:(withothers ? 2 : 1)
        rows = IOBuffer()
        for (ins, addrs) in qc.INSTRBUFFERVIEWERS
            (ins == "Others") != (pass == 2) && continue   #pass1=可用仪器,pass2=Others
            for addr in keys(addrs)
                n += 1
                als = [t[1] for t in aliasrows if t[3] == addr]
                println(rows, "  ", addr, " (", ins, ")",
                    isempty(als) ? "" : ", alias: " * join(als, ", "))
            end
        end
        body = String(take!(rows))
        body == "" && continue
        pass == 2 && println(buf, "UNREGISTERED or failed-connect (under \"Others\") - still probe-able with raw commands via the address:")
        print(buf, body)
    end
    n == 0 && return "(no instruments added yet - open an instrument panel to add one)"
    return String(take!(buf))
end

"""
    ai_search_quantities(keyword) -> String

按关键词反查全部已注册量的定义(量名/仪器/类型/cmdheader/单位/help)——
用于把"磁场/电流/温度"这类物理量映射到具体仪器量。匹配范围:量名、量别名、
仪器名、help、cmdheader(不区分大小写)。
"""
function ai_search_quantities(keyword::AbstractString)
    k = lowercase(String(keyword))
    k == "" && return "(empty keyword)"
    buf = IOBuffer()
    n = 0
    for (insnm, oneins) in qc.INSTRCONF
        if occursin(k, lowercase(insnm))
            println(buf, "instrument \"", insnm, "\" (name match) cmdtype=\"", oneins.conf.cmdtype, "\" idn=\"", oneins.conf.idn, "\"")
        end
        for (qtnm, qtc) in oneins.quantities
            hit = occursin(k, lowercase(qtnm)) || occursin(k, lowercase(qtc.alias)) ||
                  occursin(k, lowercase(qtc.help)) || occursin(k, lowercase(qtc.cmdheader))
            hit || continue
            units = haskey(qc.CONF.U, qtc.U) ? join(string.(qc.CONF.U[qtc.U]), ", ") : ""
            n += 1
            println(
                buf, "  instrument \"", insnm, "\" quantity \"", qtnm, "\" [", qtc.type, "]",
                " cmdheader=\"", qtc.cmdheader, "\" units{", units, "}",
                qtc.separator == "" ? "" : " separator=\"$(qtc.separator)\"",
                qtc.help == "" ? "" : " help: " * qtc.help
            )
        end
    end
    n == 0 && !occursin("instrument \"", String(take!(copy(buf)))) && return "no registered quantity matches \"$keyword\""
    return String(take!(buf))
end

function ai_data_keys()
    buf = IOBuffer()
    lock(qc.DATABUF) do d
        isempty(d) && print(buf, "  (empty)")
        for (k, v) in d
            last = isempty(v) ? "" : string(" | last: ", v[end][1:min(end, 40)])
            println(buf, "  \"", k, "\" (", length(v), " pts)", last)
        end
    end
    return String(take!(buf))
end

function ai_data_keylist()
    return String.(collect(lock(keys, qc.DATABUF)))
end

"数据键统计摘要(单遍扫描,无中间分配):长度/min/max/mean/NaN 率/首尾值——
判读扫描质量比喂 200 个原始采样点省一个量级的 token"
function ai_data_stats(key::AbstractString)
    return lock(qc.DATABUFPARSED) do d
        haskey(d, key) || return "key \"$key\" not found (call get_data_keys for names)"
        v = d[key]
        n = length(v)
        n == 0 && return "key \"$key\" is empty"
        nnan = 0; nf = 0; mn = Inf; mx = -Inf; sm = 0.0
        for x in v
            isnan(x) && (nnan += 1; continue)
            nf += 1
            sm += x
            x < mn && (mn = x)
            x > mx && (mx = x)
        end
        base = nf == 0 ? "points=$n, ALL NaN" :
               "points=$n, nan=$(round(100nnan / n; digits = 1))%, min=$(round(mn; sigdigits = 4)), max=$(round(mx; sigdigits = 4)), mean=$(round(sm / nf; sigdigits = 4))"
        if v isa AbstractMatrix
            return "matrix $(size(v, 1))×$(size(v, 2)): " * base
        else
            return base * ", first=$(round(Float64(v[1]); sigdigits = 4)), last=$(round(Float64(v[end]); sigdigits = 4))"
        end
    end
end

function ai_data_sample(key::AbstractString, n::Int)
    out = lock(qc.DATABUFPARSED) do d
        haskey(d, key) || return "key \"$key\" not found"
        v = d[key]
        n = clamp(n, 1, aiconf().maxdatasample)
        if v isa AbstractMatrix
            rows = size(v, 1)
            io = IOBuffer()
            for r in max(1, rows - n + 1):rows
                println(io, join((v[r, c] for c in axes(v, 2)), ", "))
            end
            return String(take!(io))
        else
            isempty(v) && return "(empty)"
            return join(v[max(1, end - n + 1):end], "\n")
        end
    end
    return String(out)
end

function ai_task_list()
    buf = IOBuffer()
    tasks = qc.leafvalues(qc.taskroot())
    isempty(tasks) && print(buf, "  (empty; use get_task_script to read one task's full script)")
    for t in tasks
        nblk = try
            length(t.blocks)
        catch
            0
        end
        println(buf, "  task \"", t.name, "\" (", t.textmode ? "text" : "block", " mode, $nblk blocks)")
    end
    return String(take!(buf))
end

"剥掉 AST 里的 LineNumberNode(interpret 输出会带 #= 绝对路径:行号 =# 噪音)。
注意 :macrocall 的 args[2] 是结构必需的位置 LNN(宏名之后、真实参数之前)——
无条件删掉它会让宏调用的展示吞掉第一个参数(alias/rangemark 消失,旧 bug 的根因)"
function striplinenums(ex::Expr)
    if ex.head == :macrocall && length(ex.args) >= 2 && ex.args[1] isa Symbol && ex.args[2] isa LineNumberNode
        args = Any[ex.args[1], ex.args[2]]
        for a in ex.args[3:end]
            a isa LineNumberNode || push!(args, a isa Expr ? striplinenums(a) : a)
        end
        return Expr(ex.head, args...)
    end
    args = Any[a isa LineNumberNode ? nothing : (a isa Expr ? striplinenums(a) : a) for a in ex.args]
    filter!(a -> a !== nothing, args)
    return Expr(ex.head, args...)
end
striplinenums(x) = x

"""
    ai_task_script(taskname) -> String

读一个任务的完整脚本:文本模式给 editcodes 原文,块模式经 interpret 反向转成 DSL 文本
(与 GUI 里 Interpret 按钮同一通道,剥掉行号注释);附带备注(explog)。
"""
function ai_task_script(taskname::AbstractString)
    name = String(taskname)
    for t in qc.leafvalues(qc.taskroot())
        t.name == name || continue
        buf = IOBuffer()
        println(buf, "## Task \"", t.name, "\" (", t.textmode ? "text" : "block", " mode, ", length(t.blocks), " blocks)")
        t.explog == "" || println(buf, "notes: ", t.explog)
        println(buf, "```julia")
        script = try
            t.textmode ? t.editcodes :
            #保留的 macrocall 位置 LNN 会被 Expr 展示为 #= file:line =# 注释,这里清掉
            replace(string(striplinenums(qc.interpret(t.blocks))), r"#=[^=]*?=#\s*" => "")
        catch e
            "(script conversion failed: " * first(sprint(showerror, e), 200) * ")"
        end
        println(buf, script)
        println(buf, "```")
        return String(take!(buf))
    end
    return "task \"$name\" not found; call list_tasks for available names"
end

ai_task_names() = String[string(mlstr("Task"), " ", OLDI + i, " ", t.name) for (i, t) in enumerate(qc.leafvalues(qc.taskroot()))]
ai_plot_names() = String[p.name for p in qc.plotleaves(qc.DAQDATAPLOTS)]

function ai_list_plots()
    ps = qc.plotleaves(qc.DAQDATAPLOTS)
    isempty(ps) && return "(no plots yet; create one with create_plot)"
    buf = IOBuffer()
    println(buf, "plots:")
    for p in ps
        println(buf, "  \"", p.name, "\" (", length(p.dtpk.series), " series)")
    end
    return String(take!(buf))
end

"读现有绘图配置为 JSON(schema 与 To-Plot/```json 围栏一致),模型改完经 update_plot 回写"
function ai_get_plot(name::AbstractString)
    for p in qc.plotleaves(qc.DAQDATAPLOTS)
        p.name == String(name) || continue
        cfg = Dict{String,Any}("name" => p.name)
        p.dtpk.codes isa qc.CodeBlock && !isempty(p.dtpk.codes.codes) && (cfg["layout"] = p.dtpk.codes.codes)
        series = Any[]
        for (i, s) in enumerate(p.dtpk.series)
            d = Dict{String,Any}("index" => i, "x" => s.x, "y" => s.y, "z" => s.z, "w" => s.w)
            isempty(s.aux) || (d["aux"] = collect(String, s.aux))
            for (fld, key) in ((:processcodes, "processcodes"), (:processfigurecodes, "processfigurecodes"), (:plotcodes, "plotcodes"))
                c = getproperty(s, fld)
                c isa qc.CodeBlock && !isempty(c.codes) && (d[key] = c.codes)
            end
            push!(series, d)
        end
        cfg["series"] = series
        return JSON.json(cfg)
    end
    return "plot \"$name\" not found; call list_plots for names"
end

function ai_status()
    buf = IOBuffer()
    println(buf, "DAQ running: ", qc.SYNCSTATES[qc.IsDAQTaskRunning], ", blocked: ", qc.SYNCSTATES[qc.IsBlocked])
    println(buf, "instruments: ", length(qc.INSTRCONF), " registered, aliases: ", length(qc.INSTRALIASLIST))
    println(buf, "data keys: ", lock(length, qc.DATABUF))
    println(buf, "last error/warning: ", first(replace(ai_recent_errors(1), '\n' => " | "), 200))
    return String(take!(buf))
end

"tail 今日日志(CONF.Logs.dir/<年>/<年-月>/<日>.log,与 Logger 窗口同一文件),按 ┌/└ 块切分,
筛出 Error/Warning 块;每块截 600 字符防栈爆炸。报错求助链的数据源"
function ai_recent_errors(n::Int=8)
    date = Dates.today()
    logdir = joinpath(qc.CONF.Logs.dir, string(Dates.year(date)), string(Dates.year(date), "-", Dates.month(date)))
    logfile = joinpath(logdir, string(date, ".log"))
    isfile(logfile) || return "(no log file for today: $logfile)"
    blocks = String[]
    cur = ""
    for line in eachline(logfile)
        if occursin("┌ ", line)          #新块开始(Logger.jl 同款标记)
            isempty(cur) || push!(blocks, cur)
            cur = line * "\n"
        elseif !isempty(cur)
            cur *= line * "\n"
            occursin("└ ", line) && (push!(blocks, cur); cur = "")
        end
    end
    isempty(cur) || push!(blocks, cur)   #未闭合块(正在写/崩溃残留)也保留
    recent = filter(b -> occursin("┌ Error", b) || occursin("┌ Warning", b), blocks)
    isempty(recent) && return "(no errors/warnings in today's log)"
    n = clamp(n, 1, 30)
    sel = last(recent, min(n, length(recent)))
    return join((b -> length(b) > 600 ? first(b, 600) * "…[truncated]" : b).(sel), "\n---\n")
end

# ============ 跨会话记忆(能"学"的唯一通道是上下文工程:检索存档 + 记忆注入) ============

memoryfile() = normpath(joinpath(aiconf().dir, "..", "memory.md"))   #Assets/AI/memory.md(与 Sessions 并排)
const MEMORY_MAXCHARS = 6000      #超限自动轮转:丢最旧一半,迫使内容保持精华
const MEMORY_HEADER = "# Persistent memory (one lesson per line, newest at bottom; auto-rotated; user-editable)"

"读记忆全文(无文件返回空串);snapshot 按此注入每个新会话"
ai_memory_text() = isfile(memoryfile()) ? read(memoryfile(), String) : ""

"追加一条经验(自动加日期前缀,单行 ≤500 字;超限轮转丢最旧一半)"
function ai_remember(text::AbstractString)
    line = strip(String(text))
    (line == "" || length(line) > 500) && return "FAILED: memory entry must be 1-500 chars, single line"
    occursin(r"[\r\n]", line) && return "FAILED: memory entry must be a single line"
    mf = memoryfile()
    old = ai_memory_text()
    body = (startswith(old, MEMORY_HEADER) || old == "") ? old : MEMORY_HEADER * "\n" * old
    startsempty = isempty(body)
    body = startsempty ? MEMORY_HEADER : body
    stamp = Dates.format(Dates.now(), "yyyy-mm-dd")
    body = body * "\n- " * stamp * ": " * line
    if length(body) > MEMORY_MAXCHARS   #轮转:标题行 + 保留最近一半
        lines = split(body, "\n")
        keep = max(2, length(lines) ÷ 2)
        body = join(vcat([MEMORY_HEADER], lines[keep:end]), "\n")
    end
    mkpath(dirname(mf))
    open(mf, "w") do io
        write(io, body)
    end
    n = count(==('\n'), body) + 1
    return "remembered (memory now $n lines, $(length(body)) chars): " * line
end

"关键词检索历史会话存档(markdown 导出,人可读):按修改时间新→旧扫至多 60 个文件,
命中行原样返回(带所在文件与行号);本地 grep,不走网络预算"
function ai_search_history(keyword::AbstractString)
    k = lowercase(strip(String(keyword)))
    k == "" && return "(empty keyword)"
    root = aiconf().dir
    isdir(root) || return "(no session archives yet)"
    files = String[]                                    #walkdir 而非 readdir(recursive=):
    for (_, _, fs) in walkdir(root)                     #1.12 的 readdir 不再接受 recursive kw
        for f in fs
            endswith(f, ".md") && push!(files, joinpath(root, f))
        end
    end
    isempty(files) && return "(no session archives yet)"
    sort!(files; by = f -> stat(f).mtime, rev = true)
    files = first(files, 60)   #只扫最近 60 个会话,防历史膨胀后拖慢
    out = String[]
    tailpath(f) = joinpath(splitpath(f)[max(1, end - 2):end], "/")
    for f in files
        lines = try
            readlines(f)
        catch
            continue   #OneDrive 云占位/被占用的文件跳过:单个不可读不能炸掉整个检索
        end
        for (i, line) in enumerate(lines)
            occursin(k, lowercase(line)) || continue
            push!(out, "[" * tailpath(f) * ":$i] " * first(strip(line), 200))
            length(out) >= 40 && return join(out, "\n")
        end
    end
    isempty(out) && return "no matches for \"$keyword\" in the last $(length(files)) archived sessions"
    return join(out, "\n")
end

# ============ 仪器操作(Level 0/1 工具后端) ============

"DAQ 运行中给模型的提示前缀(读类探测不硬拦,写类操作另有确认门)"
daqwarn() = qc.SYNCSTATES[qc.IsDAQTaskRunning] ?
            "WARN: a DAQ task is running on the I/O worker; this test interleaves with it.\n" : ""

"_ex 通道结果 → 喂给模型的文本;ok=false 时附错误根因(旧行为是 String(nothing) 抛 MethodError,
根因只进日志文件,模型永远看不到失败原因)"
function _extest(res, what::AbstractString)
    res isa Tuple || return "$what FAILED: I/O worker call failed or timed out (instrument connected?)"
    ok, payload = res
    ok || return "$what FAILED: " * payload
    return payload
end

"数值验收:与数据管线同一解析规则(DAQTask.process_databufrc 的 tryparse(Float64),失败记 NaN)"
function _numericverdict(payload::AbstractString)
    v = tryparse(Float64, payload)
    v === nothing &&
        return "parseable-as-numeric: NO — the data pipeline would record NaN for this raw string; add parsing in the get function (strip prefixes/multi-values/units first)"
    return "parseable-as-numeric: YES (parsed: $v)"
end

function ai_read_quantity(instrnm::AbstractString, addr::AbstractString, qtnm::AbstractString)
    qtc = haskey(qc.INSTRCONF, instrnm) && haskey(qc.INSTRCONF[instrnm].quantities, qtnm) ?
          qc.INSTRCONF[instrnm].quantities[qtnm] : nothing
    timeout = qtc === nothing ? 3.0f0 : qtc.timeoutr
    return daqwarn() * _extest(remote_qtread_ex(instrnm, addr, qtnm, 4, timeout), "read")
end

"端到端驱动验收:注册通道实测 get + 数据管线同规则解析判定"
function ai_test_quantity(instrnm::AbstractString, addr::AbstractString, qtnm::AbstractString)
    qtc = haskey(qc.INSTRCONF, instrnm) && haskey(qc.INSTRCONF[instrnm].quantities, qtnm) ?
          qc.INSTRCONF[instrnm].quantities[qtnm] : nothing
    timeout = qtc === nothing ? 3.0f0 : qtc.timeoutr
    res = remote_qtread_ex(instrnm, addr, qtnm, 4, timeout)
    res isa Tuple || return daqwarn() * "read FAILED: I/O worker call failed or timed out (instrument connected?)"
    ok, raw = res
    ok || return daqwarn() * "read FAILED: " * raw
    return daqwarn() * "raw: \"$raw\"\n" * _numericverdict(raw)
end

"裸读(对应仪器窗口 Communication Test 的 Read 按钮;通常只在 write 之后有意义)"
function ai_read_raw(instrnm::AbstractString, addr::AbstractString)
    return daqwarn() * _extest(remote_read_ex(instrnm, addr, 4), "read")
end

"按名单测驱动 get 函数(量不必注册),附数值验收"
function ai_test_driver_get(instrnm::AbstractString, addr::AbstractString, func::AbstractString)
    res = remote_call_driver(instrnm, addr, String(func), "", :get, 4, 3.0f0, 5.0f0)
    res isa Tuple || return daqwarn() * "call FAILED: I/O worker call failed or timed out (instrument connected?)"
    ok, raw = res
    ok || return daqwarn() * "call FAILED: " * raw
    return daqwarn() * "raw: \"$raw\"\n" * _numericverdict(raw)
end

"按名单测驱动 set 函数(量不必注册)"
function ai_test_driver_set(instrnm::AbstractString, addr::AbstractString, func::AbstractString, val)
    res = remote_call_driver(instrnm, addr, String(func), val, :set, 4, 3.0f0, 3.0f0)
    res isa Tuple || return "set FAILED: I/O worker call failed or timed out"
    ok, payload = res
    ok || return "set FAILED: " * payload
    return "set written OK"
end

"单连接内顺序执行 write/query/read/sleep 序列,返回完整 transcript"
function ai_driver_probe(instrnm::AbstractString, addr::AbstractString, steps::Vector{Tuple{String,String}})
    total_sleep = 0.0
    for (op, arg) in steps
        op == "sleep" && (total_sleep += (tryparse(Float64, arg) === nothing ? 0.0 : parse(Float64, arg)))
    end
    outer = 20.0 + total_sleep   #attr 超时之外给 sleep 与连接建立留预算
    res = remote_driver_probe(instrnm, addr, steps, 4, 3.0f0, 5.0f0, outer)
    res isa Tuple || return "probe FAILED: I/O worker call failed or timed out"
    ok, transcript = res
    ok || return "probe FAILED (see transcript):\n" * transcript
    return "transcript:\n" * transcript
end

"通信参数设置(Level 2 工具后端):走主模块 aisetcommattr! → saveattr 同通道(不绕过 CONF)"
function ai_set_comm_attr(alias::AbstractString, key::AbstractString, value)
    r = resolveaddr(alias)
    r === nothing && return "unknown alias or address \"$alias\""
    return qc.aisetcommattr!(r[2], key, value)
end

"开启 debug 会话:窗口期内对该地址免逐条确认(总开关 confirmwrites 优先级更高,仍生效)"
function ai_enable_debug_session(alias::AbstractString, minutes::Real)
    r = resolveaddr(alias)
    r === nothing && return "unknown alias or address \"$alias\""
    minutes = clamp(Float64(minutes), 1.0, 30.0)
    aiconf().confirmwrites || return "confirmwrites is off in settings - no confirmation was happening anyway; session not needed"
    ai_confirm("Enable Debug Session",
        "$alias @ $(r[2]): skip per-call confirmation for write/query/set/probe tools for $minutes minutes.\nAll actions still appear in the tool transcript and the instrument window.") ||
        return "user declined"
    DEBUGSESSIONS[r[2]] = time() + minutes * 60
    return "debug session enabled for \"$alias\" ($(r[2])) for $minutes minutes. Tools still log every action."
end

"镜像 AI 的命令/响应到仪器窗口 Communication Test 历史(窗口开着才写;仅观测用途)"
function ai_mirrortolog(instrnm::AbstractString, addr::AbstractString, text::AbstractString)
    qc.aiappendtestlog(instrnm, addr, text)
    return
end

function ai_set_quantity(instrnm::AbstractString, addr::AbstractString, qtnm::AbstractString, sv)
    qtc = haskey(qc.INSTRCONF, instrnm) && haskey(qc.INSTRCONF[instrnm].quantities, qtnm) ?
          qc.INSTRCONF[instrnm].quantities[qtnm] : nothing
    timeoutw = qtc === nothing ? 3.0f0 : qtc.timeoutw
    timeoutr = qtc === nothing ? 3.0f0 : qtc.timeoutr
    #控制器 set 通道只收字符串(与扫描块 string(ijk) 同约定);MCP/AI 常给数字,
    #裸传会 MethodError——边界处统一字符串化,unitless 量的字符串值原样保留
    return _extest(remote_qtset_ex(instrnm, addr, qtnm, string(sv), 4, timeoutw, timeoutr), "set")
end

function ai_write(instrnm::AbstractString, addr::AbstractString, cmd::AbstractString)
    res = remote_write_ex(instrnm, addr, String(cmd), 4)
    res isa Tuple || return "write FAILED: I/O worker call failed or timed out"
    res[1] || return "write FAILED: " * res[2]
    return "written OK"
end

function ai_query(instrnm::AbstractString, addr::AbstractString, cmd::AbstractString)
    return _extest(remote_query_ex(instrnm, addr, String(cmd), 4), "query")
end

ai_interrupt!() = (qc.SYNCSTATES[qc.IsInterrupted] = true; nothing)

# ============ 脚本与工程写入(Level 2 工具后端;结构性变更一律封送 UI 线程) ============

"""
    ai_validate_script(text) -> (ok::Bool, blocks|nothing, errmsg::String)

文本脚本校验:Meta.parseall → antiinterpretblocks(与 GUI Anti-interpret 同一通道),
再加一道**别名/量名白名单检查**——antiinterpret 对不存在的 alias 会静默生成占位块,
必须在此拦下(AI 幻觉的别名应触发修复循环而不是生成坏任务)。
"""
function ai_validate_script(text::AbstractString)
    blocks = try
        ex = Meta.parseall(String(text); filename="aiscript")
        qc.antiinterpretblocks(ex)
    catch e
        #strtoU 对未知单位经 @u_str 抛 Unitful ArgumentError,原始消息是
        #"LoadError: ... Symbol ZZ could not be found in unit modules ..." 含绝对路径,
        #模型难定位——翻译成一句可行动的提示,其余异常维持原文
        msg = sprint(showerror, e)
        m = match(r"Symbol (\S+) could not be found in unit modules", msg)
        m !== nothing && return (false, nothing,
            "unknown unit \"$(m[1])\" — use one of the registered unit strings for the quantity (the units{...} lists from list_instruments)")
        return (false, nothing, msg)
    end
    aliases = Set(String(a) for (a, _, _) in ai_alias_table())
    problems = String[]
    n = 0
    for bk in allscriptblocks(blocks)
        n += 1
        bk isa qc.NullBlock && continue
        propnames = try
            propertynames(bk)
        catch
            ()
        end
        :alias in propnames || continue
        bk.alias in aliases || push!(problems, "block #$n: unknown alias \"$(bk.alias)\"")
        if bk.alias in aliases && :quantity in propnames &&
           haskey(qc.INSTRCONF, bk.instrnm) && !isempty(bk.quantity)
            haskey(qc.INSTRCONF[bk.instrnm].quantities, bk.quantity) ||
                push!(problems, "block #$n: instrument \"$(bk.instrnm)\" has no quantity \"$(bk.quantity)\"")
        end
    end
    isempty(problems) || return (false, nothing, join(problems, "\n"))
    return (true, blocks, "")
end

"递归展开块树(含容器块的子块)"
function allscriptblocks(blocks)
    out = qc.AbstractBlock[]
    for bk in blocks
        bk isa qc.NullBlock && continue
        push!(out, bk)
        bk isa qc.StrideCodeBlock && append!(out, allscriptblocks(bk.blocks))
        (bk isa qc.SweepBlock || bk isa qc.FreeSweepBlock) && append!(out, allscriptblocks(bk.blocks))
    end
    return out
end

"块树 → 预览摘要行(一块一行,供预览确认窗与 create_task/update_task 工具使用)"
function blocksummary(blocks)
    lines = String[]
    for bk in blocks
        bk isa qc.NullBlock && continue
        t = nameof(typeof(bk))
        line = try
            if bk isa qc.SweepBlock
                "$t: $(bk.alias) $(bk.quantity) step=$(bk.step) stop=$(bk.stop) delay=$(bk.delay)"
            elseif bk isa qc.FreeSweepBlock
                "$t: $(bk.alias) $(bk.quantity) mode=$(bk.mode) stop=$(bk.stop) duration=$(bk.duration)"
            elseif bk isa qc.SettingBlock
                "$t: $(bk.alias) $(bk.quantity) = $(bk.setvalue) check=$(bk.ischeck)"
            elseif bk isa qc.ReadingBlock
                "$t: $(bk.alias) $(bk.quantity) index=$(bk.index) mark=$(bk.mark) async=$(bk.isasync) observe=$(bk.isobserve)"
            elseif bk isa qc.QueryBlock
                "$t: $(bk.alias) \"$(first(bk.cmd, 40))\" index=$(bk.index) mark=$(bk.mark)"
            elseif bk isa qc.WriteBlock
                "$t: $(bk.alias) \"$(first(bk.cmd, 40))\""
            elseif bk isa qc.ReadBlock
                "$t: $(bk.alias) index=$(bk.index) mark=$(bk.mark)"
            elseif bk isa qc.FeedbackBlock
                "$t: $(bk.alias) $(bk.action)"
            elseif bk isa qc.StrideCodeBlock
                "$t: $(first(bk.codes, 60))"
            elseif bk isa qc.BranchBlock
                "$t: $(first(bk.codes, 60))"
            elseif bk isa qc.CodeBlock
                "$t: $(first(replace(bk.codes, '\n' => ' '), 60))"
            else
                string(t)
            end
        catch
            string(t)
        end
        push!(lines, line)
    end
    return lines
end

function ai_add_task(name::AbstractString, script::AbstractString, blocks)
    ai_ui_enqueue() do
        task = qc.DAQTask(
            name=String(name),
            blocks=collect(qc.AbstractBlock, blocks),
            editcodes=String(script),
            textmode=false,
            showeditor=true
        )
        push!(qc.taskroot().children, qc.Tree(task))
    end
    return
end

function ai_update_task(taskname::AbstractString, script::AbstractString, blocks)
    ai_ui_enqueue() do
        for t in qc.leafvalues(qc.taskroot())
            t.name == String(taskname) || continue
            t.blocks = collect(qc.AbstractBlock, blocks)
            t.editcodes = String(script)
            t.textmode = false
            t.showeditor = true
            break
        end
    end
    return
end

"按 taskroot 叶子枚举序更新任务——ai_task_names() 是带序号的显示名,不能反查 t.name,
预览确认窗的\"更新已有任务\"必须走索引(与 ai_task_names 的 enumerate 顺序严格一致)"
function ai_update_task_byindex(idx::Int, script::AbstractString, blocks)
    ai_ui_enqueue() do
        leaves = qc.leafvalues(qc.taskroot())
        1 <= idx <= length(leaves) || return
        t = leaves[idx]
        t.blocks = collect(qc.AbstractBlock, blocks)
        t.editcodes = String(script)
        t.textmode = false
        t.showeditor = true
    end
    return
end

function ai_add_alias(alias::AbstractString, instrnm::AbstractString, addr::AbstractString)
    ai_ui_enqueue() do
        qc.INSTRALIASLIST[String(alias)] = qc.InstrAlias(alias=String(alias), instrnm=String(instrnm), addr=String(addr))
    end
    return
end

"""
    ai_save_project() -> String

把当前打开的工程(含本会话 AI 创建的任务/绘图)落盘——内存里的任务树重启即失,
AI 建完实验必须提醒或代为保存。返回失败列表(空 = 成功)。
"""
function ai_save_project()
    ch = Channel{Vector{String}}(1)
    ai_ui_enqueue() do
        put!(ch, qc.savecurrentproject())
    end
    timedwait(() -> isready(ch), 10)   #等 UI 线程真正执行完(ai_ui_enqueue 是异步投递,Ref 回读有竞态)
    isready(ch) || return "FAILED: project save timed out (UI busy)"
    failures = take!(ch)
    isempty(failures) && return "project saved (tasks, plots, aliases, circuit)."
    return occursin("no project is open", first(failures)) ?
           "FAILED: no project is open - ask the user to open or create one via the Project menu, then run save_project again" :
           "FAILED: saving project had failures:\n" * join(failures, "\n")
end

"按名字删任务:两级树(顶层 + 一级分类)里搜叶子载荷名;删的是 AI 可见的那份内存态,
落盘仍需 save_project"
function ai_delete_task(taskname::AbstractString)
    ch = Channel{Bool}(1)
    ai_ui_enqueue() do
        found = false
        for container in (qc.taskroot(), qc.taskroot().children...)
            container.isgroup || continue
            i = findfirst(c -> !c.isgroup && c.value.name == String(taskname), container.children)
            i === nothing && continue
            deleteat!(container.children, i)
            found = true
            break
        end
        put!(ch, found)
    end
    timedwait(() -> isready(ch), 10)
    (isready(ch) && take!(ch)) || return "FAILED: task \"$taskname\" not found (or UI too busy to confirm); call list_tasks for names"
    return "task \"$taskname\" deleted (in memory; run save_project to persist the change)."
end

"按名字删绘图(与删任务同两级树约定)"
function ai_delete_plot(plotname::AbstractString)
    ch = Channel{Bool}(1)
    ai_ui_enqueue() do
        found = false
        for container in (qc.DAQDATAPLOTS, qc.DAQDATAPLOTS.children...)
            container.isgroup || continue
            i = findfirst(c -> !c.isgroup && c.value.name == String(plotname), container.children)
            i === nothing && continue
            deleteat!(container.children, i)
            found = true
            break
        end
        put!(ch, found)
    end
    timedwait(() -> isready(ch), 10)
    (isready(ch) && take!(ch)) || return "FAILED: plot \"$plotname\" not found (or UI too busy to confirm); call list_plots for names"
    return "plot \"$plotname\" deleted (in memory; run save_project to persist the change)."
end

# ============ 绘图写入(Deepcopy 副本上先校验,再经 UI 队列落位) ============

"""
    ai_validate_plotcfg(cfg) -> (errmsg, warnmsg)

校验 AI 产出的绘图配置。列键不在当前 DATABUF 白名单**不再硬拒**(任务尚未运行时引用未来
数据键是合法工作流),降级为警告随确认窗展示;结构性错误(类型/形状)仍硬拒。
"""
function ai_validate_plotcfg(cfg::AbstractDict)
    whitelist = ai_data_keylist()
    warns = String[]
    for (fld, key) in (("x", "x"), ("y", "y"), ("z", "z"), ("w", "w"))
        for s in get(cfg, "series", Any[])
            s isa AbstractDict || return ("series entries must be objects", "")
            v = get(s, key, "")
            v isa AbstractString || return ("series $(key)-column must be a string", "")
            (v == "" || v in whitelist) ||
                push!(warns, "series $(key)-column \"$v\" is not a data key yet (reads NaN until a task writes it)")
        end
    end
    return ("", join(unique(warns), "; "))
end

function applyplotcfg!(dtp, cfg::AbstractDict)
    haskey(cfg, "layout") && cfg["layout"] isa AbstractString && !isempty(cfg["layout"]) && begin
            dtp.dtpk.codes = qc.CodeBlock(codes=String(cfg["layout"]))
            dtp.dtpk.updatelayout = true
        end
    for s in get(cfg, "series", Any[])
        s isa AbstractDict || continue
        idx = tryparse(Int, string(get(s, "index", 0)))
        dtss = (idx === nothing || idx < 1 || idx > length(dtp.dtpk.series)) ? nothing : dtp.dtpk.series[idx]
        if dtss === nothing
            push!(dtp.dtpk.series, qc.DataSeries())
            dtss = dtp.dtpk.series[end]
        end
        for fld in (:x, :y, :z, :w)
            v = get(s, string(fld), nothing)
            v isa AbstractString && setproperty!(dtss, fld, String(v))
        end
        aux = get(s, "aux", nothing)
        aux isa Vector && (dtss.aux = String.(aux))
        for fld in (:processcodes, :processfigurecodes, :plotcodes)
            v = get(s, string(fld), nothing)
            v isa AbstractString && !isempty(v) && setproperty!(dtss, fld, qc.CodeBlock(codes=String(v)))
        end
        dtss.updateprocessfunc = true
        dtss.updateprocessfigurefunc = true
        dtss.updateplot = true
        dtss.update = true
    end
    dtp.dtpk.update = true
    return dtp
end

function ai_add_plot(name::AbstractString, cfg::AbstractDict)
    ai_ui_enqueue() do
        dtp = qc.DataPlot(name=String(name))
        applyplotcfg!(dtp, cfg)
        dtp.showplot = true
        push!(qc.DAQDATAPLOTS.children, qc.Tree(dtp))
    end
    return
end

function ai_update_plot(name::AbstractString, cfg::AbstractDict)
    ai_ui_enqueue() do
        for p in qc.plotleaves(qc.DAQDATAPLOTS)
            p.name == String(name) || continue
            applyplotcfg!(p, cfg)
            break
        end
    end
    return
end

# ============ 仪器驱动读写(写已有仪器新驱动 / 注册新仪器;Level 2 工具后端) ============
# 驱动体系两件套:Confs/<name>.toml(注册表:conf.idn/cmdtype + 各量定义) +
# ExtraLoad/<name>.jl(手写 set/get 函数,worker 上 include)。cmdtype 非空且 cmdheader
# 非空的量由 gen_qtfunc 自动生成 <ins>_<qt>_get/set;ExtraLoad 先于代码生成加载,
# 同名函数会被代码生成覆盖——手写量的 cmdheader 必须留空。

sanename(name::AbstractString) = String(filter(c -> isletter(c) || isdigit(c) || c in "-_", String(name)))

conffile(name::AbstractString) = joinpath(assetsdir(), "Confs", sanename(name) * ".toml")
driverfile(name::AbstractString) = joinpath(assetsdir(), "ExtraLoad", sanename(name) * ".jl")

"""
    ai_driver_info(name) -> String

汇总一台仪器的注册信息与当前驱动源码,供 AI 修改已有驱动前阅读。
包含:conf(idn/cmdtype)、各量定义(cmdheader/type/单位/help)、可用单位类型表(CONF.U 键)、
ExtraLoad 驱动文件内容。
"""
function ai_driver_info(name::AbstractString)
    buf = IOBuffer()
    insnm = String(name)
    println(buf, "## Instrument \"", insnm, "\"")
    if haskey(qc.INSTRCONF, insnm)
        oneins = qc.INSTRCONF[insnm]
        println(buf, "conf.idn = \"", oneins.conf.idn, "\"  conf.cmdtype = \"", oneins.conf.cmdtype, "\"")
        for (qtnm, qtc) in oneins.quantities
            units = haskey(qc.CONF.U, qtc.U) ? join(string.(qc.CONF.U[qtc.U]), ", ") : ""
            println(
                buf, "  quantity \"", qtnm, "\" [", qtc.type, "] cmdheader=\"", qtc.cmdheader,
                "\" unittype=\"", qtc.U, "\" units{", units, "} separator=\"", qtc.separator, "\"",
                qtc.help == "" ? "" : " help: " * qtc.help
            )
        end
    else
        println(buf, "(not registered in INSTRCONF)")
    end
    println(buf, "Available unit types (conf quantity field U must be one of these keys):")
    println(buf, "  ", join(sort(collect(keys(qc.CONF.U))), ", "))
    df = driverfile(insnm)
    println(buf, "## Driver file ", df, isfile(df) ? ":" : ":\n(not created yet)")
    isfile(df) && println(buf, read(df, String))
    return String(take!(buf))
end

"""
    ai_validate_conftoml(text) -> errmsg::String(空串 = 通过)

校验 AI 产出的仪器注册 TOML:conf 表必备字段、量定义字段与取值。
"""
function ai_validate_conftoml(text::AbstractString)
    conf = try
        TOML.parse(String(text))
    catch e
        return "TOML parse error: " * sprint(showerror, e)
    end
    haskey(conf, "conf") || return "missing [conf] table"
    conf["conf"] isa AbstractDict || return "[conf] must be a table"
    haskey(conf["conf"], "idn") || return "missing conf.idn (IDN keywords, ';' separated)"
    cmdtype = string(get(conf["conf"], "cmdtype", ""))
    cmdtype in ("", "scpi", "tsp") || return "conf.cmdtype must be \"\", \"scpi\" or \"tsp\""
    nq = 0
    for (k, v) in conf
        k == "conf" && continue
        v isa AbstractDict || return "quantity [$k] must be a table"
        t = string(get(v, "type", "set"))
        t in ("read", "set", "sweep") || return "quantity [$k]: type must be \"read\", \"set\" or \"sweep\""
        get(v, "cmdheader", "") isa AbstractString || return "quantity [$k]: cmdheader must be a string"
        nq += 1
    end
    nq == 0 && return "no quantity tables defined (every quantity is a [name] table)"
    return ""
end

"写已有仪器的新驱动(ExtraLoad/<name>.jl)并在 worker 上热加载"
function ai_write_driver(name::AbstractString, code::AbstractString)
    path = driverfile(name)
    mkpath(dirname(path))
    open(path, "w") do io
        print(io, String(code))
    end
    remote_include(path)
    return path
end

"""
    ai_create_instrument(name, conftoml, drivercode) -> String

注册新仪器:写 Confs/<name>.toml + ExtraLoad/<name>.jl(可选),再 loadinsconf() 全量
重载注册(与启动时同一通道)。drivercode 为空串时跳过驱动文件。
"""
function ai_create_instrument(name::AbstractString, conftoml::AbstractString, drivercode::AbstractString)
    err = ai_validate_conftoml(conftoml)
    err != "" && return err
    cpath = conffile(name)
    open(cpath, "w") do io
        print(io, String(conftoml))
    end
    dpath = ""
    if !isempty(strip(String(drivercode)))
        dpath = driverfile(name)
        mkpath(dirname(dpath))
        open(dpath, "w") do io
            print(io, String(drivercode))
        end
    end
    qc.loadinsconf()
    return string(
        "instrument \"", sanename(name), "\" registered (", cpath,
        dpath == "" ? "" : " + " * dpath,
        "); INSTRCONF now has ", length(qc.INSTRCONF), " instruments. ",
        "Add it to the project via the alias editor, then it can be used in scripts."
    )
end

# ============ 联网查手册(web_search / fetch_url;Level 0,受 allowweb 开关约束) ============

striptags(html::AbstractString) = begin
    t = replace(String(html), r"<script.*?</script>"s => "", r"<style.*?</style>"s => "")
    t = replace(t, r"<[^>]*>" => " ")
    for (ent, ch) in ("&amp;" => "&", "&lt;" => "<", "&gt;" => ">", "&quot;" => "\"", "&#x27;" => "'", "&nbsp;" => " ")
        t = replace(t, ent => ch)
    end
    replace(t, r"\s+" => " ")
end

const _WEB_UA = ["User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"]
const _PREFERCURL = Ref(false)   #HTTP.jl 一旦失败,本进程后续网页抓取直接走 libcurl,不再白等超时

"网页 HTML 抓取:HTTP.jl(MbedTLS)先试,任何失败(含本机网络下 TLS 握手挂起)退回
Downloads(libcurl,走 schannel/openssl,实测可过同一网络)。两者都不跟随重定向
(HTTP.jl redirect=false;Downloads/libcurl 默认即不跟随),SSRF 检查只做初始 host 即可。"
function _fetchhtml(u::AbstractString, timeout::Real)
    if !_PREFERCURL[]
        try
            resp = HTTP.get(u; headers = _WEB_UA, request_timeout = timeout, retry = false, redirect = false)
            return String(resp.body)
        catch
            _PREFERCURL[] = true   #本进程记住:这台机器/这条网络走 libcurl
        end
    end
    buf = IOBuffer()
    Downloads.download(u, buf; timeout = Float64(timeout), headers = _WEB_UA)
    return String(take!(buf))
end

function ai_web_search(query::AbstractString)
    aiconf().allowweb || return "web access is disabled in AI settings"
    nb = netbudget!()
    nb === nothing || return nb
    q = HTTP.escapeuri(String(query))
    # Bing(国内可达)优先,DuckDuckGo 兜底;都失败则提示。
    # Bing 对无 cookie 客户端非确定性地软屏蔽(偶发返回首页/热榜页而非结果页),重试一次常能拿到真结果页
    results = String[]
    #锚定 <li class="b_algo" 结果块:垃圾页上仍有零散 <h2> 链接,全页匹配会把热榜链接当结果
    bingparse(html) = begin
        out = String[]
        for m in eachmatch(r"<li class=\"b_algo\".*?<h2[^>]*><a[^>]*href=\"(http[^\"]+)\"[^>]*>(.*?)</a>"s, html)
            push!(out, string(striptags(m.captures[2]), "\n  ", m.captures[1]))
        end
        return out
    end
    for _ in 1:2
        html = try
            _fetchhtml("https://www.bing.com/search?q=$q&count=10", 8)
        catch
            ""
        end
        results = bingparse(html)
        isempty(results) || break
    end
    isempty(results) || return join(first(results, 8), "\n")
    html = try
        _fetchhtml("https://html.duckduckgo.com/html/?q=$q", 8)
    catch
        ""
    end
    for m in eachmatch(r"class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>"s, html)
        href = String(m.captures[1])
        uddg = match(r"uddg=([^&]+)", href)
        uddg === nothing || (href = HTTP.URIs.unescapeuri(String(uddg.captures[1])))
        push!(results, string(striptags(m.captures[2]), "\n  ", href))
    end
    isempty(results) || return join(first(results, 8), "\n")
    return "web search failed (network unreachable or engines blocked); try fetch_url with a direct documentation URL"
end

#IPv4 私网/环回/链路本地判定(Julia 1.12 的 Sockets 未提供 isprivate/isloopback,手写全量清单;
#addr 为 host 序 UInt32,"前缀长度 = 32 - 移位数")
function isprivatev4(v::UInt32)
    return (v >> 24) == 0x0a ||      #10.0.0.0/8 私网
           (v >> 20) == 0xac1 ||     #172.16.0.0/12 私网
           (v >> 16) == 0xc0a8 ||    #192.168.0.0/16 私网
           (v >> 24) == 0x7f ||      #127.0.0.0/8 环回
           (v >> 16) == 0xa9fe ||    #169.254.0.0/16 链路本地
           (v >> 22) == 0x191 ||     #100.64.0.0/10 CGNAT
           v == 0x00000000           #0.0.0.0 未指定
end

#Julia 1.12 把 IPv4/IPv6 的字段从 addr 改名为 host(compat 声明 1.10):两型都是单字段结构,按位置取
ipvalue(ip::IPv4) = getfield(ip, fieldnames(IPv4)[1])::UInt32
ipvalue(ip::IPv6) = UInt128(getfield(ip, fieldnames(IPv6)[1])::UInt128)

"IPv6:未指定/环回/ULA/链路本地;::ffff:0:0/96 映射与弃用的 ::/96 兼容形式取低 32 位按 IPv4 复判"
function isprivateaddr(ip::IPAddr)
    ip isa IPv4 && return isprivatev4(ipvalue(ip))
    ip isa IPv6 || return true   #未知地址类型按拒绝处理
    a = ipvalue(ip)
    a == UInt128(0) && return true   #:: 未指定
    a == UInt128(1) && return true   #::1 环回
    (a >> 32) == 0xffff && return isprivatev4(UInt32(a & 0xffffffff))                         #::ffff:a.b.c.d 映射
    (a >> 96) == 0x0000 && (a & 0xffffffff00000000) == 0 &&                                   #::a.b.c.d 兼容形式
        return isprivatev4(UInt32(a & 0xffffffff))
    ((a >> 120) == 0xfc || (a >> 120) == 0xfd) && return true   #fc00::/7 ULA
    (a >> 118) == 0x3fa && return true                          #fe80::/10 链路本地
    return false
end

"SSRF 防护:fetch_url 是免确认工具,内网/环回地址一律拒绝——否则模型可借它探打本机
无鉴权服务(WebDashboard/QIC server 等)并把响应带回会话。
IPAddr 是抽象类型,字面量必须 parse;域名解析出多个地址时逐个检查(首地址公网、次地址内网的双解析是经典绕过)"
function isprivatenethost(host::AbstractString)
    h = String(host)
    isempty(h) && return true
    ips = try
        [parse(IPAddr, h)]       #裸 IP 字面量不经 DNS
    catch
        try
            getalladdrinfo(h)    #域名:解析结果本身就是 Vector{IPAddr}
        catch
            IPAddr[]             #解析失败按拒绝处理
        end
    end
    isempty(ips) && return true
    return any(isprivateaddr, ips) #任一解析结果落内网即拒绝(DNS rebinding 的 TOCTOU 窗口在此威胁模型下可接受)
end

function ai_fetch_url(url::AbstractString)
    aiconf().allowweb || return "web access is disabled in AI settings"
    nb = netbudget!()
    nb === nothing || return nb
    u = String(url)
    startswith(u, "http") || (u = "https://" * u)
    #URL 去重:同一 URL 本轮只抓一次——反复抓相同页面是模型检索死循环的典型形态
    norm = lowercase(strip(u, ['/', ' ']))
    norm in FETCHEDURLS &&
        return "you already fetched this URL earlier in this conversation - do NOT fetch it again; use the information you already have, try a DIFFERENT page, or ask the user"
    push!(FETCHEDURLS, norm)
    host = try
        HTTP.URIs.URI(u).host
    catch
        ""
    end
    isprivatenethost(host) &&
        return "fetching private/loopback addresses is not allowed (SSRF protection)"
    if !_PREFERCURL[]
        try
            #redirect=false:禁止跟随重定向——SSRF 检查只做在初始 host 上,302 跳内网是经典绕过
            resp = HTTP.get(u; request_timeout=20, retry=false, redirect=false, headers=_WEB_UA)
            300 <= resp.status < 400 &&
                return "request was redirected to $(get(Dict(resp.headers), "Location", "?")) (redirects are not followed)"
            ctype = lowercase(get(Dict(resp.headers), "Content-Type", ""))
            occursin("pdf", ctype) &&
                return "the page is a binary PDF which cannot be parsed; search for an HTML version or the vendor's SCPI command reference page"
            return first(striptags(String(resp.body)), 20000)
        catch
            _PREFERCURL[] = true   #本进程记住:后续直接走 libcurl
        end
    end
    #Downloads(libcurl)通道:无响应头,PDF 用魔数判;libcurl 默认不跟随重定向,与上面同策略
    try
        buf = IOBuffer()
        Downloads.download(u, buf; timeout = 20.0, headers = _WEB_UA)
        text = String(take!(buf))
        startswith(text, "%PDF") &&
            return "the page is a binary PDF which cannot be parsed; search for an HTML version or the vendor's SCPI command reference page"
        return first(striptags(text), 20000)
    catch e2
        return "FAILED: fetch failed: " * first(sprint(showerror, e2), 200)
    end
end

# ============ 仪器 Widget(控制面板;Level 2 工具后端) ============
# Widget 与 GUI 设计器完全等效:整个面板就是 Assets/Widgets/<instrnm>.toml,
# 缺失字段取内置默认值(通用 Dict 构造器),写好文件后 loadinswconf() 热重载即生效。

widgetsfile(name::AbstractString) = joinpath(assetsdir(), "Widgets", sanename(name) * ".toml")

# uitype 合法清单(源:InstrWidget.jl optionsmenu 的 let 局部,此处镜像,改那边记得同步)
const WIDGET_UITYPES = Dict(
    "sweep" => ["read", "unit", "readunit", "inputstep", "inputstop", "dragdelay", "progressbar", "ctrlsweep"],
    "set" => ["read", "unit", "readunit", "inputset", "inputctrlset", "ctrlset", "combo", "radio", "slider", "vslider", "toggle"],
    "read" => ["read", "unit", "readunit", "readdashboard", "readdashboarddigits", "readdashboarddigitsunit"],
    "_Panel_" => ["none"],
    "_Shape_" => ["rect", "triangle", "circle", "line"],
    "_Image_" => ["none"],
    "_QuantitySelector_" => ["combo", "slider", "vslider"],
    "none" => ["none"],
)
const WIDGET_OPTIONTYPES = ["combo", "radio", "slider", "vslider", "toggle"]  # 需要量定义 optvalues
const WIDGET_SPECIALS = ["_Panel_", "_Shape_", "_Image_", "_QuantitySelector_"]

"""
    ai_widget_info(instrnm) -> String

Widget 构建的全部事实:量的注册信息(name/type/optvalues 数目与取值/numread/separator/help)、
允许的 uitype 清单、当前 widget 文件内容(若有)。
"""
function ai_widget_info(instrnm::AbstractString)
    buf = IOBuffer()
    insnm = String(instrnm)
    println(buf, "## Widget facts for \"", insnm, "\"")
    if haskey(qc.INSTRCONF, insnm)
        for (qtnm, qtc) in qc.INSTRCONF[insnm].quantities
            println(
                buf, "  quantity \"", qtnm, "\" [", qtc.type, "] numoptvs=", length(qtc.optvalues),
                " optvalues=", qtc.optvalues, " numread=", qtc.numread,
                qtc.separator == "" ? "" : " separator=\"$(qtc.separator)\"",
                qtc.help == "" ? "" : " help: " * qtc.help
            )
        end
    else
        println(buf, "  (instrument \"", insnm, "\" not registered)")
    end
    println(buf, "allowed uitypes: ", WIDGET_UITYPES)
    wf = widgetsfile(insnm)
    println(buf, "## Widget file ", wf, isfile(wf) ? ":" : ":\n(not created yet; a new file defines the panel from scratch)")
    isfile(wf) && println(buf, read(wf, String))
    return String(take!(buf))
end

"""
    ai_validate_widgettoml(text, instrnm) -> errmsg::String(空串 = 通过)

校验 AI 产出的 widget TOML:语法、真实构造器类型检查、量名存在性、qtype/uitype 兼容性、
numoptvs 匹配、特殊元素规则。
"""
function ai_validate_widgettoml(text::AbstractString, instrnm::AbstractString)
    conf = try
        TOML.parse(String(text))
    catch e
        return "TOML parse error: " * sprint(showerror, e)
    end
    isempty(conf) && return "no widget table defined"
    insnm = String(instrnm)
    haskey(qc.INSTRCONF, insnm) ||
        return "instrument \"$insnm\" is not registered; register it first (create_instrument)"
    quantities = qc.INSTRCONF[insnm].quantities
    for (wname, w) in conf
        w isa AbstractDict || return "[$wname] must be a table"
        # 真实构造器类型检查(与 loadinswconf 同通道;缺失字段取默认值)
        try
            qc.InstrWidget(Dict{String,Any}(w))
        catch e
            return "[$wname] failed to construct InstrWidget: " * first(sprint(showerror, e), 200)
        end
        get(w, "instrnm", insnm) == insnm || return "[$wname]: instrnm must be \"$insnm\""
        qtws = get(w, "qtws", nothing)
        qtws isa AbstractVector || (isempty(qtws) && return "[$wname]: no [[qtws]] entries defined")
        qtws isa AbstractVector || return "[$wname]: qtws must be an array of tables"
        for (i, qtw) in enumerate(qtws)
            qtw isa AbstractDict || return "[$wname] qtws#$i must be a table"
            qtn = string(get(qtw, "name", ""))
            opts = get(qtw, "options", Dict())
            opts isa AbstractDict || return "[$wname] qtws#$i: options must be a table"
            uitype = string(get(opts, "uitype", "none"))
            if qtn in WIDGET_SPECIALS
                allowed = get(WIDGET_UITYPES, qtn, ["none"])
                uitype in allowed ||
                    return "[$wname] qtws#$i (\"$qtn\"): uitype \"$uitype\" not allowed (use one of $allowed)"
                continue
            end
            haskey(quantities, qtn) || return "[$wname] qtws#$i: quantity \"$qtn\" does not exist on \"$insnm\""
            qtc = quantities[qtn]
            qtwqtype = string(get(qtw, "qtype", "none"))
            qtwqtype == qtc.type ||
                return "[$wname] qtws#$i (\"$qtn\"): qtype \"$qtwqtype\" but the quantity is [$(qtc.type)]"
            uitype in get(WIDGET_UITYPES, qtc.type, ["none"]) ||
                return "[$wname] qtws#$i (\"$qtn\"): uitype \"$uitype\" not allowed for [$(qtc.type)] quantities"
            (uitype in WIDGET_OPTIONTYPES && length(qtc.optvalues) == 0) &&
                return "[$wname] qtws#$i (\"$qtn\"): uitype \"$uitype\" needs optvalues on the quantity (define optkeys/optvalues in the instrument TOML first)"
            tryparse(Int, string(get(qtw, "numoptvs", 0))) == length(qtc.optvalues) ||
                return "[$wname] qtws#$i (\"$qtn\"): numoptvs must be $(length(qtc.optvalues)) (quantity has $(length(qtc.optvalues)) optvalues)"
        end
    end
    return ""
end

"写 widget 文件并热重载全部 widget 注册(与 GUI 设计器保存等效)"
function ai_create_widget(instrnm::AbstractString, tomltext::AbstractString)
    path = widgetsfile(instrnm)
    mkpath(dirname(path))
    open(path, "w") do io
        print(io, String(tomltext))
    end
    qc.loadinswconf()
    n = haskey(qc.INSWCONF, String(instrnm)) ? length(qc.INSWCONF[String(instrnm)]) : 0
    return "widget saved to $path and hot-reloaded; instrument \"$instrnm\" now has $n panel(s). Open it from the instrument's widget menu."
end

# ============ Assets 目录探查(只读;让 AI 自学一切可配置项) ============
# QInsControlAssets 是几乎所有配置的单一事实源:仪器注册(Confs)/面板(Widgets)/驱动(ExtraLoad)/
# 主题(Styles)/翻译(Languages)/全局设置(Necessity/conf.toml)等。路径校验防越界。

const ASSET_TEXT_EXTS = [".toml", ".jl", ".md", ".mdown", ".txt", ".ini", ".cmd", ".json", ".cfg"]

function assets_resolve(rel::AbstractString)
    root = normpath(abspath(assetsdir()))
    rel2 = strip(String(rel), ['/', Char(0x5c), ' '])
    p = rel2 == "" ? root : normpath(joinpath(root, rel2))
    #前缀比较必须带分隔符:裸 startswith(p, root) 可被同级目录绕过(root="…/Assets" 时
    # "..\Assets_private\x" 归一化后仍以 root 字符串开头)
    p == root || startswith(p, root * Base.Filesystem.path_separator) || return nothing   # 越界拒绝(../ 等)
    return p
end

function ai_list_assets(rel::AbstractString="")
    p = assets_resolve(rel)
    p === nothing && return "path escapes the assets directory"
    isdir(p) || return "not a directory: $rel (use read_asset for files)"
    buf = IOBuffer()
    println(buf, "Contents of ", p, ":")
    for e in sort(readdir(p; join=true))
        b = basename(e)
        startswith(b, ".") && continue
        isdir(e) ? println(buf, "  [dir]  ", b, "/") :
        println(buf, "  ", b, "  (", filesize(e), " bytes)")
    end
    return String(take!(buf))
end

function ai_read_asset(rel::AbstractString)
    p = assets_resolve(rel)
    p === nothing && return "path escapes the assets directory"
    isdir(p) && return "that is a directory; use list_assets on it"
    isfile(p) || return "file not found: $rel"
    ext = lowercase(splitext(p)[2])
    ext in ASSET_TEXT_EXTS ||
        return "only text files can be read (allowed: $(join(ASSET_TEXT_EXTS, ", "))); images/fonts/binaries are not"
    text = read(p, String)
    #内容级脱敏:任何文件里的 apikey 行一律打码(模型只需要看到供应商/模型等结构;内容会回喂
    #模型并写进会话存档,模型可经 fetch_url 把内容带出)。旧实现按路径匹配 ai.toml,
    #Windows 大小写不敏感的路径变体可绕过——不再依赖路径判断。
    #正则覆盖 apikey/api_key/APIKEY 等大小写与下划线变体、单双引号值及行尾注释;
    #旧正则只认精确的 apikey = "..." 形式,变体写法会漏脱敏
    occursin("apikey", lowercase(text)) &&
        (text = replace(text, r"(?im)^(\s*)api_?key[_a-z0-9]*\s*=\s*[^#\r\n]*" => s"\1apikey = \"***redacted***\""))
    length(text) > 20000 && (text = first(text, 20000) * "\n...[truncated at 20k chars]")
    return text
end

"从供应商 /models 端点拉取模型列表(OpenAI 协议 data[].id;Anthropic 协议同构)。
返回换行分隔的模型 id 列表;失败返回错误文本。
精确按名查找(getprovider 对未知名字会回退到第一个供应商,拉取动作绝不能打错目标)"
function ai_fetch_models(name::AbstractString)
    i = findfirst(p -> p.name == String(name), aiconf().providers)
    i === nothing && return "unknown provider \"$name\""
    p = aiconf().providers[i]
    url = rstrip(p.baseurl, '/') * "/models"
    headers = String(p.apitype) == "anthropic" ?
              ["x-api-key" => resolvekey(p), "anthropic-version" => "2023-06-01"] :
              ["Authorization" => "Bearer $(resolvekey(p))"]
    try
        resp = HTTP.get(url; headers, request_timeout = 15, retry = false, redirect = false)
        obj = JSON.parse(String(resp.body))
        data = get(obj, "data", nothing)
        data isa AbstractVector || return "unexpected response (no data array): " * first(String(resp.body), 120)
        ids = filter!(!isempty, String[isa(m, AbstractDict) ? String(get(m, "id", "")) : "" for m in data])
        sort!(ids)
        unique!(ids)
        isempty(ids) && return "provider returned no models"
        return join(ids, "\n")
    catch e
        return "fetch failed: " * first(sprint(showerror, e), 160)
    end
end

# ============ 网络工具防死循环:会话级计数上限 + URL 去重 ============
# 提示词只能"劝"模型别反复抓取;这里硬性拦——模型陷入检索循环时每轮都是真实网络开销,
# 上限在 sendchat! 开始时重置(每轮对话一个预算)。

const MAXNETCALLS = 12
const NETCALLS = Ref(0)              #本轮对话网络工具调用计数
const FETCHEDURLS = Set{String}()    #本轮已抓取过的 URL

resetnetbudget!() = (NETCALLS[] = 0; empty!(FETCHEDURLS); nothing)

"网络工具(web_search/fetch_url)入口:超预算直接拒绝,不再发真实请求"
function netbudget!()
    NETCALLS[] += 1
    NETCALLS[] > MAXNETCALLS &&
        return "web access budget for this conversation is exhausted ($MAXNETCALLS calls) - STOP calling web tools; continue with the information you already have or tell the user what extra documentation you need"
    return nothing
end
