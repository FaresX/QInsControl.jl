# 纯 LLM 客户端协议层:只依赖 HTTP/JSON 与 Config.jl 的 AIProvider,
# 对 QInsControl 其余部分零依赖——可整体抽出独立测试/独立打包。

"""
    ChatMessage(role, content=""; toolcalls=Any[], toolcallid="", reasoning="")

与协议无关的对话消息。`toolcalls` 仅 assistant 消息携带,元素为
`Dict("id"=>..., "name"=>..., "arguments"=>JSON字符串)`,两种协议适配器统一成该格式;
`toolcallid` 仅 role=="tool" 时使用;`reasoning` 是推理模型思维链(仅供展示,不回传)。
"""
mutable struct ChatMessage
    role::String
    content::String
    toolcalls::Vector{Any}
    toolcallid::String
    reasoning::String
end
ChatMessage(role::AbstractString, content::AbstractString=""; toolcalls=Any[], toolcallid="", reasoning="") =
    ChatMessage(String(role), String(content), Any[tc for tc in toolcalls], String(toolcallid), String(reasoning))

"chat! 的返回:status ∈ :done | :aborted | :error"
struct ChatResult
    status::Symbol
    content::String
    reasoning::String
    toolcalls::Vector{Any}
end

"""
    chat!(on_delta, provider, messages; tools=nothing, stop=()->false, timeout=aiconf().timeout)

按 provider.apitype 分派到 openai/anthropic 适配器。`on_delta(kind, text)` 接收
`(:text|"reasoning", 增量)` 流式回调;`stop()` 在 SSE 帧之间轮询,返回 true 即中止。
`tools` 使用 OpenAI function-calling 格式(anthropic 适配器内部自行转换)。
"""
function chat!(
    on_delta::Function,
    p::AIProvider,
    messages::Vector{ChatMessage};
    tools=nothing,
    stop=() -> false,
    timeout=aiconf().timeout
)
    return String(p.apitype) == "anthropic" ?
           anthropic_chat!(on_delta, p, messages; tools, stop, timeout) :
           openai_chat!(on_delta, p, messages; tools, stop, timeout)
end

# —— 工具 schema(OpenAI 格式为准,anthropic 适配器转换) ——
function toolsschemas(tools::Vector)
    return Any[
        Dict(
            "type" => "function",
            "function" => Dict(
                "name" => t.name,
                "description" => t.description,
                "parameters" => Dict(
                    "type" => "object",
                    "properties" => Dict(p[1] => Dict("type" => p[2], "description" => p[3]) for p in t.props),
                    "required" => collect(String, t.required)
                )
            )
        ) for t in tools
    ]
end

# —— 共用小工具 ——
normtoolcalls(tcs::Dict{Int,Dict{String,Any}}) = Any[
    Dict(
        "id" => tc["id"] == "" ? "call_$i" : tc["id"],
        "name" => tc["name"],
        "arguments" => join(tc["args"])
    ) for (i, (_, tc)) in enumerate(sort(collect(tcs); by=first))
]

sse_request(f::Function, url, headers, body, timeout, stop, status) =
    HTTP.open("POST", url, headers; request_timeout=Float64(timeout), connect_timeout=15, retry=false) do io
        write(io, Vector{UInt8}(body))   # HTTP 2.x:请求体经流写入
        dataline = ""
        for line in eachline(io)
            stop() && (status[] = :aborted; return)
            line = rstrip(line, '\r')
            if startswith(line, "data:")
                dataline *= String(line[6:end])
            elseif line == "" && dataline != ""
                payload = String(strip(dataline))
                dataline = ""
                f(payload)
            end
        end
        dataline == "" || f(String(strip(dataline)))
    end

include("OpenAI.jl")
include("Anthropic.jl")
