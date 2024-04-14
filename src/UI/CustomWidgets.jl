function ComboS(label, preview_value::Ref, item_list, flags=0)
    iscombo = CImGui.BeginCombo(label, preview_value.x, flags)
    isselect = false
    if iscombo
        for item in item_list
            selected = preview_value.x == item
            CImGui.Selectable(item, selected) && (preview_value.x = item; isselect = true)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    iscombo && isselect
end

let
    filterlist::Dict{String,Ref{String}} = Dict()
    global function ComboSFiltered(label, preview_value::Ref, item_list, flags=0)
        iscombo = CImGui.BeginCombo(label, preview_value.x, flags)
        isselect = false
        if iscombo
            haskey(filterlist, label) || (filterlist[label] = "")
            InputTextWithHintRSZ(stcstr(label, "##hide"), mlstr("Filter"), filterlist[label])
            for item in item_list
                filter = filterlist[label][]
                (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(item))) || continue
                selected = preview_value.x == item
                CImGui.Selectable(item, selected) && (preview_value.x = item; isselect = true)
                selected && CImGui.SetItemDefaultFocus()
            end
            CImGui.EndCombo()
        end
        iscombo && isselect
    end
end

function ColoredCombo(
    label, preview_value::Ref{String}, item_list, flags=0;
    size=(0, 0),
    rounding=0,
    bdrounding=0,
    thickness=0,
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colfrmh=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgHovered),
    colfrma=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgActive),
    colpopup=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Button, colbt)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colfrm)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgHovered, colfrmh)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgActive, colfrma)
    CImGui.PushStyleColor(CImGui.ImGuiCol_PopupBg, colpopup)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    CImGui.PushStyleVar(
        CImGui.ImGuiStyleVar_FramePadding,
        (unsafe_load(IMGUISTYLE.FramePadding.x), (size[2] - CImGui.GetFontSize() * unsafe_load(CImGui.GetIO().FontGlobalScale)) / 2)
    )
    CImGui.PushItemWidth(size[1])
    iscombo = ComboS(label, preview_value, item_list, flags)
    CImGui.PopItemWidth()
    CImGui.PopStyleVar(2)
    CImGui.PopStyleColor(6)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return iscombo
end
# toint8(s) = [Int8(c) for c in s]

let
    strbuf::String = '\0'^1024
    # global function ResizeCallback(data::CImGui.ImGuiInputTextCallbackData)::Cint
    #     if data.EventFlag == CImGui.ImGuiInputTextFlags_CallbackResize
    #         occursin('\0', unsafe_pointer_to_objref(Ptr{Cchar}(data.UserData))) || (buf *= '\0')
    #         # str = unsafe_pointer_to_objref(Ptr{Cchar}(data.UserData))
    #         # if ncodeunits(str) == data.BufSize
    #         #     unsafe_store!(data.Buf, '\0', data.BufSize+1)
    #         # end
    #         # @info typeof(str)
    #         # occursin('\0', str) && 
    #         # @info str
    #         # @info occursin('\0', str)
    #         # @info unsafe_string(Ptr{Cchar}(data.Buf))
    #         # strbuf = unsafe_wrap(Vector{Int8}, data.Buf, data.BufSize)
    #         # resize!(strbuf, data.BufTextLen+1)
    #         # data.Buf = pointer(strbuf)
    #         # data.BufSize = length(strbuf)
    #     end
    #     return 0
    # end
    global function InputTextRSZ(label, str::Ref{String}, flags=0)
        buf = string(str[], strbuf)
        input = CImGui.InputText(label, buf, length(buf), flags)
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
    end
    global function InputTextWithHintRSZ(label, hint, str::Ref{String}, flags=0)
        buf = string(str[], strbuf)
        input = CImGui.InputTextWithHint(label, hint, buf, length(buf), flags)
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
    end
    global function InputTextMultilineRSZ(label, str::Ref{String}, size=(0, 0), flags=0)
        buf = string(str[], strbuf)
        input = CImGui.InputTextMultiline(label, buf, length(buf), size, flags)
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
    end
end

function ColoredInputTextWithHintRSZ(
    label,
    hint,
    str::Ref{String},
    flags=0;
    size=(0, 0),
    rounding=0,
    bdrounding=0,
    thickness=0,
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colhint=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled),
    colrect=MORESTYLE.Colors.ShowTextRect
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colfrm)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.PushStyleColor(CImGui.ImGuiCol_TextDisabled, colhint)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, (unsafe_load(IMGUISTYLE.FramePadding.x), (size[2] - CImGui.GetFontSize()) / 2))
    CImGui.PushItemWidth(size[1])
    input = InputTextWithHintRSZ(label, hint, str, flags)
    CImGui.PopItemWidth()
    CImGui.PopStyleVar(2)
    CImGui.PopStyleColor(3)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return input
end

function ColoredDragWidget(
    dragfunc,
    label, v::Ref, v_speed=1.0, v_min=0, v_max=0.0, format="%.3f", flag=0;
    size=(0, 0),
    rounding=0,
    bdrounding=0,
    thickness=0,
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colfrmh=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgHovered),
    colfrma=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colfrm)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgHovered, colfrmh)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgActive, colfrma)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, (unsafe_load(IMGUISTYLE.FramePadding.x), (size[2] - CImGui.GetFontSize()) / 2))
    CImGui.PushItemWidth(size[1])
    dragged = dragfunc(label, v, v_speed, v_min, v_max, format, flag)
    CImGui.PopItemWidth()
    CImGui.PopStyleVar(2)
    CImGui.PopStyleColor(4)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return dragged
end
# ResizeCallback_c = @cfunction ResizeCallback Cint (CImGui.ImGuiInputTextCallbackData,)

# function InputTextRSZ(label, str::Ref)
#     buf = str[] * '\0'^64
#     input = CImGui.InputText(label, buf, length(buf))
#     input && (str[] = replace(buf, r"\0.*" => ""))
#     input
# end

# function InputTextMultilineRSZ(label, str::Ref, size=(0, 0), flags=0)
#     buf = str[] * '\0'^1024
#     input = CImGui.InputTextMultiline(label, buf, length(buf), size, flags)
#     input && (str[] = replace(buf, r"\0.*" => ""))
#     input
# end

# function InputTextWithHintRSZ(label, hint, str::Ref)
#     buf = str[] * '\0'^64
#     input = CImGui.InputTextWithHint(label, hint, buf, length(buf))
#     input && (str[] = replace(buf, r"\0.*" => ""))
#     input
# end

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
    action=(si, ti, args...)->(),
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

function YesNoDialog(id, msg, flags=0)::Bool
    if CImGui.BeginPopupModal(id, C_NULL, flags)
        CImGui.TextColored(MORESTYLE.Colors.LogError, string("\n", msg, "\n\n"))
        CImGui.Button(mlstr("Confirm")) && (CImGui.CloseCurrentPopup(); return true)
        CImGui.SameLine(240)
        CImGui.Button(mlstr("Cancel")) && (CImGui.CloseCurrentPopup(); return false)
        CImGui.EndPopup()
    end
    return false
end

function TextRect(
    str;
    size=(0, 0),
    nochild=false,
    bdrounding=MORESTYLE.Variables.TextRectRounding,
    thickness=MORESTYLE.Variables.TextRectThickness,
    padding=MORESTYLE.Variables.TextRectPadding,
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
)
    draw_list = CImGui.GetWindowDrawList()
    availwidth = CImGui.GetContentRegionAvailWidth()
    nochild || CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ padding)
    nochild || CImGui.BeginChild("TextRect", size .- 2padding, true)
    CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ padding .+ thickness)
    CImGui.PushTextWrapPos(nochild ? availwidth - padding[1] : 0)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.TextUnformatted(str)
    CImGui.PopStyleColor()
    CImGui.PopTextWrapPos()
    nochild || CImGui.EndChild()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    nochild && ColoredButton(""; size=(Cfloat(0), thickness + padding[2]), colbt=[0, 0, 0, 0], colbth=[0, 0, 0, 0], colbta=[0, 0, 0, 0])
    recta = nochild ? rmin .- padding : rmin .- padding .+ thickness
    rectb = nochild ? CImGui.ImVec2(rmin.x + availwidth .- 2padding[1] .- 2thickness, rmax.y + padding[2]) : rmax .+ padding .- thickness
    CImGui.AddRect(
        draw_list,
        recta, rectb,
        CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.ShowTextRect),
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

function RenameSelectable(str_id, isrename::Ref{Bool}, label::Ref, selected::Bool, flags=0, size=(0, 0); fixedlabel="")
    trig = false
    if isrename[]
        InputTextRSZ(str_id, label)
        if (!CImGui.IsItemHovered() && !CImGui.IsItemActive() && CImGui.IsMouseClicked(0)) || CImGui.IsMouseClicked(1)
            isrename[] = false
        end
    else
        trig = CImGui.Selectable(stcstr(fixedlabel, label[]), selected, flags, size)
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (isrename[] = true)
    end
    trig
end

const IMAGES::Dict{String,LoopVector{Int}} = Dict()

let
    framecount::Cint = 0
    global function Image(path; size=(100, 100), rate=1, uv0=(0, 0), uv1=(1, 1), tint_col=[1, 1, 1, 1], border_col=[0, 0, 0, 0])
        haskey(IMAGES, path) || createimage(path; showsize=size)
        if length(IMAGES[path]) > 1 && framecount != CImGui.GetFrameCount()
            framecount = CImGui.GetFrameCount()
            framecount % rate == 0 && move!(IMAGES[path])
        end
        CImGui.Image(Ptr{Cvoid}(IMAGES[path][]), size, uv0, uv1, tint_col, border_col)
    end
end

function createimage(path; showsize=(100, 100))
    IMAGES[path] = LoopVector(Int[])
    if isfile(path)
        try
            imgload = FileIO.load(path)
            if ndims(imgload) == 2
                img = RGBA.(collect(transpose(imgload)))
                imgsize = size(img)
                push!(IMAGES[path], ImGui_ImplOpenGL3_CreateImageTexture(imgsize...))
                ImGui_ImplOpenGL3_UpdateImageTexture(IMAGES[path][], img, imgsize...)
            elseif ndims(imgload) == 3
                imgs = permutedims(RGBA.(imgload), (2, 1, 3))
                imgsize = size(imgs)[1:2]
                for img in eachslice(imgs; dims=3)
                    push!(IMAGES[path], ImGui_ImplOpenGL3_CreateImageTexture(imgsize...))
                    ImGui_ImplOpenGL3_UpdateImageTexture(IMAGES[path].data[end], img, imgsize...)
                end
            else
                push!(IMAGES[path], ImGui_ImplOpenGL3_CreateImageTexture(showsize...))
            end
        catch e
            @error "[$(now())]\n$(mlstr("loading image failed!!!"))" exception = e
            push!(IMAGES[path], ImGui_ImplOpenGL3_CreateImageTexture(showsize...))
        end
    else
        push!(IMAGES[path], ImGui_ImplOpenGL3_CreateImageTexture(showsize...))
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
        clicked = CImGui.ImageButton(label, Ptr{Cvoid}(IMAGES[path][]), size .- 2frame_padding, uv0, uv1, bg_col, tint_col)
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
    CImGui.PushStyleColor(CImGui.ImGuiCol_Button, colbt)
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, colbth)
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, colbta)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    clicked = CImGui.Button(label, size)
    CImGui.PopStyleColor(4)
    return clicked
end

function ColoredButtonRect(
    label;
    size=(0, 0),
    rounding=0.0,
    bdrounding=0.0,
    thickness=0,
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    clicked = ColoredButton(label; size=size, colbt=colbt, colbth=colbth, colbta=colbta, coltxt=coltxt)
    CImGui.PopStyleVar()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
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
    rounding=0.0,
    bdrounding=0.0,
    thickness=0,
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    colrect=MORESTYLE.Colors.ShowTextRect
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
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return clicked
end

function ImageColoredButtonRect(
    label, path, useimage=false;
    size=(40, 40),
    rate=1,
    uv0=(0, 0),
    uv1=(1, 1),
    frame_padding=(6, 6),
    rounding=0.0,
    bdrounding=0.0,
    thickness=0,
    bg_col=[0, 0, 0, 0],
    tint_col=[1, 1, 1, 1],
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
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
    rounding=0.0,
    bdrounding=0.0,
    thickness=1.0,
    colon=MORESTYLE.Colors.ToggleButtonOn,
    coloff=MORESTYLE.Colors.ToggleButtonOff,
    colbth=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered),
    colbta=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    toggled = ToggleButton(label, v; size=size, colon=colon, coloff=coloff, colbth=colbth, colbta=colbta, coltxt=coltxt)
    CImGui.PopStyleVar()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return toggled
end

function ColoredRadioButton(
    label, v::Ref, v_button::Integer;
    bdrounding=0,
    thickness=0,
    colckm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_CheckMark),
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colfrmh=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgHovered),
    colfrma=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
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
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return clicked
end

function ColoredSlider(
    sliderfunc,
    label, v::Ref, v_min, v_max, format="%d", flags=0;
    size=(0, 0),
    rounding=0,
    grabrounding=0.0,
    bdrounding=0,
    thickness=0,
    colgrab=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_SliderGrab),
    colgraba=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_SliderGrabActive),
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colfrmh=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgHovered),
    colfrma=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_SliderGrab, colgrab)
    CImGui.PushStyleColor(CImGui.ImGuiCol_SliderGrabActive, colgraba)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colfrm)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgHovered, colfrmh)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgActive, colfrma)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_GrabRounding, grabrounding)
    CImGui.PushStyleVar(
        CImGui.ImGuiStyleVar_FramePadding,
        (unsafe_load(IMGUISTYLE.FramePadding.x), (size[2] - CImGui.GetFontSize() * unsafe_load(CImGui.GetIO().FontGlobalScale)) / 2)
    )
    CImGui.PushItemWidth(size[1])
    dragged = sliderfunc(label, v, v_min, v_max, format, flags)
    CImGui.PopItemWidth()
    CImGui.PopStyleVar(3)
    CImGui.PopStyleColor(6)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return dragged
end

function ColoredVSlider(
    vsliderfunc,
    label, v::Ref, v_min, v_max, format="%d", flags=0;
    size=(0, 0),
    rounding=0,
    grabrounding=0.0,
    bdrounding=0,
    thickness=0,
    colgrab=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_SliderGrab),
    colgraba=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_SliderGrabActive),
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colfrmh=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgHovered),
    colfrma=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgActive),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_SliderGrab, colgrab)
    CImGui.PushStyleColor(CImGui.ImGuiCol_SliderGrabActive, colgraba)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colfrm)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgHovered, colfrmh)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBgActive, colfrma)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_GrabRounding, grabrounding)
    dragged = vsliderfunc(label, size, v, v_min, v_max, format, flags)
    CImGui.PopStyleVar(2)
    CImGui.PopStyleColor(6)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return dragged
end

let
    framecount::Cint = 0
    global function SetWindowBgImage(
        path=CONF.BGImage.path;
        rate=CONF.BGImage.rate, use=CONF.BGImage.useall, tint_col=MORESTYLE.Colors.BgImageTint
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
                CImGui.GetWindowDrawList(), Ptr{Cvoid}(IMAGES[path][]), wpos, wpos .+ wsz, (0, 0), (1, 1),
                CImGui.ColorConvertFloat4ToU32(tint_col)
            )
        end
    end
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
    colbd=MORESTYLE.Colors.ItemBorder)
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
            CImGui.ColorConvertFloat4ToU32(CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGripActive))
        elseif rszcd.hovered
            CImGui.ColorConvertFloat4ToU32(CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGripHovered))
        else
            CImGui.ColorConvertFloat4ToU32(CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_ResizeGrip))
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
    pos::CImGui.ImVec2 = (0, 0)
    limmin::CImGui.ImVec2 = (0, 0)
    limmax::CImGui.ImVec2 = (Inf, Inf)
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
        CImGui.ColorConvertFloat4ToU32(dp.dragging ? dp.cola : dp.hovered ? dp.colh : dp.col)
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
    posmin::CImGui.ImVec2 = (0, 0)
    posmax::CImGui.ImVec2 = (100, 100)
    dragpos::CImGui.ImVec2 = (0, 0)
    rszgripsize::Cfloat = 24
    limmin::CImGui.ImVec2 = (0, 0)
    limmax::CImGui.ImVec2 = (Inf, Inf)
    limminsize::CImGui.ImVec2 = (0, 0)
    limmaxsize::CImGui.ImVec2 = (Inf, Inf)
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

function draw(dr::DragRect)
    drawlist = CImGui.GetWindowDrawList()
    CImGui.AddRectFilled(
        drawlist, dr.posmin, dr.posmax,
        CImGui.ColorConvertFloat4ToU32(dr.dragging ? dr.cola : dr.hovered && !dr.griphovered && !dr.gripdragging ? dr.colh : dr.col),
        dr.rounding
    )
    CImGui.AddTriangleFilled(
        drawlist,
        (dr.posmax.x - dr.rszgripsize, dr.posmax.y), dr.posmax, (dr.posmax.x, dr.posmax.y - dr.rszgripsize),
        CImGui.ColorConvertFloat4ToU32(
            CImGui.c_get(
                IMGUISTYLE.Colors,
                dr.gripdragging ? ImGuiCol_ResizeGripActive : dr.griphovered ? ImGuiCol_ResizeGripHovered : ImGuiCol_ResizeGrip
            )
        )
    )
    CImGui.AddRect(
        drawlist, dr.posmin, dr.posmax,
        CImGui.ColorConvertFloat4ToU32(dr.dragging ? dr.colbda : dr.hovered && !dr.griphovered && !dr.gripdragging ? dr.colbdh : dr.colbd),
        dr.bdrounding, ImDrawFlags_RoundCornersAll, dr.thickness
    )
end

function update_state!(dr::DragRect)
    mspos = CImGui.GetMousePos()
    dr.griphovered = inregion(mspos, dr.posmax .- dr.rszgripsize, dr.posmax)
    dr.griphovered &= -(mspos.x - dr.posmax.x + dr.rszgripsize) < mspos.y - dr.posmax.y
    dr.hovered = inregion(mspos, dr.posmin, dr.posmax)
    if dr.gripdragging
        if CImGui.IsMouseDown(0)
            dr.posmax = cutoff(mspos, dr.posmin .+ dr.limminsize, dr.posmin .+ dr.limmaxsize) .+ dr.rszgripsize ./ 4
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
    update_state!(dr)
    draw(dr)
end

@kwdef mutable struct DashBoard
    limit::Vector{Cfloat} = [0.0, 400.0]
    value::Vector{Cfloat} = [0, 0]
    colorsub::Vector{Cfloat} = [0.78, 0.78]
    selfinspstatusflag::Bool = true
    valuesmoothflag::Bool = true
    start::Bool = false
end

function SetDashboardValueLimit!(db::DashBoard, limit)
    db.limit .= limit
    db.value[2] = db.limit[1]
    return db.limit
end

LIMIT_CLAMP(value, min, max) = value < min ? min : value > max ? max : value

const SemicircleDeg = ImVec2(45.0, 315.0)
const RulerScaleLen = ImVec2(3.0, 1.2)
IMFXC_DEGTORAD(deg) = deg * π / 180.0
ICB_ZEROLIMIT(high, value) = high - value < 0.0 ? 0.0 : high - value > 1.0 ? 1.0 : high - value
function ExtColorBrightnesScale(color, value)
    ImVec4(ICB_ZEROLIMIT(color[1], value), ICB_ZEROLIMIT(color[2], value), ICB_ZEROLIMIT(color[3], value), ICB_ZEROLIMIT(color[4], value))
end
function ExtDrawLine(point0, point1, color, linewidth)
    CImGui.AddLine(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + point0[1], CImGui.GetCursorScreenPos()[2] + point0[2]),
        ImVec2(CImGui.GetCursorScreenPos()[1] + point1[1], CImGui.GetCursorScreenPos()[2] + point1[2]),
        CImGui.ColorConvertFloat4ToU32(color),
        linewidth
    )
end
function ExtDrawText(position, color, text)
    CImGui.AddText(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1], CImGui.GetCursorScreenPos()[2] + position[2]),
        CImGui.ColorConvertFloat4ToU32(color),
        text
    )
end
function ExtDrawRectangleFill(position, size, color; rounding=0)
    CImGui.AddRectFilled(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1], CImGui.GetCursorScreenPos()[2] + position[2]),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1] + size[1], CImGui.GetCursorScreenPos()[2] + position[2] + size[2]),
        CImGui.ColorConvertFloat4ToU32(color), rounding
    )
end
function ExtDrawRectangle(position, size, color; thickness=0, rounding=0)
    CImGui.AddRect(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1], CImGui.GetCursorScreenPos()[2] + position[2]),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1] + size[1], CImGui.GetCursorScreenPos()[2] + position[2] + size[2]),
        CImGui.ColorConvertFloat4ToU32(color), rounding, thickness
    )
end
function ExtDrawCircleFill(position, size, color; num_segments=24)
    CImGui.AddCircleFilled(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1], CImGui.GetCursorScreenPos()[2] + position[2]),
        size,
        CImGui.ColorConvertFloat4ToU32(color),
        num_segments
    )
end

LEDSTATE(STAT, POS, HCOLOR, LCOLOR; size=(40, 20)) = ExtDrawRectangleFill(POS, size, STAT ? HCOLOR : LCOLOR)

function DrawSemicircleBox(window_width, y_offset, ruler, color; num_segments=24)
    DrawOffsetHigh = window_width * 0.5
    CircleRadius = ImVec2(DrawOffsetHigh - unsafe_load(IMGUISTYLE.ItemSpacing.x), window_width * 0.28)

    LineBeginInnerTemp = ImVec2(
        sin(IMFXC_DEGTORAD(SemicircleDeg[1])) * CircleRadius[1] + DrawOffsetHigh,
        cos(IMFXC_DEGTORAD(SemicircleDeg[1])) * CircleRadius[1] + y_offset
    )

    RulerDrawSpc = ImVec2(
        (SemicircleDeg[2] - SemicircleDeg[1]) / ruler,
        (SemicircleDeg[2] - SemicircleDeg[1]) / (ruler * 5)
    )
    RulerDrawCount = [0.0, 1.0]

    CImGui.PathArcTo(CImGui.GetWindowDrawList(), CImGui.GetCursorScreenPos() .+ (DrawOffsetHigh, y_offset), CircleRadius[1], -5π / 4, π / 4, 2num_segments)
    CImGui.PathStroke(CImGui.GetWindowDrawList(), CImGui.ColorConvertFloat4ToU32(color), false, 0.01window_width)
    for i in SemicircleDeg[1]:0.15:SemicircleDeg[2]

        LineEndInnerTemp = ImVec2(
            sin(IMFXC_DEGTORAD(i)) * CircleRadius[1] + DrawOffsetHigh,
            cos(IMFXC_DEGTORAD(i)) * CircleRadius[1] + y_offset
        )

        if i - SemicircleDeg[1] >= RulerDrawSpc[1] * RulerDrawCount[1]
            LineRulerTemp = ImVec2(
                sin(IMFXC_DEGTORAD(i)) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1]) + DrawOffsetHigh,
                cos(IMFXC_DEGTORAD(i)) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1]) + y_offset
            )
            ExtDrawLine(LineEndInnerTemp, LineRulerTemp, color, 4.0)
            RulerDrawCount[1] += 1.0
        end

        if i - SemicircleDeg[1] > RulerDrawSpc[2] * RulerDrawCount[2]
            LineRulerTemp = ImVec2(
                sin(IMFXC_DEGTORAD(i)) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[2]) + DrawOffsetHigh,
                cos(IMFXC_DEGTORAD(i)) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[2]) + y_offset
            )
            ExtDrawLine(LineEndInnerTemp, LineRulerTemp, color, 2.2)
            RulerDrawCount[2] += 1.0
        end

        LineBeginInnerTemp = LineEndInnerTemp
    end

    CImGui.PathArcTo(CImGui.GetWindowDrawList(), CImGui.GetCursorScreenPos() .+ (DrawOffsetHigh, y_offset), CircleRadius[2], -5π / 4, π / 4, round(Int, 3num_segments / 2))
    CImGui.PathStroke(CImGui.GetWindowDrawList(), CImGui.ColorConvertFloat4ToU32(color), false, 0.03window_width)

    ExtDrawLine(
        ImVec2(
            sin(IMFXC_DEGTORAD(SemicircleDeg[2])) * CircleRadius[1] + DrawOffsetHigh,
            cos(IMFXC_DEGTORAD(SemicircleDeg[2])) * CircleRadius[1] + y_offset
        ),
        ImVec2(
            sin(IMFXC_DEGTORAD(SemicircleDeg[2])) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1]) + DrawOffsetHigh,
            cos(IMFXC_DEGTORAD(SemicircleDeg[2])) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1]) + y_offset
        ),
        color, 2.2
    )
end

function DrawTextFunc(DrawText, DrawPos, color)
    TextSizeOffset = CImGui.CalcTextSize(DrawText)
    ExtDrawText(ImVec2(DrawPos[1] - TextSizeOffset[1] * 0.5, DrawPos[2] - TextSizeOffset[2] * 0.5), color, DrawText)
end

function DrawRulerscaleValue(window_width, y_offset, ruler, limit, color)
    DrawOffsetHigh = window_width * 0.5
    CircleRadius = DrawOffsetHigh - unsafe_load(IMGUISTYLE.ItemSpacing.x)
    RulerDrawSpc = (SemicircleDeg[2] - SemicircleDeg[1]) / ruler
    RulerDrawCount = 0.0
    ValueDrawTemp = limit[2]
    ValueOffset = (limit[2] - limit[1]) / ruler

    for i in SemicircleDeg[1]:0.32:SemicircleDeg[2]
        if i - SemicircleDeg[1] >= RulerDrawSpc * RulerDrawCount
            DrawTextPos = ImVec2(
                sin(IMFXC_DEGTORAD(i)) * (CircleRadius - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1] * 2.4) + DrawOffsetHigh,
                cos(IMFXC_DEGTORAD(i)) * (CircleRadius - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1] * 2.4) + y_offset
            )
            DrawTextTemp = @sprintf "%g" round(ValueDrawTemp, sigdigits=3)
            ValueDrawTemp -= ValueOffset

            DrawTextFunc(DrawTextTemp, DrawTextPos, color)
            RulerDrawCount += 1.0
        end
    end

    HeadTextPos = ImVec2(
        sin(IMFXC_DEGTORAD(SemicircleDeg[2])) * (CircleRadius - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1] * 2.4) + DrawOffsetHigh,
        cos(IMFXC_DEGTORAD(SemicircleDeg[2])) * (CircleRadius - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1] * 2.4) + y_offset
    )
    DrawTextFunc(string(limit[1]), HeadTextPos, color)
end

function DrawIndicator(
    window_width, y_offset, value, limit;
    linewidth=7.2, num_segments=24,
    colbase=[0.16, 0.16, 0.16, 1.0], colind=[1.0, 0.0, 0.0, 0.98]
)
    DrawOffsetHigh = window_width * 0.5
    IWL = linewidth / (DrawOffsetHigh * 0.85)

    SemicircleDegLen = SemicircleDeg[2] - SemicircleDeg[1] + IWL * 180.0
    ValueLength = limit[2] - limit[1]
    ValueProportion = (value - limit[1]) / ValueLength
    ValueProportion = LIMIT_CLAMP(ValueProportion, 0.0, 1.0)

    CenterPoint = ImVec2(window_width * 0.5, y_offset)
    LineBeginTemp = ImVec2(
        sin(IMFXC_DEGTORAD(SemicircleDeg[2] - SemicircleDegLen * ValueProportion) + IWL) * DrawOffsetHigh * 0.85 - unsafe_load(IMGUISTYLE.ItemSpacing.x) + DrawOffsetHigh,
        cos(IMFXC_DEGTORAD(SemicircleDeg[2] - SemicircleDegLen * ValueProportion) + IWL) * DrawOffsetHigh * 0.85 - unsafe_load(IMGUISTYLE.ItemSpacing.x) + y_offset
    )

    ExtDrawCircleFill(CenterPoint, 8linewidth, [colbase[1:3]...; colbase[4] * 0.6]; num_segments=num_segments)
    ExtDrawLine(LineBeginTemp, CenterPoint, colind, linewidth)
    ExtDrawCircleFill(CenterPoint, 6linewidth, colbase; num_segments=num_segments)
end

function DrawDashboardWindow(
    db::DashBoard, value;
    size=(400, 400), ruler=6, speed=2, num_segments=24, rounding=0, bdrounding=0, thickness=0,
    colbg=[0, 0, 0, 0], colbd=[0, 0, 0, 0],
    colpanel=[1, 1, 1, 1], coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colbase=[0.16, 0.16, 0.16, 1.0], colind=(1.0, 0.0, 0.0, 0.98)
)
    !db.selfinspstatusflag && db.start && (db.value[1] = value)
    db.value[1] = LIMIT_CLAMP(db.value[1], db.limit[1], db.limit[2])

    db.limit[1] >= db.limit[2] && (db.limit[1] = db.limit[2] - 1.0)

    # CImGui.BeginChild(name, size)
    # ColoredButton(""; size=size, colbt=(0, 0, 0, 0), colbth=(0, 0, 0, 0), colbta=(0, 0, 0, 0))
    # CImGui.SetWindowFontScale(1.42)

    if db.start
        if db.selfinspstatusflag && db.value[1] < db.limit[1] + 1.0
            db.valuesmoothflag = true
            db.value[1] = db.limit[2]
        end
        if db.selfinspstatusflag && (db.value[1] - db.value[2]) < db.value[1] * 0.08
            db.selfinspstatusflag = false
            db.value[1] = db.limit[1]
        end
        if abs(db.value[1] - db.value[2]) < (db.limit[2] - db.limit[1]) / 270
            db.valuesmoothflag = false
        else
            db.valuesmoothflag = true
        end
        db.colorsub[1] = 0.0
    else
        db.colorsub[1] = 0.78
        db.value[1] = db.limit[1]
        db.valuesmoothflag = true
        db.selfinspstatusflag = true
    end

    ledsz = (40, 20) .* (size[1] / 600)
    posl = ImVec2(unsafe_load(IMGUISTYLE.ItemSpacing.x), unsafe_load(IMGUISTYLE.ItemSpacing.x))
    posr = ImVec2(ledsz[1] + unsafe_load(IMGUISTYLE.ItemSpacing.x) * 2.0, unsafe_load(IMGUISTYLE.ItemSpacing.x))
    ExtDrawRectangleFill((0, 0), size, colbg; rounding=rounding)
    ExtDrawRectangle((0, 0), size, colbd; thickness=thickness, rounding=bdrounding)
    LEDSTATE(
        db.start && db.selfinspstatusflag,
        posl,
        (1.0, 0.0, 0.0, 1.0),
        ExtColorBrightnesScale(colpanel, 0.78);
        size=ledsz
    )
    LEDSTATE(
        db.start && !db.selfinspstatusflag,
        posr,
        (0.0, 1.0, 0.0, 1.0),
        ExtColorBrightnesScale(colpanel, 0.78);
        size=ledsz
    )
    # if CImGui.IsMouseClicked(0)
    #     mousein(CImGui.GetCursorScreenPos() .+ posl, CImGui.GetCursorScreenPos() .+ posl .+ (40, 20)) && (db.start = false)
    #     mousein(CImGui.GetCursorScreenPos() .+ posr, CImGui.GetCursorScreenPos() .+ posr .+ (40, 20)) && (db.start = true)
    # end
    DrawSemicircleBox(size[1], size[2] * 0.6, ruler, ExtColorBrightnesScale(colpanel, db.colorsub[2]); num_segments=num_segments)
    DrawRulerscaleValue(size[1], size[2] * 0.6, ruler, db.limit, ExtColorBrightnesScale(coltxt, db.colorsub[2]))
    DrawIndicator(
        size[1], size[2] * 0.6, db.value[2], db.limit;
        linewidth=0.01size[1], num_segments=num_segments, colbase=colbase, colind=colind
    )

    db.colorsub[2] += (db.colorsub[1] - db.colorsub[2]) * 0.024 * speed
    if db.valuesmoothflag
        db.value[2] += (db.value[1] - db.value[2]) * 0.016 * speed
    else
        db.value[2] = db.value[1]
    end
    # CImGui.EndChild()
    # return CImGui.IsWindowHovered()
end

let
    dashboardlist::Dict{String,DashBoard} = Dict()
    global function DashBoardPanel(
        label, value, range, start;
        size=(400, 400),
        ruler=6,
        rounding=0,
        bdrounding=0,
        thickness=0,
        num_segments=24,
        col=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ChildBg),
        colon=MORESTYLE.Colors.ToggleButtonOn,
        colbase=MORESTYLE.Colors.ToggleButtonOff,
        colind=MORESTYLE.Colors.HighlightText,
        coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
        colrect=MORESTYLE.Colors.ShowTextRect
    )
        haskey(dashboardlist, label) || (dashboardlist[label] = DashBoard())
        db = dashboardlist[label]
        db.start = start
        all(range .≈ db.limit) || SetDashboardValueLimit!(db, range)
        DrawDashboardWindow(
            db, value;
            size=size, ruler=ruler, speed=2, num_segments=num_segments,
            rounding=rounding, bdrounding=bdrounding, thickness=thickness,
            colbg=col, colbd=colrect, colpanel=colon, colbase=colbase, colind=colind, coltxt=coltxt
        )
        # rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
        # draw_list = CImGui.GetWindowDrawList()
        # CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    end
end

function ColoredProgressBarRect(
    fraction, label;
    size=(0, 0),
    rounding=0.0,
    bdrounding=0.0,
    thickness=0,
    colbar=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colbara=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PlotHistogram),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=MORESTYLE.Colors.ShowTextRect
)
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, colbar)
    CImGui.PushStyleColor(CImGui.ImGuiCol_PlotHistogram, colbara)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, rounding)
    CImGui.ProgressBar(fraction, size, label)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor(3)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    return false
end