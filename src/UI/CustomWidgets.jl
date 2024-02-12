function ComBoS(label, preview_value::Ref, item_list, flags=0)
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
    iscombo = ComBoS(label, preview_value, item_list, flags)
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

function MultiSelectable(
    rightclickmenu,
    id,
    labels,
    states,
    n,
    idxing=Ref(1),
    size=(Cfloat(0), CImGui.GetFrameHeight() * ceil(Int, length(labels) / n));
    border=false,
    selectableflags=0,
    selectablesize=(0, 0)
)
    l = length(labels)
    length(states) == l || resize!(states, l)
    size = l == 0 ? (Cfloat(0), CImGui.GetFrameHeightWithSpacing()) : size
    CImGui.BeginChild(stcstr("MultiSelectable##", id), size, border)
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
        CImGui.NextColumn()
    end
    CImGui.EndChild()
end

function DragMultiSelectable(
    rightclickmenu,
    id,
    labels,
    states,
    n,
    idxing=Ref(1),
    size=(Cfloat(0), CImGui.GetFrameHeight() * ceil(Int, length(labels) / n))
)
    l = length(labels)
    length(states) == l || resize!(states, l)
    size = l == 0 ? (Cfloat(0), CImGui.GetFrameHeightWithSpacing()) : size
    CImGui.BeginChild(stcstr("DragMultiS##", id), size)
    CImGui.Columns(n, C_NULL, false)
    for i in 1:l
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
        CImGui.Selectable(labels[i], states[i]) && (states[i] ⊻= true)
        CImGui.PopStyleVar()
        rightclickmenu() && (idxing[] = i)
        CImGui.Indent()
        if CImGui.BeginDragDropSource()
            @c CImGui.SetDragDropPayload(stcstr("DragMultiS##", id), &i, sizeof(Cint))
            CImGui.Text(labels[i])
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload(stcstr("DragMultiS##", id))
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                if i != payload_i
                    labels[i], labels[payload_i] = labels[payload_i], labels[i]
                    states[i], states[payload_i] = states[payload_i], states[i]
                end
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
    nochild || CImGui.BeginChild("TextRect", size)
    CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ padding .+ thickness)
    CImGui.PushTextWrapPos(nochild ? availwidth - padding[1] : 0)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.TextUnformatted(str)
    CImGui.PopStyleColor()
    CImGui.PopTextWrapPos()
    nochild || CImGui.EndChild()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    nochild && ColoredButton(""; size=(Cfloat(0), thickness + padding[2]), colbt=[0, 0, 0, 0], colbth=[0, 0, 0, 0], colbta=[0, 0, 0, 0])
    recta = nochild ? rmin .- padding : rmin .+ thickness
    rectb = nochild ? CImGui.ImVec2(rmin.x + availwidth .- 2padding[1] .- 2thickness, rmax.y + padding[2]) : rmax .- thickness
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

const IMAGES::Dict{String,Int} = Dict()
function Image(path; size=(100, 100), uv0=(0, 0), uv1=(1, 1), tint_col=[1, 1, 1, 1], border_col=[0, 0, 0, 0])
    haskey(IMAGES, path) || createimage(path; showsize=size)
    CImGui.Image(Ptr{Cvoid}(IMAGES[path]), size, uv0, uv1, tint_col, border_col)
end

function createimage(path; showsize=(100, 100))
    if isfile(path)
        try
            img = RGBA.(collect(transpose(FileIO.load(path))))
            imgsize = size(img)
            push!(IMAGES, path => ImGui_ImplOpenGL3_CreateImageTexture(imgsize...))
            ImGui_ImplOpenGL3_UpdateImageTexture(IMAGES[path], img, imgsize...)
        catch e
            @error "[$(now())]\n$(mlstr("loading image failed!!!"))" exception = e
            push!(IMAGES, path => ImGui_ImplOpenGL3_CreateImageTexture(showsize...))
        end
    else
        push!(IMAGES, path => ImGui_ImplOpenGL3_CreateImageTexture(showsize...))
    end
end

function ImageButton(path; size=(40, 40), uv0=(0, 0), uv1=(1, 1), frame_padding=-1, bg_col=[0, 0, 0, 0], tint_col=[1, 1, 1, 1])
    haskey(IMAGES, path) || createimage(path; showsize=size)
    CImGui.ImageButton(Ptr{Cvoid}(IMAGES[path]), size, uv0, uv1, frame_padding, bg_col, tint_col)
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
    path;
    size=(40, 40),
    uv0=(0, 0),
    uv1=(1, 1),
    frame_padding=-1,
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
    clicked = ImageButton(path; size=size, uv0=uv0, uv1=uv1, frame_padding=frame_padding, bg_col=bg_col, tint_col=tint_col)
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
    uv0=(0, 0),
    uv1=(1, 1),
    frame_padding=-1,
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
            path;
            size=size, uv0=uv0, uv1=uv1, frame_padding=frame_padding, bg_col=bg_col, tint_col=tint_col,
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
    CImGui.PopStyleVar()
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

function SetWindowBgImage(path=CONF.BGImage.path; tint_col=MORESTYLE.Colors.BgImageTint)
    if CONF.BGImage.useall
        wpos = CImGui.GetWindowPos()
        wsz = CImGui.GetWindowSize()
        haskey(IMAGES, path) || createimage(path; showsize=wsz)
        CImGui.AddImage(CImGui.GetWindowDrawList(), Ptr{Cvoid}(IMAGES[path]), wpos, wpos .+ wsz, (0, 0), (1, 1), CImGui.ColorConvertFloat4ToU32(tint_col))
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