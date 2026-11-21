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

"把工具的仪器定位参数解析成 (instrnm, addr):先按别名,失败再按**原始地址**在
INSTRBUFFERVIEWERS(含 Others 桶)里找——新仪器未注册/无别名时,GUI 里连上后会归入
Others,AI 对它发原始命令(query/write/probe)走的就是这条路径(与 GUI testcmd 同通道)"
function resolveaddr(x::AbstractString)
    r = resolvealias(x)
    r === nothing || return r
    for (ins, addrs) in qc.INSTRBUFFERVIEWERS, a in keys(addrs)
        a == String(x) && return (String(ins), String(a))
    end
    return nothing
end

# 图片输入(multimodal)限制
const IMAGEMIMES = ("image/png", "image/jpeg")
const MAXIMAGES = 4                       #单条消息图片上限
const MAXIMAGEBYTES = 4 * 1024 * 1024     #单张解码后上限

"入口校验:白名单 mime、数量与大小上限,不合格静默丢弃并告警"
function validateimages(images)
    out = NTuple{3,String}[]
    for im in images
        length(out) >= MAXIMAGES && (@warn "image dropped: at most $MAXIMAGES per message"; break)
        try
            mime, b64, name = String(im[1]), String(im[2]), String(im[3])
            mime in IMAGEMIMES || (@warn "image dropped: unsupported mime" mime name; continue)
            (length(b64) * 3) ÷ 4 > MAXIMAGEBYTES && (@warn "image dropped: larger than 4MB" name; continue)
            isempty(b64) || push!(out, (mime, b64, name))
        catch e
            @warn "image dropped: malformed entry" exception = e
        end
    end
    return out
end

const AITOOLS = AITool[
    AITool("list_aliases", "List instrument aliases (alias => instrument, address). Use these exact names in scripts.",
           [], [], 0, function (_)
        join(["  \"$(t[1])\" => \"$(t[2])\", \"$(t[3])\"" for t in ai_alias_table()], "\n")
    end),
    AITool("get_instruments", "List instruments the user actually added to their instrument panels (address + instrument + alias if any). Regular entries are USABLE instruments (currently connected, or connected before). The \"Others\" section holds UNREGISTERED / failed-connect instruments - you can STILL probe those with raw query_command / write_command / driver_probe using their address (the alias parameter accepts an address too); this is the starting point for writing a new instrument's driver. Aliases only tell you what is CONFIGURED; use this tool to see what is actually on the bench.",
           [], [], 0, function (_)
        ai_usable_instruments(true)
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
    AITool("get_data_stats", "Summary statistics of one data key: point count, NaN ratio, min/max/mean, first/last value. Prefer this over raw samples for judging scan quality or spotting all-NaN columns (unparsable driver output); call get_data_sample only when the actual values matter.",
           [("key", "string", "data key, exactly as returned by get_data_keys")],
           ["key"], 0, function (args)
        ai_data_stats(get(args, "key", ""))
    end),
    AITool("get_status", "Get software status: DAQ running/blocked, instrument count, data buffer size, last error.",
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
    AITool("test_quantity", "End-to-end driver acceptance: read a registered quantity through its driver get function, report the RAW response string and whether it parses as a number (same rule the data pipeline applies; unparsable strings are silently recorded as NaN). After create_instrument/write_driver, EVERY readable quantity must report parseable-as-numeric: YES before you may call the driver done. Errors come back with their root cause.",
           [("alias", "string", "instrument alias"),
            ("quantity", "string", "quantity name from list_instruments")], ["alias", "quantity"], 0, function (args)
        r = resolveaddr(get(args, "alias", ""))
        r === nothing && return "unknown alias \"$(get(args, "alias", ""))\""
        return ai_test_quantity(r[1], r[2], get(args, "quantity", ""))
    end),
    AITool("read_raw", "Raw read from the instrument WITHOUT writing first (the Communication Test 'Read' button). Usually only meaningful right after a write - prefer query_command or read_quantity otherwise.",
           [("alias", "string", "instrument alias")], ["alias"], 0, function (args)
        r = resolveaddr(get(args, "alias", ""))
        r === nothing && return "unknown alias"
        return ai_read_raw(r[1], r[2])
    end),
    AITool("get_recent_errors", "Read the most recent Error/Warning entries from today's application log (same file the Logger window shows). Use this FIRST when the user reports a failure, a task crashed, an instrument times out, or anything looks abnormal - do not ask the user to paste errors.",
           [("n", "integer", "how many recent entries (default 8, max 30)")], [], 0, function (args)
        n = tryparse(Int, string(get(args, "n", "8")))
        return ai_recent_errors(n === nothing ? 8 : n)
    end),
    AITool("write_command", "Write a raw command to an instrument (terminator added automatically). The alias parameter also accepts a raw ADDRESS (e.g. an unregistered instrument under \"Others\"). REQUIRES CONFIRMATION (skipped inside an active debug session).",
           [("alias", "string", "instrument alias or raw address"), ("cmd", "string", "raw command without terminator")],
           ["alias", "cmd"], 1, function (args)
        r = resolveaddr(get(args, "alias", ""))
        r === nothing && return "unknown alias or address"
        cmd = get(args, "cmd", "")
        indebugsession(r[2]) || ai_confirm("Write Command", "$(r[1]) @ $(r[2])\n> $cmd") || return "user declined"
        out = ai_write(r[1], r[2], cmd)
        ai_mirrortolog(r[1], r[2], "write: $cmd" * (out == "written OK" ? "" : "\n" * first(out, 200)))
        return out
    end),
    AITool("query_command", "Write a raw command then read the response. The alias parameter also accepts a raw ADDRESS. REQUIRES CONFIRMATION (skipped inside an active debug session).",
           [("alias", "string", "instrument alias or raw address"), ("cmd", "string", "query command")],
           ["alias", "cmd"], 1, function (args)
        r = resolveaddr(get(args, "alias", ""))
        r === nothing && return "unknown alias or address"
        cmd = get(args, "cmd", "")
        indebugsession(r[2]) || ai_confirm("Query Command", "$(r[1]) @ $(r[2])\n> $cmd") || return "user declined"
        out = ai_query(r[1], r[2], cmd)
        ai_mirrortolog(r[1], r[2], "query: $cmd\n< " * first(out, 200))
        return out
    end),
    AITool("set_quantity", "Set a settable/sweepable quantity to a value (with read-back check). REQUIRES CONFIRMATION (skipped inside an active debug session).",
           [("alias", "string", "instrument alias"),
            ("quantity", "string", "quantity name"),
            ("value", "number", "target value (in the default unit shown by list_instruments)")],
           ["alias", "quantity", "value"], 1, function (args)
        r = resolveaddr(get(args, "alias", ""))
        r === nothing && return "unknown alias or address"
        qtnm = get(args, "quantity", "")
        v = get(args, "value", nothing)
        indebugsession(r[2]) || ai_confirm("Set Quantity", "$(r[1]) @ $(r[2])\n$qtnm = $v") || return "user declined"
        out = ai_set_quantity(r[1], r[2], qtnm, v)
        ai_mirrortolog(r[1], r[2], "set $qtnm = $v" * (out == "" ? "" : "\n< " * first(out, 200)))
        return out
    end),
    AITool("test_driver_get", "Call a hand-written driver get function by NAME (e.g. \"ILM200_heliumlevel_get\") without needing the quantity registered - single-unit-test while iterating on a driver. Reports the raw response and numeric-parse verdict. Failures include the root cause.",
           [("alias", "string", "instrument alias or raw address"),
            ("func", "string", "complete function name, e.g. \"ILM200_heliumlevel_get\" (see get_driver for existing names)")],
           ["alias", "func"], 0, function (args)
        r = resolveaddr(get(args, "alias", ""))
        r === nothing && return "unknown alias or address"
        func = get(args, "func", "")
        out = ai_test_driver_get(r[1], r[2], func)
        ai_mirrortolog(r[1], r[2], "get $func → " * first(out, 120))
        return out
    end),
    AITool("test_driver_set", "Call a hand-written driver set function by NAME with a value (no quantity registration needed). REQUIRES CONFIRMATION (skipped inside an active debug session).",
           [("alias", "string", "instrument alias or raw address"),
            ("func", "string", "complete function name, e.g. \"ILM200_heliumlevelrmode_set\""),
            ("val", "number", "value to write (string when the quantity is unitless)")],
           ["alias", "func", "val"], 1, function (args)
        r = resolveaddr(get(args, "alias", ""))
        r === nothing && return "unknown alias or address"
        func = get(args, "func", "")
        v = get(args, "val", "")
        indebugsession(r[2]) || ai_confirm("Test Driver Set", "$(r[1]) @ $(r[2])\n$func($v)") || return "user declined"
        out = ai_test_driver_set(r[1], r[2], func, v)
        ai_mirrortolog(r[1], r[2], "call $func($v)" * (out == "set written OK" ? "" : "\n" * first(out, 200)))
        return out
    end),
    AITool("driver_probe", "Run a short command sequence (write/query/read/sleep) in ONE connection session and return the full transcript with each raw response. Use it to explore and verify multi-command protocols (e.g. set control mode first, then query readings) - web manuals alone cannot be trusted for such sequences. The alias parameter also accepts a raw ADDRESS. REQUIRES CONFIRMATION (skipped inside an active debug session).",
           [("alias", "string", "instrument alias or raw address"),
            ("steps", "array", "step objects, each single-key: {\"write\": cmd} | {\"query\": cmd} | {\"read\": \"\"} | {\"sleep\": seconds}. Max 12 steps, sleep <= 5s each / 15s total")],
           ["alias", "steps"], 2, function (args)
        r = resolveaddr(get(args, "alias", ""))
        r === nothing && return "unknown alias or address"
        raw = get(args, "steps", [])
        raw isa Vector || return "steps must be an array of single-key objects"
        length(raw) > 12 && return "too many steps (max 12)"
        steps = Tuple{String,String}[]
        total = 0.0
        for (i, s) in enumerate(raw)
            s isa AbstractDict || return "step #$i must be an object"
            length(keys(s)) == 1 || return "step #$i must have exactly one key (write/query/read/sleep)"
            k = String(first(keys(s)))
            v = string(first(values(s)))
            k in ("write", "query", "read", "sleep") || return "step #$i: unknown op \"$k\" (use write/query/read/sleep)"
            if k == "sleep"
                fv = tryparse(Float64, v)
                (fv === nothing || fv < 0) && return "step #$i: sleep must be a non-negative number"
                fv > 5 && (v = "5.0")
                total += min(fv, 5.0)
            end
            push!(steps, (k, v))
        end
        total > 15 && return "total sleep too long (max 15s)"
        preview = join(["  " * (op == "read" ? "read" : "$op: " * first(arg, 60)) for (op, arg) in steps], "\n")
        indebugsession(r[2]) || ai_confirm("Driver Probe", "$(r[1]) @ $(r[2])\n$preview") || return "user declined"
        out = ai_driver_probe(r[1], r[2], steps)
        ai_mirrortolog(r[1], r[2], first(out, 1000))
        return out
    end),
    AITool("set_comm_attr", "Change a communication attribute of an instrument connection: idnfunc, timeoutw, timeoutr, querydelay (seconds, >=0.1) or baudrate (serial instruments only). Same channel as the GUI's Communication Test settings - saved and synced to the I/O worker. Use it when connection trouble points at wrong timeouts or serial parameters, or when a driver needs a settle delay.",
           [("alias", "string", "instrument alias or raw address"),
            ("key", "string", "idnfunc | timeoutw | timeoutr | querydelay | baudrate"),
            ("value", "number", "new value (idnfunc takes a string)")],
           ["alias", "key", "value"], 2, function (args)
        alias = get(args, "alias", "")
        r = resolveaddr(alias)
        r === nothing && return "FAILED: unknown alias or address \"$alias\""
        key = get(args, "key", "")
        v = get(args, "value", "")
        ai_confirm("Set Communication Attribute", "$(r[1]) @ $(r[2])\n$key = $v") || return "user declined"
        return ai_set_comm_attr(alias, key, v)
    end),
    AITool("enable_debug_session", "Open a driver-debugging window: for N minutes (1-30) the write/query/set/probe tools skip their per-call confirmation dialogs for ONE instrument - one confirmation now instead of one per step, under the user's supervision. Every action is still recorded in the transcript and mirrored to the instrument window. REQUIRES CONFIRMATION.",
           [("alias", "string", "instrument alias"),
            ("minutes", "integer", "session length in minutes (1-30)")],
           ["alias", "minutes"], 2, function (args)
        m = tryparse(Float64, string(get(args, "minutes", "10")))
        m === nothing && return "FAILED: minutes must be a number"
        return ai_enable_debug_session(get(args, "alias", ""), m)
    end),
    AITool("create_task", "Create a measurement task from a QInsControl DSL script (see DSL reference). The user will review and run it. REQUIRES CONFIRMATION.",
           [("name", "string", "task name"),
            ("script", "string", "complete task script following the DSL reference")],
           ["name", "script"], 2, function (args)
        name = get(args, "name", "AI Task")
        script = get(args, "script", "")
        strip(String(name)) == "" && return "FAILED: task name must not be empty"
        #名字会进树视图与 list_tasks 的行式输出,换行会破坏解析,引号同理截断
        occursin(r"[\r\n\"]", String(name)) &&
            return "FAILED: task name must not contain line breaks or double quotes"
        ok, blocks, err = ai_validate_script(script)
        ok || return "script validation failed: $err\nFix the script and call create_task again."
        #全 NullBlock(空脚本/纯注释)对空表也非空,须显式拦下
        all(b -> b isa qc.NullBlock, blocks) &&
            return "script parsed to an empty task, please provide a real script"
        summary = join(first(blocksummary(blocks), BLOCKS_SUMMARY_LIMIT), "\n")
        ai_confirm("Create Task", "task \"$name\"\n$summary") || return "user declined"
        ai_add_task(name, script, blocks)
        return "task \"$name\" created with $(length(blocks)) blocks. It is now in the task list for the user to review and run."
    end),
    AITool("update_task_script", "Replace the script of an existing task. REQUIRES CONFIRMATION.",
           [("task", "string", "existing task name"),
            ("script", "string", "complete replacement script")],
           ["task", "script"], 2, function (args)
        taskname = String(get(args, "task", ""))
        #与 update_plot 同款存在性检查:校验后再确认,不存在直接拒绝——旧行为是弹窗、
        #用户确认后静默什么都不改,还回报"updated with N blocks"假成功
        any(t -> t.name == taskname, qc.leafvalues(qc.taskroot())) ||
            return "FAILED: task \"$taskname\" not found; call list_tasks for names"
        ok, blocks, err = ai_validate_script(get(args, "script", ""))
        ok || return "script validation failed: $err\nFix the script and call update_task_script again."
        summary = join(first(blocksummary(blocks), BLOCKS_SUMMARY_LIMIT), "\n")
        ai_confirm("Update Task", "task \"$taskname\"\n$summary") || return "user declined"
        ai_update_task(taskname, get(args, "script", ""), blocks)
        return "task \"$taskname\" updated with $(length(blocks)) blocks."
    end),
    AITool("delete_task", "Delete a task from the project tree by name (e.g. to clean up a scratch/failed task you created earlier). In-memory until save_project persists it. REQUIRES CONFIRMATION.",
           [("task", "string", "task name exactly as shown by list_tasks")],
           ["task"], 2, function (args)
        taskname = String(get(args, "task", ""))
        taskname == "" && return "FAILED: task name must not be empty"
        ai_confirm("Delete Task", "delete task \"$taskname\" from the project tree?") || return "user declined"
        return ai_delete_task(taskname)
    end),
    AITool("save_project", "Save the currently open project to disk (tasks, plots, aliases, circuit) - in-memory changes (tasks/plots created this session) are lost on app restart unless saved. Call this after creating experiments the user wants to keep. REQUIRES CONFIRMATION.",
           [], [], 2, function (_)
        ai_confirm("Save Project", "save the currently open project (all tasks, plots, aliases, circuit) to disk?") || return "user declined"
        return ai_save_project()
    end),
    AITool("delete_plot", "Delete a plot from the plot tree by name (e.g. to clean up plots you created earlier). In-memory until save_project persists it. REQUIRES CONFIRMATION.",
           [("name", "string", "plot name exactly as shown by list_plots")],
           ["name"], 2, function (args)
        plotname = String(get(args, "name", ""))
        plotname == "" && return "FAILED: plot name must not be empty"
        ai_confirm("Delete Plot", "delete plot \"$plotname\" from the plot tree?") || return "user declined"
        return ai_delete_plot(plotname)
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
        #空闲时拒绝且不动标志:IsInterrupted 置位后由扫描函数消费,闲置置位会让下一次
        #测量一开跑就被当成"已请求中断"瞬间终止
        qc.SYNCSTATES[qc.IsDAQTaskRunning] ||
            return "FAILED: no DAQ task is running (nothing to interrupt)"
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
    AITool("search_history", "Keyword-search past conversation archives (markdown exports, newest first, up to 60 sessions). Use it to recall how earlier experiments were configured, what failed before, or what the user preferred. Local grep - no network.",
           [("keyword", "string", "keyword to search for, e.g. \"diamond\", \"ILM200\", \"菱形\"")],
           ["keyword"], 0, function (args)
        ai_search_history(get(args, "keyword", ""))
    end),
    AITool("remember", "Persist ONE lesson from this conversation for all future sessions (single line, 1-500 chars): a validated experiment pattern, an instrument quirk, or a user preference. Auto-injected into every future conversation; auto-rotated (oldest dropped) when full. Content is visible to the user in Assets/AI/memory.md.",
           [("text", "string", "one-line lesson, e.g. \"菱形扫描: 外层 for + @settingblock 变量 + 内层两段式表达式 stop\"")],
           ["text"], 0, function (args)
        ai_remember(get(args, "text", ""))
    end),
    AITool("write_driver", "Write (or replace) the hand-written driver file Assets/ExtraLoad/<instrument>.jl and hot-load it on the I/O worker. For non-standard protocol functions (<ins>_<qt>_get/set). REQUIRES CONFIRMATION.",
           [("instrument", "string", "instrument name (file base name)"),
            ("code", "string", "complete Julia source of the driver file")],
           ["instrument", "code"], 2, function (args)
        name = get(args, "instrument", "")
        code = get(args, "code", "")
        strip(code) == "" && return "FAILED: empty driver code"
        #写盘前先过一遍语法:坏文件会随每次启动/热加载在 worker 上报错,
        #且 create_task/create_instrument/create_widget 都有写前校验,这里补齐同款。
        #注意 parseall 不抛异常而是把 Expr(:error/:incomplete) 嵌进 AST,须递归扫出
        err = try
            synerrcode(Meta.parseall(String(code); filename="driver_" * sanename(name) * ".jl"))
        catch e
            first(sprint(showerror, e), 300)
        end
        err != "" &&
            return "FAILED: driver code has Julia syntax errors: $err\nFix the code and call write_driver again."
        #确认框必须让用户能看清将执行的全部内容:只截 2000 字符时尾部代码等于盲签
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
    AITool("list_plots", "List the user's live plots (name and series count).",
           [], [], 0, function (_)
        ai_list_plots()
    end),
    AITool("get_plot", "Read a plot's full configuration as JSON (same schema create_plot/update_plot take: layout + series with x/y/z/w columns and GLMakie codes). Use before modifying an existing plot.",
           [("name", "string", "plot name from list_plots")],
           ["name"], 0, function (args)
        ai_get_plot(get(args, "name", ""))
    end),
    AITool("create_plot", "Create a live plot from a JSON config: {\"layout\": \"GLMakie layout codes\", \"series\": [{\"index\": 1, \"x\": \"<data key>\", \"y\": \"<data key>\", \"processcodes\": \"...\", \"plotcodes\": \"...\"}]}. Follow the plot configuration reference for the code fields; columns may reference data keys a future task will write (warned, NaN until then). REQUIRES CONFIRMATION.",
           [("name", "string", "new plot name"),
            ("cfg", "string", "the JSON config object itself (not fenced)")],
           ["name", "cfg"], 2, function (args)
        name = get(args, "name", "AI Plot")
        cfg = try
            normalizejson(JSON.parse(String(get(args, "cfg", ""))))
        catch
            return "FAILED: cfg must be a valid JSON object"
        end
        cfg isa AbstractDict || return "cfg must be a JSON object"
        err, warn = ai_validate_plotcfg(cfg)
        err == "" || return "plot config validation failed: $err\nFix the config and call create_plot again."
        ai_confirm("Create Plot", "plot \"$name\"" * (warn == "" ? "" : "\nWARN: $warn")) || return "user declined"
        ai_add_plot(name, cfg)
        return "plot \"$name\" created. It shows the current data and live-updates while tasks run." *
               (warn == "" ? "" : "\nWARN: $warn")
    end),
    AITool("update_plot", "Replace a plot's configuration. Call get_plot first, modify the JSON, send the complete config back. REQUIRES CONFIRMATION.",
           [("name", "string", "existing plot name"),
            ("cfg", "string", "the complete JSON config object")],
           ["name", "cfg"], 2, function (args)
        name = get(args, "name", "")
        cfg = try
            normalizejson(JSON.parse(String(get(args, "cfg", ""))))
        catch
            return "FAILED: cfg must be a valid JSON object"
        end
        cfg isa AbstractDict || return "cfg must be a JSON object"
        err, warn = ai_validate_plotcfg(cfg)
        err == "" || return "plot config validation failed: $err\nFix and call update_plot again."
        any(p -> p.name == String(name), qc.plotleaves(qc.DAQDATAPLOTS)) ||
            return "plot \"$name\" not found; call list_plots for names"
        ai_confirm("Update Plot", "plot \"$name\"" * (warn == "" ? "" : "\nWARN: $warn")) || return "user declined"
        ai_update_plot(name, cfg)
        return "plot \"$name\" updated." * (warn == "" ? "" : "\nWARN: $warn")
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

"识别 context 超限类供应商错误(400/413 + 正文关键词):触发自愈裁剪重试。
旧行为是会话被这类 400 永久卡死——每轮重发同样的历史必然再撞。"
function iscontexterror(e)
    e isa HTTP.StatusError || return false
    e.status in (400, 413) || return false
    msg = try
        obj = JSON.parse(String(e.response.body))
        obj isa AbstractDict || return false
        err = get(obj, "error", obj)
        err isa AbstractDict ? string(get(err, "message", "")) : string(get(obj, "message", ""))
    catch
        return false
    end
    low = lowercase(msg)
    return occursin("context", low) || occursin("token", low) || occursin("too long", low) ||
           occursin("maximum", low) || occursin("length", low)
end

"按模式下发工具:普通聊天只开放只读(Level 0)工具——解释/查询不需要开 Agent;Agent 模式开放全部"
toolset(agent::Bool) = toolsschemas(agent ? AITOOLS : filter(t -> t.level == 0, AITOOLS))

"Meta.parseall/parse 语法错误不抛异常,而是把 Expr(:error/:incomplete) 嵌进 AST;
递归扫出第一个错误节点的消息,干净代码返回空串"
function synerrcode(ex, depth::Int = 0)
    depth > 64 && return ""
    ex isa Expr || return ""
    if ex.head === :error || ex.head === :incomplete
        length(ex.args) == 1 && ex.args[1] isa Base.Meta.ParseError && return ex.args[1].msg
        return first(string(ex), 300)
    end
    for a in ex.args
        (r = synerrcode(a, depth + 1)) != "" && return r
    end
    return ""
end

"分发一个工具调用(结果总是字符串,异常转错误文本回喂模型);allowwrite=false 时写工具拒绝"
function calltool(name::AbstractString, argstr::AbstractString; allowwrite::Bool=true)
    tool = get(toolmap(), String(name), nothing)
    #失败一律以 FAILED 开头:Bridge 的仪器错误已用此约定,MCP 的 isError 判定
    #(occursin "FAILED"/"user declined")也依赖它——裸错误文本会被误报成成功
    tool === nothing && return "FAILED: unknown tool \"$name\""
    (allowwrite || tool.level == 0) ||
        return "FAILED: tool \"$(tool.name)\" writes to instruments/projects and is only available in Agent mode"
    args = try
        JSON.parse(argstr == "" ? "{}" : String(argstr))
    catch
        return "FAILED: invalid arguments JSON: $(first(argstr, 200))"
    end
    args isa AbstractDict || return "FAILED: arguments must be a JSON object"
    return try
        String(tool.f(args))
    catch e
        "FAILED: tool error: " * sprint(showerror, e)
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
    sendchat!(text; agent=false, images=())

聊天总入口(UI 线程/网页端调用,内部 spawn AI 任务):压入用户消息(可带 vision 图片)→
流式请求 → 工具调用循环(仅 agent)→ 结果入历史 → 存档。同一时刻只允许一个在途请求。
"""
function sendchat!(text::AbstractString; agent::Bool = false, images = NTuple{3,String}[])
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
    resetnetbudget!()   #网络工具预算按对话轮重置
    conv = currentconv()
    conv.provider = string(prov.name, " / ", prov.model)
    pushmessage!(conv, ChatMessage("user", String(text); images = validateimages(images)))
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

"瞬态网络/供应商故障(超时、连接失败、限流、5xx):值得换通道重试;
4xx 语义错误(鉴权/参数/上下文)重试没有意义——上下文超限另有自愈分支"
function istransient(e)
    e isa HTTP.StatusError && e.status in (408, 429, 500, 502, 503, 504) && return true
    e isa Base.IOError && return true          #连接失败/对端重置(HTTP.jl 没有 ConnectException)
    msg = lowercase(sprint(showerror, e))
    for pat in ("timeout", "timed out", "connection", "eof", "reset", "dns", "unreachable")
        occursin(pat, msg) && return true
    end
    return false
end

haspartialoutput() = lock(CHATLOCK) do
    !isempty(CHAT.inflight) || !isempty(CHAT.reasoning)
end

"单轮执行:请求 → 工具调用循环(有 toolcalls 则回喂结果递归,受 maxtoolturns 约束);
tried = 已因瞬态网络故障切换过的供应商名集合,递归与故障转移间传递防乒乓"
function runturn!(conv::Conversation, prov::AIProvider; agent::Bool, turns::Int=1, tried::Set{String}=Set{String}())
    if turns > aiconf().maxtoolturns
        pushmessage!(conv, ChatMessage("assistant", mlstr("Too many tool turns, stopped.")))
        return
    end
    tools = toolset(agent)
    res = try
        chat!(ondelta(), prov, buildmessages(conv; agent); tools, stop=() -> lock(() -> CHAT.stop, CHATLOCK))
    catch e
        if CONTEXTMULT[] > 0.1 && iscontexterror(e)
            #自愈:折减历史窗口重试一次(减半),而不是让会话永久卡死在同一份超长历史上
            CONTEXTMULT[] = CONTEXTMULT[] * 0.5
            pushmessage!(conv, ChatMessage("assistant", "⚠ " * mlstr("Context window exceeded; retrying with shorter history…")))
            return runturn!(conv, prov; agent, turns)
        end
        #瞬态网络故障自愈:流式尚未吐出任何内容时,按 tried 集合换下一个供应商;
        #已有部分输出则不重试(重试会拼接重复内容),直接报错
        if istransient(e) && !haspartialoutput()
            push!(tried, prov.name)
            nxt = findfirst(p -> !(p.name in tried), aiconf().providers)
            if nxt !== nothing
                p2 = aiconf().providers[nxt]
                pushmessage!(conv, ChatMessage("assistant",
                    "⚠ network error ($(first(friendlyaierror(e), 80))); failing over to provider \"$(p2.name)\"…"))
                return runturn!(conv, p2; agent, turns, tried)
            end
            pushmessage!(conv, ChatMessage("assistant", string("⚠ ", friendlyaierror(e),
                " (providers tried: ", join(sort(collect(tried)), ", "), ")")))
            return
        end
        pushmessage!(conv, ChatMessage("assistant", string("⚠ ", friendlyaierror(e))))
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
            #工具循环停止检查点:之前 stop 只在 SSE 帧间生效,工具链(检索/抓取)执行期间无法打断,
            #用户点停止后还要跑完 16 轮。现在每个工具执行前 + 递归前都检查
            lock(() -> CHAT.stop, CHATLOCK) &&
                return pushmessage!(conv, ChatMessage("assistant", "⚠ " * mlstr("stopped by user")))
            result = calltool(get(tc, "name", ""), get(tc, "arguments", ""); allowwrite=agent)
            lock(CHATLOCK) do
                push!(CHAT.toolsteps, (String(get(tc, "name", "")), String(get(tc, "arguments", "")), result))
                CHAT.newtoken = true
            end
            pushmessage!(conv, ChatMessage("tool", result; toolcallid=String(get(tc, "id", ""))))
        end
        lock(() -> CHAT.stop, CHATLOCK) &&
            return pushmessage!(conv, ChatMessage("assistant", "⚠ " * mlstr("stopped by user")))
        return runturn!(conv, prov; agent, turns = turns + 1, tried)
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
            return runturn!(conv, prov; agent, turns = turns + 1)
        end
    end
    pushmessage!(conv, ChatMessage("assistant", res.content; reasoning=res.reasoning))
    return
end

"连通性测试(Settings 页):非流式 1 轮小请求,返回状态文本。
name 缺省用默认供应商;Settings 页传入当前编辑的供应商,测的才是表单里这一家。"
function testconnection!(status::Ref{String}, busy::Ref{Bool}, name::AbstractString = aiconf().default)
    CHAT.busy && (status[] = "chat is busy"; return)
    prov = getprovider(name)
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
