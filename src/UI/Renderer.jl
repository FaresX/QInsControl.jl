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
    ranges = ImVector_ImWchar_create()
    ImVector_ImWchar_Init(ranges)
    builder = ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()
    addchar = [
        'Α', 'Β', 'Γ', 'Δ', 'Ε', 'Ζ', 'Η', 'Θ', 'Ι', 'Κ', 'Λ', 'Ξ', 'Π', 'Ρ', 'Σ', 'Τ', 'Υ', 'Φ', 'Χ', 'Ψ', 'Ω',
        'α', 'β', 'γ', 'δ', 'ϵ', 'ζ', 'η', 'θ', 'ι', 'κ', 'λ', 'μ', 'ν', 'ξ', 'ο', 'π', 'ρ', 'σ', 'τ', 'υ', 'ϕ', 'χ', 'ψ', 'ω',
        '┌', '│', '└'
    ]
    for c in addchar
        ImFontGlyphRangesBuilder_AddChar(builder, c)
    end
    ImFontGlyphRangesBuilder_AddRanges(builder, ImFontAtlas_GetGlyphRangesDefault(fonts))
    ImFontGlyphRangesBuilder_BuildRanges(builder, ranges)
    r = unsafe_wrap(Vector{ImVector_ImWchar}, ranges, 1)
    # 加载全局字体
    global GLOBALFONT = CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(CONF.Fonts.dir, CONF.Fonts.first),
        CONF.Fonts.size,
        C_NULL,
        ImFontAtlas_GetGlyphRangesDefault(fonts)
    )
    fontcfg = ImFontConfig_ImFontConfig()
    fontcfg.OversampleH = fontcfg.OversampleV = 1
    fontcfg.MergeMode = true
    CImGui.AddFontFromFileTTF(fonts, joinpath(CONF.Fonts.dir, CONF.Fonts.second), CONF.Fonts.size, fontcfg, r[1].Data)

    # 加载全局图标字体
    icon_ranges = ImVector_ImWchar_create()
    ImVector_ImWchar_Init(icon_ranges)
    icon_ranges_ptr = pointer([ICON_MIN, ICON_MAX, ImWchar(0)])
    icon_builder = ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()
    ImFontGlyphRangesBuilder_AddRanges(icon_builder, icon_ranges_ptr)
    ImFontGlyphRangesBuilder_BuildRanges(icon_builder, icon_ranges)
    icon_r = unsafe_wrap(Vector{ImVector_ImWchar}, icon_ranges, 1)
    CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(ENV["QInsControlAssets"], "Necessity/fa-regular-400.ttf"),
        CONF.Fonts.size,
        fontcfg,
        icon_r[1].Data
    )
    CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(ENV["QInsControlAssets"], "Necessity/fa-solid-900.ttf"),
        CONF.Fonts.size,
        fontcfg,
        icon_r[1].Data
    )

    # 加载绘图字体
    global BIGFONT = CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(CONF.Fonts.dir, CONF.Fonts.bigfont),
        CONF.Fonts.plotfontsize,
        C_NULL,
        ImFontAtlas_GetGlyphRangesDefault(fonts)
    )
    # fontcfg = ImFontConfig_ImFontConfig()
    # fontcfg.MergeMode = true
    CImGui.AddFontFromFileTTF(fonts, joinpath(CONF.Fonts.dir, CONF.Fonts.second), CONF.Fonts.plotfontsize, fontcfg, r[1].Data)
    CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(CONF.Fonts.dir, CONF.Fonts.first),
        CONF.Fonts.plotfontsize,
        fontcfg,
        ImFontAtlas_GetGlyphRangesDefault(fonts)
    )

    # 加载绘图图标字体
    icon_ranges = ImVector_ImWchar_create()
    ImVector_ImWchar_Init(icon_ranges)
    icon_ranges_ptr = pointer([ICON_MIN, ICON_MAX, ImWchar(0)])
    icon_builder = ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()
    ImFontGlyphRangesBuilder_AddRanges(icon_builder, icon_ranges_ptr)
    ImFontGlyphRangesBuilder_BuildRanges(icon_builder, icon_ranges)
    icon_r = unsafe_wrap(Vector{ImVector_ImWchar}, icon_ranges, 1)
    CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(ENV["QInsControlAssets"], "Necessity/fa-regular-400.ttf"),
        CONF.Fonts.plotfontsize,
        fontcfg,
        icon_r[1].Data
    )
    CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(ENV["QInsControlAssets"], "Necessity/fa-solid-900.ttf"),
        CONF.Fonts.plotfontsize,
        fontcfg,
        icon_r[1].Data
    )

    global IMGUISTYLE = CImGui.GetStyle()
    global IMNODESSTYLE = imnodes_GetStyle()
    global MORESTYLE = MoreStyle()
    haskey(STYLES, CONF.Style.default) && loadstyle(STYLES[CONF.Style.default])

    # temp files
    isdir(joinpath(ENV["QInsControlAssets"], "temp")) || mkdir(joinpath(ENV["QInsControlAssets"], "temp"))

    global ICONID = nothing

    rendertask = Threads.@spawn CImGui.render(
        ctx;
        window_size=CONF.Basic.windowsize, window_title="QInsControl", on_exit=onexitaction,
        opengl_version=VersionNumber(CONF.Basic.openglversion)
    ) do
        try
            # 加载图标
            if isnothing(ICONID)
                icons = FileIO.load.([joinpath(ENV["QInsControlAssets"], "Necessity/QInsControl.ico")])
                icons_8bit = reinterpret.(NTuple{4,UInt8}, icons)
                GLFW.SetWindowIcon(CImGui.current_window(), icons_8bit)
                GLFW.PollEvents()
                iconsize = reverse(size(icons[1]))
                global ICONID = CImGui.create_image_texture(iconsize...)
                CImGui.update_image_texture(ICONID, transpose(icons[1]), iconsize...)
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