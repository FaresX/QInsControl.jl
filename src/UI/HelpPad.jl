function ShowHelpPad(p_open::Ref{Bool})
    # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
    if CImGui.Begin(stcstr(MORESTYLE.Icons.HelpPad, "  ", mlstr("helppad")), p_open)
        CImGui.Columns(2)
        @cstatic firsttime::Bool = true begin
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
        end
        CImGui.BeginChild("Content Menu", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))

        CImGui.EndChild()
        CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("save")))
        CImGui.SameLine(CImGui.GetColumnOffset(1) - CImGui.GetItemRectSize().x - unsafe_load(IMGUISTYLE.WindowPadding.x))
        CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " 新建")) && CImGui.OpenPopup("new topic or item")
        if CImGui.BeginPopup("new topic or item")
            CImGui.MenuItem(mlstr("topic"))
            CImGui.MenuItem(mlstr("item"))
            CImGui.EndPopup()
        end
        CImGui.NextColumn()

        CImGui.BeginChild("Content")
        CImGui.EndChild()
    end
    CImGui.End()
end