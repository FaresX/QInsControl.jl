let
    show_preferences::Bool = false
    show_instr_register::Bool = false

    show_console::Bool = false
    show_metrics::Bool = false
    show_logger::Bool = false
    show_about::Bool = false

    showapp::Ref{Bool} = true

    #main window flags
    no_titlebar::Bool = true
    no_scrollbar::Bool = false
    no_menu::Bool = true
    no_move::Bool = true
    no_resize::Bool = true
    no_collapse::Bool = true
    # no_close::Bool = true
    no_nav::Bool = false
    no_background::Bool = false
    no_bring_to_front::Bool = false
    no_docking::Bool = true

    fileviewers = FileViewer[]
    dataformatters = DataFormatter[]
    instrwidgets = Dict{String,Dict{String,Tuple{Ref{Bool},Vector{InstrWidget}}}}()

    window_flags::Cint = 0
    no_titlebar && (window_flags |= CImGui.ImGuiWindowFlags_NoTitleBar)
    no_scrollbar && (window_flags |= CImGui.ImGuiWindowFlags_NoScrollbar)
    !no_menu && (window_flags |= CImGui.ImGuiWindowFlags_MenuBar)
    no_move && (window_flags |= CImGui.ImGuiWindowFlags_NoMove)
    no_resize && (window_flags |= CImGui.ImGuiWindowFlags_NoResize)
    no_collapse && (window_flags |= CImGui.ImGuiWindowFlags_NoCollapse)
    no_nav && (window_flags |= CImGui.ImGuiWindowFlags_NoNav)
    no_background && (window_flags |= CImGui.ImGuiWindowFlags_NoBackground)
    no_bring_to_front && (window_flags |= CImGui.ImGuiWindowFlags_NoBringToFrontOnFocus)
    no_docking && (window_flags |= CImGui.ImGuiWindowFlags_NoDocking)

    global isshowapp() = showapp
    global function closeallwindows()
        show_preferences = false
        show_instr_register = false

        show_console = false
        show_metrics = false
        show_logger = false
        show_about = false
        for fv in fileviewers
            fv.p_open = false
        end
        for dft in dataformatters
            dft.p_open = false
        end
        for (_, inses) in filter(x -> !isempty(x.second), INSTRBUFFERVIEWERS)
            for (_, ibv) in inses
                ibv.p_open = false
            end
        end
        empty!(instrwidgets)
        closedaqwindows()
        menuidx = 2
        showwhat = 1
    end

    selectedins::String = ""
    showst::Bool = false
    st::Bool = false
    showwhat::Cint = 0
    menuidx::Cint = 0
    global function MainWindow()
        if !CONF.Basic.hidewindow
            viewport = igGetMainViewport()
            if CONF.Basic.viewportenable
                CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
                CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
            else
                CImGui.SetNextWindowPos((0, 0))
                CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
            end
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, 0)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, (0, 0))
            CImGui.Begin("DockSpace", C_NULL, window_flags | CImGui.ImGuiWindowFlags_NoBackground)
            igDockSpace(CImGui.GetID("Main Window"), CImGui.ImVec2(0, 0), ImGuiDockNodeFlags_PassthruCentralNode, C_NULL)
            CImGui.End()
            CImGui.PopStyleVar(2)

            if CONF.Basic.holdmainwindow
                CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
                CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
            else
                CImGui.SetNextWindowSize(CONF.Basic.windowsize, CImGui.ImGuiCond_FirstUseEver)
            end
            CImGui.Begin(
                stcstr(mlstr("Main Window"), "###MainWindow"),
                C_NULL, CONF.Basic.holdmainwindow ? window_flags | CImGui.ImGuiWindowFlags_NoBringToFrontOnFocus : 0
            )
            SetWindowBgImage()
            DAQtoolbar()
            CImGui.SameLine()
            CImGui.BeginChild("main")
            CImGui.Columns(2)
            CImGui.GetFrameCount() == 1 && CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.7)
            colrate = CImGui.GetColumnOffset(1) / CImGui.GetWindowWidth()
            colrate > 0.8 && CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.8)
            colrate < 0.2 && CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.2)
            CImGui.BeginChild("left")
            DAQtasks()
            CImGui.EndChild()
            CImGui.NextColumn()
            CImGui.BeginChild("right")
            CImGui.PushFont(BIGFONT)
            isopenfiles = false
            isopenfolder = false
            isopenformatter = false
            ftsz = CImGui.GetFontSize()
            sbsz = (3ftsz / 2, CImGui.GetFrameHeight())
            CImGui.PushStyleColor(CImGui.ImGuiCol_Header, MORESTYLE.Colors.ToolBarBg)
            CImGui.PushStyleColor(CImGui.ImGuiCol_HeaderHovered, MORESTYLE.Colors.ToolBarBg)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            CImGui.Selectable(MORESTYLE.Icons.Instruments, menuidx == 0, 0, sbsz) && (menuidx = 0)
            CImGui.SameLine()
            CImGui.Selectable(MORESTYLE.Icons.File, menuidx == 1, 0, sbsz) && (menuidx = 1)
            CImGui.SameLine()
            SYNCSTATES[Int(FatalError)] && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ErrorText)
            CImGui.Selectable(MORESTYLE.Icons.Help, menuidx == 2, 0, sbsz) && (menuidx = 2)
            SYNCSTATES[Int(FatalError)] && CImGui.PopStyleColor()
            CImGui.PopStyleColor(2)
            CImGui.SameLine()
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
            @c CImGui.Selectable(MORESTYLE.Icons.Preferences, &show_preferences, 0, sbsz)
            CImGui.PopStyleColor()

            CImGui.AddRectFilled(
                CImGui.GetWindowDrawList(),
                CImGui.GetCursorScreenPos(),
                CImGui.GetCursorScreenPos() .+ (CImGui.GetWindowWidth(), CImGui.GetFrameHeight() + unsafe_load(IMGUISTYLE.ItemSpacing.y)),
                MORESTYLE.Colors.ToolBarBg
            )
            if menuidx == 0
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.InstrumentsRegister, &show_instr_register, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("Instrument Registration"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                CImGui.Selectable(MORESTYLE.Icons.CPUMonitor, showwhat == 2, 0, sbsz) && (showwhat = 2)
                CImGui.PopStyleColor()
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("Instrument CPU Monitor"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                CImGui.Selectable(MORESTYLE.Icons.InstrumentsSetting, showwhat == 0, 0, sbsz) && (showwhat = 0)
                CImGui.PopStyleColor()
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("Instrument Control"))
                CImGui.PopFont()
            elseif menuidx == 1
                showwhat = 1
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                isopenfiles = CImGui.Button(stcstr(MORESTYLE.Icons.File, "##openfiles"), sbsz)
                CImGui.PopStyleColor(2)
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("Open Files"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                isopenfolder = CImGui.Button(MORESTYLE.Icons.OpenFolder, sbsz)
                CImGui.PopStyleColor(2)
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("Open Folder"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                isopenformatter = CImGui.Button(MORESTYLE.Icons.DataFormatter, sbsz)
                CImGui.PopStyleColor(2)
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("Open Formatter"))
                CImGui.PopFont()
            elseif menuidx == 2
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.Console, &show_console, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("Console"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.Metrics, &show_metrics, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("Metrics"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                SYNCSTATES[Int(FatalError)] && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ErrorText)
                @c CImGui.Selectable(MORESTYLE.Icons.Logger, &show_logger, 0, sbsz)
                SYNCSTATES[Int(FatalError)] && CImGui.PopStyleColor()
                CImGui.PopStyleColor()
                CImGui.PushFont(GLOBALFONT)
                if SYNCSTATES[Int(FatalError)] && CImGui.BeginPopupContextItem()
                    CImGui.MenuItem(mlstr("Clear Fatal Error")) && (SYNCSTATES[Int(FatalError)] = false)
                    CImGui.EndPopup()
                end
                ItemTooltip(mlstr("Logger"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.About, &show_about, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(GLOBALFONT)
                ItemTooltip(mlstr("About"))
                CImGui.PopFont()
            end

            CImGui.PopStyleVar(2)
            CImGui.PopFont()
            CImGui.SeparatorText("")

            CImGui.BeginChild("right content")
            if showwhat == 0
                btw = 2CImGui.GetFrameHeight() + unsafe_load(IMGUISTYLE.ItemSpacing.y)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
                CImGui.BeginChild("border1", (Cfloat(0), btw + 2unsafe_load(IMGUISTYLE.WindowPadding.y)), true)
                showst |= SYNCSTATES[Int(AutoDetecting)]
                showst && CImGui.PushStyleColor(
                    CImGui.ImGuiCol_Button,
                    SYNCSTATES[Int(AutoDetecting)] ? MORESTYLE.Colors.InfoBg : st ? MORESTYLE.Colors.HighlightText : MORESTYLE.Colors.ErrorBg
                )
                igBeginDisabled(SYNCSTATES[Int(IsDAQTaskRunning)] || hassweeping())
                CImGui.Button(MORESTYLE.Icons.InstrumentsAutoDetect, (btw, btw)) && refresh_instrlist()
                showst && CImGui.PopStyleColor()
                CImGui.SameLine()
                CImGui.BeginGroup()
                CImGui.PushItemWidth(CImGui.GetContentRegionAvail().x - unsafe_load(IMGUISTYLE.ItemSpacing.x) - CImGui.GetFrameHeight())
                showst1, st1 = manualadd_from_others()
                showst2, st2 = manualadd_from_input()
                showst = showst1 || showst2
                st = st1 || st2
                CImGui.PopItemWidth()
                CImGui.EndGroup()
                igEndDisabled()
                CImGui.EndChild()

                CImGui.BeginChild("border2", (0, 0), true)
                for (ins, inses) in INSTRBUFFERVIEWERS
                    isempty(inses) && CImGui.PushStyleColor(
                        CImGui.ImGuiCol_Text, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled)
                    )
                    isrefreshingdict = Dict(addr => hasref(ibv) for (addr, ibv) in inses)
                    hasrefreshing = !isempty(inses) && SYNCSTATES[Int(IsAutoRefreshing)] && (|)(values(isrefreshingdict)...)
                    hasrefreshing && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.DAQTaskRunning)
                    insnode = CImGui.TreeNode(stcstr(INSCONF[ins].conf.icon, " ", ins, "  ", "(", length(inses), ")"))
                    hasrefreshing && CImGui.PopStyleColor()
                    if insnode
                        if isempty(inses)
                            CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
                        else
                            for (addr, ibv) in inses
                                isrefreshingdict[addr] && CImGui.PushStyleColor(
                                    CImGui.ImGuiCol_Text, MORESTYLE.Colors.DAQTaskRunning
                                )
                                addrnode = CImGui.TreeNode(addr)
                                isrefreshingdict[addr] && CImGui.PopStyleColor()
                                if CImGui.BeginPopupContextItem()
                                    sweeping = hassweeping(ibv)
                                    if CImGui.MenuItem(
                                        stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")),
                                        C_NULL,
                                        false,
                                        ins != "VirtualInstr" && !SYNCSTATES[Int(IsDAQTaskRunning)] && !sweeping
                                    )
                                        delete!(INSTRBUFFERVIEWERS[ins], addr)
                                        remotecall_fetch(addr -> logout!(CPU, addr), workers()[1], addr)
                                    end
                                    if CImGui.BeginMenu(
                                        stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add to")),
                                        ins == "Others" && !SYNCSTATES[Int(IsDAQTaskRunning)] && !sweeping
                                    )
                                        for (cfins, cf) in INSCONF
                                            cfins in ["Others", "VirtualInstr"] && continue
                                            if CImGui.MenuItem(stcstr(cf.conf.icon, " ", cfins))
                                                delete!(INSTRBUFFERVIEWERS[ins], addr)
                                                get!(INSTRBUFFERVIEWERS[cfins], addr, InstrBufferViewer(cfins, addr))
                                            end
                                        end
                                        CImGui.EndMenu()
                                    end
                                    CImGui.EndPopup()
                                end
                                if addrnode
                                    @c CImGui.MenuItem(mlstr("Common"), C_NULL, &ibv.p_open)
                                    if haskey(INSWCONF, ins)
                                        haskey(instrwidgets, addr) || (instrwidgets[addr] = Dict())
                                        for w in INSWCONF[ins]
                                            if !haskey(instrwidgets[addr], w.name)
                                                instrwidgets[addr][w.name] = (Ref(false), [])
                                            end
                                            if CImGui.MenuItem(w.name, C_NULL, instrwidgets[addr][w.name][1])
                                                if instrwidgets[addr][w.name][1][]
                                                    push!(instrwidgets[addr][w.name][2], deepcopy(w))
                                                    initialize!(only(instrwidgets[addr][w.name][2]), addr)
                                                end
                                            end
                                        end
                                    end
                                    CImGui.TreePop()
                                end
                            end
                        end
                        CImGui.TreePop()
                    end
                    isempty(inses) && CImGui.PopStyleColor()
                end
                CImGui.EndChild()
                CImGui.PopStyleVar()
                CImGui.PopStyleColor()
            elseif showwhat == 1
                filelist = filter(fv -> fv.filetree.rootpath_bnm == "", fileviewers)
                folderlist = filter(fv -> fv.filetree.rootpath_bnm != "", fileviewers)
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Files"))
                if isempty(filelist)
                    CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
                else
                    for (i, fv) in enumerate(filelist)
                        CImGui.PushID(i)
                        title = isempty(fv.filetree.filetrees) ? mlstr("no file opened") : basename(fv.filetree.filetrees[1].filepath)
                        @c CImGui.MenuItem(title, C_NULL, &fv.p_open)
                        if CImGui.BeginPopupContextItem()
                            CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Close"))) && (fv.noclose = false)
                            CImGui.EndPopup()
                        end
                        CImGui.PopID()
                    end
                end
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Folders"))
                if isempty(folderlist)
                    CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
                else
                    for (i, fv) in enumerate(folderlist)
                        CImGui.PushID(i)
                        @c CImGui.MenuItem(basename(fv.filetree.rootpath), C_NULL, &fv.p_open)
                        if CImGui.BeginPopupContextItem()
                            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Refresh")))
                                fv.filetree.filetrees = FolderFileTree(
                                    fv.filetree.rootpath,
                                    fv.filetree.selectedpathes,
                                    fv.filetree.filter,
                                    fv.filetree.valid
                                ).filetrees
                            end
                            CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Close"))) && (fv.noclose = false)
                            CImGui.EndPopup()
                        end
                        CImGui.PopID()
                    end
                end
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Formatters"))
                if isempty(dataformatters)
                    CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
                else
                    for (i, dft) in enumerate(dataformatters)
                        CImGui.PushID(i)
                        @c CImGui.MenuItem(stcstr(mlstr("Formatter"), " ", i), C_NULL, &dft.p_open)
                        if CImGui.BeginPopupContextItem()
                            CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Close"))) && (dft.noclose = false)
                            CImGui.EndPopup()
                        end
                        CImGui.PopID()
                    end
                end
            elseif showwhat == 2
                CPUMonitor()
            end
            CImGui.EndChild()

            CImGui.EndChild()
            CImGui.EndChild()

            CImGui.End()
        end

        ######子窗口######
        for (i, fv) in enumerate(fileviewers)
            fv.p_open && edit(fv, i)
        end
        for (i, fv) in enumerate(fileviewers)
            fv.noclose || (atclosefileviewer(fv); deleteat!(fileviewers, i))
        end
        for (i, dft) in enumerate(dataformatters)
            dft.p_open && edit(dft, i)
        end
        for (i, dft) in enumerate(dataformatters)
            dft.noclose || (atclosedataformatter(dft); deleteat!(dataformatters, i))
        end
        show_preferences && @c Preferences(&show_preferences)

        show_instr_register && @c InstrRegister(&show_instr_register)
        for (_, inses) in filter(x -> !isempty(x.second), INSTRBUFFERVIEWERS)
            for (addr, ibv) in inses
                ibv.p_open && edit(ibv)
                if haskey(instrwidgets, addr)
                    for (wnm, insw) in instrwidgets[addr]
                        if insw[1][]
                            edit(only(insw[2]), ibv.insbuf, addr, insw[1], wnm; usingit=true)
                        elseif !isempty(insw[2])
                            exit!(only(insw[2]), addr)
                            pop!(insw[2])
                        end
                    end
                end
            end
        end

        show_console && @c ShowConsole(&show_console)
        show_metrics && @c CImGui.ShowMetricsWindow(&show_metrics)
        show_logger && @c LogWindow(&show_logger)
        ShowAbout()
        show_about && (CImGui.OpenPopup(mlstr("About"));
        show_about = false)

        ######快捷键######
        if isopenfiles || (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyDown(ImGuiKey_O))
            Threads.@spawn @trycatch mlstr("task failed!!!") begin
                files = pick_multi_file()
                isempty(files) || push!(fileviewers, FileViewer(filetree=FolderFileTree(files)))
            end
        end
        if isopenfolder || (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyDown(ImGuiKey_K))
            Threads.@spawn @trycatch mlstr("task failed!!!") begin
                root = pick_folder()
                isdir(root) && push!(fileviewers, FileViewer(filetree=FolderFileTree(root)))
            end
        end
        if isopenformatter
            push!(dataformatters, DataFormatter())
        end
        if !isempty(ARGS)
            filepath = reencoding(ARGS[1], CONF.Basic.encoding)
            isfile(filepath) && push!(fileviewers, FileViewer(filetree=FolderFileTree([abspath(filepath)])))
            empty!(ARGS)
        end
    end
end #let

function hassweeping()
    for (_, inses) in INSTRBUFFERVIEWERS
        for (_, ibv) in inses
            hassweeping(ibv) && return true
        end
    end
    return false
end
function hassweeping(ibv::InstrBufferViewer)
    for qt in values(ibv.insbuf.quantities)
        qt isa SweepQuantity && qt.issweeping && return true
    end
    return false
end
function hasref(ibv::InstrBufferViewer)
    for qt in values(ibv.insbuf.quantities)
        SYNCSTATES[Int(IsAutoRefreshing)] && ibv.insbuf.isautorefresh && qt.isautorefresh && return true
        qt isa SweepQuantity && qt.issweeping && return true
    end
    return false
end

function atclosefileviewer(fv::FileViewer)
    for dtv in values(fv.dtviewers)
        dtv.p_open && rmplots!(dtv)
    end
end

atclosedataformatter(dft::DataFormatter) = atcloseformatdata.(dft.data)
atcloseformatdata(d::FormatData) = d.dtviewer.p_open && rmplots!(d.dtviewer)
atcloseformatdata(d::FormatDataGroup) = (atcloseformatdata.(d.data); d.dtviewer.p_open && rmplots!(d.dtviewer))
atcloseformatdata(d::FormatCodes) = nothing