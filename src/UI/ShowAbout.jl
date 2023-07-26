function ShowAbout()
    if CImGui.BeginPopupModal("关于", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        ftsz = CImGui.GetFontSize()
        ww = CImGui.GetWindowWidth()
        CImGui.SameLine(ww / 3)
        CImGui.Image(Ptr{Cvoid}(ICONID), (ww / 3, ww / 3))
        CImGui.Text("\n")
        CImGui.Text("")
        CImGui.SameLine(ww / 2 - 2.5ftsz)
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, "QInsControl\n\n")
        CImGui.Text("版本 : 0.1.0")
        CImGui.Text("作者 : XST\n\n")
        global JLVERINFO
        CImGui.Text(JLVERINFO)
        CImGui.Text("\n")
        CImGui.Button("确认##ShowAbout", (-1, 0)) && CImGui.CloseCurrentPopup()
        CImGui.EndPopup()
    end
end
