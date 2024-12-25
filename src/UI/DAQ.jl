let
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

    global function closedaqwindows()
        show_daq_editors .= false
        show_circuit_editor = false
        DAQDATAPLOT.showdtpks .= false
        DAQDATAPLOT.layout.states .= false
    end

    global function DAQtoolbar()
        # CImGui.Columns(2, C_NULL, false)
        # CImGui.SetColumnOffset(1, 6ftsz)
        CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, MORESTYLE.Colors.ToolBarBg)
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
        CImGui.PushFont(BIGFONT)
        ftsz = CImGui.GetFontSize()
        CImGui.BeginChild("Toolbar", (3ftsz, Cfloat(0)))
        CImGui.SetCursorPos(ftsz / 2, ftsz / 2)
        CImGui.Image(CImGui.ImTextureID(ICONID), (2ftsz, 2ftsz))
        CImGui.SetCursorPosY(CImGui.GetCursorPosY() + ftsz / 2)
        btwidth = Cfloat(CImGui.GetContentRegionAvail().x - unsafe_load(IMGUISTYLE.WindowPadding.x))
        btheight = 2ftsz
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
        if SYNCSTATES[Int(IsBlocked)]
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ControlButtonPause)
            if CImGui.Button(stcstr(MORESTYLE.Icons.RunTask, "##Continue"), (btwidth, btheight))
                SYNCSTATES[Int(IsBlocked)] = false
                remote_do(workers()[1]) do
                    lock(() -> notify(BLOCK), BLOCK)
                end
            end
            CImGui.PopStyleColor()
        else
            if CImGui.Button(stcstr(MORESTYLE.Icons.BlockTask, "##Pause"), (btwidth, btheight))
                SYNCSTATES[Int(IsDAQTaskRunning)] && (SYNCSTATES[Int(IsBlocked)] = true)
            end
        end
        # CImGui.SameLine()
        if CImGui.Button(stcstr(MORESTYLE.Icons.InterruptTask, "##Interrupt"), (btwidth, btheight))
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
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Text,
            SYNCSTATES[Int(IsAutoRefreshing)] ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
        )
        if CImGui.Button(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, "##autorefresh"), (btwidth, btheight))
            SYNCSTATES[Int(IsAutoRefreshing)] ⊻= true
        end
        CImGui.PopStyleColor()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.Circuit, "##circuit"),
            (btwidth, btheight)
        ) && (show_circuit_editor ⊻= true)
        igBeginDisabled(SYNCSTATES[Int(IsDAQTaskRunning)])
        CImGui.Button(
            stcstr(MORESTYLE.Icons.Load, "##Load Project"), (btwidth, btheight)
        ) && loadproject(pick_file(filterlist="daq;qdt"))
        igEndDisabled()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.SaveButton, "##Save Project"),
            (btwidth, btheight)
        ) && saveproject()
        CImGui.PopStyleColor()
        CImGui.EndChild()
        CImGui.PopFont()
        CImGui.PopStyleColor(2)
        show_circuit_editor && @c edit(CIRCUIT, "Circuit Editor", &show_circuit_editor)
    end

    # CImGui.NextColumn()
    global function DAQtasks()
        global WORKPATH
        global OLDI
        ftsz = CImGui.GetFontSize()
        CImGui.BeginChild("queue")
        bth = 2CONF.Fonts.plotfontsize * unsafe_load(CImGui.GetIO().FontGlobalScale) +
              4unsafe_load(IMGUISTYLE.FramePadding.y) - unsafe_load(IMGUISTYLE.ItemSpacing.y)
        if ColoredButtonRect(
            stcstr(MORESTYLE.Icons.SelectPath, " ", mlstr("Workplace"));
            size=(6ftsz, bth),
            colbt=zeros(4),
            coltxt=MORESTYLE.Colors.HighlightText,
            colrect=MORESTYLE.Colors.ItemBorder
        )
            WORKPATH = pick_folder()
        end
        CImGui.SameLine()
        TextRect(
            WORKPATH;
            size=(Cfloat(0), bth),
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
        halfwidth = (CImGui.GetContentRegionAvail().x - unsafe_load(IMGUISTYLE.ItemSpacing.x)) / 2
        bth = 2ftsz + unsafe_load(IMGUISTYLE.FramePadding.y)
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
        CImGui.Button(
            stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Task")), (halfwidth, bth)
        ) && push!(daqtasks, DAQTask())
        CImGui.SameLine()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Plot")),
            (halfwidth - 2ftsz - unsafe_load(IMGUISTYLE.ItemSpacing.x), bth)
        ) && newplot!(DAQDATAPLOT)
        CImGui.SameLine()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.Update, "##update showing plots"), (2ftsz, bth)
        ) && update!(DAQDATAPLOT, DATABUF, DATABUFPARSED)
        CImGui.PopStyleColor()
        length(show_daq_editors) == length(daqtasks) || resizebool!(show_daq_editors, length(daqtasks))
        length(torunstates) == length(daqtasks) || resizebool!(torunstates, length(daqtasks))
        daqtaskscdy = (length(daqtasks) + SYNCSTATES[Int(IsDAQTaskRunning)] * length(PROGRESSLIST)) *
                      CImGui.GetFrameHeightWithSpacing() - unsafe_load(IMGUISTYLE.ItemSpacing.y) +
                      2unsafe_load(IMGUISTYLE.WindowPadding.y)

        CImGui.BeginChild("scrobartask", (halfwidth, Cfloat(0)))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
        # CImGui.BeginChild("daqtasks", (halfwidth, daqtaskscdy), true)
        CImGui.BeginChild("daqtasks", (0, 0), true)
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
                            running_i = payload_i < i ? i - 1 : i
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
            isrunning_i && ShowProgressBar()

            if CImGui.BeginPopup(stcstr("edit queue menu", i))
                if CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.RunTask, " ", mlstr(torunstates[i] ? "Cancel" : "Run")),
                    C_NULL,
                    false,
                    !isrunning_i && !SYNCSTATES[Int(AutoDetecting)]
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
                    begin
                        confsvpath = save_file(filterlist="cfg")
                        isempty(confsvpath) || jldsave(confsvpath; daqtask=task)
                    end
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load")))
                    begin
                        confldpath = pick_file(filterlist="cfg,qdt")
                        if isfile(confldpath)
                            loadcfg = @trypass load(confldpath, "daqtask") begin
                                @error "[$(now())]\n$(mlstr("unsupported file!!!"))" filepath = confldpath
                            end
                            daqtasks[i] = isnothing(loadcfg) ? task : loadcfg
                        end
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
                begin
                    confldpath = pick_file(filterlist="cfg")
                    if isfile(confldpath)
                        newdaqtask = @trypasse load(confldpath, "daqtask") begin
                            @error "[$(now())]\n$(mlstr("unsupported file!!!"))" filepath = confldpath
                        end
                        isnothing(newdaqtask) || push!(daqtasks, newdaqtask)
                    end
                end
            end
            CImGui.Separator()
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save Project"))) && saveproject()
            CImGui.MenuItem(
                stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load Project")), C_NULL, false, !SYNCSTATES[Int(IsDAQTaskRunning)]
            ) && loadproject(pick_file(filterlist="daq;qdt"))
            CImGui.EndPopup()
        end
        if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
            CImGui.IsMouseClicked(1) && CImGui.OpenPopup("add task")
        end
        ### show daq datapickers ###
        showdtpks(DAQDATAPLOT, "DAQ", DATABUF, DATABUFPARSED)
        for i in DAQDATAPLOT.layout.selectedidx
            syncplotdata(DAQDATAPLOT.plots[i], DAQDATAPLOT.dtpks[i], DATABUF, DATABUFPARSED)
        end
        renderplots(DAQDATAPLOT, "DAQ")
    end

    global function rundaqtasks()
        if !SYNCSTATES[Int(IsDAQTaskRunning)]
            global WORKPATH
            if ispath(WORKPATH)
                saveproject(projpath)
                @async @trycatch mlstr("runing daq tasks failed!!!") begin
                    for (i, task) in enumerate(daqtasks)
                        torunstates[i] || continue
                        running_i = i
                        saferun(task)
                        torunstates[running_i] = false
                        saveproject(projpath)
                        SYNCSTATES[Int(IsInterrupted)] && (SYNCSTATES[Int(IsInterrupted)] = false; break)
                    end
                end
                DAQDATAPLOT.showdtpks .= false
            else
                WORKPATH = mlstr("no workplace selected!!!")
            end
        end
    end

    global function saveproject(daqsvpath="")
        begin
            daqsvpath == "" && (daqsvpath = save_file(filterlist="daq"))
            if daqsvpath != ""
                projpath = daqsvpath
                jldsave(daqsvpath;
                    daqtasks=daqtasks,
                    circuit=CIRCUIT,
                    dataplot=deepcopy(DAQDATAPLOT)
                )
            end
        end
    end

    global function loadproject(daqloadpath)
        if isfile(daqloadpath)
            loaddaqproj = @trypasse load(daqloadpath) begin
                @error "[$(now())]\n$(mlstr("unsupported file!!!"))" filepath = daqloadpath
            end
            if !isnothing(loaddaqproj)
                projpath = daqloadpath
                haskey(loaddaqproj, "daqtasks") && (empty!(daqtasks); append!(daqtasks, loaddaqproj["daqtasks"]))
                if haskey(loaddaqproj, "circuit")
                    CIRCUIT = loaddaqproj["circuit"]
                    for (_, node) in CIRCUIT.nodes
                        if node isa SampleHolderNode
                            @trycatch mlstr("loading image failed!!!") begin
                                img = RGBA.(jpeg_decode(node.imgr.image))
                                imgsize = size(img)
                                node.imgr.id = CImGui.create_image_texture(imgsize...)
                                CImGui.update_image_texture(node.imgr.id, img, imgsize...)
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