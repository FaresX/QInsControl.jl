let
    firsttime::Bool = true
    show_daq_editors::Vector{Bool} = [false]
    show_daq_dtpickers::Vector{Bool} = [false]
    show_circuit_editor::Bool = false
    isdeldaqtask::Bool = false
    isrename::Bool = false
    showdisabled::Bool = false
    isdelall::Bool = false
    oldworkpath::String = ""
    running_i::Int = 0
    isrunall::Bool = false
    daqtasks::Vector{DAQTask} = [DAQTask()] #任务列表
    global CIRCUIT::NodeEditor = NodeEditor()
    global UIPSWEEPS::Vector{UIPlot} = [UIPlot()] #绘图缓存
    global DAQDTPKS::Vector{DataPicker} = [DataPicker()] #绘图数据选择
    global DAQPLOTLAYOUT::Layout = Layout("DAQ Plot Layout", 3, 1, ["1"], [""], falses(1), [], Dict(), [])
    isdelplot::Bool = false
    delplot_i::Int = 0
    # layout
    ccbtsz::Cfloat = 0
    bottombtsz::Cfloat = 0

    global function DAQ(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin(stcstr(MORESTYLE.Icons.InstrumentsDAQ, "  ", mlstr("Data Acquiring")), p_open)
            global WORKPATH
            global OLDI
            CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, " ", mlstr("Workplace"), " ")) && (WORKPATH = pick_folder())
            CImGui.SameLine()
            CImGui.TextColored(
                if WORKPATH == mlstr("no workplace selected!!!")
                    MORESTYLE.Colors.LogError
                else
                    CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
                end,
                WORKPATH
            )
            if WORKPATH != oldworkpath
                if isdir(WORKPATH)
                    oldworkpath = WORKPATH
                    date = today()
                    find_old_i(
                        joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date))
                    )
                else
                    OLDI = 0
                end
            end
            CImGui.Separator()
            CImGui.Columns(2)
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            column1pos = CImGui.GetColumnOffset(1)
            CImGui.BeginChild("queue", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))
            CImGui.BulletText(mlstr("Task Queue"))
            CImGui.SameLine(column1pos - ccbtsz - unsafe_load(IMGUISTYLE.WindowPadding.x) - 3)
            CImGui.Button(stcstr(MORESTYLE.Icons.Circuit, "##circuit")) && (show_circuit_editor ⊻= true)
            show_circuit_editor && @c edit(CIRCUIT, "Circuit Editor", &show_circuit_editor)
            ccbtsz = CImGui.GetItemRectSize().x

            length(show_daq_editors) == length(daqtasks) || resize!(show_daq_editors, length(daqtasks))
            length(show_daq_dtpickers) == length(DAQDTPKS) || resize!(show_daq_dtpickers, length(DAQDTPKS))
            for (i, task) in enumerate(daqtasks)
                task.enable || showdisabled || continue
                CImGui.PushID(i)
                isrunning_i = SYNCSTATES[Int(IsDAQTaskRunning)] && i == running_i
                CImGui.PushStyleColor(
                    CImGui.ImGuiCol_Button,
                    if task.enable
                        if isrunning_i
                            MORESTYLE.Colors.DAQTaskRunning
                        else
                            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
                        end
                    else
                        MORESTYLE.Colors.LogError
                    end
                )
                CImGui.PushStyleColor(
                    CImGui.ImGuiCol_ButtonHovered,
                    if task.enable
                        if isrunning_i
                            MORESTYLE.Colors.DAQTaskRunning
                        else
                            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
                        end
                    else
                        MORESTYLE.Colors.LogError
                    end
                )
                if CImGui.Button(
                    stcstr(MORESTYLE.Icons.TaskButton, " ", mlstr("Task"), " ", i + OLDI, " ", task.name, "###rename"),
                    (-1, 0)
                )
                    show_daq_editors[i] = true
                end
                CImGui.PopStyleColor(2)

                CImGui.OpenPopupOnItemClick(stcstr("edit queue menu", i))
                isrunning_i && ShowProgressBar()
                if !SYNCSTATES[Int(IsDAQTaskRunning)]
                    CImGui.Indent()
                    if CImGui.BeginDragDropSource(0)
                        @c CImGui.SetDragDropPayload("Swap DAQTask", &i, sizeof(Cint))
                        CImGui.Text(stcstr(mlstr("Task"), " ", i + OLDI, " ", task.name))
                        CImGui.EndDragDropSource()
                    end
                    if CImGui.BeginDragDropTarget()
                        payload = CImGui.AcceptDragDropPayload("Swap DAQTask")
                        if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                            payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                            if i != payload_i
                                insert!(daqtasks, i, daqtasks[payload_i])
                                payload_i < i ? deleteat!(daqtasks, payload_i) : deleteat!(daqtasks, payload_i + 1)
                            end
                        end
                        CImGui.EndDragDropTarget()
                    end
                    CImGui.Unindent()
                end

                if CImGui.BeginPopup(stcstr("edit queue menu", i))
                    if CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.RunTask, " ", mlstr("Run")),
                        C_NULL,
                        false,
                        !SYNCSTATES[Int(IsDAQTaskRunning)] && task.enable
                    )
                        if ispath(WORKPATH)
                            running_i = i
                            errormonitor(@async begin
                                run(task)
                                SYNCSTATES[Int(IsInterrupted)] && (SYNCSTATES[Int(IsInterrupted)] = false)
                            end)
                            show_daq_dtpickers .= false
                        else
                            WORKPATH = mlstr("no workplace selected!!!")
                        end
                    end
                    CImGui.Separator()
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Edit, " ", mlstr("Edit"))) && (show_daq_editors[i] = true)
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy"))) && (insert!(daqtasks, i + 1, deepcopy(task)))
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")))
                        confsvpath = save_file(filterlist="cfg")
                        isempty(confsvpath) || jldsave(confsvpath; daqtask=task)
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load")))
                        confldpath = pick_file(filterlist="cfg,qdt")
                        if isfile(confldpath)
                            loadcfg = @trypass load(confldpath, "daqtask") begin
                                @error mlstr("unsupported file!!!") filepath = confldpath
                            end
                            daqtasks[i] = isnothing(loadcfg) ? task : loadcfg
                        end
                    end
                    CImGui.Separator()
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Rename, " ", mlstr("Rename"))) && (isrename = true)
                    if task.enable
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.Disable, " ", mlstr("Disable"))) && (task.enable = false)
                    else
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.Restore, " ", mlstr("Enable"))) && (task.enable = true)
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (isdeldaqtask = true)
                    end
                    CImGui.EndPopup()
                end

                ### show daq editors ###
                isshow_editor = show_daq_editors[i]
                isshow_editor && @c edit(task, i, &isshow_editor)
                show_daq_editors[i] = isshow_editor

                # 是否删除
                isdeldaqtask && (CImGui.OpenPopup(stcstr("##if delete daqtasks", i));
                isdeldaqtask = false)
                if YesNoDialog(
                    stcstr("##if delete daqtasks", i),
                    mlstr("Confirm delete?"),
                    CImGui.ImGuiWindowFlags_AlwaysAutoResize
                )
                    deleteat!(daqtasks, i)
                    deleteat!(show_daq_editors, i)
                end

                # 重命名
                isrename && (CImGui.OpenPopup(stcstr(mlstr("rename"), i));
                isrename = false)
                if CImGui.BeginPopup(stcstr(mlstr("rename"), i))
                    @c InputTextRSZ(stcstr(MORESTYLE.Icons.TaskButton, " ", mlstr("Task"), " ", i + OLDI), &task.name)
                    CImGui.EndPopup()
                end
                CImGui.PopID()
            end
            CImGui.EndChild()

            if CImGui.BeginPopup("add task")
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add"))) && push!(daqtasks, DAQTask())
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load")))
                    confldpath = pick_file(filterlist="cfg")
                    if isfile(confldpath)
                        newdaqtask = @trypasse load(confldpath, "daqtask") begin
                            @error mlstr("unsupported file!!!") filepath = confldpath
                        end
                        isnothing(newdaqtask) || push!(daqtasks, newdaqtask)
                    end
                end
                CImGui.Separator()
                if showdisabled
                    CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.NotShowDisable, " ", mlstr("Hide Disabled"))
                    ) && (showdisabled = false)
                    CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete Disabled"))
                    ) && (isdelall = true)
                else
                    CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.ShowDisable, " ", mlstr("Show Disabled"))
                    ) && (showdisabled = true)
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save Project")))
                    daqsvpath = save_file(filterlist="daq")
                    if daqsvpath != ""
                        jldsave(daqsvpath;
                            daqtasks=daqtasks,
                            circuit=CIRCUIT,
                            uiplots=UIPSWEEPS,
                            datapickers=DAQDTPKS,
                            plotlayout=DAQPLOTLAYOUT
                        )
                    end
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load Project")))
                    daqloadpath = pick_file(filterlist="daq")
                    if isfile(daqloadpath)
                        loaddaqproj = @trypasse load(daqloadpath) begin
                            @error mlstr("unsupported file!!!") filepath = daqloadpath
                        end
                        if !isnothing(loaddaqproj)
                            if haskey(loaddaqproj, "daqtasks")
                                empty!(daqtasks)
                                for task in loaddaqproj["daqtasks"]
                                    push!(daqtasks, task)
                                end
                            end
                            if haskey(loaddaqproj, "circuit")
                                CIRCUIT = loaddaqproj["circuit"]
                                for (_, node) in CIRCUIT.nodes
                                    if node isa SampleBaseNode
                                        try
                                            imgsize = size(node.imgr.image)
                                            node.imgr.id = ImGui_ImplOpenGL3_CreateImageTexture(imgsize...)
                                            ImGui_ImplOpenGL3_UpdateImageTexture(node.imgr.id, node.imgr.image, imgsize...)
                                        catch e
                                            @error "[$(now())]\n$(mlstr("loading image failed!!!"))" exception = e
                                        end
                                    end
                                end
                            end
                            if haskey(loaddaqproj, "uiplots")
                                empty!(UIPSWEEPS)
                                for uip in loaddaqproj["uiplots"]
                                    push!(UIPSWEEPS, uip)
                                end
                            end
                            if haskey(loaddaqproj, "datapickers")
                                empty!(DAQDTPKS)
                                for dtpk in loaddaqproj["datapickers"]
                                    push!(DAQDTPKS, dtpk)
                                end
                            end
                            haskey(loaddaqproj, "plotlayout") && (DAQPLOTLAYOUT = loaddaqproj["plotlayout"])
                        end
                    end
                end
                CImGui.Separator()
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot")))
                    CImGui.Text(mlstr("plot columns"))
                    CImGui.SameLine()
                    CImGui.PushItemWidth(2CImGui.GetFontSize())
                    @c CImGui.DragInt(
                        "##plot columns",
                        &CONF.DAQ.plotshowcol,
                        1, 1, 6, "%d",
                        CImGui.ImGuiSliderFlags_AlwaysClamp
                    )
                    CImGui.PopItemWidth()
                    CImGui.SameLine()
                    CImGui.PushID("add new plot")
                    if CImGui.Button(MORESTYLE.Icons.NewFile)
                        push!(DAQPLOTLAYOUT.labels, string(length(DAQPLOTLAYOUT.labels) + 1))
                        push!(DAQPLOTLAYOUT.marks, "")
                        push!(DAQPLOTLAYOUT.states, false)
                        push!(UIPSWEEPS, UIPlot())
                        push!(DAQDTPKS, DataPicker())
                    end
                    CImGui.PopID()

                    ### edit show plots ###
                    DAQPLOTLAYOUT.showcol = CONF.DAQ.plotshowcol
                    DAQPLOTLAYOUT.labels = MORESTYLE.Icons.Plot * " " .* string.(collect(eachindex(DAQPLOTLAYOUT.labels)))
                    maxplotmarkidx = argmax(lengthpr.(DAQPLOTLAYOUT.marks))
                    maxploticonwidth = DAQPLOTLAYOUT.showcol * CImGui.CalcTextSize(
                        stcstr(
                            MORESTYLE.Icons.Plot,
                            " ",
                            DAQPLOTLAYOUT.labels[maxplotmarkidx],
                            DAQPLOTLAYOUT.marks[maxplotmarkidx]
                        )
                    ).x
                    edit(
                        DAQPLOTLAYOUT,
                        (
                            maxploticonwidth,
                            CImGui.GetFrameHeight() * ceil(Int, length(DAQPLOTLAYOUT.labels) / DAQPLOTLAYOUT.showcol)
                        )
                    ) do
                        openright = CImGui.BeginPopupContextItem()
                        if openright
                            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Select Data")))
                                if DAQPLOTLAYOUT.states[DAQPLOTLAYOUT.idxing]
                                    show_daq_dtpickers[DAQPLOTLAYOUT.idxing] = true
                                end
                            end
                            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")))
                                isdelplot = true
                                delplot_i = DAQPLOTLAYOUT.idxing
                            end
                            markbuf = DAQPLOTLAYOUT.marks[DAQPLOTLAYOUT.idxing]
                            CImGui.PushItemWidth(6CImGui.GetFontSize())
                            @c InputTextRSZ(DAQPLOTLAYOUT.labels[DAQPLOTLAYOUT.idxing], &markbuf)
                            CImGui.PopItemWidth()
                            DAQPLOTLAYOUT.marks[DAQPLOTLAYOUT.idxing] = markbuf
                            CImGui.EndPopup()
                        end
                        return openright
                    end
                    CImGui.EndMenu()
                end
                CImGui.EndPopup()
            end
            isdelall && (CImGui.OpenPopup("##delete all disable tasks");
            isdelall = false)
            if YesNoDialog(
                "##delete all disable tasks",
                mlstr("Confirm delete?"),
                CImGui.ImGuiWindowFlags_AlwaysAutoResize
            )
                deleteat!(daqtasks, findall(task -> !task.enable, daqtasks))
                deleteat!(show_daq_editors, findall(task -> !task.enable, daqtasks))
            end

            ### show daq datapickers ###
            for (i, isshow_dtpk) in enumerate(show_daq_dtpickers)
                if isshow_dtpk
                    daq_dtpk = DAQDTPKS[i]
                    datakeys::Set{String} = keys(DATABUF)
                    if datakeys != Set(daq_dtpk.datalist)
                        daq_dtpk.datalist = collect(datakeys)
                        daq_dtpk.y = falses(length(datakeys))
                        daq_dtpk.w = falses(length(datakeys))
                    end
                    isupdate = @c edit(daq_dtpk, stcstr("DAQ", i), &isshow_dtpk)
                    show_daq_dtpickers[i] = isshow_dtpk
                    if !isshow_dtpk || isupdate
                        syncplotdata(UIPSWEEPS[i], daq_dtpk, DATABUF, DATABUFPARSED)
                    end
                end
            end

            isdelplot && ((CImGui.OpenPopup(stcstr("##delete plot", DAQPLOTLAYOUT.idxing)));
            isdelplot = false)
            if YesNoDialog(
                stcstr("##delete plot", DAQPLOTLAYOUT.idxing),
                mlstr("Confirm delete?"),
                CImGui.ImGuiWindowFlags_AlwaysAutoResize
            )
                if length(UIPSWEEPS) > 1
                    deleteat!(DAQPLOTLAYOUT, delplot_i)
                    deleteat!(UIPSWEEPS, delplot_i)
                    deleteat!(DAQDTPKS, delplot_i)
                    deleteat!(show_daq_dtpickers, delplot_i)
                end
            end

            CImGui.IsAnyItemHovered() || CImGui.OpenPopupOnItemClick("add task")
            CImGui.PushStyleColor(
                CImGui.ImGuiCol_Button,
                if isrunall
                    MORESTYLE.Colors.DAQTaskRunning
                else
                    CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
                end
            )
            if CImGui.Button(stcstr(MORESTYLE.Icons.RunTask, " ", mlstr("Run All")))
                if !SYNCSTATES[Int(IsDAQTaskRunning)]
                    if ispath(WORKPATH)
                        runalltask = @async begin
                            isrunall = true
                            for (i, task) in enumerate(daqtasks)
                                running_i = i
                                run(task)
                                SYNCSTATES[Int(IsInterrupted)] && (SYNCSTATES[Int(IsInterrupted)] = false; break)
                            end
                            isrunall = false
                        end
                        errormonitor(runalltask)
                        show_daq_dtpickers .= false
                    else
                        WORKPATH = mlstr("no workplace selected!!!")
                    end
                end
            end
            CImGui.PopStyleColor()

            CImGui.SameLine(CImGui.GetColumnOffset(1) - bottombtsz - unsafe_load(IMGUISTYLE.WindowPadding.x))
            if SYNCSTATES[Int(IsBlocked)]
                if CImGui.Button(stcstr(MORESTYLE.Icons.RunTask, " ", mlstr("Continue")))
                    SYNCSTATES[Int(IsBlocked)] = false
                    remote_do(workers()[1]) do
                        lock(() -> notify(BLOCK), BLOCK)
                    end
                end
            else
                if CImGui.Button(stcstr(MORESTYLE.Icons.BlockTask, " ", mlstr("Pause")))
                    SYNCSTATES[Int(IsDAQTaskRunning)] && (SYNCSTATES[Int(IsBlocked)] = true)
                end
            end
            bottombtsz = CImGui.GetItemRectSize().x
            CImGui.SameLine()
            if CImGui.Button(stcstr(MORESTYLE.Icons.InterruptTask, " ", mlstr("Interrupt")))
                if SYNCSTATES[Int(IsDAQTaskRunning)]
                    SYNCSTATES[Int(IsInterrupted)] = true
                    if SYNCSTATES[Int(IsBlocked)]
                        SYNCSTATES[Int(IsBlocked)] = false
                        remote_do(workers()[1]) do
                            lock(() -> notify(BLOCK), BLOCK)
                        end
                    end
                end
            end
            bottombtsz += CImGui.GetItemRectSize().x

            for i in DAQPLOTLAYOUT.selectedidx
                if DAQDTPKS[i].isrealtime && waittime(stcstr("DAQ", i), DAQDTPKS[i].refreshrate)
                    syncplotdata(UIPSWEEPS[i], DAQDTPKS[i], DATABUF, DATABUFPARSED)
                end
            end

            CImGui.NextColumn()

            CImGui.BeginChild("plotlayout")
            if isempty(DAQPLOTLAYOUT.selectedidx)
                Plot(UIPSWEEPS[1], stcstr("sweeping realtime plot", 1))
            else
                l = length(DAQPLOTLAYOUT.selectedidx)
                n = CONF.DAQ.plotshowcol
                m = ceil(Int, l / n)
                n = m == 1 ? l : n
                height = (CImGui.GetContentRegionAvail().y - (m - 1) * unsafe_load(IMGUISTYLE.ItemSpacing.y)) / m
                CImGui.Columns(n)
                for i in 1:m
                    for j in 1:n
                        idx = (i - 1) * n + j
                        if idx <= l
                            index = DAQPLOTLAYOUT.selectedidx[idx]
                            Plot(UIPSWEEPS[index], stcstr("sweeping realtime plot", index), (Cfloat(0), height))
                            CImGui.NextColumn()
                        end
                    end
                end
            end

            CImGui.EndChild()
            CImGui.NextColumn()
        end
        CImGui.End()
    end
end #let

function find_old_i(dir)
    global OLDI
    if isdir(dir)
        for file in readdir(dir) # 任务顺序根据文件夹内容确定
            if isfile(joinpath(dir, file))
                m = match(Regex("$(mlstr("Task")) ([0-9]+)"), file)
                if !isnothing(m)
                    new_i = tryparse(Int, m[1])
                    isnothing(new_i) || (OLDI = new_i > OLDI ? new_i : OLDI)
                end
            end
        end
    else
        OLDI = 0
    end
    nothing
end