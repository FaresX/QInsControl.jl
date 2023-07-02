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
    global circuit_editor::NodeEditor = NodeEditor()
    global uipsweeps::Vector{UIPlot} = [UIPlot()] #绘图缓存
    global daq_dtpks::Vector{DataPicker} = [DataPicker()] #绘图数据选择
    global daq_plot_layout::Layout = Layout("DAQ Plot Layout", 3, 1, ["1"], [""], falses(1), [], Dict(), [])
    isdelplot::Bool = false
    delplot_i::Int = 0
    # layout
    ccbtsz::Cfloat = 0
    bottombtsz::Cfloat = 0

    global function DAQ(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin(stcstr(morestyle.Icons.InstrumentsDAQ, "  数据采集"), p_open)
            global workpath
            global savepath
            global old_i
            CImGui.Button(stcstr(morestyle.Icons.SelectPath, " 工作区 ")) && (workpath = pick_folder())
            CImGui.SameLine()
            CImGui.TextColored(
                if workpath == "未选择工作区！！！"
                    morestyle.Colors.LogError
                else
                    CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
                end,
                workpath
            )
            if workpath != oldworkpath
                if isdir(workpath)
                    oldworkpath = workpath
                    date = today()
                    find_old_i(
                        joinpath(workpath, string(year(date)), string(year(date), "-", month(date)), string(date))
                    )
                else
                    old_i = 0
                end
            end
            CImGui.Separator()
            CImGui.Columns(2)
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            column1pos = CImGui.GetColumnOffset(1)
            CImGui.BeginChild("队列", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))
            CImGui.BulletText("任务队列")
            CImGui.SameLine(column1pos - ccbtsz - unsafe_load(imguistyle.WindowPadding.x) - 3)
            CImGui.Button(stcstr(morestyle.Icons.Circuit, "##电路")) && (show_circuit_editor ⊻= true)
            show_circuit_editor && @c edit(circuit_editor, "Circuit Editor", &show_circuit_editor)
            ccbtsz = CImGui.GetItemRectSize().x

            length(show_daq_editors) == length(daqtasks) || resize!(show_daq_editors, length(daqtasks))
            length(show_daq_dtpickers) == length(daq_dtpks) || resize!(show_daq_dtpickers, length(daq_dtpks))
            for (i, task) in enumerate(daqtasks)
                task.enable || showdisabled || continue
                CImGui.PushID(i)
                isrunning_i = SyncStates[Int(isdaqtask_running)] && i == running_i
                CImGui.PushStyleColor(
                    CImGui.ImGuiCol_Button,
                    if task.enable
                        if isrunning_i
                            morestyle.Colors.DAQTaskRunning
                        else
                            CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Button)
                        end
                    else
                        morestyle.Colors.LogError
                    end
                )
                CImGui.PushStyleColor(
                    CImGui.ImGuiCol_ButtonHovered,
                    if task.enable
                        if isrunning_i
                            morestyle.Colors.DAQTaskRunning
                        else
                            CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_ButtonHovered)
                        end
                    else
                        morestyle.Colors.LogError
                    end
                )
                if CImGui.Button(
                    stcstr(morestyle.Icons.TaskButton, " 任务 ", i + old_i, " ", task.name, "###rename"),
                    (-1, 0)
                )
                    show_daq_editors[i] = true
                end
                CImGui.PopStyleColor(2)

                CImGui.OpenPopupOnItemClick(stcstr("队列编辑菜单", i))
                isrunning_i && ShowProgressBar()
                if !SyncStates[Int(isdaqtask_running)]
                    CImGui.Indent()
                    if CImGui.BeginDragDropSource(0)
                        @c CImGui.SetDragDropPayload("Swap DAQTask", &i, sizeof(Cint))
                        CImGui.Text(stcstr("任务 ", i + old_i, " ", task.name))
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
                        morestyle.Icons.RunTask * " 运行",
                        C_NULL,
                        false,
                        !SyncStates[Int(isdaqtask_running)] && task.enable
                    )
                        if ispath(workpath)
                            running_i = i
                            errormonitor(@async begin
                                run(task)
                                SyncStates[Int(isinterrupt)] && (SyncStates[Int(isinterrupt)] = false)
                            end)
                            show_daq_dtpickers .= false
                        else
                            workpath = "未选择工作区！！！"
                        end
                    end
                    CImGui.Separator()
                    CImGui.MenuItem(morestyle.Icons.Edit * " 编辑") && (show_daq_editors[i] = true)
                    CImGui.MenuItem(morestyle.Icons.Copy * " 复制") && (insert!(daqtasks, i + 1, deepcopy(task)))
                    if CImGui.MenuItem(morestyle.Icons.SaveButton * " 保存")
                        confsvpath = save_file(filterlist="cfg")
                        isempty(confsvpath) || jldsave(confsvpath; daqtask=task)
                    end
                    if CImGui.MenuItem(morestyle.Icons.Load * " 加载")
                        confldpath = pick_file(filterlist="cfg,qdt")
                        if isfile(confldpath)
                            loadcfg = @trypass load(confldpath, "daqtask") (@error "不支持的文件！！！" filepath = confldpath)
                            daqtasks[i] = isnothing(loadcfg) ? task : loadcfg
                        end
                    end
                    CImGui.Separator()
                    CImGui.MenuItem(morestyle.Icons.Rename * " 重命名") && (isrename = true)
                    if task.enable
                        CImGui.MenuItem(morestyle.Icons.Disable * " 停用") && (task.enable = false)
                    else
                        CImGui.MenuItem(morestyle.Icons.Restore * " 恢复") && (task.enable = true)
                        CImGui.MenuItem(morestyle.Icons.CloseFile * " 删除") && (isdeldaqtask = true)
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
                    @c InputTextRSZ(stcstr(morestyle.Icons.TaskButton, " 任务 ", i + old_i), &task.name)
                    CImGui.EndPopup()
                end
                CImGui.PopID()
            end
            CImGui.EndChild()

            if CImGui.BeginPopup("添加队列")
                CImGui.MenuItem(morestyle.Icons.NewFile * " 添加") && push!(daqtasks, DAQTask())
                if CImGui.MenuItem(morestyle.Icons.Load * " 加载")
                    confldpath = pick_file(filterlist="cfg")
                    if isfile(confldpath)
                        newdaqtask = @trypasse load(confldpath, "daqtask") (@error "不支持的文件！！！" filepath = confldpath)
                        isnothing(newdaqtask) || push!(daqtasks, newdaqtask)
                    end
                end
                CImGui.Separator()
                if showdisabled
                    CImGui.MenuItem(morestyle.Icons.NotShowDisable * " 隐藏不可用") && (showdisabled = false)
                    CImGui.MenuItem(morestyle.Icons.CloseFile * " 删除不可用") && (isdelall = true)
                else
                    CImGui.MenuItem(morestyle.Icons.ShowDisable * " 显示不可用") && (showdisabled = true)
                end
                if CImGui.MenuItem(morestyle.Icons.SaveButton * " 保存项目")
                    daqsvpath = save_file(filterlist="daq")
                    if daqsvpath != ""
                        jldsave(daqsvpath;
                            daqtasks=daqtasks,
                            circuit_editor=circuit_editor,
                            uipsweeps=uipsweeps,
                            daq_dtpks=daq_dtpks,
                            daq_plot_layout=daq_plot_layout
                        )
                    end
                end
                if CImGui.MenuItem(morestyle.Icons.Load * " 加载项目")
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
                            haskey(loaddaqproj, "circuit_editor") && (circuit_editor = loaddaqproj["circuit_editor"])
                            if haskey(loaddaqproj, "uipsweeps")
                                empty!(uipsweeps)
                                for uip in loaddaqproj["uipsweeps"]
                                    push!(uipsweeps, uip)
                                end
                            end
                            if haskey(loaddaqproj, "daq_dtpks")
                                empty!(daq_dtpks)
                                for dtpk in loaddaqproj["daq_dtpks"]
                                    push!(daq_dtpks, dtpk)
                                end
                            end
                            haskey(loaddaqproj, "daq_plot_layout") && (daq_plot_layout = loaddaqproj["daq_plot_layout"])
                        end
                    end
                end
                CImGui.Separator()
                if CImGui.BeginMenu(morestyle.Icons.SelectData * " 绘图")
                    CImGui.Text("绘图列数")
                    CImGui.SameLine()
                    CImGui.PushItemWidth(2CImGui.GetFontSize())
                    @c CImGui.DragInt(
                        "##绘图列数",
                        &conf.DAQ.plotshowcol,
                        1, 1, 6, "%d",
                        CImGui.ImGuiSliderFlags_AlwaysClamp
                    )
                    CImGui.PopItemWidth()
                    CImGui.SameLine()
                    CImGui.PushID("add new plot")
                    if CImGui.Button(morestyle.Icons.NewFile)
                        push!(daq_plot_layout.labels, string(length(daq_plot_layout.labels) + 1))
                        push!(daq_plot_layout.marks, "")
                        push!(daq_plot_layout.states, false)
                        push!(uipsweeps, UIPlot())
                        push!(daq_dtpks, DataPicker())
                    end
                    CImGui.PopID()

                    ### edit show plots ###
                    daq_plot_layout.showcol = conf.DAQ.plotshowcol
                    daq_plot_layout.labels = morestyle.Icons.SelectData * " " .* string.(collect(eachindex(daq_plot_layout.labels)))
                    maxplotmarkidx = argmax(lengthpr.(daq_plot_layout.marks))
                    maxploticonwidth = daq_plot_layout.showcol * CImGui.CalcTextSize(
                        stcstr(
                            morestyle.Icons.SelectData,
                            " ",
                            daq_plot_layout.labels[maxplotmarkidx],
                            daq_plot_layout.marks[maxplotmarkidx]
                        )
                    ).x
                    edit(
                        daq_plot_layout,
                        (
                            maxploticonwidth,
                            CImGui.GetFrameHeight() * ceil(Int, length(daq_plot_layout.labels) / daq_plot_layout.showcol)
                        )
                    ) do
                        openright = CImGui.BeginPopupContextItem()
                        if openright
                            if CImGui.MenuItem(morestyle.Icons.SelectData * " 选择数据")
                                if daq_plot_layout.states[daq_plot_layout.idxing]
                                    show_daq_dtpickers[daq_plot_layout.idxing] = true
                                end
                            end
                            if CImGui.MenuItem(morestyle.Icons.CloseFile * " 删除")
                                isdelplot = true
                                delplot_i = daq_plot_layout.idxing
                            end
                            markbuf = daq_plot_layout.marks[daq_plot_layout.idxing]
                            CImGui.PushItemWidth(6CImGui.GetFontSize())
                            @c InputTextRSZ(daq_plot_layout.labels[daq_plot_layout.idxing], &markbuf)
                            CImGui.PopItemWidth()
                            daq_plot_layout.marks[daq_plot_layout.idxing] = markbuf
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
                    daq_dtpk = daq_dtpks[i]
                    datakeys::Set{String} = keys(databuf)
                    if datakeys != Set(daq_dtpk.datalist)
                        daq_dtpk.datalist = collect(datakeys)
                        daq_dtpk.y = falses(length(datakeys))
                        daq_dtpk.w = falses(length(datakeys))
                    end
                    isupdate = @c edit(daq_dtpk, stcstr("DAQ", i), &isshow_dtpk)
                    show_daq_dtpickers[i] = isshow_dtpk
                    if !isshow_dtpk || isupdate
                        syncplotdata(uipsweeps[i], daq_dtpk, databuf, databuf_parsed)
                    end
                end
            end

            isdelplot && ((CImGui.OpenPopup(stcstr("##删除绘图", daq_plot_layout.idxing)));
            isdelplot = false)
            if YesNoDialog(
                stcstr("##删除绘图", daq_plot_layout.idxing),
                "确认删除？",
                CImGui.ImGuiWindowFlags_AlwaysAutoResize
            )
                if length(uipsweeps) > 1
                    deleteat!(daq_plot_layout, delplot_i)
                    deleteat!(uipsweeps, delplot_i)
                    deleteat!(daq_dtpks, delplot_i)
                    deleteat!(show_daq_dtpickers, delplot_i)
                end
            end

            CImGui.IsAnyItemHovered() || CImGui.OpenPopupOnItemClick("添加队列")
            CImGui.PushStyleColor(
                CImGui.ImGuiCol_Button,
                if isrunall
                    morestyle.Colors.DAQTaskRunning
                else
                    CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Button)
                end
            )
            if CImGui.Button(stcstr(morestyle.Icons.RunTask, " 全部运行"))
                if !SyncStates[Int(isdaqtask_running)]
                    if ispath(workpath)
                        runalltask = @async begin
                            isrunall = true
                            for (i, task) in enumerate(daqtasks)
                                running_i = i
                                run(task)
                                SyncStates[Int(isinterrupt)] && (SyncStates[Int(isinterrupt)] = false; break)
                            end
                            isrunall = false
                        end
                        errormonitor(runalltask)
                        show_daq_dtpickers .= false
                    else
                        workpath = "未选择工作区！！！"
                    end
                end
            end
            CImGui.PopStyleColor()

            CImGui.SameLine(CImGui.GetColumnOffset(1) - bottombtsz - unsafe_load(imguistyle.WindowPadding.x))
            if SyncStates[Int(isblock)]
                if CImGui.Button(stcstr(morestyle.Icons.RunTask, " 继续"))
                    SyncStates[Int(isblock)] = false
                    remote_do(workers()[1]) do
                        lock(() -> notify(block), block)
                    end
                end
            else
                if CImGui.Button(stcstr(morestyle.Icons.BlockTask, " 暂停"))
                    SyncStates[Int(isdaqtask_running)] && (SyncStates[Int(isblock)] = true)
                end
            end
            bottombtsz = CImGui.GetItemRectSize().x
            CImGui.SameLine()
            if CImGui.Button(stcstr(morestyle.Icons.InterruptTask, " 中断"))
                if SyncStates[Int(isdaqtask_running)]
                    SyncStates[Int(isinterrupt)] = true
                    if SyncStates[Int(isblock)]
                        SyncStates[Int(isblock)] = false
                        remote_do(workers()[1]) do
                            lock(() -> notify(block), block)
                        end
                    end
                end
            end
            bottombtsz += CImGui.GetItemRectSize().x

            for i in daq_plot_layout.selectedidx
                if daq_dtpks[i].isrealtime && waittime(stcstr("DAQ", i), daq_dtpks[i].refreshrate)
                    syncplotdata(uipsweeps[i], daq_dtpks[i], databuf, databuf_parsed)
                end
            end

            CImGui.NextColumn()

            CImGui.BeginChild("绘图")
            if isempty(daq_plot_layout.selectedidx)
                Plot(uipsweeps[1], stcstr("扫描实时绘图", 1))
            else
                l = length(daq_plot_layout.selectedidx)
                n = conf.DAQ.plotshowcol
                m = ceil(Int, l / n)
                n = m == 1 ? l : n
                height = (CImGui.GetContentRegionAvail().y - (m - 1) * unsafe_load(imguistyle.ItemSpacing.y)) / m
                CImGui.Columns(n)
                for i in 1:m
                    for j in 1:n
                        idx = (i - 1) * n + j
                        if idx <= l
                            index = daq_plot_layout.selectedidx[idx]
                            Plot(uipsweeps[index], stcstr("扫描实时绘图", index), (Cfloat(0), height))
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
    global old_i
    if isdir(dir)
        for file in readdir(dir) # 任务顺序根据文件夹内容确定
            if isfile(joinpath(dir, file))
                m = match(r"任务 ([0-9]+)", file)
                if !isnothing(m)
                    new_i = tryparse(Int, m[1])
                    isnothing(new_i) || (old_i = new_i > old_i ? new_i : old_i)
                end
            end
        end
    else
        old_i = 0
    end
    nothing
end

function ShowProgressBar()
    for pgb in values(progresslist)
        pgmark = string(pgb[2], "/", pgb[3], "(", tohms(pgb[4]), "/", tohms(pgb[3] * pgb[4] / pgb[2]), ")")
        if pgb[2] == pgb[3]
            delete!(progresslist, pgb[1])
        else
            CImGui.ProgressBar(pgb[2] / pgb[3], (-1, 0), pgmark)
        end
    end
end