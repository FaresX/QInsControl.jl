mutable struct Node
    id::Cint
    title::String
    content::String
    input_ids::Vector{Cint}
    input_labels::Vector{String}
    output_ids::Vector{Cint}
    output_labels::Vector{String}
    connected_ids::Set{Cint}
    position::CImGui.ImVec2
end
# input id: x0xx nodeid 0 inputid output id: x1xx nodeid 1 outputid

Node() = Node(1, "Node 1", "", [1001], ["Input 1"], [1101], ["Output 1"], Set(), (0, 0))
Node(id) = Node(
    id,
    morestyle.Icons.CommonNode * " Node $id",
    "",
    [id * 1000 + 1],
    ["Input 1"],
    [id * 1000 + 100 + 1],
    ["Output 1"],
    Set(),
    (0, 0)
)
Node(id, ::Val{:ground}) = Node(
    id,
    morestyle.Icons.GroundNode * " 接地头 0Ω",
    "",
    [],
    [],
    [id * 1000 + 100 + 1],
    ["Ground"],
    Set(),
    (0, 0)
)
Node(id, ::Val{:resistance}) = Node(
    id,
    morestyle.Icons.ResistanceNode * " 电阻 10MΩ",
    "",
    [id * 1000 + 1],
    ["Input 1"],
    [id * 1000 + 100 + 1],
    ["Output 1"],
    Set(),
    (0, 0)
)
Node(id, ::Val{:trilink21}) = Node(
    id,
    morestyle.Icons.TrilinkNode * " 三通21",
    "",
    [id * 1000 + 1, id * 1000 + 2],
    ["Input 1", "Input 2"],
    [id * 1000 + 100 + 1],
    ["Output 1"],
    Set(),
    (0, 0)
)
Node(id, ::Val{:trilink12}) = Node(
    id,
    morestyle.Icons.TrilinkNode * " 三通12",
    "",
    [id * 1000 + 1],
    ["Input 1"],
    [id * 1000 + 100 + 1, id * 1000 + 100 + 2],
    ["Output 1", "Output 2"],
    Set(),
    (0, 0)
)
function Node(id, ::Val{:samplebase16})
    node = Node(id, morestyle.Icons.SampleBaseNode * " 样品座16", "", [], [], [], [], Set(), (0, 0))
    for i in 1:16
        push!(node.input_ids, id * 1000 + i)
        push!(node.input_labels, "Input $i")
        push!(node.output_ids, id * 1000 + 100 + i)
        push!(node.output_labels, "Output $i")
    end
    node
end
function Node(id, ::Val{:samplebase24})
    node = Node(id, morestyle.Icons.SampleBaseNode * " 样品座24", "", [], [], [], [], Set(), (0, 0))
    for i in 1:24
        push!(node.input_ids, id * 1000 + i)
        push!(node.input_labels, "Input $i")
        push!(node.output_ids, id * 1000 + 100 + i)
        push!(node.output_labels, "Output $i")
    end
    node
end

function Node(id, instrnm, ::Val{:instrument})
    node = Node(
        id,
        insconf[instrnm].conf.icon * " " * instrnm,
        "",
        [],
        insconf[instrnm].conf.input_labels,
        [],
        insconf[instrnm].conf.output_labels,
        Set(),
        (0, 0)
    )
    for i in 1:length(node.input_labels)
        push!(node.input_ids, id * 1000 + i)
    end
    for i in 1:length(node.output_labels)
        push!(node.output_ids, id * 1000 + 100 + i)
    end
    node
end

mutable struct NodeEditor
    nodes::OrderedDict{Cint,Node}
    links::Vector{Tuple{Cint,Cint}}
    link_start::Cint
    link_stop::Cint
    created_from_snap::Bool
    hoverednode_id::Cint
    hoveredlink_id::Cint
end
NodeEditor() = NodeEditor(OrderedDict(), Tuple{Cint,Cint}[], 0, 0, false, 0, 0)

maxid(nodeeditor::NodeEditor) = isempty(nodeeditor.nodes) ? 0 : max_with_empty(keys(nodeeditor.nodes))

function edit(node::Node)
    imnodes_BeginNode(node.id)
    imnodes_BeginNodeTitleBar()
    CImGui.Text(node.title)
    imnodes_EndNodeTitleBar()
    CImGui.Text(node.content)
    CImGui.BeginGroup()
    for i in eachindex(node.input_ids)
        imnodes_BeginInputAttribute(node.input_ids[i], morestyle.PinShapes.input)
        CImGui.TextColored(
            if node.input_ids[i] in node.connected_ids
                morestyle.Colors.NodeConnected
            else
                CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
            end,
            node.input_labels[i]
        )
        imnodes_EndInputAttribute()
    end
    CImGui.EndGroup()
    inlens = lengthpr.(node.input_labels)
    outlens = lengthpr.(node.output_labels)
    contentlines = split(node.content, '\n')
    contentls = lengthpr.(contentlines)
    maxcontentline = argmax(contentls)
    if true in (max_with_empty(inlens) + max_with_empty(outlens) .< [lengthpr(node.title), contentls[maxcontentline]])
        maxinlabel = isempty(node.input_labels) ? "" : node.input_labels[argmax(inlens)]
        maxoutlabel = isempty(node.output_labels) ? "" : node.output_labels[argmax(outlens)]
        spacing = if lengthpr(node.title) < contentls[maxcontentline]
            CImGui.CalcTextSize(contentlines[maxcontentline]).x - CImGui.CalcTextSize(maxinlabel).x - CImGui.CalcTextSize(maxoutlabel).x
        else
            CImGui.CalcTextSize(node.title).x - CImGui.CalcTextSize(maxinlabel).x - CImGui.CalcTextSize(maxoutlabel).x
        end
        CImGui.SameLine(0, max(spacing, 2CImGui.GetFontSize()))
    else
        CImGui.SameLine(0, 2CImGui.GetFontSize())
    end
    CImGui.BeginGroup()
    for i in eachindex(node.output_ids)
        imnodes_BeginOutputAttribute(node.output_ids[i], morestyle.PinShapes.output)
        CImGui.TextColored(
            if node.output_ids[i] in node.connected_ids
                morestyle.Colors.NodeConnected
            else
                CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
            end,
            node.output_labels[i]
        )
        imnodes_EndOutputAttribute()
    end
    CImGui.EndGroup()
    imnodes_EndNode()
end

let
    isanynodehovered::Bool = false
    isanylinkhovered::Bool = false
    newnode::Bool = false
    global function edit(nodeeditor::NodeEditor)
        imnodes_BeginNodeEditor()
        if CImGui.BeginPopup("NodeEditor")
            if CImGui.MenuItem(stcstr(morestyle.Icons.CommonNode, " 通用节点"))
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, id => Node(id))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(morestyle.Icons.GroundNode, " 接地头"))
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, id => Node(id, Val(:ground)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(morestyle.Icons.ResistanceNode, " 电阻"))
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, id => Node(id, Val(:resistance)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(morestyle.Icons.TrilinkNode, " 三通21"))
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, id => Node(id, Val(:trilink21)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(morestyle.Icons.TrilinkNode, " 三通12"))
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, id => Node(id, Val(:trilink12)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(morestyle.Icons.SampleBaseNode, " 样品座16"))
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, id => Node(id, Val(:samplebase16)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(morestyle.Icons.SampleBaseNode, " 样品座24"))
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, id => Node(id, Val(:samplebase24)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            for ins in keys(insconf)
                ins == "Others" && continue
                if CImGui.MenuItem(stcstr(insconf[ins].conf.icon, " ", ins))
                    id = maxid(nodeeditor) + 1
                    push!(nodeeditor.nodes, id => Node(id, ins, Val(:instrument)))
                    imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                    newnode = true
                end
            end
            CImGui.EndPopup()
        end
        if CImGui.BeginPopup("Edit Node")
            hoverednode = nodeeditor.nodes[nodeeditor.hoverednode_id]
            if CImGui.BeginMenu(stcstr(morestyle.Icons.Edit, " 编辑"))
                @c InputTextRSZ("标题", &hoverednode.title)
                linesnum = (1 + length(findall("\n", hoverednode.content)))
                mtheigth = (linesnum > 6 ? 6 : linesnum) * CImGui.GetTextLineHeight() + 2unsafe_load(imguistyle.FramePadding.y)
                @c InputTextMultilineRSZ("内容", &hoverednode.content, (Cfloat(0), mtheigth))
                if CImGui.BeginPopupContextItem()
                    for ins in keys(instrbufferviewers)
                        if !isempty(instrbufferviewers[ins])
                            if CImGui.BeginMenu(ins)
                                for addr in keys(instrbufferviewers[ins])
                                    CImGui.MenuItem(addr) && (hoverednode.content *= addr)
                                end
                                CImGui.EndMenu()
                            end
                        end
                    end
                    CImGui.EndPopup()
                end
                width = CImGui.GetItemRectSize().x / 2
                CImGui.BeginGroup()
                for i in eachindex(hoverednode.input_ids)
                    input_label = hoverednode.input_labels[i]
                    CImGui.PushItemWidth(width - CImGui.CalcTextSize(stcstr("In ", i, "       ")).x)
                    @c InputTextRSZ(stcstr("In ", i), &input_label)
                    hoverednode.input_labels[i] = input_label
                    CImGui.PopItemWidth()
                    CImGui.SameLine()
                    if CImGui.Button(stcstr(morestyle.Icons.CloseFile, "##input ", i))
                        deleteat!(hoverednode.input_ids, i)
                        deleteat!(hoverednode.input_labels, i)
                        break
                    end
                end
                CImGui.EndGroup()
                CImGui.SameLine()
                CImGui.BeginGroup()
                for i in eachindex(hoverednode.output_ids)
                    output_label = hoverednode.output_labels[i]
                    CImGui.PushItemWidth(width - CImGui.CalcTextSize(stcstr("Out ", i, "       ")).x)
                    @c InputTextRSZ(stcstr("Out ", i), &output_label)
                    hoverednode.output_labels[i] = output_label
                    CImGui.PopItemWidth()
                    CImGui.SameLine()
                    if CImGui.Button(stcstr(morestyle.Icons.CloseFile, "##Output ", i))
                        deleteat!(hoverednode.output_ids, i)
                        deleteat!(hoverednode.output_labels, i)
                        break
                    end
                end
                CImGui.EndGroup()
                if CImGui.Button(stcstr(morestyle.Icons.NewFile, " 添加##Input"))
                    li = length(hoverednode.input_ids)
                    push!(hoverednode.input_ids, hoverednode.id * 1000 + li + 1)
                    push!(hoverednode.input_labels, "Input $(li+1)")
                end
                CImGui.SameLine(width)
                if CImGui.Button(stcstr(morestyle.Icons.NewFile, " 添加##Output"))
                    lo = length(hoverednode.output_ids)
                    push!(hoverednode.output_ids, hoverednode.id * 1000 + 100 + lo + 1)
                    push!(hoverednode.output_labels, "Output $(lo+1)")
                end
                CImGui.EndMenu()
            end
            if CImGui.MenuItem(stcstr(morestyle.Icons.CloseFile, " 删除"))
                delete!(nodeeditor.nodes, nodeeditor.hoverednode_id)
                dellinks = Cint[]
                for (j, link) in enumerate(nodeeditor.links)
                    (link[1] ÷ 1000 == hoverednode.id || link[2] ÷ 1000 == hoverednode.id) && push!(dellinks, j)
                end
                deleteat!(nodeeditor.links, dellinks)
            end
            CImGui.EndPopup()
        end
        if CImGui.BeginPopup("Edit Link")
            if CImGui.MenuItem(stcstr(morestyle.Icons.CloseFile, " 删除"))
                deleteat!(nodeeditor.links, nodeeditor.hoveredlink_id)
            end
            CImGui.EndPopup()
        end
        if CImGui.IsMouseClicked(1)
            if imnodes_IsEditorHovered() && !isanynodehovered && !isanylinkhovered
                CImGui.OpenPopup("NodeEditor")
            elseif isanynodehovered
                CImGui.OpenPopup("Edit Node")
            elseif isanylinkhovered
                CImGui.OpenPopup("Edit Link")
            end
        end
        for (id, node) in nodeeditor.nodes
            newnode || imnodes_SetNodeGridSpacePos(id, node.position)
            edit(node)
            empty!(node.connected_ids)
        end
        newnode = false
        for (i, link) in enumerate(nodeeditor.links)
            imnodes_Link(i, link...)
            push!(nodeeditor.nodes[link[1]÷1000].connected_ids, link[1])
            push!(nodeeditor.nodes[link[2]÷1000].connected_ids, link[2])
        end
        imnodes_EndNodeEditor()
        if @c imnodes_IsLinkCreated_BoolPtr(
            &nodeeditor.link_start,
            &nodeeditor.link_stop,
            &nodeeditor.created_from_snap
        )
            if (nodeeditor.link_start, nodeeditor.link_stop) ∉ nodeeditor.links
                push!(nodeeditor.links, (nodeeditor.link_start, nodeeditor.link_stop))
            end
        end
        for (id, node) in nodeeditor.nodes
            @c imnodes_GetNodeGridSpacePos(&node.position, id)
        end
        isanynodehovered = @c imnodes_IsNodeHovered(&nodeeditor.hoverednode_id)
        isanylinkhovered = @c imnodes_IsLinkHovered(&nodeeditor.hoveredlink_id)
    end
end

let
    hold::Bool = false
    holdsz::Cfloat = 0
    global function edit(nodeeditor::NodeEditor, id, p_open::Ref{Bool})
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_PopupBg))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, unsafe_load(imguistyle.PopupRounding))
        isfocus = true
        if CImGui.Begin(id, p_open, CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking)
            CImGui.TextColored(morestyle.Colors.HighlightText, morestyle.Icons.Circuit)
            CImGui.SameLine()
            CImGui.Text(" 电路")
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
            @c CImGui.Checkbox("HOLD", &hold)
            holdsz = CImGui.GetItemRectSize().x
            edit(nodeeditor)
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        CImGui.End()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        p_open[] &= (isfocus | hold)
    end
end

function view(nodeeditor::NodeEditor)
    imnodes_BeginNodeEditor()
    for (id, node) in nodeeditor.nodes
        imnodes_SetNodeGridSpacePos(node.id, node.position)
        edit(node)
        empty!(node.connected_ids)
    end
    for (i, link) in enumerate(nodeeditor.links)
        imnodes_Link(i, link...)
        push!(nodeeditor.nodes[link[1]÷1000].connected_ids, link[1])
        push!(nodeeditor.nodes[link[2]÷1000].connected_ids, link[2])
    end
    imnodes_EndNodeEditor()
    for (id, node) in nodeeditor.nodes
        @c imnodes_GetNodeGridSpacePos(&node.position, id)
    end
end

###Patch###
Base.convert(::Type{OrderedDict{Cint,Node}}, nodes::Vector{Node}) = OrderedDict(node.id => node for node in nodes)