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

    dtviewers = Tuple{DataViewer,FolderFileTree,Dict{String,Bool}}[]
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
    global function closeallwindow()
        show_preferences = false
        show_instr_register = false

        show_console = false
        show_metrics = false
        show_logger = false
        show_about = false
        for dtv in dtviewers
            dtv[1].p_open = false
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
    end

    selectedins::String = ""
    showst::Bool = false
    st::Bool = false
    showwhat::Cint = 0
    menuidx::Cint = 0
    global function MainWindow()
        if !CONF.Basic.hidewindow
            viewport = igGetMainViewport()
            CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
            CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
            CImGui.Begin("Wallpaper", C_NULL, window_flags | CImGui.ImGuiWindowFlags_NoBringToFrontOnFocus)
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
            CImGui.PushFont(PLOTFONT)
            isopenfiles = false
            isopenfolder = false
            isopenformatter = false
            ftsz = CImGui.GetFontSize()
            sbsz = (3ftsz / 2, CImGui.GetFrameHeight())
            CImGui.PushStyleColor(CImGui.ImGuiCol_Header, MORESTYLE.Colors.ToolBarBg)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            CImGui.Selectable(MORESTYLE.Icons.Instruments, menuidx == 0, 0, sbsz) && (menuidx = 0)
            CImGui.SameLine()
            CImGui.Selectable(MORESTYLE.Icons.File, menuidx == 1, 0, sbsz) && (menuidx = 1)
            CImGui.SameLine()
            CImGui.Selectable(MORESTYLE.Icons.Help, menuidx == 2, 0, sbsz) && (menuidx = 2)
            CImGui.PopStyleColor()
            CImGui.SameLine()
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
            @c CImGui.Selectable(MORESTYLE.Icons.Preferences, &show_preferences, 0, sbsz)
            CImGui.PopStyleColor()

            CImGui.AddRectFilled(
                CImGui.GetWindowDrawList(),
                CImGui.GetCursorScreenPos(),
                CImGui.GetCursorScreenPos() .+ (CImGui.GetWindowContentRegionMax().x, CImGui.GetFrameHeight() + unsafe_load(IMGUISTYLE.ItemSpacing.y)),
                CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.ToolBarBg)
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
                @c CImGui.Selectable(MORESTYLE.Icons.Logger, &show_logger, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(GLOBALFONT)
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
            igSeparatorText("")


            if showwhat == 0
                btw = 2CImGui.GetFrameHeight() + unsafe_load(IMGUISTYLE.ItemSpacing.y)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
                CImGui.BeginChild("border1", (Cfloat(0), btw + 2unsafe_load(IMGUISTYLE.WindowPadding.y)), true)
                showst |= SYNCSTATES[Int(AutoDetecting)]
                showst && CImGui.PushStyleColor(
                    CImGui.ImGuiCol_Button,
                    SYNCSTATES[Int(AutoDetecting)] ? MORESTYLE.Colors.LogInfo : st ? MORESTYLE.Colors.HighlightText : MORESTYLE.Colors.LogError
                )
                igBeginDisabled(SYNCSTATES[Int(IsDAQTaskRunning)])
                CImGui.Button(MORESTYLE.Icons.InstrumentsAutoDetect, (btw, btw)) && refresh_instrlist()
                showst && CImGui.PopStyleColor()
                CImGui.SameLine()
                CImGui.BeginGroup()
                CImGui.PushItemWidth(CImGui.GetContentRegionAvailWidth() - unsafe_load(IMGUISTYLE.ItemSpacing.x) - CImGui.GetFrameHeight())
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
                    isrefreshingdict = Dict()
                    for (addr, ibv) in inses
                        hasref = false
                        for qt in values(ibv.insbuf.quantities)
                            SYNCSTATES[Int(IsAutoRefreshing)] && ibv.insbuf.isautorefresh && (hasref |= qt.isautorefresh)
                            qt isa SweepQuantity && (hasref |= qt.issweeping)
                            hasref && break
                        end
                        push!(isrefreshingdict, addr => hasref)
                    end
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
                                    if CImGui.MenuItem(
                                        stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")),
                                        C_NULL,
                                        false,
                                        ins != "VirtualInstr" && !SYNCSTATES[Int(IsDAQTaskRunning)]
                                    )
                                        synccall_wait(workers()[1], ins, addr) do ins, addr
                                            delete!(INSTRBUFFERVIEWERS[ins], addr)
                                        end
                                    end
                                    if CImGui.BeginMenu(
                                        stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add to")),
                                        ins == "Others" && !SYNCSTATES[Int(IsDAQTaskRunning)]
                                    )
                                        for (cfins, cf) in INSCONF
                                            cfins in ["Others", "VirtualInstr"] && continue
                                            if CImGui.MenuItem(stcstr(cf.conf.icon, " ", cfins))
                                                synccall_wait(workers()[1], ins, addr, cfins) do ins, addr, cfins
                                                    delete!(INSTRBUFFERVIEWERS[ins], addr)
                                                    get!(INSTRBUFFERVIEWERS[cfins], addr, InstrBufferViewer(cfins, addr))
                                                end
                                            end
                                        end
                                        CImGui.EndMenu()
                                    end
                                    CImGui.EndPopup()
                                end
                                if addrnode
                                    @c CImGui.MenuItem(mlstr("Common"), C_NULL, &ibv.p_open)
                                    if haskey(INSWCONF, ins)
                                        haskey(instrwidgets, addr) || push!(instrwidgets, addr => Dict())
                                        for w in INSWCONF[ins]
                                            if !haskey(instrwidgets[addr], w.name)
                                                push!(instrwidgets[addr], w.name => (Ref(false), []))
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
                filelist = filter(x -> x[2].rootpath_bnm == "", dtviewers)
                folderlist = filter(x -> x[2].rootpath_bnm != "", dtviewers)
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Files"))
                if isempty(filelist)
                    CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
                else
                    for dtv in filelist
                        title = isempty(dtv[2].filetrees) ? mlstr("no file opened") : basename(dtv[2].filetrees[1].filepath)
                        @c CImGui.MenuItem(title, C_NULL, &dtv[1].p_open)
                        if CImGui.BeginPopupContextItem()
                            CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Close"))) && (dtv[1].noclose = false)
                            CImGui.EndPopup()
                        end
                    end
                end
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Folders"))
                if isempty(folderlist)
                    CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
                else
                    for (i, dtv) in enumerate(folderlist)
                        CImGui.PushID(i)
                        @c CImGui.MenuItem(basename(dtv[2].rootpath), C_NULL, &dtv[1].p_open)
                        if CImGui.BeginPopupContextItem()
                            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Refresh")))
                                dtv[2].filetrees = FolderFileTree(
                                    dtv[2].rootpath,
                                    dtv[2].selectedpath,
                                    dtv[2].filter
                                ).filetrees
                            end
                            CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Close"))) && (dtv[1].noclose = false)
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

            CImGui.End()

            CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
            CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, 0)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, (0, 0))
            CImGui.Begin("DockSpace", C_NULL, window_flags | CImGui.ImGuiWindowFlags_NoBackground)
            igDockSpace(CImGui.GetID("MainWindow"), CImGui.ImVec2(0, 0), ImGuiDockNodeFlags_PassthruCentralNode, C_NULL)
            CImGui.End()
            CImGui.PopStyleVar(2)
        end

        ######子窗口######
        for (i, dtv) in enumerate(dtviewers)
            dtv[1].p_open && edit(dtv..., i)
        end
        for (i, dtv) in enumerate(dtviewers)
            dtv[1].noclose || deleteat!(dtviewers, i)
        end
        for (i, dft) in enumerate(dataformatters)
            dft.p_open && edit(dft, i)
        end
        for (i, dft) in enumerate(dataformatters)
            dft.noclose || deleteat!(dataformatters, i)
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
            Threads.@spawn begin
                files = pick_multi_file()
                isempty(files) || push!(dtviewers, (DataViewer(), FolderFileTree(files), Dict())) #true -> active
            end
        end
        if isopenfolder || (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyDown(ImGuiKey_K))
            Threads.@spawn begin
                root = pick_folder()
                isdir(root) && push!(dtviewers, (DataViewer(), FolderFileTree(root), Dict())) #true -> active
            end
        end
        if isopenformatter
            push!(dataformatters, DataFormatter())
        end
        if !isempty(ARGS)
            filepath = reencoding(ARGS[1], CONF.Basic.encoding)
            isfile(filepath) && push!(dtviewers, (DataViewer(), FolderFileTree([abspath(filepath)]), Dict()))
            empty!(ARGS)
        end
    end
end #let