function ComBoS(label, preview_value::Ref, item_list, flags=0)
    iscombo = CImGui.BeginCombo(label, preview_value.x, flags)
    if iscombo
        for item in item_list
            selected = preview_value.x == item
            CImGui.Selectable(item, selected) && (preview_value.x = item)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    iscombo
end

# toint8(s) = [Int8(c) for c in s]

let
    buf::String = ""
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
    global function InputTextRSZ(label, str::Ref{String})
        buf = str[] * '\0'^64
        input = CImGui.InputText(label, buf, length(buf))
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
    end
    global function InputTextWithHintRSZ(label, hint, str::Ref{String}, flags=0)
        buf = str[] * '\0'^64
        input = CImGui.InputTextWithHint(label, hint, buf, length(buf), flags)
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
    end
    global function InputTextMultilineRSZ(label, str::Ref{String}, size=(0, 0), flags=0)
        buf = str[] * '\0'^1024
        input = CImGui.InputTextMultiline(label, buf, length(buf), size, flags)
        input && (str[] = replace(buf, r"\0.*" => ""))
        input
    end
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

function ShowUnit(id, utype, ui::Ref, flags=CImGui.ImGuiComboFlags_NoArrowButton)
    units = string.(conf.U[utype])
    showu = @trypass units[ui.x] ""
    if CImGui.BeginCombo("##单位$id", showu, flags)
        for u in eachindex(units)
            local selected = ui.x == u
            CImGui.Selectable(units[u], selected) && (ui.x = u)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
end

function MultiSelectable(
    rightclickmenu,
    id,
    labels,
    states,
    n,
    idxing=Ref(1),
    size=(Cfloat(0), CImGui.GetFrameHeight() * ceil(Int, length(labels) / n))
)
    l = length(labels)
    size = l == 0 ? (Cfloat(0), CImGui.GetFrameHeightWithSpacing()) : size
    CImGui.BeginChild("MultiSelectable##$id", size)
    CImGui.Columns(n, C_NULL, false)
    for i in 1:l
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
        CImGui.Selectable(labels[i], states[i]) && (states[i] ⊻= true)
        CImGui.PopStyleVar()
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
    size = l == 0 ? (Cfloat(0), CImGui.GetFrameHeightWithSpacing()) : size
    CImGui.BeginChild("MultiSelectable##$id", size)
    CImGui.Columns(n, C_NULL, false)
    for i in 1:l
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
        CImGui.Selectable(labels[i], states[i]) && (states[i] ⊻= true)
        CImGui.PopStyleVar()
        rightclickmenu() && (idxing[] = i)
        CImGui.Indent()
        if CImGui.BeginDragDropSource(0)
            @c CImGui.SetDragDropPayload("DragMultiSelectable##id", &i, sizeof(Cint))
            CImGui.Text(labels[i])
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("DragMultiSelectable##id")
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
        CImGui.TextColored(morestyle.Colors.LogError, string("\n", msg, "\n\n"))
        CImGui.Button("确认") && (CImGui.CloseCurrentPopup(); return true)
        CImGui.SameLine(240)
        CImGui.Button("取消") && (CImGui.CloseCurrentPopup(); return false)
        CImGui.EndPopup()
    end
    return false
end

function TextRect(str)
    pos = CImGui.GetCursorScreenPos()
    draw_list = CImGui.GetWindowDrawList()
    width = CImGui.GetContentRegionAvailWidth()
    CImGui.PushTextWrapPos(CImGui.GetCursorPosX() + width)
    CImGui.TextUnformatted(str)
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    CImGui.AddRect(
        draw_list,
        rmin,
        CImGui.ImVec2(pos.x + width, rmax.y),
        CImGui.ColorConvertFloat4ToU32(morestyle.Colors.ShowTextRect),
        0.0,
        0
    )
    CImGui.PopTextWrapPos()
    [rmin.x, rmin.y, pos.x + width, rmax.y]
end

function ItemTooltip(tipstr, wrappos=CImGui.GetFontSize() * 36.0)
    if CImGui.IsItemHovered()
        CImGui.BeginTooltip()
        CImGui.PushTextWrapPos(wrappos)
        CImGui.TextUnformatted(tipstr)
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
end

function RenameSelectable(str_id, isrename::Ref{Bool}, label::Ref, selected::Bool, flags=0, size=(0, 0))
    trig = false
    if isrename[]
        InputTextRSZ(str_id, label)
        if (!CImGui.IsItemHovered() && !CImGui.IsItemActive() && CImGui.IsMouseClicked(0)) || CImGui.IsMouseClicked(1)
            isrename[] = false
        end
    else
        trig = CImGui.Selectable(label[], selected, flags, size)
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (isrename[] = true)
    end
    trig
end

mutable struct Layout
    id::String
    showcol::Cint
    idxing::Cint
    labels::Vector{String}
    marks::Vector{String}
    states::Vector{Bool}
    selectedlabels::Vector{String}
    labeltoidx::Dict{String,Int}
    selectedidx::Vector{Int}
end
Layout(id) = Layout(id, 3, 1, ["default"], [""], [false], [], Dict(), [])
Layout() = Layout("Layout")

labeltoidx!(lo::Layout) = lo.selectedidx = [lo.labeltoidx[lb] for lb in lo.selectedlabels]

function edit(rightclickmenu, lo::Layout, size=(Cfloat(0), CImGui.GetFrameHeight() * ceil(Int, length(lo.labels) / lo.showcol)))
    states_old = copy(lo.states)
    marks_old = copy(lo.marks)
    editlabels = @. lo.labels * " " * lo.marks * "###for rename" * lo.labels
    @c MultiSelectable(rightclickmenu, "select##$(lo.id)", editlabels, lo.states, lo.showcol, &lo.idxing, size)
    CImGui.Separator()
    CImGui.Text("布局")
    selectedlabels_old = copy(lo.selectedlabels)
    if lo.states != states_old || lo.marks != marks_old
        editlabels = @. lo.labels * " " * lo.marks
        lo.selectedlabels = editlabels[lo.states]
        lo.labeltoidx = Dict(zip(editlabels, collect(eachindex(editlabels))))
    end
    DragMultiSelectable(
        () -> false,
        "selected##$(lo.id)",
        lo.selectedlabels,
        trues(length(lo.selectedlabels)),
        lo.showcol,
        Ref(1),
        size
    )
    lo.selectedlabels == selectedlabels_old || labeltoidx!(lo)
end

function update!(lo::Layout)
    lo.selectedlabels = lo.labels[lo.states]
    lo.labeltoidx = Dict(zip(lo.labels, collect(eachindex(lo.labels))))
    labeltoidx!(lo)
end