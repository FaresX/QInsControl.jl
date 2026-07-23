@kwdef mutable struct DAQTask
    name::String = ""
    explog::String = ""
    blocks::Vector{AbstractBlock} = [SweepBlock()]
    viewcodes::String = ""
    editcodes::String = ""
    textmode::Bool = false
    viewmode::Bool = false
    hold::Bool = false
end

global OLDI::Int = 0
global WORKPATH::String = ""
global SAVEPATH::String = ""
global CFGCACHESAVEPATH::String = ""
global QDTCACHESAVEPATH::String = ""
global RUNNINGTASK::String = ""
const CFGBUF = Dict{String,Any}()
const DATABUF = Lockable(Dict{String,Vector{String}}())
const DATABUFPARSED = Lockable(Dict{String,VecOrMat{Cdouble}}())
const PROGRESSLIST = Lockable(OrderedDict{UUID,Tuple{UUID,Int,Int,Float64}}())

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
        if CImGui.Begin(
            stcstr("Edit Task ", id),
            p_open,
            CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking
        )
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
                    @c InputTextMultilineRSZ(stcstr("##Script", id), &daqtask.viewcodes, (-1, -1), ImGuiInputTextFlags_ReadOnly)
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
                    @c InputTextMultilineRSZ(stcstr("##Script", id), &daqtask.editcodes, (-1, -1), ImGuiInputTextFlags_AllowTabInput)
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
        CImGui.End()
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
    empty!(DATABUF)
    empty!(DATABUFPARSED)
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
                    remotedotask = @async @trycatch "remotedotask failed!!!" begin
                        start!(CPU)
                        fast!(CPU)
                        for ct in values(controllers)
                            login!(CPU, ct; quiet=false, attr=getattr(ct.addr))
                        end
                        remote_sweep_block(controllers, databuf_lc, progress_lc, extradatabuf_lc, SYNCSTATES)
                    end
                    @async @trycatch "transfering data task failded!!!" while true
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
    wait(Threads.@spawn @trycatch mlstr("transfer_data failed!!!") begin
        while !SYNCSTATES[IsDAQTaskDone]
            isready_databufrc() && process_databufrc()
            isready_extradatabufrc() && process_extradatabufrc()
            isready_progressrc() && process_progressrc()
            CONF.DAQ.highspeeddatatransfer ? yield() : sleep(0.001)
        end
        exittask()
    end)
end
function exittask()
    (isfile(SAVEPATH) || !isempty(DATABUF)) && (saveqdt(); global OLDI += 1)
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
        for data in packdata
            haskey(DATABUF, data[1]) || (DATABUF[data[1]] = String[])
            haskey(DATABUFPARSED, data[1]) || (DATABUFPARSED[data[1]] = Float64[])
            push!(DATABUF[data[1]], data[2])
            push!(cache, data)
            parsed_data = tryparse(Float64, data[2])
            push!(DATABUFPARSED[data[1]], isnothing(parsed_data) ? NaN : parsed_data)
            splitdata = split(data[1], "/")
            if length(splitdata) == 4
                _, instrnm, qt, addr = splitdata
            else
                continue
            end
            insbuf = INSTRBUFFERVIEWERS[instrnm][addr].insbuf
            if occursin(r"\[.*\]", qt)
                splitqt = split(qt, '[')
                qt = splitqt[1]
                idx = parse(Int, splitqt[2][1:end-1])
                splitread = split(insbuf.quantities[qt].read, insbuf.quantities[qt].separator)
                if idx > length(splitread)
                    insbuf.quantities[qt].read *= repeat(insbuf.quantities[qt].separator, idx - length(splitread))
                    insbuf.quantities[qt].read *= data[2]
                else
                    splitread[idx] = data[2]
                    insbuf.quantities[qt].read = join(splitread, insbuf.quantities[qt].separator)
                end
            else
                insbuf.quantities[qt].read = data[2]
            end
            updatefront!(insbuf.quantities[qt])
        end
        waittime("saveqdtcache", CONF.DAQ.savetime) && (saveqdtcache(cache); empty!(cache))
        waittime("savecfgcache", 60CONF.DAQ.savetime) && savecfgcache()
        waittime("savedatabuf", 60CONF.DAQ.savetime) && saveqdt()
    end
end
function process_extradatabufrc()
    key, val = take_extradatabufrc!()
    DATABUF[key] = val
    DATABUFPARSED[key] = replace(tryparse.(Float64, val), nothing => NaN)
    haskey(CFGBUF, "EXTRADATA") || (CFGBUF["EXTRADATA"] = Dict())
    CFGBUF["EXTRADATA"][key] = val
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
    jldopen(SAVEPATH, "w") do file
        lock(DATABUF) do DATABUF
            if savetype == String
                file["data"] = DATABUF
            else
                datafloat = Dict()
                for (key, val) in DATABUF
                    dataparsed = tryparse.(savetype, val)
                    datafloat[key] = all(.!isnothing.(dataparsed)) ? dataparsed : val
                end
                file["data"] = datafloat
            end
        end
        file["circuit"] = CIRCUIT
        file["daqdataplots"] = norealtime!(deepcopy(DAQDATAPLOTS))
        for (key, val) in CFGBUF
            key == "EXTRADATA" && continue
            file[key] = val
        end
        file["info"] = FILEINFO
        file["valid"] = !STATES[InValidFile]
    end
    if sum(length(data) for data in values(DATABUF); init=0) > CONF.DAQ.cuttingfile
        dir, file = splitdir(SAVEPATH)
        cuttingnum = find_cutting_i(dir, file)
        if cuttingnum != 1
            savepathhead = chop(file, tail=cuttingnum == 2 ? 4 : 7 + length(string(cuttingnum)))
            global SAVEPATH = joinpath(dir, string(savepathhead, " [", cuttingnum, "].qdt"))
            empty!(DATABUF)
            empty!(DATABUFPARSED)
            @trycatch mlstr("instrument logging error, program terminates!!!") log_instrbufferviewers()
        end
    end
end
function savecfgcache()
    jldopen(CFGCACHESAVEPATH, "w") do file
        file["circuit"] = CIRCUIT
        file["daqdataplots"] = deepcopy(DAQDATAPLOTS)
        for (key, val) in CFGBUF
            file[key] = val
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
            bk.instrnm == "VirtualInstr" && bk.addr != "VirtualAddress" && return controllers, false
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
    for k in keys(CFGBUF)
        k == "daqtask" || delete!(CFGBUF, k)
    end
    try
        log_instrbufferviewers()
    catch e
        @error "[$(now())]\n$(mlstr("instrument logging error, continue..."))" exception = e
        showbacktrace()
    end

    empty!(DATABUF)
    empty!(DATABUFPARSED)
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
    daqtask.textmode ? @c(InputTextMultilineRSZ(
        "##Script", &daqtask.viewcodes, (-1, -1), ImGuiInputTextFlags_ReadOnly
    )) : view(daqtask.blocks)
    CImGui.EndChild()
end