# Agent 工具注册表、三级安全门分发,以及聊天发送/执行链路(在 AI 任务线程上运行)
# 注意:AITOOLS 内的回调一律用 function 形式——Julia 1.12 的 include 期解析
# 不接受"数组字面量内多行调用的尾部 -> begin lambda"(Meta.parseall 却接受)。

struct AITool
    name::String
    description::String
    props::Vector{NTuple{3,String}}    # (参数名, 类型, 说明)
    required::Vector{String}
    level::Int                          # 0 只读自动执行 / 1 写仪器确认 / 2 改工程确认
    f::Function                         # args::Dict{String,Any} -> String(结果回喂模型)
end

const BLOCKS_SUMMARY_LIMIT = 12

function resolvealias(alias::AbstractString)
    for (a, ins, addr) in ai_alias_table()
        a == String(alias) && return (String(ins), String(addr))
    end
    return nothing
end

const AITOOLS = AITool[
    AITool("list_aliases", "List instrument aliases (alias => instrument, address). Use these exact names in scripts.",
           [], [], 0, function (_)
        join(["  \"$(t[1])\" => \"$(t[2])\", \"$(t[3])\"" for t in ai_alias_table()], "\n")
    end),
    AITool("list_instruments", "List registered instruments with their quantities, types (sweep/set/read), units and help.",
           [], [], 0, function (_)
        ai_instrument_summary(true)
    end),
    AITool("list_tasks", "List measurement tasks in the current project (name/mode/block count). Use get_task_script to read one task's full script.",
           [], [], 0, function (_)
        ai_task_list()
    end),
    AITool("get_task_script", "Read a task's full script: the DSL text (text mode keeps the original; block mode is converted back with the same interpret pass as the GUI). Use this before explaining, comparing or modifying an existing task.",
           [("task", "string", "task name exactly as shown by list_tasks")],
           ["task"], 0, function (args)
        ai_task_script(get(args, "task", ""))
    end),
    AITool("get_data_keys", "List data keys currently in the buffer (with point counts and last values).",
           [], [], 0, function (_)
        ai_data_keys()
    end),
    AITool("get_data_sample", "Read the last n values of one data key (numeric).",
           [("key", "string", "data key, exactly as returned by get_data_keys"),
            ("n", "integer", "number of tail values, default 50")], ["key"], 0, function (args)
        n = tryparse(Int, string(get(args, "n", "50")))
        ai_data_sample(get(args, "key", ""), n === nothing ? 50 : n)
    end),
    AITool("get_status", "Get software status: DAQ running/blocked, instrument count, data buffer size.",
           [], [], 0, function (_)
        ai_status()
    end),
    AITool("read_quantity", "Read a defined quantity of an instrument once (single-shot).",
           [("alias", "string", "instrument alias from list_aliases"),
            ("quantity", "string", "quantity name from list_instruments")], ["alias", "quantity"], 0, function (args)
        r = resolvealias(get(args, "alias", ""))
        r === nothing && return "unknown alias \"$(get(args, "alias", ""))\""
        return ai_read_quantity(r[1], r[2], get(args, "quantity", ""))
    end),
    AITool("write_command", "Write a raw command to an instrument (terminator added automatically). REQUIRES CONFIRMATION.",
           [("alias", "string", "instrument alias"), ("cmd", "string", "raw command without terminator")],
           ["alias", "cmd"], 1, function (args)
        r = resolvealias(get(args, "alias", ""))
        r === nothing && return "unknown alias"
        ai_confirm("Write Command", "$(r[1]) @ $(r[2])\n> $(get(args, "cmd", ""))") || return "user declined"
        return ai_write(r[1], r[2], get(args, "cmd", ""))
    end),
    AITool("query_command", "Write a raw command then read the response. REQUIRES CONFIRMATION.",
           [("alias", "string", "instrument alias"), ("cmd", "string", "query command")],
           ["alias", "cmd"], 1, function (args)
        r = resolvealias(get(args, "alias", ""))
        r === nothing && return "unknown alias"
        ai_confirm("Query Command", "$(r[1]) @ $(r[2])\n> $(get(args, "cmd", ""))") || return "user declined"
        return ai_query(r[1], r[2], get(args, "cmd", ""))
    end),
    AITool("set_quantity", "Set a settable/sweepable quantity to a value (with read-back check). REQUIRES CONFIRMATION.",
           [("alias", "string", "instrument alias"),
            ("quantity", "string", "quantity name"),
            ("value", "number", "target value (in the default unit shown by list_instruments)")],
           ["alias", "quantity", "value"], 1, function (args)
        r = resolvealias(get(args, "alias", ""))
        r === nothing && return "unknown alias"
        qtnm = get(args, "quantity", "")
        v = get(args, "value", nothing)
        ai_confirm("Set Quantity", "$(r[1]) @ $(r[2])\n$qtnm = $v") || return "user declined"
        return ai_set_quantity(r[1], r[2], qtnm, v)
    end),
    AITool("create_task", "Create a measurement task from a QInsControl DSL script (see DSL reference). The user will review and run it. REQUIRES CONFIRMATION.",
           [("name", "string", "task name"),
            ("script", "string", "complete task script following the DSL reference")],
           ["name", "script"], 2, function (args)
        name = get(args, "name", "AI Task")
        script = get(args, "script", "")
        ok, blocks, err = ai_validate_script(script)
        ok || return "script validation failed: $err\nFix the script and call create_task again."
        isempty(blocks) && return "script parsed to an empty task, please provide a real script"
        summary = join(first(blocksummary(blocks), BLOCKS_SUMMARY_LIMIT), "\n")
        ai_confirm("Create Task", "task \"$name\"\n$summary") || return "user declined"
        ai_add_task(name, script, blocks)
        return "task \"$name\" created with $(length(blocks)) blocks. It is now in the task list for the user to review and run."
    end),
    AITool("update_task_script", "Replace the script of an existing task. REQUIRES CONFIRMATION.",
           [("task", "string", "existing task name"),
            ("script", "string", "complete replacement script")],
           ["task", "script"], 2, function (args)
        taskname = get(args, "task", "")
        ok, blocks, err = ai_validate_script(get(args, "script", ""))
        ok || return "script validation failed: $err\nFix the script and call update_task_script again."
        summary = join(first(blocksummary(blocks), BLOCKS_SUMMARY_LIMIT), "\n")
        ai_confirm("Update Task", "task \"$taskname\"\n$summary") || return "user declined"
        ai_update_task(taskname, get(args, "script", ""), blocks)
        return "task \"$taskname\" updated with $(length(blocks)) blocks."
    end),
    AITool("add_alias", "Add or update an instrument alias. REQUIRES CONFIRMATION.",
           [("alias", "string", "alias name used in scripts"),
            ("instrument", "string", "registered instrument name"),
            ("address", "string", "instrument address, e.g. GPIB0::12::INSTR")],
           ["alias", "instrument", "address"], 2, function (args)
        alias = get(args, "alias", "")
        ai_confirm("Add Alias", "$alias => $(get(args, "instrument", "")) @ $(get(args, "address", ""))") || return "user declined"
        ai_add_alias(alias, get(args, "instrument", ""), get(args, "address", ""))
        return "alias \"$alias\" saved."
    end),
    AITool("interrupt_task", "Interrupt the running DAQ task (same as pressing the stop button). REQUIRES CONFIRMATION.",
           [], [], 2, function (_)
        ai_confirm("Interrupt Task", "stop the running DAQ task?") || return "user declined"
        ai_interrupt!()
        return "interrupt requested."
    end),
    AITool("get_driver", "Read an instrument's registry entry (idn/cmdtype/quantities with cmdheaders), the available unit types, and its current driver source code. Always call this before modifying a driver.",
           [("instrument", "string", "instrument name as shown in list_instruments")],
           ["instrument"], 0, function (args)
        ai_driver_info(get(args, "instrument", ""))
    end),
    AITool("list_unit_types", "List available unit type keys (for the U field of quantity tables in instrument TOML).",
           [], [], 0, function (_)
        join(sort(collect(keys(qc.CONF.U))), ", ")
    end),
    AITool("search_quantities", "Search ALL registered quantities by keyword (matches quantity name, alias, help text, cmdheader, instrument name; case-insensitive). Use this to map physical quantities like \"field\"/\"current\"/\"temperature\" to concrete instruments/quantities.",
           [("keyword", "string", "physical quantity or name fragment, e.g. \"field\", \"current\", \"temp\", \"querydata\"")],
           ["keyword"], 0, function (args)
        ai_search_quantities(get(args, "keyword", ""))
    end),
    AITool("write_driver", "Write (or replace) the hand-written driver file Assets/ExtraLoad/<instrument>.jl and hot-load it on the I/O worker. For non-standard protocol functions (<ins>_<qt>_get/set). REQUIRES CONFIRMATION.",
           [("instrument", "string", "instrument name (file base name)"),
            ("code", "string", "complete Julia source of the driver file")],
           ["instrument", "code"], 2, function (args)
        name = get(args, "instrument", "")
        code = get(args, "code", "")
        strip(code) == "" && return "empty driver code"
        #确认框必须让用户能看清将执行的全部内容:只截 500 字符时尾部代码等于盲签
        preview = length(code) <= 2000 ? String(code) :
                  first(code, 2000) * "\n...[truncated, $(length(code)) chars in total]"
        ai_confirm("Write Driver", "file: ExtraLoad/$(sanename(name)).jl\n$preview") ||
            return "user declined"
        ai_write_driver(name, code)
        return "driver saved to ExtraLoad/$(sanename(name)).jl and hot-loaded. Remember: quantities with a non-empty cmdheader are auto-generated and will override hand-written functions."
    end),
    AITool("create_instrument", "Create or fully update an instrument: write Assets/Confs/<name>.toml (registry) plus an optional driver file, then hot-reload the registry. REQUIRES CONFIRMATION.",
           [("name", "string", "instrument name (file base name, e.g. K2400)"),
            ("conftoml", "string", "complete TOML following the driver authoring reference"),
            ("drivercode", "string", "Julia driver source, or \"\" if every quantity uses standard SCPI/TSP headers")],
           ["name", "conftoml"], 2, function (args)
        name = get(args, "name", "")
        conftoml = get(args, "conftoml", "")
        err = ai_validate_conftoml(conftoml)
        err != "" && return "instrument TOML validation failed: $err\nFix the TOML and call create_instrument again."
        qnames = [k for k in keys(TOML.parse(String(conftoml))) if k != "conf"]
        summary = string("name: ", name, "\nidn: ", string(get(TOML.parse(String(conftoml))["conf"], "idn", "?")),
                         "\ncmdtype: ", string(get(TOML.parse(String(conftoml))["conf"], "cmdtype", "")),
                         "\nquantities: ", join(qnames, ", "))
        ai_confirm("Create Instrument", summary) || return "user declined"
        return ai_create_instrument(name, conftoml, get(args, "drivercode", ""))
    end),
    AITool("web_search", "Search the web (Bing, DuckDuckGo fallback) for e.g. an instrument's programming manual or SCPI command reference. Returns title+URL lines.",
           [("query", "string", "search query, e.g. \"Keysight 34410A SCPI command reference\"")],
           ["query"], 0, function (args)
        ai_web_search(get(args, "query", ""))
    end),
    AITool("fetch_url", "Fetch a web page and return its readable text (HTML stripped, ~20k chars max). Use URLs found by web_search. PDFs are rejected - look for HTML versions.",
           [("url", "string", "http(s) URL to fetch")],
           ["url"], 0, function (args)
        ai_fetch_url(get(args, "url", ""))
    end),
    AITool("get_widget", "Read everything needed to build a control panel for an instrument: quantity facts (type/optvalues count/numread), allowed uitype lists, and the current widget TOML file.",
           [("instrument", "string", "registered instrument name")],
           ["instrument"], 0, function (args)
        ai_widget_info(get(args, "instrument", ""))
    end),
    AITool("create_widget", "Create or replace an instrument control panel: write Assets/Widgets/<instrument>.toml (whole file = the panel, missing fields take defaults) and hot-reload. Follow the widget authoring reference. REQUIRES CONFIRMATION.",
           [("instrument", "string", "registered instrument name (file base name)"),
            ("toml", "string", "complete widget TOML following the widget authoring reference")],
           ["instrument", "toml"], 2, function (args)
        name = get(args, "instrument", "")
        toml = get(args, "toml", "")
        err = ai_validate_widgettoml(toml, name)
        err != "" && return "widget TOML validation failed: $err
Fix the TOML and call create_widget again."
        nw = length(keys(TOML.parse(String(toml))))
        ai_confirm("Create Widget", "instrument \"$name\": $nw panel(s)
First 300 chars:
" * first(toml, 300)) || return "user declined"
        return ai_create_widget(name, toml)
    end),
    AITool("list_assets", "List files/folders under the QInsControlAssets directory - the single source of ALL configuration: Confs/<instr>.toml (instrument registry), Widgets/<instr>.toml (control panels), ExtraLoad/<instr>.jl (drivers), Styles/*.toml (themes), Languages/*.toml (translations), Necessity/conf.toml (global settings), Necessity/ai.toml (AI settings). Explore here before asking the user for configuration details.",
           [("subdir", "string", "subdirectory relative to the assets root, e.g. \"Confs\"; empty for the root")],
           [], 0, function (args)
        ai_list_assets(get(args, "subdir", ""))
    end),
    AITool("read_asset", "Read a text file under the QInsControlAssets directory (e.g. Confs/K2400.toml, Widgets/ILM200.toml, Necessity/conf.toml, Styles/OceanBreeze.toml). Text files only (toml/jl/md/txt/ini/json); binaries are rejected.",
           [("path", "string", "path relative to the assets root, e.g. \"Confs/K2400.toml\"")],
           ["path"], 0, function (args)
        ai_read_asset(get(args, "path", ""))
    end),
]

toolmap() = Dict(t.name => t for t in AITOOLS)

"按模式下发工具:普通聊天只开放只读(Level 0)工具——解释/查询不需要开 Agent;Agent 模式开放全部"
toolset(agent::Bool) = toolsschemas(agent ? AITOOLS : filter(t -> t.level == 0, AITOOLS))

"分发一个工具调用(结果总是字符串,异常转错误文本回喂模型);allowwrite=false 时写工具拒绝"
function calltool(name::AbstractString, argstr::AbstractString; allowwrite::Bool=true)
    tool = get(toolmap(), String(name), nothing)
    tool === nothing && return "unknown tool \"$name\""
    (allowwrite || tool.level == 0) ||
        return "tool \"$(tool.name)\" writes to instruments/projects and is only available in Agent mode"
    args = try
        JSON.parse(argstr == "" ? "{}" : String(argstr))
    catch
        return "invalid arguments JSON: $(first(argstr, 200))"
    end
    args isa AbstractDict || return "arguments must be a JSON object"
    return try
        String(tool.f(args))
    catch e
        "tool error: " * sprint(showerror, e)
    end
end

# ============ 聊天执行链路(全部在 AI 任务线程上) ============

function ondelta()
    return function (kind, s)
        lock(CHATLOCK) do
            if kind == :text
                CHAT.inflight *= s
            else
                CHAT.reasoning *= s
            end
            CHAT.newtoken = true
        end
    end
end

"""
    sendchat!(text; agent=false)

聊天总入口(UI 线程调用,内部 spawn AI 任务):压入用户消息 → 流式请求 →
工具调用循环(仅 agent)→ 结果入历史 → 存档。同一时刻只允许一个在途请求。
"""
function sendchat!(text::AbstractString; agent::Bool=false)
    aiconf().enable || return
    prov = getprovider()
    prov === nothing && (@warn "no AI provider configured"; return)
    #busy 检查与置位必须同锁原子完成:UI 与 WebDashboard 都能并发调 sendchat!,
    #锁外先查后置会双双通过,同时 spawn 两个在途请求
    started = lock(CHATLOCK) do
        CHAT.busy && return false
        CHAT.busy = true
        CHAT.stop = false
        CHAT.inflight = ""
        CHAT.reasoning = ""
        CHAT.newtoken = true
        empty!(CHAT.toolsteps)
        return true
    end
    started || return
    conv = currentconv()
    conv.provider = string(prov.name, " / ", prov.model)
    pushmessage!(conv, ChatMessage("user", String(text)))
    @spawn_record "ai chat" catchlog("AI request failed") do
        try
            runturn!(conv, prov; agent)
        finally
            lock(CHATLOCK) do
                if !isempty(CHAT.inflight) || !isempty(CHAT.reasoning)
                    push!(conv.messages, ChatMessage("assistant", CHAT.inflight; reasoning=CHAT.reasoning))
                    CHAT.inflight = ""
                    CHAT.reasoning = ""
                end
                CHAT.busy = false
                CHAT.newtoken = true
            end
            savearchive(conv)
        end
    end
    return
end

stopchat!() = lock(() -> (CHAT.stop = true), CHATLOCK)

"单轮执行:请求 → 工具调用循环(有 toolcalls 则回喂结果递归,受 maxtoolturns 约束)"
function runturn!(conv::Conversation, prov::AIProvider; agent::Bool, turns::Int=1)
    if turns > aiconf().maxtoolturns
        pushmessage!(conv, ChatMessage("assistant", mlstr("Too many tool turns, stopped.")))
        return
    end
    tools = toolset(agent)
    res = try
        chat!(ondelta(), prov, buildmessages(conv; agent); tools, stop=() -> lock(() -> CHAT.stop, CHATLOCK))
    catch e
        pushmessage!(conv, ChatMessage("assistant", string("⚠ ", sprint(showerror, e))))
        return
    end
    lock(CHATLOCK) do
        CHAT.inflight = ""
        CHAT.reasoning = ""
        CHAT.newtoken = true
    end
    if res.status == :aborted
        pushmessage!(conv, ChatMessage("assistant", isempty(res.content) ? "…(" * mlstr("aborted") * ")" : res.content))
        return
    end
    if !isempty(res.toolcalls)
        pushmessage!(conv, ChatMessage("assistant", res.content; toolcalls=res.toolcalls, reasoning=res.reasoning))
        for tc in res.toolcalls
            result = calltool(get(tc, "name", ""), get(tc, "arguments", ""); allowwrite=agent)
            lock(CHATLOCK) do
                push!(CHAT.toolsteps, (String(get(tc, "name", "")), String(get(tc, "arguments", "")), result))
                CHAT.newtoken = true
            end
            pushmessage!(conv, ChatMessage("tool", result; toolcallid=String(get(tc, "id", ""))))
        end
        return runturn!(conv, prov; agent, turns=turns + 1)
    end
    # 文本回退提取两种模式都启用(只读工具在普通聊天也可用)
    if true
        tcc = extracttoolcall(res.content)
        if tcc !== nothing
            pushmessage!(conv, ChatMessage("assistant", res.content; reasoning=res.reasoning))
            argstr = try
                JSON.json(get(tcc, "arguments", Dict()))
            catch
                "{}"
            end
            result = calltool(String(get(tcc, "tool", "")), argstr; allowwrite=agent)
            lock(CHATLOCK) do
                push!(CHAT.toolsteps, (String(get(tcc, "tool", "")), argstr, result))
                CHAT.newtoken = true
            end
            pushmessage!(conv, ChatMessage("tool", result; toolcallid="fallback"))
            return runturn!(conv, prov; agent, turns=turns + 1)
        end
    end
    pushmessage!(conv, ChatMessage("assistant", res.content; reasoning=res.reasoning))
    return
end

"连通性测试(Settings 页):非流式 1 轮小请求,返回状态文本"
function testconnection!(status::Ref{String}, busy::Ref{Bool})
    CHAT.busy && (status[] = "chat is busy"; return)
    prov = getprovider()
    prov === nothing && (status[] = "no provider"; return)
    busy[] = true
    status[] = "testing…"
    p2 = deepcopy(prov)
    p2.stream = false
    @spawn_record "ai test connection" catchlog("AI connection test failed") do
        try
            res = chat!((_, _) -> nothing, p2, ChatMessage[ChatMessage("user", "Reply with exactly: OK")]; timeout=20)
            status[] = res.status == :done ? "OK ($(p2.name) / $(p2.model))" : "failed: $(res.status)"
        catch e
            status[] = "failed: " * first(sprint(showerror, e), 160)
        finally
            busy[] = false
        end
    end
    return
end
