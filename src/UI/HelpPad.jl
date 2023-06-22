function ShowHelpPad(p_open::Ref{Bool})
    # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
    if CImGui.Begin(stcstr(morestyle.Icons.HelpPad, "  帮助板"), p_open)
        CImGui.Columns(2)
        @cstatic firsttime::Bool = true begin
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
        end
        CImGui.BeginChild("Content Menu", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))

        CImGui.EndChild()
        CImGui.Button(stcstr(morestyle.Icons.SaveButton, " 保存"))
        CImGui.SameLine(CImGui.GetColumnOffset(1) - CImGui.GetItemRectSize().x - unsafe_load(imguistyle.WindowPadding.x))
        CImGui.Button(stcstr(morestyle.Icons.NewFile, " 新建")) && CImGui.OpenPopup("新建主题或条目")
        if CImGui.BeginPopup("新建主题或项目")
            CImGui.MenuItem("主题")
            CImGui.MenuItem("项目")
            CImGui.EndPopup()
        end
        CImGui.NextColumn()

        CImGui.BeginChild("Content")
        CImGui.EndChild()
    end
    CImGui.End()
end