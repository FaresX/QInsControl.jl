function UI(breakdown=false)
    glfwDefaultWindowHints()
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2)
    CONF.Basic.scale && glfwWindowHint(GLFW_SCALE_TO_MONITOR, GLFW_TRUE)
    if Sys.isapple()
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # required on Mac
    end

    # create window
    CONF.Basic.viewportenable || (CONF.Basic.hidewindow = false)
    window = glfwCreateWindow(CONF.Basic.windowsize..., "QInsControl", C_NULL, C_NULL)
    @assert window != C_NULL
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)  # enable vsync
    CONF.Basic.hidewindow && glfwHideWindow(window)

    # create OpenGL and GLFW context
    window_ctx = ImGuiGLFWBackend.create_context(window)
    gl_ctx = ImGuiOpenGLBackend.create_context()

    # 加载图标
    icons = FileIO.load.([joinpath(ENV["QInsControlAssets"], "Necessity/QInsControl.ico")])
    icons_8bit = reinterpret.(NTuple{4,UInt8}, icons)
    glfwicons = Base.unsafe_convert(Ref{GLFWimage}, Base.cconvert(Ref{GLFWimage}, icons_8bit))
    glfwSetWindowIcon(window, 1, glfwicons)
    iconsize = reverse(size(icons[1]))
    global ICONID = ImGui_ImplOpenGL3_CreateImageTexture(iconsize...)
    ImGui_ImplOpenGL3_UpdateImageTexture(ICONID, transpose(icons[1]), iconsize...)
    # 加载背景
    createimage(CONF.BGImage.path)


    # setup Dear ImGui context
    ctx = CImGui.CreateContext()

    #setup ImPlot context
    ctxp = ImPlot.CreateContext()
    ImPlot.SetImGuiContext(ctx)

    #setup ImNodes context
    ctxi = imnodes_CreateContext()

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
        ImFontAtlas_GetGlyphRangesChineseFull(fonts)
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
    global PLOTFONT = CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(CONF.Fonts.dir, CONF.Fonts.plotfont),
        CONF.Fonts.plotfontsize,
        C_NULL,
        ImFontAtlas_GetGlyphRangesChineseFull(fonts)
    )
    # fontcfg = ImFontConfig_ImFontConfig()
    # fontcfg.MergeMode = true
    CImGui.AddFontFromFileTTF(fonts, joinpath(CONF.Fonts.dir, CONF.Fonts.second), CONF.Fonts.plotfontsize, fontcfg, r[1].Data)
    CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(CONF.Fonts.dir, CONF.Fonts.first),
        CONF.Fonts.plotfontsize,
        fontcfg,
        ImFontAtlas_GetGlyphRangesChineseFull(fonts)
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

    # setup Platform/Renderer bindings
    ImGuiGLFWBackend.init(window_ctx)
    ImGuiOpenGLBackend.init(gl_ctx)
    ImGui_ImplGlfw_UpdateMonitors_fixeddpiscale(window_ctx)

    global IMGUISTYLE = CImGui.GetStyle()
    global IMPLOTSTYLE = ImPlot.GetStyle()
    global IMNODESSTYLE = imnodes_GetStyle()
    global MORESTYLE = MoreStyle()
    haskey(STYLES, CONF.Style.default) && loadstyle(STYLES[CONF.Style.default])

    breakdown && closeallwindow()

    uitask = Threads.@spawn :interactive try
        scale_old::Cfloat = 0
        isshowapp()[] = true
        updateframe::Bool = true
        # firsthide::Bool = CONF.Basic.hidewindow
        while true
            glfwSwapInterval(updateframe ? 1 : CONF.Basic.noactionswapinterval)
            glfwPollEvents()
            ImGuiOpenGLBackend.new_frame(gl_ctx)
            ImGuiGLFWBackend.new_frame(window_ctx)
            CImGui.NewFrame()
            CONF.Basic.scale && @c Update_DpiScale(&scale_old)

            ###### 检查 STATICSTRINGS ######
            waittime("Check STATICSTRINGS", 36) && checklifetime()

            MainWindow()
            if CImGui.BeginPopupModal("##windowshouldclose?", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                CImGui.TextColored(
                    MORESTYLE.Colors.LogError,
                    stcstr("\n\n", mlstr("data acquiring or sweeping, please wait......"), "\n\n\n")
                )
                CImGui.Button(mlstr("Confirm"), (-1, 0)) && CImGui.CloseCurrentPopup()
                CImGui.EndPopup()
            end
            if glfwWindowShouldClose(window) != 0 || !isshowapp()[]
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
                    glfwSetWindowShouldClose(window, false)
                    isshowapp()[] = true
                else
                    break
                end
            end

            ###### Hide Window ######
            # if CONF.Basic.hidewindow ⊻ (glfwGetWindowAttrib(window, GLFW_VISIBLE) == GLFW_FALSE) || firsthide
            #     firsthide && (firsthide = false)
            #     if CONF.Basic.hidewindow
            #         glfwHideWindow(window)
            #         glfwSetWindowSize(window, 1, 1)
            #     else
            #         glfwShowWindow(window)
            #         glfwSetWindowSize(window, glfwwindoww, glfwwindowh)
            #     end
            # end
            # if glfwGetWindowAttrib(window, GLFW_VISIBLE) == GLFW_FALSE
            #     glfwSetWindowPos(window, glfwwindowx, glfwwindowy)
            # end
            updateframe = updating()

            CImGui.Render()
            glfwMakeContextCurrent(window)

            width, height = Ref{Cint}(), Ref{Cint}() #! need helper fcn
            glfwGetFramebufferSize(window, width, height)
            display_w = width[]
            display_h = height[]

            glViewport(0, 0, display_w, display_h)
            glClearColor(MORESTYLE.Colors.ClearColor...)
            glClear(GL_COLOR_BUFFER_BIT)
            ImGuiOpenGLBackend.render(gl_ctx)

            if unsafe_load(io.ConfigFlags) & ImGuiConfigFlags_ViewportsEnable == ImGuiConfigFlags_ViewportsEnable
                backup_current_context = glfwGetCurrentContext()
                igUpdatePlatformWindows()
                GC.@preserve gl_ctx igRenderPlatformWindowsDefault(C_NULL, pointer_from_objref(gl_ctx))
                glfwMakeContextCurrent(backup_current_context)
            end

            glfwSwapBuffers(window)
            GC.safepoint()
            yield()
        end
    catch e
        @error "[$(now())]\n$(mlstr("Error in renderloop!"))" exception = e
        showbacktrace()
    finally
        SYNCSTATES[Int(IsDAQTaskRunning)] || remotecall_wait(() -> stop!(CPU), workers()[1])
        schedule(AUTOREFRESHTASK, mlstr("Stop"); error=true)
        empty!(STATICSTRINGS)
        empty!(MLSTRINGS)
        empty!(IMAGES)
        for file in readdir(joinpath(ENV["QInsControlAssets"], "temp"), join=true)
            Base.Filesystem.rm(file, force=true)
        end
        CImGui.SaveIniSettingsToDisk(imguiinifile)
        ImGuiOpenGLBackend.shutdown(gl_ctx)
        ImGuiGLFWBackend.shutdown(window_ctx)
        imnodes_DestroyContext(ctxi)
        ImPlot.DestroyContext(ctxp)
        CImGui.DestroyContext(ctx)
        glfwDestroyWindow(window)
    end

    return window, uitask
end

let
    t1 = time()
    mousepos::CImGui.ImVec2 = (0, 0)
    global function updating()
        if time() - t1 > 2
            newmousepos = CImGui.GetMousePos()
            mousemoved = newmousepos != mousepos
            mousemoved && (mousepos = newmousepos)
            updateframe = CImGui.IsAnyMouseDown()
            updateframe |= CImGui.IsKeyDown(ImGuiKey_MouseWheelX) || CImGui.IsKeyDown(ImGuiKey_MouseWheelY)
            updateframe |= CImGui.IsAnyItemActive() || (CImGui.IsAnyWindowHovered() && mousemoved)
            updateframe && (t1 = time())
            return updateframe
        else
            return true
        end
    end
end