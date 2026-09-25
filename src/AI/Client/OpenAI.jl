# OpenAI Chat Completions 兼容适配器(覆盖 DeepSeek/Kimi/GLM/Qwen/Ollama/LM Studio 等)

function openai_body(p::AIProvider, messages::Vector{ChatMessage}; tools)
    ms = Any[]
    for m in messages
        if m.role == "tool"
            push!(ms, Dict("role" => "tool", "content" => m.content, "tool_call_id" => m.toolcallid))
        elseif !isempty(m.toolcalls)
            push!(
                ms,
                Dict(
                    "role" => "assistant",
                    "content" => (isempty(m.content) ? nothing : m.content),
                    "tool_calls" => Any[
                        Dict(
                            "id" => tc["id"],
                            "type" => "function",
                            "function" => Dict("name" => tc["name"], "arguments" => tc["arguments"])
                        ) for tc in m.toolcalls
                    ]
                )
            )
        else
            push!(ms, Dict("role" => m.role, "content" => m.content))
        end
    end
    body = Dict{String,Any}(
        "model" => p.model,
        "messages" => ms,
        "temperature" => p.temperature,
        "stream" => p.stream
    )
    tools === nothing || (body["tools"] = tools)
    return JSON.json(body)
end

function openai_delta!(obj, content, reasoning, tcs, on_delta)
    haskey(obj, "error") && error(get(obj["error"], "message", "unknown provider error"))
    chs = get(obj, "choices", nothing)
    (chs isa Vector && !isempty(chs)) || return nothing
    ch = chs[1]
    delta = get(ch, "delta", nothing)
    if delta !== nothing
        c = get(delta, "content", nothing)
        c isa AbstractString && !isempty(c) && (push!(content, c); on_delta(:text, c))
        r = get(delta, "reasoning_content", nothing)
        r isa AbstractString && !isempty(r) && (push!(reasoning, r); on_delta(:reasoning, r))
        for tcd in get(delta, "tool_calls", Any[])
            idx = tcd["index"]
            tc = get!(tcs, idx) do
                Dict{String,Any}("id" => "", "name" => "", "args" => String[])
            end
            id = get(tcd, "id", "")
            isempty(id) || (tc["id"] = id)
            fn = get(tcd, "function", nothing)
            if fn !== nothing
                n = get(fn, "name", "")
                (n isa AbstractString && !isempty(n) && tc["name"] == "") && (tc["name"] = n)
                a = get(fn, "arguments", "")
                a isa AbstractString && !isempty(a) && push!(tc["args"], a)
            end
        end
    end
    return get(ch, "finish_reason", nothing)
end

function openai_chat!(
    on_delta::Function,
    p::AIProvider,
    messages::Vector{ChatMessage};
    tools=nothing,
    stop=() -> false,
    timeout=aiconf().timeout
)
    url = rstrip(p.baseurl, '/') * "/chat/completions"
    headers = ["Authorization" => "Bearer $(resolvekey(p))", "Content-Type" => "application/json"]
    body = openai_body(p, messages; tools)
    content, reasoning = String[], String[]
    tcs = Dict{Int,Dict{String,Any}}()
    status = Ref(:done)
    if p.stream
        sse_request(url, headers, body, timeout, stop, status) do payload
            payload == "[DONE]" && return
            try
                openai_delta!(JSON.parse(payload), content, reasoning, tcs, on_delta)
            catch e
                e isa ErrorException && rethrow()   # provider error 帧必须上抛
                # 其余单帧解析失败(罕见分帧切割)不致命,跳过
            end
        end
    else
        resp = HTTP.request("POST", url, headers, body; request_timeout=Float64(timeout), connect_timeout=15, retry=false)
        obj = JSON.parse(String(resp.body))
        haskey(obj, "error") && error(get(obj["error"], "message", "unknown provider error"))
        ch = get(get(obj, "choices", [Dict()]), 1, Dict())
        msg = get(ch, "message", Dict())
        c = get(msg, "content", nothing)
        c isa AbstractString && !isempty(c) && (push!(content, c); on_delta(:text, c))
        for tc in get(msg, "tool_calls", Any[])
            fn = get(tc, "function", Dict())
            tcs[length(tcs) + 1] = Dict(
                "id" => get(tc, "id", ""),
                "name" => get(fn, "name", ""),
                "args" => String[get(fn, "arguments", "")]
            )
        end
    end
    return ChatResult(status[], join(content), join(reasoning), normtoolcalls(tcs))
end
