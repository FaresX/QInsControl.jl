let
    selectedpref::String = "General"
    ecds::Vector{String} = encodings()
    global function Preferences(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)

        if CImGui.Begin(stcstr(MORESTYLE.Icons.Preferences, "  ", mlstr("Preferences"), "###pref"), p_open)
            SetWindowBgImage()
            CImGui.Columns(2)
            @cstatic firsttime::Bool = true begin
                firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.2); firsttime = false)
            end
            CImGui.BeginChild("options", (Float32(0), -2CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y)))
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            CImGui.Selectable(
                stcstr(MORESTYLE.Icons.CommonSetting, " ", mlstr("General")),
                selectedpref == "General",
                0,
                (Cfloat(0), 4CImGui.GetFrameHeight())
            ) && (selectedpref = "General")
            CImGui.Selectable(
                stcstr(MORESTYLE.Icons.StyleSetting, " ", mlstr("Style")),
                selectedpref == "Style",
                0,
                (Cfloat(0), 4CImGui.GetFrameHeight())
            ) && (selectedpref = "Style")
            CImGui.PopStyleVar()
            CImGui.EndChild()
            if CImGui.Button(
                stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")),
                (CImGui.GetColumnOffset(1) - 2unsafe_load(IMGUISTYLE.WindowPadding.x), 2CImGui.GetFrameHeight())
            )
                svconf = deepcopy(CONF)
                svconf.U = Dict(up.first => string.(up.second) for up in CONF.U)
                to_toml(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"), svconf)
            end
            CImGui.NextColumn()

            CImGui.BeginChild("specific options")
            ftsz = CImGui.GetFontSize()
            if selectedpref == "General"
                ### Basic ###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Basic Setup"))
                @c CImGui.Checkbox(
                    CONF.Basic.isremote ? mlstr("dual core") : mlstr("single core"),
                    &CONF.Basic.isremote
                )
                @c CImGui.Checkbox(
                    mlstr("remote processing data"),
                    &CONF.Basic.remoteprocessdata
                )
                @c(CImGui.Checkbox(
                    CONF.Basic.viewportenable ? mlstr("multi-viewport mode on") : mlstr("multi-viewport mode off"),
                    &CONF.Basic.viewportenable
                )) && (CONF.Basic.viewportenable || (CONF.Basic.hidewindow = false))
                @c CImGui.Checkbox(
                    CONF.Basic.scale ? mlstr("scale on") : mlstr("scale off"),
                    &CONF.Basic.scale
                )
                # if unsafe_load(CImGui.GetIO().ConfigFlags) & CImGui.ImGuiConfigFlags_ViewportsEnable == CImGui.ImGuiConfigFlags_ViewportsEnable
                #     @c CImGui.Checkbox(mlstr("hide window"), &CONF.Basic.hidewindow)
                # end
                @c CImGui.DragInt(
                    mlstr("DAQ threads"),
                    &CONF.Basic.nthreads_2,
                    1, 1, 100, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    mlstr("data processing threads"),
                    &CONF.Basic.nthreads_3,
                    1, 1, 100, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                # io = CImGui.GetIO()
                # if conf.Basic.viewportenable
                #     io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_ViewportsEnable
                # else
                #     io.ConfigFlags = unsafe_load(io.ConfigFlags) & ~CImGui.ImGuiConfigFlags_ViewportsEnable
                # end
                CImGui.DragInt2(
                    mlstr("window size"),
                    CONF.Basic.windowsize,
                    2.0, 100, 4000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c ComBoS(mlstr("system encoding"), &CONF.Basic.encoding, ecds)
                editor = CONF.Basic.editor
                @c InputTextRSZ(mlstr("text editor"), &editor)
                editor == "" || (CONF.Basic.editor = editor)
                # global pick_fps
                # @c CImGui.DragInt("拾取帧数", &pick_fps, 1.0, 1, 180, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                if @c ComBoS(mlstr("language"), &CONF.Basic.language, keys(CONF.Basic.languages))
                    loadlanguage(CONF.Basic.languages[CONF.Basic.language])
                end
                CImGui.Text(" ")
                

                ###DtViewer###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Data Viewer"))
                @c CImGui.DragInt(
                    mlstr("data amount per page"),
                    &CONF.DtViewer.showdatarow,
                    1, 1, 200000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                

                ###DAQ###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, "DAQ")
                # @c CImGui.Checkbox(mlstr("screenshot save"), &CONF.DAQ.saveimg)
                @c CImGui.Checkbox(
                    CONF.DAQ.logall ? mlstr("log all quantities") : mlstr("log enabled quantities"),
                    &CONF.DAQ.logall
                )
                @c CImGui.Checkbox(
                    CONF.DAQ.equalstep ? mlstr("equal step sampling") : mlstr("fixed step sampling"),
                    &CONF.DAQ.equalstep
                )
                @c CImGui.Checkbox(
                    CONF.DAQ.showeditplotlayout ? mlstr("show plot toolbar") : mlstr("hide plot toolbar"),
                    &CONF.DAQ.showeditplotlayout
                )
                @c CImGui.Checkbox(mlstr("Free layout"), &CONF.DAQ.freelayout)
                @c CImGui.DragInt(
                    mlstr("saving time"),
                    &CONF.DAQ.savetime,
                    1.0, 1, 180, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    mlstr("channel size"),
                    &CONF.DAQ.channel_size,
                    1.0, 4, 2048, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    mlstr("packing size"),
                    &CONF.DAQ.packsize,
                    1.0, 6, 120, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    mlstr("plot columns"),
                    &CONF.DAQ.plotshowcol,
                    1.0, 1, 6, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                # CImGui.DragInt2(
                #     mlstr("pickup frame counts"),
                #     CONF.DAQ.pick_fps,
                #     1.0, 1, 180, "%d",
                #     CImGui.ImGuiSliderFlags_AlwaysClamp
                # )
                @c CImGui.DragInt(
                    stcstr(mlstr("history blocks"), "##DAQ"),
                    &CONF.DAQ.historylen,
                    1.0, 6, 60, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c(CImGui.DragInt(
                    stcstr(mlstr("times of retrying sending commands"), "##DAQ"),
                    &CONF.DAQ.retrysendtimes,
                    1.0, 1, 60, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )) && remotecall_wait(x -> (CONF.DAQ.retrysendtimes = x), workers()[1], CONF.DAQ.retrysendtimes)
                @c(CImGui.DragInt(
                    stcstr(mlstr("times of retrying connecting"), "##DAQ"),
                    &CONF.DAQ.retryconnecttimes,
                    1.0, 1, 60, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )) && remotecall_wait(x -> (CONF.DAQ.retryconnecttimes = x), workers()[1], CONF.DAQ.retryconnecttimes)
                CImGui.Text(" ")
                

                ###InsBuf###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Instrument Settings and Status"))
                @c CImGui.Checkbox(mlstr("show help"), &CONF.InsBuf.showhelp)
                @c CImGui.DragInt(
                    mlstr("display columns"),
                    &CONF.InsBuf.showcol,
                    1.0, 1, 6, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragFloat(
                    mlstr("refresh rate"),
                    &CONF.InsBuf.refreshrate,
                    0.01, 0.01, 60, "%.2f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                

                ###Fonts###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Font"))
                fontdir = CONF.Fonts.dir
                inputfontdir = @c InputTextRSZ(stcstr(mlstr("path"), "##Fonts"), &fontdir)
                CImGui.SameLine()
                selectfontdir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-dir"))
                selectfontdir && (fontdir = pick_folder(abspath(fontdir)))
                (inputfontdir || selectfontdir) && isvalidpath(fontdir; file=false) && (CONF.Fonts.dir = fontdir)
                ft1 = CONF.Fonts.first
                inputft1 = @c InputTextRSZ(stcstr(mlstr("font"), "1"), &ft1)
                CImGui.SameLine()
                selectft1 = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-first"))
                selectft1 && (ft1 = basename(pick_file(joinpath(abspath(fontdir), ft1); filterlist="ttf,ttc,otf")))
                (inputft1 || selectft1) && isvalidpath(joinpath(fontdir, ft1)) && (CONF.Fonts.first = ft1)
                ft2 = CONF.Fonts.second
                inputft2 = @c InputTextRSZ(stcstr(mlstr("font"), "2"), &ft2)
                CImGui.SameLine()
                selectft2 = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-second"))
                selectft2 && (ft2 = basename(pick_file(joinpath(abspath(fontdir), ft2); filterlist="ttf,ttc,otf")))
                (inputft2 || selectft2) && isvalidpath(joinpath(fontdir, ft2)) && (CONF.Fonts.second = ft2)
                ftp = CONF.Fonts.plotfont
                inputftp = @c InputTextRSZ(stcstr(mlstr("plot font"), ""), &ftp)
                CImGui.SameLine()
                selectftp = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-second"))
                selectftp && (ftp = basename(pick_file(joinpath(abspath(fontdir), ftp); filterlist="ttf,ttc,otf")))
                (inputftp || selectftp) && isvalidpath(joinpath(fontdir, ftp)) && (CONF.Fonts.plotfont = ftp)
                @c CImGui.DragInt(
                    mlstr("font size"),
                    &CONF.Fonts.size, 1.0, 6, 60, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    mlstr("plot font size"),
                    &CONF.Fonts.plotfontsize, 1.0, 6, 60, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                

                ###Icons###
                # SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Icon"))
                # @c CImGui.DragInt(
                #     mlstr("icon size"),
                #     &CONF.Icons.size, 1.0, 6, 120, "%d",
                #     CImGui.ImGuiSliderFlags_AlwaysClamp
                # )
                # CImGui.Text(" ")
                # 

                ###Console###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Console"))
                iodir = CONF.Console.dir
                inputiodir = @c InputTextRSZ(stcstr(mlstr("path"), "##Console"), &iodir)
                CImGui.SameLine()
                selectiodir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##IO-dir"))
                selectiodir && (iodir = pick_folder(abspath(iodir)))
                (inputiodir || selectiodir) && isvalidpath(iodir; file=false) && (CONF.Console.dir = iodir)
                @c CImGui.DragFloat(
                    stcstr(mlstr("refresh rate"), "##Console"),
                    &CONF.Console.refreshrate,
                    1.0, 0.1, 60, "%.1f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    stcstr(mlstr("display lines"), "##Console"),
                    &CONF.Console.showioline,
                    1.0, 100, 6000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    stcstr(mlstr("history command"), "##Console"),
                    &CONF.Console.historylen,
                    1.0, 10, 6000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                

                ###Logs###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Logger"))
                logdir = CONF.Logs.dir
                inputlogdir = @c InputTextRSZ(stcstr(mlstr("path"), "##Logs"), &logdir)
                CImGui.SameLine()
                selectlogdir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Logs-dir"))
                selectlogdir && (logdir = pick_folder(abspath(logdir)))
                (inputlogdir || selectlogdir) && isvalidpath(logdir; file=false) && (CONF.Logs.dir = logdir)
                @c CImGui.DragFloat(
                    stcstr(mlstr("refresh rate"), "##Logs"),
                    &CONF.Logs.refreshrate,
                    1.0, 0.1, 60, "%.1f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    stcstr(mlstr("display lines"), "##Logs"),
                    &CONF.Logs.showlogline,
                    1.0, 100, 6000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    stcstr(mlstr("display length"), "##Logs"),
                    &CONF.Logs.showloglength,
                    1.0, 100, 100000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")
                

                ###ComAddr###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Common Address"))
                addrs = join(CONF.ComAddr.addrs, "\n")
                y = max(1, length(CONF.ComAddr.addrs)) * CImGui.GetTextLineHeight() +
                    2unsafe_load(IMGUISTYLE.FramePadding.y)
                if @c InputTextMultilineRSZ("##common address", &addrs, (Float32(0), y))
                    CONF.ComAddr.addrs = split(addrs, '\n')
                    for (i, addr) in enumerate(CONF.ComAddr.addrs)
                        rstrip(addr, ' ') == "" && deleteat!(CONF.ComAddr.addrs, i)
                    end
                end
                CImGui.Text(" ")
                

                ###U###
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
                showunitsetting = CImGui.CollapsingHeader(mlstr("Unit"))
                CImGui.PopStyleColor()
                if showunitsetting
                    CImGui.BeginGroup()
                    CImGui.Text(stcstr("     ", mlstr("type")))
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
                            CImGui.MenuItem(
                                stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")),
                                C_NULL, false, length(CONF.U) > 2
                            ) && (pop!(CONF.U, ut); break)
                            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add")))
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
                    CImGui.Text(stcstr("   ", mlstr("unit set")))
                    for (i, up) in enumerate(CONF.U)
                        up.first == "" && continue
                        CImGui.PushID(i)
                        showonesetu(up)
                        CImGui.PopID()
                    end
                    CImGui.EndGroup()
                end
            elseif selectedpref == "Style"
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
                if CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")),
                    C_NULL, false, length(up.second) > 1
                )
                    deleteat!(CONF.U[up.first], j)
                    break
                end
                CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add Left"))
                ) && (insert!(CONF.U[up.first], j, u"m"); break)
                CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add Right"))
                ) && (insert!(CONF.U[up.first], j + 1, u"m"); break)
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
        CImGui.TextColored(
            MORESTYLE.Colors.LogError, file ? mlstr("file does not exist!!!") : mlstr("path does not exist!!!")
        )
        return false
    end
end