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
    think::String
    extra::String
end
AIProvider(; name="T", apitype="openai", baseurl="", model="m", apikey="", temperature=0.7, stream=true, think="", extra="") =
    AIProvider(name, apitype, baseurl, model, apikey, temperature, stream, think, extra)
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

# 思考挡位:openai 系协议 reasoning_effort(StepFun step_plan/OpenAI o 系列);
# anthropic 协议 thinking 预算(必须 < max_tokens 且 temperature 强制 1);extra JSON 兜底合并
@testset "思考挡位与 extra body" begin
    p = AIProvider(stream = false, think = "high", extra = "{\"thinking\":{\"type\":\"enabled\"}}")
    body = JSON.parse(openai_body(p, ChatMessage[ChatMessage("user", "q")]; tools = nothing))
    @test body["reasoning_effort"] == "high"
    @test body["thinking"] == Dict("type" => "enabled")   #extra 合并进顶层
    @test body["temperature"] == 0.7                      #默认键保留
    p0 = AIProvider(stream = false)
    body0 = JSON.parse(openai_body(p0, ChatMessage[ChatMessage("user", "q")]; tools = nothing))
    @test !haskey(body0, "reasoning_effort")              #空挡位不发送
    pa = AIProvider(apitype = "anthropic", stream = false, think = "low", temperature = 0.3)
    bodya = JSON.parse(anthropic_body(pa, ChatMessage[ChatMessage("user", "q")]; tools = nothing))
    @test bodya["thinking"] == Dict("type" => "enabled", "budget_tokens" => 4096)
    @test bodya["max_tokens"] >= 4096 + 8192              #预算必须 < max_tokens
    @test bodya["temperature"] == 1.0                     #anthropic 硬性要求
    pbad = AIProvider(stream = false, extra = "not json")
    bodyb = JSON.parse(openai_body(pbad, ChatMessage[ChatMessage("user", "q")]; tools = nothing))
    @test !haskey(bodyb, "thinking")                      #非法 extra 告警忽略,不炸
end

# 回归:```tool 文本回退会产生"无前导 tool_calls 的 tool 消息"——严格校验的供应商
# (OpenAI/Anthropic 官方、DeepSeek 等)直接 400,且该消息永久留在历史里卡死会话
@testset "孤儿 tool 消息降级 (openai)" begin
    p = AIProvider(stream=false)
    msgs = ChatMessage[
        ChatMessage("system", "sys"),
        ChatMessage("user", "q"),
        ChatMessage("assistant", "```tool\n{\"tool\":\"list_aliases\"}\n```"),
        ChatMessage("tool", "res1"; toolcallid="fallback"),
    ]
    body = JSON.parse(openai_body(p, msgs; tools=nothing))
    @test !any(m["role"] == "tool" for m in body["messages"])
    @test body["messages"][end]["role"] == "user"
    @test occursin("[tool result (fallback)]", body["messages"][end]["content"])
    #混合场景:合法配对保留 tool 角色,新 user 轮之后的迟到结果降级
    msgs2 = ChatMessage[
        ChatMessage("system", "sys"),
        ChatMessage("user", "q"),
        ChatMessage("assistant", ""; toolcalls=[Dict("id" => "c1", "name" => "f", "arguments" => "{}")]),
        ChatMessage("tool", "ok"; toolcallid="c1"),
        ChatMessage("assistant", ""; toolcalls=[Dict("id" => "c2", "name" => "g", "arguments" => "{}")]),
        ChatMessage("tool", "ok2"; toolcallid="c2"),
        ChatMessage("user", "next"),
        ChatMessage("tool", "late"; toolcallid="c9"),
    ]
    body2 = JSON.parse(openai_body(p, msgs2; tools=nothing))
    tools = filter(m -> m["role"] == "tool", body2["messages"])
    @test [t["tool_call_id"] for t in tools] == ["c1", "c2"]
    @test body2["messages"][end]["role"] == "user" && occursin("[tool result (c9)]", body2["messages"][end]["content"])
end

@testset "孤儿 tool 消息降级 (anthropic)" begin
    p = AIProvider(apitype="anthropic", stream=false)
    msgs = ChatMessage[
        ChatMessage("system", "sys"),
        ChatMessage("user", "q"),
        ChatMessage("assistant", "```tool\n{\"tool\":\"list_aliases\"}\n```"),
        ChatMessage("tool", "res1"; toolcallid="fallback"),
    ]
    body = JSON.parse(anthropic_body(p, msgs; tools=nothing))
    last = body["messages"][end]
    @test last["role"] == "user"
    @test all(b["type"] == "text" for b in last["content"])   #没有无配对的 tool_result
    @test any(occursin("[tool result (fallback)]", b["text"]) for b in last["content"])
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
    elseif startswith(String(req.target), "/redir")
        return HTTP.Response(302, ["Location" => "http://127.0.0.1:18923/secret"], body = "")
    elseif startswith(String(req.target), "/secret")
        return HTTP.Response(200, body = "SECRET-PAGE")
    elseif startswith(String(req.target), "/err401")
        return HTTP.Response(
            401,
            ["Content-Type" => "application/json"],
            body = JSON.json(Dict("error" => Dict("message" => "Invalid API key provided", "type" => "invalid_request_error")))
        )
    elseif startswith(String(req.target), "/errplain")
        return HTTP.Response(500, body = "upstream exploded")
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

    #回归:fetch_url 的 SSRF 检查只做在初始 host 上——必须禁止跟随重定向,否则 302 跳内网即绕过
    @testset "重定向不跟随 (redirect=false)" begin
        r = HTTP.get("http://127.0.0.1:18923/redir"; redirect=false, retry=false, request_timeout=5)
        @test r.status == 302
        r2 = HTTP.get("http://127.0.0.1:18923/redir"; retry=false, request_timeout=5)   #对照:默认仍跟随
        @test r2.status == 200 && String(r2.body) == "SECRET-PAGE"
    end

    #回归:裸 showerror 只有状态码,供应商的错误正文(欠费/模型名错/上下文超限)被丢弃
    @testset "friendlyaierror 提取供应商错误正文" begin
        err = try
            HTTP.get(
                "http://127.0.0.1:18923/err401", ["Authorization" => "Bearer sk-TESTSECRET"];
                retry=false, request_timeout=5
            )
            nothing
        catch e
            e
        end
        @test err isa HTTP.StatusError
        txt = friendlyaierror(err)
        @test occursin("401", txt) && occursin("Invalid API key provided", txt)
        @test !occursin("sk-TESTSECRET", txt)   #报错文本不含请求头(密钥不泄漏)
        err2 = try
            HTTP.get("http://127.0.0.1:18923/errplain"; retry=false, request_timeout=5)
            nothing
        catch e
            e
        end
        txt2 = friendlyaierror(err2)
        @test occursin("500", txt2) && occursin("upstream exploded", txt2)
        @test friendlyaierror(ErrorException("boom")) == "boom"   #非 HTTP 错误原样透传
    end

    #回归:连接层瞬断识别(DeepSeek 真实使用中 TranscodingStreams 的 close→read 错序
    #把根因掩盖成裸 ArgumentError;chat! 外层据此在未吐增量时换新连接重试一次)
    @testset "瞬断识别 istransientconn" begin
        @test istransientconn(ArgumentError("cannot change the mode from close to read"))
        @test istransientconn(EOFError())
        @test istransientconn(Base.IOError("connection reset", -4077))
        @test !istransientconn(ArgumentError("cannot change the mode from read to write"))
        @test !istransientconn(ArgumentError("some other argument problem"))
        @test !istransientconn(ErrorException("boom"))
    end
finally
    close(server)
end

println("AI client smoke tests passed.")
end # module
