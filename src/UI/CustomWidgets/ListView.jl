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
    rounding=unsafe_load(IMGUISTYLE.FrameRounding),
    bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
    thickness=0,
    colbt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button),
    colfrm=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg),
    colfrmh=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgHovered),
    colfrma=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBgActive),
    colpopup=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg),
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colrect=(0, 0, 0, 0)
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
    CImGui.AddRect(draw_list, rmin, rmax, colrect, bdrounding, 0, thickness)
    return iscombo
end