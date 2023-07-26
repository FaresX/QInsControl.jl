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
        if CImGui.Begin(stcstr(MORESTYLE.Icons.InstrumentsDAQ, "  数据采集"), p_open)
            global WORKPATH
            global OLDI
            CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, " 工作区 ")) && (WORKPATH = pick_folder())
            CImGui.SameLine()
            CImGui.TextColored(
                if WORKPATH == "未选择工作区！！！"
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
            CImGui.BeginChild("队列", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))
            CImGui.BulletText("任务队列")
            CImGui.SameLine(column1pos - ccbtsz - unsafe_load(IMGUISTYLE.WindowPadding.x) - 3)
            CImGui.Button(stcstr(MORESTYLE.Icons.Circuit, "##电路")) && (show_circuit_editor ⊻= true)
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
                    stcstr(MORESTYLE.Icons.TaskButton, " 任务 ", i + OLDI, " ", task.name, "###rename"),
                    (-1, 0)
                )
                    show_daq_editors[i] = true
                end
                CImGui.PopStyleColor(2)

                CImGui.OpenPopupOnItemClick(stcstr("队列编辑菜单", i))
                isrunning_i && ShowProgressBar()
                if !SYNCSTATES[Int(IsDAQTaskRunning)]
                    CImGui.Indent()
                    if CImGui.BeginDragDropSource(0)
                        @c CImGui.SetDragDropPayload("Swap DAQTask", &i, sizeof(Cint))
                        CImGui.Text(stcstr("任务 ", i + OLDI, " ", task.name))
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

                if CImGui.BeginPopup(stcstr("队列编辑菜单", i))
                    if CImGui.MenuItem(
                        MORESTYLE.Icons.RunTask * " 运行",
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
                            WORKPATH = "未选择工作区！！！"
                        end
                    end
                    CImGui.Separator()
                    CImGui.MenuItem(MORESTYLE.Icons.Edit * " 编辑") && (show_daq_editors[i] = true)
                    CImGui.MenuItem(MORESTYLE.Icons.Copy * " 复制") && (insert!(daqtasks, i + 1, deepcopy(task)))
                    if CImGui.MenuItem(MORESTYLE.Icons.SaveButton * " 保存")
                        confsvpath = save_file(filterlist="cfg")
                        isempty(confsvpath) || jldsave(confsvpath; daqtask=task)
                    end
                    if CImGui.MenuItem(MORESTYLE.Icons.Load * " 加载")
                        confldpath = pick_file(filterlist="cfg,qdt")
                        if isfile(confldpath)
                            loadcfg = @trypass load(confldpath, "daqtask") (@error "不支持的文件！！！" filepath = confldpath)
                            daqtasks[i] = isnothing(loadcfg) ? task : loadcfg
                        end
                    end
                    CImGui.Separator()
                    CImGui.MenuItem(MORESTYLE.Icons.Rename * " 重命名") && (isrename = true)
                    if task.enable
                        CImGui.MenuItem(MORESTYLE.Icons.Disable * " 停用") && (task.enable = false)
                    else
                        CImGui.MenuItem(MORESTYLE.Icons.Restore * " 恢复") && (task.enable = true)
                        CImGui.MenuItem(MORESTYLE.Icons.CloseFile * " 删除") && (isdeldaqtask = true)
                    end
                    CImGui.EndPopup()
                end

                ### show daq editors ###
                isshow_editor = show_daq_editors[i]
                isshow_editor && @c edit(task, i, &isshow_editor)
                show_daq_editors[i] = isshow_editor

                # 是否删除
                isdeldaqtask && (CImGui.OpenPopup(stcstr("##是否删除daqtasks", i));
                isdeldaqtask = false)
                if YesNoDialog(stcstr("##是否删除daqtasks", i), "确认删除？", CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                    deleteat!(daqtasks, i)
                    deleteat!(show_daq_editors, i)
                end

                # 重命名
                isrename && (CImGui.OpenPopup(stcstr("重命名", i));
                isrename = false)
                if CImGui.BeginPopup(stcstr("重命名", i))
                    @c InputTextRSZ(stcstr(MORESTYLE.Icons.TaskButton, " 任务 ", i + OLDI), &task.name)
                    CImGui.EndPopup()
                end
                CImGui.PopID()
            end
            CImGui.EndChild()

            if CImGui.BeginPopup("添加队列")
                CImGui.MenuItem(MORESTYLE.Icons.NewFile * " 添加") && push!(daqtasks, DAQTask())
                if CImGui.MenuItem(MORESTYLE.Icons.Load * " 加载")
                    confldpath = pick_file(filterlist="cfg")
                    if isfile(confldpath)
                        newdaqtask = @trypasse load(confldpath, "daqtask") (@error "不支持的文件！！！" filepath = confldpath)
                        isnothing(newdaqtask) || push!(daqtasks, newdaqtask)
                    end
                end
                CImGui.Separator()
                if showdisabled
                    CImGui.MenuItem(MORESTYLE.Icons.NotShowDisable * " 隐藏不可用") && (showdisabled = false)
                    CImGui.MenuItem(MORESTYLE.Icons.CloseFile * " 删除不可用") && (isdelall = true)
                else
                    CImGui.MenuItem(MORESTYLE.Icons.ShowDisable * " 显示不可用") && (showdisabled = true)
                end
                if CImGui.MenuItem(MORESTYLE.Icons.SaveButton * " 保存项目")
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
                if CImGui.MenuItem(MORESTYLE.Icons.Load * " 加载项目")
                    daqloadpath = pick_file(filterlist="daq")
                    if isfile(daqloadpath)
                        loaddaqproj = @trypasse load(daqloadpath) (@error "不支持的文件！！！" filepath = daqloadpath)
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
                                            @error "[$(now())]\n加载图像出错！！！" exception = e
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
                if CImGui.BeginMenu(MORESTYLE.Icons.SelectData * " 绘图")
                    CImGui.Text("绘图列数")
                    CImGui.SameLine()
                    CImGui.PushItemWidth(2CImGui.GetFontSize())
                    @c CImGui.DragInt(
                        "##绘图列数",
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
                    DAQPLOTLAYOUT.labels = MORESTYLE.Icons.SelectData * " " .* string.(collect(eachindex(DAQPLOTLAYOUT.labels)))
                    maxplotmarkidx = argmax(lengthpr.(DAQPLOTLAYOUT.marks))
                    maxploticonwidth = DAQPLOTLAYOUT.showcol * CImGui.CalcTextSize(
                        stcstr(
                            MORESTYLE.Icons.SelectData,
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
                            if CImGui.MenuItem(MORESTYLE.Icons.SelectData * " 选择数据")
                                if DAQPLOTLAYOUT.states[DAQPLOTLAYOUT.idxing]
                                    show_daq_dtpickers[DAQPLOTLAYOUT.idxing] = true
                                end
                            end
                            if CImGui.MenuItem(MORESTYLE.Icons.CloseFile * " 删除")
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
            isdelall && (CImGui.OpenPopup("##删除所有不可用task");
            isdelall = false)
            if YesNoDialog("##删除所有不可用task", "确认删除？", CImGui.ImGuiWindowFlags_AlwaysAutoResize)
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

            isdelplot && ((CImGui.OpenPopup(stcstr("##删除绘图", DAQPLOTLAYOUT.idxing)));
            isdelplot = false)
            if YesNoDialog(
                stcstr("##删除绘图", DAQPLOTLAYOUT.idxing),
                "确认删除？",
                CImGui.ImGuiWindowFlags_AlwaysAutoResize
            )
                if length(UIPSWEEPS) > 1
                    deleteat!(DAQPLOTLAYOUT, delplot_i)
                    deleteat!(UIPSWEEPS, delplot_i)
                    deleteat!(DAQDTPKS, delplot_i)
                    deleteat!(show_daq_dtpickers, delplot_i)
                end
            end

            CImGui.IsAnyItemHovered() || CImGui.OpenPopupOnItemClick("添加队列")
            CImGui.PushStyleColor(
                CImGui.ImGuiCol_Button,
                if isrunall
                    MORESTYLE.Colors.DAQTaskRunning
                else
                    CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
                end
            )
            if CImGui.Button(stcstr(MORESTYLE.Icons.RunTask, " 全部运行"))
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
                        WORKPATH = "未选择工作区！！！"
                    end
                end
            end
            CImGui.PopStyleColor()

            CImGui.SameLine(CImGui.GetColumnOffset(1) - bottombtsz - unsafe_load(IMGUISTYLE.WindowPadding.x))
            if SYNCSTATES[Int(IsBlocked)]
                if CImGui.Button(stcstr(MORESTYLE.Icons.RunTask, " 继续"))
                    SYNCSTATES[Int(IsBlocked)] = false
                    remote_do(workers()[1]) do
                        lock(() -> notify(BLOCK), BLOCK)
                    end
                end
            else
                if CImGui.Button(stcstr(MORESTYLE.Icons.BlockTask, " 暂停"))
                    SYNCSTATES[Int(IsDAQTaskRunning)] && (SYNCSTATES[Int(IsBlocked)] = true)
                end
            end
            bottombtsz = CImGui.GetItemRectSize().x
            CImGui.SameLine()
            if CImGui.Button(stcstr(MORESTYLE.Icons.InterruptTask, " 中断"))
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

            CImGui.BeginChild("绘图")
            if isempty(DAQPLOTLAYOUT.selectedidx)
                Plot(UIPSWEEPS[1], stcstr("扫描实时绘图", 1))
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
                            Plot(UIPSWEEPS[index], stcstr("扫描实时绘图", index), (Cfloat(0), height))
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
                m = match(r"任务 ([0-9]+)", file)
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