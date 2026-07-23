let
    show_daq_editors::Vector{Bool} = [false]
    show_circuit_editor::Bool = false
    show_editinstraliaslist::Bool = false
    isdeldaqtask::Bool = false
    isrename::Bool = false
    oldworkpath::String = ""
    running_i::Int = 0
    torunstates::Vector{Bool} = [false]
    daqtasks::Vector{DAQTask} = [DAQTask()] #任务列表
    hidenorunning::Bool = false
    global CIRCUIT::NodeEditor = NodeEditor()
    global DAQDATAPLOTS::Vector{DataPlot} = [DataPlot()]

    projpath::String = ""

    global function closedaqwindows()
        show_daq_editors .= false
        show_circuit_editor = false
        for dtp in DAQDATAPLOTS
            dtp.showplot = false
            dtp.showdtpk = false
        end
    end

    global function DAQtoolbar()
        # CImGui.Columns(2, C_NULL, false)
        # CImGui.SetColumnOffset(1, 6ftsz)
        CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, MORESTYLE.Colors.ToolBarBg)
        CImGui.PushFont(C_NULL, MORESTYLE.Variables.BigIconSize)
        ftsz = CImGui.GetFontSize()
        CImGui.BeginChild("Toolbar", (3ftsz, Cfloat(0)))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)

        CImGui.SetCursorPos(ftsz / 2, ftsz / 2)
        CImGui.Image(ICONID, (2ftsz, 2ftsz))
        CImGui.SetCursorPosY(CImGui.GetCursorPosY() + ftsz / 2)
        # btwidth = Cfloat(CImGui.GetContentRegionAvail().x - unsafe_load(IMGUISTYLE.WindowPadding.x))
        btwidth = CImGui.GetContentRegionAvail().x
        btheight = 2ftsz
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
        if SYNCSTATES[IsBlocked]
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ControlButtonPause)
            if CImGui.Button(stcstr(MORESTYLE.Icons.RunTask, "##Continue"), (btwidth, btheight))
                SYNCSTATES[IsBlocked] = false
                remote_continue()
            end
            CImGui.PopStyleColor()
        else
            if CImGui.Button(stcstr(MORESTYLE.Icons.BlockTask, "##Pause"), (btwidth, btheight))
                SYNCSTATES[IsDAQTaskRunning] && (SYNCSTATES[IsBlocked] = true)
            end
        end
        # CImGui.SameLine()
        if CImGui.Button(stcstr(MORESTYLE.Icons.InterruptTask, "##Interrupt"), (btwidth, btheight))
            SYNCSTATES[IsDAQTaskRunning] && CImGui.OpenPopup("##InterruptTask")
        end
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Text,
            STATES[AutoRefreshing] ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
        )
        if CImGui.Button(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, "##autorefresh"), (btwidth, btheight))
            STATES[AutoRefreshing] ⊻= true
        end
        CImGui.PopStyleColor()
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Button,
            CImGui.c_get(IMGUISTYLE.Colors, show_circuit_editor ? CImGui.ImGuiCol_ButtonActive : CImGui.ImGuiCol_Button)
        )
        CImGui.Button(
            stcstr(MORESTYLE.Icons.Circuit, "##circuit"),
            (btwidth, btheight)
        ) && (show_circuit_editor ⊻= true)
        CImGui.PopStyleColor()
        igBeginDisabled(SYNCSTATES[IsDAQTaskRunning])
        CImGui.Button(
            stcstr(MORESTYLE.Icons.Load, "##Load Project"), (btwidth, btheight)
        ) && loadproject(pick_file(filterlist="daq;qdt"))
        igEndDisabled()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.SaveButton, "##Save Project"),
            (btwidth, btheight)
        ) && saveproject()
        CImGui.PopStyleColor()
        CImGui.PopFont()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()

        if CImGui.BeginPopupModal("##InterruptTask", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            ftsz = CImGui.GetFontSize()
            CImGui.Text("\n")
            msg = mlstr("Save as invalid data?")
            CImGui.PushFont(C_NULL, 2unsafe_load(IMGUISTYLE.FontSizeBase))
            CImGui.SetCursorPosX(CImGui.GetCursorPosX() + (CImGui.GetContentRegionAvail().x - CImGui.CalcTextSize(msg).x) / 2)
            CImGui.TextColored(MORESTYLE.Colors.WarnText, msg)
            CImGui.PopFont()
            CImGui.Text("\n\n")
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, MORESTYLE.Colors.WarnBg)
            confirmy = CImGui.Button(mlstr("Yes"), (4ftsz, Cfloat(0)))
            CImGui.PopStyleColor()
            CImGui.SameLine()
            confirmn = CImGui.Button(mlstr("No"), (4ftsz, Cfloat(0)))
            confirmy && (STATES[InValidFile] = true)
            if confirmy || confirmn
                SYNCSTATES[IsInterrupted] = true
                if SYNCSTATES[IsBlocked]
                    SYNCSTATES[IsBlocked] = false
                    remote_continue()
                end
                CImGui.CloseCurrentPopup()
            end
            CImGui.SameLine(0, 4ftsz)
            CImGui.Button(mlstr("Cancel"), (4ftsz, Cfloat(0))) && CImGui.CloseCurrentPopup()
            CImGui.EndPopup()
        end

        CImGui.EndChild()
        CImGui.PopStyleColor()
        show_circuit_editor && @c edit(CIRCUIT, "Circuit Editor", &show_circuit_editor)
    end

    # CImGui.NextColumn()
    taskpos::Dict{Int,Vector{ImVec2}} = Dict()
    global function DAQtasks()
        global WORKPATH
        global OLDI
        ftsz = CImGui.GetFontSize()
        CImGui.BeginChild("queue")
        bth = 2 * MORESTYLE.Variables.BigIconSize * CImGui.GetWindowDpiScale() +
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
            size=(CImGui.GetContentRegionAvail().x, bth),
            coltxt=if WORKPATH == mlstr("no workplace selected!!!")
                MORESTYLE.Colors.ErrorText
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
            stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Task")),
            (halfwidth - 4ftsz - 2unsafe_load(IMGUISTYLE.ItemSpacing.x), bth)
        ) && push!(daqtasks, DAQTask())
        CImGui.SameLine()
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Button,
            CImGui.c_get(IMGUISTYLE.Colors, show_editinstraliaslist ? CImGui.ImGuiCol_ButtonActive : CImGui.ImGuiCol_Button)
        )
        CImGui.Button(
            stcstr(ICONS.ICON_LAYER_GROUP, "##configure the instruments"), (2ftsz, bth)
        ) && (show_editinstraliaslist ⊻= true)
        CImGui.PopStyleColor()
        CImGui.SameLine()
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Text,
            hidenorunning ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
        )
        CImGui.Button(
            stcstr(hidenorunning ? ICONS.ICON_EYE_SLASH : ICONS.ICON_EYE, "##hide no running tasks"), (2ftsz, bth)
        ) && (hidenorunning ⊻= true)
        CImGui.PopStyleColor()
        CImGui.SameLine()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Plot")),
            (halfwidth - 2ftsz - unsafe_load(IMGUISTYLE.ItemSpacing.x), bth)
        ) && push!(DAQDATAPLOTS, DataPlot())
        CImGui.SameLine()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.Update, "##update showing plots"), (2ftsz, bth)
        ) && lock(DATABUF) do DATABUF
            lock(DATABUFPARSED) do DATABUFPARSED
                update!(DAQDATAPLOTS, DATABUF, DATABUFPARSED)
            end
        end
        CImGui.PopStyleColor()
        length(show_daq_editors) == length(daqtasks) || resizebool!(show_daq_editors, length(daqtasks))
        length(torunstates) == length(daqtasks) || resizebool!(torunstates, length(daqtasks))
        daqtaskscdy = (length(daqtasks) + SYNCSTATES[IsDAQTaskRunning] * lock(length, PROGRESSLIST)) *
                      CImGui.GetFrameHeightWithSpacing() - unsafe_load(IMGUISTYLE.ItemSpacing.y) +
                      2unsafe_load(IMGUISTYLE.WindowPadding.y)

        CImGui.BeginChild("scrobartask", (halfwidth, Cfloat(0)))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
        # CImGui.BeginChild("daqtasks", (halfwidth, daqtaskscdy), true)
        CImGui.BeginChild("daqtasks", (0, 0), true)
        for (i, task) in enumerate(daqtasks)
            hidenorunning && !torunstates[i] && continue
            isrunning_i = SYNCSTATES[IsDAQTaskRunning] && i == running_i
            # CImGui.PushStyleColor(
            #     CImGui.ImGuiCol_Button,
            #     if isrunning_i
            #         MORESTYLE.Colors.DAQTaskRunning
            #     elseif torunstates[i]
            #         MORESTYLE.Colors.DAQTaskToRun
            #     else
            #         show_daq_editors[i] ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button) : (0, 0, 0, 0)
            #     end
            # )
            # CImGui.PushStyleColor(
            #     CImGui.ImGuiCol_ButtonHovered,
            #     if isrunning_i
            #         MORESTYLE.Colors.DAQTaskRunning
            #     else
            #         CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
            #     end
            # )
            # CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
            # if CImGui.Button(
            #     stcstr(MORESTYLE.Icons.TaskButton, " ", mlstr("Task"), " ", i + OLDI, " ", task.name, "###task", i),
            #     (-1, 0)
            # )
            #     show_daq_editors[i] ⊻= true
            # end
            # CImGui.PopStyleVar()
            # CImGui.PopStyleColor(2)
            haskey(taskpos, i) || (taskpos[i] = [ImVec2(0, 0), ImVec2(0, 0)])
            if isrunning_i || torunstates[i]
                CImGui.AddRectFilled(
                    CImGui.GetWindowDrawList(), taskpos[i][1], taskpos[i][2],
                    isrunning_i ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.DAQTaskToRun
                )
            end
            if i == 1
                ccpos = CImGui.GetCursorScreenPos()
                CImGui.SetCursorScreenPos(ccpos.x, ccpos.y + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2)
            end
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            CImGui.Selectable(
                stcstr(MORESTYLE.Icons.TaskButton, " ", mlstr("Task"), " ", i + OLDI, " ", task.name, "###task", i),
                show_daq_editors[i], 0, (Cfloat(0), CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y))
            ) && (show_daq_editors[i] ⊻= true)
            CImGui.PopStyleVar()
            taskpos[i][1] = CImGui.GetItemRectMin()
            taskpos[i][2] = CImGui.GetItemRectMax()
            CImGui.Spacing()


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
                            isrunning_i = SYNCSTATES[IsDAQTaskRunning] && i == running_i
                        elseif payload_i < running_i < i
                            running_i -= 1
                            isrunning_i = SYNCSTATES[IsDAQTaskRunning] && i == running_i
                        elseif payload_i > running_i >= i
                            running_i += 1
                            isrunning_i = SYNCSTATES[IsDAQTaskRunning] && i == running_i
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
                    !isrunning_i && !STATES[AutoDetecting]
                )
                    torunstates[i] ⊻= true
                    torunstates[i] && (SYNCSTATES[IsDAQTaskRunning] || rundaqtasks())
                end
                CImGui.Separator()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Edit, " ", mlstr("Edit Script"))) && (show_daq_editors[i] = true)
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy Script")))
                    insert!(daqtasks, i + 1, deepcopy(task))
                    insert!(torunstates, i + 1, false)
                    insert!(show_daq_editors, i + 1, false)
                    i < running_i && (running_i += 1)
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save Script")))
                    begin
                        confsvpath = save_file(filterlist="cfg")
                        isempty(confsvpath) || jldsave(confsvpath; daqtask=task)
                    end
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load Script")))
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
                    stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete")),
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
                @c InputTextRSZ(
                    stcstr(MORESTYLE.Icons.TaskButton, " ", mlstr("Task"), " ", i + OLDI, "###task", i + OLDI),
                    &task.name
                )
                CImGui.EndPopup()
            end
        end
        CImGui.EndChild()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        CImGui.EndChild()

        CImGui.SameLine()

        CImGui.BeginChild("scrobarplot", (halfwidth, Cfloat(0)))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
        lock(DATABUF) do DATABUF
            lock(DATABUFPARSED) do DATABUFPARSED
                edit(DAQDATAPLOTS, DATABUF, DATABUFPARSED)
            end
        end
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        CImGui.EndChild()

        CImGui.EndChild()

        if CImGui.BeginPopup("add task")
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Task"))) && push!(daqtasks, DAQTask())
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Plot"))) && push!(DAQDATAPLOTS, DataPlot())
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste Plot"))) && pasteplot!(DAQDATAPLOTS)
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load Script")))
                begin
                    confldpath = pick_file(filterlist="cfg,qdt")
                    if isfile(confldpath)
                        newdaqtask = @trypasse load(confldpath, "daqtask") begin
                            @error "[$(now())]\n$(mlstr("unsupported file!!!"))" filepath = confldpath
                        end
                        isnothing(newdaqtask) || push!(daqtasks, newdaqtask)
                    end
                end
            end
            CImGui.Separator()
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Project")))
                saveproject()
                empty!(daqtasks)
                empty!(show_daq_editors)
                empty!(torunstates)
                CIRCUIT = NodeEditor()
                DAQDATAPLOTS = [DataPlot()]
            end
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save Project"))) && saveproject()
            CImGui.MenuItem(
                stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load Project")), C_NULL, false, !SYNCSTATES[IsDAQTaskRunning]
            ) && loadproject(pick_file(filterlist="daq;qdt"))
            CImGui.EndPopup()
        end
        if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
            CImGui.IsMouseClicked(1) && CImGui.OpenPopup("add task")
        end
        show_editinstraliaslist && @c editinstraliaslist(&show_editinstraliaslist)
        ### show daq datapickers ###
        lock(DATABUF) do DATABUF
            lock(DATABUFPARSED) do DATABUFPARSED
                showdtpks(DAQDATAPLOTS, "DAQ", DATABUF, DATABUFPARSED)
                for dtp in DAQDATAPLOTS
                    dtp.showplot || continue
                    syncplotdata(dtp.plot, dtp.dtpk, DATABUF, DATABUFPARSED)
                end
            end
        end
        renderplots(DAQDATAPLOTS, "DAQ")
    end

    global function rundaqtasks()
        if !SYNCSTATES[IsDAQTaskRunning]
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
                        SYNCSTATES[IsInterrupted] && (SYNCSTATES[IsInterrupted] = false; break)
                    end
                end
                for dtp in DAQDATAPLOTS
                    dtp.showdtpk = false
                end
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
                    instraliaslist=deepcopy(INSTRALIASLIST),
                    DAQDATAPLOTS=deepcopy(DAQDATAPLOTS)
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
                                tex_ref = CImGui.create_image_texture(imgsize...)
                                node.imgr.id = tex_ref._TexID
                                CImGui.update_image_texture(tex_ref, img, imgsize...)
                            end
                        end
                    end
                end
                haskey(loaddaqproj, "instraliaslist") && (INSTRALIASLIST = loaddaqproj["instraliaslist"])
                haskey(loaddaqproj, "DAQDATAPLOTS") && (DAQDATAPLOTS = loaddaqproj["DAQDATAPLOTS"])
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