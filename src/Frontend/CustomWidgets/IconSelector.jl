const ICONS = Icon()
const ICONS_NAME = Dict()
for f in fieldnames(Icon)
    ICONS_NAME[getproperty(ICONS, f)] = string(f)
end

let
    filter::Ptr{ImGuiTextFilter} = ImGuiTextFilter_ImGuiTextFilter(C_NULL)
    push!(init_funcs, () -> filter = ImGuiTextFilter_ImGuiTextFilter(C_NULL))
    global function IconSelector(label, icon_str::Ref{String})
        selected = false
        CImGui.PushID(label)
        CImGui.Button(icon_str[]) && CImGui.OpenPopup(label)
        CImGui.IsItemHovered() && CImGui.SetTooltip(ICONS_NAME[icon_str[]])
        CImGui.SameLine()
        CImGui.Text(label)
        CImGui.SetNextWindowSize((1000, 600))
        if CImGui.BeginPopup(label)
            ImGuiTextFilter_Draw(filter, "Filter ICONS", 0)
            CImGui.Columns(24, C_NULL, false)
            for (i, icon) in enumerate(fieldnames(Icon))
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