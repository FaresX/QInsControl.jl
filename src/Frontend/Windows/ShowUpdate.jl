let
    global function ShowUpdate(p_open::Ref{Bool})
        CImGui.SetNextWindowSize((480, 420) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Once)
        nm = stcstr(MORESTYLE.Icons.Update, "  ", mlstr("Update"), "###update")
        begun, own, popenarg = BeginNoClose(nm, p_open)
        if begun
            phase, latest, chain, item, done, total, reason, err = lock(
                st -> (
                    st[:phase], st[:latest], copy(st[:chain]), st[:item],
                    st[:done], st[:total], st[:reason], st[:err]
                ),
                UPDSTATE
            )
            ftsz = CImGui.GetFontSize()
            CImGui.Text(stcstr(mlstr("current version"), " : ", FILEINFO["QInsControl version"]))
            CImGui.Text(stcstr(mlstr("latest version"), "  : ", latest))
            CImGui.Separator()

            if phase == :unsupported
                # 非便携安装:应用内更新不可用,引导去浏览器
                CImGui.TextColored(
                    MORESTYLE.Colors.WarnText, mlstr("in-app update is only available for the portable edition")
                )
                CImGui.TextLinkOpenURL(
                    mlstr("open release page"), "https://github.com/FaresX/QInsControl.jl/releases/latest"
                )
            elseif phase == :checking
                CImGui.TextColored(MORESTYLE.Colors.InfoText, mlstr("checking for updates..."))
            elseif phase == :failed
                CImGui.TextColored(MORESTYLE.Colors.ErrorText, stcstr(mlstr("failed"), " : ", err))
            elseif isempty(chain)
                CImGui.TextColored(
                    MORESTYLE.Colors.InfoText,
                    isempty(reason) ? mlstr("already the latest version!") : reason
                )
                CImGui.TextLinkOpenURL(
                    mlstr("open release page"), "https://github.com/FaresX/QInsControl.jl/releases/latest"
                )
            else
                ### 补丁链列表 ###
                CImGui.BeginChild(
                    "patchchain",
                    (0, -2CImGui.GetFrameHeight() - 2unsafe_load(IMGUISTYLE.ItemSpacing.y))
                )
                for (i, p) in enumerate(chain)
                    CImGui.PushID(i)
                    if phase == :downloading && i == item
                        frac = total > 0 ? clamp(done / total, 0, 1) : 0
                        ColoredProgressBarRect(
                            frac, stcstr(p.from, " → ", p.to, "  ", round(Int, 100frac), "%");
                            size = (-1, 0),
                            colbara = MORESTYLE.Colors.AccentTop,
                            colbara2 = MORESTYLE.Colors.AccentBottom
                        )
                    elseif phase == :downloaded || (phase == :downloading && i < item)
                        CImGui.TextColored(
                            MORESTYLE.Colors.InfoText,
                            stcstr(p.from, " → ", p.to, "  ", mlstr("downloaded"))
                        )
                    elseif phase == :downloading
                        CImGui.TextDisabled(stcstr(p.from, " → ", p.to))
                    else
                        CImGui.Text(stcstr(p.from, " → ", p.to))
                    end
                    CImGui.PopID()
                end
                CImGui.EndChild()

                ### 操作按钮 ###
                if phase == :downloaded
                    if ColoredButton(
                        stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("quit and install"));
                        size = (-1, 0)
                    )
                        stop() # 正常退出路径:启动器链在进程结束后应用全部补丁并重启
                    end
                    CImGui.TextColored(
                        MORESTYLE.Colors.InfoText, mlstr("patches are installed automatically after exit")
                    )
                else
                    if phase != :downloading && ColoredButton(
                        stcstr(MORESTYLE.Icons.Update, " ", mlstr("start download"))
                    )
                        startdownload!()
                    end
                    CImGui.SameLine()
                    ColoredButton(mlstr("check update")) && checkupdate!()
                end
            end

            ### 检查按钮:unsupported/checking 之外的状态都可手动重查 ###
            if phase ∉ (:unsupported, :checking) && (isempty(chain) || phase == :failed)
                CImGui.Separator()
                ColoredButton(mlstr("check update")) && checkupdate!()
            end
        end
        EndNoClose(own, p_open, popenarg)
    end
end
