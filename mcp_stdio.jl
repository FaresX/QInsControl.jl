# QInsControl MCP stdio 桥：把 stdio JSON-RPC（MCP 标准传输）转发到
# 运行中的 QInsControl 的 Streamable HTTP 端点 http://127.0.0.1:<port>/mcp。
#
# 前置：QInsControl 已启动，且 设置 → Web Dashboard 已启用（enable + MCP 默认开）。
# 注册到 Claude Code 等外部 agent（示例）：
#   claude mcp add qinscontrol -- julia --project=<QInsControl 项目路径> <项目路径>/mcp_stdio.jl 8088
# 或 Cursor 的 MCP 配置里填同样的 command/args。
#
# 说明：写仪器/改工程的工具会触发桌面端的确认模态——人确认后才执行。

using HTTP
import JSON

const PORT = isempty(ARGS) ? "8088" : String(ARGS[1])
const BASE = "http://127.0.0.1:$PORT/mcp"

"转发一条 JSON-RPC 请求到主程序，返回响应字符串；失败返回 MCP 错误对象"
function forward(msg::AbstractDict)
    r = HTTP.post(BASE, [
        "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream",
    ], JSON.json(msg); retry = false, request_timeout = 180.0)
    body = String(r.body)
    #兼容后端以 SSE 帧返回的情况（当前实现返回纯 JSON，此处仅为稳健性）
    if (m = match(r"data: (.*)", body)) !== nothing
        body = m[1]
    end
    return body
end

for line in eachline(stdin)
    isempty(strip(line)) && continue
    msg = try
        JSON.parse(line)
    catch
        continue   #非 JSON 行忽略
    end
    msg isa AbstractDict || continue
    haskey(msg, "id") || continue   #notification：桥不转发（对端无响应语义）
    out = try
        forward(msg)
    catch e
        JSON.json(Dict(
            "jsonrpc" => "2.0", "id" => get(msg, "id", nothing),
            "error" => Dict("code" => -32000, "message" => "QInsControl bridge: " * sprint(showerror, e)
                * "  — is QInsControl running with the web dashboard enabled?")
        ))
    end
    println(out)
    flush(stdout)
end
