let
    firsttime::Bool = true
    show_daq_editors::Vector{Bool} = [false]
    show_circuit_editor::Bool = false
    isdeldaqtask::Bool = false
    isrename::Bool = false
    oldworkpath::String = ""
    running_i::Int = 0
    torunstates::Vector{Bool} = [false]
    daqtasks::Vector{DAQTask} = [DAQTask()] #任务列表
    global CIRCUIT::NodeEditor = NodeEditor()
    global DAQDATAPLOT::DataPlot = DataPlot()

    projpath::String = ""

    global function DAQ(p_open::Ref)
        CImGui.SetNextWindowSize((48CImGui.GetFontSize(), 31CImGui.GetFontSize()), CImGui.ImGuiCond_Once)
        if CImGui.Begin(stcstr(MORESTYLE.Icons.InstrumentsDAQ, "  ", mlstr("Data Acquiring"), "###DAQ"), p_open)
            SetWindowBgImage()
            global WORKPATH
            global OLDI
            CImGui.Columns(2, C_NULL, false)
            ftsz = CImGui.GetFontSize()
            CImGui.SetColumnOffset(1, 16ftsz)
            CImGui.Text(" \n ")
            CImGui.Text("")
            CImGui.SameLine(5ftsz)
            CImGui.Image(Ptr{Cvoid}(ICONID), (6ftsz, 6ftsz))
            CImGui.Text(" \n ")
            CImGui.PushFont(PLOTFONT)
            btwidth = 8ftsz - unsafe_load(IMGUISTYLE.ItemSpacing.x) - unsafe_load(IMGUISTYLE.WindowPadding.x) / 2
            if SYNCSTATES[Int(IsBlocked)]
                if ColoredButton(
                    stcstr(MORESTYLE.Icons.RunTask, "##", mlstr("Continue"));
                    size=(btwidth, 6ftsz), colbt=MORESTYLE.Colors.ControlButtonPause
                )
                    SYNCSTATES[Int(IsBlocked)] = false
                    remote_do(workers()[1]) do
                        lock(() -> notify(BLOCK), BLOCK)
                    end
                end
            else
                if ColoredButton(
                    stcstr(MORESTYLE.Icons.BlockTask, "##", mlstr("Pause"));
                    size=(btwidth, 6ftsz), colbt=MORESTYLE.Colors.ControlButton
                )
                    SYNCSTATES[Int(IsDAQTaskRunning)] && (SYNCSTATES[Int(IsBlocked)] = true)
                end
            end
            CImGui.SameLine()
            if ColoredButton(
                stcstr(MORESTYLE.Icons.InterruptTask, "##", mlstr("Interrupt"));
                size=(btwidth, 6ftsz), colbt=MORESTYLE.Colors.ControlButton
            )
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
            CImGui.Button(
                stcstr(MORESTYLE.Icons.Circuit, "##circuit"),
                (btwidth, 6ftsz)
            ) && (show_circuit_editor ⊻= true)
            CImGui.SameLine()
            CImGui.Button(stcstr(MORESTYLE.Icons.Load, "##Load Project"), (btwidth, 6ftsz)) && loadproject()
            CImGui.Button(
                stcstr(MORESTYLE.Icons.SaveButton, "##Save Project"),
                (2btwidth + unsafe_load(IMGUISTYLE.ItemSpacing.x), 6ftsz)
            ) && saveproject()
            CImGui.PopFont()
            show_circuit_editor && @c edit(CIRCUIT, "Circuit Editor", &show_circuit_editor)

            CImGui.NextColumn()
            CImGui.BeginChild("queue")
            if ColoredButtonRect(
                stcstr(MORESTYLE.Icons.SelectPath, " ", mlstr("Workplace"));
                size=(Cfloat(-1), 2ftsz),
                colbt=zeros(4),
                coltxt=MORESTYLE.Colors.HighlightText
            )
                WORKPATH = pick_folder()
            end
            CImGui.Spacing()
            TextRect(
                WORKPATH;
                coltxt=if WORKPATH == mlstr("no workplace selected!!!")
                    MORESTYLE.Colors.LogError
                else
                    CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
                end
            )
            if WORKPATH != oldworkpath
                if isdir(WORKPATH)
                    oldworkpath = WORKPATH
                    date = today()
                    find_old_i(joinpath(WORKPATH, string(year(date)), string(year(date), "-", month(date)), string(date)))
                else
                    OLDI = 0
                end
            end
            igSeparatorText("")
            halfwidth = (CImGui.GetContentRegionAvailWidth() - unsafe_load(IMGUISTYLE.ItemSpacing.x)) / 2
            CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Task")), (halfwidth, 2ftsz)) && push!(daqtasks, DAQTask())
            CImGui.SameLine()
            if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Plot")), (halfwidth, 2CImGui.GetFontSize()))
                newplot!(DAQDATAPLOT)
            end
            length(show_daq_editors) == length(daqtasks) || resize!(show_daq_editors, length(daqtasks))
            length(torunstates) == length(daqtasks) || resize!(torunstates, length(daqtasks))
            daqtaskscdy = (length(daqtasks) + SYNCSTATES[Int(IsDAQTaskRunning)] * length(PROGRESSLIST)) *
                          CImGui.GetFrameHeightWithSpacing() - unsafe_load(IMGUISTYLE.ItemSpacing.y) +
                          2unsafe_load(IMGUISTYLE.WindowPadding.y)

            CImGui.BeginChild("scrobartask", (halfwidth, Cfloat(0)))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
            CImGui.BeginChild("daqtasks", (halfwidth, daqtaskscdy), true)
            for (i, task) in enumerate(daqtasks)
                CImGui.PushID(i)
                isrunning_i = SYNCSTATES[Int(IsDAQTaskRunning)] && i == running_i
                CImGui.PushStyleColor(
                    CImGui.ImGuiCol_Button,
                    if isrunning_i
                        MORESTYLE.Colors.DAQTaskRunning
                    elseif torunstates[i]
                        MORESTYLE.Colors.DAQTaskToRun
                    else
                        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
                    end
                )
                CImGui.PushStyleColor(
                    CImGui.ImGuiCol_ButtonHovered,
                    if isrunning_i
                        MORESTYLE.Colors.DAQTaskRunning
                    else
                        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
                    end
                )
                if CImGui.Button(
                    stcstr(MORESTYLE.Icons.TaskButton, " ", mlstr("Task"), " ", i + OLDI, " ", task.name, "###task", i),
                    (-1, 0)
                )
                    show_daq_editors[i] = true
                end
                CImGui.PopStyleColor(2)

                CImGui.OpenPopupOnItemClick(stcstr("edit queue menu", i))
                isrunning_i && ShowProgressBar()
                # if !SYNCSTATES[Int(IsDAQTaskRunning)]
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
                            insert!(torunstates, i, torunstates[payload_i])
                            deleteat!(daqtasks, payload_i < i ? payload_i : payload_i + 1)
                            deleteat!(torunstates, payload_i < i ? payload_i : payload_i + 1)
                            if running_i == payload_i
                                running_i = i
                                isrunning_i = SYNCSTATES[Int(IsDAQTaskRunning)] && i == running_i
                            elseif payload_i < running_i < i
                                running_i -= 1
                                isrunning_i = SYNCSTATES[Int(IsDAQTaskRunning)] && i == running_i
                            elseif payload_i > running_i >= i
                                running_i += 1
                                isrunning_i = SYNCSTATES[Int(IsDAQTaskRunning)] && i == running_i
                            end
                        end
                    end
                    CImGui.EndDragDropTarget()
                end
                CImGui.Unindent()
                # end

                if CImGui.BeginPopup(stcstr("edit queue menu", i))
                    if CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.RunTask, " ", mlstr(torunstates[i] ? "Cancel" : "Run")),
                        C_NULL,
                        false,
                        !isrunning_i
                    )
                        torunstates[i] ⊻= true
                        torunstates[i] && (SYNCSTATES[Int(IsDAQTaskRunning)] || rundaqtasks())
                    end
                    CImGui.Separator()
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Edit, " ", mlstr("Edit"))) && (show_daq_editors[i] = true)
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy")))
                        insert!(daqtasks, i + 1, deepcopy(task))
                        insert!(torunstates, i + 1, false)
                        insert!(show_daq_editors, i + 1, false)
                        i < running_i && (running_i += 1)
                    end
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
                    CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")),
                        C_NULL, false, !isrunning_i
                    ) && (isdeldaqtask = true)
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
                    deleteat!(torunstates, i)
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
            CImGui.PopStyleVar()
            CImGui.PopStyleColor()
            CImGui.EndChild()

            CImGui.SameLine()
            # plotscdy = length(DAQDATAPLOT.plots) * CImGui.GetFrameHeightWithSpacing() -
            #            unsafe_load(IMGUISTYLE.ItemSpacing.y) + 2unsafe_load(IMGUISTYLE.WindowPadding.y)
            CImGui.BeginChild("scrobarplot", (halfwidth, Cfloat(0)))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
            editmenu(DAQDATAPLOT)
            CImGui.PopStyleVar()
            CImGui.PopStyleColor()
            CImGui.EndChild()

            CImGui.EndChild()

            if CImGui.BeginPopup("add task")
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Task"))) && push!(daqtasks, DAQTask())
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Plot"))) && newplot!(DAQDATAPLOT)
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
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save Project"))) && saveproject()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load Project"))) && loadproject()
                CImGui.EndPopup()
            end
            if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
                CImGui.IsMouseClicked(1) && CImGui.OpenPopup("add task")
            end
            ### show daq datapickers ###
            showdtpks(DAQDATAPLOT, "DAQ", DATABUF, DATABUFPARSED)
        end
        CImGui.End()
        if p_open[]
            for i in DAQDATAPLOT.layout.selectedidx
                if DAQDATAPLOT.linkidx[i] == 0
                    syncplotdata(DAQDATAPLOT.plots[i], DAQDATAPLOT.dtpks[i], DATABUF, DATABUFPARSED)
                else
                    if true in [
                        dtss.isrealtime && waittime(stcstr("DAQ", i, "-", j), dtss.refreshrate)
                        for (j, dtss) in enumerate(DAQDATAPLOT.dtpks[i].series)
                    ]
                        pltlink = DAQDATAPLOT.plots[DAQDATAPLOT.linkidx[i]]
                        dtpklink = DAQDATAPLOT.dtpks[DAQDATAPLOT.linkidx[i]]
                        linkeddata = Dict{String,VecOrMat{Cdouble}}()
                        for (j, pss) in enumerate(pltlink.series)
                            push!(linkeddata, "x$j" => pss.x)
                            push!(linkeddata, "y$j" => pss.y)
                            push!(linkeddata, "z$j" => pss.z)
                            dtpklink.series[j].hflipz && reverse!(linkeddata["z$j"], dims=1)
                            dtpklink.series[j].vflipz && reverse!(linkeddata["z$j"], dims=2)
                            linkeddata["z$j"] = transpose(linkeddata["z$j"]) |> collect
                        end
                        syncplotdata(DAQDATAPLOT.plots[i], DAQDATAPLOT.dtpks[i], Dict{String,Vector{String}}(), linkeddata)
                    end
                end
            end
            renderplots(DAQDATAPLOT, "DAQ")
        end
    end

    global function rundaqtasks()
        if !SYNCSTATES[Int(IsDAQTaskRunning)]
            global WORKPATH
            if ispath(WORKPATH)
                saveproject(projpath)
                runalltask = @async begin
                    for (i, task) in enumerate(daqtasks)
                        torunstates[i] || continue
                        running_i = i
                        run(task)
                        torunstates[running_i] = false
                        SYNCSTATES[Int(IsInterrupted)] && (SYNCSTATES[Int(IsInterrupted)] = false; break)
                    end
                end
                errormonitor(runalltask)
                DAQDATAPLOT.showdtpks .= false
            else
                WORKPATH = mlstr("no workplace selected!!!")
            end
        end
    end

    global function saveproject(daqsvpath="")
        daqsvpath == "" && (daqsvpath = save_file(filterlist="daq"))
        if daqsvpath != ""
            projpath = daqsvpath
            jldsave(daqsvpath;
                daqtasks=daqtasks,
                circuit=CIRCUIT,
                dataplot=empty!(deepcopy(DAQDATAPLOT))
            )
        end
    end

    global function loadproject()
        daqloadpath = pick_file(filterlist="daq;qdt")
        if isfile(daqloadpath)
            loaddaqproj = @trypasse load(daqloadpath) begin
                @error mlstr("unsupported file!!!") filepath = daqloadpath
            end
            if !isnothing(loaddaqproj)
                projpath = daqloadpath
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
                haskey(loaddaqproj, "dataplot") && (DAQDATAPLOT = loaddaqproj["dataplot"])
            end
        end
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
                    isnothing(new_i) || (OLDI = max(new_i, OLDI))
                end
            end
        end
    else
        OLDI = 0
    end
end

