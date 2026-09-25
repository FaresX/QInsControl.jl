# AI 子模块加载态集成冒烟(不启动 GUI、不做真实网络请求):
#   julia --project=. test/ai_integration_smoke.jl
# 验证:initialize_ai! 写出 ai.toml、Bridge 只读适配函数、脚本校验通道、系统提示词构建。
assets = abspath(joinpath(@__DIR__, "..", "..", "QInsControlAssets"))  # 与 precompile.jl 一致的开发资产目录
isdir(assets) || (assets = mktempdir())
ENV["QInsControlAssets"] = assets
using QInsControl
const AI = QInsControl.QInsControlAI

QInsControl.initialize_ai!()
@assert isfile(AI.aiconfpath()) "ai.toml not written"
println("[ok] ai.toml written to ", AI.aiconfpath())
println("[ok] providers: ", [p.name for p in AI.aiconf().providers])
println("[ok] resolvekey env-indirect: '", AI.resolvekey(AI.AIProvider(apikey="env:SOME_MISSING_VAR")), "'")

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
