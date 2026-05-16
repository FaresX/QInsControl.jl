function ShowHelpMarker(desc)
    CImGui.TextDisabled("(?)")
    if CImGui.IsItemHovered()
        CImGui.BeginTooltip()
        CImGui.PushTextWrapPos(CImGui.GetFontSize() * 36.0)
        CImGui.TextUnformatted(desc)
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
end

function ShowUnit(id, utype, ui::Ref{Int}, flags=CImGui.ImGuiComboFlags_NoArrowButton)
    Us = string.(haskey(CONF.U, utype) ? CONF.U[utype] : [""])
    (ui[] > length(Us) || ui[] < 1) && (ui[] = 1)
    U = Us[ui[]]
    begincombo = CImGui.BeginCombo(stcstr("##unit", id), U, flags)
    if begincombo
        for u in eachindex(Us)
            local selected = ui[] == u
            CImGui.Selectable(Us[u], selected) && (ui[] = u)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    return begincombo
end

function YesNoDialog(id, msg, flags=0)::Bool
    retval = false
    if CImGui.BeginPopupModal(id, C_NULL, flags)
        CImGui.TextColored(MORESTYLE.Colors.ErrorText, string("\n", msg, "\n\n"))
        CImGui.Button(mlstr("Confirm")) && (CImGui.CloseCurrentPopup(); retval = true)
        CImGui.SameLine(240)
        CImGui.Button(mlstr("Cancel")) && CImGui.CloseCurrentPopup()
        CImGui.EndPopup()
    end
    return retval
end

function TextRect(
    str, update=false;
    size=(0, 0),
    nochild=false,
    bdrounding=MORESTYLE.Variables.TextRectRounding,
    thickness=MORESTYLE.Variables.TextRectThickness,
    padding=MORESTYLE.Variables.TextRectPadding,
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
)
    draw_list = CImGui.GetWindowDrawList()
    availwidth = CImGui.GetContentRegionAvail().x
    nochild || CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ padding)
    nochild || CImGui.BeginChild("TextRect", size .- 2padding, ImGuiChildFlags_None)
    CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ padding .+ thickness)
    CImGui.PushTextWrapPos(nochild ? availwidth - padding[1] : 0)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.TextUnformatted(str)
    CImGui.PopStyleColor()
    CImGui.PopTextWrapPos()
    nochild || (update && CImGui.SetScrollHereY(1))
    nochild || CImGui.EndChild()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    nochild && ColoredButton(""; size=(Cfloat(0), thickness + padding[2]), colbt=[0, 0, 0, 0], colbth=[0, 0, 0, 0], colbta=[0, 0, 0, 0])
    recta = nochild ? rmin .- padding : rmin .- padding .+ thickness
    rectb = nochild ? CImGui.ImVec2(rmin.x + availwidth .- 2padding[1] .- 2thickness, rmax.y + padding[2]) : rmax .+ padding .- thickness
    CImGui.AddRect(
        draw_list,
        recta, rectb,
        MORESTYLE.Colors.ShowTextRect,
        bdrounding,
        0,
        thickness
    )
    recta, rectb
end

function ItemTooltip(tipstr, wrappos=36CImGui.GetFontSize())
    if CImGui.IsItemHovered()
        CImGui.BeginTooltip()
        CImGui.PushTextWrapPos(wrappos)
        CImGui.TextUnformatted(tipstr)
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
end

function ItemTooltipNoHovered(tipstr, wrappos=36CImGui.GetFontSize())
    CImGui.BeginTooltip()
    CImGui.PushTextWrapPos(wrappos)
    CImGui.TextUnformatted(tipstr)
    CImGui.PopTextWrapPos()
    CImGui.EndTooltip()
end

function SeparatorTextColored(col, label)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, col)
    igSeparatorText(label)
    CImGui.PopStyleColor()
end

function BoxTextColored(
    label;
    size=(0, 0),
    col=CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_Text),
    colbd=MORESTYLE.Colors.ItemBorder
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, colbd)
    CImGui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1)
    ColoredButton(label; size=size, colbt=[0, 0, 0, 0], colbth=[0, 0, 0, 0], colbta=[0, 0, 0, 0], coltxt=col)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end

@kwdef mutable struct ResizeChild
    posmin::CImGui.ImVec2 = (0, 0)
    posmax::CImGui.ImVec2 = (200, 400)
    rszgripsize::Cfloat = 24
    limminsize::CImGui.ImVec2 = (0, 0)
    limmaxsize::CImGui.ImVec2 = (Inf, Inf)
    hovered::Bool = false
    dragging::Bool = false
end

function (rszcd::ResizeChild)(f, id, args...; kwargs...)
    CImGui.BeginChild(id, rszcd.posmax .- rszcd.posmin, true)
    f(args...; kwargs...)
    CImGui.EndChild()
    CImGui.AddTriangleFilled(
        CImGui.GetWindowDrawList(),
        (rszcd.posmax.x - rszcd.rszgripsize, rszcd.posmax.y), rszcd.posmax, (rszcd.posmax.x, rszcd.posmax.y - rszcd.rszgripsize),
        if rszcd.hovered && rszcd.dragging
            CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGripActive)
        elseif rszcd.hovered
            CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGripHovered)
        else
            CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGrip)
        end
    )
    rszcd.posmin = CImGui.GetItemRectMin()
    rszcd.posmax = CImGui.GetItemRectMax()
    mspos = CImGui.GetMousePos()
    rszcd.hovered = inregion(mspos, rszcd.posmax .- rszcd.rszgripsize, rszcd.posmax)
    rszcd.hovered &= -(mspos.x - rszcd.posmax.x + rszcd.rszgripsize) < mspos.y - rszcd.posmax.y
    if rszcd.dragging
        if CImGui.IsMouseDown(0)
            rszcd.posmax = cutoff(mspos, rszcd.posmin .+ rszcd.limminsize, rszcd.posmin .+ rszcd.limmaxsize) .+ rszcd.rszgripsize ./ 4
        else
            rszcd.dragging = false
        end
    else
        rszcd.hovered && CImGui.IsMouseDown(0) && CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) < 0.1 && (rszcd.dragging = true)
    end
end

@kwdef mutable struct AnimateChild
    presentsize::CImGui.ImVec2 = (0, 0)
    targetsize::CImGui.ImVec2 = (400, 600)
    rate::CImGui.ImVec2 = (4, 6)
end

function (acd::AnimateChild)(f, id, border, flags, args...; kwargs...)
    CImGui.BeginChild(id, acd.presentsize, border, flags)
    f(args...; kwargs...)
    CImGui.EndChild()
    acd.presentsize = CImGui.GetItemRectSize()
    if all(acd.presentsize .== acd.targetsize)
    else
        rate = sign.(acd.targetsize .- acd.presentsize) .* abs.(acd.rate)
        gap = abs.(acd.presentsize .- acd.targetsize)
        newsize = acd.presentsize .+ rate
        acd.presentsize = (
            gap[1] < abs(acd.rate[1]) ? acd.targetsize[1] : newsize[1],
            gap[2] < abs(acd.rate[2]) ? acd.targetsize[2] : newsize[2]
        )
    end
end

@kwdef mutable struct DragPoint
    pos::Vector{Cfloat} = [0, 0]
    limmin::Vector{Cfloat} = [0, 0]
    limmax::Vector{Cfloat} = [Inf, Inf]
    radius::Cfloat = 6
    segments::Cint = 12
    col::Vector{Cfloat} = [1, 1, 1, 0.6]
    colh::Vector{Cfloat} = [1, 1, 1, 1]
    cola::Vector{Cfloat} = [0, 1, 0, 1]
    hovered::Bool = false
    dragging::Bool = false
end

function draw(dp::DragPoint)
    CImGui.AddCircleFilled(
        CImGui.GetWindowDrawList(), dp.pos, dp.radius,
        dp.dragging ? dp.cola : dp.hovered ? dp.colh : dp.col
    )
end

function update_state!(dp::DragPoint)
    mspos = CImGui.GetMousePos()
    dp.hovered = sum(abs2.(mspos .- dp.pos)) < abs2(dp.radius)
    if dp.dragging
        CImGui.IsMouseDown(0) ? dp.pos = cutoff(mspos, dp.limmin, dp.limmax) : dp.dragging = false
    else
        dp.hovered && CImGui.IsMouseDown(0) && CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) < 0.1 && (dp.dragging = true)
    end
end

function edit(dp::DragPoint)
    update_state!(dp)
    draw(dp)
end

@kwdef mutable struct DragRect
    posmin::Vector{Cfloat} = [0, 0]
    posmax::Vector{Cfloat} = [100, 100]
    dragpos::Vector{Cfloat} = [0, 0]
    rszgripsize::Cfloat = 24
    limmin::Vector{Cfloat} = [0, 0]
    limmax::Vector{Cfloat} = [Inf, Inf]
    limminsize::Vector{Cfloat} = [0, 0]
    limmaxsize::Vector{Cfloat} = [Inf, Inf]
    scale::Cfloat = 1
    rounding::Cfloat = 0
    bdrounding::Cfloat = 0
    thickness::Cfloat = 2
    col::Vector{Cfloat} = [1, 1, 1, 0.6]
    colh::Vector{Cfloat} = [1, 1, 1, 1]
    cola::Vector{Cfloat} = [0, 1, 0, 1]
    colbd::Vector{Cfloat} = [0, 0, 0, 1]
    colbdh::Vector{Cfloat} = [0, 0, 0, 1]
    colbda::Vector{Cfloat} = [0, 0, 0, 1]
    hovered::Bool = false
    dragging::Bool = false
    griphovered::Bool = false
    gripdragging::Bool = false
end
function pushscale!(dr::DragRect)
    # dr.posmin .*= dr.scale
    dr.posmax .= dr.posmin .+ (dr.posmax .- dr.posmin) * dr.scale
    dr.dragpos .*= dr.scale
    dr.rszgripsize *= dr.scale
    dr.limmin .*= dr.scale
    dr.limmax .*= dr.scale
    dr.limminsize .*= dr.scale
    dr.limmaxsize .*= dr.scale
    dr.rounding *= dr.scale
    dr.bdrounding *= dr.scale
    dr.thickness *= dr.scale
end
function endscale!(dr::DragRect)
    # dr.posmin ./= dr.scale
    dr.posmax .= dr.posmin .+ (dr.posmax .- dr.posmin) / dr.scale
    dr.dragpos ./= dr.scale
    dr.rszgripsize /= dr.scale
    dr.limmin ./= dr.scale
    dr.limmax ./= dr.scale
    dr.limminsize ./= dr.scale
    dr.limmaxsize ./= dr.scale
    dr.rounding /= dr.scale
    dr.bdrounding /= dr.scale
    dr.thickness /= dr.scale
end

function draw(dr::DragRect)
    drawlist = CImGui.GetWindowDrawList()
    CImGui.AddRectFilled(
        drawlist, dr.posmin, dr.posmax,
        dr.dragging ? dr.cola : dr.hovered && !dr.griphovered && !dr.gripdragging ? dr.colh : dr.col,
        dr.rounding
    )
    CImGui.AddTriangleFilled(
        drawlist,
        (dr.posmax[1] - dr.rszgripsize, dr.posmax[2]), dr.posmax, (dr.posmax[1], dr.posmax[2] - dr.rszgripsize),
        CImGui.c_get(
            IMGUISTYLE.Colors,
            dr.gripdragging ? ImGuiCol_ResizeGripActive : dr.griphovered ? ImGuiCol_ResizeGripHovered : ImGuiCol_ResizeGrip
        )
    )
    CImGui.AddRect(
        drawlist, dr.posmin, dr.posmax,
        dr.dragging ? dr.colbda : dr.hovered && !dr.griphovered && !dr.gripdragging ? dr.colbdh : dr.colbd,
        dr.bdrounding, ImDrawFlags_RoundCornersAll, dr.thickness
    )
end

function update_state!(dr::DragRect)
    mspos = CImGui.GetMousePos()
    dr.griphovered = inregion(mspos, dr.posmax .- dr.rszgripsize, dr.posmax)
    dr.griphovered &= -(mspos.x - dr.posmax[1] + dr.rszgripsize) < mspos.y - dr.posmax[2]
    dr.hovered = inregion(mspos, dr.posmin, dr.posmax)
    if dr.gripdragging
        if CImGui.IsMouseDown(0)
            if CImGui.IsMouseDragging(0)
                dr.posmax = cutoff(mspos, dr.posmin .+ dr.limminsize, dr.posmin .+ dr.limmaxsize) .+ dr.rszgripsize ./ 4
            end
        else
            dr.gripdragging = false
        end
    else
        dr.griphovered && !dr.dragging && CImGui.IsMouseDown(0) && CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) < 0.1 && (dr.gripdragging = true)
    end
    if dr.dragging
        if CImGui.IsMouseDown(0)
            drsize = dr.posmax .- dr.posmin
            dr.posmin = cutoff(mspos .- dr.dragpos, dr.limmin, dr.limmax .- drsize)
            dr.posmax = dr.posmin .+ drsize
        else
            dr.dragging = false
        end
    else
        if dr.hovered && !dr.gripdragging && CImGui.IsMouseDown(0) && CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) < 0.1
            dr.dragging = true
            dr.dragpos = mspos .- dr.posmin
        end
    end
end

function edit(dr::DragRect)
    pushscale!(dr)
    update_state!(dr)
    draw(dr)
    endscale!(dr)
end

let
    framecount::Cint = 0
    global function SetWindowBgImage(
        path=CONF.BGImage.main.path;
        rate=CONF.BGImage.main.rate, use=CONF.BGImage.main.use, tint_col=MORESTYLE.Colors.BgImageTint
    )
        if use
            wpos = CImGui.GetWindowPos()
            wsz = CImGui.GetWindowSize()
            haskey(IMAGES, path) || createimage(path; showsize=wsz)
            if length(IMAGES[path]) > 1 && framecount != CImGui.GetFrameCount()
                framecount = CImGui.GetFrameCount()
                framecount % rate == 0 && move!(IMAGES[path])
            end
            CImGui.AddImage(
                CImGui.GetWindowDrawList(), IMAGES[path][], wpos, wpos .+ wsz, (0, 0), (1, 1),
                tint_col
            )
        end
    end
end

let
    states::Dict{String,Bool} = Dict()
    global function CopyableText(label, text; size=(0, 0))
        haskey(states, label) || (states[label] = false)
        if states[label]
            CImGui.InputTextMultiline(
                label, text, length(text), size, CImGui.ImGuiInputTextFlags_ReadOnly
            )
            !CImGui.IsItemHovered() && CImGui.IsAnyMouseDown() && (states[label] = false)
        else
            CImGui.TextUnformatted(text)
            CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (states[label] = true)
        end
    end
end