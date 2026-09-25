# AI Client 冒烟测试(独立于 QInsControl 主模块,只需 HTTP/JSON):
#   julia --project=. test/ai_client_smoketest.jl
# 用本地 mock SSE 服务器验证:流式文本、工具调用增量拼装、中止、非流式回退、
# OpenAI/Anthropic 双协议的请求体归一化。
module AIClientTest

import HTTP
import JSON
using Dates: now

function catchlog(f::Function, msg::AbstractString)
    try
        f()
    catch e
        @error "[$(now())]\n$msg" exception = e
        rethrow()
    end
end

# —— 最小 Config 桩(替代 src/AI/Config.jl 中主模块相关部分) ——
mutable struct AIProvider
    name::String
    apitype::String
    baseurl::String
    model::String
    apikey::String
    temperature::Float64
    stream::Bool
end
AIProvider(; name="T", apitype="openai", baseurl="", model="m", apikey="", temperature=0.7, stream=true) =
    AIProvider(name, apitype, baseurl, model, apikey, temperature, stream)
const AICONF = Ref{NamedTuple}((timeout=10,))
aiconf() = AICONF[]
resolvekey(p::AIProvider) = p.apikey

include("../src/AI/Client/Client.jl")

using Test

@testset "openai_body 归一化" begin
    p = AIProvider(stream=false)
    msgs = ChatMessage[
        ChatMessage("system", "sys"),
        ChatMessage("user", "q"),
        ChatMessage("assistant", ""; toolcalls=[Dict("id" => "c1", "name" => "f", "arguments" => "{\"x\":1}")]),
        ChatMessage("tool", "res"; toolcallid="c1"),
    ]
    body = JSON.parse(openai_body(p, msgs; tools=nothing))
    @test body["messages"][1] == Dict("role" => "system", "content" => "sys")
    @test body["messages"][3]["tool_calls"][1]["function"]["name"] == "f"
    @test body["messages"][4] == Dict("role" => "tool", "content" => "res", "tool_call_id" => "c1")
end

@testset "anthropic_body 归一化" begin
    p = AIProvider(apitype="anthropic", stream=false)
    msgs = ChatMessage[
        ChatMessage("system", "sys"),
        ChatMessage("user", "q"),
        ChatMessage("assistant", ""; toolcalls=[Dict("id" => "c1", "name" => "f", "arguments" => "{\"x\":1}")]),
        ChatMessage("tool", "res"; toolcallid="c1"),
    ]
    body = JSON.parse(anthropic_body(p, msgs; tools=nothing))
    @test body["system"] == "sys"
    @test body["max_tokens"] > 0
    @test body["messages"][2]["content"][1]["type"] == "tool_use"
    @test body["messages"][2]["content"][1]["input"] == Dict("x" => 1)
    @test body["messages"][3]["content"][1]["type"] == "tool_result"
    @test body["messages"][3]["content"][1]["tool_use_id"] == "c1"
end

# —— mock OpenAI SSE 服务器:文本两帧 + 跨帧工具调用参数拼装 + [DONE] ——
sse(data::AbstractString) = string("data: ", data)
sseempty() = "data: [DONE]"
frame(obj) = sse(JSON.json(obj))

openai_sse = join(
    [
        frame(Dict("choices" => [Dict("delta" => Dict("content" => "Hel"))])),
        "",
        frame(Dict("choices" => [Dict("delta" => Dict("content" => "lo"))])),
        "",
        frame(Dict("choices" => [Dict("delta" => Dict("tool_calls" => [Dict("index" => 0, "id" => "call1", "function" => Dict("name" => "create_task", "arguments" => "{\"na"))]))])),
        "",
        frame(Dict("choices" => [Dict("delta" => Dict("tool_calls" => [Dict("index" => 0, "function" => Dict("arguments" => "me\": \"t\"}"))]))])),
        "",
        sseempty(),
        "",
    ],
    "\n"
)

anthropic_sse = join(
    [
        "event: content_block_start",
        frame(Dict("type" => "content_block_start", "index" => 0, "content_block" => Dict("type" => "text"))),
        "",
        frame(Dict("type" => "content_block_delta", "index" => 0, "delta" => Dict("type" => "text_delta", "text" => "Hi"))),
        "",
        frame(Dict("type" => "content_block_start", "index" => 1, "content_block" => Dict("type" => "tool_use", "id" => "tu1", "name" => "list_aliases"))),
        "",
        frame(Dict("type" => "content_block_delta", "index" => 1, "delta" => Dict("type" => "input_json_delta", "partial_json" => "{}"))),
        "",
        frame(Dict("type" => "message_stop")),
        "",
    ],
    "\n"
)

const STATE = Dict{String,String}()   # path -> 上次请求体(供断言)
server = HTTP.serve!("127.0.0.1", 18923) do req
    STATE[String(req.target)] = String(req.body)
    if startswith(String(req.target), "/v1/chat/completions")
        return HTTP.Response(200, ["Content-Type" => "text/event-stream"], body = openai_sse)
    elseif startswith(String(req.target), "/v1/messages")
        return HTTP.Response(200, ["Content-Type" => "text/event-stream"], body = anthropic_sse)
    elseif startswith(String(req.target), "/plain")
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            body = JSON.json(Dict("choices" => [Dict("message" => Dict(
                "content" => "ok",
                "tool_calls" => [Dict("id" => "c1", "function" => Dict("name" => "f", "arguments" => "{}"))]
            ))]))
        )
    end
    return HTTP.Response(404)
end

try
    @testset "openai 流式:文本 + 工具调用拼装" begin
        p = AIProvider(baseurl="http://127.0.0.1:18923/v1", model="test")
        chunks = String[]
        res = chat!((k, s) -> k == :text && push!(chunks, s), p, ChatMessage[ChatMessage("user", "hi")])
        @test res.status == :done
        @test res.content == "Hello"
        @test chunks == ["Hel", "lo"]
        @test length(res.toolcalls) == 1
        @test res.toolcalls[1]["id"] == "call1"
        @test res.toolcalls[1]["name"] == "create_task"
        @test JSON.parse(res.toolcalls[1]["arguments"]) == Dict("name" => "t")
    end

    @testset "openai 非流式回退" begin
        p = AIProvider(baseurl="http://127.0.0.1:18923/plain", model="test", stream=false)
        res = chat!((_, _) -> nothing, p, ChatMessage[ChatMessage("user", "hi")])
        @test res.status == :done
        @test res.content == "ok"
        @test res.toolcalls[1]["name"] == "f"
    end

    @testset "中止(stop)" begin
        p = AIProvider(baseurl="http://127.0.0.1:18923/v1", model="test")
        res = chat!((_, _) -> nothing, p, ChatMessage[ChatMessage("user", "hi")]; stop=() -> true)
        @test res.status == :aborted
    end

    @testset "anthropic 流式:文本 + tool_use" begin
        p = AIProvider(apitype="anthropic", baseurl="http://127.0.0.1:18923/v1", model="test")
        res = chat!((_, _) -> nothing, p, ChatMessage[ChatMessage("user", "hi")])
        @test res.status == :done
        @test res.content == "Hi"
        @test res.toolcalls[1]["id"] == "tu1"
        @test res.toolcalls[1]["name"] == "list_aliases"
        @test JSON.parse(res.toolcalls[1]["arguments"]) == Dict()
        body = JSON.parse(STATE["/v1/messages"])
        @test body["stream"] == true
        @test haskey(body, "max_tokens")
    end
finally
    close(server)
end

println("AI client smoke tests passed.")
end # module
