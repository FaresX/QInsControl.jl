# 分界线拖拽状态:抓取偏移与激活标记(卡片子窗口覆盖接缝,拖拽用全局鼠标状态实现,
# 占比持久化于 CONF.Basic.maincolsplit)
const DIVDRAGACTIVE = Ref{Bool}(false)
const DIVDRAGBASE = Ref{Cfloat}(0f0)

let
    show_preferences::Bool = false
    show_instr_register::Bool = false

    show_console::Bool = false
    show_metrics::Bool = false
    show_logger::Bool = false
    show_about::Bool = false
    show_update::Bool = false #应用内更新窗口(src/Updater + Windows/ShowUpdate)
    show_debugger::Bool = false
    show_aiassistant::Bool = false #AI 助手窗口(AI 子模块的窗口开关,见 src/AI/)

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
    pendingfvs = Channel{FileViewer}(32) #后台文件对话框任务 → 渲染线程的 FileViewer 投递队列

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

    global get_fileviewers() = fileviewers
    global debugger() = show_debugger = true
    global openupdatewindow() = (show_update = true) #供 ShowAbout 的"更新"按钮打开更新窗口
    global isshowapp() = showapp
    global function closeallwindows()
        show_preferences = false
        show_instr_register = false

        show_console = false
        show_metrics = false
        show_logger = false
        show_about = false
        show_update = false
        show_debugger = false
        show_aiassistant = false
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

    showwhat::Cint = 0
    menuidx::Cint = 0
    global function MainWindow()
        if !CONF.Basic.hidemainwindow
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
            #禁用垂直滚动条:卡片宽度按 mainw 显式计算,若内容出现尾随 ItemSpacing 的
            #幻影溢出,ImGui 预留的滚动条槽会压缩裁剪框,右卡片描边再次被裁
            CImGui.BeginChild(
                "main", (0, 0), CImGui.ImGuiChildFlags_None,
                CImGui.ImGuiWindowFlags_NoScrollbar
            )
            # 无 Columns:两张卡片按 maincolsplit 显式布局(遗留 Columns 的 border 参数
            # 同时控制画线与拖拽,源码级耦合,"透明分割线 + 可拖拽"无法兼得,故弃用)。
            # 卡片间隙 = ItemSpacing.x,与工具栏到面板的间隔一致;分界线平时透明
            split = clamp(Float64(CONF.Basic.maincolsplit), 0.2, 0.8)
            mainw = CImGui.GetWindowWidth()
            halfgap = Cfloat(unsafe_load(IMGUISTYLE.ItemSpacing.x) / 2)
            leftw = Cfloat(mainw * split)
            CardChild("left", (leftw - halfgap, 0))
            DAQtasks()
            EndCard()
            CImGui.SetCursorPos(leftw + halfgap, 0)
            CardChild("right", (mainw - leftw - halfgap - 1, 0))
            originfontsize = unsafe_load(IMGUISTYLE.FontSizeBase)
            CImGui.PushFont(C_NULL, MORESTYLE.Variables.BigIconSize)
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
            CImGui.PushFont(C_NULL, originfontsize)
            ItemTooltip(mlstr("Instruments"))
            CImGui.PopFont()
            CImGui.SameLine()
            CImGui.Selectable(MORESTYLE.Icons.File, menuidx == 1, 0, sbsz) && (menuidx = 1)
            CImGui.PushFont(C_NULL, originfontsize)
            ItemTooltip(mlstr("Files"))
            CImGui.PopFont()
            CImGui.SameLine()
            CImGui.Selectable(MORESTYLE.Icons.Assistant, menuidx == 2, 0, sbsz) && (menuidx = 2)
            CImGui.PushFont(C_NULL, originfontsize)
            ItemTooltip(mlstr("Assistant"))
            CImGui.PopFont()
            CImGui.SameLine()
            STATES[NewVersion] && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.InfoText)
            STATES[FatalError] && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ErrorText)
            CImGui.Selectable(MORESTYLE.Icons.Help, menuidx == 3, 0, sbsz) && (menuidx = 3)
            CImGui.PushFont(C_NULL, originfontsize)
            ItemTooltip(mlstr("Help"))
            CImGui.PopFont()
            STATES[FatalError] && CImGui.PopStyleColor()
            STATES[NewVersion] && CImGui.PopStyleColor()
            CImGui.PopStyleColor(2)
            # CImGui.SameLine()
            # CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
            # @c CImGui.Selectable(MORESTYLE.Icons.Preferences, &show_preferences, 0, sbsz)
            # CImGui.PopStyleColor()
            # CImGui.PushFont(C_NULL, originfontsize)
            # ItemTooltip(mlstr("Preferences"))
            # CImGui.PopFont()

            CImGui.AddRectFilled(
                CImGui.GetWindowDrawList(),
                CImGui.GetCursorScreenPos(),
                CImGui.GetCursorScreenPos() .+ (CImGui.GetContentRegionAvail().x, CImGui.GetFrameHeight() + unsafe_load(IMGUISTYLE.ItemSpacing.y)),
                MORESTYLE.Colors.ToolBarBg
            )
            if menuidx == 0
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.InstrumentsRegister, &show_instr_register, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Instrument Registration"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                CImGui.Selectable(MORESTYLE.Icons.CPUMonitor, showwhat == 2, 0, sbsz) && (showwhat = 2)
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Instrument CPU Monitor"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                CImGui.Selectable(MORESTYLE.Icons.ServerMonitor, showwhat == 3, 0, sbsz) && (showwhat = 3)
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Server Monitor"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                CImGui.Selectable(MORESTYLE.Icons.InstrumentsSetting, showwhat == 0, 0, sbsz) && (showwhat = 0)
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Instrument Control"))
                CImGui.PopFont()
            elseif menuidx == 1
                showwhat = 1
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                isopenfiles = CImGui.Selectable(stcstr(MORESTYLE.Icons.File, "##openfiles"), false, 0, sbsz)
                CImGui.PopStyleColor(2)
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Open Files"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                isopenfolder = CImGui.Selectable(stcstr(MORESTYLE.Icons.OpenFolder, "##openfolder"), false, 0, sbsz)
                CImGui.PopStyleColor(2)
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Open Folder"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                isopenformatter = CImGui.Selectable(stcstr(MORESTYLE.Icons.DataFormatter, "##openformatter"), false, 0, sbsz)
                CImGui.PopStyleColor(2)
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Open Formatter"))
                CImGui.PopFont()
            elseif menuidx == 2
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.Console, &show_console, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Console"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.AIAssistant, &show_aiassistant, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("AI Assistant"))
                CImGui.PopFont()
                CImGui.SameLine()
                #Web 仪表盘:启动只读服务并用系统浏览器打开(未启动时点击即启动)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                CImGui.Selectable(MORESTYLE.Icons.WebDashboard, false, 0, sbsz) && begin
                    url = startwebdashboard!()
                    isempty(url) || Threads.@spawn DefaultApplication.open(url)
                end
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Web Dashboard"))
                CImGui.PopFont()
            elseif menuidx == 3
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.Metrics, &show_metrics, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Metrics"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                STATES[FatalError] && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ErrorText)
                @c CImGui.Selectable(MORESTYLE.Icons.Logger, &show_logger, 0, sbsz)
                STATES[FatalError] && CImGui.PopStyleColor()
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                if STATES[FatalError] && CImGui.BeginPopupContextItem()
                    CImGui.MenuItem(mlstr("Clear Fatal Error")) && (STATES[FatalError] = false)
                    CImGui.EndPopup()
                end
                ItemTooltip(mlstr("Logger"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                @c CImGui.Selectable(MORESTYLE.Icons.Preferences, &show_preferences, 0, sbsz)
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("Preferences"))
                CImGui.PopFont()
                CImGui.SameLine()
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                STATES[NewVersion] && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.InfoText)
                @c CImGui.Selectable(MORESTYLE.Icons.About, &show_about, 0, sbsz)
                STATES[NewVersion] && CImGui.PopStyleColor()
                CImGui.PopStyleColor()
                CImGui.PushFont(C_NULL, originfontsize)
                ItemTooltip(mlstr("About"))
                CImGui.PopFont()
                # CImGui.SameLine()
                # CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                # @c CImGui.Selectable(MORESTYLE.Icons.AIAssistant, &show_aiassistant, 0, sbsz)
                # CImGui.PopStyleColor()
                # CImGui.PushFont(C_NULL, originfontsize)
                # ItemTooltip(mlstr("AI Assistant"))
                # CImGui.PopFont()
                # CImGui.SameLine()
                # #Web 仪表盘:启动只读服务并用系统浏览器打开(未启动时点击即启动)
                # CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
                # CImGui.Selectable(MORESTYLE.Icons.WebDashboard, false, 0, sbsz) && begin
                #     url = startwebdashboard!()
                #     isempty(url) || Threads.@spawn DefaultApplication.open(url)
                # end
                # CImGui.PopStyleColor()
                # CImGui.PushFont(C_NULL, originfontsize)
                # ItemTooltip(mlstr("Web Dashboard"))
                # CImGui.PopFont()
            end

            CImGui.PopStyleVar(2)
            CImGui.PopFont()
            CImGui.SeparatorText("")

            CImGui.BeginChild("right content")
            if showwhat == 0
                InstrumentMonitor(instrwidgets)
            elseif showwhat == 1
                OpenFileMonitor(fileviewers, dataformatters)
            elseif showwhat == 2
                CPUMonitor()
            elseif showwhat == 3
                ServerMonitor()
            end
            CImGui.EndChild()

            EndCard()
            # 分界线:两张卡片无缝相接,平时完全透明;鼠标靠近接缝时浮现强调色竖线。
            # 拖拽用全局鼠标状态更新 maincolsplit(mousein 按坐标判定,卡片覆盖时仍生效;
            # 松手 saveconf 持久化占比)
            wx, wy = CImGui.GetWindowPos().x, CImGui.GetWindowPos().y
            wh = CImGui.GetWindowSize().y
            dx = Cfloat(wx + leftw)  # 强制 Float32:异构元组不匹配 NTuple{2}(ai/08 坑 31)
            near = mousein((dx - 6, wy), (dx + 6, wy + wh))
            if !DIVDRAGACTIVE[] && near && CImGui.IsMouseClicked(0)
                DIVDRAGACTIVE[] = true
                DIVDRAGBASE[] = CImGui.GetMousePos().x - dx
            end
            if DIVDRAGACTIVE[]
                CONF.Basic.maincolsplit = clamp(
                    (CImGui.GetMousePos().x - DIVDRAGBASE[] - wx) / mainw, 0.2, 0.8
                )
                CImGui.IsMouseDown(0) || (DIVDRAGACTIVE[] = false; saveconf())
            end
            if near || DIVDRAGACTIVE[]
                gradientfill(
                    CImGui.GetWindowDrawList(), (dx - 2, wy), (dx + 2, wy + wh),
                    MORESTYLE.Colors.AccentTop, MORESTYLE.Colors.AccentBottom
                )
                CImGui.SetMouseCursor(CImGui.ImGuiMouseCursor_ResizeEW)
            end
            CImGui.EndChild()

            CImGui.End()
        end

        ######子窗口######
        #后台选好的 FileViewer 经 Channel 回渲染线程入列:直接从 @spawn 任务 push! 会与
        #本循环的迭代/删除竞争(GUI 向量只能 GUI 线程动)
        while isready(pendingfvs)
            push!(fileviewers, take!(pendingfvs))
        end
        for (i, fv) in enumerate(fileviewers)
            fv.p_open && edit(fv, i)
        end
        for i in reverse(eachindex(fileviewers)) #倒序遍历:循环体内 deleteat! 不会使未访问下标位移
            fv = fileviewers[i]
            fv.noclose || (atclosefileviewer!(fv); deleteat!(fileviewers, i))
        end
        for (i, dft) in enumerate(dataformatters)
            dft.p_open && edit(dft, i)
        end
        for i in reverse(eachindex(dataformatters))
            dft = dataformatters[i]
            dft.noclose || (atclosedataformatter!(dft); deleteat!(dataformatters, i))
        end
        show_preferences && @c Preferences(&show_preferences)
        show_update && @c ShowUpdate(&show_update)

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
        show_aiassistant && @c ShowAIAssistant(&show_aiassistant)
        ShowAbout()
        show_about && (CImGui.OpenPopup(mlstr("About"));
        show_about = false)
        show_debugger && @c Debugger(&show_debugger)

        ######快捷键######
        drain_ui!() #AI 子模块的 UI 线程封送队列(结构性变更必须回到渲染线程执行)
        RenderAIConfirm() #AI 写操作确认模态:必须无条件渲染,不能只挂在 AI 窗口可见时(否则队列无人消费)
        if isopenfiles || (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyPressed(ImGuiKey_O)) #IsKeyPressed 边沿触发:IsKeyDown 长按会每帧连发文件对话框
            Threads.@spawn @trycatch mlstr("task failed!!!") begin
                files = pick_multi_file()
                isempty(files) || put!(pendingfvs, FileViewer(filetree=FolderFileTree(files)))
            end
        end
        if isopenfolder || (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyPressed(ImGuiKey_K))
            Threads.@spawn @trycatch mlstr("task failed!!!") begin
                root = pick_folder()
                isdir(root) && put!(pendingfvs, FileViewer(filetree=FolderFileTree(root)))
            end
        end
        if isopenformatter
            push!(dataformatters, DataFormatter())
        end
        unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyPressed(ImGuiKey_I) && (show_aiassistant = true) #Ctrl+I 打开 AI 助手
        if !isempty(ARGS)
            filepath = reencoding(ARGS[1], CONF.Basic.encoding)
            isfile(filepath) && push!(fileviewers, FileViewer(filetree=FolderFileTree([abspath(filepath)])))
            empty!(ARGS)
        end
    end
end #let