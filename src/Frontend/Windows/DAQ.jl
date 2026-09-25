# DAQ 任务树：复用通用结构 Tree{DAQTask}（见 GenericUtilities/Tree.jl）
# 根节点 children 为顶层任务与一级分类，分类 children 全为任务叶子
# 任务的待运行/编辑器展开状态（torunstate/showeditor）随 DAQTask 存储

let
    show_circuit_editor::Bool = false
    show_editinstraliaslist::Bool = false
    isdeldaqtask::Bool = false
    isrename::Bool = false
    isrenamegroup::Bool = false
    isdelgroup::Bool = false
    oldworkpath::String = ""
    running_i::Int = 0
    daqtasks::Tree{DAQTask} = TreeGroup(DAQTask, "root") #任务树（根节点，children 为顶层任务与一级分类）
    hidenorunning::Bool = false
    global CIRCUIT::NodeEditor = NodeEditor()
    global DAQDATAPLOTS::Tree{DataPlot} = TreeGroup(DataPlot, "") #绘图树（根节点，children 为顶层绘图与一级分类）
    global taskroot() = daqtasks #任务树访问器（AI 子模块等外部组件的唯一入口，见 src/AI/Bridge.jl）

    projpath::String = ""

    global function closedaqwindows()
        for task in leafvalues(daqtasks)
            task.showeditor = false
        end
        show_circuit_editor = false
        for dtp in plotleaves(DAQDATAPLOTS)
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
        # 顶部品牌渐变条(AccentTop→AccentBottom 横向;主题置同色即关闭)
        tbpos = CImGui.GetWindowPos()
        gradientfill(
            CImGui.GetWindowDrawList(), tbpos, tbpos .+ (CImGui.GetWindowWidth(), 2CImGui.GetWindowDpiScale()),
            MORESTYLE.Colors.AccentTop, MORESTYLE.Colors.AccentBottom; dir=:h
        )
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

    #渲染单个任务节点（i 为树遍历顺序的平铺索引；gi 为分类索引，0 表示顶层；ti 为分类内索引）
    function renderdaqtask(node::Tree{DAQTask}, i::Int, gi::Int, ti::Int)
        task = node.value
        isrunning_i = SYNCSTATES[IsDAQTaskRunning] && i == running_i
        haskey(taskpos, i) || (taskpos[i] = [ImVec2(0, 0), ImVec2(0, 0)])
        if isrunning_i || task.torunstate
            CImGui.AddRectFilled(
                CImGui.GetWindowDrawList(), taskpos[i][1], taskpos[i][2],
                isrunning_i ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.DAQTaskToRun
            )
        end
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
        CImGui.Selectable(
            stcstr(MORESTYLE.Icons.TaskButton, " ", mlstr("Task"), " ", i + OLDI, " ", task.name, "###task", i),
            task.showeditor, 0, (Cfloat(0), CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y))
        ) && (task.showeditor ⊻= true)
        CImGui.PopStyleVar()
        taskpos[i][1] = CImGui.GetItemRectMin()
        taskpos[i][2] = CImGui.GetItemRectMax()
        CImGui.Spacing()


        CImGui.OpenPopupOnItemClick(stcstr("edit queue menu", i))
        CImGui.Indent()
        if !SYNCSTATES[IsDAQTaskRunning] && CImGui.BeginDragDropSource(0)
            dp = TreeDragPayload(Cint(gi), Cint(ti))
            @c CImGui.SetDragDropPayload("Move DAQTask", &dp, sizeof(TreeDragPayload))
            CImGui.Text(stcstr(mlstr("Task"), " ", i + OLDI, " ", task.name))
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Move DAQTask")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(TreeDragPayload)
                d = unsafe_load(Ptr{TreeDragPayload}(unsafe_load(payload).Data))
                #拖到任务上：进目标所在容器插到目标前（组内任务同样直接进组，与 block 编辑器一致）
                moveleaf!(daqtasks, Int(d.group), Int(d.index), gi, ti)
            end
            payload = CImGui.AcceptDragDropPayload("Move DAQGroup")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(TreeDragPayload)
                d = unsafe_load(Ptr{TreeDragPayload}(unsafe_load(payload).Data))
                #分类拖到叶子上：按平铺顺序插到目标之前（组内目标落到该分类之前）
                insertgrouporder!(daqtasks, Int(d.index), gi, ti)
            end
            CImGui.EndDragDropTarget()
        end
        CImGui.Unindent()
        isrunning_i && ShowProgressBar()

        if CImGui.BeginPopup(stcstr("edit queue menu", i))
            if CImGui.MenuItem(
                stcstr(MORESTYLE.Icons.RunTask, " ", mlstr(task.torunstate ? "Cancel" : "Run")),
                C_NULL,
                false,
                !isrunning_i && !STATES[AutoDetecting]
            )
                task.torunstate ⊻= true
                task.torunstate && (SYNCSTATES[IsDAQTaskRunning] || rundaqtasks())
            end
            CImGui.Separator()
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Edit, " ", mlstr("Edit Script"))) && (task.showeditor = true)
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy Script")))
                container = gi == 0 ? daqtasks : daqtasks.children[gi]
                newtask = deepcopy(task)
                newtask.torunstate = false #复制的任务不继承运行与编辑器状态
                newtask.showeditor = false
                insert!(container.children, ti + 1, Tree(newtask))
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
                        if !isnothing(loadcfg)
                            loadcfg.torunstate = task.torunstate #加载脚本不改变节点的运行与编辑器状态
                            loadcfg.showeditor = task.showeditor
                            node.value = loadcfg
                        end
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
        isshow_editor = task.showeditor
        isshow_editor && @c edit(task, i, &isshow_editor)
        task.showeditor = isshow_editor

        # 是否删除
        isdeldaqtask && (CImGui.OpenPopup(stcstr("##if delete daqtasks", i));
        isdeldaqtask = false)
        if YesNoDialog(
            stcstr("##if delete daqtasks", i),
            mlstr("Confirm delete?"),
            CImGui.ImGuiWindowFlags_AlwaysAutoResize
        )
            container = gi == 0 ? daqtasks : daqtasks.children[gi]
            deleteat!(container.children, ti)
            i < running_i && (running_i -= 1)
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

    #渲染一级分类节点，返回更新后的叶子索引
    function renderdaqgroup(group::Tree{DAQTask}, gi::Int, leaf_i::Int)
        #分类内有任务正在运行时文字使用运行色（运行与展开状态无关，折叠时同样生效）
        isrunning_g = SYNCSTATES[IsDAQTaskRunning] && running_i in (leaf_i+1):(leaf_i+length(group.children))
        isrunning_g && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.DAQTaskRunning)
        # group.open = CImGui.TreeNodeEx(
        #     stcstr(group.open ? ICONS.ICON_FOLDER_OPEN : ICONS.ICON_FOLDER, " ", group.name, "###daqtasks_group", gi),
        #     group.open ? CImGui.ImGuiTreeNodeFlags_DefaultOpen : Cint(0)
        # )
        CImGui.PushStyleColor(CImGui.ImGuiCol_Header, surfacestyle(2)[1])
        group.open = CImGui.CollapsingHeader(
            stcstr(group.open ? ICONS.ICON_FOLDER_OPEN : ICONS.ICON_FOLDER, " ", group.name, "###daqtasks_group", gi)
        )
        CImGui.PopStyleColor()
        isrunning_g && CImGui.PopStyleColor()
        #在 TreeNode ID 作用域内捕获右键点击，展开态下 OpenPopupOnItemClick 会因作用域不一致而失效
        isgroupmenu = CImGui.IsItemHovered() && CImGui.IsMouseClicked(1)
        if !SYNCSTATES[IsDAQTaskRunning] && CImGui.BeginDragDropSource(0)
            dp = TreeDragPayload(Cint(0), Cint(gi))
            @c CImGui.SetDragDropPayload("Move DAQGroup", &dp, sizeof(TreeDragPayload))
            CImGui.Text(group.name)
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Move DAQTask")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(TreeDragPayload)
                d = unsafe_load(Ptr{TreeDragPayload}(unsafe_load(payload).Data))
                #只有拖到组头上时 Ctrl 才进组（插到组尾）；无 Ctrl 插到该组之前的顶层位置，与 block 编辑器一致
                if unsafe_load(CImGui.GetIO().KeyCtrl)
                    moveleaf!(daqtasks, Int(d.group), Int(d.index), gi, length(group.children) + 1)
                else
                    insertleafbeforegroup!(daqtasks, Int(d.group), Int(d.index), gi)
                end
            end
            payload = CImGui.AcceptDragDropPayload("Move DAQGroup")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(TreeDragPayload)
                d = unsafe_load(Ptr{TreeDragPayload}(unsafe_load(payload).Data))
                movegroup!(daqtasks, Int(d.index), gi)
            end
            CImGui.EndDragDropTarget()
        end
        if group.open
            for (ti, tnode) in enumerate(group.children)
                leaf_i += 1
                hidenorunning && !tnode.value.torunstate && continue
                renderdaqtask(tnode, leaf_i, gi, ti)
            end
            # CImGui.TreePop()
            CImGui.SeparatorText("")
        else
            leaf_i += length(group.children)
        end
        # 分类右键菜单（与 BeginPopup 同处父级作用域）
        isgroupmenu && CImGui.OpenPopup(stcstr("daq group menu", gi))
        if CImGui.BeginPopup(stcstr("daq group menu", gi))
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Rename, " ", mlstr("Rename"))) && (isrenamegroup = true)
            CImGui.MenuItem(
                stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete")),
                C_NULL, false, !SYNCSTATES[IsDAQTaskRunning]
            ) && (isdelgroup = true)
            CImGui.EndPopup()
        end
        # 分类重命名
        isrenamegroup && (CImGui.OpenPopup(stcstr(mlstr("rename group"), gi));
        isrenamegroup = false)
        if CImGui.BeginPopup(stcstr(mlstr("rename group"), gi))
            @c InputTextRSZ(
                stcstr(ICONS.ICON_FOLDER, " ", mlstr("Group"), "###daqtasks_group", gi),
                &group.name
            )
            CImGui.EndPopup()
        end
        # 是否删除分类（分类内任务移回顶层）
        isdelgroup && (CImGui.OpenPopup(stcstr("##if delete daqgroup", gi));
        isdelgroup = false)
        if YesNoDialog(
            stcstr("##if delete daqgroup", gi),
            mlstr("Move tasks in group to top level?"),
            CImGui.ImGuiWindowFlags_AlwaysAutoResize
        )
            ungroup!(daqtasks, gi)
        end
        leaf_i
    end

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
            (halfwidth - 6ftsz - 3unsafe_load(IMGUISTYLE.ItemSpacing.x), bth)
        ) && push!(daqtasks.children, Tree(DAQTask()))
        CImGui.SameLine()
        CImGui.Button(stcstr(ICONS.ICON_FOLDER_PLUS, "##new daq group"), (2ftsz, bth)) &&
            push!(daqtasks.children, TreeGroup(DAQTask))
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
            (halfwidth - 4ftsz - 2unsafe_load(IMGUISTYLE.ItemSpacing.x), bth)
        ) && push!(DAQDATAPLOTS.children, Tree(DataPlot()))
        CImGui.SameLine()
        CImGui.Button(stcstr(ICONS.ICON_FOLDER_PLUS, "##new daq plot group"), (2ftsz, bth)) &&
            push!(DAQDATAPLOTS.children, TreeGroup(DataPlot))
        CImGui.SameLine()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.Update, "##update showing plots"), (2ftsz, bth)
        ) && update!(plotleaves(DAQDATAPLOTS), DATABUF, DATABUFPARSED)
        CImGui.PopStyleColor()
        # 任务面板 = 一级卡片上的子卡片(level 2):PanelBg/PanelBorder + 阴影,与外层卡片分离
        CardChild("scrobartask", (halfwidth, Cfloat(0)); level=2)
        # CardChild("daqtasks", (0, 0); level = 2, shadow = false)
        #树形遍历渲染：顶层任务与一级分类
        leaf_i = 0
        firstitem = true
        for (ci, child) in enumerate(daqtasks.children)
            isgroup = child.isgroup
            ishidden = !isgroup && hidenorunning && !child.value.torunstate
            if firstitem && !ishidden
                ccpos = CImGui.GetCursorScreenPos()
                CImGui.SetCursorScreenPos(ccpos.x, ccpos.y + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2)
                firstitem = false
            end
            if isgroup
                leaf_i = renderdaqgroup(child, ci, leaf_i)
            else
                leaf_i += 1
                ishidden || renderdaqtask(child, leaf_i, 0, ci)
            end
        end
        EndCard()
        # EndCard()

        CImGui.SameLine()

        CardChild("scrobarplot", (halfwidth, Cfloat(0)); level=2)
        edit(DAQDATAPLOTS, DATABUF, DATABUFPARSED)
        EndCard()

        CImGui.EndChild()

        if CImGui.BeginPopup("add task")
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Task"))) && push!(daqtasks.children, Tree(DAQTask()))
            CImGui.MenuItem(stcstr(ICONS.ICON_FOLDER_PLUS, " ", mlstr("New Task Group"))) && push!(daqtasks.children, TreeGroup(DAQTask))
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Plot"))) && push!(DAQDATAPLOTS.children, Tree(DataPlot()))
            CImGui.MenuItem(stcstr(ICONS.ICON_FOLDER_PLUS, " ", mlstr("New Plot Group"))) && push!(DAQDATAPLOTS.children, TreeGroup(DataPlot))
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste Plot"))) && pasteplot!(DAQDATAPLOTS)
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, " ", mlstr("Load Script")))
                begin
                    confldpath = pick_file(filterlist="cfg,qdt")
                    if isfile(confldpath)
                        newdaqtask = @trypasse load(confldpath, "daqtask") begin
                            @error "[$(now())]\n$(mlstr("unsupported file!!!"))" filepath = confldpath
                        end
                        if !isnothing(newdaqtask)
                            newdaqtask.torunstate = false #导入的任务不继承运行与编辑器状态
                            newdaqtask.showeditor = false
                            push!(daqtasks.children, Tree(newdaqtask))
                        end
                    end
                end
            end
            CImGui.Separator()
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Project")))
                saveproject()
                empty!(daqtasks.children)
                running_i = 0
                CIRCUIT = NodeEditor()
                empty!(DAQDATAPLOTS.children)
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
        showdtpks(plotleaves(DAQDATAPLOTS), "DAQ", DATABUF, DATABUFPARSED)
        for dtp in plotleaves(DAQDATAPLOTS)
            dtp.showplot || continue
            syncplotdata(dtp.plot, dtp.dtpk, DATABUF, DATABUFPARSED)
        end
        renderplots(plotleaves(DAQDATAPLOTS), "DAQ")
    end

    global function rundaqtasks()
        if !SYNCSTATES[IsDAQTaskRunning]
            global WORKPATH
            if ispath(WORKPATH)
                saveproject(projpath)
                @async_record "run daq tasks" @toastcatch mlstr("running daq tasks failed!!!") begin
                    for (i, task) in enumerate(leafvalues(daqtasks))
                        task.torunstate || continue
                        running_i = i
                        println("running task $(i): $(task.name)")
                        saferun(task)
                        task.torunstate = false
                        saveproject(projpath)
                        SYNCSTATES[IsInterrupted] && (SYNCSTATES[IsInterrupted] = false; break)
                    end
                end
                for dtp in plotleaves(DAQDATAPLOTS)
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
                toast(:error, mlstr("unsupported file!!!"), daqloadpath)
            end
            if !isnothing(loaddaqproj)
                projpath = daqloadpath
                if haskey(loaddaqproj, "daqtasks")
                    empty!(daqtasks.children)
                    running_i = 0
                    loadedtasks = loaddaqproj["daqtasks"]
                    if loadedtasks isa Tree{DAQTask}
                        append!(daqtasks.children, loadedtasks.children) #新版树形工程
                    elseif loadedtasks isa DAQTaskNode
                        append!(daqtasks.children, Tree{DAQTask}.(loadedtasks.children)) #旧版树形工程自动迁移
                    else
                        append!(daqtasks.children, Tree{DAQTask}.(loadedtasks)) #旧版平铺工程自动迁移
                    end
                end
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
                if haskey(loaddaqproj, "DAQDATAPLOTS")
                    empty!(DAQDATAPLOTS.children)
                    loadedplots = loaddaqproj["DAQDATAPLOTS"]
                    if loadedplots isa Tree{DataPlot}
                        append!(DAQDATAPLOTS.children, loadedplots.children) #新版树形工程
                    elseif loadedplots isa DAQPlotNode
                        append!(DAQDATAPLOTS.children, Tree{DataPlot}.(loadedplots.children)) #旧版树形工程自动迁移
                    else
                        append!(DAQDATAPLOTS.children, Tree{DataPlot}.(loadedplots)) #旧版平铺工程自动迁移
                    end
                end
            end
        end
    end
end #let