let
    newversion::String = ""
    hasnewversiontime::Float64 = 0
    global function ShowAbout()
        if CImGui.BeginPopupModal(mlstr("About"), C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            ftsz = CImGui.GetFontSize()
            ww = CImGui.GetWindowWidth()
            CImGui.SetCursorPos(ww / 3, CImGui.GetCursorPosY())
            CImGui.Image(ICONID, (ww / 3, ww / 3))
            CImGui.PushFont(C_NULL, MORESTYLE.Variables.BigIconSize)
            CImGui.SetCursorPos(
                CImGui.GetCursorPos() .+
                ((CImGui.GetContentRegionAvail().x - CImGui.CalcTextSize("QInsControl").x) / 2, ftsz)
            )
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, "QInsControl\n")
            CImGui.PopFont()
            CImGui.Text(stcstr(mlstr("version"), " : ", FILEINFO["QInsControl version"]))
            CImGui.SameLine()
            if STATES[NewVersion]
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("New version!"))
                CImGui.SameLine()
                CImGui.TextLinkOpenURL(newversion, "https://github.com/FaresX/QInsControl.jl/releases/latest")
            else
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, (0, 0))
                ColoredButton(MORESTYLE.Icons.Update; colbt=[0, 0, 0, 0]) && (getnewestversion(); hasnewversiontime = time())
                CImGui.PopStyleVar(2)

                if !STATES[NewVersion] && time() - hasnewversiontime < 4
                    CImGui.SameLine()
                    # CImGui.SetCursorPosY(CImGui.GetCursorPosY() - 4)
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
            CImGui.Text(stcstr("JLD2 ", mlstr("version"), " : ", FILEINFO["JLD2 version"]))
            CImGui.Text("\n")
            CImGui.Text(FILEINFO["Julia version"])
            CImGui.Text("\n")
            CImGui.Button(stcstr(mlstr("Confirm"), "##ShowAbout"), (-1, 0)) && CImGui.CloseCurrentPopup()
            CImGui.EndPopup()
        end
    end

    global function getnewestversion()
        #必须后台执行:渲染线程同步跑 GitHub 请求(最多 6 次重试)会把整个 UI 卡死数秒;
        #结果经 STATES/toast 异步呈现,渲染帧只读标志位
        @spawn_record "check new version" begin
            for i in 1:6
                try
                    maxversion = max([VersionNumber(rel.tag_name) for rel in releases("FaresX/QInsControl.jl")[1]]...)
                    STATES[NewVersion] = maxversion > FILEINFO["QInsControl version"]
                    if STATES[NewVersion]
                        newversion = string(maxversion)
                        toast(:info, mlstr("new version available!"), stcstr(maxversion, "  ", mlstr("see About for details")))
                    end
                    break
                catch e
                    i == 6 && @warn "[$(now())]\nfailed to check new version" exception = e
                    sleep(1)
                end
            end
        end
        return nothing
    end
end
