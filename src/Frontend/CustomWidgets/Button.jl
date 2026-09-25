# function MultiSelectable(
#     rightclickmenu,
#     id,
#     labels,
#     states,
#     n,
#     idxing=Ref(1),
#     size=(Cfloat(0), CImGui.GetFrameHeight() * ceil(Int, length(labels) / n));
#     border=false,
#     selectableflags=0,
#     selectablesize=(0, 0)
# )
#     l = length(labels)
#     length(states) == l || resize!(states, l)
#     size = l == 0 ? (Cfloat(0), CImGui.GetFrameHeightWithSpacing()) : size
#     CImGui.BeginChild(stcstr("MultiSelectable##", id), size, border)
#     CImGui.Columns(n, C_NULL, false)
#     for i in 1:l
#         if i == 1
#             ccpos = CImGui.GetCursorScreenPos()
#             CImGui.SetCursorScreenPos(ccpos.x, ccpos.y + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2)
#         end
#         CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
#         CImGui.Selectable(labels[i], states[i], selectableflags, selectablesize) && (states[i] ⊻= true)
#         CImGui.PopStyleVar()
#         i == l || CImGui.Spacing()
#         rightclickmenu() && (idxing[] = i)
#         CImGui.NextColumn()
#     end
#     CImGui.EndChild()
# end

function DragMultiSelectable(
    rightclickmenu, id, labels, states, n, idxing, args...;
    action=(si, ti, args...) -> (),
    size=(Cfloat(0), CImGui.GetFrameHeight() * ceil(Int, length(labels) / n)),
    border=false,
    selectableflags=0,
    selectablesize=(0, 0)
)
    l = length(labels)
    length(states) == l || resize!(states, l)
    size = l == 0 ? (Cfloat(0), CImGui.GetFrameHeightWithSpacing()) : size
    CImGui.BeginChild(stcstr("DragMultiS##", id), size, border)
    CImGui.Columns(n, C_NULL, false)
    for i in 1:l
        if i == 1
            ccpos = CImGui.GetCursorScreenPos()
            CImGui.SetCursorScreenPos(ccpos.x, ccpos.y + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2)
        end
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
        CImGui.Selectable(labels[i], states[i], selectableflags, selectablesize) && (states[i] ⊻= true)
        CImGui.PopStyleVar()
        i == l || CImGui.Spacing()
        rightclickmenu() && (idxing[] = i)
        CImGui.Indent()
        if CImGui.BeginDragDropSource()
            @c CImGui.SetDragDropPayload(stcstr("DragMultiS##", id), &i, sizeof(Cint))
            CImGui.Text(replace(labels[i], r"##.*" => ""))
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload(stcstr("DragMultiS##", id))
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                i == payload_i || action(payload_i, i, args...)
            end
            CImGui.EndDragDropTarget()
        end
        CImGui.Unindent()
        CImGui.NextColumn()
    end
    CImGui.EndChild()
end

function RenameSelectable(
    str_id, isrename::Ref{Bool}, label::Ref, selected::Bool, flags=0, size1=(0, 0);
    size2=(0, 0), fixedlabel=""
)
    trig = false
    if isrename[]
        size2[2] > 0 && CImGui.PushStyleVar(
            CImGui.ImGuiStyleVar_FramePadding,
            (unsafe_load(IMGUISTYLE.FramePadding.x), (size2[2] - CImGui.GetFontSize()) / 2)
        )
        CImGui.PushItemWidth(size2[1])
        InputTextRSZ(str_id, label)
        CImGui.PopItemWidth()
        size2[2] > 0 && CImGui.PopStyleVar()
        CImGui.IsItemDeactivated() && (isrename[] = false)
    else
        trig = CImGui.Selectable(stcstr(fixedlabel, label[]), selected, flags, size1)
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (isrename[] = true)
    end
    trig
end

const IMAGES::Dict{String,LoopVector{CImGui.ImTextureRef}} = Dict()

let
    framecount::Cint = 0
    global function Image(path; size=(100, 100), rate=1, uv0=(0, 0), uv1=(1, 1), bg_col=[0, 0, 0, 0], tint_col=[1, 1, 1, 1])
        haskey(IMAGES, path) || createimage(path; showsize=size)
        if length(IMAGES[path]) > 1 && framecount != CImGui.GetFrameCount()
            framecount = CImGui.GetFrameCount()
            framecount % rate == 0 && move!(IMAGES[path])
        end
        CImGui.ImageWithBg(IMAGES[path][], size, uv0, uv1, bg_col, tint_col)
    end
end

function destroyimage!(path)
    if haskey(IMAGES, path) && !isempty(IMAGES[path].data)
        for id in IMAGES[path].data
            destroytexture!(id)
        end
        delete!(IMAGES, path)
    end
end

function createimage(path; showsize=(100, 100))
    destroyimage!(path)
    IMAGES[path] = LoopVector(CImGui.ImTextureRef[])
    if isfile(path)
        try
            imgload = FileIO.load(path)
            if ndims(imgload) == 2
                img = RGBA.(collect(transpose(imgload)))
                imgsize = size(img)
                push!(IMAGES[path], CImGui.create_image_texture(imgsize...))
                CImGui.update_image_texture(IMAGES[path][], img, imgsize...)
            elseif ndims(imgload) == 3
                imgs = permutedims(RGBA.(imgload), (2, 1, 3))
                imgsize = size(imgs)[1:2]
                for img in eachslice(imgs; dims=3)
                    push!(IMAGES[path], CImGui.create_image_texture(imgsize...))
                    CImGui.update_image_texture(IMAGES[path].data[end], img, imgsize...)
                end
            else
                push!(IMAGES[path], CImGui.create_image_texture(showsize...))
            end
        catch e
            @error "[$(now())]\n$(mlstr("loading image failed!!!"))" exception = e
            push!(IMAGES[path], CImGui.create_image_texture(showsize...))
        end
    else
        push!(IMAGES[path], CImGui.create_image_texture(showsize...))
    end
end

let
    framecount::Cint = 0
    global function ImageButton(label, path; size=(40, 40), rate=1, frame_padding=(6, 6), uv0=(0, 0), uv1=(1, 1), bg_col=[0, 0, 0, 0], tint_col=[1, 1, 1, 1])
        haskey(IMAGES, path) || createimage(path; showsize=size)
        if length(IMAGES[path]) > 1 && framecount != CImGui.GetFrameCount()
            framecount = CImGui.GetFrameCount()
            framecount % rate == 0 && move!(IMAGES[path])
        end
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, frame_padding)
        clicked = CImGui.ImageButton(label, IMAGES[path][], size .- 2 .* frame_padding, uv0, uv1, bg_col, tint_col)
        CImGui.PopStyleVar()
        return clicked
    end
end

function ColoredButton(
    label::AbstractString;
    size=(0, 0),
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
)
    # 现代感:自绘按钮 — InvisibleButton 承担交互/ID/布局,背景为单色圆角矩形 +
    # Fluent 风格底部内侧深色边(整个按钮以暗色重绘、裁剪只留底部条:有深度暗示、
    # 无上下分割线;圆角轮廓与底色完全一致),hover 提亮、按压用 active 色
    text = String(split(label, "##"; limit = 2)[1])
    tsz = CImGui.CalcTextSize(text)
    fp = unsafe_load(IMGUISTYLE.FramePadding)
    w = Cfloat(size[1] > 0 ? size[1] : tsz.x + 2fp.x)
    h = Cfloat(size[2] > 0 ? size[2] : tsz.y + 2fp.y)
    w = max(w, 1f0)  # InvisibleButton 断言尺寸非零(FramePadding=0 时纯 "##" 标签会算出 0)
    h = max(h, 1f0)
    rounding = unsafe_load(IMGUISTYLE.FrameRounding)
    clicked = CImGui.InvisibleButton(label, (w, h))
    hovered = CImGui.IsItemHovered()
    active = CImGui.IsItemActive()
    base = active ? colbta : hovered ? colbth : colbt
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    dl = CImGui.GetWindowDrawList()
    CImGui.AddRectFilled(dl, rmin, rmax, base, rounding)
    e = 2f0 * CImGui.GetWindowDpiScale()
    CImGui.PushClipRect(dl, (rmin.x, rmax.y - e), rmax)
    CImGui.AddRectFilled(dl, rmin, rmax, darkencolor(base, 0.16), rounding)
    CImGui.PopClipRect(dl)
    if !isempty(text)
        tx = (rmin.x + rmax.x - tsz.x) * 0.5f0
        ty = (rmin.y + rmax.y - tsz.y) * 0.5f0
        CImGui.PushClipRect(dl, rmin, rmax)
        CImGui.AddText(dl, (tx, ty), CImGui.ColorConvertFloat4ToU32(coltxt), text)
        CImGui.PopClipRect(dl)
    end
    return clicked
end

function ColoredButtonRect(
    label;
    size=(0, 0),
    rounding=unsafe_load(IMGUISTYLE.FrameRounding),
    bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
    thickness=0,
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=(0, 0, 0, 0)
)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    clicked = ColoredButton(label; size=size, colbt=colbt, colbth=colbth, colbta=colbta, coltxt=coltxt)
    CImGui.PopStyleVar()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, thickness)
    return clicked
end

function ImageButtonRect(
    label, path;
    size=(40, 40),
    uv0=(0, 0),
    uv1=(1, 1),
    rate=1,
    frame_padding=(6, 6),
    bg_col=[0, 0, 0, 0],
    tint_col=[1, 1, 1, 1],
    rounding=unsafe_load(IMGUISTYLE.FrameRounding),
    bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
    thickness=0,
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    colrect=(0, 0, 0, 0)
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Button, colbt)
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, colbth)
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, colbta)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    clicked = ImageButton(label, path; size=size, rate=rate, frame_padding=frame_padding, uv0=uv0, uv1=uv1, bg_col=bg_col, tint_col=tint_col)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor(3)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, thickness)
    return clicked
end

function ImageColoredButtonRect(
    label, path, useimage=false;
    size=(40, 40),
    rate=1,
    uv0=(0, 0),
    uv1=(1, 1),
    frame_padding=(6, 6),
    rounding=unsafe_load(IMGUISTYLE.FrameRounding),
    bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
    thickness=0,
    bg_col=[0, 0, 0, 0],
    tint_col=[1, 1, 1, 1],
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=(0, 0, 0, 0)
)
    return if useimage
        ImageButtonRect(
            label, path;
            size=size, rate=rate, frame_padding=frame_padding, uv0=uv0, uv1=uv1, bg_col=bg_col, tint_col=tint_col,
            rounding=rounding, bdrounding=bdrounding, thickness=thickness,
            colbt=colbt, colbth=colbth, colbta=colbta, colrect=colrect
        )
    else
        ColoredButtonRect(
            label;
            size=size, rounding=rounding, bdrounding=bdrounding, thickness=thickness,
            colbt=colbt, colbth=colbth, colbta=colbta, coltxt=coltxt, colrect=colrect
        )
    end
end

function ToggleButton(
    label::AbstractString,
    v::Ref{Bool};
    size=(0, 0),
    colon=MORESTYLE.Colors.ToggleButtonOn,
    coloff=MORESTYLE.Colors.ToggleButtonOff,
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
)
    toggled = ColoredButton(label; size=size, colbt=v[] ? colon : coloff, colbth=colbth, colbta=colbta, coltxt=coltxt)
    toggled && (v[] ⊻= true)
    return toggled
end

function ToggleButtonRect(
    label,
    v::Ref{Bool};
    size=(0, 0),
    rounding=unsafe_load(IMGUISTYLE.FrameRounding),
    bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
    thickness=1.0,
    colon=MORESTYLE.Colors.ToggleButtonOn,
    coloff=MORESTYLE.Colors.ToggleButtonOff,
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=(0, 0, 0, 0)
)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    toggled = ToggleButton(label, v; size=size, colon=colon, coloff=coloff, colbth=colbth, colbta=colbta, coltxt=coltxt)
    CImGui.PopStyleVar()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, thickness)
    return toggled
end

function ColoredRadioButton(
    label, v::Ref, v_button::Integer;
    bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
    thickness=0,
    colckm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_CheckMark),
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colfrmh=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgHovered),
    colfrma=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=(0, 0, 0, 0)
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_CheckMark, colckm)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colfrm)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgHovered, colfrmh)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgActive, colfrma)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    clicked = CImGui.RadioButton(label, v, v_button)
    CImGui.PopStyleColor(5)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, thickness)
    return clicked
end

function ColoredProgressBarRect(
    fraction, label;
    size=(0, 0),
    rounding=unsafe_load(IMGUISTYLE.FrameRounding),
    bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
    thickness=0,
    colbar=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colbara=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PlotHistogram),
    colbara2=(0, 0, 0, 0),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=(0, 0, 0, 0)
)
    draw_list = CImGui.GetWindowDrawList()
    if colbara2 != (0, 0, 0, 0)
        # —— 自绘路径:底色 + 渐变填充 + 单次居中文字 ——
        # 不能叠加在 ProgressBar 之上:渐变会盖住其自绘文字,重绘文字又会与原生两段式
        # 文字渲染(填充区/非填充区)错位重叠,故渐变启用时整条自绘。
        # 注意 ImVec2 与元组广播的结果是 Vector{Float32},没有 .x/.y 字段,必须用下标
        # 负宽度沿用 ImGui 惯例 = 剩余宽度 + size;用 avail 而非 CalcItemWidth,
        # 后者受 ItemWidth 栈残留影响,会让进度条与任务行(满宽 Selectable)不等长
        w = Cfloat(size[1] > 0 ? size[1] : CImGui.GetContentRegionAvail().x + size[1])
        hgt = Cfloat(size[2] > 0 ? size[2] : CImGui.GetFrameHeight())
        rmin = CImGui.GetCursorScreenPos()
        rmax = (rmin.x + w, rmin.y + hgt)
        CImGui.Dummy((w, hgt))
        CImGui.AddRectFilled(draw_list, rmin, rmax, colbar, rounding)
        if fraction > 0
            gradientfill(
                draw_list, rmin, (rmin.x + Cfloat(fraction) * w, rmax[2]),
                colbara, colbara2; dir = :h
            )
        end
        CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, thickness)
        if !isempty(label)
            tsz = CImGui.CalcTextSize(label)
            # 文字比条宽时左对齐(与 ImGui RenderTextClipped 行为一致),否则水平居中
            tx = tsz.x >= w ? rmin.x : (rmin.x + rmax[1] - tsz.x) * 0.5f0
            ty = (rmin.y + rmax[2] - tsz.y) * 0.5f0
            CImGui.PushClipRect(draw_list, rmin, rmax)
            CImGui.AddText(draw_list, (tx, ty), CImGui.ColorConvertFloat4ToU32(coltxt), label)
            CImGui.PopClipRect(draw_list)
        end
        return false
    end
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colbar)
    CImGui.PushStyleColor(CImGui.ImGuiCol_PlotHistogram, colbara)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    CImGui.ProgressBar(fraction, size, label)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor(3)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, thickness)
    return false
end

function RadioButton2(label1, label2, v::Ref{Bool}; local_pos_x=0, spacing_w=-1)
    trig1 = CImGui.RadioButton(label1, v[])
    CImGui.SameLine(local_pos_x, spacing_w)
    trig2 = CImGui.RadioButton(label2, !v[])
    trig1 && (v[] = true)
    trig2 && (v[] = false)
    return trig1 || trig2
end
