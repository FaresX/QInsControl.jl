@kwdef mutable struct DataPlot
    name::String = ""
    showplot::Bool = false
    plot::QPlot = QPlot()
    dtpk::DataPicker = DataPicker()
    showdtpk::Bool = false
end

#DAQ 绘图树：复用通用结构 Tree{DataPlot}（见 GenericUtilities/Tree.jl）
#根节点 children 为顶层绘图与一级分类，分类 children 全为 plot 叶子
plotleaves(root::Tree{DataPlot}) = leafvalues(root) #按树遍历顺序展开所有 plot

let
    copydataplot::DataPlot = DataPlot()
    pendingdels = Tuple{Int,Int}[] #树版待删 (gi,pi),遍历外统一应用
    global function edit(dtps::Vector{DataPlot}, datastr, datafloat=Dict())
        isdelplot = false
        delplot_i = 0
        isrename = false
        delpending = Int[]      #确认删除的索引,循环后统一删(遍历中 deleteat! 会跳过相邻元素)
        swappending = NTuple{2,Int}[] #拖拽交换 (i, payload_i),循环后统一应用
        CImGui.BeginChild("DataPlots", (0, 0), true)
        for (i, dtp) in enumerate(dtps)
            if i == 1
                ccpos = CImGui.GetCursorScreenPos()
                CImGui.SetCursorScreenPos(ccpos.x, ccpos.y + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2)
            end
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            @c CImGui.Selectable(
                stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i, " ", dtp.name, "###plot", i), &dtp.showplot, 0,
                (Cfloat(0), CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y))
            )
            CImGui.PopStyleVar()
            i == length(dtps) || CImGui.Spacing()
            CImGui.Indent()
            if CImGui.BeginDragDropSource(0)
                @c CImGui.SetDragDropPayload("Swap DataPlot", &i, sizeof(Cint))
                CImGui.Text(stcstr(mlstr("Plot"), " ", i, " ", dtp.name))
                CImGui.EndDragDropSource()
            end
            if CImGui.BeginDragDropTarget()
                payload = CImGui.AcceptDragDropPayload("Swap DataPlot")
                if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                    payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                    i != payload_i && push!(swappending, (i, payload_i))
                end
                CImGui.EndDragDropTarget()
            end
            CImGui.Unindent()
            if CImGui.BeginPopupContextItem()
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Select Data")))
                    dtp.showdtpk = true
                end
                CImGui.Separator()
                if dtp.showplot && CImGui.MenuItem(stcstr(MORESTYLE.Icons.Update, " ", mlstr("Update")))
                    dtp.dtpk.update = true
                    syncplotdata(dtp.plot, dtp.dtpk, datastr, datafloat)
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy")))
                    copydataplot = deepcopy(dtp)
                end
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste"))) && insert!(dtps, i, copydataplot)
                CImGui.Separator()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Rename, " ", mlstr("Rename"))) && (isrename = true)
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete")))
                    isdelplot = true
                    delplot_i = i
                end
                CImGui.EndPopup()
            end
            isdelplot && delplot_i == i && CImGui.OpenPopup(stcstr("##delete plot", i))
            if YesNoDialog(
                stcstr("##delete plot", i),
                mlstr("Confirm delete?"),
                CImGui.ImGuiWindowFlags_AlwaysAutoResize
            )
                length(dtps) > 1 && (rmplot!(dtp.plot); push!(delpending, i))
            end
            isrename && (CImGui.OpenPopup(stcstr("rename plot", i));
            isrename = false)
            if CImGui.BeginPopup(stcstr("rename plot", i))
                @c InputTextRSZ(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i, "###plot", i), &dtp.name)
                CImGui.EndPopup()
            end
        end
        isempty(delpending) || deleteat!(dtps, unique!(sort!(delpending)))
        for (i, payload_i) in swappending
            insert!(dtps, i, dtps[payload_i])
            deleteat!(dtps, payload_i < i ? payload_i : payload_i + 1)
        end
        CImGui.EndChild()
    end

    #渲染单个 plot 叶子节点（i 为树遍历顺序的平铺索引；gi 为分类索引，0 表示顶层；pi 为分类内索引）
    function renderplotnode(root::Tree{DataPlot}, node::Tree{DataPlot}, i::Int, gi::Int, pi::Int, datastr, datafloat=Dict())
        dtp = node.value
        isrename = false
        isdelplot = false
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
        @c CImGui.Selectable(
            stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i, " ", dtp.name, "###plot", i), &dtp.showplot, 0,
            (Cfloat(0), CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y))
        )
        CImGui.PopStyleVar()
        CImGui.OpenPopupOnItemClick(stcstr("daq plot menu", i))
        CImGui.Spacing()
        if CImGui.BeginDragDropSource(0)
            dp = TreeDragPayload(Cint(gi), Cint(pi))
            @c CImGui.SetDragDropPayload("Move DAQPlot", &dp, sizeof(TreeDragPayload))
            CImGui.Text(stcstr(mlstr("Plot"), " ", i, " ", dtp.name))
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Move DAQPlot")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(TreeDragPayload)
                d = unsafe_load(Ptr{TreeDragPayload}(unsafe_load(payload).Data))
                #拖到绘图上：进目标所在容器插到目标前（组内绘图同样直接进组，与 block 编辑器一致）
                moveleaf!(root, Int(d.group), Int(d.index), gi, pi)
            end
            payload = CImGui.AcceptDragDropPayload("Move DAQPlotGroup")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(TreeDragPayload)
                d = unsafe_load(Ptr{TreeDragPayload}(unsafe_load(payload).Data))
                #分类拖到叶子上：按平铺顺序插到目标之前（组内目标落到该分类之前）
                insertgrouporder!(root, Int(d.index), gi, pi)
            end
            CImGui.EndDragDropTarget()
        end
        if CImGui.BeginPopup(stcstr("daq plot menu", i))
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Select Data")))
                dtp.showdtpk = true
            end
            CImGui.Separator()
            if dtp.showplot && CImGui.MenuItem(stcstr(MORESTYLE.Icons.Update, " ", mlstr("Update")))
                dtp.dtpk.update = true
                syncplotdata(dtp.plot, dtp.dtpk, datastr, datafloat)
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy")))
                copydataplot = deepcopy(dtp)
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste")))
                container = gi == 0 ? root : root.children[gi]
                insert!(container.children, pi, Tree(copydataplot))
            end
            CImGui.Separator()
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Rename, " ", mlstr("Rename"))) && (isrename = true)
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && (isdelplot = true)
            CImGui.EndPopup()
        end
        # 删除（至少保留一个 plot）——只记录,遍历外统一删:父循环正在迭代 children,中途 deleteat! 会跳过兄弟节点
        isdelplot && (CImGui.OpenPopup(stcstr("##delete plot", i));
        isdelplot = false)
        if YesNoDialog(
            stcstr("##delete plot", i),
            mlstr("Confirm delete?"),
            CImGui.ImGuiWindowFlags_AlwaysAutoResize
        )
            length(plotleaves(root)) > 1 && (rmplot!(dtp.plot);
            push!(pendingdels, (gi, pi)))
        end
        # 重命名
        isrename && (CImGui.OpenPopup(stcstr("rename plot", i));
        isrename = false)
        if CImGui.BeginPopup(stcstr("rename plot", i))
            @c InputTextRSZ(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i, "###plot", i), &dtp.name)
            CImGui.EndPopup()
        end
    end

    #渲染一级分类节点，返回更新后的叶子索引
    function renderplotgroup(root::Tree{DataPlot}, group::Tree{DataPlot}, gi::Int, leaf_i::Int, datastr, datafloat=Dict())
        isrenamegroup = false
        isdelgroup = false
        # group.open = CImGui.TreeNodeEx(
        #     stcstr(group.open ? ICONS.ICON_FOLDER_OPEN : ICONS.ICON_FOLDER, " ", group.name, "###daqplots_group", gi),
        #     group.open ? CImGui.ImGuiTreeNodeFlags_DefaultOpen : Cint(0)
        # )
        CImGui.PushStyleColor(CImGui.ImGuiCol_Header, MORESTYLE.Colors.PanelBg)
        group.open = CImGui.CollapsingHeader(
            stcstr(group.open ? ICONS.ICON_FOLDER_OPEN : ICONS.ICON_FOLDER, " ", group.name, "###daqplots_group", gi)
        )
        CImGui.PopStyleColor()
        #在 TreeNode ID 作用域内捕获右键点击，展开态下 OpenPopupOnItemClick 会因作用域不一致而失效
        isgroupmenu = CImGui.IsItemHovered() && CImGui.IsMouseClicked(1)
        if CImGui.BeginDragDropSource(0)
            dp = TreeDragPayload(Cint(0), Cint(gi))
            @c CImGui.SetDragDropPayload("Move DAQPlotGroup", &dp, sizeof(TreeDragPayload))
            CImGui.Text(group.name)
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Move DAQPlot")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(TreeDragPayload)
                d = unsafe_load(Ptr{TreeDragPayload}(unsafe_load(payload).Data))
                #只有拖到组头上时 Ctrl 才进组（插到组尾）；无 Ctrl 插到该组之前的顶层位置，与 block 编辑器一致
                if unsafe_load(CImGui.GetIO().KeyCtrl)
                    moveleaf!(root, Int(d.group), Int(d.index), gi, length(group.children) + 1)
                else
                    insertleafbeforegroup!(root, Int(d.group), Int(d.index), gi)
                end
            end
            payload = CImGui.AcceptDragDropPayload("Move DAQPlotGroup")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(TreeDragPayload)
                d = unsafe_load(Ptr{TreeDragPayload}(unsafe_load(payload).Data))
                movegroup!(root, Int(d.index), gi)
            end
            CImGui.EndDragDropTarget()
        end
        if group.open
            for (pi, pnode) in enumerate(group.children)
                leaf_i += 1
                renderplotnode(root, pnode, leaf_i, gi, pi, datastr, datafloat)
            end
            # CImGui.TreePop()
            CImGui.SeparatorText("")
        else
            leaf_i += length(group.children)
        end
        # 分类右键菜单（与 BeginPopup 同处父级作用域）
        isgroupmenu && CImGui.OpenPopup(stcstr("daq plot group menu", gi))
        if CImGui.BeginPopup(stcstr("daq plot group menu", gi))
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Rename, " ", mlstr("Rename"))) && (isrenamegroup = true)
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && (isdelgroup = true)
            CImGui.EndPopup()
        end
        # 分类重命名
        isrenamegroup && (CImGui.OpenPopup(stcstr("rename daq plot group", gi));
        isrenamegroup = false)
        if CImGui.BeginPopup(stcstr("rename daq plot group", gi))
            @c InputTextRSZ(
                stcstr(ICONS.ICON_FOLDER, " ", mlstr("Group"), "###daqplots_group", gi),
                &group.name
            )
            CImGui.EndPopup()
        end
        # 是否删除分类（分类内 plot 移回顶层）
        isdelgroup && (CImGui.OpenPopup(stcstr("##if delete daqplotgroup", gi));
        isdelgroup = false)
        if YesNoDialog(
            stcstr("##if delete daqplotgroup", gi),
            mlstr("Move plots in group to top level?"),
            CImGui.ImGuiWindowFlags_AlwaysAutoResize
        )
            ungroup!(root, gi)
        end
        leaf_i
    end

    #树形编辑 DAQ 绘图树（与 task 树同模式：一级分类 + plot 叶子，支持拖拽重排）
    global function edit(root::Tree{DataPlot}, datastr, datafloat=Dict())
        # 同 daqtasks:卡片内去边框、留内边距
        # CImGui.BeginChild("DAQPlotTree", (0, 0), CImGui.ImGuiChildFlags_AlwaysUseWindowPadding)
        firstitem = true
        leaf_i = 0
        empty!(pendingdels)
        for (ci, child) in enumerate(root.children)
            if firstitem
                ccpos = CImGui.GetCursorScreenPos()
                CImGui.SetCursorScreenPos(ccpos.x, ccpos.y + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2)
                firstitem = false
            end
            if child.isgroup
                leaf_i = renderplotgroup(root, child, ci, leaf_i, datastr, datafloat)
            else
                leaf_i += 1
                renderplotnode(root, child, leaf_i, 0, ci, datastr, datafloat)
            end
        end
        #应用树形版待删项:gi、pi 均降序删除,高索引先删不扰动未删的低索引
        sort!(pendingdels; rev=true)
        for (gi, pi) in pendingdels
            gi != 0 && gi > length(root.children) && continue
            container = gi == 0 ? root : root.children[gi]
            pi <= length(container.children) && deleteat!(container.children, pi)
        end
        # CImGui.EndChild()
    end

    global pasteplot!(dtps::Vector{DataPlot}) = push!(dtps, copydataplot)
    global pasteplot!(root::Tree{DataPlot}) = push!(root.children, Tree(copydataplot))
end

function showdtpks(dtps::Vector{DataPlot}, id, datastr, datafloat=Dict())
    for (i, dtp) in enumerate(dtps)
        if dtp.showdtpk
            datakeys = [sort(collect(keys(isempty(datastr) ? datafloat : datastr))); ""]
            datakeys == dtp.dtpk.datalist || (dtp.dtpk.datalist = datakeys)
            @c edit(dtp.dtpk, stcstr(id, "-", i), &dtp.showdtpk)
            syncplotdata(dtp.plot, dtp.dtpk, datastr, datafloat)
        end
    end
end

function renderplots(dtps::Vector{DataPlot}, id)
    for (i, dtp) in enumerate(dtps)
        dtp.showplot || continue
        ws = (
            dtp.plot.size[1] + 2unsafe_load(IMGUISTYLE.WindowPadding.x),
            dtp.plot.size[2] + 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight()
        )
        CImGui.SetNextWindowSize(ws, CImGui.ImGuiCond_Once)
        nm = stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i, " ", dtp.name, "###", id, "-", i, "dtv")
        begun, own, popenarg = @c BeginNoClose(nm, &dtp.showplot, true; hastitle=true)
        if begun
            SetWindowShadow()
            QPlot(dtp.plot, stcstr(id, "-", i))
        end
        @c EndNoClose(own, &dtp.showplot, popenarg)
    end
end

function update!(dtps::Vector{DataPlot}, datastr, datafloat=Dict(); all=false)
    for dtp in dtps
        (all || dtp.showplot) || continue
        dtp.dtpk.update = true
        syncplotdata(dtp.plot, dtp.dtpk, datastr, datafloat)
    end
end

norealtime!(root::Tree{DataPlot}) = norealtime!(plotleaves(root))
function norealtime!(dtps::Vector{DataPlot})
    for dtp in dtps
        for dtss in dtp.dtpk.series
            dtss.isrealtime = false
        end
    end
    return dtps
end

rmplots!(root::Tree{DataPlot}) = rmplots!(plotleaves(root))
function rmplots!(dtps::Vector{DataPlot})
    for dtp in dtps
        rmplot!(dtp.plot)
    end
end