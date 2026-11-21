# AI 子模块加载态集成冒烟(不启动 GUI、不做真实网络请求):
#   julia --project=. test/ai_integration_smoke.jl
# 验证:initialize_ai! 写出 ai.toml、Bridge 只读适配函数、脚本校验通道、系统提示词构建。
assets = abspath(joinpath(@__DIR__, "..", "..", "QInsControlAssets"))  # 与 precompile.jl 一致的开发资产目录
_prev_qic_assets = get(ENV, "QInsControlAssets", nothing)  # 文件末尾恢复:后续 ITE 电池要用真实资产启动应用
if isdir(assets)
    mkpath(joinpath(assets, "Necessity"))  # 资产目录存在但 Necessity 缺失时,saveconf_ai 也能落盘
else
    assets = mktempdir()
    mkpath(joinpath(assets, "Necessity"))
end
ENV["QInsControlAssets"] = assets
using Distributed
import JSON
using QInsControl
const AI = QInsControl.QInsControlAI

QInsControl.initialize_ai!()
@assert isfile(AI.aiconfpath()) "ai.toml not written"
println("[ok] ai.toml written to ", AI.aiconfpath())
println("[ok] providers: ", [p.name for p in AI.aiconf().providers])
println("[ok] resolvekey env-indirect: '", AI.resolvekey(AI.AIProvider(apikey="env:SOME_MISSING_VAR")), "'")

# 回归:落盘密钥不得为明文(env:/dpapi:/空)
for line in eachline(AI.aiconfpath())
    if startswith(line, "apikey")
        occursin(r"apikey\s*=\s*\"(env:|dpapi:)?[^\"]*\"", line) || error("plaintext apikey stored in ai.toml!")
    end
end
println("[ok] ai.toml apikey lines are all env:/dpapi:/empty")
if Sys.iswindows()
    AI.dpapi_decrypt(AI.dpapi_encrypt("QIC-TEST-KEY")) == "QIC-TEST-KEY" || error("DPAPI roundtrip failed")
    println("[ok] DPAPI roundtrip")
    #save 路径加密:临时明文 provider 存盘必须变成 dpapi: 且 resolvekey 能解回
    push!(AI.aiconf().providers, AI.AIProvider(name = "DPAPITest", apikey = "sk-DPAPI-SELFTEST"))
    AI.saveconf_ai()
    txt = read(AI.aiconfpath(), String)
    occursin("sk-DPAPI-SELFTEST", txt) && error("DPAPI encryption did not apply on save!")
    p = AI.getprovider("DPAPITest")
    AI.resolvekey(p) == "sk-DPAPI-SELFTEST" || error("DPAPI resolvekey roundtrip failed")
    deleteat!(AI.aiconf().providers, findlast(p -> p.name == "DPAPITest", AI.aiconf().providers))
    AI.saveconf_ai()
    println("[ok] DPAPI save-encryption + resolvekey roundtrip")
end

# 回归:read_asset 内容级 apikey 脱敏(任何路径,含 Windows 大小写变体)
tmpd = joinpath(ENV["QInsControlAssets"], "tmpredact")
mkpath(tmpd)
write(joinpath(tmpd, "t.toml"), "enable = true\napikey = \"sk-LEAKTEST-123\"\n")
r1 = AI.ai_read_asset("tmpredact/t.toml")
r2 = AI.ai_read_asset("TMPREDACT/T.TOML")
occursin("sk-LEAKTEST-123", r1 * r2) && error("apikey redaction bypassed!")
occursin("***redacted***", r1) || error("apikey redaction missing")
rm(tmpd; recursive = true)
println("[ok] content-based apikey redaction (case-variant path covered)")

B = AI  # Bridge.jl 无模块包装,ai_* 函数直接位于 QInsControlAI 命名空间
println("[ok] aliases: ", B.ai_alias_table())
println("[ok] language: ", B.ai_language())
println("[ok] instrument summary (empty ok): '", B.ai_instrument_summary(true), "'")
println("[ok] data keys: ", B.ai_data_keys())
println("[ok] task list: ", B.ai_task_list())
println("[ok] status: ", replace(B.ai_status(), '\n' => ' '))

# 脚本校验通道(与 GUI Anti-interpret 同一 antiinterpretblocks + 别名白名单)
# 注意:规范文本中所有字符串实参(别名/量名/单位/mark/index/cmd)都带双引号
ok, blocks, err = B.ai_validate_script("@writeblock \"Virtual\" \"*IDN?\" false false")
println("[ok] writeblock validate: ok=", ok, " err=", err)
ok && println("[ok] summary: ", B.blocksummary(blocks))

ok2, blocks2, err2 = B.ai_validate_script("""
@sweepblock "" "Virtual" "Vac" "1uV" "100uA" "μV" 0.1 0 false begin
    @readingblock "Virtual" "Date" "" "D" false false true false
end
""")
println("[ok] sweepblock validate: ok=", ok2, " err=", err2, " nblocks=", ok2 ? length(blocks2) : 0)
ok2 && foreach(l -> println("     ", l), B.blocksummary(blocks2))

bad = B.ai_validate_script("@writeblock \"NoSuchAlias\" \"x\" false false")
println("[ok] bad alias correctly rejected: ok=", bad[1], " err=", first(bad[3], 60))

println("[ok] snapshot head: ", replace(first(AI.snapshot(), 160), '\n' => " | "))
println("[ok] systemprompt chars: ", length(AI.systemprompt(true)))
println("AI integration smoke passed.")

# 驱动规范:TOML 校验(好的通过,坏的报具体错误)
goodtoml = """
[conf]
idn = "TEST123"
cmdtype = "scpi"
[readdata]
cmdheader = "READ?"
type = "read"
U = ""
"""
println("[ok] good conftoml: err='", B.ai_validate_conftoml(goodtoml), "'")
badtoml1 = replace(goodtoml, "[conf]" => "")
println("[ok] conftoml without conf: ", first(B.ai_validate_conftoml(badtoml1), 40))
badtoml2 = replace(goodtoml, "type = \"read\"" => "type = \"noop\"")
println("[ok] conftoml bad type: ", first(B.ai_validate_conftoml(badtoml2), 45))

# 驱动信息读取(真实仪器)
println("[ok] driver info head: ", replace(first(B.ai_driver_info("34410"), 120), '\n' => " | "))

# 系统提示词包含驱动规范
occursin("Instrument driver authoring reference", AI.systemprompt(true)) &&
    println("[ok] systemprompt contains driver reference")
println("AI integration smoke passed.")

# Widget:校验器(好/坏)+ 信息读取(真实仪器)
goodw = """
[Panel1]
instrnm = "VirtualInstr"
name = "Demo Panel"
windowsize = [300.0, 200.0]
    [[Panel1.qtws]]
    name = "_Shape_"
    alias = "frame"
    qtype = "none"
        [Panel1.qtws.options]
        uitype = "rect"
        vertices = [[10.0, 10.0], [0.0, 0.0], [0.0, 0.0]]
        itemsize = [280.0, 180.0]
"""
println("[ok] good widget toml: err='", B.ai_validate_widgettoml(goodw, "VirtualInstr"), "'")
badw1 = replace(goodw, "instrnm = \"VirtualInstr\"" => "instrnm = \"NoSuchIns\"")
println("[ok] widget wrong instrnm: ", first(B.ai_validate_widgettoml(badw1, "NoSuchIns"), 50))
badw2 = replace(goodw, "uitype = \"rect\"" => "uitype = \"combo\"")   # _Panel_ 不接受 combo
println("[ok] widget bad uitype: ", first(B.ai_validate_widgettoml(badw2, "VirtualInstr"), 55))
println("[ok] widget info head: ", replace(first(B.ai_widget_info("VirtualInstr"), 110), '\n' => " | "))
occursin("widget authoring reference", AI.systemprompt(true)) &&
    println("[ok] systemprompt contains widget reference")
println("AI integration smoke passed.")

# 任务脚本读取:建任务(封送队列手动排水,无 GUI)→ get_task_script 读回
okt, blockst, _ = B.ai_validate_script("@sweepblock \"\" \"Virtual\" \"Vac\" \"1uV\" \"10uV\" \"μV\" 0.1 0 false begin\n    @readingblock \"Virtual\" \"Date\" \"\" \"Vx\" true false true false\nend")
@assert okt
B.ai_add_task("SmokeTask", "@sweepblock test script", blockst)
AI.drain_ui!()
println("[ok] task script readback:")
println(first(B.ai_task_script("SmokeTask"), 260))
occursin("sweepblock", B.ai_task_script("SmokeTask")) && println("[ok] get_task_script roundtrip OK")
println("AI integration smoke passed.")

# 回归:JSON 1.7 的 JSON.parse 返回 JSON.Object(非 Dict),calltool 曾因此误杀所有调用
r = AI.calltool("list_tasks", "{}")
occursin("arguments must be", r) && error("calltool JSON.Object regression!")
println("[ok] calltool list_tasks: ", first(r, 60))
r2 = AI.calltool("get_data_sample", "{\"key\": \"nope\", \"n\": 5}")
occursin("arguments must be", r2) && error("calltool JSON.Object regression #2!")
println("[ok] calltool get_data_sample: ", first(r2, 50))
println("AI integration smoke passed.")

# Assets 探查:列目录/读文件/越界拒绝
occursin("Confs", AI.ai_list_assets()) && println("[ok] list_assets root contains Confs")
occursin("[Date]", AI.ai_read_asset("Confs/VirtualInstr.toml")) && println("[ok] read_asset VirtualInstr.toml OK")
occursin("escapes", AI.ai_read_asset("../../secrets.txt")) && println("[ok] path escape rejected")
occursin("only text files", AI.ai_read_asset("Necessity/QInsControl.ico")) && println("[ok] binary rejected")
println("AI integration smoke passed.")

# 回归:buildmessages 截空修复——agent 工具链消息数超过 maxhistory 窗口且尾窗内无 user 消息时,
# 旧行为把历史整段丢弃(请求只剩 system,模型中途失忆;Anthropic 因空 messages 直接 400)。
# 修复后必须始终携带自最近一条 user 消息起的完整链,且较早的 tool 结果全文截断。
function _smoke_agentchain(k::Int, maxturns::Int)
    conv = AI.Conversation(AI.UUIDs.uuid4(), "t", AI.ChatMessage[], "")
    AI.pushmessage!(conv, AI.ChatMessage("user", "build a driver + panel for my instrument"))
    for turn in 1:maxturns
        sent = AI.buildmessages(conv; agent=true)
        any(m -> m.role == "user", sent) || return false   #截空 = 请求只剩 system
        tcs = [Dict("id" => "c$turn-$j", "name" => "read_asset", "arguments" => "{}") for j in 1:k]
        AI.pushmessage!(conv, AI.ChatMessage("assistant", ""; toolcalls=tcs))
        for j in 1:k
            AI.pushmessage!(conv, AI.ChatMessage("tool", repeat("x", 500); toolcallid="c$turn-$j"))
        end
    end
    return true
end
@assert _smoke_agentchain(3, 8) "buildmessages dropped history in a long parallel-tool chain"
@assert _smoke_agentchain(1, 20) "buildmessages dropped history with maxtoolturns=20"
conv = AI.Conversation(AI.UUIDs.uuid4(), "t", AI.ChatMessage[], "")
AI.pushmessage!(conv, AI.ChatMessage("user", "q"))
for j in 1:5   #12 条历史:前 5 个 tool 结果超出"最近 6 条保留全文"窗口,应被截断
    AI.pushmessage!(conv, AI.ChatMessage("assistant", ""; toolcalls=[Dict("id" => "c$j", "name" => "f", "arguments" => "{}")]))
    AI.pushmessage!(conv, AI.ChatMessage("tool", repeat("y", 500); toolcallid="c$j"))
end
AI.pushmessage!(conv, AI.ChatMessage("assistant", "done"))
sent = AI.buildmessages(conv; agent=true)
@assert length(sent) == 13   #system + 12 条
oldtool, newtool = sent[4], sent[12]
@assert oldtool.role == "tool" && length(oldtool.content) <= AI.TOOLCLIPLEN + 20 "old tool result not clipped"
@assert occursin("…[clipped]", oldtool.content) "clip marker missing"
@assert newtool.role == "tool" && length(newtool.content) == 500 "recent tool result should stay full"
println("[ok] buildmessages keeps user boundary & clips old tool results")

# 回归:SSRF 私网判定(裸 IP 字面量,离线可测;域名解析/重定向在 client 冒烟的 mock 里覆盖)
for (h, want) in [
    ("10.0.0.1", true), ("172.16.0.1", true), ("192.168.1.5", true), ("127.0.0.1", true),
    ("169.254.169.254", true), ("100.64.0.1", true), ("0.0.0.0", true),
    ("::1", true), ("fc00::1", true), ("fd12::1", true), ("fe80::1", true),
    ("::ffff:127.0.0.1", true), ("::7f00:1", true), ("::ffff:8.8.8.8", false),
    ("8.8.8.8", false), ("1.1.1.1", false), ("2606:4700:4700::1111", false),
]
    got = AI.isprivatenethost(h)
    @assert got == want "isprivatenethost($h) = $got, want $want"
end
occursin("SSRF", AI.ai_fetch_url("http://127.0.0.1:9/")) && println("[ok] fetch_url rejects loopback")
println("[ok] isprivatenethost private/public matrix OK")
println("AI integration smoke passed.")

# 驱动实测工具链冒烟(真实 I/O worker + VirtualInstr,离线无硬件):
# 验证 test_quantity/read_raw/test_driver_get/driver_probe/get_recent_errors 的返回形状——
# 要么给出 raw+parse 判定,要么给出带根因的 FAILED 文本;绝不出现 "tool error:"(MethodError 回归)。
begin
    function _bootworker!()
        try
            nprocs() == 1 && addprocs(1; exeflags = "--project=$(Base.active_project())")
            #worker 必须加载主模块(闭包反序列化要按模块路径解析);@everywhere 不能进函数,用显式 eval
            remotecall_wait(() -> Base.eval(Main, :(using QInsControl)), workers()[1])
            QInsControl.initialize_qinscontrolcore!()
            remotecall_wait(cs -> QInsControl.initialize_qinscontrolcore!(cs), workers()[1], 64)
            return true
        catch e
            println("[warn] I/O worker unavailable in this environment, driver-chain smoke skipped: ",
                first(sprint(showerror, e), 120))
            return false
        end
    end
    workerok = _bootworker!()
    if workerok
        #确保被测仪器有别名(冒烟专用,不依赖用户工程)
        hasalias = any(t[2] == "VirtualInstr" for t in B.ai_alias_table())
        hasalias || (B.ai_add_alias("VSmoke", "VirtualInstr", "VIRT::0"); AI.drain_ui!())
        aliasm = first(t[1] for t in B.ai_alias_table() if t[2] == "VirtualInstr")

        #校验器:参数形状错误要有确定性文案(不依赖硬件)
        occursin("unknown alias", AI.calltool("test_quantity", "{\"alias\": \"NoSuch\", \"quantity\": \"x\"}")) &&
            println("[ok] test_quantity unknown alias rejected")
        steps13 = "[" * join(fill("{\"read\": \"\"}", 13), ", ") * "]"
        occursin("too many steps", AI.calltool("driver_probe", "{\"alias\": \"$aliasm\", \"steps\": $steps13}")) &&
            println("[ok] driver_probe step cap enforced")
        occursin("unknown op", AI.calltool("driver_probe", "{\"alias\": \"$aliasm\", \"steps\": [{\"fly\": \"1\"}]}")) &&
            println("[ok] driver_probe unknown op rejected")

        #真实通道:测试函数不存在时,根因(UndefVarError)必须回到模型手里
        r = AI.calltool("test_driver_get", "{\"alias\": \"$aliasm\", \"func\": \"NoSuchDriverFn_get\"}")
        occursin("call FAILED", r) && occursin("UndefVarError", r) &&
            println("[ok] test_driver_get surfaces root cause: ", first(r, 80))
        occursin("tool error", r) && error("driver tool returned raw tool error - regression!")

        #真实通道:test_quantity 走注册通道(形状断言,连接结果依环境而异)
        r2 = AI.calltool("test_quantity", "{\"alias\": \"$aliasm\", \"quantity\": \"Date\"}")
        (occursin("raw: \"", r2) || occursin("FAILED", r2)) || error("test_quantity unexpected shape: " * first(r2, 80))
        occursin("tool error", r2) && error("test_quantity returned raw tool error - regression!")
        println("[ok] test_quantity: ", replace(first(r2, 110), '\n' => " | "))
        println("[ok] driver-chain tool shapes OK")
    end
    println("AI integration smoke passed.")
end

# 报错求助链:get_recent_errors 返回形态(今日无日志文件/无错误时的占位文本也算通过)
# MCP (Model Context Protocol) 端点分发:initialize/tools list/tools call/resources
begin
    QInsControl.CONF.Basic.mcp = true   #分发测试直调 mcp_handle,显式固定 gate 状态
    import HTTP as HTTPj
    r = QInsControl.mcp_message(JSON.parse("""{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"""))
    d = JSON.parse(r.body)
    d["result"]["serverInfo"]["name"] == "QInsControl" || error("MCP initialize failed")
    d["result"]["protocolVersion"] == QInsControl.MCP_PROTOCOL_VERSION || error("MCP protocol version missing")
    r2 = QInsControl.mcp_message(JSON.parse("""{"jsonrpc":"2.0","id":2,"method":"tools/list"}"""))
    tools = JSON.parse(r2.body)["result"]["tools"]
    names = [t["name"] for t in tools]
    "get_status" in names && "test_quantity" in names || error("MCP tools/list missing tools")
    schema = only(filter(t -> t["name"] == "query_command", tools))["inputSchema"]
    schema["type"] == "object" && "alias" in keys(schema["properties"]) || error("MCP tool schema malformed")
    r3 = QInsControl.mcp_message(JSON.parse("""{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_status","arguments":{}}}"""))
    res = JSON.parse(r3.body)["result"]
    occursin("DAQ running", res["content"][1]["text"]) || error("MCP tools/call get_status failed: " * res["content"][1]["text"][1:min(end,80)])
    r4 = QInsControl.mcp_handle(HTTPj.Request("POST", "/mcp", [], """{"jsonrpc":"2.0","method":"notifications/initialized"}"""))
    r4.status == 202 || error("MCP notification should return 202")
    r5 = QInsControl.mcp_message(JSON.parse("""{"jsonrpc":"2.0","id":5,"method":"resources/read","params":{"uri":"qinscontrol://snapshot"}}"""))
    occursin("Instruments on the bench", JSON.parse(r5.body)["result"]["contents"][1]["text"]) || error("MCP snapshot resource missing bench info")
    println("[ok] MCP endpoint: initialize / tools/list(", length(names), " tools) / tools/call / notification 202 / snapshot resource")
    #真实 HTTP 路由链路:起完整 WebDashboard 后打 /mcp(含 confirm gate 与开关检查)
    try
        QInsControl.startwebdashboard!(port = Cint(18986), bind = "127.0.0.1")
        r = HTTPj.post("http://127.0.0.1:18986/mcp",
            ["Content-Type" => "application/json", "Accept" => "application/json"],
            """{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_status","arguments":{}}}""";
            retry = false, request_timeout = 10)
        occursin("DAQ running", String(r.body)) ||
            error("MCP HTTP route failed: " * first(String(r.body), 100))
        println("[ok] MCP HTTP route end-to-end (POST /mcp tools/call)")
    catch e
        error("MCP HTTP route: " * first(sprint(showerror, e), 120))
    finally
        QInsControl.stopwebdashboard!()
    end
    println("AI integration smoke passed.")
end

# 可用仪器实况:INSTRBUFFERVIEWERS(非 Others)→ get_instruments 工具
ri = AI.calltool("get_instruments", "{}")
occursin("tool error", ri) && error("get_instruments regression!")
occursin("usable instruments", ri) || occursin("(", ri) || error("get_instruments unexpected shape: " * first(ri, 80))
println("[ok] get_instruments: ", replace(first(ri, 90), '\n' => " | "))
rerr = AI.calltool("get_recent_errors", "{}")
occursin("tool error", rerr) && error("get_recent_errors regression!")
println("[ok] get_recent_errors: ", replace(first(rerr, 90), '\n' => " | "))
println("AI integration smoke passed.")

# 模型列表拉取:本地 mock /models 端点(OpenAI 协议 data[].id)+ 临时 provider
begin
    import HTTP as HTTPj
    msrv = HTTPj.serve!("127.0.0.1", 18984) do req
        startswith(String(req.target), "/v1/models") &&
            return HTTPj.Response(200, ["Content-Type" => "application/json"],
                body = "{\"data\":[{\"id\":\"model-b\"},{\"id\":\"model-a\"},{\"id\":\"model-b\"}]}")
        return HTTPj.Response(404)
    end
    push!(AI.aiconf().providers, AI.AIProvider(name = "MockFetch", baseurl = "http://127.0.0.1:18984/v1", apikey = "k"))
    out = AI.ai_fetch_models("MockFetch")
    out == "model-a\nmodel-b" || error("ai_fetch_models mismatch: " * first(out, 80))
    occursin("unknown provider", AI.ai_fetch_models("NoSuch")) || error("unknown provider not rejected")
    deleteat!(AI.aiconf().providers, findlast(p -> p.name == "MockFetch", AI.aiconf().providers))
    close(msrv)
    println("[ok] ai_fetch_models (sorted, deduped by provider, error text on failure)")
    println("AI integration smoke passed.")
end

# 会话持久化往返:savearchive(JSON+md 双写) → loadarchives! 载回校验。
# 目录指向独立临时目录——绝不读写用户真实会话目录(否则与用户的真实对话互相干扰)
olddir = AI.aiconf().dir
AI.aiconf().dir = mktempdir()
conv = AI.Conversation(AI.UUIDs.uuid4(), "PersistenceSmoke", AI.ChatMessage[], "test/model")
AI.pushmessage!(conv, AI.ChatMessage("user", "hello persist"))
AI.pushmessage!(conv, AI.ChatMessage("assistant", "hi there"; reasoning = "thought"))
AI.savearchive(conv)
AI.loadarchives!()
smokeconv = filter(c -> !isempty(c.messages) && c.messages[1].content == "hello persist", AI.CHAT.conversations)
@assert length(smokeconv) >= 1 "JSON archive not loaded back"
@assert all(c -> length(c.messages) == 2 && c.messages[2].reasoning == "thought", smokeconv) "messages/reasoning lost in archive roundtrip"
AI.aiconf().dir = olddir   #还原用户目录并恢复其会话列表
AI.loadarchives!()
println("[ok] conversation archive JSON roundtrip (write + load, isolated temp dir)")
println("AI integration smoke passed.")

# 绘图工具:创建(未来数据键只警告不拒绝)→ 确认窗自动应答 → get_plot 往返 → update_plot
function _drainconfirms!(want::Bool)
    @async for _ in 1:8
        t0 = time()
        while time() - t0 < 3 && !isready(AI.CONFIRMREQS)
            sleep(0.01)
        end
        isready(AI.CONFIRMREQS) || break
        req = take!(AI.CONFIRMREQS)
        req.answer[] = want
    end
end
begin
    inner = JSON.json(Dict("layout" => "Axis(figure[1,1])",
        "series" => [Dict("index" => 1, "x" => "Marked X", "y" => "future/key")]))
    _drainconfirms!(true)
    r = AI.calltool("create_plot", JSON.json(Dict("name" => "SmokePlot", "cfg" => inner)))
    occursin("WARN", r) || error("create_plot future-key warning missing")
    occursin("created", r) || error("create_plot failed: " * first(r, 80))
    AI.drain_ui!()
    r = AI.calltool("get_plot", "{\"name\": \"SmokePlot\"}")
    occursin("Marked X", r) && occursin("future/key", r) || error("get_plot roundtrip mismatch: " * first(r, 120))
    inner2 = JSON.json(Dict("series" => [Dict("index" => 1, "x" => "Marked X", "y" => "other/key")]))
    _drainconfirms!(true)
    r = AI.calltool("update_plot", JSON.json(Dict("name" => "SmokePlot", "cfg" => inner2)))
    AI.drain_ui!()
    occursin("updated", r) || error("update_plot failed: " * first(r, 80))
    occursin("other/key", AI.calltool("get_plot", "{\"name\": \"SmokePlot\"}")) || error("update_plot roundtrip mismatch")
    println("[ok] plot tool chain (create with future-key warn / get / update roundtrip)")
    println("AI integration smoke passed.")
end

# 恢复资产目录环境:本文件为隔离 AI 初始化而重定向了 ENV,不恢复会让
# 后续测试(ITE 电池启动真实应用)读不到 Languages 等资产而静默降级
if _prev_qic_assets === nothing
    delete!(ENV, "QInsControlAssets")
else
    ENV["QInsControlAssets"] = _prev_qic_assets
end
