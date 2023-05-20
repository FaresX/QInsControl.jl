let
    selectedpref::String = "通用"
    ecds::Vector{String} = encodings()
    global function Preferences(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)

        if CImGui.Begin(morestyle.Icons.Preferences * "  首选项", p_open)
            CImGui.Columns(2)
            @cstatic firsttime::Bool = true begin
                firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.2); firsttime = false)
            end
            CImGui.BeginChild("选项", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))
            CImGui.Selectable(morestyle.Icons.CommonSetting * " 通用", selectedpref == "通用") && (selectedpref = "通用")
            CImGui.Selectable(morestyle.Icons.StyleSetting * " 风格", selectedpref == "风格") && (selectedpref = "风格")
            CImGui.EndChild()
            if CImGui.Button(morestyle.Icons.SaveButton * " 保存", (-1, 0))
                svconf = deepcopy(conf)
                svconf.U = Dict(up.first => string.(up.second) for up in conf.U)
                to_toml(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"), svconf)
            end
            CImGui.NextColumn()

            CImGui.BeginChild("具体选项")
            ftsz = CImGui.GetFontSize()
            if selectedpref == "通用"
                ###Init##
                # CImGui.SetWindowFontScale(1.2)
                CImGui.TextColored(morestyle.Colors.HighlightText, "初始化")
                # CImGui.SetWindowFontScale(1)
                if conf.Init.isremote
                    @c CImGui.Checkbox("双核", &conf.Init.isremote)
                else
                    @c CImGui.Checkbox("单核", &conf.Init.isremote)
                end
                if conf.Init.viewportenable
                    @c CImGui.Checkbox("视窗模式 开", &conf.Init.viewportenable)
                else
                    @c CImGui.Checkbox("视窗模式 关", &conf.Init.viewportenable)
                end
                CImGui.DragInt2("窗口大小", conf.Init.windowsize, 2.0, 100, 4000, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                @c ComBoS("系统编码", &conf.Init.encoding, ecds)
                editor = conf.Init.editor
                @c InputTextRSZ("文本编辑器", &editor)
                editor == "" || (conf.Init.editor = editor)
                CImGui.Text(" ")
                CImGui.Separator()

                ###DAQ###
                CImGui.TextColored(morestyle.Colors.HighlightText, "DAQ")
                @c CImGui.DragInt("保存时间", &conf.DAQ.savetime, 1.0, 1, 180, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                @c CImGui.DragInt("通道大小", &conf.DAQ.channel_size, 1.0, 4, 2048, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                @c CImGui.DragInt("打包尺寸", &conf.DAQ.packsize, 1.0, 6, 120, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                @c CImGui.DragInt("绘图列数", &conf.DAQ.plotshowcol, 1.0, 1, 6, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.Text(" ")
                CImGui.Separator()

                ###InsBuf###
                CImGui.TextColored(morestyle.Colors.HighlightText, "仪器设置和状态")
                @c CImGui.Checkbox("显示帮助", &conf.InsBuf.showhelp)
                @c CImGui.DragInt("显示列数", &conf.InsBuf.showcol, 1.0, 1, 6, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                @c CImGui.DragFloat("刷新速率", &conf.InsBuf.refreshrate, 0.1, 0.1, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.Text(" ")
                CImGui.Separator()

                ###Fonts###
                CImGui.TextColored(morestyle.Colors.HighlightText, "字体")
                fontdir = conf.Fonts.dir
                inputfontdir = @c InputTextRSZ("路径##Fonts", &fontdir)
                CImGui.SameLine()
                selectfontdir = CImGui.Button(morestyle.Icons.SelectPath * "##Fonts-dir")
                selectfontdir && (fontdir = pick_folder(abspath(fontdir)))
                if inputfontdir || selectfontdir
                    if isdir(fontdir)
                        conf.Fonts.dir = fontdir
                    else
                        CImGui.SameLine()
                        CImGui.TextColored(morestyle.Colors.LogError, "路径不存在！！！")
                    end
                end
                ft1 = conf.Fonts.first
                inputft1 = @c InputTextRSZ("字体1", &ft1)
                CImGui.SameLine()
                selectft1 = CImGui.Button(morestyle.Icons.SelectPath * "##Fonts-first")
                selectft1 && (ft1 = basename(pick_file(joinpath(abspath(fontdir), ft1); filterlist="ttf,ttc,otf")))
                if inputft1 || selectft1
                    if isfile(joinpath(fontdir, ft1))
                        conf.Fonts.first = ft1
                    else
                        CImGui.SameLine()
                        CImGui.TextColored(morestyle.Colors.LogError, "文件不存在！！！")
                    end
                end
                ft2 = conf.Fonts.second
                inputft2 = @c InputTextRSZ("字体2", &ft2)
                CImGui.SameLine()
                selectft2 = CImGui.Button(morestyle.Icons.SelectPath * "##Fonts-second")
                selectft2 && (ft2 = basename(pick_file(joinpath(abspath(fontdir), ft2); filterlist="ttf,ttc,otf")))
                if inputft2 || selectft2
                    if isfile(joinpath(fontdir, ft2))
                        conf.Fonts.second = ft2
                    else
                        CImGui.SameLine()
                        CImGui.TextColored(morestyle.Colors.LogError, "文件不存在！！！")
                    end
                end
                @c CImGui.DragInt("字体大小", &conf.Fonts.size, 1.0, 6, 60, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.Text(" ")
                CImGui.Separator()

                ###Icons###
                CImGui.TextColored(morestyle.Colors.HighlightText, "图标")
                @c CImGui.DragInt("图标大小", &conf.Icons.size, 1.0, 6, 120, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.Text(" ")
                CImGui.Separator()

                ###Logs###
                CImGui.TextColored(morestyle.Colors.HighlightText, "日志")
                logdir = conf.Logs.dir
                inputlogdir = @c InputTextRSZ("路径##Logs", &logdir)
                CImGui.SameLine()
                selectlogdir = CImGui.Button(morestyle.Icons.SelectPath * "##Logs-dir")
                selectlogdir && (logdir = pick_folder(abspath(logdir)))
                if inputlogdir || selectlogdir
                    if isdir(logdir)
                        conf.Logs.dir = logdir
                    else
                        CImGui.SameLine()
                        CImGui.TextColored(morestyle.Colors.LogError, "路径不存在！！！")
                    end
                end
                @c CImGui.DragInt("刷新率", &conf.Logs.refreshrate, 1.0, 0, 60, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                @c CImGui.DragInt("显示行数", &conf.Logs.showlogline, 1.0, 100, 6000, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.Text(" ")
                CImGui.Separator()

                ###Icon###
                # CImGui.TextColored(morestyle.Colors.HighlightText, "图标")
                # path = conf["Icon"]["path"]
                # @c InputTextRSZ("路径##Icon-path", &path); CImGui.SameLine()
                # CImGui.Button("选择##Icon-path") && (path = pick_file(abspath(path); filterlist="ico"))
                # if isfile(path)
                #     conf["Icon"]["path"] = path
                # else
                #     CImGui.SameLine(); CImGui.TextColored(morestyle.logerrorcol, "文件不存在！！！")
                # end
                # CImGui.Text(" ")
                # CImGui.Separator()

                ###BGImage###
                CImGui.TextColored(morestyle.Colors.HighlightText, "背景")
                bgpath = conf.BGImage.path
                inputbgpath = @c InputTextRSZ("路径##BGImage-path", &bgpath)
                CImGui.SameLine()
                selectbgpath = CImGui.Button(morestyle.Icons.SelectPath * "##BGImage-path")
                selectbgpath && (bgpath = pick_file(abspath(bgpath); filterlist="png,jpg,jpeg,tif,bmp"))
                if inputbgpath || selectbgpath
                    if isfile(bgpath)
                        try
                            bgimg = RGB.(transposeimg(FileIO.load(bgpath)))
                            conf.BGImage.path = bgpath
                            bgsize = size(bgimg)
                            global bgid = ImGui_ImplOpenGL3_CreateImageTexture(bgsize...)
                            ImGui_ImplOpenGL3_UpdateImageTexture(bgid, bgimg, bgsize...)
                        catch e
                            @error "[$(now())]\n加载背景出错！！！" exception = e
                        end
                    else
                        CImGui.SameLine()
                        CImGui.TextColored(morestyle.Colors.LogError, "文件不存在！！！")
                    end
                end
                CImGui.Text(" ")
                CImGui.Separator()

                ###ComAddr###
                CImGui.TextColored(morestyle.Colors.HighlightText, "常用地址")
                addrs = join(conf.ComAddr.addrs, "\n")
                y = length(conf.ComAddr.addrs) * CImGui.GetTextLineHeight() + 2unsafe_load(imguistyle.FramePadding.y)
                @c(InputTextMultilineRSZ("##常用地址", &addrs, (Float32(0), y))) && (conf.ComAddr.addrs = split(addrs, '\n'))
                CImGui.Text(" ")
                CImGui.Separator()

                ###U###
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, morestyle.Colors.HighlightText)
                showunitsetting = CImGui.CollapsingHeader("单位")
                CImGui.PopStyleColor()
                # if showunitsetting
                #     CImGui.Text("      类型")
                #     CImGui.SameLine(0, 5ftsz)
                #     CImGui.Text("单位集")
                #     for (i, up) in enumerate(conf.U)
                #         ut = up.first
                #         ut == "" && continue
                #         CImGui.PushID(i)
                #         CImGui.PushItemWidth(5ftsz)
                #         if @c InputTextRSZ("##Utype", &ut)
                #             if ut == "" || haskey(conf.U, ut)
                #                 ut = up.first
                #             else
                #                 newkey!(conf.U, up.first, ut)
                #             end
                #         end
                #         CImGui.PopItemWidth()
                #         if CImGui.BeginPopupContextItem()
                #             CImGui.MenuItem("删除", C_NULL, false, length(conf.U) > 2) && (pop!(conf.U, ut); break)
                #             CImGui.MenuItem("添加") && insert!(conf.U, ut, "NU" => Union{Unitful.FreeUnits,Unitful.MixedUnits}[u"m"], after=true)
                #             CImGui.EndPopup()
                #         end
                #         CImGui.SameLine()
                #         CImGui.Text("  =>  ")
                #         CImGui.SameLine()
                #         for (j, u) in enumerate(up.second)
                #             ustr = string(u)
                #             CImGui.PushID(j)
                #             CImGui.PushItemWidth(5ftsz)
                #             if @c InputTextRSZ("##U", &ustr)
                #                 uf = @trypass eval(:(@u_str($ustr))) nothing
                #                 !isnothing(uf) && (uf isa Unitful.FreeUnits || uf isa Unitful.MixedUnits) && (conf.U[ut][j] = uf)
                #             end
                #             CImGui.PopItemWidth()
                #             if !isa(up.second[1], Unitful.MixedUnits)
                #                 if CImGui.BeginPopupContextItem()
                #                     CImGui.MenuItem("删除", C_NULL, false, length(up.second) > 1) && (deleteat!(conf.U[ut], j); break)
                #                     CImGui.MenuItem("向左添加") && (insert!(conf.U[ut], j, u"m"); break)
                #                     CImGui.MenuItem("向右添加") && (insert!(conf.U[ut], j + 1, u"m"); break)
                #                     CImGui.EndPopup()
                #                 end
                #             end
                #             j == length(up.second) || CImGui.SameLine()
                #             CImGui.PopID()
                #         end
                #         CImGui.PopID()
                #     end
                # end
                if showunitsetting
                    CImGui.BeginGroup()
                    CImGui.Text("     类型")
                    for (i, up) in enumerate(conf.U)
                        ut = up.first
                        ut == "" && continue
                        CImGui.PushID(i)
                        CImGui.PushItemWidth(5ftsz)
                        if @c InputTextRSZ("##Utype", &ut)
                            if ut == "" || haskey(conf.U, ut)
                                ut = up.first
                            else
                                newkey!(conf.U, up.first, ut)
                            end
                        end
                        CImGui.PopItemWidth()
                        if CImGui.BeginPopupContextItem()
                            CImGui.MenuItem("删除", C_NULL, false, length(conf.U) > 2) && (pop!(conf.U, ut); break)
                            if CImGui.MenuItem("添加")
                                insert!(conf.U, ut, "NU" => Union{Unitful.FreeUnits,Unitful.MixedUnits}[u"m"], after=true)
                            end
                            CImGui.EndPopup()
                        end
                        CImGui.SameLine()
                        CImGui.Text("  =>  ")
                        CImGui.PopID()
                    end
                    CImGui.EndGroup()
                    CImGui.SameLine()
                    CImGui.BeginGroup()
                    CImGui.Text("   单位集")
                    for (i, up) in enumerate(conf.U)
                        up.first == "" && continue
                        CImGui.PushID(i)
                        for (j, u) in enumerate(up.second)
                            ustr = string(u)
                            CImGui.PushID(j)
                            CImGui.PushItemWidth(5ftsz)
                            if @c InputTextRSZ("##U", &ustr)
                                uf = @trypass eval(:(@u_str($ustr))) nothing
                                if !isnothing(uf) && (uf isa Unitful.FreeUnits || uf isa Unitful.MixedUnits)
                                    conf.U[up.first][j] = uf
                                end
                            end
                            CImGui.PopItemWidth()
                            if !isa(up.second[1], Unitful.MixedUnits)
                                if CImGui.BeginPopupContextItem()
                                    if CImGui.MenuItem("删除", C_NULL, false, length(up.second) > 1)
                                        deleteat!(conf.U[up.first], j)
                                        break
                                    end
                                    CImGui.MenuItem("向左添加") && (insert!(conf.U[up.first], j, u"m"); break)
                                    CImGui.MenuItem("向右添加") && (insert!(conf.U[up.first], j + 1, u"m"); break)
                                    CImGui.EndPopup()
                                end
                            end
                            j == length(up.second) || CImGui.SameLine()
                            CImGui.PopID()
                        end
                        CImGui.PopID()
                    end
                    CImGui.EndGroup()
                end
            elseif selectedpref == "风格"
                StyleEditor()
            end
            CImGui.EndChild()
        end
        CImGui.End()
    end
end # let