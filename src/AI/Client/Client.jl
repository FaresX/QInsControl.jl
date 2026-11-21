# 纯 LLM 客户端协议层:只依赖 HTTP/JSON 与 Config.jl 的 AIProvider,
# 对 QInsControl 其余部分零依赖——可整体抽出独立测试/独立打包。

"""
    ChatMessage(role, content=""; toolcalls=Any[], toolcallid="", reasoning="", images=())

与协议无关的对话消息。`toolcalls` 仅 assistant 消息携带,元素为
`Dict("id"=>..., "name"=>..., "arguments"=>JSON字符串)`,两种协议适配器统一成该格式;
`toolcallid` 仅 role=="tool" 时使用;`reasoning` 是推理模型思维链(仅供展示,不回传);
`images` 仅 user 消息携带,元素为 (mime, base64, name) 三元组——vision 模型的图片输入,
空 = 纯文本消息(两种适配器此时行为与从前完全一致)。
"""
mutable struct ChatMessage
    role::String
    content::String
    toolcalls::Vector{Any}
    toolcallid::String
    reasoning::String
    images::Vector{NTuple{3,String}}
end
ChatMessage(role::AbstractString, content::AbstractString="";
    toolcalls=Any[], toolcallid="", reasoning="", images=NTuple{3,String}[]) =
    ChatMessage(String(role), String(content), Any[tc for tc in toolcalls], String(toolcallid),
        String(reasoning), NTuple{3,String}[im for im in images])

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
外层带连接层瞬断自愈:请求尚未吐出任何增量时,EOF/连接重置/解压流错序自动换新连接重试一次
(已吐过增量则原样抛出——流中重试会造成文本重复)。
"""
function chat!(
    on_delta::Function,
    p::AIProvider,
    messages::Vector{ChatMessage};
    tools=nothing,
    stop=() -> false,
    timeout=aiconf().timeout
)
    streamed = Ref(false)
    wrapped = function (kind, s)
        streamed[] = true
        on_delta(kind, s)
    end
    try
        return String(p.apitype) == "anthropic" ?
               anthropic_chat!(wrapped, p, messages; tools, stop, timeout) :
               openai_chat!(wrapped, p, messages; tools, stop, timeout)
    catch e
        streamed[] && rethrow()
        istransientconn(e) || rethrow()
        @warn "[AI] connection dropped before any content arrived; retrying once on a fresh connection" exception = e
        return String(p.apitype) == "anthropic" ?
               anthropic_chat!(wrapped, p, messages; tools, stop, timeout) :
               openai_chat!(wrapped, p, messages; tools, stop, timeout)
    end
end

"连接层瞬断识别:TranscodingStreams 的 close→read 错序、EOF、IOError(连接重置)。
这类错误的原始信息对用户没有诊断价值,且换一条新连接即可恢复。"
function istransientconn(e)
    e isa EOFError && return true
    e isa Base.IOError && return true
    if e isa ArgumentError
        msg = sprint(showerror, e)
        occursin("change the mode from close", msg) && return true
        (occursin("stream", lowercase(msg)) && occursin("closed", lowercase(msg))) && return true
    end
    return false
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

"把 provider.extra 的 JSON 对象合并进请求 body 顶层(用户键覆盖默认);非法 JSON 告警后忽略。
用于各供应商自有参数(GLM thinking / Qwen enable_thinking 等)的兜底。"
function mergeextra!(body::Dict{String,Any}, extra::AbstractString)
    isempty(strip(extra)) && return body
    obj = try
        JSON.parse(String(extra))
    catch
        @warn "[AI] provider extra body is not valid JSON - ignored" extra = first(String(extra), 120)
        return body
    end
    obj isa AbstractDict || (@warn "[AI] provider extra body must be a JSON object - ignored"; return body)
    for (k, v) in obj
        body[String(k)] = v
    end
    return body
end

"从供应商错误里提取可读信息:StatusError 带完整 response body(通常是 JSON 的 error.message),
裸 showerror 只有状态码,用户无法区分欠费/模型名错/上下文超限;报错文本不得包含请求头(密钥)"
function friendlyaierror(e)
    e isa HTTP.StatusError || return sprint(showerror, e)
    base = "provider returned HTTP $(e.status)"
    raw = try
        String(e.response.body)
    catch
        ""
    end
    isempty(strip(raw)) && return base
    msg = try
        obj = JSON.parse(raw)
        obj isa AbstractDict || return ""
        err = get(obj, "error", nothing)
        err isa AbstractDict ? string(get(err, "message", "")) :
        string(get(obj, "message", get(obj, "detail", "")))
    catch
        ""
    end
    isempty(strip(msg)) || return string(base, ": ", first(strip(msg), 400))
    return string(base, ": ", first(strip(raw), 300))
end

function sse_request(f::Function, url, headers, body, timeout, stop, status)
    err = Ref{Any}(nothing)
    #请求放在子任务里跑:阻塞读期间无法轮询 stop(思考型模型长时间不出首帧),
    #收到停止就关底层 socket 掐断阻塞读,流结束/已掐断时再关一次也无害。
    #不能用 schedule(InterruptException) 强断:轮询判定与任务结束存在竞态,若任务恰已进入
    #收尾钩子(task_done_hook),异常会投递进无人处理的位置,Julia 以 "no exception handler"
    #直接强退整个进程(实测:停止时机撞上流自然结束即触发)
    sock = Ref{Any}(nothing)
    t = errormonitor(Threads.@spawn begin
        try
            HTTP.open("POST", url, headers; request_timeout=Float64(timeout), connect_timeout=15, retry=false) do io
                sock[] = io #存 Stream 本身:close(io)(Base.close,HTTP≥2 已扩展)会丢弃未读并关闭连接,掐断阻塞读
                write(io, Vector{UInt8}(body))
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
        catch e
            status[] == :aborted || (err[] = e)
        end
    end)
    while !istaskdone(t)
        if stop() && status[] != :aborted
            status[] = :aborted
            s = sock[]
            s === nothing || try
                close(s)
            catch
            end
        end
        istaskdone(t) || sleep(0.05)
    end
    err[] === nothing || throw(err[]) #不能用 rethrow:此处不在 catch 作用域,1.12 会抛 "rethrow not allowed" 掩盖真错误
    return nothing
end

include("OpenAI.jl")
include("Anthropic.jl")
