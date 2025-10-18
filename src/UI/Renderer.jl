function UI()
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
    CONF.Basic.viewportenable && (io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_ViewportsEnable)
    # io.ConfigDockingWithShift = true
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_RendererHasVtxOffset

    # load imgui.ini
    # isfile(imguiinifile) ? CImGui.LoadIniSettingsFromDisk(imguiinifile) : touch(imguiinifile)
    imguiinifile = joinpath(ENV["QInsControlAssets"], "Necessity/imgui.ini")
    isfile(imguiinifile) && CImGui.LoadIniSettingsFromDisk(imguiinifile)

    # 加载字体
    fonts = unsafe_load(io.Fonts)
    # 加载全局字体
    global GLOBALFONT = CImGui.AddFontFromFileTTF(fonts, joinpath(CONF.Fonts.dir, CONF.Fonts.first))
    fontcfg = ImFontConfig_ImFontConfig()
    fontcfg.OversampleH = fontcfg.OversampleV = 1
    fontcfg.MergeMode = true
    CImGui.AddFontFromFileTTF(fonts, joinpath(CONF.Fonts.dir, CONF.Fonts.second), 0, fontcfg)

    # 加载全局图标字体
    CImGui.AddFontFromFileTTF(
        fonts, joinpath(ENV["QInsControlAssets"], "Necessity/fa-regular-400.ttf"), 0, fontcfg
    )
    CImGui.AddFontFromFileTTF(
        fonts, joinpath(ENV["QInsControlAssets"], "Necessity/fa-solid-900.ttf"), 0, fontcfg
    )

    global IMGUISTYLE = CImGui.GetStyle()
    global IMNODESSTYLE = imnodes_GetStyle()
    global MORESTYLE = MoreStyle()
    haskey(STYLES, CONF.Style.default) && loadstyle(STYLES[CONF.Style.default])

    # temp files
    isdir(joinpath(ENV["QInsControlAssets"], "temp")) || mkdir(joinpath(ENV["QInsControlAssets"], "temp"))

    firstframe = true

    rendertask = Threads.@spawn CImGui.render(
        ctx;
        window_size=CONF.Basic.windowsize, window_title="QInsControl", on_exit=onexitaction,
        opengl_version=VersionNumber(CONF.Basic.openglversion),
        wait_events=true
    ) do
        try
            if firstframe
                # 加载图标
                icons = FileIO.load.([joinpath(ENV["QInsControlAssets"], "Necessity/QInsControl.ico")])
                icons_8bit = reinterpret.(NTuple{4,UInt8}, icons)
                GLFW.SetWindowIcon(CImGui.current_window(), icons_8bit)
                GLFW.PollEvents()
                iconsize = reverse(size(icons[1]))
                global ICONID = CImGui.create_image_texture(iconsize...)
                CImGui.update_image_texture(ICONID, transpose(icons[1]), iconsize...)
                # 缩放设置
                scale = CImGui.GetWindowDpiScale()
                ImGuiStyle_ScaleAllSizes(IMGUISTYLE, scale / MORESTYLE.Variables.ImGuiScale)
                IMGUISTYLE.FontScaleDpi = scale

                firstframe = false
            end
            ###### 检查 STATICSTRINGS ######
            waittime("Check STATICSTRINGS", 36) && checklifetime()
            ###### 检查新版本 ######
            waittime("Check new version", 3600) && getnewestversion()

            MainWindow()
            if CImGui.BeginPopupModal("##windowshouldclose?", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                CImGui.TextColored(
                    MORESTYLE.Colors.ErrorText,
                    stcstr("\n\n", mlstr("data acquiring or sweeping, please wait......"), "\n\n\n")
                )
                CImGui.Button(mlstr("Confirm"), (-1, 0)) && CImGui.CloseCurrentPopup()
                CImGui.EndPopup()
            end
            if GLFW.WindowShouldClose(CImGui.current_window()) != 0 || !isshowapp()[]
                hasrefreshing = false
                for inses in values(INSTRBUFFERVIEWERS)
                    for ibv in values(inses)
                        for (_, qt) in filter(x -> x.second isa SweepQuantity, ibv.insbuf.quantities)
                            hasrefreshing |= qt.issweeping
                        end
                    end
                end
                if SYNCSTATES[Int(IsDAQTaskRunning)] || hasrefreshing
                    CImGui.OpenPopup("##windowshouldclose?")
                    GLFW.SetWindowShouldClose(CImGui.current_window(), false)
                    isshowapp()[] = true
                else
                    return
                end
            end
        catch e
            @error "[$(now())]\n$(mlstr("error in renderloop!"))" exception = e
            SYNCSTATES[Int(FatalError)] = true
            closeallwindows()
            showbacktrace()
        end
    end

    return rendertask
end

let
    ctxi = nothing
    global setctxi(ctx) = (ctxi = ctx)
    global function onexitaction()
        SYNCSTATES[Int(IsDAQTaskRunning)] || timed_remotecall_wait(() -> stop!(CPU), workers()[1])
        timed_remotecall_wait(() -> stop!(QICSERVER), workers()[1])
        stoprefresh()
        empty!(STATICSTRINGS)
        empty!(MLSTRINGS)
        empty!(IMAGES)
        empty!(FIGURES)
        temppath = joinpath(ENV["QInsControlAssets"], "temp")
        isdir(temppath) && for file in readdir(temppath, join=true)
            Base.Filesystem.rm(file, force=true)
        end
        CImGui.SaveIniSettingsToDisk(joinpath(ENV["QInsControlAssets"], "Necessity/imgui.ini"))
        imnodes_DestroyContext(ctxi)
    end
end