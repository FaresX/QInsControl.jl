function UI(breakdown=false)
    glfwDefaultWindowHints()
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2)
    if Sys.isapple()
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # required on Mac
    end

    # create window
    initws::Vector{Cint} = conf.Basic.windowsize
    global window = glfwCreateWindow(initws..., "QInsControl", C_NULL, C_NULL)
    @assert window != C_NULL
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)  # enable vsync

    # create OpenGL and GLFW context
    window_ctx = ImGuiGLFWBackend.create_context(window)
    gl_ctx = ImGuiOpenGLBackend.create_context()

    # 加载图标
    icons = FileIO.load.([joinpath(ENV["QInsControlAssets"], "Necessity/QInsControl.ico")])
    icons_8bit = reinterpret.(NTuple{4,UInt8}, icons)
    glfwicons = Base.unsafe_convert(Ref{GLFWimage}, Base.cconvert(Ref{GLFWimage}, icons_8bit))
    glfwSetWindowIcon(window, 1, glfwicons)
    iconsize = reverse(size(icons[1]))
    global iconid = ImGui_ImplOpenGL3_CreateImageTexture(iconsize...)
    ImGui_ImplOpenGL3_UpdateImageTexture(iconid, transpose(icons[1]), iconsize...)
    # 加载背景
    if isfile(conf.BGImage.path)
        try
            bgimg = RGB.(collect(transpose(FileIO.load(conf.BGImage.path))))
            bgsize = size(bgimg)
            global bgid = ImGui_ImplOpenGL3_CreateImageTexture(bgsize...; format=GL_RGB)
            ImGui_ImplOpenGL3_UpdateImageTexture(bgid, bgimg, bgsize...; format=GL_RGB)
        catch e
            @error "[$now()]\n加载背景出错！！！" exception = e
            global bgid = ImGui_ImplOpenGL3_CreateImageTexture(conf.Basic.windowsize...; format=GL_RGB)
        end
    else
        global bgid = ImGui_ImplOpenGL3_CreateImageTexture(conf.Basic.windowsize...)
    end


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
    conf.Basic.viewportenable && (io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_ViewportsEnable)
    # io.ConfigDockingWithShift = true

    # load imgui.ini
    # isfile(imguiinifile) ? CImGui.LoadIniSettingsFromDisk(imguiinifile) : touch(imguiinifile)
    imguiinifile = joinpath(ENV["QInsControlAssets"], "Necessity/imgui.ini")
    isfile(imguiinifile) && CImGui.LoadIniSettingsFromDisk(imguiinifile)

    # 加载字体
    fonts = unsafe_load(io.Fonts)
    ranges = ImVector_ImWchar_create()
    ImVector_ImWchar_Init(ranges)
    builder = ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()
    addchar = ['α', 'β', 'γ', 'μ', 'Ω', '┌', '│', '└']
    for c in addchar
        ImFontGlyphRangesBuilder_AddChar(builder, c)
    end
    ImFontGlyphRangesBuilder_AddRanges(builder, ImFontAtlas_GetGlyphRangesDefault(fonts))
    ImFontGlyphRangesBuilder_BuildRanges(builder, ranges)
    r = unsafe_wrap(Vector{ImVector_ImWchar}, ranges, 1)
    CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(conf.Fonts.dir, conf.Fonts.first),
        conf.Fonts.size,
        C_NULL,
        ImFontAtlas_GetGlyphRangesChineseFull(fonts)
    )
    fontcfg = ImFontConfig_ImFontConfig()
    fontcfg.MergeMode = true
    CImGui.AddFontFromFileTTF(fonts, joinpath(conf.Fonts.dir, conf.Fonts.second), conf.Fonts.size, fontcfg, r[1].Data)

    # 加载图标字体
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
        conf.Icons.size,
        fontcfg,
        icon_r[1].Data
    )
    CImGui.AddFontFromFileTTF(
        fonts,
        joinpath(ENV["QInsControlAssets"], "Necessity/fa-solid-900.ttf"),
        conf.Icons.size,
        fontcfg,
        icon_r[1].Data
    )

    # setup Platform/Renderer bindings
    ImGuiGLFWBackend.init(window_ctx)
    ImGuiOpenGLBackend.init(gl_ctx)

    global imguistyle = CImGui.GetStyle()
    global implotstyle = ImPlot.GetStyle()
    global imnodesstyle = imnodes_GetStyle()
    global morestyle = MoreStyle()
    haskey(styles, conf.Style.default) && loadstyle(styles[conf.Style.default])

    breakdown && closeallwindow()

    @async try
        clear_color = Cfloat[0.45, 0.55, 0.60, 1.00]
        global glfwwindowx = Cint(0)
        global glfwwindowy = Cint(0)
        iswindowiconified::Bool = false
        pick_fps_normal = conf.DAQ.pick_fps[1]
        while true
            glfwPollEvents()
            ImGuiOpenGLBackend.new_frame(gl_ctx)
            ImGuiGLFWBackend.new_frame(window_ctx)
            CImGui.NewFrame()

            ######检查STATICSTRINGS######
            waittime("Check STATICSTRINGS", 36) && checklifetime()

            ######保存图像######
            if savingimg
                @c glfwGetWindowPos(window, &glfwwindowx, &glfwwindowy)
                count_fps = saveimg()
                if count_fps == 1
                    iswindowiconified = glfwGetWindowAttrib(window, GLFW_ICONIFIED) != 0
                    if iswindowiconified
                        pick_fps_normal = conf.DAQ.pick_fps[1]
                        conf.DAQ.pick_fps[1] = conf.DAQ.pick_fps[2]
                    end
                elseif count_fps == 0
                    glfwSetWindowAttrib(window, GLFW_FLOATING, GLFW_FALSE)
                    if iswindowiconified
                        glfwIconifyWindow(window)
                        conf.DAQ.pick_fps[1] = pick_fps_normal
                    end
                else
                    iswindowiconified && glfwRestoreWindow(window)
                    glfwSetWindowAttrib(window, GLFW_FLOATING, GLFW_TRUE)
                end
            end

            MainWindow()
            if CImGui.BeginPopupModal("##windowshouldclose?", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                CImGui.TextColored(morestyle.Colors.LogError, "\n\n正在进行数据采集，请稍等。。。\n\n\n")
                CImGui.Button("确认", (-1, 0)) && CImGui.CloseCurrentPopup()
                CImGui.EndPopup()
            end
            if glfwWindowShouldClose(window) != 0
                if SyncStates[Int(isdaqtask_running)]
                    CImGui.OpenPopup("##windowshouldclose?")
                    glfwSetWindowShouldClose(window, false)
                else
                    break
                end
            end

            CImGui.Render()
            glfwMakeContextCurrent(window)

            width, height = Ref{Cint}(), Ref{Cint}() #! need helper fcn
            glfwGetFramebufferSize(window, width, height)
            display_w = width[]
            display_h = height[]

            glViewport(0, 0, display_w, display_h)
            glClearColor(clear_color...)
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
        @error "[$(now())]\nError in renderloop!" exception = e
        Base.show_backtrace(stderr, catch_backtrace())
    finally
        SyncStates[Int(isdaqtask_running)] || remotecall_wait(() -> stop!(CPU), workers()[1])
        CImGui.SaveIniSettingsToDisk(imguiinifile)
        ImGuiOpenGLBackend.shutdown(gl_ctx)
        ImGuiGLFWBackend.shutdown(window_ctx)
        imnodes_DestroyContext(ctxi)
        ImPlot.DestroyContext(ctxp)
        CImGui.DestroyContext(ctx)
        glfwDestroyWindow(window)
    end
end

