mutable struct DAQTask
    name::String
    explog::String
    blocks::Vector{AbstractBlock}
    enable::Bool
    hold::Bool
end
DAQTask() = DAQTask("", "", [SweepBlock(1)], true, false)

global OLDI::Int = 0
global WORKPATH::String = ""
global SAVEPATH::String = ""
const CFGBUF = Dict{String,Any}()

let
    holdsz::Cfloat = 0
    viewmode::Bool = false
    # global redolist::Dict{Int,LoopVector{Vector{AbstractBlock}}} = Dict()
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
            CImGui.BeginChild("Blocks")
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, MORESTYLE.Icons.TaskButton)
            CImGui.SameLine()
            CImGui.Text(stcstr(" ", mlstr("Edit queue: Task")," ", id + OLDI, " ", daqtask.name))
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
            @c CImGui.Checkbox(mlstr("HOLD"), &daqtask.hold)
            holdsz = CImGui.GetItemRectSize().x
            CImGui.Separator()
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("experimental record"))
            y = (1 + length(findall("\n", daqtask.explog))) * CImGui.GetTextLineHeight() +
                2unsafe_load(IMGUISTYLE.FramePadding.y)
            @c InputTextMultilineRSZ("##experimental record", &daqtask.explog, (Float32(-1), y))
            if CImGui.BeginPopupContextItem("clear##experimental record")
                CImGui.MenuItem(stcstr(mlstr("clear"), "##experimental record")) && (daqtask.explog = "")
                CImGui.EndPopup()
            end
            CImGui.Button(
                stcstr(MORESTYLE.Icons.InstrumentsAutoDetect, " ", mlstr("Refresh instrument list"))
            ) && refresh_instrlist()
            if CImGui.BeginPopupContextItem()
                manualadd_ui()
                CImGui.EndPopup()
            end
            if SYNCSTATES[Int(AutoDetecting)]
                CImGui.SameLine()
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(mlstr("searching instruments"), "......"))
            end
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
            @c CImGui.Checkbox(viewmode ? mlstr("View") : mlstr("Edit"), &viewmode)
            CImGui.PushID(id)
            CImGui.BeginChild("DAQTask.blocks")
            viewmode ? view(daqtask.blocks) : edit(daqtask.blocks, 1)
            CImGui.EndChild()
            # haskey(redolist, id) || (push!(redolist, id => LoopVector(fill(AbstractBlock[], 10))); redolist[id][] = deepcopy(daqtask.blocks))
            # redolist[id][] == daqtask.blocks || (move!(redolist[id]); redolist[id][] = deepcopy(daqtask.blocks))
            all(.!mousein.(daqtask.blocks, true)) && CImGui.OpenPopupOnItemClick("add new Block")
            if CImGui.BeginPopup("add new Block")
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add")))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CodeBlock, " ", mlstr("CodeBlock"))) && push!(daqtask.blocks, CodeBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.StrideCodeBlock, " ", mlstr("StrideCodeBlock"))) && push!(daqtask.blocks, StrideCodeBlock(1))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SweepBlock, " ", mlstr("SweepBlock"))) && push!(daqtask.blocks, SweepBlock(1))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SettingBlock, " ", mlstr("SettingBlock"))) && push!(daqtask.blocks, SettingBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadingBlock, " ", mlstr("ReadingBlock"))) && push!(daqtask.blocks, ReadingBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.LogBlock, " ", mlstr("LogBlock"))) && push!(daqtask.blocks, LogBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.WriteBlock, " ", mlstr("WriteBlock"))) && push!(daqtask.blocks, WriteBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.QueryBlock, " ", mlstr("QueryBlock"))) && push!(daqtask.blocks, QueryBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadBlock, " ", mlstr("ReadBlock"))) && push!(daqtask.blocks, ReadBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveBlock, " ", mlstr("SaveBlock"))) && push!(daqtask.blocks, SaveBlock())
                    # CImGui.MenuItem("undo") && (move!(redolist[id], -1); daqtask.blocks = deepcopy(redolist[id][]))
                    # CImGui.MenuItem("redo") && (move!(redolist[id]); daqtask.blocks = deepcopy(redolist[id][]))
                    CImGui.EndMenu()
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Interpret")))
                    codes = @trypasse quote
                        $(tocodes.(daqtask.blocks)...)
                    end |> prettify @error "[$(now())]\n$(mlstr("interpreting blocks failed!!!"))"
                    isnothing(codes) || @info codes
                end
                CImGui.EndPopup()
            end
            CImGui.EndChild()
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        CImGui.End()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        p_open[] &= (isfocus | daqtask.hold)
    end
end

function run(daqtask::DAQTask)
    global WORKPATH
    global SAVEPATH
    global OLDI
    daqtask.enable || return
    SYNCSTATES[Int(IsDAQTaskRunning)] = true
    date = today()
    find_old_i(joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date)))
    cfgsvdir = joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date))
    ispath(cfgsvdir) || mkpath(cfgsvdir)
    SAVEPATH = joinpath(cfgsvdir, replace("[$(now())] $(mlstr("Task")) $(1+OLDI) $(daqtask.name).qdt", ':' => '.'))
    push!(CFGBUF, "daqtask" => daqtask)
    try
        log_instrbufferviewers()
    catch e
        @error "[($now())]\n$(mlstr("instrument logging error, program terminates!!!"))" exception = e
        SYNCSTATES[Int(IsDAQTaskRunning)] = false
        return nothing
    end
    run_remote(daqtask)
    wait(
        @async while update_all()
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
    ex = quote
        function remote_sweep_block(controllers, databuf_lc, progress_lc, SYNCSTATES)
            $(blockcodes...)
        end
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
    end |> prettify
    remotecall_wait(workers()[1], ex, SYNCSTATES) do ex, SYNCSTATES
        try
            @info "[$(now())]\n" task = ex
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
            jldopen(SAVEPATH, "w") do file
                file["data"] = DATABUF
                file["circuit"] = CIRCUIT
                file["uiplots"] = UIPSWEEPS
                file["datapickers"] = DAQDTPKS
                file["plotlayout"] = DAQPLOTLAYOUT
                for (key, val) in CFGBUF
                    file[key] = val
                end
            end
        end
    end
end

function update_all()
    if SYNCSTATES[Int(IsDAQTaskDone)]
        if isfile(SAVEPATH) || !isempty(DATABUF)
            jldopen(SAVEPATH, "w") do file
                file["data"] = DATABUF
                file["circuit"] = CIRCUIT
                file["uiplots"] = UIPSWEEPS
                file["datapickers"] = DAQDTPKS
                file["plotlayout"] = DAQPLOTLAYOUT
                for (key, val) in CFGBUF
                    file[key] = val
                end
            end
            if CONF.DAQ.saveimg
                if isempty(DAQPLOTLAYOUT.selectedidx)
                    saveimg_seting("$SAVEPATH.png", UIPSWEEPS[[1]])
                else
                    saveimg_seting("$SAVEPATH.png", UIPSWEEPS[DAQPLOTLAYOUT.selectedidx])
                end
                SYNCSTATES[Int(SavingImg)] = true
            end
            global OLDI += 1
        end
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
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("experimental record"))
    TextRect(string(daqtask.explog, "\n "))
    view(daqtask.blocks)
    CImGui.EndChild()
end