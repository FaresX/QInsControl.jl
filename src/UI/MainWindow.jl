let
    show_preferences::Bool = false
    show_cpu_monitor::Bool = false
    show_instr_buffer::Bool = false
    show_daq::Bool = false
    show_instr_register::Bool = false
    show_metrics::Bool = false
    # show_debug = false
    show_logger::Bool = false
    show_helppad::Bool = false
    show_about::Bool = false

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

    global dtviewers = Tuple{DataViewer,FolderFileTree,Dict{String,Bool}}[]
    # window_class = ImGuiWindowClass_ImGuiWindowClass()
    global function MainWindow()
        window_flags = UInt32(0)
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
        ######加载背景######
        # igDockSpaceOverViewport(igGetMainViewport(), ImGuiDockNodeFlags_None, C_NULL)
        viewport = igGetMainViewport()
        CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
        CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, 0)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, (0, 0))
        CImGui.Begin("Q仪器控制与采集", C_NULL, window_flags | CImGui.ImGuiWindowFlags_NoBringToFrontOnFocus)
        CImGui.Image(Ptr{Cvoid}(bgid), unsafe_load(viewport.WorkSize))
        CImGui.End()

        CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
        CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
        CImGui.Begin("DockSpace", C_NULL, window_flags | CImGui.ImGuiWindowFlags_NoBackground)
        igDockSpace(CImGui.GetID("MainWindow"), CImGui.ImVec2(0, 0), ImGuiDockNodeFlags_PassthruCentralNode, C_NULL)
        CImGui.End()
        CImGui.PopStyleVar(2)
        # igDockSpaceOverViewport(igGetMainViewport(), ImGuiDockNodeFlags_None, C_NULL)

        ######子窗口######
        for (i, dtv) in enumerate(dtviewers)
            dtv[1].p_open && edit(dtv..., i)
        end
        for (i, dtv) in enumerate(dtviewers)
            dtv[1].noclose || deleteat!(dtviewers, i)
        end
        show_preferences && @c Preferences(&show_preferences)
        show_cpu_monitor && @c CPUMonitor(&show_cpu_monitor)
        show_instr_buffer && @c ShowInstrBuffer(&show_instr_buffer)
        for ins in keys(instrbufferviewers)
            for addr in keys(instrbufferviewers[ins])
                ibv = instrbufferviewers[ins][addr]
                ibv.p_open && edit(ibv)
            end
        end
        show_instr_register && @c InstrRegister(&show_instr_register)
        show_daq && @c DAQ(&show_daq)
        show_metrics && @c CImGui.ShowMetricsWindow(&show_metrics)
        # show_debug && @c debug(&show_debug)
        show_logger && @c LogWindow(&show_logger)
        show_helppad && @c ShowHelpPad(&show_helppad)
        ShowAbout()
        show_about && (CImGui.OpenPopup("关于");
        show_about = false)

        ######主菜单######
        isopenfiles = false
        isopenfolder = false
        if CImGui.BeginMainMenuBar()
            #File Menu
            if CImGui.BeginMenu(morestyle.Icons.File * " 文件 ")
                if CImGui.BeginMenu(morestyle.Icons.OpenFile * " 打开文件")
                    isopenfiles = CImGui.MenuItem(morestyle.Icons.NewFile * " 新建", "Ctrl+O")
                    if true in [dtv[2].rootpath_bnm == "" for dtv in dtviewers]
                        CImGui.Separator()
                        CImGui.TextColored(morestyle.Colors.HighlightText, "已打开")
                    end
                    for dtv in dtviewers
                        if dtv[2].rootpath_bnm == ""
                            title = isempty(dtv[2].filetrees) ? "没有打开文件" : basename(dtv[2].filetrees[1].filepath)
                            @c CImGui.MenuItem(title, C_NULL, &dtv[1].p_open)
                            if CImGui.BeginPopupContextItem()
                                CImGui.MenuItem(morestyle.Icons.CloseFile * " 关闭") && (dtv[1].noclose = false)
                                CImGui.EndPopup()
                            end
                        end
                    end
                    CImGui.EndMenu()
                end
                if CImGui.BeginMenu(morestyle.Icons.OpenFolder * " 打开文件夹")
                    isopenfolder = CImGui.MenuItem(morestyle.Icons.NewFile * " 新建", "Ctrl+K")
                    if true in [dtv[2].rootpath_bnm != "" for dtv in dtviewers]
                        CImGui.Separator()
                        CImGui.TextColored(morestyle.Colors.HighlightText, "已打开")
                    end
                    for dtv in dtviewers
                        if dtv[2].rootpath_bnm != ""
                            @c CImGui.MenuItem(basename(dtv[2].rootpath), C_NULL, &dtv[1].p_open)
                            if CImGui.BeginPopupContextItem()
                                if CImGui.MenuItem(morestyle.Icons.InstrumentsAutoRef*" 刷新")
                                    dtv[2].filetrees = FolderFileTree(dtv[2].rootpath, dtv[2].selectedpath).filetrees
                                end
                                CImGui.MenuItem(morestyle.Icons.CloseFile * " 关闭") && (dtv[1].noclose = false)
                                CImGui.EndPopup()
                            end
                        end
                    end
                    CImGui.EndMenu()
                end
                @c CImGui.MenuItem(morestyle.Icons.Preferences * " 首选项", C_NULL, &show_preferences)
                CImGui.EndMenu()
            end
            #Instrument Menu
            if CImGui.BeginMenu(morestyle.Icons.Instrumets * " 仪器 ")
                @c CImGui.MenuItem(morestyle.Icons.CPUMonitor * " 仪器CPU监测", C_NULL, &show_cpu_monitor)
                if CImGui.BeginMenu(morestyle.Icons.InstrumentsSetting * " 仪器设置和状态")
                    @c CImGui.MenuItem(morestyle.Icons.InstrumentsOverview * " 总览", C_NULL, &show_instr_buffer)
                    CImGui.Separator()
                    for ins in keys(instrbufferviewers)
                        if !isempty(instrbufferviewers[ins])
                            if CImGui.BeginMenu(insconf[ins].conf.icon * " " * ins)
                                for addr in keys(instrbufferviewers[ins])
                                    ibv = instrbufferviewers[ins][addr]
                                    @c CImGui.Checkbox("##$ins$addr", &ibv.insbuf.isautorefresh)
                                    CImGui.SameLine()
                                    @c CImGui.MenuItem(addr, C_NULL, &ibv.p_open)
                                end
                                CImGui.EndMenu()
                            end
                        end
                    end
                    CImGui.EndMenu()
                end
                @c CImGui.MenuItem(morestyle.Icons.InstrumentsDAQ * " 数据采集", C_NULL, &show_daq)
                @c CImGui.MenuItem(morestyle.Icons.InstrumentsRegister * " 仪器注册", C_NULL, &show_instr_register)
                if CImGui.BeginMenu(morestyle.Icons.InstrumentsSeach * " 查找仪器")
                    CImGui.MenuItem(morestyle.Icons.InstrumentsAutoDetect * " 自动查询") && refresh_instrlist()
                    manualadd_ui()
                    CImGui.EndMenu()
                end
                CImGui.EndMenu()
            end
            #Help Menu
            if CImGui.BeginMenu(morestyle.Icons.Help * " 帮助")
                @c CImGui.MenuItem(morestyle.Icons.Metrics * " 监测", C_NULL, &show_metrics)
                @c CImGui.MenuItem(morestyle.Icons.Logger * " 日志", C_NULL, &show_logger)
                @c CImGui.MenuItem(morestyle.Icons.HelpPad * " 帮助板", C_NULL, &show_helppad)
                @c CImGui.MenuItem(morestyle.Icons.About * " 关于", C_NULL, &show_about)
                CImGui.EndMenu()
            end
            ######自动查询仪器######
            if syncstates[Int(autodetecting)]
                CImGui.TextColored(morestyle.Colors.HighlightText, "查找仪器中......")
            end
            CImGui.EndMainMenuBar()
        end
        ######快捷键######
        if isopenfiles || ((CImGui.IsKeyDown(341) || CImGui.IsKeyDown(345)) && CImGui.IsKeyDown(79))
            files = pick_multi_file()
            isempty(files) || push!(dtviewers, (DataViewer(), FolderFileTree(files), Dict())) #true -> active
        end
        if isopenfolder || ((CImGui.IsKeyDown(341) || CImGui.IsKeyDown(345)) && CImGui.IsKeyDown(75))
            root = pick_folder()
            isdir(root) && push!(dtviewers, (DataViewer(), FolderFileTree(root), Dict())) #true -> active
        end
        if !isempty(ARGS)
            filepath = reencoding(ARGS[1], conf.Init.encoding)
            isfile(filepath) && push!(dtviewers, (DataViewer(), FolderFileTree([abspath(filepath)]), Dict()))
            empty!(ARGS)
        end
    end
end #let