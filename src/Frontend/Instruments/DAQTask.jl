@kwdef mutable struct DAQTask
    name::String = ""
    explog::String = ""
    blocks::Vector{AbstractBlock} = [SweepBlock()]
    viewcodes::String = ""
    editcodes::String = ""
    textmode::Bool = false
    viewmode::Bool = false
    hold::Bool = false
    torunstate::Bool = false #待运行标记（树形化前存于 DAQTaskNode，现随任务存储）
    showeditor::Bool = false #任务编辑器展开标记
end

global OLDI::Int = 0
global WORKPATH::String = ""
global SAVEPATH::String = ""
global CFGCACHESAVEPATH::String = ""
global QDTCACHESAVEPATH::String = ""
global RUNNINGTASK::String = ""
#GUI 线程(logaction/log_instrbufferviewers)与数据任务(saveqdt/savecfgcache)会同时访问,必须加锁
const CFGBUF = Lockable(Dict{String,Any}())
const DATABUF = Lockable(Dict{String,Vector{String}}())
const DATABUFPARSED = Lockable(Dict{String,VecOrMat{Cdouble}}())
const PROGRESSLIST = Lockable(OrderedDict{UUID,Tuple{UUID,Int,Int,Float64}}())

function find_old_i(dir)
    global OLDI
    if isdir(dir)
        for file in readdir(dir) # 任务顺序根据文件夹内容确定
            if isfile(joinpath(dir, file))
                m = match(Regex("$(mlstr("Task")) ([0-9]+)"), file)
                if !isnothing(m)
                    new_i = tryparse(Int, m[1])
                    isnothing(new_i) || (OLDI = max(new_i, OLDI))
                end
            end
        end
    else
        OLDI = 0
    end
end

let
    redolist::Dict{Int,LoopVector{Vector{AbstractBlock}}} = Dict()
    blocksbuf::Vector{AbstractBlock} = []
    undobtx::Cfloat = 0
    redobtx::Cfloat = 0
    compilebtx::Cfloat = 0
    tbtx1::Cfloat = 0
    tbtx2::Cfloat = 0
    btx::Cfloat = 0
    global function edit(daqtask::DAQTask, id, p_open::Ref{Bool})
        CImGui.SetNextWindowSize((600, 800) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Once)
        CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, unsafe_load(IMGUISTYLE.PopupRounding))
        isfocus = true
        global OLDI
        nm = stcstr("Edit Task ", id)
        begun, own, popenarg = BeginNoClose(
            nm, p_open, true, CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking
        )
        if begun
            ftsz = CImGui.GetFontSize()
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Cfloat(0), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, (Cfloat(0), unsafe_load(IMGUISTYLE.FramePadding.y)))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
            CImGui.Button(MORESTYLE.Icons.TaskButton)
            CImGui.PopStyleColor()
            CImGui.SameLine()
            CImGui.Button(stcstr(" ", mlstr("Edit queue: Task"), " ", id + OLDI, " ", daqtask.name))
            CImGui.PopStyleColor(3)
            CImGui.PopStyleVar(3)
            if daqtask.textmode
                CImGui.SameLine(
                    CImGui.GetContentRegionAvail().x - compilebtx - tbtx1 - tbtx2 - btx -
                    2unsafe_load(IMGUISTYLE.ItemSpacing.x)
                )
            else
                CImGui.SameLine(
                    CImGui.GetContentRegionAvail().x - undobtx - redobtx - compilebtx - tbtx1 - tbtx2 - btx -
                    4unsafe_load(IMGUISTYLE.ItemSpacing.x)
                )
                CImGui.Button(MORESTYLE.Icons.Undo) && undo!(daqtask, id)
                ItemTooltip(mlstr("Undo"))
                undobtx = CImGui.GetItemRectSize().x
                CImGui.SameLine()
                CImGui.Button(MORESTYLE.Icons.Redo) && redo!(daqtask, id)
                ItemTooltip(mlstr("Redo"))
                redobtx = CImGui.GetItemRectSize().x
                CImGui.SameLine()
            end
            if CImGui.Button(MORESTYLE.Icons.Convert)
                ex = @trypasse compile(daqtask.blocks) nothing
                ex = @trypasse prettify(ex) ex
                @info "[$(now())]\n" codes = ex
            end
            ItemTooltip(mlstr("Compile"))
            compilebtx = CImGui.GetItemRectSize().x
            CImGui.SameLine()
            if @c ToggleButton(mlstr(daqtask.textmode ? "Text" : "Block"), &daqtask.textmode)
                try
                    daqtask.textmode && (daqtask.viewcodes = string(prettify(interpret(daqtask.blocks))))
                catch e
                    @error "[$(now())]\nan error occurs during interpreting blocks" exception = e
                    showbacktrace()
                end
            end
            tbtx1 = CImGui.GetItemRectSize().x
            # CImGui.SameLine(CImGui.GetContentRegionAvail().x - tbtx2 - btx - unsafe_load(IMGUISTYLE.ItemSpacing.x))
            CImGui.SameLine()
            CImGui.Button(
                daqtask.viewmode ? MORESTYLE.Icons.View : MORESTYLE.Icons.Edit
            ) && (daqtask.viewmode ⊻= true)
            btx = CImGui.GetItemRectSize().x
            CImGui.SameLine()
            @c ToggleButton(MORESTYLE.Icons.HoldPin, &daqtask.hold)
            tbtx2 = CImGui.GetItemRectSize().x
            CImGui.Separator()
            SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Experimental Records"))
            y = (1 + length(findall("\n", daqtask.explog))) * CImGui.GetTextLineHeight() +
                2unsafe_load(IMGUISTYLE.FramePadding.y)
            @c InputTextMultilineRSZ("##experimental record", &daqtask.explog, (Float32(-1), y))
            if CImGui.BeginPopupContextItem("clear##experimental record")
                CImGui.MenuItem(stcstr(mlstr("clear"), "##experimental record")) && (daqtask.explog = "")
                CImGui.EndPopup()
            end
            SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Script"))
            if daqtask.textmode
                if daqtask.viewmode
                    codeview(stcstr("##Script", id), daqtask.viewcodes, (-1, -1))
                else
                    if CImGui.Button(mlstr("Open with Editor"))
                        Threads.@spawn @trycatch mlstr("error editing text!!!") begin
                            file = joinpath(ENV["QInsControlAssets"], "temp", string(basename(tempname()), ".jl"))
                            open(file, "w") do io
                                write(io, daqtask.editcodes)
                            end
                            DefaultApplication.open(file; wait=true)
                            daqtask.editcodes = read(file, String)
                        end
                    end
                    CImGui.SameLine()
                    if CImGui.Button(mlstr("Interpret"))
                        try
                            daqtask.editcodes = string(prettify(interpret(daqtask.blocks)))
                        catch e
                            @error "[$(now())]\nan error occurs during interpreting blocks" exception = e
                            showbacktrace()
                        end
                    end
                    CImGui.SameLine()
                    if CImGui.Button(mlstr("Anti-interpret"))
                        try
                            blocksbuf = antiinterpretblocks(Meta.parseall(daqtask.editcodes))
                        catch e
                            blocksbuf = []
                            @error "[$(now())]\nan error occurs during anti-interpreting codes" exception = e
                            showbacktrace()
                        end
                        CImGui.OpenPopup("##Blocks Buffer$id")
                    end
                    @c codeedit(stcstr("##Script", id), &daqtask.editcodes, (-1, -1))
                    CImGui.SetNextWindowSize((1200, 800) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Once)
                    if CImGui.BeginPopupModal(stcstr("##Blocks Buffer", id))
                        CImGui.Button(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Close"))) && CImGui.CloseCurrentPopup()
                        CImGui.SameLine()
                        if CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")))
                            daqtask.blocks = copy(blocksbuf)
                            CImGui.CloseCurrentPopup()
                        end
                        CImGui.Columns(2)
                        BoxTextColored(mlstr("Original"); size=(-1, 0), col=MORESTYLE.Colors.HighlightText)
                        CImGui.BeginChild("blocksorigin")
                        edit(daqtask.blocks, 1, "blocksorigin")
                        CImGui.EndChild()
                        CImGui.NextColumn()
                        BoxTextColored(mlstr("New"); size=(-1, 0), col=MORESTYLE.Colors.HighlightText)
                        CImGui.BeginChild("blocksbuf")
                        edit(blocksbuf, 1, "blocksbuf")
                        CImGui.EndChild()
                        CImGui.EndPopup()
                    end
                end
            else
                dragblockmenu(id)
                # CImGui.Button(stcstr(MORESTYLE.Icons.Undo, " ", mlstr("Undo"))) && undo!(daqtask, id)
                # CImGui.SameLine()
                # CImGui.Button(stcstr(MORESTYLE.Icons.Redo, " ", mlstr("Redo"))) && redo!(daqtask, id)
                # CImGui.SameLine()
                # if CImGui.Button(stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Compile")))
                #     ex = @trypasse compile(daqtask.blocks) nothing
                #     ex = @trypasse prettify(ex) ex
                #     @info "[$(now())]\n" codes = ex
                # end
                CImGui.BeginChild("DAQTask.blocks")
                CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.NormalBlockBorder)
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
                daqtask.viewmode ? view(daqtask.blocks) : edit(daqtask.blocks, 1, id)
                CImGui.PopStyleVar()
                CImGui.PopStyleColor()
                CImGui.EndChild()
                diff(daqtask, id)
                if unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
                    CImGui.IsKeyPressed(ImGuiKey_Z, false) && undo!(daqtask, id)
                    CImGui.IsKeyPressed(ImGuiKey_Y, false) && redo!(daqtask, id)
                end
            end
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        EndNoClose(own, p_open, popenarg)
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        p_open[] &= (isfocus | daqtask.hold)
    end

    function diff(daqtask::DAQTask, id)
        if !haskey(redolist, id)
            redolist[id] = LoopVector(fill(AbstractBlock[], CONF.DAQ.historylen))
            redolist[id][] = deepcopy(daqtask.blocks)
        end
        if !CImGui.IsMouseDown(0)
            redolist[id][] ≈ daqtask.blocks || (move!(redolist[id]); redolist[id][] = deepcopy(daqtask.blocks))
        end
    end
    function undo!(daqtask::DAQTask, id)
        if !isempty(redolist[id][-1])
            move!(redolist[id], -1)
            daqtask.blocks = deepcopy(redolist[id][])
        end
    end
    function redo!(daqtask::DAQTask, id)
        if !isempty(redolist[id][1])
            move!(redolist[id])
            daqtask.blocks = deepcopy(redolist[id][])
        end
    end
end

function saferun(daqtask::DAQTask)
    try
        setup(daqtask)
        define(daqtask)
        sleep(0.1)
        transfer_data()
    catch e
        @error "[$(now())]\n$(mlstr("running task terminated unexpectedly!!!"))" exception = e
        showbacktrace()
        toast(:error, mlstr("running task terminated unexpectedly!!!"), sprint(showerror, e))
        if SYNCSTATES[IsDAQTaskRunning]
            SYNCSTATES[IsInterrupted] = true
            if SYNCSTATES[IsBlocked]
                SYNCSTATES[IsBlocked] = false
                remote_continue()
            end
        end
        t1 = time()
        while time() - t1 < 12 && (!SYNCSTATES[IsDAQTaskDone] || isready_databufrc() || isready_progressrc())
            isready_databufrc() && take_databufrc!()
            isready_progressrc() && take_progressrc!()
            sleep(0.001)
        end
        @warn "[$(now())]\n$(mlstr("terminates the task successfully!"))"
        SYNCSTATES[IsDAQTaskDone] = false
        SYNCSTATES[IsDAQTaskRunning] = false
        SYNCSTATES[IsInterrupted] = false
    end
    STATES[AutoRefreshing] = true
end

function setup(daqtask::DAQTask)
    global WORKPATH
    global SAVEPATH
    global CFGCACHESAVEPATH
    global QDTCACHESAVEPATH
    global OLDI
    global RUNNINGTASK
    SYNCSTATES[IsDAQTaskRunning] = true
    STATES[AutoRefreshing] = false
    STATES[InValidFile] = false
    RUNNINGTASK = daqtask.name
    date = today()
    find_old_i(joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date)))
    cfgsvdir = joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date))
    ispath(cfgsvdir) || mkpath(cfgsvdir)
    fileprename = replace("[$(now())] $(mlstr("Task")) $(1+OLDI) $(daqtask.name)", ':' => '.')
    SAVEPATH = joinpath(cfgsvdir, "$fileprename.qdt")
    CFGCACHESAVEPATH = joinpath(cfgsvdir, "$fileprename.cfg.cache")
    QDTCACHESAVEPATH = joinpath(cfgsvdir, "$fileprename.qdt.cache")
    CFGBUF["daqtask"] = deepcopy(daqtask)
    try
        log_instrbufferviewers()
    catch e
        @error "[$(now())]\n$(mlstr("instrument logging error, program terminates!!!"))" exception = e
        showbacktrace()
        SYNCSTATES[IsDAQTaskRunning] = false
        return nothing
    end
    remote_unsetbusy!()
    remote_logout!()
    savecfgcache()
end

function define(daqtask::DAQTask)
    controllers, st = extract_controllers(daqtask.blocks)
    st || (SYNCSTATES[IsDAQTaskDone] = true; return)
    #两个 buffer 一起清空,避免读取方看到一半空一半非空的不一致状态
    lock(DATABUF) do databuf
        lock(DATABUFPARSED) do databufparsed
            empty!(databuf)
            empty!(databufparsed)
        end
    end
    rn = length(controllers)
    func1 = try
        compile(daqtask.blocks)
    catch e
        @error "[$(now())]\n$(mlstr("generating codes failed!!!"))" exception = e
        SYNCSTATES[IsDAQTaskDone] = true
        return
    end
    func2 = quote
        $func1
        function remote_do_block(databuf_rc, progress_rc, extradatabuf_rc, SYNCSTATES, rn)
            controllers = $controllers
            try
                databuf_lc = Channel{Tuple{String,String}}($(CONF.DAQ.channelsize))
                progress_lc = Channel{Tuple{UUID,Int,Int,Float64}}($(CONF.DAQ.channelsize))
                extradatabuf_lc = Channel{Tuple{String,Vector{String}}}($(CONF.DAQ.channelsize))
                @sync begin
                    remotedotask = @async_record "remotedotask" @trycatch "remotedotask failed!!!" begin
                        start!(CPU)
                        fast!(CPU)
                        for ct in values(controllers)
                            login!(CPU, ct; quiet=false, attrlist=$(CONF.Communication.attrlist))
                        end
                        remote_sweep_block(controllers, databuf_lc, progress_lc, extradatabuf_lc, SYNCSTATES)
                    end
                    @async_record "localtransfer" @trycatch "transfering data task failded!!!" while true
                        if all(.!isready.([databuf_lc, databuf_rc, progress_lc, progress_rc, extradatabuf_lc, extradatabuf_rc]))
                            if istaskdone(remotedotask)
                                logblock()
                                SYNCSTATES[IsDAQTaskDone] = true
                                break
                            elseif SYNCSTATES[IsNewFile]
                                SYNCSTATES[IsNewFile] = false
                                continue
                            end
                        else
                            isready(databuf_lc) && put!(databuf_rc, packtake!(databuf_lc, 2rn * $(CONF.DAQ.packsize)))
                            isready(progress_lc) && put!(progress_rc, packtake!(progress_lc, $(CONF.DAQ.packsize)))
                            isready(extradatabuf_lc) && put!(extradatabuf_rc, take!(extradatabuf_lc))
                        end
                        CPU.fast[] ? yield() : sleep(0.001)
                    end
                end
            catch e
                @error "[$(now())]\ntask failed!!!" exception = e
                showbacktrace()
            finally
                unsetbusy!(CPU)
                for ct in values(controllers)
                    logout!(CPU, ct; quiet=false)
                end
                slow!(CPU)
            end
        end
    end
    func1 = @trypasse prettify(func1) func1
    @info "[$(now())]\n" task = func1
    remote_def_prog(func2)
    SYNCSTATES[IsDAQTaskDone] && return
    remote_runtask(rn)
end

function transfer_data()
    wait(@spawn_record "transfer_data" @trycatch mlstr("transfer_data failed!!!") begin
        while !SYNCSTATES[IsDAQTaskDone]
            #单批数据的异常不能终止整个泵:否则后续数据全部丢失,且 exittask 不会执行
            if isready_databufrc()
                @trycatch mlstr("processing data failed!!!") process_databufrc()
            end
            if isready_extradatabufrc()
                @trycatch mlstr("processing extra data failed!!!") process_extradatabufrc()
            end
            if isready_progressrc()
                @trycatch mlstr("processing progress failed!!!") process_progressrc()
            end
            CONF.DAQ.highspeeddatatransfer ? yield() : sleep(0.001)
        end
        exittask()
    end)
end
function exittask()
    if isfile(SAVEPATH) || !isempty(DATABUF)
        saveqdt()
        global OLDI += 1
        toast(:success, stcstr(mlstr("Task"), " ", OLDI, " ", mlstr("saved")), SAVEPATH)
    end
    empty!(PROGRESSLIST)
    empty!(CFGBUF)
    SYNCSTATES[IsDAQTaskDone] = false
    SYNCSTATES[IsDAQTaskRunning] = false
    Base.Filesystem.rm(CFGCACHESAVEPATH; force=true)
    Base.Filesystem.rm(QDTCACHESAVEPATH; force=true)
end

let
    cache::Vector{Tuple{String,String}} = []
    global function process_databufrc()
        packdata = take_databufrc!()
        #整批写入必须在同一段临界区内完成:saveqdt 会持锁遍历 DATABUF、newfile/define 会 empty!,
        #原先"取引用—锁外 push!"的写法会让 Dict 在迭代/清空的同时被插入(未定义行为)
        lock(DATABUF) do databuf
            lock(DATABUFPARSED) do databufparsed
                for data in packdata
                    haskey(databuf, data[1]) || (databuf[data[1]] = String[])
                    haskey(databufparsed, data[1]) || (databufparsed[data[1]] = Float64[])
                    push!(databuf[data[1]], data[2])
                    push!(cache, data)
                    parsed_data = tryparse(Float64, data[2])
                    push!(databufparsed[data[1]], isnothing(parsed_data) ? NaN : parsed_data)
                end
            end
        end
        #回写仪器缓冲放到锁外:缺键/下标非法不该让整批数据丢掉,更不能打断采集
        qtstoupdate = []
        for data in packdata
            splitdata = split(data[1], "/")
            length(splitdata) == 4 || continue
            _, instrnm, qt, addr = splitdata
            #用 get 一次取出,避免 haskey 与 getindex 之间被 GUI 线程删掉导致 KeyError
            inses = get(INSTRBUFFERVIEWERS, instrnm, nothing)
            isnothing(inses) && continue
            ibv = get(inses, addr, nothing)
            isnothing(ibv) && continue
            insbuf = ibv.insbuf
            idx = 0
            if occursin('[', qt)
                splitqt = split(qt, '[')
                length(splitqt) == 2 || continue
                endswith(splitqt[2], ']') || continue
                qt = splitqt[1]
                parsedidx = tryparse(Int, splitqt[2][1:end-1]) #下标非法时按标量处理,不抛异常
                isnothing(parsedidx) || (idx = parsedidx)
            end
            qtins = get(insbuf.quantities, qt, nothing)
            isnothing(qtins) && continue
            if idx == 0
                qtins.read = data[2]
            else
                splitread = split(qtins.read, qtins.separator)
                if idx > length(splitread)
                    qtins.read = string(
                        join(splitread, qtins.separator), repeat(qtins.separator, idx - length(splitread)), data[2]
                    )
                else
                    splitread[idx] = data[2]
                    qtins.read = join(splitread, qtins.separator)
                end
            end
            push!(qtstoupdate, qtins)
        end
        for qtins in qtstoupdate
            updatefront!(qtins)
        end
        waittime("saveqdtcache", CONF.DAQ.savetime) && (saveqdtcache(cache); empty!(cache))
        waittime("savecfgcache", 60CONF.DAQ.savetime) && savecfgcache()
        waittime("savedatabuf", 60CONF.DAQ.savetime) && saveqdt()
    end
end
function process_extradatabufrc()
    key, val = take_extradatabufrc!()
    parsedvals = tryparse.(Float64, val)
    #两个 buffer 必须在同一临界区内一起更新(加锁顺序与 process_databufrc 一致,不会死锁)
    lock(DATABUF) do databuf
        lock(DATABUFPARSED) do databufparsed
            databuf[key] = String[string(v) for v in val]
            #必须显式构造 Vector{Float64}:replace 会保留 nothing 所在的 Union 元素类型,
            #直接赋给 Dict{String,VecOrMat{Cdouble}} 会在元素类型转换时抛错并打断数据泵
            databufparsed[key] = Float64[isnothing(p) ? NaN : p for p in parsedvals]
        end
    end
    lock(CFGBUF) do CFGBUF
        haskey(CFGBUF, "EXTRADATA") || (CFGBUF["EXTRADATA"] = Dict())
        CFGBUF["EXTRADATA"][key] = val
    end
end
function process_progressrc()
    packpb = take_progressrc!()
    lock(PROGRESSLIST) do PROGRESSLIST
        for pb in packpb
            haskey(PROGRESSLIST, pb[1]) || (PROGRESSLIST[pb[1]] = pb)
            PROGRESSLIST[pb[1]] = pb
            dorender()
        end
    end
end

function saveqdt()
    savetype = eval(Symbol(CONF.DAQ.savetype))
    datalen = 0
    jldopen(SAVEPATH, "w") do file
        lock(DATABUF) do DATABUF
            datalen = sum(length(data) for data in values(DATABUF); init=0) #持锁统计,避免锁外遍历
            if savetype == String
                file["data"] = DATABUF
            else
                datafloat = Dict()
                for (key, val) in DATABUF
                    dataparsed = tryparse.(savetype, val)
                    #必须把 Union{Nothing,T} 收成纯 T 数组:JLD2 写不了带 Nothing 的联合类型数组
                    datafloat[key] = all(!isnothing, dataparsed) ? Array{savetype,1}(dataparsed) : val
                end
                file["data"] = datafloat
            end
        end
        file["circuit"] = CIRCUIT
        file["daqdataplots"] = norealtime!(deepcopy(DAQDATAPLOTS))
        lock(CFGBUF) do CFGBUF
            for (key, val) in CFGBUF
                key == "EXTRADATA" && continue
                file[key] = val
            end
        end
        file["info"] = FILEINFO
        file["valid"] = !STATES[InValidFile]
    end
    if datalen > CONF.DAQ.cuttingfile
        dir, file = splitdir(SAVEPATH)
        cuttingnum = find_cutting_i(dir, file)
        if cuttingnum != 1
            savepathhead = chop(file, tail=cuttingnum == 2 ? 4 : 7 + length(string(cuttingnum)))
            global SAVEPATH = joinpath(dir, string(savepathhead, " [", cuttingnum, "].qdt"))
            lock(DATABUF) do databuf
                lock(DATABUFPARSED) do databufparsed
                    empty!(databuf)
                    empty!(databufparsed)
                end
            end
            @trycatch mlstr("instrument logging error, program terminates!!!") log_instrbufferviewers()
        end
    end
end
function savecfgcache()
    jldopen(CFGCACHESAVEPATH, "w") do file
        file["circuit"] = CIRCUIT
        file["daqdataplots"] = norealtime!(deepcopy(DAQDATAPLOTS))
        lock(CFGBUF) do CFGBUF
            for (key, val) in CFGBUF
                file[key] = val
            end
        end
        file["info"] = FILEINFO
        file["valid"] = !STATES[InValidFile]
    end
end
function saveqdtcache(cache)
    data = join(map(x -> string(x[1], ",", x[2]), cache), '\n')
    open(QDTCACHESAVEPATH, "a+") do file
        write(file, data)
    end
end

function find_cutting_i(dir, file)
    if isfile(joinpath(dir, file))
        m = match(r"[\w.]* \[([0-9]+)\].qdt", file)
        return if isnothing(m)
            2
        else
            old_i = tryparse(Int, m[1])
            isnothing(old_i) ? 2 : old_i + 1
        end
    end
    return 1
end

function extract_controllers(bkch::Vector{AbstractBlock})
    controllers = Dict()
    for bk in bkch
        if isinstr(bk)
            bk.instrnm == "VirtualInstr" && bk.addr != "VIRTUAL::ADDRESS" && return controllers, false
            @assert haskey(INSTRBUFFERVIEWERS, bk.instrnm) mlstr("$(bk.instrnm) has not been added")
            @assert haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr) mlstr("$(bk.addr) has not been added")
            ct, st = remote_check_instr(bk.instrnm, bk.addr, CONF.DAQ.ctbuflen, CONF.DAQ.retryconnecttimes, CONF.DAQ.retrysendtimes)
            st || return controllers, false
            controllers[string(bk.instrnm, "/", bk.addr)] = ct
        end
        if iscontainer(bk)
            inner_controllers, inner_st = extract_controllers(bk.blocks)
            inner_st || return controllers, false
            merge!(controllers, inner_controllers)
        end
    end
    controllers, true
end

function newfile(filename="")
    SYNCSTATES[IsNewFile] = true
    if :timed_out == timedwait(() -> !SYNCSTATES[IsNewFile], 6)
        SYNCSTATES[IsNewFile] = false
        error(mlstr("cannot finish the last task"))
    end

    global WORKPATH
    global SAVEPATH
    global CFGCACHESAVEPATH
    global QDTCACHESAVEPATH
    global OLDI
    global RUNNINGTASK

    if isfile(SAVEPATH) || !isempty(DATABUF)
        try
            log_instrbufferviewers()
        catch e
            @error "[$(now())]\n$(mlstr("instrument logging error, continue..."))" exception = e
            showbacktrace()
        end
        saveqdt()
        global OLDI += 1
    end
    Base.Filesystem.rm(CFGCACHESAVEPATH; force=true)
    Base.Filesystem.rm(QDTCACHESAVEPATH; force=true)

    STATES[InValidFile] = false
    date = today()
    find_old_i(joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date)))
    cfgsvdir = joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date))
    ispath(cfgsvdir) || mkpath(cfgsvdir)
    fileprename = replace("[$(now())] $(mlstr("Task")) $(1+OLDI) $(filename == "" ? RUNNINGTASK : filename)", ':' => '.')
    SAVEPATH = joinpath(cfgsvdir, "$fileprename.qdt")
    CFGCACHESAVEPATH = joinpath(cfgsvdir, "$fileprename.cfg.cache")
    QDTCACHESAVEPATH = joinpath(cfgsvdir, "$fileprename.qdt.cache")
    #先快照再删除:边遍历 keys 边 delete! 会破坏 Dict 内部槽位,单线程下也是未定义行为
    lock(CFGBUF) do CFGBUF
        for k in collect(keys(CFGBUF))
            k == "daqtask" || delete!(CFGBUF, k)
        end
    end
    try
        log_instrbufferviewers()
    catch e
        @error "[$(now())]\n$(mlstr("instrument logging error, continue..."))" exception = e
        showbacktrace()
    end

    #两个 buffer 一起清空,避免读取方看到一半空一半非空的不一致状态
    lock(DATABUF) do databuf
        lock(DATABUFPARSED) do databufparsed
            empty!(databuf)
            empty!(databufparsed)
        end
    end
end

#DAQTask Viewer
#################################################################
function view(daqtask::DAQTask)
    CImGui.BeginChild("view DAQTask")
    BoxTextColored(mlstr("Experimental Records"); col=MORESTYLE.Colors.HighlightText)
    CImGui.SameLine()
    if @c ToggleButton(mlstr(daqtask.textmode ? "Text" : "Block"), &daqtask.textmode)
        try
            daqtask.textmode && (daqtask.viewcodes = string(prettify(interpret(daqtask.blocks))))
        catch e
            @error "[$(now())]\nan error occurs during interpreting blocks" exception = e
            showbacktrace()
        end
    end
    TextRect(string(daqtask.explog, "\n "); nochild=true)
    daqtask.textmode ? codeview("##Script", daqtask.viewcodes, (-1, -1)) : view(daqtask.blocks)
    CImGui.EndChild()
end