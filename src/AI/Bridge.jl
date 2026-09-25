# ============ Bridge.jl —— AI 模块与 QInsControl 其余部分的唯一边界 ============
# 强隔离规则(见 ai/ai-integration/03-architecture.md §4):
#   1. 本文件之外的 AI 代码禁止直接引用 QInsControl 的任何符号——逻辑层只调下面的
#      ai_* 适配函数(AI 无 UI 代码:前端视图在 src/Frontend/Windows/AIAssistant.jl,
#      经 QInsControlAI. 限定名调用后端,不属于本模块)。
#   2. 白名单变化必须体现在本文件的 import/注释中,评审时一目了然。
# ==============================================================================

import ..QInsControlCore: remote_write, remote_query, remote_qtread, remote_qtset, remote_include
import Sockets: Sockets, @ip_str, IPv4, IPv6   # 本地/链路本地地址判定(Bridge.jl 尾部)

const qc = parentmodule(QInsControlAI)   # 主模块 QInsControl(动态限定访问,const/非 const 通吃)

# —— 跨线程 UI 封送:AI 任务线程 → 渲染线程(MainWindow 每帧调 drain_ui!) ——
const UIQUEUE = Channel{Function}(256)

function ai_ui_enqueue(f::Function)
    put!(UIQUEUE, f)
    return
end

function drain_ui!()
    while isready(UIQUEUE)
        f = take!(UIQUEUE)
        catchlog(f, "queued AI UI action failed!!!")
    end
    return
end

# —— 写操作确认门:AI 任务线程发起,AIAssistant 窗口内弹模态应答(120s 超时=拒绝) ——
mutable struct ConfirmRequest
    title::String
    detail::String
    answer::Ref{Union{Nothing,Bool}}
end
const CONFIRMREQS = Channel{ConfirmRequest}(32)

function ai_confirm(title::AbstractString, detail::AbstractString)
    aiconf().confirmwrites || return true
    #队满=渲染端无人消费(模态由 MainWindow 每帧经 RenderAIConfirm 消费,正常不会发生):
    #直接拒绝,防止 put! 在满 Channel 上永久挂起、AI 任务卡死不复位
    isfull(CONFIRMREQS) && return false
    req = ConfirmRequest(String(title), String(detail), Ref{Union{Nothing,Bool}}(nothing))
    put!(CONFIRMREQS, req)
    timedwait(() -> req.answer[] !== nothing, 120)
    return req.answer[] === true
end

takedisplaysreq() = isready(CONFIRMREQS) ? take!(CONFIRMREQS) : nothing

# ============ 上下文快照(只读) ============

ai_language() =
    try
        String(qc.CONF.Basic.language)
    catch
        "English"
    end

function ai_alias_table()
    out = Tuple{String,String,String}[]
    for (alias, a) in qc.INSTRALIASLIST
        push!(out, (String(alias), String(a.instrnm), String(a.addr)))
    end
    return out
end

function ai_instrument_summary(withhelp::Bool)
    buf = IOBuffer()
    for (insnm, oneins) in qc.INSTRCONF
        println(buf, "  instrument \"", insnm, "\":")
        for (qtnm, qtc) in oneins.quantities
            units = haskey(qc.CONF.U, qtc.U) ? join(string.(qc.CONF.U[qtc.U]), ", ") : ""
            extra = qtc.separator == "" ? "" : " (multi-value response, separator \"$(qtc.separator)\")"
            header = qtc.cmdheader == "" ? "" : " cmdheader=\"$(qtc.cmdheader)\""
            helpnote = withhelp && qtc.help != "" ? " | help: " * qtc.help : ""
            println(buf, "    quantity \"", qtnm, "\" [", qtc.type, "]", header, " units {", units, "}", extra, helpnote)
        end
    end
    return String(take!(buf))
end

ai_instrument_names() = String[k for k in keys(qc.INSTRCONF)]

"""
    ai_search_quantities(keyword) -> String

按关键词反查全部已注册量的定义(量名/仪器/类型/cmdheader/单位/help)——
用于把"磁场/电流/温度"这类物理量映射到具体仪器量。匹配范围:量名、量别名、
仪器名、help、cmdheader(不区分大小写)。
"""
function ai_search_quantities(keyword::AbstractString)
    k = lowercase(String(keyword))
    k == "" && return "(empty keyword)"
    buf = IOBuffer()
    n = 0
    for (insnm, oneins) in qc.INSTRCONF
        if occursin(k, lowercase(insnm))
            println(buf, "instrument \"", insnm, "\" (name match) cmdtype=\"", oneins.conf.cmdtype, "\" idn=\"", oneins.conf.idn, "\"")
        end
        for (qtnm, qtc) in oneins.quantities
            hit = occursin(k, lowercase(qtnm)) || occursin(k, lowercase(qtc.alias)) ||
                  occursin(k, lowercase(qtc.help)) || occursin(k, lowercase(qtc.cmdheader))
            hit || continue
            units = haskey(qc.CONF.U, qtc.U) ? join(string.(qc.CONF.U[qtc.U]), ", ") : ""
            n += 1
            println(
                buf, "  instrument \"", insnm, "\" quantity \"", qtnm, "\" [", qtc.type, "]",
                " cmdheader=\"", qtc.cmdheader, "\" units{", units, "}",
                qtc.separator == "" ? "" : " separator=\"$(qtc.separator)\"",
                qtc.help == "" ? "" : " help: " * qtc.help
            )
        end
    end
    n == 0 && !occursin("instrument \"", String(take!(copy(buf)))) && return "no registered quantity matches \"$keyword\""
    return String(take!(buf))
end

function ai_data_keys()
    buf = IOBuffer()
    lock(qc.DATABUF) do d
        isempty(d) && print(buf, "  (empty)")
        for (k, v) in d
            last = isempty(v) ? "" : string(" | last: ", v[end][1:min(end, 40)])
            println(buf, "  \"", k, "\" (", length(v), " pts)", last)
        end
    end
    return String(take!(buf))
end

function ai_data_keylist()
    return String.(collect(lock(keys, qc.DATABUF)))
end

function ai_data_sample(key::AbstractString, n::Int)
    out = lock(qc.DATABUFPARSED) do d
        haskey(d, key) || return "key \"$key\" not found"
        v = d[key]
        n = clamp(n, 1, aiconf().maxdatasample)
        if v isa AbstractMatrix
            rows = size(v, 1)
            io = IOBuffer()
            for r in max(1, rows - n + 1):rows
                println(io, join((v[r, c] for c in axes(v, 2)), ", "))
            end
            return String(take!(io))
        else
            isempty(v) && return "(empty)"
            return join(v[max(1, end - n + 1):end], "\n")
        end
    end
    return String(out)
end

function ai_task_list()
    buf = IOBuffer()
    tasks = qc.leafvalues(qc.taskroot())
    isempty(tasks) && print(buf, "  (empty; use get_task_script to read one task's full script)")
    for t in tasks
        nblk = try
            length(t.blocks)
        catch
            0
        end
        println(buf, "  task \"", t.name, "\" (", t.textmode ? "text" : "block", " mode, $nblk blocks)")
    end
    return String(take!(buf))
end

"剥掉 AST 里的 LineNumberNode(interpret 输出会带 #= 绝对路径:行号 =# 噪音)"
function striplinenums(ex::Expr)
    args = Any[a isa LineNumberNode ? nothing : (a isa Expr ? striplinenums(a) : a) for a in ex.args]
    filter!(a -> a !== nothing, args)
    return Expr(ex.head, args...)
end
striplinenums(x) = x

"""
    ai_task_script(taskname) -> String

读一个任务的完整脚本:文本模式给 editcodes 原文,块模式经 interpret 反向转成 DSL 文本
(与 GUI 里 Interpret 按钮同一通道,剥掉行号注释);附带备注(explog)。
"""
function ai_task_script(taskname::AbstractString)
    name = String(taskname)
    for t in qc.leafvalues(qc.taskroot())
        t.name == name || continue
        buf = IOBuffer()
        println(buf, "## Task \"", t.name, "\" (", t.textmode ? "text" : "block", " mode, ", length(t.blocks), " blocks)")
        t.explog == "" || println(buf, "notes: ", t.explog)
        println(buf, "```julia")
        script = try
            t.textmode ? t.editcodes : string(striplinenums(qc.interpret(t.blocks)))
        catch e
            "(script conversion failed: " * first(sprint(showerror, e), 200) * ")"
        end
        println(buf, script)
        println(buf, "```")
        return String(take!(buf))
    end
    return "task \"$name\" not found; call list_tasks for available names"
end

ai_task_names() = String[string(mlstr("Task"), " ", OLDI + i, " ", t.name) for (i, t) in enumerate(qc.leafvalues(qc.taskroot()))]
ai_plot_names() = String[p.name for p in qc.plotleaves(qc.DAQDATAPLOTS)]

function ai_status()
    buf = IOBuffer()
    println(buf, "DAQ running: ", qc.SYNCSTATES[qc.IsDAQTaskRunning], ", blocked: ", qc.SYNCSTATES[qc.IsBlocked])
    println(buf, "instruments: ", length(qc.INSTRCONF), " registered, aliases: ", length(qc.INSTRALIASLIST))
    println(buf, "data keys: ", lock(length, qc.DATABUF))
    return String(take!(buf))
end

# ============ 仪器操作(Level 0/1 工具后端) ============

function ai_read_quantity(instrnm::AbstractString, addr::AbstractString, qtnm::AbstractString)
    qtc = haskey(qc.INSTRCONF, instrnm) && haskey(qc.INSTRCONF[instrnm].quantities, qtnm) ?
          qc.INSTRCONF[instrnm].quantities[qtnm] : nothing
    timeout = qtc === nothing ? 3.0f0 : qtc.timeoutr
    return String(remote_qtread(instrnm, addr, qtnm, 4, timeout))
end

function ai_set_quantity(instrnm::AbstractString, addr::AbstractString, qtnm::AbstractString, sv)
    qtc = haskey(qc.INSTRCONF, instrnm) && haskey(qc.INSTRCONF[instrnm].quantities, qtnm) ?
          qc.INSTRCONF[instrnm].quantities[qtnm] : nothing
    timeoutw = qtc === nothing ? 3.0f0 : qtc.timeoutw
    timeoutr = qtc === nothing ? 3.0f0 : qtc.timeoutr
    return String(remote_qtset(instrnm, addr, qtnm, sv, 4, timeoutw, timeoutr; retreading=true))
end

ai_write(instrnm::AbstractString, addr::AbstractString, cmd::AbstractString) =
    String(remote_write(instrnm, addr, String(cmd), 4))
ai_query(instrnm::AbstractString, addr::AbstractString, cmd::AbstractString) =
    String(remote_query(instrnm, addr, String(cmd), 4))

ai_interrupt!() = (qc.SYNCSTATES[qc.IsInterrupted] = true; nothing)

# ============ 脚本与工程写入(Level 2 工具后端;结构性变更一律封送 UI 线程) ============

"""
    ai_validate_script(text) -> (ok::Bool, blocks|nothing, errmsg::String)

文本脚本校验:Meta.parseall → antiinterpretblocks(与 GUI Anti-interpret 同一通道),
再加一道**别名/量名白名单检查**——antiinterpret 对不存在的 alias 会静默生成占位块,
必须在此拦下(AI 幻觉的别名应触发修复循环而不是生成坏任务)。
"""
function ai_validate_script(text::AbstractString)
    blocks = try
        ex = Meta.parseall(String(text); filename="aiscript")
        qc.antiinterpretblocks(ex)
    catch e
        return (false, nothing, sprint(showerror, e))
    end
    aliases = Set(String(a) for (a, _, _) in ai_alias_table())
    problems = String[]
    n = 0
    for bk in allscriptblocks(blocks)
        n += 1
        bk isa qc.NullBlock && continue
        propnames = try
            propertynames(bk)
        catch
            ()
        end
        :alias in propnames || continue
        bk.alias in aliases || push!(problems, "block #$n: unknown alias \"$(bk.alias)\"")
        if bk.alias in aliases && :quantity in propnames &&
           haskey(qc.INSTRCONF, bk.instrnm) && !isempty(bk.quantity)
            haskey(qc.INSTRCONF[bk.instrnm].quantities, bk.quantity) ||
                push!(problems, "block #$n: instrument \"$(bk.instrnm)\" has no quantity \"$(bk.quantity)\"")
        end
    end
    isempty(problems) || return (false, nothing, join(problems, "\n"))
    return (true, blocks, "")
end

"递归展开块树(含容器块的子块)"
function allscriptblocks(blocks)
    out = qc.AbstractBlock[]
    for bk in blocks
        bk isa qc.NullBlock && continue
        push!(out, bk)
        bk isa qc.StrideCodeBlock && append!(out, allscriptblocks(bk.blocks))
        (bk isa qc.SweepBlock || bk isa qc.FreeSweepBlock) && append!(out, allscriptblocks(bk.blocks))
    end
    return out
end

"块树 → 预览摘要行(一块一行,供预览确认窗与 create_task/update_task 工具使用)"
function blocksummary(blocks)
    lines = String[]
    for bk in blocks
        bk isa qc.NullBlock && continue
        t = nameof(typeof(bk))
        line = try
            if bk isa qc.SweepBlock
                "$t: $(bk.alias) $(bk.quantity) step=$(bk.step) stop=$(bk.stop) delay=$(bk.delay)"
            elseif bk isa qc.FreeSweepBlock
                "$t: $(bk.alias) $(bk.quantity) mode=$(bk.mode) stop=$(bk.stop) duration=$(bk.duration)"
            elseif bk isa qc.SettingBlock
                "$t: $(bk.alias) $(bk.quantity) = $(bk.setvalue) check=$(bk.ischeck)"
            elseif bk isa qc.ReadingBlock
                "$t: $(bk.alias) $(bk.quantity) index=$(bk.index) mark=$(bk.mark) async=$(bk.isasync) observe=$(bk.isobserve)"
            elseif bk isa qc.QueryBlock
                "$t: $(bk.alias) \"$(first(bk.cmd, 40))\" index=$(bk.index) mark=$(bk.mark)"
            elseif bk isa qc.WriteBlock
                "$t: $(bk.alias) \"$(first(bk.cmd, 40))\""
            elseif bk isa qc.ReadBlock
                "$t: $(bk.alias) index=$(bk.index) mark=$(bk.mark)"
            elseif bk isa qc.FeedbackBlock
                "$t: $(bk.alias) $(bk.action)"
            elseif bk isa qc.StrideCodeBlock
                "$t: $(first(bk.codes, 60))"
            elseif bk isa qc.BranchBlock
                "$t: $(first(bk.codes, 60))"
            elseif bk isa qc.CodeBlock
                "$t: $(first(replace(bk.codes, '\n' => ' '), 60))"
            else
                string(t)
            end
        catch
            string(t)
        end
        push!(lines, line)
    end
    return lines
end

function ai_add_task(name::AbstractString, script::AbstractString, blocks)
    ai_ui_enqueue() do
        task = qc.DAQTask(
            name=String(name),
            blocks=collect(qc.AbstractBlock, blocks),
            editcodes=String(script),
            textmode=false,
            showeditor=true
        )
        push!(qc.taskroot().children, qc.Tree(task))
    end
    return
end

function ai_update_task(taskname::AbstractString, script::AbstractString, blocks)
    ai_ui_enqueue() do
        for t in qc.leafvalues(qc.taskroot())
            t.name == String(taskname) || continue
            t.blocks = collect(qc.AbstractBlock, blocks)
            t.editcodes = String(script)
            t.textmode = false
            t.showeditor = true
            break
        end
    end
    return
end

function ai_add_alias(alias::AbstractString, instrnm::AbstractString, addr::AbstractString)
    ai_ui_enqueue() do
        qc.INSTRALIASLIST[String(alias)] = qc.InstrAlias(alias=String(alias), instrnm=String(instrnm), addr=String(addr))
    end
    return
end

# ============ 绘图写入(Deepcopy 副本上先校验,再经 UI 队列落位) ============

"""
    ai_validate_plotcfg(cfg) -> errmsg::String(空串=通过)

校验 AI 产出的绘图配置:列名必须在 DATABUF 键白名单内(或空)。
"""
function ai_validate_plotcfg(cfg::Dict)
    whitelist = ai_data_keylist()
    for (fld, key) in (("x", "x"), ("y", "y"), ("z", "z"), ("w", "w"))
        for s in get(cfg, "series", Any[])
            v = get(s, key, "")
            (v isa AbstractString && (v == "" || v in whitelist)) ||
                return "series $(key)-column \"$v\" is not a valid data key"
        end
    end
    return ""
end

function applyplotcfg!(dtp, cfg::AbstractDict)
    haskey(cfg, "layout") && cfg["layout"] isa AbstractString && !isempty(cfg["layout"]) && begin
            dtp.dtpk.codes = qc.CodeBlock(codes=String(cfg["layout"]))
            dtp.dtpk.updatelayout = true
        end
    for s in get(cfg, "series", Any[])
        s isa AbstractDict || continue
        idx = tryparse(Int, string(get(s, "index", 0)))
        dtss = (idx === nothing || idx < 1 || idx > length(dtp.dtpk.series)) ? nothing : dtp.dtpk.series[idx]
        if dtss === nothing
            push!(dtp.dtpk.series, qc.DataSeries())
            dtss = dtp.dtpk.series[end]
        end
        for fld in (:x, :y, :z, :w)
            v = get(s, string(fld), nothing)
            v isa AbstractString && setproperty!(dtss, fld, String(v))
        end
        aux = get(s, "aux", nothing)
        aux isa Vector && (dtss.aux = String.(aux))
        for fld in (:processcodes, :processfigurecodes, :plotcodes)
            v = get(s, string(fld), nothing)
            v isa AbstractString && !isempty(v) && setproperty!(dtss, fld, qc.CodeBlock(codes=String(v)))
        end
        dtss.updateprocessfunc = true
        dtss.updateprocessfigurefunc = true
        dtss.updateplot = true
        dtss.update = true
    end
    dtp.dtpk.update = true
    return dtp
end

function ai_add_plot(name::AbstractString, cfg::Dict)
    ai_ui_enqueue() do
        dtp = qc.DataPlot(name=String(name))
        applyplotcfg!(dtp, cfg)
        dtp.showplot = true
        push!(qc.DAQDATAPLOTS.children, qc.Tree(dtp))
    end
    return
end

function ai_update_plot(name::AbstractString, cfg::Dict)
    ai_ui_enqueue() do
        for p in qc.plotleaves(qc.DAQDATAPLOTS)
            p.name == String(name) || continue
            applyplotcfg!(p, cfg)
            break
        end
    end
    return
end

# ============ 仪器驱动读写(写已有仪器新驱动 / 注册新仪器;Level 2 工具后端) ============
# 驱动体系两件套:Confs/<name>.toml(注册表:conf.idn/cmdtype + 各量定义) +
# ExtraLoad/<name>.jl(手写 set/get 函数,worker 上 include)。cmdtype 非空且 cmdheader
# 非空的量由 gen_qtfunc 自动生成 <ins>_<qt>_get/set;ExtraLoad 先于代码生成加载,
# 同名函数会被代码生成覆盖——手写量的 cmdheader 必须留空。

sanename(name::AbstractString) = String(filter(c -> isletter(c) || isdigit(c) || c in "-_", String(name)))

conffile(name::AbstractString) = joinpath(assetsdir(), "Confs", sanename(name) * ".toml")
driverfile(name::AbstractString) = joinpath(assetsdir(), "ExtraLoad", sanename(name) * ".jl")

"""
    ai_driver_info(name) -> String

汇总一台仪器的注册信息与当前驱动源码,供 AI 修改已有驱动前阅读。
包含:conf(idn/cmdtype)、各量定义(cmdheader/type/单位/help)、可用单位类型表(CONF.U 键)、
ExtraLoad 驱动文件内容。
"""
function ai_driver_info(name::AbstractString)
    buf = IOBuffer()
    insnm = String(name)
    println(buf, "## Instrument \"", insnm, "\"")
    if haskey(qc.INSTRCONF, insnm)
        oneins = qc.INSTRCONF[insnm]
        println(buf, "conf.idn = \"", oneins.conf.idn, "\"  conf.cmdtype = \"", oneins.conf.cmdtype, "\"")
        for (qtnm, qtc) in oneins.quantities
            units = haskey(qc.CONF.U, qtc.U) ? join(string.(qc.CONF.U[qtc.U]), ", ") : ""
            println(
                buf, "  quantity \"", qtnm, "\" [", qtc.type, "] cmdheader=\"", qtc.cmdheader,
                "\" unittype=\"", qtc.U, "\" units{", units, "} separator=\"", qtc.separator, "\"",
                qtc.help == "" ? "" : " help: " * qtc.help
            )
        end
    else
        println(buf, "(not registered in INSTRCONF)")
    end
    println(buf, "Available unit types (conf quantity field U must be one of these keys):")
    println(buf, "  ", join(sort(collect(keys(qc.CONF.U))), ", "))
    df = driverfile(insnm)
    println(buf, "## Driver file ", df, isfile(df) ? ":" : ":\n(not created yet)")
    isfile(df) && println(buf, read(df, String))
    return String(take!(buf))
end

"""
    ai_validate_conftoml(text) -> errmsg::String(空串 = 通过)

校验 AI 产出的仪器注册 TOML:conf 表必备字段、量定义字段与取值。
"""
function ai_validate_conftoml(text::AbstractString)
    conf = try
        TOML.parse(String(text))
    catch e
        return "TOML parse error: " * sprint(showerror, e)
    end
    haskey(conf, "conf") || return "missing [conf] table"
    conf["conf"] isa AbstractDict || return "[conf] must be a table"
    haskey(conf["conf"], "idn") || return "missing conf.idn (IDN keywords, ';' separated)"
    cmdtype = string(get(conf["conf"], "cmdtype", ""))
    cmdtype in ("", "scpi", "tsp") || return "conf.cmdtype must be \"\", \"scpi\" or \"tsp\""
    nq = 0
    for (k, v) in conf
        k == "conf" && continue
        v isa AbstractDict || return "quantity [$k] must be a table"
        t = string(get(v, "type", "set"))
        t in ("read", "set", "sweep") || return "quantity [$k]: type must be \"read\", \"set\" or \"sweep\""
        get(v, "cmdheader", "") isa AbstractString || return "quantity [$k]: cmdheader must be a string"
        nq += 1
    end
    nq == 0 && return "no quantity tables defined (every quantity is a [name] table)"
    return ""
end

"写已有仪器的新驱动(ExtraLoad/<name>.jl)并在 worker 上热加载"
function ai_write_driver(name::AbstractString, code::AbstractString)
    path = driverfile(name)
    mkpath(dirname(path))
    open(path, "w") do io
        print(io, String(code))
    end
    remote_include(path)
    return path
end

"""
    ai_create_instrument(name, conftoml, drivercode) -> String

注册新仪器:写 Confs/<name>.toml + ExtraLoad/<name>.jl(可选),再 loadinsconf() 全量
重载注册(与启动时同一通道)。drivercode 为空串时跳过驱动文件。
"""
function ai_create_instrument(name::AbstractString, conftoml::AbstractString, drivercode::AbstractString)
    err = ai_validate_conftoml(conftoml)
    err != "" && return err
    cpath = conffile(name)
    open(cpath, "w") do io
        print(io, String(conftoml))
    end
    dpath = ""
    if !isempty(strip(String(drivercode)))
        dpath = driverfile(name)
        mkpath(dirname(dpath))
        open(dpath, "w") do io
            print(io, String(drivercode))
        end
    end
    qc.loadinsconf()
    return string(
        "instrument \"", sanename(name), "\" registered (", cpath,
        dpath == "" ? "" : " + " * dpath,
        "); INSTRCONF now has ", length(qc.INSTRCONF), " instruments. ",
        "Add it to the project via the alias editor, then it can be used in scripts."
    )
end

# ============ 联网查手册(web_search / fetch_url;Level 0,受 allowweb 开关约束) ============

striptags(html::AbstractString) = begin
    t = replace(String(html), r"<script.*?</script>"s => "", r"<style.*?</style>"s => "")
    t = replace(t, r"<[^>]*>" => " ")
    for (ent, ch) in ("&amp;" => "&", "&lt;" => "<", "&gt;" => ">", "&quot;" => "\"", "&#x27;" => "'", "&nbsp;" => " ")
        t = replace(t, ent => ch)
    end
    replace(t, r"\s+" => " ")
end

function ai_web_search(query::AbstractString)
    aiconf().allowweb || return "web access is disabled in AI settings"
    q = HTTP.escapeuri(String(query))
    headers = ["User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"]
    # Bing(国内可达)优先,DuckDuckGo 兜底;都失败则提示
    try
        resp = HTTP.get("https://www.bing.com/search?q=$q&count=10"; headers, request_timeout=15, retry=false)
        html = String(resp.body)
        results = String[]
        for m in eachmatch(r"<h2><a[^>]*href=\"(http[^\"]+)\"[^>]*>(.*?)</a>"s, html)
            push!(results, string(striptags(m.captures[2]), "\n  ", m.captures[1]))
        end
        isempty(results) || return join(first(results, 8), "\n")
    catch
    end
    try
        resp = HTTP.get("https://html.duckduckgo.com/html/?q=$q"; headers, request_timeout=15, retry=false)
        html = String(resp.body)
        results = String[]
        for m in eachmatch(r"class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>"s, html)
            href = String(m.captures[1])
            uddg = match(r"uddg=([^&]+)", href)
            uddg === nothing || (href = HTTP.URIs.unescapeuri(String(uddg.captures[1])))
            push!(results, string(striptags(m.captures[2]), "\n  ", href))
        end
        isempty(results) || return join(first(results, 8), "\n")
    catch
    end
    return "web search failed (network unreachable or engines blocked); try fetch_url with a direct documentation URL"
end

"SSRF 防护:fetch_url 是免确认工具,内网/环回地址一律拒绝——否则模型可借它探打本机
无鉴权服务(WebDashboard/QIC server 等)并把响应带回会话"
function isprivatenethost(host::AbstractString)
    h = String(host)
    isempty(h) && return true
    ip = try
        IPAddr(h)
    catch
        try
            getalladdrinfo(h)[1] #域名:解析首地址(DNS rebinding 的 TOCTOU 窗口在此威胁模型下可接受)
        catch
            return true #解析失败按拒绝处理
        end
    end
    return isprivate(ip) || isloopback(ip) ||
           (ip isa IPv4 && (ip.addr & 0xffff0000 == 0xa9fe0000 || ip.addr == 0x00000000)) || #169.254.0.0/16 链路本地与 0.0.0.0;ip"..." 不支持 CIDR 后缀,用位掩码
           (ip isa IPv6 && ip.addr >> 118 == 0x3fa) #fe80::/10 链路本地
end

function ai_fetch_url(url::AbstractString)
    aiconf().allowweb || return "web access is disabled in AI settings"
    u = String(url)
    startswith(u, "http") || (u = "https://" * u)
    host = try
        HTTP.URIs.URI(u).host
    catch
        ""
    end
    isprivatenethost(host) &&
        return "fetching private/loopback addresses is not allowed (SSRF protection)"
    try
        resp = HTTP.get(u; request_timeout=20, retry=false, headers=["User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"])
        ctype = lowercase(get(Dict(resp.headers), "Content-Type", ""))
        occursin("pdf", ctype) &&
            return "the page is a binary PDF which cannot be parsed; search for an HTML version or the vendor's SCPI command reference page"
        return first(striptags(String(resp.body)), 20000)
    catch e
        return "fetch failed: " * first(sprint(showerror, e), 200)
    end
end

# ============ 仪器 Widget(控制面板;Level 2 工具后端) ============
# Widget 与 GUI 设计器完全等效:整个面板就是 Assets/Widgets/<instrnm>.toml,
# 缺失字段取内置默认值(通用 Dict 构造器),写好文件后 loadinswconf() 热重载即生效。

widgetsfile(name::AbstractString) = joinpath(assetsdir(), "Widgets", sanename(name) * ".toml")

# uitype 合法清单(源:InstrWidget.jl optionsmenu 的 let 局部,此处镜像,改那边记得同步)
const WIDGET_UITYPES = Dict(
    "sweep" => ["read", "unit", "readunit", "inputstep", "inputstop", "dragdelay", "progressbar", "ctrlsweep"],
    "set" => ["read", "unit", "readunit", "inputset", "inputctrlset", "ctrlset", "combo", "radio", "slider", "vslider", "toggle"],
    "read" => ["read", "unit", "readunit", "readdashboard", "readdashboarddigits", "readdashboarddigitsunit"],
    "_Panel_" => ["none"],
    "_Shape_" => ["rect", "triangle", "circle", "line"],
    "_Image_" => ["none"],
    "_QuantitySelector_" => ["combo", "slider", "vslider"],
    "none" => ["none"],
)
const WIDGET_OPTIONTYPES = ["combo", "radio", "slider", "vslider", "toggle"]  # 需要量定义 optvalues
const WIDGET_SPECIALS = ["_Panel_", "_Shape_", "_Image_", "_QuantitySelector_"]

"""
    ai_widget_info(instrnm) -> String

Widget 构建的全部事实:量的注册信息(name/type/optvalues 数目与取值/numread/separator/help)、
允许的 uitype 清单、当前 widget 文件内容(若有)。
"""
function ai_widget_info(instrnm::AbstractString)
    buf = IOBuffer()
    insnm = String(instrnm)
    println(buf, "## Widget facts for \"", insnm, "\"")
    if haskey(qc.INSTRCONF, insnm)
        for (qtnm, qtc) in qc.INSTRCONF[insnm].quantities
            println(
                buf, "  quantity \"", qtnm, "\" [", qtc.type, "] numoptvs=", length(qtc.optvalues),
                " optvalues=", qtc.optvalues, " numread=", qtc.numread,
                qtc.separator == "" ? "" : " separator=\"$(qtc.separator)\"",
                qtc.help == "" ? "" : " help: " * qtc.help
            )
        end
    else
        println(buf, "  (instrument \"", insnm, "\" not registered)")
    end
    println(buf, "allowed uitypes: ", WIDGET_UITYPES)
    wf = widgetsfile(insnm)
    println(buf, "## Widget file ", wf, isfile(wf) ? ":" : ":\n(not created yet; a new file defines the panel from scratch)")
    isfile(wf) && println(buf, read(wf, String))
    return String(take!(buf))
end

"""
    ai_validate_widgettoml(text, instrnm) -> errmsg::String(空串 = 通过)

校验 AI 产出的 widget TOML:语法、真实构造器类型检查、量名存在性、qtype/uitype 兼容性、
numoptvs 匹配、特殊元素规则。
"""
function ai_validate_widgettoml(text::AbstractString, instrnm::AbstractString)
    conf = try
        TOML.parse(String(text))
    catch e
        return "TOML parse error: " * sprint(showerror, e)
    end
    isempty(conf) && return "no widget table defined"
    insnm = String(instrnm)
    haskey(qc.INSTRCONF, insnm) ||
        return "instrument \"$insnm\" is not registered; register it first (create_instrument)"
    quantities = qc.INSTRCONF[insnm].quantities
    for (wname, w) in conf
        w isa AbstractDict || return "[$wname] must be a table"
        # 真实构造器类型检查(与 loadinswconf 同通道;缺失字段取默认值)
        try
            qc.InstrWidget(Dict{String,Any}(w))
        catch e
            return "[$wname] failed to construct InstrWidget: " * first(sprint(showerror, e), 200)
        end
        get(w, "instrnm", insnm) == insnm || return "[$wname]: instrnm must be \"$insnm\""
        qtws = get(w, "qtws", nothing)
        qtws isa AbstractVector || (isempty(qtws) && return "[$wname]: no [[qtws]] entries defined")
        qtws isa AbstractVector || return "[$wname]: qtws must be an array of tables"
        for (i, qtw) in enumerate(qtws)
            qtw isa AbstractDict || return "[$wname] qtws#$i must be a table"
            qtn = string(get(qtw, "name", ""))
            opts = get(qtw, "options", Dict())
            opts isa AbstractDict || return "[$wname] qtws#$i: options must be a table"
            uitype = string(get(opts, "uitype", "none"))
            if qtn in WIDGET_SPECIALS
                allowed = get(WIDGET_UITYPES, qtn, ["none"])
                uitype in allowed ||
                    return "[$wname] qtws#$i (\"$qtn\"): uitype \"$uitype\" not allowed (use one of $allowed)"
                continue
            end
            haskey(quantities, qtn) || return "[$wname] qtws#$i: quantity \"$qtn\" does not exist on \"$insnm\""
            qtc = quantities[qtn]
            qtwqtype = string(get(qtw, "qtype", "none"))
            qtwqtype == qtc.type ||
                return "[$wname] qtws#$i (\"$qtn\"): qtype \"$qtwqtype\" but the quantity is [$(qtc.type)]"
            uitype in get(WIDGET_UITYPES, qtc.type, ["none"]) ||
                return "[$wname] qtws#$i (\"$qtn\"): uitype \"$uitype\" not allowed for [$(qtc.type)] quantities"
            (uitype in WIDGET_OPTIONTYPES && length(qtc.optvalues) == 0) &&
                return "[$wname] qtws#$i (\"$qtn\"): uitype \"$uitype\" needs optvalues on the quantity (define optkeys/optvalues in the instrument TOML first)"
            tryparse(Int, string(get(qtw, "numoptvs", 0))) == length(qtc.optvalues) ||
                return "[$wname] qtws#$i (\"$qtn\"): numoptvs must be $(length(qtc.optvalues)) (quantity has $(length(qtc.optvalues)) optvalues)"
        end
    end
    return ""
end

"写 widget 文件并热重载全部 widget 注册(与 GUI 设计器保存等效)"
function ai_create_widget(instrnm::AbstractString, tomltext::AbstractString)
    path = widgetsfile(instrnm)
    mkpath(dirname(path))
    open(path, "w") do io
        print(io, String(tomltext))
    end
    qc.loadinswconf()
    n = haskey(qc.INSWCONF, String(instrnm)) ? length(qc.INSWCONF[String(instrnm)]) : 0
    return "widget saved to $path and hot-reloaded; instrument \"$instrnm\" now has $n panel(s). Open it from the instrument's widget menu."
end

# ============ Assets 目录探查(只读;让 AI 自学一切可配置项) ============
# QInsControlAssets 是几乎所有配置的单一事实源:仪器注册(Confs)/面板(Widgets)/驱动(ExtraLoad)/
# 主题(Styles)/翻译(Languages)/全局设置(Necessity/conf.toml)等。路径校验防越界。

const ASSET_TEXT_EXTS = [".toml", ".jl", ".md", ".mdown", ".txt", ".ini", ".cmd", ".json", ".cfg"]

function assets_resolve(rel::AbstractString)
    root = normpath(abspath(assetsdir()))
    rel2 = strip(String(rel), ['/', Char(0x5c), ' '])
    p = rel2 == "" ? root : normpath(joinpath(root, rel2))
    #前缀比较必须带分隔符:裸 startswith(p, root) 可被同级目录绕过(root="…/Assets" 时
    # "..\Assets_private\x" 归一化后仍以 root 字符串开头)
    p == root || startswith(p, root * Base.Filesystem.path_separator) || return nothing   # 越界拒绝(../ 等)
    return p
end

function ai_list_assets(rel::AbstractString="")
    p = assets_resolve(rel)
    p === nothing && return "path escapes the assets directory"
    isdir(p) || return "not a directory: $rel (use read_asset for files)"
    buf = IOBuffer()
    println(buf, "Contents of ", p, ":")
    for e in sort(readdir(p; join=true))
        b = basename(e)
        startswith(b, ".") && continue
        isdir(e) ? println(buf, "  [dir]  ", b, "/") :
        println(buf, "  ", b, "  (", filesize(e), " bytes)")
    end
    return String(take!(buf))
end

function ai_read_asset(rel::AbstractString)
    p = assets_resolve(rel)
    p === nothing && return "path escapes the assets directory"
    isdir(p) && return "that is a directory; use list_assets on it"
    isfile(p) || return "file not found: $rel"
    ext = lowercase(splitext(p)[2])
    ext in ASSET_TEXT_EXTS ||
        return "only text files can be read (allowed: $(join(ASSET_TEXT_EXTS, ", "))); images/fonts/binaries are not"
    text = read(p, String)
    #ai.toml 含明文 API key:本工具免确认(Level 0),内容会回喂模型并写进会话存档,
    #模型可经 fetch_url 把内容带出——key 值一律屏蔽,模型只需要看到供应商/模型等结构
    normpath(p) == normpath(aiconfpath()) &&
        (text = replace(text, r"^apikey\s*=\s*\"[^\"]*\"\s*$"m => "apikey = \"***redacted***\""))
    length(text) > 20000 && (text = first(text, 20000) * "\n...[truncated at 20k chars]")
    return text
end
