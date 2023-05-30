mutable struct Node
    id::Cint
    title::String
    content::String
    input_ids::Vector{Cint}
    input_labels::Vector{String}
    output_ids::Vector{Cint}
    output_labels::Vector{String}
    position::CImGui.ImVec2
end
Node() = Node(1, "Node 1", "", [1001], ["Input 1"], [1101], ["Output 1"], (0, 0))
Node(id) = Node(
    id,
    morestyle.Icons.CommonNode * " Node $id",
    "",
    [id * 1000 + 1],
    ["Input 1"],
    [id * 1000 + 100 + 1],
    ["Output 1"],
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
    (0, 0)
)
function Node(id, ::Val{:samplebase16})
    node = Node(id, morestyle.Icons.SampleBaseNode * " 样品座16", "", [], [], [], [], (0, 0))
    for i in 1:16
        push!(node.input_ids, id * 1000 + i)
        push!(node.input_labels, "Input $i")
        push!(node.output_ids, id * 1000 + 100 + i)
        push!(node.output_labels, "Output $i")
    end
    node
end
function Node(id, ::Val{:samplebase24})
    node = Node(id, morestyle.Icons.SampleBaseNode * " 样品座24", "", [], [], [], [], (0, 0))
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
    nodes::Vector{Node}
    links::Vector{Tuple{Cint,Cint}}
    link_start::Cint
    link_stop::Cint
    created_from_snap::Bool
    link_destroyed::Cint
    hoverednode::Cint
    hoveredlink::Cint
end
NodeEditor() = NodeEditor(Node[], Tuple{Cint,Cint}[], 0, 0, false, 0, 0, 0)

maxid(nodeeditor::NodeEditor) = isempty(nodeeditor.nodes) ? 0 : max_with_empty([node.id for node in nodeeditor.nodes])

function edit(node::Node)
    imnodes_BeginNode(node.id)
    imnodes_BeginNodeTitleBar()
    CImGui.Text(node.title)
    imnodes_EndNodeTitleBar()
    CImGui.Text(node.content)
    CImGui.BeginGroup()
    for i in eachindex(node.input_ids)
        imnodes_BeginInputAttribute(node.input_ids[i], morestyle.PinShapes.input)
        CImGui.Text(node.input_labels[i])
        imnodes_EndInputAttribute()
    end
    CImGui.EndGroup()
    inlens = lengthpr.(node.input_labels)
    outlens = lengthpr.(node.output_labels)
    if max_with_empty(inlens) + max_with_empty(outlens) < lengthpr(node.title)
        maxinlabel = isempty(node.input_labels) ? "" : node.input_labels[argmax(inlens)]
        maxoutlabel = isempty(node.output_labels) ? "" : node.output_labels[argmax(outlens)]
        spacing = CImGui.CalcTextSize(node.title).x - CImGui.CalcTextSize(maxinlabel).x - CImGui.CalcTextSize(maxoutlabel).x
        CImGui.SameLine(0, spacing)
    else
        CImGui.SameLine(0, 2CImGui.GetFontSize())
    end
    CImGui.BeginGroup()
    for i in eachindex(node.output_ids)
        imnodes_BeginOutputAttribute(node.output_ids[i], morestyle.PinShapes.output)
        CImGui.Text(node.output_labels[i])
        imnodes_EndOutputAttribute()
    end
    CImGui.EndGroup()
    imnodes_EndNode()
end

let
    isanynodehovered::Bool = false
    isanylinkhovered::Bool = false
    global function edit(nodeeditor::NodeEditor)
        imnodes_BeginNodeEditor()
        if CImGui.BeginPopup("NodeEditor")
            if CImGui.MenuItem(morestyle.Icons.CommonNode * " 通用节点")
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, Node(id))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
            end
            if CImGui.MenuItem(morestyle.Icons.GroundNode * " 接地头")
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, Node(id, Val(:ground)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
            end
            if CImGui.MenuItem(morestyle.Icons.ResistanceNode * " 电阻")
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, Node(id, Val(:resistance)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
            end
            if CImGui.MenuItem(morestyle.Icons.TrilinkNode * " 三通21")
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, Node(id, Val(:trilink21)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
            end
            if CImGui.MenuItem(morestyle.Icons.TrilinkNode * " 三通12")
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, Node(id, Val(:trilink12)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
            end
            if CImGui.MenuItem(morestyle.Icons.SampleBaseNode * " 样品座16")
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, Node(id, Val(:samplebase16)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
            end
            if CImGui.MenuItem(morestyle.Icons.SampleBaseNode * " 样品座24")
                id = maxid(nodeeditor) + 1
                push!(nodeeditor.nodes, Node(id, Val(:samplebase24)))
                imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
            end
            for ins in keys(insconf)
                ins == "Others" && continue
                if CImGui.MenuItem(insconf[ins].conf.icon * " " * ins)
                    id = maxid(nodeeditor) + 1
                    push!(nodeeditor.nodes, Node(id, ins, Val(:instrument)))
                    imnodes_SetNodeScreenSpacePos(id, CImGui.GetMousePosOnOpeningCurrentPopup())
                end
            end
            CImGui.EndPopup()
        end
        if CImGui.BeginPopup("Edit Node")
            hoverednode_idx, hoverednode = only(
                [(i, node) for (i, node) in enumerate(nodeeditor.nodes) if node.id == nodeeditor.hoverednode]
            )
            if CImGui.BeginMenu(morestyle.Icons.Edit * " 编辑")
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
                    CImGui.PushItemWidth(width - CImGui.CalcTextSize("In $i       ").x)
                    @c InputTextRSZ("In $i", &input_label)
                    hoverednode.input_labels[i] = input_label
                    CImGui.PopItemWidth()
                    CImGui.SameLine()
                    if CImGui.Button(morestyle.Icons.CloseFile * "##input $i")
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
                    CImGui.PushItemWidth(width - CImGui.CalcTextSize("Out $i       ").x)
                    @c InputTextRSZ("Out $i", &output_label)
                    hoverednode.output_labels[i] = output_label
                    CImGui.PopItemWidth()
                    CImGui.SameLine()
                    if CImGui.Button(morestyle.Icons.CloseFile * "##Output $i")
                        deleteat!(hoverednode.output_ids, i)
                        deleteat!(hoverednode.output_labels, i)
                        break
                    end
                end
                CImGui.EndGroup()
                if CImGui.Button(morestyle.Icons.NewFile * " 添加##Input")
                    li = length(hoverednode.input_ids)
                    push!(hoverednode.input_ids, hoverednode.id * 1000 + li + 1)
                    push!(hoverednode.input_labels, "Input $(li+1)")
                end
                CImGui.SameLine(width)
                if CImGui.Button(morestyle.Icons.NewFile * " 添加##Output")
                    lo = length(hoverednode.output_ids)
                    push!(hoverednode.output_ids, hoverednode.id * 1000 + 100 + lo + 1)
                    push!(hoverednode.output_labels, "Output $(lo+1)")
                end
                CImGui.EndMenu()
            end
            if CImGui.MenuItem(morestyle.Icons.CloseFile * " 删除")
                deleteat!(nodeeditor.nodes, hoverednode_idx)
                dellinks = Cint[]
                for (j, link) in enumerate(nodeeditor.links)
                    if link[1] ÷ 1000 == hoverednode.id || link[2] ÷ 1000 == hoverednode.id
                        push!(dellinks, j)
                    end
                end
                deleteat!(nodeeditor.links, dellinks)
            end
            CImGui.EndPopup()
        end
        if CImGui.BeginPopup("Edit Link")
            CImGui.MenuItem(morestyle.Icons.CloseFile * " 删除") && deleteat!(nodeeditor.links, nodeeditor.hoveredlink)
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
        for node in nodeeditor.nodes
            edit(node)
        end
        for (i, link) in enumerate(nodeeditor.links)
            imnodes_Link(i, link...)
        end
        imnodes_EndNodeEditor()
        if @c imnodes_IsLinkCreated_BoolPtr(&nodeeditor.link_start, &nodeeditor.link_stop, &nodeeditor.created_from_snap)
            if !((nodeeditor.link_start, nodeeditor.link_stop) in nodeeditor.links)
                push!(nodeeditor.links, (nodeeditor.link_start, nodeeditor.link_stop))
            end
        end
        for node in nodeeditor.nodes
            @c imnodes_GetNodeGridSpacePos(&node.position, node.id)
        end
        isanynodehovered = @c imnodes_IsNodeHovered(&nodeeditor.hoverednode)
        isanylinkhovered = @c imnodes_IsLinkHovered(&nodeeditor.hoveredlink)
    end
end

function view(nodeeditor::NodeEditor)
    imnodes_BeginNodeEditor()
    for node in nodeeditor.nodes
        imnodes_SetNodeGridSpacePos(node.id, node.position)
        edit(node)
    end
    for (i, link) in enumerate(nodeeditor.links)
        imnodes_Link(i, link...)
    end
    imnodes_EndNodeEditor()
    for node in nodeeditor.nodes
        @c imnodes_GetNodeGridSpacePos(&node.position, node.id)
    end
end