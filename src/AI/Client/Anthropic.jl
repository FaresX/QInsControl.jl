# Anthropic Messages API 适配器(system 为顶层字段;工具以 tool_use/tool_result 块传输)

const ANTHROPIC_VERSION = "2023-06-01"
const ANTHROPIC_MAXTOKENS = 8192

function anthropic_body(p::AIProvider, messages::Vector{ChatMessage}; tools)
    sys = join([m.content for m in messages if m.role == "system"], "\n\n")
    ms = Any[]
    pendingtool = Any[]
    liveids = Set{String}()   #前一条 assistant 声明的 tool_use id:孤儿 tool 消息(```tool
    flushtool() = begin       #文本回退会产生)降级为文本块,否则 tool_result 无配对直接 400
        isempty(pendingtool) || (push!(ms, Dict("role" => "user", "content" => pendingtool)); pendingtool = Any[])
    end
    for m in messages
        m.role == "system" && continue
        if m.role == "tool"
            if String(m.toolcallid) in liveids
                push!(
                    pendingtool,
                    Dict("type" => "tool_result", "tool_use_id" => m.toolcallid, "content" => m.content)
                )
            else
                push!(
                    pendingtool,
                    Dict("type" => "text", "text" => string("[tool result (", m.toolcallid, ")]\n", m.content))
                )
            end
            continue
        end
        flushtool()
        empty!(liveids)
        !isempty(m.toolcalls) && foreach(tc -> push!(liveids, String(get(tc, "id", ""))), m.toolcalls)
        if !isempty(m.toolcalls)
            blocks = Any[]
            isempty(m.content) || push!(blocks, Dict("type" => "text", "text" => m.content))
            for tc in m.toolcalls
                input = try
                    JSON.parse(tc["arguments"] == "" ? "{}" : tc["arguments"])
                catch
                    Dict{String,Any}()
                end
                push!(blocks, Dict("type" => "tool_use", "id" => tc["id"], "name" => tc["name"], "input" => input))
            end
            push!(ms, Dict("role" => "assistant", "content" => blocks))
        elseif m.role == "user" && !isempty(m.images)
            #vision 输入:text + base64 image 块(image/jpg 归一为 image/jpeg)
            blocks = Any[Dict("type" => "text", "text" => m.content)]
            for (mime, b64, _) in m.images
                mt = mime == "image/jpg" ? "image/jpeg" : mime
                push!(blocks, Dict("type" => "image", "source" => Dict("type" => "base64", "media_type" => mt, "data" => b64)))
            end
            push!(ms, Dict("role" => "user", "content" => blocks))
        else
            push!(ms, Dict("role" => m.role, "content" => m.content))
        end
    end
    flushtool()
    body = Dict{String,Any}(
        "model" => p.model,
        "max_tokens" => ANTHROPIC_MAXTOKENS,
        "messages" => ms,
        "temperature" => min(p.temperature, 1.0),
        "stream" => p.stream
    )
    #思考挡位(anthropic 官方协议):enabled + 预算 token;预算必须 < max_tokens,故同步抬高
    #max_tokens,且 anthropic 硬性要求 thinking 启用时 temperature == 1
    if p.think in ("low", "medium", "high")
        budget = p.think == "low" ? 4096 : p.think == "medium" ? 10240 : 24576
        body["thinking"] = Dict("type" => "enabled", "budget_tokens" => budget)
        body["max_tokens"] = max(ANTHROPIC_MAXTOKENS, budget + 8192)
        body["temperature"] = 1.0
    end
    mergeextra!(body, p.extra)
    sys == "" || (body["system"] = sys)
    if tools !== nothing
        body["tools"] = Any[
            Dict(
                "name" => t["function"]["name"],
                "description" => t["function"]["description"],
                "input_schema" => t["function"]["parameters"]
            ) for t in tools
        ]
    end
    return JSON.json(body)
end

function anthropic_delta!(obj, content, reasoning, tcs, on_delta, status)
    t = get(obj, "type", "")
    if t == "content_block_start"
        cb = get(obj, "content_block", Dict())
        get(cb, "type", "") == "tool_use" &&
            (tcs[get(obj, "index", 0)] = Dict{String,Any}("id" => get(cb, "id", ""), "name" => get(cb, "name", ""), "args" => String[]))
    elseif t == "content_block_delta"
        d = get(obj, "delta", Dict())
        dt = get(d, "type", "")
        if dt == "text_delta"
            s = get(d, "text", "")
            s isa AbstractString && !isempty(s) && (push!(content, s); on_delta(:text, s))
        elseif dt == "thinking_delta"
            s = get(d, "thinking", "")
            s isa AbstractString && !isempty(s) && (push!(reasoning, s); on_delta(:reasoning, s))
        elseif dt == "input_json_delta"
            tc = get(tcs, get(obj, "index", -1), nothing)
            tc === nothing || (s = get(d, "partial_json", ""); s isa AbstractString && !isempty(s) && push!(tc["args"], s))
        end
    elseif t == "error"
        status[] = :error
        error(get(get(obj, "error", Dict()), "message", "anthropic provider error"))
    end
    return nothing
end

function anthropic_chat!(
    on_delta::Function,
    p::AIProvider,
    messages::Vector{ChatMessage};
    tools=nothing,
    stop=() -> false,
    timeout=aiconf().timeout
)
    url = rstrip(p.baseurl, '/') * "/messages"
    headers = [
        "x-api-key" => resolvekey(p),
        "anthropic-version" => ANTHROPIC_VERSION,
        "Content-Type" => "application/json"
    ]
    body = anthropic_body(p, messages; tools)
    content, reasoning = String[], String[]
    tcs = Dict{Int,Dict{String,Any}}()
    status = Ref(:done)
    if p.stream
        sse_request(url, headers, body, timeout, stop, status) do payload
            try
                anthropic_delta!(JSON.parse(payload), content, reasoning, tcs, on_delta, status)
            catch e
                e isa ErrorException && rethrow()
            end
        end
    else
        resp = HTTP.request("POST", url, headers, body; request_timeout=Float64(timeout), connect_timeout=15, retry=false)
        obj = JSON.parse(String(resp.body))
        haskey(obj, "error") && error(get(obj["error"], "message", "unknown provider error"))
        for (i, blk) in enumerate(get(obj, "content", Any[]))
            bt = get(blk, "type", "")
            if bt == "text"
                s = get(blk, "text", "")
                s isa AbstractString && !isempty(s) && (push!(content, s); on_delta(:text, s))
            elseif bt == "thinking"
                s = get(blk, "thinking", "")
                s isa AbstractString && push!(reasoning, s)
            elseif bt == "tool_use"
                tcs[i] = Dict{String,Any}(
                    "id" => get(blk, "id", ""),
                    "name" => get(blk, "name", ""),
                    "args" => String[JSON.json(get(blk, "input", Dict()))]
                )
            end
        end
    end
    return ChatResult(status[], join(content), join(reasoning), normtoolcalls(tcs))
end
