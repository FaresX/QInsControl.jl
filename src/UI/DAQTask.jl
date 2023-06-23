mutable struct DAQTask
    name::String
    explog::String
    blocks::Vector{AbstractBlock}
    enable::Bool
end
DAQTask() = DAQTask("", "", [SweepBlock(1)], true)

old_i::Int = 0
workpath::String = ""
savepath::String = ""
const cfgbuf = Dict{String,Any}()

let
    hold::Bool = false
    holdsz::Cfloat = 0
    global function edit(daqtask::DAQTask, id, p_open::Ref{Bool})
        CImGui.SetNextWindowSize((600, 800), CImGui.ImGuiCond_Once)
        CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_PopupBg))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, unsafe_load(imguistyle.PopupRounding))
        isfocus = true
        global old_i
        if CImGui.Begin(stcstr("编辑任务 ", id), p_open, CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking)
            CImGui.BeginChild("Blocks")
            CImGui.TextColored(morestyle.Colors.HighlightText, morestyle.Icons.TaskButton)
            CImGui.SameLine()
            CImGui.Text(stcstr(" 编辑队列：任务 ", id + old_i, " ", daqtask.name))
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
            @c CImGui.Checkbox("HOLD", &hold)
            holdsz = CImGui.GetItemRectSize().x
            CImGui.Separator()
            CImGui.TextColored(morestyle.Colors.HighlightText, "实验记录")
            y = (1 + length(findall("\n", daqtask.explog))) * CImGui.GetTextLineHeight() + 2unsafe_load(imguistyle.FramePadding.y)
            @c InputTextMultilineRSZ("##实验记录", &daqtask.explog, (Float32(-1), y))
            if CImGui.BeginPopupContextItem("清空##实验记录")
                CImGui.MenuItem("清空##实验记录") && (daqtask.explog = "")
                CImGui.EndPopup()
            end
            CImGui.Button(stcstr(morestyle.Icons.InstrumentsAutoDetect, " 刷新仪器列表")) && refresh_instrlist()
            if CImGui.BeginPopupContextItem()
                manualadd_ui()
                CImGui.EndPopup()
            end
            if SyncStates[Int(autodetecting)]
                CImGui.SameLine()
                CImGui.TextColored(morestyle.Colors.HighlightText, "查找仪器中......")
            end
            CImGui.PushID(id)
            CImGui.BeginChild("DAQTask.blocks")
            edit(daqtask.blocks, 1)
            CImGui.EndChild()
            all(.!mousein.(daqtask.blocks, true)) && CImGui.OpenPopupOnItemClick("添加新Block")
            if CImGui.BeginPopup("添加新Block")
                if CImGui.BeginMenu(morestyle.Icons.NewFile * " 添加")
                    CImGui.MenuItem(morestyle.Icons.CodeBlock * " CodeBlock") && push!(daqtask.blocks, CodeBlock())
                    CImGui.MenuItem(morestyle.Icons.StrideCodeBlock * " StrideCodeBlock") && push!(daqtask.blocks, StrideCodeBlock(1))
                    CImGui.MenuItem(morestyle.Icons.SettingBlock * " SettingBlock") && push!(daqtask.blocks, SettingBlock())
                    CImGui.MenuItem(morestyle.Icons.SweepBlock * " SweepBlock") && push!(daqtask.blocks, SweepBlock(1))
                    CImGui.MenuItem(morestyle.Icons.ReadingBlock * " ReadingBlock") && push!(daqtask.blocks, ReadingBlock())
                    CImGui.MenuItem(morestyle.Icons.LogBlock * " LogBlock") && push!(daqtask.blocks, LogBlock())
                    CImGui.MenuItem(morestyle.Icons.WriteBlock * " WriteBlock") && push!(daqtask.blocks, WriteBlock())
                    CImGui.MenuItem(morestyle.Icons.QueryBlock * " QueryBlock") && push!(daqtask.blocks, QueryBlock())
                    CImGui.MenuItem(morestyle.Icons.ReadBlock * " ReadBlock") && push!(daqtask.blocks, ReadBlock())
                    CImGui.MenuItem(morestyle.Icons.SaveBlock * " SaveBlock") && push!(daqtask.blocks, SaveBlock())
                    CImGui.EndMenu()
                end
                CImGui.EndPopup()
            end
            CImGui.EndChild()
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        CImGui.End()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        p_open[] &= (isfocus | hold)
    end
end

function run(daqtask::DAQTask)
    global workpath
    global savepath
    global old_i
    global issweeping
    daqtask.enable || return
    SyncStates[Int(isdaqtask_running)] = true
    date = today()
    find_old_i(joinpath(workpath, string(year(date)), string(year(date), "-", month(date)), string(date)))
    cfgsvdir = joinpath(workpath, string(year(date)), string(year(date), "-", month(date)), string(date))
    ispath(cfgsvdir) || mkpath(cfgsvdir)
    savepath = joinpath(cfgsvdir, replace("[$(now())] 任务 $(1+old_i) $(daqtask.name).qdt", ':' => '.'))
    push!(cfgbuf, "daqtask" => daqtask)
    try
        log_instrbufferviewers()
    catch e
        @error "[($now())]\n仪器记录错误，程序终止！！！" exception = e
        SyncStates[Int(isdaqtask_running)] = false
        return
    end
    run_remote(daqtask)
    wait(
        @async while update_all()
            yield()
        end
    )
end

const block::Threads.Condition = Threads.Condition()
function run_remote(daqtask::DAQTask)
    controllers, st = extract_controllers(daqtask.blocks)
    empty!(databuf)
    empty!(databuf_parsed)
    if !st
        SyncStates[Int(isdaqtask_done)] = true
        return
    end
    blockcodes = @trypasse tocodes.(daqtask.blocks) begin
        @error "[$(now())]\n代码生成失败!!!"
        SyncStates[Int(isdaqtask_done)] = true
        return
    end
    ex = quote
        function remote_sweep_block(controllers, SyncStates)
            $(blockcodes...)
        end
        function remote_do_block()
            controllers = $controllers
            try
                @sync begin
                    start!(CPU)
                    fast!(CPU)
                    for ct in values(controllers)
                        login!(CPU, ct)
                    end
                    remotedotask = errormonitor(Threads.@spawn remote_sweep_block(controllers, SyncStates))
                    errormonitor(@async while true
                        if istaskdone(remotedotask) && !isready(databuf_lc) && !isready(progress_lc)
                            SyncStates[Int(isdaqtask_done)] = true
                            break
                        end
                        yield()
                    end)
                end
            catch e
                @error "[$(now())]\n任务失败！！！" exeption = e
                SyncStates[Int(isdaqtask_done)] = true
            finally
                for ct in values(controllers)
                    logout!(CPU, ct)
                end
                slow!(CPU)
            end
        end
    end |> prettify
    try
        @info "[$(now())]\n" task = ex
        @eval $ex
    catch e
        SyncStates[Int(isdaqtask_done)] = true
        @error "[$(now())]\n程序定义有误！！！" exception = e
    end
    SyncStates[Int(isdaqtask_done)] && return
    errormonitor(Threads.@spawn @eval remote_do_block())
end

function update_data()
    if isready(databuf_lc)
        key, val = take!(databuf_lc)
        haskey(databuf, key) || push!(databuf, key => String[])
        haskey(databuf_parsed, key) || push!(databuf_parsed, key => Float64[])
        push!(databuf[key], val)
        parsed_data = tryparse(Float64, val)
        push!(databuf_parsed[key], isnothing(parsed_data) ? NaN : parsed_data)
        if !occursin(r"\[.*\]", key)
            splitdata = split(key, "_")
            if length(splitdata) == 4
                _, instrnm, qt, addr = splitdata
                insbuf = instrbufferviewers[instrnm][addr].insbuf
                insbuf.quantities[qt].read = val
                updatefront!(insbuf.quantities[qt])
            end
        end
        if waittime("savedatabuf", conf.DAQ.savetime)
            jldopen(savepath, "w") do file
                file["data"] = databuf
                file["circuit"] = circuit_editor
                file["uiplots"] = uipsweeps
                file["datapickers"] = daq_dtpks
                file["plotlayout"] = daq_plot_layout
                for (key, val) in cfgbuf
                    file[key] = val
                end
            end
        end
    end
end

function update_all()
    if SyncStates[Int(isdaqtask_done)]
        if isfile(savepath) || !isempty(databuf)
            try
                log_instrbufferviewers()
            catch e
                @error "[$(now())]\n仪器记录错误，无法保存结束状态！！！" exception = e
            end
            jldopen(savepath, "w") do file
                file["data"] = databuf
                file["circuit"] = circuit_editor
                file["uiplots"] = uipsweeps
                file["datapickers"] = daq_dtpks
                file["plotlayout"] = daq_plot_layout
                for (key, val) in cfgbuf
                    file[key] = val
                end
            end
            if conf.DAQ.saveimg
                if isempty(daq_plot_layout.selectedidx)
                    saveimg_seting("$savepath.png", uipsweeps[[1]])
                else
                    saveimg_seting("$savepath.png", uipsweeps[daq_plot_layout.selectedidx])
                end
                SyncStates[Int(savingimg)] = true
            end
            global old_i += 1
        end
        empty!(progresslist)
        empty!(cfgbuf)
        SyncStates[Int(isdaqtask_done)] = false
        SyncStates[Int(isdaqtask_running)] = false
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
                @error "[$(now())]\n仪器设置不正确！！！" instrument = string(bk.instrnm, ": ", bk.addr) exception = e
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
    CImGui.BeginChild("查看DAQTask")
    CImGui.TextColored(morestyle.Colors.HighlightText, "实验记录")
    TextRect(string(daqtask.explog, "\n "))
    view(daqtask.blocks)
    CImGui.EndChild()
end