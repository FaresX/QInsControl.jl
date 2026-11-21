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
                CImGui.SameLine()
                #便携版可走应用内更新(下载补丁链,退出后自动安装);弹窗先收起
                ColoredButton(stcstr(MORESTYLE.Icons.Update, " ", mlstr("Update")); colbt = [0, 0, 0, 0]) &&
                    (openupdatewindow(); CImGui.CloseCurrentPopup())
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
        #必须后台执行:渲染线程同步跑 GitHub 请求会把整个 UI 卡死数秒;
        #结果经 STATES/toast 异步呈现,渲染帧只读标志位。
        #直连 GitHub API(Downloads/libcurl):不用 GitHub.jl —— 其内部对 TLS 异常做
        #指数退避重试,代理不可达时会重试风暴刷屏;应用侧统一节奏(3 次、间隔 60s)安静放弃。
        @spawn_record "check new version" begin
            local tags = VersionNumber[]
            for i in 1:3
                try
                    buf = IOBuffer()
                    Downloads.download(
                        "https://api.github.com/repos/FaresX/QInsControl.jl/releases?per_page=100", buf;
                        headers = ["User-Agent" => "QInsControl",
                                   "Accept" => "application/vnd.github+json"])
                    body = JSON.parse(String(take!(buf)))
                    body isa AbstractVector || error("GitHub API 响应格式异常")
                    for r in body
                        (r isa AbstractDict && haskey(r, "tag_name")) || continue
                        v = try
                            VersionNumber(r["tag_name"])
                        catch
                            continue
                        end
                        push!(tags, v)
                    end
                    break
                catch e
                    i == 3 && @warn "[$(now())]\nfailed to check new version" exception = e
                    sleep(60)
                end
            end
            isempty(tags) && return nothing
            maxversion = max(tags...)
            STATES[NewVersion] = maxversion > FILEINFO["QInsControl version"]
            if STATES[NewVersion]
                newversion = string(maxversion)
                toast(:info, mlstr("new version available!"), stcstr(maxversion, "  ", mlstr("see About for details")))
            end
        end
        return nothing
    end
end
