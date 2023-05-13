ICONS = ICON()
ICONS_NAME = Dict()
for f in fieldnames(ICON)
    push!(ICONS_NAME, getproperty(ICONS, f) => string(f))
end

# mutable struct IconColored
#     icon::String
#     color::Vector{Cfloat}
#     IconColored(icon) = new(icon, CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text))
# end

# function IconColoredSelector(label, icon::IconColored)
#     CImGui.ColorEdit4("##" * label, icon.color, CImGui.ImGuiColorEditFlags_AlphaBar)
#     CImGui.SameLine()
#     @c IconSelector(label, &icon.icon)
# end

let 
    filter::Ptr{ImGuiTextFilter} = ImGuiTextFilter_ImGuiTextFilter(C_NULL)
    global function IconSelector(label, icon_str::Ref{String})
        selected = false
        CImGui.PushID(label)
        CImGui.Button(icon_str[]) && CImGui.OpenPopup(label)
        CImGui.IsItemHovered() && CImGui.SetTooltip(ICONS_NAME[icon_str[]])
        CImGui.SameLine()
        CImGui.Text(label)
        CImGui.SetNextWindowSize((1000, 600))
        if CImGui.BeginPopup(label)
            ImGuiTextFilter_Draw(filter, "Filter ICONS", 600)
            CImGui.Columns(24, C_NULL, false)
            for (i, icon) in enumerate(fieldnames(ICON))
                ImGuiTextFilter_PassFilter(filter, pointer(string(icon)), C_NULL) || continue
                CImGui.PushID(i)
                if CImGui.Selectable(getproperty(ICONS, icon), getproperty(ICONS, icon) == icon_str[])
                    icon_str[] = getproperty(ICONS, icon)
                    selected = true
                end
                CImGui.IsItemHovered() && CImGui.SetTooltip(string(icon))
                CImGui.PopID()
                CImGui.NextColumn()
            end
            CImGui.EndPopup()
        end
        CImGui.PopID()
        return selected
    end
end

# TextIconColored(icon::IconColored) = CImGui.TextColored(icon.color, icon.icon)
# ButtonIconColored(icon::IconColored) = 