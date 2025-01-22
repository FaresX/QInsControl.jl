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
const CFGBUF = Dict{String,Any}()

let
    redolist::Dict{Int,LoopVector{Vector{AbstractBlock}}} = Dict()
    blocksbuf::Vector{AbstractBlock} = []
    tbtx::Cfloat = 0
    global function edit(daqtask::DAQTask, id, p_open::Ref{Bool})
        CImGui.SetNextWindowSize((600, 800), CImGui.ImGuiCond_Once)
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
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
            CImGui.Button(MORESTYLE.Icons.TaskButton)
            CImGui.PopStyleColor()
            CImGui.SameLine()
            CImGui.Button(stcstr(" ", mlstr("Edit queue: Task"), " ", id + OLDI, " ", daqtask.name))
            CImGui.PopStyleColor(3)
            CImGui.SameLine(CImGui.GetContentRegionAvail().x - 3ftsz - tbtx - unsafe_load(IMGUISTYLE.ItemSpacing.x))
            if @c ToggleButton(mlstr(daqtask.textmode ? "Text" : "Block"), &daqtask.textmode)
                try
                    daqtask.textmode && (daqtask.viewcodes = string(prettify(interpret(daqtask.blocks))))
                catch e
                    @error "[$(now())]\nan error occurs during interpreting blocks" exception = e
                    showbacktrace()
                end
            end
            tbtx = CImGui.GetItemRectSize().x
            CImGui.SameLine(CImGui.GetContentRegionAvail().x - 3ftsz)
            CImGui.Button(
                daqtask.viewmode ? MORESTYLE.Icons.View : MORESTYLE.Icons.Edit, (3ftsz / 2, Cfloat(0))
            ) && (daqtask.viewmode ⊻= true)
            CImGui.SameLine()
            @c ToggleButton(MORESTYLE.Icons.HoldPin, &daqtask.hold)
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
                    CImGui.SetNextWindowSize((1200, 800), CImGui.ImGuiCond_Once)
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
                CImGui.PushID(id)
                dragblockmenu(id)
                CImGui.BeginChild("DAQTask.blocks")
                CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.NormalBlockBorder)
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
                daqtask.viewmode ? view(daqtask.blocks) : edit(daqtask.blocks, 1, id)
                CImGui.PopStyleVar()
                CImGui.PopStyleColor()
                CImGui.EndChild()
                CImGui.PopID()
                if !haskey(redolist, id)
                    redolist[id] = LoopVector(fill(AbstractBlock[], CONF.DAQ.historylen))
                    redolist[id][] = deepcopy(daqtask.blocks)
                end
                if !CImGui.IsMouseDown(0)
                    redolist[id][] ≈ daqtask.blocks || (move!(redolist[id]); redolist[id][] = deepcopy(daqtask.blocks))
                end
                all(.!mousein.(daqtask.blocks, true)) && CImGui.OpenPopupOnItemClick("add new Block")
                if CImGui.BeginPopup("add new Block")
                    if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add")))
                        newblock = addblockmenu(1)
                        isnothing(newblock) || push!(daqtask.blocks, newblock)
                        CImGui.EndMenu()
                    end
                    CImGui.Separator()
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Undo, " ", mlstr("Undo"))) && !isempty(redolist[id][-1])
                        move!(redolist[id], -1)
                        daqtask.blocks = deepcopy(redolist[id][])
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Redo, " ", mlstr("Redo"))) && !isempty(redolist[id][1])
                        move!(redolist[id])
                        daqtask.blocks = deepcopy(redolist[id][])
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Compile")))
                        @info "[$(now())]\n" codes = @trypasse prettify(compile(daqtask.blocks)) nothing
                    end
                    CImGui.EndPopup()
                end
                if unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
                    if CImGui.IsKeyPressed(ImGuiKey_Z, false) && !isempty(redolist[id][-1])
                        move!(redolist[id], -1)
                        daqtask.blocks = deepcopy(redolist[id][])
                    elseif CImGui.IsKeyPressed(ImGuiKey_Y, false) && !isempty(redolist[id][1])
                        move!(redolist[id])
                        daqtask.blocks = deepcopy(redolist[id][])
                    end
                end
            end
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        CImGui.End()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        p_open[] &= (isfocus | daqtask.hold)
    end
end

function saferun(daqtask::DAQTask)
    try
        run(daqtask)
    catch e
        @error "[$(now())]\n$(mlstr("running task terminated unexpectedly!!!"))" exception = e
        showbacktrace()
        if SYNCSTATES[Int(IsDAQTaskRunning)]
            SYNCSTATES[Int(IsInterrupted)] = true
            if SYNCSTATES[Int(IsBlocked)]
                SYNCSTATES[Int(IsBlocked)] = false
                remote_do(workers()[1]) do
                    lock(() -> notify(BLOCK), BLOCK)
                end
            end
        end
        t1 = time()
        while time() - t1 < 2CONF.DAQ.cttimeout && (!SYNCSTATES[Int(IsDAQTaskDone)] || isready(DATABUFRC) || isready(PROGRESSRC))
            isready(DATABUFRC) && take!(DATABUFRC)
            isready(PROGRESSRC) && take!(PROGRESSRC)
            sleep(0.001)
        end
        @warn "[$(now())]\n$(mlstr("terminates the task successfully!"))"
        SYNCSTATES[Int(IsDAQTaskDone)] = false
        SYNCSTATES[Int(IsDAQTaskRunning)] = false
    end
end

function run(daqtask::DAQTask)
    global WORKPATH
    global SAVEPATH
    global CFGCACHESAVEPATH
    global QDTCACHESAVEPATH
    global OLDI
    SYNCSTATES[Int(IsDAQTaskRunning)] = true
    SYNCSTATES[Int(IsAutoRefreshing)] = false
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
        SYNCSTATES[Int(IsDAQTaskRunning)] = false
        return nothing
    end
    run_remote(daqtask)
    wait(
        Threads.@spawn @trycatch mlstr("updating data failed!") begin
            savecfgcache()
            while update_all()
                yield()
            end
        end
    )
end


function run_remote(daqtask::DAQTask)
    remotecall_wait(() -> unsetbusy!(CPU), workers()[1])
    controllers, st = remotecall_fetch(extract_controllers, workers()[1], daqtask.blocks)
    empty!(DATABUF)
    empty!(DATABUFPARSED)
    if !st
        SYNCSTATES[Int(IsDAQTaskDone)] = true
        return
    end
    rn = length(controllers)
    ex1 = try
        compile(daqtask.blocks)
    catch e
        @error "[$(now())]\n$(mlstr("generating codes failed!!!"))" exception = e
        SYNCSTATES[Int(IsDAQTaskDone)] = true
        return
    end
    ex = quote
        $ex1
        function remote_do_block(databuf_rc, progress_rc, extradatabuf_rc, SYNCSTATES, rn)
            controllers = $controllers
            try
                databuf_lc = Channel{Tuple{String,String}}(CONF.DAQ.channelsize)
                progress_lc = Channel{Tuple{UUID,Int,Int,Float64}}(CONF.DAQ.channelsize)
                extradatabuf_lc = Channel{Tuple{String,Vector{String}}}(CONF.DAQ.channelsize)
                @sync begin
                    remotedotask = @async @trycatch mlstr("remotedotask failed!!!") begin
                        start!(CPU)
                        fast!(CPU)
                        for ct in values(controllers)
                            login!(CPU, ct; quiet=false, attr=getattr(ct.addr))
                        end
                        remote_sweep_block(controllers, databuf_lc, progress_lc, extradatabuf_lc, SYNCSTATES)
                    end
                    @async @trycatch mlstr("transfering data task failded!!!") while true
                        if istaskdone(remotedotask) && all(.!isready.(
                            [databuf_lc, databuf_rc, progress_lc, progress_rc, extradatabuf_lc, extradatabuf_rc]
                        ))
                            timed_remotecall_wait(eval, 1, :(log_instrbufferviewers()); timeout=60)
                            SYNCSTATES[Int(IsDAQTaskDone)] = true
                            break
                        else
                            isready(databuf_lc) && put!(databuf_rc, packtake!(databuf_lc, 2rn * CONF.DAQ.packsize))
                            isready(progress_lc) && put!(progress_rc, packtake!(progress_lc, CONF.DAQ.packsize))
                            isready(extradatabuf_lc) && put!(extradatabuf_rc, take!(extradatabuf_lc))
                        end
                        yield()
                    end
                end
            catch e
                @error "[$(now())]\n$(mlstr("task failed!!!"))" exeption = e
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
    timed_remotecall_wait(workers()[1], ex1, ex, SYNCSTATES; timeout=60) do ex1, ex, SYNCSTATES
        try
            @info "[$(now())]\n" task = prettify(ex1)
            eval(ex)
        catch e
            SYNCSTATES[Int(IsDAQTaskDone)] = true
            @error "[$(now())]\n$(mlstr("errors in program definition!!!"))" exception = e
            showbacktrace()
        end
    end
    SYNCSTATES[Int(IsDAQTaskDone)] && return
    remote_do(
        workers()[1], DATABUFRC, PROGRESSRC, EXTRADATABUFRC, SYNCSTATES, rn
    ) do databuf_rc, progress_rc, extradatabuf_rc, syncstates, rn
        try
            global BLOCK = Threads.Condition()
            remote_do_block(databuf_rc, progress_rc, extradatabuf_rc, syncstates, rn)
        catch e
            syncstates[Int(IsDAQTaskDone)] = true
            @error "[$(now())]\n$(mlstr("executing program failed!!!"))" exception = e
            showbacktrace()
        end
    end
end

function update_all()
    if SYNCSTATES[Int(IsDAQTaskDone)]
        (isfile(SAVEPATH) | !isempty(DATABUF)) && (saveqdt(); global OLDI += 1)
        lock(empty!, PROGRESSLIST)
        empty!(CFGBUF)
        SYNCSTATES[Int(IsDAQTaskDone)] = false
        SYNCSTATES[Int(IsDAQTaskRunning)] = false
        Base.Filesystem.rm(CFGCACHESAVEPATH; force=true)
        Base.Filesystem.rm(QDTCACHESAVEPATH; force=true)
        return false
    else
        update_data()
        update_progress()
        return true
    end
end

let
    cache::Vector{Tuple{String,String}} = []
    global function update_data()
        if isready(DATABUFRC)
            packdata = take!(DATABUFRC)
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
            waittime("savedatabuf", 3600CONF.DAQ.savetime) && saveqdt()
        end
        if isready(EXTRADATABUFRC)
            key, val = take!(EXTRADATABUFRC)
            DATABUF[key] = val
            DATABUFPARSED[key] = replace(tryparse.(Float64, val), nothing => NaN)
            haskey(CFGBUF, "EXTRADATA") || (CFGBUF["EXTRADATA"] = Dict())
            CFGBUF["EXTRADATA"][key] = val
        end
    end
end

function saveqdt()
    savetype = eval(Symbol(CONF.DAQ.savetype))
    jldopen(SAVEPATH, "w") do file
        if savetype == String
            file["data"] = DATABUF
        else
            datafloat = Dict()
            for (key, val) in DATABUF
                dataparsed = tryparse.(savetype, val)
                datafloat[key] = true in isnothing.(dataparsed) ? val : dataparsed
            end
            file["data"] = datafloat
        end
        file["circuit"] = CIRCUIT
        file["dataplot"] = norealtime!(deepcopy(DAQDATAPLOT))
        for (key, val) in CFGBUF
            key == "EXTRADATA" && continue
            file[key] = val
        end
        file["info"] = fileinfo()
        file["valid"] = false
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
        file["dataplot"] = deepcopy(DAQDATAPLOT)
        for (key, val) in CFGBUF
            file[key] = val
        end
        file["info"] = fileinfo()
        file["valid"] = false
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
            ct = Controller(
                bk.instrnm, bk.addr;
                buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout,
                busytimeout=CONF.DAQ.cttimeout * CONF.DAQ.retryconnecttimes * CONF.DAQ.retrysendtimes
            )
            try
                @assert haskey(INSTRBUFFERVIEWERS, bk.instrnm) mlstr("$(bk.instrnm) has not been added")
                @assert haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr) mlstr("$(bk.addr) has not been added")
                login!(CPU, ct; attr=getattr(bk.addr))
                ct(query, CPU, "*IDN?", Val(:query))
                controllers[string(bk.instrnm, "/", bk.addr)] = ct
            catch e
                @error(
                    "[$(now())]\n$(mlstr("incorrect instrument settings!!!"))",
                    instrument = string(bk.instrnm, ": ", bk.addr),
                    exception = e
                )
                showbacktrace()
                return controllers, false
            finally
                logout!(CPU, ct)
            end
        end
        if iscontainer(bk)
            inner_controllers, inner_st = extract_controllers(bk.blocks)
            inner_st || return controllers, false
            merge!(controllers, inner_controllers)
        end
    end
    controllers, true
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