let
    selectedpref::String = "General"
    ecds::Vector{String} = encodings()
    datatypes::Vector{String} = ["String", "Float16", "Float32", "Float64"]
    global function Preferences(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)

        CImGui.PushStyleColor(CImGui.ImGuiCol_Separator, (0, 0, 0, 0))
        if CImGui.Begin(stcstr(MORESTYLE.Icons.Preferences, "  ", mlstr("Preferences"), "###pref"), p_open)
            CImGui.PopStyleColor()
            SetWindowBgImage()

            CImGui.Columns(2)
            @cstatic firsttime::Bool = true begin
                firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.2); firsttime = false)
            end
            CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, MORESTYLE.Colors.ToolBarBg)
            CImGui.BeginChild("Toolbar")
            CImGui.PopStyleColor()
            width = CImGui.GetContentRegionAvail().x
            ftsz = CImGui.GetFontSize()
            CImGui.SameLine((width - 6ftsz) / 2)
            CImGui.SetCursorPos((width - 6ftsz) / 2, ftsz)
            CImGui.Image(Ptr{Cvoid}(ICONID), (6ftsz, 6ftsz))
            CImGui.SetCursorPosY(8ftsz)

            CImGui.BeginChild("Options", (Cfloat(0), -2CImGui.GetFrameHeight() - 2unsafe_load(IMGUISTYLE.ItemSpacing.y)))
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

            CImGui.SetCursorPosY(
                CImGui.GetWindowHeight() - 2CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y)
            )
            CImGui.Separator()
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
            if CImGui.Button(
                stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")),
                (Cfloat(-1), 2CImGui.GetFrameHeight())
            )
                svconf = deepcopy(CONF)
                svconf.U = Dict(up.first => string.(up.second) for up in CONF.U)
                @trycatch mlstr("saving configurations failed!!!") begin
                    to_toml(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"), svconf)
                    !isinteractive() && open(joinpath(ENV["QInsControlAssets"], "Necessity/threads.cmd"), "w") do file
                        write(file, string("set JULIA_NUM_THREADS=", CONF.Basic.nthreads))
                    end
                end
            end
            CImGui.PopStyleColor()
            CImGui.EndChild()

            CImGui.NextColumn()

            CImGui.BeginChild("specific options")
            ftsz = CImGui.GetFontSize()
            if selectedpref == "General"
                ftsz = CImGui.GetFontSize()
                ### Basic ###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Basic Setup"))
                @c(CImGui.Checkbox(
                    CONF.Basic.viewportenable ? mlstr("multi-viewport mode on") : mlstr("multi-viewport mode off"),
                    &CONF.Basic.viewportenable
                )) 
                #&& (CONF.Basic.viewportenable || (CONF.Basic.hidewindow = false))
                @c CImGui.Checkbox(mlstr("hold main window"), &CONF.Basic.holdmainwindow)
                # @c CImGui.Checkbox(
                #     CONF.Basic.scale ? mlstr("scale on") : mlstr("scale off"),
                #     &CONF.Basic.scale
                # )
                # if unsafe_load(CImGui.GetIO().ConfigFlags) & CImGui.ImGuiConfigFlags_ViewportsEnable == CImGui.ImGuiConfigFlags_ViewportsEnable
                #     @c CImGui.Checkbox(mlstr("hide window"), &CONF.Basic.hidewindow)
                # end
                @c RadioButton2(mlstr("dual core"), mlstr("single core"), &CONF.Basic.isremote; local_pos_x=12ftsz)
                !isinteractive() && @c(CImGui.DragInt(
                    mlstr("threads"),
                    &CONF.Basic.nthreads,
                    1, 1, 100, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                ))
                @c CImGui.DragInt(
                    mlstr("DAQ threads"),
                    &CONF.Basic.nthreads_2,
                    1, 1, 100, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                # @c CImGui.DragInt(
                #     mlstr("no action swap interval"),
                #     &CONF.Basic.noactionswapinterval,
                #     1, 1, 12, "%d",
                #     CImGui.ImGuiSliderFlags_AlwaysClamp
                # )
                # io = CImGui.GetIO()
                # if conf.Basic.viewportenable
                #     io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_ViewportsEnable
                # else
                #     io.ConfigFlags = unsafe_load(io.ConfigFlags) & ~CImGui.ImGuiConfigFlags_ViewportsEnable
                # end
                # @c CImGui.DragInt(
                #     mlstr("sampling threshold"),
                #     &CONF.Basic.samplingthreshold,
                #     100, 10000, 1000000, "%d",
                #     CImGui.ImGuiSliderFlags_AlwaysClamp
                # )
                CImGui.DragInt2(
                    mlstr("window size"),
                    CONF.Basic.windowsize,
                    2.0, 100, 4000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c ComboS(mlstr("system encoding"), &CONF.Basic.encoding, ecds)
                editor = CONF.Basic.editor
                @c InputTextRSZ(mlstr("text editor"), &editor)
                editor == "" || (CONF.Basic.editor = editor)
                if @c ComboS(mlstr("language"), &CONF.Basic.language, keys(CONF.Basic.languages))
                    loadlanguage(CONF.Basic.languages[CONF.Basic.language])
                end
                CImGui.Text(" ")

                ### Communication ###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Communication"))
                visapath = CONF.Communication.visapath
                inputvisapath = @c InputTextRSZ("##visa path", &visapath)
                CImGui.SameLine()
                selectvisapath = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##visapath"))
                CImGui.SameLine()
                autovisapath = CImGui.Button(stcstr(MORESTYLE.Icons.InstrumentsManualRef, "##visapath"))
                CImGui.SameLine()
                CImGui.Text(mlstr("visa path"))
                selectvisapath && (visapath = pick_file(abspath(visapath)))
                autovisapath && (visapath = QInsControlCore.find_visa())
                if inputvisapath || selectvisapath || autovisapath
                    isvalidpath(visapath) && (CONF.Communication.visapath = visapath)
                    if isfile(CONF.Communication.visapath)
                        QInsControlCore.Instruments.libvisa = CONF.Communication.visapath
                        remotecall_wait(workers()[1], CONF.Communication.visapath) do visapath
                            CONF.Communication.visapath = visapath
                            QInsControlCore.Instruments.libvisa = visapath
                        end
                    end
                end
                CImGui.Text(" ")

                ### DtViewer ###
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
                @c(RadioButton2(
                    mlstr("log all quantities"), mlstr("log enabled quantities"), &CONF.DAQ.logall;
                    local_pos_x=12ftsz
                )) && remotecall_wait(x -> CONF.DAQ.logall = x, workers()[1], CONF.DAQ.logall)
                @c(RadioButton2(
                    mlstr("equal step sampling"), mlstr("fixed step sampling"), &CONF.DAQ.equalstep;
                    local_pos_x=12ftsz
                )) && remotecall_wait(x -> CONF.DAQ.equalstep = x, workers()[1], CONF.DAQ.equalstep)
                @c RadioButton2(mlstr("eval in Main"), mlstr("eval in QInsControl"), &CONF.DAQ.externaleval; local_pos_x=12ftsz)
                @c ComboS(mlstr("stored data type"), &CONF.DAQ.savetype, datatypes)
                @c CImGui.DragInt(
                    stcstr(mlstr("saving time"), " (h)"),
                    &CONF.DAQ.savetime,
                    1.0, 1, 24, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    mlstr("file-cutting length"),
                    &CONF.DAQ.cuttingfile,
                    100, 100, 10000000, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c(CImGui.DragInt(
                    mlstr("channel size"),
                    &CONF.DAQ.channelsize,
                    1.0, 4, 2048, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )) && remotecall_wait(x -> (CONF.DAQ.channelsize = x), workers()[1], CONF.DAQ.channelsize)
                @c(CImGui.DragInt(
                    mlstr("packing size"),
                    &CONF.DAQ.packsize,
                    1.0, 6, 2048, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )) && remotecall_wait(x -> (CONF.DAQ.packsize = x), workers()[1], CONF.DAQ.packsize)
                @c(CImGui.DragInt(
                    mlstr("controller buffer size"),
                    &CONF.DAQ.ctbuflen,
                    1.0, 1, 1024, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )) && remotecall_wait(x -> (CONF.DAQ.ctbuflen = x), workers()[1], CONF.DAQ.ctbuflen)
                @c(CImGui.DragFloat(
                    stcstr(mlstr("controller timeout"), " (s)"),
                    &CONF.DAQ.cttimeout,
                    0.1, 0.1, 240, "%.1f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )) && remotecall_wait(x -> (CONF.DAQ.cttimeout = x), workers()[1], CONF.DAQ.cttimeout)
                @c CImGui.DragInt(
                    stcstr(mlstr("history blocks"), "##DAQ"),
                    &CONF.DAQ.historylen,
                    1.0, 6, 1200, "%d",
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
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Instrument Control"))
                @c(CImGui.Checkbox(
                    mlstr("read after sweeping"), &CONF.InsBuf.retreading)
                ) && remotecall_wait(x -> (CONF.InsBuf.retreading = x), workers()[1], CONF.InsBuf.retreading)
                @c CImGui.Checkbox(mlstr("show help"), &CONF.InsBuf.showhelp)
                @c CImGui.DragInt(
                    mlstr("display columns"),
                    &CONF.InsBuf.showcol,
                    1.0, 1, 6, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")

                ###Register###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Instrument Registration"))
                @c CImGui.DragInt(
                    stcstr(mlstr("history widgets"), "##Register"),
                    &CONF.Register.historylen,
                    1.0, 6, 1200, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")

                ###Fonts###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Font"))
                fontdir = CONF.Fonts.dir
                inputfontdir = @c InputTextRSZ("##Fonts", &fontdir)
                CImGui.SameLine()
                selectfontdir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-dir"))
                CImGui.SameLine()
                CImGui.Text(mlstr("path"))
                selectfontdir && (fontdir = pick_folder(abspath(fontdir)))
                (inputfontdir || selectfontdir) && isvalidpath(fontdir; file=false) && (CONF.Fonts.dir = fontdir)
                ft1 = CONF.Fonts.first
                inputft1 = @c InputTextRSZ("##font1", &ft1)
                CImGui.SameLine()
                selectft1 = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-first"))
                CImGui.SameLine()
                CImGui.Text(stcstr(mlstr("font"), " ", 1))
                selectft1 && (ft1 = basename(pick_file(joinpath(abspath(fontdir), ft1); filterlist="ttf,ttc,otf")))
                (inputft1 || selectft1) && isvalidpath(joinpath(fontdir, ft1)) && (CONF.Fonts.first = ft1)
                ft2 = CONF.Fonts.second
                inputft2 = @c InputTextRSZ("##font2", &ft2)
                CImGui.SameLine()
                selectft2 = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-second"))
                CImGui.SameLine()
                CImGui.Text(stcstr(mlstr("font"), " ", 2))
                selectft2 && (ft2 = basename(pick_file(joinpath(abspath(fontdir), ft2); filterlist="ttf,ttc,otf")))
                (inputft2 || selectft2) && isvalidpath(joinpath(fontdir, ft2)) && (CONF.Fonts.second = ft2)
                ftp = CONF.Fonts.bigfont
                inputftp = @c InputTextRSZ("##bigfont", &ftp)
                CImGui.SameLine()
                selectftp = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Fonts-plot"))
                CImGui.SameLine()
                CImGui.Text(mlstr("big font"))
                selectftp && (ftp = basename(pick_file(joinpath(abspath(fontdir), ftp); filterlist="ttf,ttc,otf")))
                (inputftp || selectftp) && isvalidpath(joinpath(fontdir, ftp)) && (CONF.Fonts.bigfont = ftp)
                @c CImGui.DragInt(
                    mlstr("font size"),
                    &CONF.Fonts.size, 1.0, 6, 60, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    mlstr("big font size"),
                    &CONF.Fonts.plotfontsize, 1.0, 6, 60, "%d",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.Text(" ")

                ###Console###
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Console"))
                iodir = CONF.Console.dir
                inputiodir = @c InputTextRSZ("##Console", &iodir)
                CImGui.SameLine()
                selectiodir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##IO-dir"))
                CImGui.SameLine()
                CImGui.Text(mlstr("path"))
                selectiodir && (iodir = pick_folder(abspath(iodir)))
                (inputiodir || selectiodir) && isvalidpath(iodir; file=false) && (CONF.Console.dir = iodir)
                @c CImGui.DragFloat(
                    stcstr(mlstr("refresh rate"), " (s)##Console"),
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
                    stcstr(mlstr("display length"), "##Console"),
                    &CONF.Console.showiolength,
                    1.0, 100, 100000, "%d",
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
                inputlogdir = @c InputTextRSZ("##Logs", &logdir)
                CImGui.SameLine()
                selectlogdir = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##Logs-dir"))
                CImGui.SameLine()
                CImGui.Text(mlstr("path"))
                selectlogdir && (logdir = pick_folder(abspath(logdir)))
                (inputlogdir || selectlogdir) && isvalidpath(logdir; file=false) && (CONF.Logs.dir = logdir)
                @c CImGui.DragFloat(
                    stcstr(mlstr("refresh rate"), " (s)##Logs"),
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
                # CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
                # showunitsetting = CImGui.CollapsingHeader(mlstr("Unit"))
                # CImGui.PopStyleColor()
                # if showunitsetting
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Unit"))
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
                # end
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