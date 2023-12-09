let
    firsttime::Bool = true
    show_daq_editors::Vector{Bool} = [false]
    show_circuit_editor::Bool = false
    isdeldaqtask::Bool = false
    isrename::Bool = false
    showdisabled::Bool = false
    isdelall::Bool = false
    oldworkpath::String = ""
    running_i::Int = 0
    torunstates::Vector{Bool} = [false]
    daqtasks::Vector{DAQTask} = [DAQTask()] #任务列表
    global CIRCUIT::NodeEditor = NodeEditor()
    global DAQDATAPLOT::DataPlot = DataPlot()
    # layout
    ccbtsz::Cfloat = 0
    bottombtsz::Cfloat = 0

    projpath::String = ""

    global function DAQ(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin(stcstr(MORESTYLE.Icons.InstrumentsDAQ, "  ", mlstr("Data Acquiring"), "###DAQ"), p_open)
            SetWindowBgImage()
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
            if !CONF.DAQ.freelayout
                CImGui.Columns(2)
                firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            end
            CONF.DAQ.freelayout || (column1pos = CImGui.GetColumnOffset(1))
            CImGui.BeginChild("queue")
            # CImGui.BulletText(mlstr("Task Queue"))
            if CImGui.CollapsingHeader(mlstr("Task Queue"))
                ftsz = CImGui.GetFontSize()
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, 60)
                if SYNCSTATES[Int(IsBlocked)]
                    if ColoredButton(
                        stcstr(MORESTYLE.Icons.RunTask, "##", mlstr("Continue"));
                        size=(2ftsz, 2ftsz), colbt=MORESTYLE.Colors.LogWarn
                    )
                        SYNCSTATES[Int(IsBlocked)] = false
                        remote_do(workers()[1]) do
                            lock(() -> notify(BLOCK), BLOCK)
                        end
                    end
                else
                    if ColoredButton(
                        stcstr(MORESTYLE.Icons.BlockTask, "##", mlstr("Pause"));
                        size=(2ftsz, 2ftsz), colbt=MORESTYLE.Colors.LogInfo
                    )
                        SYNCSTATES[Int(IsDAQTaskRunning)] && (SYNCSTATES[Int(IsBlocked)] = true)
                    end
                end
                CImGui.SameLine()
                if ColoredButton(
                    stcstr(MORESTYLE.Icons.InterruptTask, "##", mlstr("Interrupt"));
                    size=(2ftsz, 2ftsz), colbt=MORESTYLE.Colors.LogInfo
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
                CImGui.SameLine(
                    if CONF.DAQ.freelayout
                        CImGui.GetContentRegionAvailWidth() - ccbtsz - 3
                    else
                        column1pos - ccbtsz - unsafe_load(IMGUISTYLE.WindowPadding.x) - 3
                    end
                )
                CImGui.Button(
                    stcstr(MORESTYLE.Icons.Circuit, "##circuit"),
                    (2ftsz, 2ftsz)
                ) && (show_circuit_editor ⊻= true)
                CImGui.PopStyleVar()
                CImGui.Spacing()
                show_circuit_editor && @c edit(CIRCUIT, "Circuit Editor", &show_circuit_editor)
                ccbtsz = CImGui.GetItemRectSize().x

                length(show_daq_editors) == length(daqtasks) || resize!(show_daq_editors, length(daqtasks))
                length(torunstates) == length(daqtasks) || resize!(torunstates, length(daqtasks))
                for (i, task) in enumerate(daqtasks)
                    task.enable || showdisabled || continue
                    CImGui.PushID(i)
                    isrunning_i = SYNCSTATES[Int(IsDAQTaskRunning)] && i == running_i
                    CImGui.PushStyleColor(
                        CImGui.ImGuiCol_Button,
                        if task.enable
                            if isrunning_i
                                MORESTYLE.Colors.DAQTaskRunning
                            elseif torunstates[i]
                                MORESTYLE.Colors.DAQTaskToRun
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
                            task.enable && !isrunning_i
                            # !SYNCSTATES[Int(IsDAQTaskRunning)] && task.enable
                        )
                            torunstates[i] ⊻= true
                            torunstates[i] && (SYNCSTATES[Int(IsDAQTaskRunning)] || rundaqtasks())
                            # if ispath(WORKPATH)
                            #     saveproject(projpath)
                            #     running_i = i
                            #     errormonitor(@async begin
                            #         run(task)
                            #         SYNCSTATES[Int(IsInterrupted)] && (SYNCSTATES[Int(IsInterrupted)] = false)
                            #     end)
                            #     DAQDATAPLOT.showdtpks .= false
                            # else
                            #     WORKPATH = mlstr("no workplace selected!!!")
                            # end
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
                        if task.enable
                            CImGui.MenuItem(
                                stcstr(MORESTYLE.Icons.Disable, " ", mlstr("Disable")),
                                C_NULL,
                                false,
                                !isrunning_i
                            ) && (task.enable = false)
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
            end
            CONF.DAQ.showeditplotlayout && CImGui.CollapsingHeader(mlstr("Plot")) && editmenu(DAQDATAPLOT)
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
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save Project"))) && saveproject()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load Project"))) && loadproject()
                if !CONF.DAQ.showeditplotlayout
                    CImGui.Separator()
                    if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot")))
                        editmenu(DAQDATAPLOT)
                        CImGui.EndMenu()
                    end
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
                deleteidxes = findall(task -> !task.enable, daqtasks)
                deleteat!(daqtasks, deleteidxes)
                deleteat!(torunstates, deleteidxes)
                deleteat!(show_daq_editors, deleteidxes)
            end

            ### show daq datapickers ###
            showdtpks(DAQDATAPLOT, "DAQ", DATABUF, DATABUFPARSED)

            CImGui.IsAnyItemHovered() || CImGui.OpenPopupOnItemClick("add task")

            CONF.DAQ.freelayout || CImGui.NextColumn()
        end
        CImGui.End()
        if p_open[]
            for i in DAQDATAPLOT.layout.selectedidx
                if DAQDATAPLOT.dtpks[i].isrealtime && waittime(stcstr("DAQ", i), DAQDATAPLOT.dtpks[i].refreshrate)
                    if DAQDATAPLOT.linkidx[i] == 0
                        syncplotdata(DAQDATAPLOT.uiplots[i], DAQDATAPLOT.dtpks[i], DATABUF, DATABUFPARSED)
                    else
                        uip = DAQDATAPLOT.uiplots[DAQDATAPLOT.linkidx[i]]
                        dtpklink = DAQDATAPLOT.dtpks[DAQDATAPLOT.linkidx[i]]
                        linkeddata = Dict(
                            "x" => uip.x,
                            Dict("y$yi" => uip.y[yi] for yi in 1:length(uip.y))...,
                            "z" => copy(uip.z)
                        )
                        dtpklink.hflipz && reverse!(linkeddata["z"], dims=1)
                        dtpklink.vflipz && reverse!(linkeddata["z"], dims=2)
                        linkeddata["z"] = collect(transpose(linkeddata["z"]))
                        syncplotdata(DAQDATAPLOT.uiplots[i], DAQDATAPLOT.dtpks[i], Dict(), linkeddata)
                    end
                end
            end
            renderplots(DAQDATAPLOT, "DAQ")
        end
    end

    function rundaqtasks()
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

    function saveproject(daqsvpath="")
        daqsvpath == "" && (daqsvpath = save_file(filterlist="daq"))
        if daqsvpath != ""
            projpath = daqsvpath
            jldsave(daqsvpath;
                daqtasks=daqtasks,
                circuit=CIRCUIT,
                dataplot=DAQDATAPLOT
            )
        end
    end

    function loadproject()
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

