let
    selectedpref::String = "通用"
    ecds::Vector{String} = encodings()
    global function Preferences(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)

        if CImGui.Begin(stcstr(MORESTYLE.Icons.Preferences, "  首选项"), p_open)
            CImGui.Columns(2)
            @cstatic firsttime::Bool = true begin
                firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.2); firsttime = false)
            end
            CImGui.BeginChild("选项", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))
            CImGui.Selectable(
                stcstr(MORESTYLE.Icons.CommonSetting, " 通用"),
                selectedpref == "通用"
            ) && (selectedpref = "通用")
            CImGui.Selectable(
                stcstr(MORESTYLE.Icons.StyleSetting, " 风格"),
                selectedpref == "风格"
            ) && (selectedpref = "风格")
            CImGui.EndChild()
            if CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " 保存"), (-1, 0))
                svconf = deepcopy(conf)
                svconf.U = Dict(up.first => string.(up.second) for up in CONF.U)
                to_toml(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"), svconf)
            end
            CImGui.NextColumn()

            CImGui.BeginChild("具体选项")
            ftsz = CImGui.GetFontSize()
            if selectedpref == "通用"
                ###Init##
                # CImGui.SetWindowFontScale(1.2)
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "基本设置")
                # CImGui.SetWindowFontScale(1)
                @c CImGui.Checkbox(CONF.Basic.isremote ? "双核" : "单核", &CONF.Basic.isremote)
                @c CImGui.Checkbox(
                    CONF.Basic.viewportenable ? "多视窗模式 开" : "多视窗模式 关",
                    &CONF.Basic.viewportenable
                )
                # io = CImGui.GetIO()
                # if conf.Basic.viewportenable
                #     io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_ViewportsEnable
                # else
                #     io.ConfigFlags = unsafe_load(io.ConfigFlags) & ~CImGui.ImGuiConfigFlags_ViewportsEnable
                # end
                CImGui.DragInt2(
                    "窗口大小",
                    CONF.Basic.windowsize,
                    2.0, 100, 4000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c ComBoS("系统编码", &CONF.Basic.encoding, ecds)
                editor = CONF.Basic.editor
                @c InputTextRSZ("文本编辑器", &editor)
                editor == "" || (CONF.Basic.editor = editor)
                # global pick_fps
                # @c CImGui.DragInt("拾取帧数", &pick_fps, 1.0, 1, 180, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.Text(" ")
                CImGui.Separator()

                ###DtViewer###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "数据浏览")
                @c CImGui.DragInt(
                    "单页数据量",
                    &CONF.DtViewer.showdatarow,
                    1, 1, 200000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                CImGui.Separator()

                ###DAQ###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "DAQ")
                @c CImGui.Checkbox("截图保存", &CONF.DAQ.saveimg)
                @c CImGui.Checkbox(CONF.DAQ.logall ? "记录全部变量" : "记录启用变量", &CONF.DAQ.logall)
                @c CImGui.Checkbox(CONF.DAQ.equalstep ? "等长采点" : "定长采点", &CONF.DAQ.equalstep)
                @c CImGui.DragInt(
                    "保存时间",
                    &CONF.DAQ.savetime,
                    1.0, 1, 180, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    "通道大小",
                    &CONF.DAQ.channel_size,
                    1.0, 4, 2048, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    "打包尺寸",
                    &CONF.DAQ.packsize,
                    1.0, 6, 120, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    "绘图列数",
                    &CONF.DAQ.plotshowcol,
                    1.0, 1, 6, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.DragInt2(
                    "拾取帧数",
                    CONF.DAQ.pick_fps,
                    1.0, 1, 180, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                CImGui.Separator()

                ###InsBuf###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "仪器设置和状态")
                @c CImGui.Checkbox("显示帮助", &CONF.InsBuf.showhelp)
                @c CImGui.DragInt(
                    "显示列数",
                    &CONF.InsBuf.showcol,
                    1.0, 1, 6, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragFloat(
                    "刷新速率",
                    &CONF.InsBuf.refreshrate,
                    0.1, 0.1, 60, "%.3f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                CImGui.Separator()

                ###Fonts###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "字体")
                fontdir = CONF.Fonts.dir
                inputfontdir = @c InputTextRSZ("路径##Fonts", &fontdir)
                CImGui.SameLine()
                selectfontdir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-dir"))
                selectfontdir && (fontdir = pick_folder(abspath(fontdir)))
                (inputfontdir || selectfontdir) && isvalidpath(fontdir; file=false) && (CONF.Fonts.dir = fontdir)
                ft1 = CONF.Fonts.first
                inputft1 = @c InputTextRSZ("字体1", &ft1)
                CImGui.SameLine()
                selectft1 = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-first"))
                selectft1 && (ft1 = basename(pick_file(joinpath(abspath(fontdir), ft1); filterlist="ttf,ttc,otf")))
                (inputft1 || selectft1) && isvalidpath(joinpath(fontdir, ft1)) && (CONF.Fonts.first = ft1)
                ft2 = CONF.Fonts.second
                inputft2 = @c InputTextRSZ("字体2", &ft2)
                CImGui.SameLine()
                selectft2 = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-second"))
                selectft2 && (ft2 = basename(pick_file(joinpath(abspath(fontdir), ft2); filterlist="ttf,ttc,otf")))
                (inputft2 || selectft2) && isvalidpath(joinpath(fontdir, ft2)) && (CONF.Fonts.second = ft2)
                @c CImGui.DragInt("字体大小", &CONF.Fonts.size, 1.0, 6, 60, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.Text(" ")
                CImGui.Separator()

                ###Icons###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "图标")
                @c CImGui.DragInt("图标大小", &CONF.Icons.size, 1.0, 6, 120, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.Text(" ")
                CImGui.Separator()

                ###Console###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "控制台")
                iodir = CONF.Console.dir
                inputiodir = @c InputTextRSZ("路径##Console", &iodir)
                CImGui.SameLine()
                selectiodir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##IO-dir"))
                selectiodir && (iodir = pick_folder(abspath(iodir)))
                (inputiodir || selectiodir) && isvalidpath(iodir; file=false) && (CONF.Console.dir = iodir)
                @c CImGui.DragFloat(
                    "刷新率##Console",
                    &CONF.Console.refreshrate,
                    1.0, 0.1, 60, "%.1f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    "显示行数##Console",
                    &CONF.Console.showioline,
                    1.0, 100, 6000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    "历史命令##Console",
                    &CONF.Console.showioline,
                    1.0, 10, 6000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                CImGui.Separator()

                ###Logs###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "日志")
                logdir = CONF.Logs.dir
                inputlogdir = @c InputTextRSZ("路径##Logs", &logdir)
                CImGui.SameLine()
                selectlogdir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Logs-dir"))
                selectlogdir && (logdir = pick_folder(abspath(logdir)))
                (inputlogdir || selectlogdir) && isvalidpath(logdir; file=false) && (CONF.Logs.dir = logdir)
                @c CImGui.DragFloat(
                    "刷新率##Logs",
                    &CONF.Logs.refreshrate,
                    1.0, 0.1, 60, "%.1f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    "显示行数##Logs",
                    &CONF.Logs.showlogline,
                    1.0, 100, 6000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                CImGui.Separator()

                ###ComAddr###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, "常用地址")
                addrs = join(CONF.ComAddr.addrs, "\n")
                y = max(1, length(CONF.ComAddr.addrs)) * CImGui.GetTextLineHeight() + 2unsafe_load(IMGUISTYLE.FramePadding.y)
                @c(InputTextMultilineRSZ(
                    "##常用地址", &addrs, (Float32(0), y))
                ) && (CONF.ComAddr.addrs = split(addrs, '\n'))
                CImGui.Text(" ")
                CImGui.Separator()

                ###U###
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
                showunitsetting = CImGui.CollapsingHeader("单位")
                CImGui.PopStyleColor()
                if showunitsetting
                    CImGui.BeginGroup()
                    CImGui.Text("     类型")
                    for (i, up) in enumerate(CONF.U)
                        ut = up.first
                        ut == "" && continue
                        CImGui.PushID(i)
                        CImGui.PushItemWidth(5ftsz)
                        if @c InputTextRSZ("##Utype", &ut)
                            if ut == "" || haskey(CONF.U, ut)
                                ut = up.first
                            else
                                newkey!(CONF.U, up.first, ut)
                            end
                        end
                        CImGui.PopItemWidth()
                        if CImGui.BeginPopupContextItem()
                            CImGui.MenuItem("删除", C_NULL, false, length(CONF.U) > 2) && (pop!(CONF.U, ut); break)
                            if CImGui.MenuItem("添加")
                                insert!(
                                    CONF.U,
                                    ut,
                                    "NU" => Union{Unitful.FreeUnits,Unitful.MixedUnits}[u"m"];
                                    after=true
                                )
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
                    for (i, up) in enumerate(CONF.U)
                        up.first == "" && continue
                        CImGui.PushID(i)
                        showonesetu(up)
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

function showonesetu(up)
    for (j, u) in enumerate(up.second)
        ustr = string(u)
        CImGui.PushID(j)
        CImGui.PushItemWidth(5CImGui.GetFontSize())
        if @c InputTextRSZ("##U", &ustr)
            uf = @trypass eval(:(@u_str($ustr))) nothing
            if !isnothing(uf) && (uf isa Unitful.FreeUnits || uf isa Unitful.MixedUnits)
                CONF.U[up.first][j] = uf
            end
        end
        CImGui.PopItemWidth()
        if !isa(up.second[1], Unitful.MixedUnits)
            if CImGui.BeginPopupContextItem()
                if CImGui.MenuItem("删除", C_NULL, false, length(up.second) > 1)
                    deleteat!(CONF.U[up.first], j)
                    break
                end
                CImGui.MenuItem("向左添加") && (insert!(CONF.U[up.first], j, u"m"); break)
                CImGui.MenuItem("向右添加") && (insert!(CONF.U[up.first], j + 1, u"m"); break)
                CImGui.EndPopup()
            end
        end
        j == length(up.second) || CImGui.SameLine()
        CImGui.PopID()
    end
end

function isvalidpath(path; file=true)
    if file ? isfile(path) : isdir(path)
        return true
    else
        CImGui.SameLine()
        CImGui.TextColored(MORESTYLE.Colors.LogError, file ? "文件不存在！！！" : "路径不存在！！！")
        return false
    end
end