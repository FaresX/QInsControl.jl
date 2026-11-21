#文件夹式工程：取代旧单文件 .daq。
#- 每个任务/绘图一个 .task/.plot 文件(JLD2,内含 formatversion 键;字段经 JLD2Struct.jl 的
#  Dict 包装持久化,增删字段天然兼容)
#- 子文件夹 = 一级分类,tasks/ 根下文件 = 顶层任务;分组与顺序存 project.toml 清单
#- 兼容逻辑不进主源码:旧 .daq 用 scripts/import_legacy_project.jl 一次性转换;未来结构性
#  变更按 formatversion 写外置迁移脚本,主流程只认当前版本
#纯逻辑无 GUI 依赖,导入脚本与单元测试直接调用(见 test/runtests.jl "ProjectFolder")

const PROJ_FMT_VERSION = 2
#v1→v2:顶层清单由 order+groups 双列表改为 items 混排单列表——v1 在"裸任务与文件夹穿插"
#的场景下会丢失两者之间的相对顺序(加载端固定叶子在前);读取端同时兼容 v1/v2,无需迁移脚本
const PROJ_MANIFEST = "project.toml"
const PROJ_TASKSDIR = "tasks"
const PROJ_PLOTSDIR = "plots"
const PROJ_CIRCUIT = "circuit.circuit"
const PROJ_ALIASES = "aliases.toml"
const TASK_EXT = ".task"
const PLOT_EXT = ".plot"

const WIN_RESERVEDNAMES = ["CON", "PRN", "AUX", "NUL", ["COM$i" for i in 1:9]..., ["LPT$i" for i in 1:9]...]

#Windows 文件名清洗:非法字符/控制符→'_',去首尾点空格,规避保留设备名(区分大小写文件系统也无害)
function sanitizefilename(name::AbstractString)
    cleaned = replace(String(name), r"[\\/:*?\"<>|\x00-\x1f]" => "_")
    cleaned = String(strip(cleaned, ('.', ' ')))
    isempty(cleaned) && return "unnamed"
    occursin(r"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])($|\.)"i, cleaned) && (cleaned *= "_")
    cleaned
end

#tmp 写完再 mv:进程中途被杀不会留下半个损坏文件
function atomicsave(f::Function, path::AbstractString)
    tmppath = path * ".tmp"
    try
        f(tmppath)
        mv(tmppath, path; force=true)
    catch e
        isfile(tmppath) && rm(tmppath; force=true)
        rethrow()
    end
end

#容器(tasks/ 或 plots/)内唯一文件名:重名追加 -2/-3;小写比较,Windows 文件系统大小写不敏感
function uniquename(used::Set{String}, stem::AbstractString, ext::AbstractString)
    candidate = string(stem, ext)
    i = 1
    while lowercase(candidate) in used
        i += 1
        candidate = string(stem, "-", i, ext)
    end
    push!(used, lowercase(candidate))
    candidate
end

_projectext(::Type{DAQTask}) = TASK_EXT
_projectext(::Type{DataPlot}) = PLOT_EXT

####### 保存 #######

function _savecomponent(path::AbstractString, task::DAQTask, failures::Vector{String})
    try
        atomicsave(path) do tmppath
            jldsave(tmppath; formatversion=PROJ_FMT_VERSION, task=deepcopy(task))
        end
    catch e
        @error "[$(now())]\n$(mlstr("saving project component failed!!!"))" filepath = path exception = e
        push!(failures, String(path))
    end
end
function _savecomponent(path::AbstractString, dtp::DataPlot, failures::Vector{String})
    try
        atomicsave(path) do tmppath
            jldsave(tmppath; formatversion=PROJ_FMT_VERSION, plot=deepcopy(dtp))
        end
    catch e
        @error "[$(now())]\n$(mlstr("saving project component failed!!!"))" filepath = path exception = e
        push!(failures, String(path))
    end
end

#保存一个容器:children 为 Tree 叶子/一级分类,返回 (顶层 items 混排列表, 清单引用的相对路径集, 组目录名集)
function _savecontainer(partsdir::String, children, ::Type{T}, failures::Vector{String}) where {T}
    ext = _projectext(T)
    items = Vector{Dict{String,Any}}()
    keepfiles = Set{String}()
    keepdirs = Set{String}()
    usedroot = Set{String}()
    for child in children
        if child.isgroup
            gname = sanitizefilename(child.name)
            gdir = mkpath(joinpath(partsdir, gname))
            push!(keepdirs, gname)
            usedg = Set{String}()
            order = String[]
            for leaf in child.children
                fname = uniquename(usedg, sanitizefilename(leaf.value.name), ext)
                _savecomponent(joinpath(gdir, fname), leaf.value, failures)
                push!(order, fname)
                push!(keepfiles, lowercase(joinpath(gname, fname)))
            end
            #v2:顶层 items 为混排单列表,叶子与文件夹的实际穿插顺序在此保留(v1 的 order+groups 双列表会丢失混排序)
            push!(items, Dict{String,Any}("group" => String(child.name), "dir" => gname, "order" => order))
        else
            fname = uniquename(usedroot, sanitizefilename(child.value.name), ext)
            _savecomponent(joinpath(partsdir, fname), child.value, failures)
            push!(items, Dict{String,Any}("file" => fname))
            push!(keepfiles, lowercase(fname))
        end
    end
    items, keepfiles, keepdirs
end

#清理不再被清单引用的本工程文件:只删约定扩展名与残留 tmp,分类文件夹删空;用户的其他文件不动
function _cleanupparts(partsdir::String, keepfiles::Set{String}, keepdirs::Set{String}, ext::String)
    isdir(partsdir) || return
    for (root, dirs, files) in walkdir(partsdir)
        for f in files
            rel = relpath(joinpath(root, f), partsdir)
            if endswith(f, ext) && lowercase(rel) ∉ keepfiles
                rm(joinpath(root, f); force=true)
            elseif endswith(f, ext * ".tmp")
                rm(joinpath(root, f); force=true) #上次保存中断的残留
            end
        end
    end
    for d in readdir(partsdir; join=true)
        isdir(d) && basename(d) ∉ keepdirs && isempty(readdir(d)) && rm(d; recursive=true)
    end
end

function _savemanifest(path::AbstractString, manifest::Dict{String,Any}, failures::Vector{String})
    try
        atomicsave(path) do tmppath
            open(tmppath, "w") do io
                TOML.print(io, manifest)
            end
        end
    catch e
        @error "[$(now())]\n$(mlstr("saving project manifest failed!!!"))" filepath = path exception = e
        push!(failures, String(path))
    end
end

function _aliasesmanifest(aliases)
    entries = [
        Dict{String,Any}(
            "name" => String(k),
            "alias" => String(a.alias),
            "instrnm" => String(a.instrnm),
            "addr" => String(a.addr)
        ) for (k, a) in aliases
    ]
    Dict{String,Any}("formatversion" => PROJ_FMT_VERSION, "alias" => entries)
end

"""
    save_project_folder(dir, tasksroot, plotsroot, circuit, aliases) -> failures::Vector{String}

把工程写入文件夹式工程目录 `dir`。原子逐文件写,返回写入失败的文件路径列表(空即全部成功)。
"""
function save_project_folder(
    dir::AbstractString,
    tasksroot::Tree{DAQTask},
    plotsroot::Tree{DataPlot},
    circuit::NodeEditor,
    aliases
)
    dir = abspath(dir)
    failures = String[]
    mkpath(dir)
    tasksdir = mkpath(joinpath(dir, PROJ_TASKSDIR))
    plotsdir = mkpath(joinpath(dir, PROJ_PLOTSDIR))
    taskitems, taskfiles, taskdirs = _savecontainer(tasksdir, tasksroot.children, DAQTask, failures)
    plotitems, plotfiles, plotdirs = _savecontainer(plotsdir, plotsroot.children, DataPlot, failures)
    try
        atomicsave(joinpath(dir, PROJ_CIRCUIT)) do tmppath
            jldsave(tmppath; formatversion=PROJ_FMT_VERSION, circuit=deepcopy(circuit))
        end
    catch e
        @error "[$(now())]\n$(mlstr("saving project component failed!!!"))" filepath = joinpath(dir, PROJ_CIRCUIT) exception = e
        push!(failures, joinpath(dir, PROJ_CIRCUIT))
    end
    try
        atomicsave(joinpath(dir, PROJ_ALIASES)) do tmppath
            open(tmppath, "w") do io
                TOML.print(io, _aliasesmanifest(aliases))
            end
        end
    catch e
        @error "[$(now())]\n$(mlstr("saving project manifest failed!!!"))" filepath = joinpath(dir, PROJ_ALIASES) exception = e
        push!(failures, joinpath(dir, PROJ_ALIASES))
    end
    manifest = Dict{String,Any}(
        "formatversion" => PROJ_FMT_VERSION,
        "tasks" => Dict{String,Any}("items" => taskitems),
        "plots" => Dict{String,Any}("items" => plotitems)
    )
    _savemanifest(joinpath(dir, PROJ_MANIFEST), manifest, failures)
    #清理以本次清单为准,只在清单写成功后执行
    if !isfile(joinpath(dir, PROJ_MANIFEST)) || joinpath(dir, PROJ_MANIFEST) in failures
        return failures
    end
    _cleanupparts(tasksdir, taskfiles, taskdirs, TASK_EXT)
    _cleanupparts(plotsdir, plotfiles, plotdirs, PLOT_EXT)
    failures
end

####### 校验与加载 #######

#保存目标判定::empty(不存在或空目录)/:project/:repair(清单损坏但部件在,可覆盖重建)/:foreign(非空且不是工程)
function classify_project_dir(dir::AbstractString)
    isdir(dir) || return :empty
    isempty(readdir(dir)) && return :empty
    state, _ = probe_project(dir)
    state == :foreign ? :foreign : state
end

#工程身份判定:(:project, manifest)/(:repair, nothing)/(:foreign, nothing)/(:notdir, nothing)
function probe_project(dir::AbstractString)
    isdir(dir) || return (:notdir, nothing)
    mpath = joinpath(dir, PROJ_MANIFEST)
    if isfile(mpath)
        try
            return (:project, TOML.parsefile(mpath))
        catch e
            @warn "[$(now())]\n$(mlstr("project manifest is corrupted, rescanning"))" filepath = mpath exception = e
            return (:repair, nothing)
        end
    end
    (isdir(joinpath(dir, PROJ_TASKSDIR)) || isdir(joinpath(dir, PROJ_PLOTSDIR))) ? (:repair, nothing) : (:foreign, nothing)
end

#清单缺失/损坏的修复扫描:组=子文件夹,顺序=名称排序
function _scanmanifest(partsdir::String, ext::String)
    isdir(partsdir) || return Dict{String,Any}()
    groups = [
        Dict{String,Any}(
            "name" => basename(d),
            "dir" => basename(d),
            "order" => sort([f for f in readdir(d) if endswith(f, ext)])
        ) for d in readdir(partsdir; join=true) if isdir(d)
    ]
    Dict{String,Any}(
        "order" => sort([f for f in readdir(partsdir) if isfile(joinpath(partsdir, f)) && endswith(f, ext)]),
        "groups" => groups
    )
end

Base.@kwdef struct ProjectLoadResult
    ok::Bool = false
    reason::Symbol = :foreign   #:notdir / :foreign / :ok
    tasks::Tree{DAQTask} = TreeGroup(DAQTask, "root")
    plots::Tree{DataPlot} = TreeGroup(DataPlot, "")
    circuit::Union{Nothing,NodeEditor} = nothing
    aliases::Union{Nothing,OrderedDict{String,InstrAlias}} = nothing
    failures::Vector{String} = String[]  #加载失败的部件文件
    warnings::Vector{String} = String[]  #修复扫描/版本不符/清单外文件等提示
end

function _loadcomponent(path::AbstractString, ::Type{DAQTask}, failures::Vector{String})
    data = try
        load(path, "task")
    catch e
        @error "[$(now())]\n$(mlstr("loading project component failed!!!"))" filepath = path exception = e
        push!(failures, String(path))
        return nothing
    end
    data isa DAQTask || (push!(failures, String(path)); return nothing)
    data.torunstate = false #载入的任务不继承运行与编辑器展开状态(见 DAQ.jl 单任务导入的同一约定)
    data.showeditor = false
    Tree(data)
end
function _loadcomponent(path::AbstractString, ::Type{DataPlot}, failures::Vector{String})
    data = try
        load(path, "plot")
    catch e
        @error "[$(now())]\n$(mlstr("loading project component failed!!!"))" filepath = path exception = e
        push!(failures, String(path))
        return nothing
    end
    data isa DataPlot || (push!(failures, String(path)); return nothing)
    data.showplot = false
    data.showdtpk = false
    Tree(data)
end

#按清单装载叶子到容器(root/group),登记相对路径供"清单外文件"核对
function _loadleaves!(container::Tree{T}, partsdir::String, gdir::String, order, listed::Set{String}, ::Type{T}, failures) where {T}
    for f in order
        rel = gdir == "" ? lowercase(String(f)) : lowercase(joinpath(gdir, String(f)))
        push!(listed, rel)
        path = gdir == "" ? joinpath(partsdir, String(f)) : joinpath(partsdir, gdir, String(f))
        node = _loadcomponent(path, T, failures)
        isnothing(node) || push!(container.children, node)
    end
end

#按清单装载一个容器树;以清单为准,缺失记 failures,清单外文件记 warnings
#v2 清单:items 混排单列表(叶子/文件夹穿插顺序原样保留);v1 旧清单:order+groups 双列表,
#读取端固定叶子在前、文件夹在后(混排顺序在 v1 里本就没存下来,无从恢复)
function _loadtree(dir::String, subdirname::String, spec, ::Type{T}, failures, warnings) where {T}
    root = TreeGroup(T, "root")
    ext = _projectext(T)
    partsdir = joinpath(dir, subdirname)
    isdir(partsdir) || return root
    listed = Set{String}()
    if haskey(spec, "items")
        for item in get(spec, "items", [])
            item isa AbstractDict || continue
            if haskey(item, "file") #裸叶子
                _loadleaves!(root, partsdir, "", [item["file"]], listed, T, failures)
            elseif haskey(item, "group") #一级分类
                gname = string(get(item, "group", ""))
                gdir = string(get(item, "dir", sanitizefilename(gname)))
                group = TreeGroup(T, gname)
                _loadleaves!(group, partsdir, gdir, get(item, "order", []), listed, T, failures)
                push!(root.children, group)
            end
        end
    else #v1 兼容:order(裸叶子)+groups(分类),叶子在前、文件夹在后
        _loadleaves!(root, partsdir, "", get(spec, "order", []), listed, T, failures)
        for g in get(spec, "groups", [])
            g isa AbstractDict || continue
            gname = string(get(g, "name", ""))
            gdir = string(get(g, "dir", sanitizefilename(gname)))
            group = TreeGroup(T, gname)
            _loadleaves!(group, partsdir, gdir, get(g, "order", []), listed, T, failures)
            push!(root.children, group)
        end
    end
    for (rootpath, dirs, files) in walkdir(partsdir)
        for f in files
            rel = relpath(joinpath(rootpath, f), partsdir)
            if endswith(f, ext) && lowercase(rel) ∉ listed
                push!(warnings, mlstr("unlisted file ignored") * ": " * rel)
            elseif endswith(f, ext * ".tmp")
                rm(joinpath(rootpath, f); force=true) #残留 tmp 直接清掉
            end
        end
    end
    root
end

function _loadcircuit(dir::String, failures::Vector{String})
    path = joinpath(dir, PROJ_CIRCUIT)
    isfile(path) || return nothing
    circuit = try
        load(path, "circuit")
    catch e
        @error "[$(now())]\n$(mlstr("loading project component failed!!!"))" filepath = path exception = e
        push!(failures, path)
        return nothing
    end
    circuit isa NodeEditor || (push!(failures, path); return nothing)
    circuit
end

function _loadaliases(dir::String, failures::Vector{String})
    path = joinpath(dir, PROJ_ALIASES)
    isfile(path) || return nothing
    try
        toml = TOML.parsefile(path)
        aliases = OrderedDict{String,InstrAlias}()
        for entry in get(toml, "alias", [])
            entry isa AbstractDict || continue
            a = InstrAlias(
                alias=string(get(entry, "alias", "")),
                instrnm=string(get(entry, "instrnm", "")),
                addr=string(get(entry, "addr", ""))
            )
            aliases[string(get(entry, "name", a.alias))] = a
        end
        aliases
    catch e
        @error "[$(now())]\n$(mlstr("loading project component failed!!!"))" filepath = path exception = e
        push!(failures, path)
        nothing
    end
end

"""
    load_project_folder(dir) -> ProjectLoadResult

从文件夹式工程目录 `dir` 装载工程。文件夹身份/清单版本/逐文件完整性都在此校验,
GUI 层只负责把 `failures`/`warnings` 转成 toast。`reason` 为 `:notdir`/`:foreign` 时
`ok == false`,其余字段不可用。
"""
function load_project_folder(dir::AbstractString)
    dir = abspath(dir)
    state, manifest = probe_project(dir)
    state == :notdir && return ProjectLoadResult(reason=:notdir)
    state == :foreign && return ProjectLoadResult(reason=:foreign)
    warnings = String[]
    failures = String[]
    if state == :repair
        push!(warnings, mlstr("project manifest missing or corrupted, rescanned from folders"))
        manifest = Dict{String,Any}()
    else
        fv = get(manifest, "formatversion", 0)
        fv = fv isa Integer ? Int(fv) : 0
        fv > PROJ_FMT_VERSION &&
            push!(warnings, mlstr("project saved by a newer version, best-effort loading") * " (v$fv)")
        fv < PROJ_FMT_VERSION &&
            push!(warnings, mlstr("project of older format, consider the migration scripts") * " (v$fv)")
    end
    tasks = _loadtree(dir, PROJ_TASKSDIR, state == :repair ? _scanmanifest(joinpath(dir, PROJ_TASKSDIR), TASK_EXT) : get(manifest, "tasks", Dict{String,Any}()), DAQTask, failures, warnings)
    plots = _loadtree(dir, PROJ_PLOTSDIR, state == :repair ? _scanmanifest(joinpath(dir, PROJ_PLOTSDIR), PLOT_EXT) : get(manifest, "plots", Dict{String,Any}()), DataPlot, failures, warnings)
    circuit = _loadcircuit(dir, failures)
    aliases = _loadaliases(dir, failures)
    ProjectLoadResult(; ok=true, reason=:ok, tasks, plots, circuit, aliases, failures, warnings)
end
