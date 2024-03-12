@kwdef mutable struct DAQTask
    name::String = ""
    explog::String = ""
    blocks::Vector{AbstractBlock} = [SweepBlock()]
    hold::Bool = false
end

global OLDI::Int = 0
global WORKPATH::String = ""
global SAVEPATH::String = ""
const CFGBUF = Dict{String,Any}()

let
    viewmode::Bool = false
    redolist::Dict{Int,LoopVector{Vector{AbstractBlock}}} = Dict()
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
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - 3ftsz)
            CImGui.Button(viewmode ? MORESTYLE.Icons.View : MORESTYLE.Icons.Edit, (3ftsz / 2, Cfloat(0))) && (viewmode ⊻= true)
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
            if SYNCSTATES[Int(AutoDetecting)]
                CImGui.SameLine()
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(mlstr("searching instruments"), "......"))
            end
            CImGui.PushID(id)
            dragblockmenu(id)
            CImGui.BeginChild("DAQTask.blocks")
            CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.NormalBlockBorder)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
            viewmode ? view(daqtask.blocks) : edit(daqtask.blocks, 1, id)
            CImGui.PopStyleVar()
            CImGui.PopStyleColor()
            CImGui.EndChild()
            if !haskey(redolist, id)
                push!(redolist, id => LoopVector(fill(AbstractBlock[], CONF.DAQ.historylen)))
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
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Interpret"))) && interpret(daqtask.blocks)
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
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        CImGui.End()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        p_open[] &= (isfocus | daqtask.hold)
    end
end

function interpret(blocks::Vector{AbstractBlock})
    codes = @trypasse quote
        $(tocodes.(blocks)...)
    end |> prettify @error "[$(now())]\n$(mlstr("interpreting blocks failed!!!"))"
    return isnothing(codes) ? :nothing : (@info "[$(now())]\n$codes"; codes)
end

function run(daqtask::DAQTask)
    global WORKPATH
    global SAVEPATH
    global OLDI
    SYNCSTATES[Int(IsDAQTaskRunning)] = true
    SYNCSTATES[Int(IsAutoRefreshing)] = false
    date = today()
    find_old_i(joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date)))
    cfgsvdir = joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date))
    ispath(cfgsvdir) || mkpath(cfgsvdir)
    SAVEPATH = joinpath(cfgsvdir, replace("[$(now())] $(mlstr("Task")) $(1+OLDI) $(daqtask.name).qdt", ':' => '.'))
    push!(CFGBUF, "daqtask" => deepcopy(daqtask))
    try
        log_instrbufferviewers()
    catch e
        @error "[($now())]\n$(mlstr("instrument logging error, program terminates!!!"))" exception = e
        SYNCSTATES[Int(IsDAQTaskRunning)] = false
        return nothing
    end
    run_remote(daqtask)
    wait(
        Threads.@spawn while update_all()
            yield()
        end
    )
end


function run_remote(daqtask::DAQTask)
    controllers, st = remotecall_fetch(extract_controllers, workers()[1], daqtask.blocks)
    empty!(DATABUF)
    empty!(DATABUFPARSED)
    if !st
        SYNCSTATES[Int(IsDAQTaskDone)] = true
        return
    end
    rn = length(controllers)
    blockcodes = @trypasse tocodes.(daqtask.blocks) begin
        @error "[$(now())]\n$(mlstr("generating codes failed!!!"))"
        SYNCSTATES[Int(IsDAQTaskDone)] = true
        return
    end
    ex1 = quote
        function remote_sweep_block(controllers, databuf_lc, progress_lc, SYNCSTATES)
            $(blockcodes...)
        end
    end
    ex = quote
        $ex1
        function remote_do_block(databuf_rc, progress_rc, SYNCSTATES, rn)
            controllers = $controllers
            try
                databuf_lc = Channel{Tuple{String,String}}(CONF.DAQ.channel_size)
                progress_lc = Channel{Tuple{UUID,Int,Int,Float64}}(CONF.DAQ.channel_size)
                @sync begin
                    remotedotask = errormonitor(@async begin
                        remotecall_wait(() -> (start!(CPU); fast!(CPU)), workers()[1])
                        for ct in values(controllers)
                            login!(CPU, ct)
                        end
                        remote_sweep_block(controllers, databuf_lc, progress_lc, SYNCSTATES)
                    end)
                    errormonitor(@async while true
                        if istaskdone(remotedotask) && all(.!isready.([databuf_lc, databuf_rc, progress_lc, progress_rc]))
                            remotecall_wait(eval, 1, :(log_instrbufferviewers()))
                            SYNCSTATES[Int(IsDAQTaskDone)] = true
                            break
                        else
                            isready(databuf_lc) && put!(databuf_rc, packtake!(databuf_lc, 2rn * CONF.DAQ.packsize))
                            isready(progress_lc) && put!(progress_rc, packtake!(progress_lc, CONF.DAQ.packsize))
                        end
                        yield()
                    end)
                end
            catch e
                @error "[$(now())]\n$(mlstr("task failed!!!"))" exeption = e
            finally
                for ct in values(controllers)
                    logout!(CPU, ct)
                end
                slow!(CPU)
            end
        end
    end
    remotecall_wait(workers()[1], ex1, ex, SYNCSTATES) do ex1, ex, SYNCSTATES
        try
            @info "[$(now())]\n" task = prettify(ex1)
            eval(ex)
        catch e
            SYNCSTATES[Int(IsDAQTaskDone)] = true
            @error "[$(now())]\n$(mlstr("errors in program definition!!!"))" exception = e
        end
    end
    SYNCSTATES[Int(IsDAQTaskDone)] && return
    remote_do(workers()[1], DATABUFRC, PROGRESSRC, SYNCSTATES, rn) do databuf_rc, progress_rc, syncstates, rn
        try
            global BLOCK = Threads.Condition()
            remote_do_block(databuf_rc, progress_rc, syncstates, rn)
        catch e
            syncstates[Int(IsDAQTaskDone)] = true
            @error "[$(now())]\n$(mlstr("executing program failed!!!"))" exception = e
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
                push!(datafloat, key => true in isnothing.(dataparsed) ? val : dataparsed)
            end
            file["data"] = datafloat
        end
        file["circuit"] = CIRCUIT
        file["dataplot"] = empty!(deepcopy(DAQDATAPLOT))
        for (key, val) in CFGBUF
            file[key] = val
        end
    end
end

function update_data()
    if isready(DATABUFRC)
        packdata = take!(DATABUFRC)
        for data in packdata
            haskey(DATABUF, data[1]) || push!(DATABUF, data[1] => String[])
            haskey(DATABUFPARSED, data[1]) || push!(DATABUFPARSED, data[1] => Float64[])
            push!(DATABUF[data[1]], data[2])
            parsed_data = tryparse(Float64, data[2])
            push!(DATABUFPARSED[data[1]], isnothing(parsed_data) ? NaN : parsed_data)
            splitdata = split(data[1], "_")
            if length(splitdata) == 4
                _, instrnm, qt, addr = splitdata
            else
                continue
            end
            occursin(r"\[.*\]", qt) && continue
            insbuf = INSTRBUFFERVIEWERS[instrnm][addr].insbuf
            insbuf.quantities[qt].read = data[2]
            updatefront!(insbuf.quantities[qt])
        end
        if waittime("savedatabuf", CONF.DAQ.savetime)
            saveqdt()
        end
    end
end

function update_all()
    if SYNCSTATES[Int(IsDAQTaskDone)]
        (isfile(SAVEPATH) | !isempty(DATABUF)) && (saveqdt(); global OLDI += 1)
        empty!(PROGRESSLIST)
        empty!(CFGBUF)
        SYNCSTATES[Int(IsDAQTaskDone)] = false
        SYNCSTATES[Int(IsDAQTaskRunning)] = false
        return false
    else
        update_data()
        update_progress()
        return true
    end
end

function extract_controllers(bkch::Vector{AbstractBlock})
    controllers = Dict()
    for bk in bkch
        if typeof(bk) in [SettingBlock, SweepBlock, ReadingBlock, WriteBlock, QueryBlock, ReadBlock]
            bk.instrnm == "VirtualInstr" && bk.addr != "VirtualAddress" && return controllers, false
            ct = Controller(bk.instrnm, bk.addr)
            try
                login!(CPU, ct)
                ct(query, CPU, "*IDN?", Val(:query))
                logout!(CPU, ct)
                push!(controllers, string(bk.instrnm, "_", bk.addr) => ct)
            catch e
                @error(
                    "[$(now())]\n$(mlstr("incorrect instrument settings!!!"))",
                    instrument = string(bk.instrnm, ": ", bk.addr),
                    exception = e
                )
                logout!(CPU, ct)
                return controllers, false
            end
        end
        if typeof(bk) in [SweepBlock, StrideCodeBlock]
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
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("Experimental Records"))
    TextRect(string(daqtask.explog, "\n "); nochild=true)
    view(daqtask.blocks)
    CImGui.EndChild()
end