abstract type AbstractNode end

mutable struct Node <: AbstractNode
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
    MORESTYLE.Icons.CommonNode * " Node $id",
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
    MORESTYLE.Icons.GroundNode * " 接地头 0Ω",
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
    MORESTYLE.Icons.ResistanceNode * " 电阻 10MΩ",
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
    MORESTYLE.Icons.TrilinkNode * " 三通21",
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
    MORESTYLE.Icons.TrilinkNode * " 三通12",
    "",
    [id * 1000 + 1],
    ["Input 1"],
    [id * 1000 + 100 + 1, id * 1000 + 100 + 2],
    ["Output 1", "Output 2"],
    Set(),
    (0, 0)
)
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

mutable struct ResizeGrip
    pos::ImVec2
    size::ImVec2
    limmin::ImVec2
    limmax::ImVec2
    hovered::Bool
    dragging::Bool
end
ResizeGrip() = ResizeGrip((0, 0), (24, 24), (0, 0), (Inf, Inf), false, false)

mutable struct ImagePin
    pos::ImVec2
    radius::Cfloat
    num_segments::Cint
    thickness::Cint
    limmin::ImVec2
    limmax::ImVec2
    link_idx::Cint
    linked::Bool
    hovered_in::Bool
    hovered_out::Bool
    dragging_in::Bool
    dragging_out::Bool
end
ImagePin() = ImagePin((0, 0), 24, 12, 4, (0, 0), (Inf, Inf), 1, false, false, false, false, false)

mutable struct ImageRegion
    id::Int
    posmin::ImVec2
    posmax::ImVec2
    image::Matrix{T} where {T}
    rszgrip::ResizeGrip
    pins::Vector{ImagePin}
    pin_relds::Vector{ImVec2}
    hovered::Bool
end
ImageRegion() = ImageRegion(0, (0, 0), (400, 400), Matrix{RGBA}(undef, 0, 0), ResizeGrip(), [], [], false)

mutable struct SampleBaseNode <: AbstractNode
    id::Cint
    title::String
    content::String
    attr_ids::Vector{Cint}
    attr_labels::Vector{String}
    attr_types::Vector{Bool} # true for input 
    connected_ids::Set{Cint}
    position::CImGui.ImVec2
    imgr::ImageRegion
end
SampleBaseNode() = SampleBaseNode(1, MORESTYLE.Icons.SampleBaseNode*"样品座", "", [], [], [], Set(), (0, 0), ImageRegion())
function SampleBaseNode(id)
    node = SampleBaseNode()
    node.id = id
    for i in 1:24
        push!(node.attr_ids, id * 1000 + i)
        push!(node.attr_labels, "Pin $i")
        push!(node.attr_types, isodd(i))
    end
    node
end

mutable struct NodeEditor
    nodes::OrderedDict{Cint,AbstractNode}
    links::Vector{Tuple{Cint,Cint}}
    link_start::Cint
    link_stop::Cint
    created_from_snap::Bool
    hoverednode_id::Cint
    hoveredlink_id::Cint
    maxid::Cint
end
NodeEditor() = NodeEditor(OrderedDict(), Tuple{Cint,Cint}[], 0, 0, false, 0, 0, 0)

### update_state ###----------------------------------------------------------------------------------------------------
function update_state!(rszgrip::ResizeGrip)
    mospos = CImGui.GetMousePos()
    rszgrip.hovered = inregion(mospos, rszgrip.pos .- rszgrip.size, rszgrip.pos)
    rszgrip.hovered &= -(rszgrip.size.y / rszgrip.size.x) * (mospos.x - rszgrip.pos.x + rszgrip.size.x) < mospos.y - rszgrip.pos.y
    if rszgrip.dragging
        if CImGui.IsMouseDragging(2)
            rszgrip.pos = cutoff(mospos, rszgrip.limmin, rszgrip.limmax) .+ rszgrip.size ./ 4
        else
            rszgrip.dragging = false
        end
    else
        rszgrip.hovered && CImGui.IsMouseDown(2) && (rszgrip.dragging = true)
    end
end

function update_state!(pin::ImagePin)
    mospos = CImGui.GetMousePos()
    reld2 = sqrt(sum(abs2.(mospos .- pin.pos)))
    pin.hovered_in = reld2 < pin.radius - pin.thickness
    pin.hovered_out = pin.radius - pin.thickness < reld2 < pin.radius + pin.thickness
    if pin.dragging_in
        CImGui.IsMouseDragging(2) ? pin.pos = cutoff(mospos, pin.limmin, pin.limmax) : pin.dragging_in = false
    else
        pin.hovered_in && !pin.dragging_out && CImGui.IsMouseDown(2) && (pin.dragging_in = true)
    end
    if pin.dragging_out
        CImGui.IsMouseClicked(0) ? (pin.dragging_out = false) : pin.radius = sqrt(sum(abs2.(mospos .- pin.pos)))
    else
        pin.hovered_out && !pin.dragging_in && CImGui.IsMouseClicked(0) && (pin.dragging_out = true)
    end
end

function update_state!(imgr::ImageRegion)
    for (i, pin) in enumerate(imgr.pins)
        imgr.rszgrip.dragging || update_state!(pin)
        pin.limmin, pin.limmax = imgr.posmin, imgr.posmax
        pin.dragging_in && (imgr.pin_relds[i] = @. (pin.pos - imgr.posmin) / (imgr.posmax - imgr.posmin); break)
    end
    imgr.rszgrip.limmin, imgr.rszgrip.limmax = imgr.posmin, (Inf, Inf)
    true in map(x -> x.dragging_in, imgr.pins) || update_state!(imgr.rszgrip)
    newsize = imgr.rszgrip.pos .- imgr.posmin
    imgr.posmax = Tuple(newsize[i] > 60 ? imgr.rszgrip.pos[i] : imgr.posmax[i] for i in eachindex(newsize))
    imgr.rszgrip.pos = imgr.posmax
    imgr.hovered = inregion(CImGui.GetMousePos(), imgr.posmin, imgr.posmax)
    for (i, pin) in enumerate(imgr.pins)
        pin.dragging_in ? break : pin.pos = @. (imgr.posmax - imgr.posmin) * imgr.pin_relds[i] + imgr.posmin
    end
end

### draw ###------------------------------------------------------------------------------------------------------------
function draw(rszgrip::ResizeGrip)
    CImGui.AddTriangleFilled(
        CImGui.GetWindowDrawList(),
        (rszgrip.pos.x - rszgrip.size.x, rszgrip.pos.y), rszgrip.pos, (rszgrip.pos.x, rszgrip.pos.y - rszgrip.size.y),
        if rszgrip.hovered && rszgrip.dragging
            CImGui.ColorConvertFloat4ToU32(CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGripActive))
        elseif rszgrip.hovered
            CImGui.ColorConvertFloat4ToU32(CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGripHovered))
        else
            CImGui.ColorConvertFloat4ToU32(CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGrip))
        end
    )
end

function draw(pin::ImagePin)
    drawlist = CImGui.GetWindowDrawList()
    CImGui.AddCircle(
        drawlist,
        pin.pos, pin.radius,
        CImGui.ColorConvertFloat4ToU32(
            if pin.dragging_in || pin.dragging_out
                MORESTYLE.Colors.ImagePinDragging
            elseif pin.hovered_out
                MORESTYLE.Colors.ImagePinHoveredout
            else
                MORESTYLE.Colors.ImagePin
            end
        ),
        pin.num_segments, pin.thickness
    )
    if pin.linked
        CImGui.AddCircleFilled(
            drawlist,
            pin.pos, pin.radius - pin.thickness / 2,
            CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.NodeConnected),
            pin.num_segments
        )
    end
    ftsz = ceil(Int, 3pin.radius / 2)
    l = lengthpr(stcstr(pin.link_idx))
    CImGui.AddText(
        drawlist,
        CImGui.GetFont(),
        ftsz,
        pin.pos .- (l * ftsz / 4, ftsz / 2),
        CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.ImagePinLinkId),
        stcstr(pin.link_idx)
    )
end

function draw(imgr::ImageRegion)
    CImGui.Image(Ptr{Cvoid}(imgr.id), imgr.posmax .- imgr.posmin)
    imgr.posmin = CImGui.GetItemRectMin()
    imgr.posmax = CImGui.GetItemRectMax()
    imgr.rszgrip.pos = imgr.posmax
    update_state!(imgr)
    for (i, pin) in enumerate(imgr.pins)
        draw(pin)
        pin.hovered_in && CImGui.IsMouseClicked(1) && CImGui.OpenPopup(stcstr("editpin", pin.pos))
        if CImGui.BeginPopup(stcstr("editpin", pin.pos))
            @c CImGui.InputInt("阵脚", &pin.link_idx)
            @c CImGui.DragFloat("大小", &pin.radius, 1.0, 1, 100, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
            CImGui.SameLine()
            CImGui.Button(MORESTYLE.Icons.CloseFile) && (deleteat!(imgr.pins, i); deleteat!(imgr.pin_relds, i))
            CImGui.EndPopup()
        end
    end
    draw(imgr.rszgrip)
end

### edit ###------------------------------------------------------------------------------------------------------------
function edit(node::Node)
    imnodes_BeginNode(node.id)
    imnodes_BeginNodeTitleBar()
    CImGui.Text(node.title)
    imnodes_EndNodeTitleBar()
    CImGui.Text(node.content)
    CImGui.BeginGroup()
    for i in eachindex(node.input_ids)
        imnodes_BeginInputAttribute(node.input_ids[i], MORESTYLE.PinShapes.input)
        CImGui.TextColored(
            if node.input_ids[i] in node.connected_ids
                MORESTYLE.Colors.NodeConnected
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
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
        imnodes_BeginOutputAttribute(node.output_ids[i], MORESTYLE.PinShapes.output)
        CImGui.TextColored(
            if node.output_ids[i] in node.connected_ids
                MORESTYLE.Colors.NodeConnected
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
            end,
            node.output_labels[i]
        )
        imnodes_EndOutputAttribute()
    end
    CImGui.EndGroup()
    imnodes_EndNode()
end

let
    pinbuf::ImagePin = ImagePin()
    global function edit(imgr::ImageRegion)
        draw(imgr)
        openpopup = imgr.hovered && !imgr.rszgrip.hovered && CImGui.IsMouseClicked(1) &&
                    all(map(x -> !x.hovered_in, imgr.pins)) && all(map(x -> !x.hovered_out, imgr.pins))
        openpopup && CImGui.OpenPopup(stcstr("editimage", imgr.id))
        if CImGui.BeginPopup(stcstr("editimage", imgr.id))
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Load, "加载"))
                imgpath = pick_file(filterlist="png,jpg,jpeg,tif,bmp")
                if isfile(imgpath)
                    try
                        img = RGBA.(collect(transpose(FileIO.load(imgpath))))
                        imgsize = size(img)
                        imgr.id = ImGui_ImplOpenGL3_CreateImageTexture(imgsize...)
                        ImGui_ImplOpenGL3_UpdateImageTexture(imgr.id, img, imgsize...)
                        imgr.image = img
                    catch e
                        @error "[$(now())]\n加载图像出错！！！" exception = e
                    end
                end
            end
            if CImGui.CollapsingHeader("阵脚")
                @c CImGui.InputInt("阵脚", &pinbuf.link_idx)
                @c CImGui.DragFloat("大小", &pinbuf.radius, 1.0, 1, 100, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                pinbuf.pos = CImGui.GetMousePosOnOpeningCurrentPopup()
                CImGui.SameLine()
                if CImGui.Button(MORESTYLE.Icons.NewFile * "##imgpin")
                    reld = (pinbuf.pos .- imgr.posmin) ./ (imgr.posmax .- imgr.posmin)
                    push!(imgr.pins, deepcopy(pinbuf))
                    push!(imgr.pin_relds, reld)
                    CImGui.CloseCurrentPopup()
                end
            end
            CImGui.EndPopup()
        end
    end
end

function edit(node::SampleBaseNode)
    imnodes_BeginNode(node.id)
    imnodes_BeginNodeTitleBar()
    CImGui.Text(node.title)
    imnodes_EndNodeTitleBar()
    CImGui.Text(node.content)
    CImGui.BeginGroup()
    for i in eachindex(node.attr_ids)
        node.attr_types[i] || (CImGui.Text(""); continue)
        imnodes_BeginInputAttribute(node.attr_ids[i], MORESTYLE.PinShapes.input)
        CImGui.TextColored(
            if node.attr_ids[i] in node.connected_ids
                MORESTYLE.Colors.NodeConnected
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
            end,
            node.attr_labels[i]
        )
        imnodes_EndInputAttribute()
    end
    CImGui.EndGroup()
    # inlens = lengthpr.(node.input_labels)
    # outlens = lengthpr.(node.output_labels)
    # contentlines = split(node.content, '\n')
    # contentls = lengthpr.(contentlines)
    # maxcontentline = argmax(contentls)
    # if true in (max_with_empty(inlens) + max_with_empty(outlens) .< [lengthpr(node.title), contentls[maxcontentline]])
    #     maxinlabel = isempty(node.input_labels) ? "" : node.input_labels[argmax(inlens)]
    #     maxoutlabel = isempty(node.output_labels) ? "" : node.output_labels[argmax(outlens)]
    #     spacing = if lengthpr(node.title) < contentls[maxcontentline]
    #         CImGui.CalcTextSize(contentlines[maxcontentline]).x - CImGui.CalcTextSize(maxinlabel).x - CImGui.CalcTextSize(maxoutlabel).x
    #     else
    #         CImGui.CalcTextSize(node.title).x - CImGui.CalcTextSize(maxinlabel).x - CImGui.CalcTextSize(maxoutlabel).x
    #     end
    #     CImGui.SameLine(0, max(spacing, 2CImGui.GetFontSize()))
    # else
    #     CImGui.SameLine(0, 2CImGui.GetFontSize())
    # end
    CImGui.SameLine()
    edit(node.imgr)
    CImGui.SameLine()
    CImGui.BeginGroup()
    for i in eachindex(node.attr_ids)
        node.attr_types[i] && (CImGui.Text(""); continue)
        imnodes_BeginOutputAttribute(node.attr_ids[i], MORESTYLE.PinShapes.output)
        CImGui.TextColored(
            if node.attr_ids[i] in node.connected_ids
                MORESTYLE.Colors.NodeConnected
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
            end,
            node.attr_labels[i]
        )
        imnodes_EndOutputAttribute()
    end
    CImGui.EndGroup()
    imnodes_EndNode()
    for pin in node.imgr.pins
        pin.linked = pin.link_idx in node.connected_ids .% 100 ? true : false
    end
end

let
    isanynodehovered::Bool = false
    isanylinkhovered::Bool = false
    newnode::Bool = false
    global function edit(nodeeditor::NodeEditor)
        !(isanynodehovered || isanylinkhovered) && CImGui.IsMouseDoubleClicked(0) && imnodes_EditorContextResetPanning((0, 0))
        imnodes_BeginNodeEditor()
        if CImGui.BeginPopup("NodeEditor")
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.CommonNode, " 通用节点"))
                nodeeditor.maxid += 1
                push!(nodeeditor.nodes, nodeeditor.maxid => Node(nodeeditor.maxid))
                imnodes_SetNodeScreenSpacePos(nodeeditor.maxid, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.GroundNode, " 接地头"))
                nodeeditor.maxid += 1
                push!(nodeeditor.nodes, nodeeditor.maxid => Node(nodeeditor.maxid, Val(:ground)))
                imnodes_SetNodeScreenSpacePos(nodeeditor.maxid, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.ResistanceNode, " 电阻"))
                nodeeditor.maxid += 1
                push!(nodeeditor.nodes, nodeeditor.maxid => Node(nodeeditor.maxid, Val(:resistance)))
                imnodes_SetNodeScreenSpacePos(nodeeditor.maxid, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.TrilinkNode, " 三通21"))
                nodeeditor.maxid += 1
                push!(nodeeditor.nodes, nodeeditor.maxid => Node(nodeeditor.maxid, Val(:trilink21)))
                imnodes_SetNodeScreenSpacePos(nodeeditor.maxid, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.TrilinkNode, " 三通12"))
                nodeeditor.maxid += 1
                push!(nodeeditor.nodes, nodeeditor.maxid => Node(nodeeditor.maxid, Val(:trilink12)))
                imnodes_SetNodeScreenSpacePos(nodeeditor.maxid, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.SampleBaseNode, " 样品座"))
                nodeeditor.maxid += 1
                push!(nodeeditor.nodes, nodeeditor.maxid => SampleBaseNode(nodeeditor.maxid))
                imnodes_SetNodeScreenSpacePos(nodeeditor.maxid, CImGui.GetMousePosOnOpeningCurrentPopup())
                newnode = true
            end
            for ins in keys(insconf)
                ins == "Others" && continue
                if CImGui.MenuItem(stcstr(insconf[ins].conf.icon, " ", ins))
                    nodeeditor.maxid += 1
                    push!(nodeeditor.nodes, nodeeditor.maxid => Node(nodeeditor.maxid, ins, Val(:instrument)))
                    imnodes_SetNodeScreenSpacePos(nodeeditor.maxid, CImGui.GetMousePosOnOpeningCurrentPopup())
                    newnode = true
                end
            end
            CImGui.EndPopup()
        end
        if CImGui.BeginPopup("Edit Node")
            hoverednode = nodeeditor.nodes[nodeeditor.hoverednode_id]
            if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Edit, " 编辑"))
                if hoverednode isa Node
                    @c InputTextRSZ("标题", &hoverednode.title)
                    linesnum = (1 + length(findall("\n", hoverednode.content)))
                    mtheigth = (linesnum > 6 ? 6 : linesnum) * CImGui.GetTextLineHeight() + 2unsafe_load(IMGUISTYLE.FramePadding.y)
                    @c InputTextMultilineRSZ("内容", &hoverednode.content, (Cfloat(0), mtheigth))
                    if CImGui.BeginPopupContextItem()
                        for ins in keys(INSTRBUFFERVIEWERS)
                            if !isempty(INSTRBUFFERVIEWERS[ins])
                                if CImGui.BeginMenu(ins)
                                    for addr in keys(INSTRBUFFERVIEWERS[ins])
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
                        if CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##input ", i))
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
                        if CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##Output ", i))
                            deleteat!(hoverednode.output_ids, i)
                            deleteat!(hoverednode.output_labels, i)
                            break
                        end
                    end
                    CImGui.EndGroup()
                    if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " 添加##Input"))
                        li = length(hoverednode.input_ids)
                        push!(hoverednode.input_ids, hoverednode.id * 1000 + li + 1)
                        push!(hoverednode.input_labels, "Input $(li+1)")
                    end
                    CImGui.SameLine(width)
                    if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " 添加##Output"))
                        lo = length(hoverednode.output_ids)
                        push!(hoverednode.output_ids, hoverednode.id * 1000 + 100 + lo + 1)
                        push!(hoverednode.output_labels, "Output $(lo+1)")
                    end
                elseif hoverednode isa SampleBaseNode
                    @c InputTextRSZ("标题", &hoverednode.title)
                    linesnum = (1 + length(findall("\n", hoverednode.content)))
                    mtheigth = (linesnum > 6 ? 6 : linesnum) * CImGui.GetTextLineHeight() + 2unsafe_load(IMGUISTYLE.FramePadding.y)
                    @c InputTextMultilineRSZ("内容", &hoverednode.content, (Cfloat(0), mtheigth))
                    CImGui.BeginGroup()
                    for i in eachindex(hoverednode.attr_ids)
                        attr_label = hoverednode.attr_labels[i]
                        @c InputTextRSZ(stcstr("Pin ", i), &attr_label)
                        hoverednode.attr_labels[i] = attr_label
                        CImGui.SameLine()
                        if CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##attr ", i))
                            deleteat!(hoverednode.attr_ids, i)
                            deleteat!(hoverednode.attr_labels, i)
                            deleteat!(hoverednode.attr_types, i)
                            break
                        end
                        CImGui.SameLine()
                        attr_type = hoverednode.attr_types[i]
                        if @c CImGui.Checkbox(stcstr("##IsInput", i), &attr_type)
                            hoverednode.attr_types[i] = attr_type
                            if hoverednode.attr_ids[i] in hoverednode.connected_ids
                                dellinks = Cint[]
                                for (j, link) in enumerate(nodeeditor.links)
                                    true in (link .== hoverednode.attr_ids[i]) && push!(dellinks, j)
                                end
                                deleteat!(nodeeditor.links, dellinks)
                            end
                        end
                    end
                    CImGui.EndGroup()
                    if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " 添加##Attr"))
                        li = length(hoverednode.attr_ids)
                        push!(hoverednode.attr_ids, hoverednode.id * 1000 + li + 1)
                        push!(hoverednode.attr_labels, "Pin $(li+1)")
                        push!(hoverednode.attr_types, true)
                    end
                end
                CImGui.EndMenu()
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " 删除"))
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
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " 删除"))
                deleteat!(nodeeditor.links, nodeeditor.hoveredlink_id)
            end
            CImGui.EndPopup()
        end
        if CImGui.IsMouseClicked(1)
            if imnodes_IsEditorHovered() && !isanynodehovered && !isanylinkhovered
                CImGui.OpenPopup("NodeEditor")
            elseif isanynodehovered
                hoverednode = nodeeditor.nodes[nodeeditor.hoverednode_id]
                if hoverednode isa Node || (hoverednode isa SampleBaseNode && !hoverednode.imgr.hovered)
                    CImGui.OpenPopup("Edit Node")
                end
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
    nodeeditor_contexts::Dict{String,Ptr{LibCImGui.EditorContext}} = Dict()
    global function edit(nodeeditor::NodeEditor, id, p_open::Ref{Bool})
        CImGui.SetNextWindowSize((1200, 600), CImGui.ImGuiCond_Once)
        CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, unsafe_load(IMGUISTYLE.PopupRounding))
        isfocus = true
        if CImGui.Begin(id, p_open, CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking)
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, MORESTYLE.Icons.Circuit)
            CImGui.SameLine()
            CImGui.Text(" 电路")
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
            @c CImGui.Checkbox("HOLD", &hold)
            holdsz = CImGui.GetItemRectSize().x
            haskey(nodeeditor_contexts, id) || push!(nodeeditor_contexts, id => imnodes_EditorContextCreate())
            imnodes_EditorContextSet(nodeeditor_contexts[id])
            edit(nodeeditor)
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        CImGui.End()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
        p_open[] &= (isfocus | hold)
    end
end

### view ###------------------------------------------------------------------------------------------------------------
view(node::Node) = edit(node)

view(pin::ImagePin) = (draw(pin); pin.dragging_in = false)

function view(imgr::ImageRegion)
    CImGui.Image(Ptr{Cvoid}(imgr.id), imgr.posmax .- imgr.posmin)
    imgr.posmin = CImGui.GetItemRectMin()
    imgr.posmax = CImGui.GetItemRectMax()
    imgr.rszgrip.pos = imgr.posmax
    update_state!(imgr)
    for pin in imgr.pins
        view(pin)
    end
    draw(imgr.rszgrip)
end

function view(node::SampleBaseNode)
    imnodes_BeginNode(node.id)
    imnodes_BeginNodeTitleBar()
    CImGui.Text(node.title)
    imnodes_EndNodeTitleBar()
    CImGui.Text(node.content)
    CImGui.BeginGroup()
    for i in eachindex(node.attr_ids)
        node.attr_types[i] || (CImGui.Text(""); continue)
        imnodes_BeginInputAttribute(node.attr_ids[i], MORESTYLE.PinShapes.input)
        CImGui.TextColored(
            if node.attr_ids[i] in node.connected_ids
                MORESTYLE.Colors.NodeConnected
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
            end,
            node.attr_labels[i]
        )
        imnodes_EndInputAttribute()
    end
    CImGui.EndGroup()
    # inlens = lengthpr.(node.input_labels)
    # outlens = lengthpr.(node.output_labels)
    # contentlines = split(node.content, '\n')
    # contentls = lengthpr.(contentlines)
    # maxcontentline = argmax(contentls)
    # if true in (max_with_empty(inlens) + max_with_empty(outlens) .< [lengthpr(node.title), contentls[maxcontentline]])
    #     maxinlabel = isempty(node.input_labels) ? "" : node.input_labels[argmax(inlens)]
    #     maxoutlabel = isempty(node.output_labels) ? "" : node.output_labels[argmax(outlens)]
    #     spacing = if lengthpr(node.title) < contentls[maxcontentline]
    #         CImGui.CalcTextSize(contentlines[maxcontentline]).x - CImGui.CalcTextSize(maxinlabel).x - CImGui.CalcTextSize(maxoutlabel).x
    #     else
    #         CImGui.CalcTextSize(node.title).x - CImGui.CalcTextSize(maxinlabel).x - CImGui.CalcTextSize(maxoutlabel).x
    #     end
    #     CImGui.SameLine(0, max(spacing, 2CImGui.GetFontSize()))
    # else
    #     CImGui.SameLine(0, 2CImGui.GetFontSize())
    # end
    CImGui.SameLine()
    view(node.imgr)
    CImGui.SameLine()
    CImGui.BeginGroup()
    for i in eachindex(node.attr_ids)
        node.attr_types[i] && (CImGui.Text(""); continue)
        imnodes_BeginOutputAttribute(node.attr_ids[i], MORESTYLE.PinShapes.output)
        CImGui.TextColored(
            if node.attr_ids[i] in node.connected_ids
                MORESTYLE.Colors.NodeConnected
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
            end,
            node.attr_labels[i]
        )
        imnodes_EndOutputAttribute()
    end
    CImGui.EndGroup()
    imnodes_EndNode()
    for pin in node.imgr.pins
        pin.linked = pin.link_idx in node.connected_ids .% 100 ? true : false
    end
end

let
    # isanynodehovered_list::Dict{String,Bool} = Dict()
    # isanylinkhovered_list::Dict{String,Bool} = Dict()
    nodeeditor_contexts::Dict{String,Ptr{LibCImGui.EditorContext}} = Dict()
    global function view(nodeeditor::NodeEditor, id)
        haskey(nodeeditor_contexts, id) || push!(nodeeditor_contexts, id => imnodes_EditorContextCreate())
        # haskey(isanynodehovered_list, id) || push!(isanynodehovered_list, id => false)
        # haskey(isanylinkhovered_list, id) || push!(isanylinkhovered_list, id => false)
        imnodes_EditorContextSet(nodeeditor_contexts[id])
        # !(isanynodehovered_list[id] || isanylinkhovered_list[id]) && CImGui.IsMouseDoubleClicked(0) &&
        # imnodes_EditorContextResetPanning((0, 0))
        imnodes_BeginNodeEditor()
        for (id, node) in nodeeditor.nodes
            imnodes_SetNodeGridSpacePos(id, node.position)
            view(node)
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
        # isanynodehovered_list[id] = @c imnodes_IsNodeHovered(&nodeeditor.hoverednode_id)
        # isanylinkhovered_list[id] = @c imnodes_IsLinkHovered(&nodeeditor.hoveredlink_id)
    end
end

# function auxid(nodeeditor::NodeEditor, auxid)
#     auxnodeeditor = deepcopy(nodeeditor)
#     nodebuf = OrderedDict()
#     for (_, node) in auxnodeeditor.nodes
#         node.id += auxid * 1000
#         if node isa Node
#             node.input_ids .+= auxid * 1000000
#             node.output_ids .+= auxid * 1000000
#         elseif node isa ImageNode
#             node.attr_ids .+= auxid * 1000000
#         end
#         node.connected_ids = Set(@. node.connected_ids + auxid * 1000000)
#         push!(nodebuf, node.id => node)
#     end
#     empty!(auxnodeeditor.nodes)
#     for idnode in nodebuf
#         push!(auxnodeeditor.nodes, idnode)
#     end
#     for i in eachindex(auxnodeeditor.links)
#         auxnodeeditor.links[i] = auxnodeeditor.links[i] .+ auxid * 1000000
#     end
#     return auxnodeeditor
# end

### Patch ###-----------------------------------------------------------------------------------------------------------
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Vector{Node}) = OrderedDict(node.id => node for node in nodes)
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Type{OrderedDict{Cint,Node}}) = OrderedDict{Cint,AbstractNode}(node.id => node for node in nodes)