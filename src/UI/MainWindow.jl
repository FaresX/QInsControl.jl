let
    show_preferences::Bool = false
    show_instr_register::Bool = false
    show_cpu_monitor::Bool = false
    show_instr_buffer::Bool = false
    show_daq::Bool = false

    show_console::Bool = false
    show_metrics::Bool = false
    # show_debug = false
    show_logger::Bool = false
    # show_helppad::Bool = false
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
    instrwidgets = Dict{String,Dict{String,Tuple{Ref{Bool},InstrWidget}}}()

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
        show_cpu_monitor = false
        show_instr_buffer = false
        show_daq = false

        show_console = false
        show_metrics = false
        # show_debug = false
        show_logger = false
        # show_helppad = false
        show_about = false
        for dtv in dtviewers
            dtv[1].p_open = false
        end
        for (_, inses) in filter(x->!isempty(x.second), INSTRBUFFERVIEWERS)
            for (_, ibv) in inses
                ibv.p_open = false
            end
        end
        empty!(instrwidgets)
    end

    global function MainWindow()
        ######加载背景######
        # igDockSpaceOverViewport(igGetMainViewport(), ImGuiDockNodeFlags_None, C_NULL)
        if !CONF.Basic.hidewindow
            viewport = igGetMainViewport()
            CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
            CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, 0)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, (0, 0))
            CImGui.Begin("Wallpaper", C_NULL, window_flags | CImGui.ImGuiWindowFlags_NoBringToFrontOnFocus)
            Image(CONF.BGImage.path; size=unsafe_load(viewport.WorkSize), tint_col=MORESTYLE.Colors.BgImageTint)
            CImGui.End()

            CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
            CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
            CImGui.Begin("DockSpace", C_NULL, window_flags | CImGui.ImGuiWindowFlags_NoBackground)
            igDockSpace(CImGui.GetID("MainWindow"), CImGui.ImVec2(0, 0), ImGuiDockNodeFlags_PassthruCentralNode, C_NULL)
            CImGui.End()
            CImGui.PopStyleVar(2)
            # igDockSpaceOverViewport(igGetMainViewport(), ImGuiDockNodeFlags_None, C_NULL)
        end

        ######Debug######


        ######子窗口######
        for (i, dtv) in enumerate(dtviewers)
            dtv[1].p_open && edit(dtv..., i)
        end
        for (i, dtv) in enumerate(dtviewers)
            dtv[1].noclose || deleteat!(dtviewers, i)
        end
        show_preferences && @c Preferences(&show_preferences)

        show_instr_register && @c InstrRegister(&show_instr_register)
        show_cpu_monitor && @c CPUMonitor(&show_cpu_monitor)
        show_instr_buffer && @c ShowInstrBuffer(&show_instr_buffer)
        for (_, inses) in filter(x->!isempty(x.second), INSTRBUFFERVIEWERS)
            for (addr, ibv) in inses
                ibv.p_open && edit(ibv)
                if haskey(instrwidgets, addr)
                    for (wnm, insw) in instrwidgets[addr]
                        insw[1][] ? edit(insw[2], ibv.insbuf, addr, insw[1], wnm) : delete!(instrwidgets[addr], wnm)
                    end
                end
            end
        end
        show_daq && @c DAQ(&show_daq)

        show_console && @c ShowConsole(&show_console)
        show_metrics && @c CImGui.ShowMetricsWindow(&show_metrics)
        # show_debug && @c debug(&show_debug)
        show_logger && @c LogWindow(&show_logger)
        # show_helppad && @c ShowHelpPad(&show_helppad)
        ShowAbout()
        show_about && (CImGui.OpenPopup(mlstr("About"));
        show_about = false)

        ######主菜单######
        isopenfiles = false
        isopenfolder = false
        # if CONF.Basic.hidewindow
        #     viewport = igGetMainViewport()
        #     CImGui.SetNextWindowPos((unsafe_load(viewport.WorkPos) .+ 6 ...,), CImGui.ImGuiCond_Appearing)
        #     CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize), CImGui.ImGuiCond_Appearing)
        #     CImGui.Begin("QInsControl", showapp, CImGui.ImGuiWindowFlags_MenuBar) || (CImGui.End(); return nothing)
        # end
        if CONF.Basic.hidewindow ? CImGui.BeginMenuBar() : CImGui.BeginMainMenuBar()
            #File Menu
            if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.File, " ", mlstr("File"), " "))
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.OpenFile, " ", mlstr("Open File")))
                    isopenfiles = CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New")), "Ctrl+O")
                    if true in [dtv[2].rootpath_bnm == "" for dtv in dtviewers]
                        CImGui.Separator()
                        CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("Opened"))
                    end
                    for dtv in dtviewers
                        if dtv[2].rootpath_bnm == ""
                            title = isempty(dtv[2].filetrees) ? mlstr("no file opened") : basename(dtv[2].filetrees[1].filepath)
                            @c CImGui.MenuItem(title, C_NULL, &dtv[1].p_open)
                            if CImGui.BeginPopupContextItem()
                                CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Close"))) && (dtv[1].noclose = false)
                                CImGui.EndPopup()
                            end
                        end
                    end
                    CImGui.EndMenu()
                end
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.OpenFolder, " ", mlstr("Open Folder")))
                    isopenfolder = CImGui.MenuItem(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New")), "Ctrl+K")
                    if true in [dtv[2].rootpath_bnm != "" for dtv in dtviewers]
                        CImGui.Separator()
                        CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("Opened"))
                    end
                    for (i, dtv) in enumerate(dtviewers)
                        CImGui.PushID(i)
                        if dtv[2].rootpath_bnm != ""
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
                        end
                        CImGui.PopID()
                    end
                    CImGui.EndMenu()
                end
                @c CImGui.MenuItem(stcstr(MORESTYLE.Icons.Preferences, " ", mlstr("Preferences")), C_NULL, &show_preferences)
                CImGui.EndMenu()
            end
            #Instrument Menu
            if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Instrumets, " ", mlstr("Instrument"), " "))
                @c CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.InstrumentsRegister, " ", mlstr("Instrument Registration")),
                    C_NULL,
                    &show_instr_register
                )
                @c CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.CPUMonitor, " ", mlstr("Instrument CPU Monitor")),
                    C_NULL,
                    &show_cpu_monitor
                )
                if CImGui.BeginMenu(
                    stcstr(MORESTYLE.Icons.InstrumentsSetting, " ", mlstr("Instrument Settings and Status"))
                )
                    @c CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.InstrumentsOverview, " ", mlstr("Overview")),
                        C_NULL,
                        &show_instr_buffer
                    )
                    CImGui.Separator()
                    for (ins, inses) in filter(x -> !isempty(x.second), INSTRBUFFERVIEWERS)
                        if CImGui.BeginMenu(stcstr(INSCONF[ins].conf.icon, " ", ins))
                            for (addr, ibv) in inses
                                @c CImGui.Checkbox(stcstr("##", ins, addr), &ibv.insbuf.isautorefresh)
                                CImGui.SameLine()
                                if @c CImGui.BeginMenu(addr)
                                    @c CImGui.MenuItem(mlstr("Common"), C_NULL, &ibv.p_open)
                                    if CImGui.BeginPopupContextItem()
                                        if CImGui.MenuItem(
                                            stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")),
                                            C_NULL,
                                            false,
                                            ins != "VirtualInstr"
                                        )
                                            synccall_wait(workers()[1], ins, addr) do ins, addr
                                                delete!(INSTRBUFFERVIEWERS[ins], addr)
                                            end
                                        end
                                        if CImGui.BeginMenu(
                                            stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add to")),
                                            ins == "Others"
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
                                    if haskey(INSWCONF, ins)
                                        haskey(instrwidgets, addr) || push!(instrwidgets, addr => Dict())
                                        for w in INSWCONF[ins]
                                            if !haskey(instrwidgets[addr], w.name)
                                                insw = deepcopy(w)
                                                push!(instrwidgets[addr], w.name => (Ref(false), insw))
                                            end
                                            if CImGui.MenuItem(w.name, C_NULL, instrwidgets[addr][w.name][1]) && instrwidgets[addr][w.name][1][]
                                                Threads.@spawn initialize!(instrwidgets[addr][w.name][2], addr)
                                            end
                                        end
                                    end
                                    CImGui.EndMenu()
                                end
                            end
                            CImGui.EndMenu()
                        end
                    end
                    CImGui.EndMenu()
                end
                @c CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.InstrumentsDAQ, " ", mlstr("Data Acquiring")),
                    C_NULL,
                    &show_daq
                )
                if CImGui.BeginMenu(
                    stcstr(MORESTYLE.Icons.InstrumentsSeach, " ", mlstr("Search Instruments")),
                    !SYNCSTATES[Int(IsDAQTaskRunning)]
                )
                    CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.InstrumentsAutoDetect, " ", mlstr("Auto Search"))
                    ) && refresh_instrlist()
                    manualadd_ui()
                    CImGui.EndMenu()
                end
                CImGui.EndMenu()
            end
            #Help Menu
            if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Help, " ", mlstr("Help")))
                @c CImGui.MenuItem(stcstr(MORESTYLE.Icons.Console, " ", mlstr("Console")), C_NULL, &show_console)
                @c CImGui.MenuItem(stcstr(MORESTYLE.Icons.Metrics, " ", mlstr("Metrics")), C_NULL, &show_metrics)
                @c CImGui.MenuItem(stcstr(MORESTYLE.Icons.Logger, " ", mlstr("Logger")), C_NULL, &show_logger)
                                # @c CImGui.MenuItem(MORESTYLE.Icons.HelpPad * " 帮助板", C_NULL, &show_helppad)
                @c CImGui.MenuItem(stcstr(MORESTYLE.Icons.About, " ", mlstr("About")), C_NULL, &show_about)
                CImGui.EndMenu()
            end
            ######自动查询仪器######
            if SYNCSTATES[Int(AutoDetecting)]
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(mlstr("searching instruments"), "......"))
            end
            CONF.Basic.hidewindow ? CImGui.EndMenuBar() : CImGui.EndMainMenuBar()
        end
        # if CONF.Basic.hidewindow
        #     if CImGui.BeginPopupContextWindow()
        #         @c CImGui.MenuItem(mlstr("Hide Window"), C_NULL, &CONF.Basic.hidewindow)
        #         CImGui.EndPopup()
        #     end
        #     global glfwwindowx
        #     global glfwwindowy
        #     global glfwwindoww
        #     global glfwwindowh
        #     glfwwindowx, glfwwindowy = round.(Cint, CImGui.GetWindowPos() .- 6)
        #     glfwwindoww, glfwwindowh = round.(Cint, CImGui.GetWindowSize())
        #     CImGui.End()
        # end
        ######快捷键######
        if isopenfiles || (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyDown(79))
            files = pick_multi_file()
            isempty(files) || push!(dtviewers, (DataViewer(), FolderFileTree(files), Dict())) #true -> active
        end
        if isopenfolder || (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyDown(75))
            root = pick_folder()
            isdir(root) && push!(dtviewers, (DataViewer(), FolderFileTree(root), Dict())) #true -> active
        end
        if !isempty(ARGS)
            filepath = reencoding(ARGS[1], CONF.Basic.encoding)
            isfile(filepath) && push!(dtviewers, (DataViewer(), FolderFileTree([abspath(filepath)]), Dict()))
            empty!(ARGS)
        end
    end
end #let