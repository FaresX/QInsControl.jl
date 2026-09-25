function UI(; engine=nothing)
    CImGui.set_backend(:GlfwOpenGL3)
    ctx = CImGui.CreateContext()

    #setup ImNodes context
    ctxi = imnodes_CreateContext()
    setctxi(ctxi)

    # enable docking and multi-viewport
    io = CImGui.GetIO()
    # imguiinifile = joinpath(ENV["QInsControlAssets"], "Necessity/imgui.ini")
    # io.IniFilename = pointer(imguiinifile)
    io.IniFilename = C_NULL
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_DockingEnable
    CONF.Basic.viewportenable && begin
        io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_ViewportsEnable
        # 让拖出的独立 OS 窗口使用系统装饰(标题栏/DWM 阴影/系统圆角/贴边分屏),
        # 默认 true 是无边框窗口(ImGui 自绘标题条),观感扁平
        io.ConfigViewportsNoDecoration = CONF.Basic.hideglfwwindow
    end
    # io.ConfigDockingWithShift = true
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_RendererHasVtxOffset

    # load imgui.ini
    # isfile(imguiinifile) ? CImGui.LoadIniSettingsFromDisk(imguiinifile) : touch(imguiinifile)
    imguiinifile = joinpath(ENV["QInsControlAssets"], "Necessity/imgui.ini")
    isfile(imguiinifile) && CImGui.LoadIniSettingsFromDisk(imguiinifile)

    # # 加载字体
    # fonts = unsafe_load(io.Fonts)
    # # 加载全局字体
    # global GLOBALFONT = CImGui.AddFontFromFileTTF(fonts, joinpath(CONF.Fonts.path))
    # fontcfg = ImFontConfig_ImFontConfig()
    # fontcfg.OversampleH = fontcfg.OversampleV = 1
    # fontcfg.MergeMode = true

    # # 加载全局图标字体
    # CImGui.AddFontFromFileTTF(
    #     fonts, joinpath(ENV["QInsControlAssets"], "Necessity/fa-regular-400.ttf"), 0, fontcfg
    # )
    # CImGui.AddFontFromFileTTF(
    #     fonts, joinpath(ENV["QInsControlAssets"], "Necessity/fa-solid-900.ttf"), 0, fontcfg
    # )

    global IMGUISTYLE = CImGui.GetStyle()
    global IMNODESSTYLE = imnodes_GetStyle()
    global MORESTYLE = MoreStyle()
    haskey(STYLES, CONF.Style.default) && loadstyle(STYLES[CONF.Style.default])
    # 清屏色与主题 ClearColor 共享同一向量:ColorEdit4/loadstyle 原地修改即热更
    global CLEARCOLOR = Ref{Vector{Cfloat}}(MORESTYLE.Colors.ClearColor)

    # 加载字体
    fonts = unsafe_load(io.Fonts)
    # 加载全局字体
    if !isfile(MORESTYLE.Variables.FontPath)
        MORESTYLE.Variables.FontPath = joinpath(ENV["QInsControlAssets"], "Fonts/HarmonyOS_Sans_SC_Regular.ttf")
    end
    global GLOBALFONT = CImGui.AddFontFromFileTTF(fonts, MORESTYLE.Variables.FontPath)
    fontcfg = ImFontConfig_ImFontConfig()
    fontcfg.OversampleH = fontcfg.OversampleV = 1
    fontcfg.MergeMode = true

    # 加载全局图标字体
    CImGui.AddFontFromFileTTF(
        fonts, joinpath(ENV["QInsControlAssets"], "Necessity/fa-regular-400.ttf"), 0, fontcfg
    )
    CImGui.AddFontFromFileTTF(
        fonts, joinpath(ENV["QInsControlAssets"], "Necessity/fa-solid-900.ttf"), 0, fontcfg
    )

    # 代码编辑器等宽字体:ASCII 等宽,合并 HarmonyOS 回退中文;无等宽字体时回退全局字体
    global CODEFONT = C_NULL
    monopath = joinpath(ENV["QInsControlAssets"], "Fonts/CascadiaMono.ttf")
    isfile(monopath) || (monopath = joinpath(@__DIR__, "../../Assets/Fonts/CascadiaMono.ttf"))
    if isfile(monopath)
        global CODEFONT = CImGui.AddFontFromFileTTF(fonts, monopath)
        fontcfg = ImFontConfig_ImFontConfig()
        fontcfg.MergeMode = true
        CImGui.AddFontFromFileTTF(fonts, MORESTYLE.Variables.FontPath, 0, fontcfg)
    end

    # temp files
    isdir(joinpath(ENV["QInsControlAssets"], "temp")) || mkdir(joinpath(ENV["QInsControlAssets"], "temp"))

    firstframe = true

    rendertask = Threads.@spawn CImGui.render(
        ctx;
        window_size=CONF.Basic.windowsize, window_title="QInsControl", on_exit=onexitaction,
        opengl_version=VersionNumber(CONF.Basic.openglversion), engine=engine, clear_color=CLEARCOLOR
    ) do
        try
            if firstframe
                # 加载图标
                icons = FileIO.load.([joinpath(ENV["QInsControlAssets"], "Necessity/QInsControl.ico")])
                icons_8bit = reinterpret.(NTuple{4,UInt8}, icons)
                APPICON[] = icons_8bit  # 缓存像素,供拖出的新视口窗口补设系统标题栏图标
                GLFW.SetWindowIcon(CImGui.current_window(), icons_8bit)
                iconsize = reverse(size(icons[1]))
                global ICONID = CImGui.create_image_texture(iconsize...)
                CImGui.update_image_texture(ICONID, transpose(icons[1]), iconsize...)
                # 缩放设置
                toimguitheme!(get!(MAKIETHEMES, MORESTYLE.Variables.MakieTheme, "default"))
                scale = CImGui.GetWindowDpiScale()
                ImGuiStyle_ScaleAllSizes(IMGUISTYLE, scale / MORESTYLE.Variables.ImGuiScale)
                IMGUISTYLE.FontScaleDpi = scale
                applytheme!()
                ws = round.(Int, CONF.Basic.windowsize * scale)
                GLFW.SetWindowSize(CImGui.current_window(), ws...)

                firstframe = false
            end
            ###### 检查 STATICSTRINGS ######
            waittime("Check STATICSTRINGS", 36) && checklifetime()
            ###### 检查新版本 ######
            waittime("Check new version", 3600) && getnewestversion()
            ###### 新平台视口的系统外观(拖出的 OS 窗口动态出现)######
            applyallchrome!(isthemedark(MORESTYLE.Colors.ClearColor))
            syncviewportcloses!()

            MainWindow()
            rendernotifications()
            if CImGui.BeginPopupModal("##windowshouldclose?", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                CImGui.TextColored(
                    MORESTYLE.Colors.ErrorText,
                    stcstr("\n\n", mlstr("data acquiring or sweeping, please wait......"), "\n\n\n")
                )
                CImGui.Button(mlstr("Confirm"), (-1, 0)) && CImGui.CloseCurrentPopup()
                CImGui.EndPopup()
            end
            if GLFW.WindowShouldClose(CImGui.current_window()) || !isshowapp()[]
                hasrefreshing = false
                for inses in values(INSTRBUFFERVIEWERS)
                    for ibv in values(inses)
                        for (_, qt) in filter(x -> x.second isa SweepQuantity, ibv.insbuf.quantities)
                            hasrefreshing |= qt.issweeping
                        end
                    end
                end
                if SYNCSTATES[IsDAQTaskRunning] || hasrefreshing
                    CImGui.OpenPopup("##windowshouldclose?")
                    GLFW.SetWindowShouldClose(CImGui.current_window(), false)
                    isshowapp()[] = true
                else
                    return
                end
            end
            if CONF.Basic.waitevents
                if CImGui.IsAnyItemActive() || CImGui.IsAnyItemHovered()
                    dorender()
                elseif CImGui.IsAnyMouseDown() || unsafe_load(io.MouseWheel) != 0
                    dorender(12, false)
                end
                waittorender()
            end
        catch e
            @error "[$(now())]\n$(mlstr("error in renderloop!"))" exception = e
            STATES[FatalError] = true
            closeallwindows()
            showbacktrace()
            toast(:error, String(mlstr("error in renderloop!")), sprint(showerror, e))
        end
    end

    startposttask()

    return rendertask
end

let
    ctxi = nothing
    global setctxi(ctx) = (ctxi = ctx)
    global function onexitaction()
        stopposttask()
        SYNCSTATES[IsDAQTaskRunning] || remote_stopcpu!()
        remote_stopserver!()
        stopwebdashboard!()
        stoprefresh()
        remote_stoprefresh()
        empty!(STATICSTRINGS)
        empty!(QInsControlCore.MLSTRINGS)
        empty!(IMAGES)
        empty!(FIGURES)
        destroyshadowtexture!()
        temppath = joinpath(ENV["QInsControlAssets"], "temp")
        isdir(temppath) && for file in readdir(temppath, join=true)
            Base.Filesystem.rm(file, force=true)
        end
        CImGui.SaveIniSettingsToDisk(joinpath(ENV["QInsControlAssets"], "Necessity/imgui.ini"))
        imnodes_DestroyContext(ctxi)
        stoplogger()
    end

    isrunningpost = Ref(true)
    #eventnum 由后台帧泵任务与渲染线程并发 +=/-=,hasaddevent 会被任意投递线程(Toasts 等)写:
    #Ref 的读改写不原子会丢事件导致渲染停滞,必须用 Atomic
    eventnum = Threads.Atomic{Int}(0)
    hasaddevent = Threads.Atomic{Bool}(false)
    global function startposttask()
        isrunningpost[] = true
        Threads.@spawn begin
            while isrunningpost[]
                CONF.Basic.waitevents && Threads.atomic_add!(eventnum, 1)
                sleep(1 / CONF.Basic.lowestframerate)
            end
        end
    end
    stopposttask() = (isrunningpost[] = false; sleep(1 / CONF.Basic.lowestframerate))
    global function waittorender()
        eventnum[] < 0 && (eventnum[] = 0)
        while eventnum[] == 0
            sleep(0.001)
        end
        Threads.atomic_sub!(eventnum, 1)
        hasaddevent[] = false
    end
    global function dorender(n=1, skip=true)
        CONF.Basic.waitevents || return
        if eventnum[] < 1800 && ((skip && !hasaddevent[]) || !skip)
            Threads.atomic_add!(eventnum, n)
            hasaddevent[] = true
        end
    end
end