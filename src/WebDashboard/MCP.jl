# ============ MCP (Model Context Protocol) Streamable HTTP 端点 ============
# 让外部 agent 软件(Claude Code / Cursor 等)操控 QInsControl:
#   - 工具与内置 AI 助手完全同源(同一 AITOOLS 注册表 + Bridge 边界):
#     外部 agent 调用写工具时,桌面端照样弹确认模态,总开关 confirmwrites 同样生效
#   - 无状态 Streamable HTTP:POST /mcp 收 JSON-RPC,回 application/json;
#     不提供 SSE 会话流(GET 返回 405),不派发 session id(每请求独立处理)
#   - 安全面:跟随 AI 总开关(aiconf().enable=false 时 403) + CONF.WebDashboard.mcp;
#     服务器本身只绑定 127.0.0.1(startwebdashboard! 的 bind 参数)
# 外部 agent 与内置 AI 的仪器操作可能并发交叉:tools/call 用 MCPCALL 锁串行化,
# 但与内置 AI 会话之间仍无互斥——同一仪器别同时让两边操作。

const MCP_PROTOCOL_VERSION = "2024-11-05"
const MCP_SERVER = Ref{Any}(nothing)
const MCP_PORT = Ref{Int}(-1)

function startmcp!(; port = Cint(CONF.Basic.mcpport), bind = "127.0.0.1")
    MCP_SERVER[] !== nothing && MCP_PORT[] == Int(port) && return   #已在目标端口运行
    MCP_SERVER[] !== nothing && stopmcp!()                          #端口变化:热重启
    MCP_SERVER[] = HTTP.serve!(mcp_handle, bind, Int(port))
    MCP_PORT[] = Int(port)
    return
end

stopmcp!() = begin
    MCP_SERVER[] === nothing || close(MCP_SERVER[])
    MCP_SERVER[] = nothing
    MCP_PORT[] = -1
    return
end

"配置与服务器状态对齐(主程序启动与 Preferences 开关/端口变化都走这里)"
syncmcp!() = CONF.Basic.mcp ? startmcp!() : stopmcp!()
const AI = QInsControlAI   #主模块内的子模块限定名(AITOOLS/calltool/snapshot/aiconf 未 export)
const MCPCALL = ReentrantLock()   #MCP tools/call 串行化(多客户端并发不互相交叉)

mcp_result(id, result::AbstractDict) =
    HTTP.Response(200, ["Content-Type" => "application/json"], body = JSON.json(
        Dict("jsonrpc" => "2.0", "id" => id, "result" => result)))
mcp_error(id, code, message) =
    HTTP.Response(200, ["Content-Type" => "application/json"], body = JSON.json(Dict(
        "jsonrpc" => "2.0", "id" => id,
        "error" => Dict("code" => code, "message" => message))))

"AITOOLS → MCP 工具描述(inputSchema)"
mcp_tool_schema(t) = Dict(
    "name" => t.name,
    "description" => t.description,
    "inputSchema" => Dict(
        "type" => "object",
        "properties" => Dict(pt[1] => Dict("type" => pt[2], "description" => pt[3]) for pt in t.props),
        "required" => collect(String, t.required),
    ),
)

"处理一条 MCP JSON-RPC 消息;notification(无 id)返回 nothing(调用方回 202)"
function mcp_message(msg::AbstractDict)
    method = String(get(msg, "method", ""))
    haskey(msg, "id") || return nothing
    id = msg["id"]
    if method == "initialize"
        return mcp_result(id, Dict(
            "protocolVersion" => MCP_PROTOCOL_VERSION,
            "capabilities" => Dict("tools" => Dict(), "resources" => Dict()),
            "serverInfo" => Dict("name" => "QInsControl", "version" => "1.0"),
        ))
    elseif method == "notifications/initialized" || startswith(method, "notifications/")
        return nothing
    elseif method == "ping"
        return mcp_result(id, Dict())
    elseif method == "tools/list"
        return mcp_result(id, Dict("tools" => [mcp_tool_schema(t) for t in AI.AITOOLS]))
    elseif method == "tools/call"
        params = get(msg, "params", Dict())
        name = String(get(params, "name", ""))
        arguments = AI.normalizejson(get(params, "arguments", Dict{String,Any}()))
        result = lock(MCPCALL) do
            AI.calltool(name, JSON.json(arguments); allowwrite = true)
        end
        return mcp_result(id, Dict(
            "content" => [Dict("type" => "text", "text" => String(result))],
            "isError" => occursin("FAILED", uppercase(result)) ||
                         occursin("user declined", result),
        ))
    elseif method == "resources/list"
        return mcp_result(id, Dict("resources" => [Dict(
            "uri" => "qinscontrol://snapshot",
            "name" => "Experiment snapshot",
            "description" => "Current bench state: aliases, usable instruments, registered quantities, data keys, tasks",
            "mimeType" => "text/plain",
        )]))
    elseif method == "resources/read"
        uri = String(get(get(msg, "params", Dict()), "uri", ""))
        startswith(uri, "qinscontrol://snapshot") ||
            return mcp_error(id, -32602, "unknown resource: $uri")
        return mcp_result(id, Dict("contents" => [Dict(
            "uri" => "qinscontrol://snapshot",
            "mimeType" => "text/plain",
            "text" => AI.snapshot(),
        )]))
    else
        return mcp_error(id, -32601, "method not found: $method")
    end
end

function mcp_handle(req::HTTP.Request)
    AI.aiconf().enable || return HTTP.Response(403, body = "MCP disabled: AI is disabled in settings")
    CONF.Basic.mcp || return HTTP.Response(403, body = "MCP disabled in basic settings")
    req.method == "POST" || return HTTP.Response(405, body = "use POST with a JSON-RPC message (SSE stream not provided)")
    msg = try
        JSON.parse(String(req.body))
    catch
        return mcp_error(nothing, -32700, "parse error")
    end
    msg isa AbstractDict || return mcp_error(nothing, -32600, "invalid request")
    #兜底 -32603:calltool 已自捕获异常,这层防的是 snapshot/注册表遍历等周边路径抛错
    #——没有它 HTTP.jl 会直接掐断连接,客户端只看到网络错误而非 JSON-RPC 错误对象
    resp = try
        mcp_message(msg)
    catch e
        id = get(msg, "id", nothing)
        id === nothing && return HTTP.Response(202)
        mcp_error(id, -32603, "internal error: " * first(sprint(showerror, e), 200))
    end
    return resp === nothing ? HTTP.Response(202) : resp
end
