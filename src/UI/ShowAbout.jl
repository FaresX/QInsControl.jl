let
    newversion::String = ""
    hasnewversiontime::Float64 = 0
    global function ShowAbout()
        if CImGui.BeginPopupModal(mlstr("About"), C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            ftsz = CImGui.GetFontSize()
            ww = CImGui.GetWindowWidth()
            CImGui.SetCursorPos(ww / 3, CImGui.GetCursorPosY())
            CImGui.Image(CImGui.ImTextureID(ICONID), (ww / 3, ww / 3))
            CImGui.PushFont(BIGFONT)
            CImGui.SetCursorPos(CImGui.GetCursorPos() .+ ((ww - CImGui.CalcTextSize("QInsControl").x) / 2, ftsz))
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, "QInsControl\n")
            CImGui.PopFont()
            CImGui.Text(stcstr(mlstr("version"), " : ", QINSCONTROLVERSION))
            CImGui.SameLine()
            if SYNCSTATES[Int(NewVersion)]
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("New version!"))
                CImGui.SameLine()
                CImGui.TextLinkOpenURL(newversion, "https://github.com/FaresX/QInsControl.jl/releases/latest")
            else
                CImGui.SetWindowFontScale(0.6)
                ColoredButton(MORESTYLE.Icons.Update; colbt=[0, 0, 0, 0]) && (getnewestversion(); hasnewversiontime = time())
                CImGui.SetWindowFontScale(1)
                if !SYNCSTATES[Int(NewVersion)] && time() - hasnewversiontime < 4
                    CImGui.SameLine()
                    CImGui.SetCursorPosY(CImGui.GetCursorPosY() - 4)
                    CImGui.TextColored(MORESTYLE.Colors.InfoText, mlstr("Already the latest version!"))
                end
            end
            CImGui.Text(stcstr(mlstr("author"), " : XST\n"))
            CImGui.Text(stcstr(mlstr("license"), " : MPL-2.0 License\n"))
            CImGui.Text(stcstr(mlstr("github"), " : "))
            CImGui.SameLine()
            CImGui.TextLinkOpenURL("https://github.com/FaresX/QInsControl.jl", "https://github.com/FaresX/QInsControl.jl")
            CImGui.Text("\n")
            CImGui.Text(stcstr("OpenGL ", mlstr("version"), " : ", unsafe_string(glGetString(GL_VERSION))))
            CImGui.Text(stcstr("JLD2 ", mlstr("version"), " : ", JLD2VERSION))
            CImGui.Text("\n")
            global JLVERINFO
            CImGui.Text(JLVERINFO)
            CImGui.Text("\n")
            CImGui.Button(stcstr(mlstr("Confirm"), "##ShowAbout"), (-1, 0)) && CImGui.CloseCurrentPopup()
            CImGui.EndPopup()
        end
    end

    global function getnewestversion()
        for _ in 1:6
            try
                maxversion = max([VersionNumber(rel.tag_name) for rel in releases("FaresX/QInsControl.jl")[1]]...)
                SYNCSTATES[Int(NewVersion)] = maxversion > QINSCONTROLVERSION
                SYNCSTATES[Int(NewVersion)] && (newversion = string(maxversion))
                break
            catch
            end
        end
        return nothing
    end
end
