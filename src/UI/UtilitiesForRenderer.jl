function ImGui_ImplOpenGL3_CreateImageTexture(image_width, image_height; format=GL_RGBA, type=GL_UNSIGNED_BYTE)

    id = GLuint(0)
    @c glGenTextures(1, &id)
    glBindTexture(GL_TEXTURE_2D, id)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
    glTexImage2D(GL_TEXTURE_2D, 0, format, GLsizei(image_width), GLsizei(image_height), 0, format, type, C_NULL)
    g_ImageTexture[id] = id

    return Int(id)
end

function ImGui_ImplOpenGL3_UpdateImageTexture(id, image_data, image_width, image_height; format=GL_RGBA, type=GL_UNSIGNED_BYTE)
    glBindTexture(GL_TEXTURE_2D, g_ImageTexture[id])
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, GLsizei(image_width), GLsizei(image_height), format, type, image_data)
end

const g_ImageTexture = Dict{Int,GLuint}()

function DisplayBG(bgid, width, height)
    zoom = 300

    # glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    # glMatrixMode(GL_PROJECTION)
    # glLoadIdentity()
    # glOrtho(-zoom* width / height, zoom* width / height, -zoom, zoom, -300.0, 300.0) #切换为正交视角；
    # glMatrixMode(GL_MODELVIEW)
    # glLoadIdentity()

    # glColor3f(1.000, 1.000, 1.000)   
    # glDisable(GL_DEPTH_TEST) #关闭深度测试;

    texture = g_ImageTexture[bgid] #加载图片

    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, texture)
    glBegin(GL_QUADS) #将图片四个角的位置设置为正交窗口后裁剪面的四个角；
    glTexCoord2d(0.0, 0.0)
    glVertex3d(-zoom * width / height, -zoom, -300)
    glTexCoord2d(1.0, 0.0)
    glVertex3d(zoom * width / height, -zoom, -300)
    glTexCoord2d(1.0, 1.0)
    glVertex3d(zoom * width / height, zoom, -300)
    glTexCoord2d(0.0, 1.0)
    glVertex3d(-zoom * width / height, zoom, -300)
    glEnd()

    glDisable(GL_TEXTURE_2D)
    # glEnable(GL_DEPTH_TEST) #开启深度测试；

    # glMatrixMode(GL_PROJECTION)
    # glLoadIdentity()
    # gluPerspective(45, (float)win_width/win_height, 0.01, 3000)
    # glMatrixMode(GL_MODELVIEW)
    # glLoadIdentity()

    # #显示三维场景；
    # glColor3f(0.1f, 0.1f, 0.1f)
    # glLineWidth(0.1f)
    # glBegin(GL_LINES)
    # for i = -100:10:100
    #     glVertex3f(i, 0, -100)
    #     glVertex3f(i, 0, 100)
    #     glVertex3f(100, 0, i)
    #     glVertex3f(-100, 0, i)
    # end
    # glEnd()

    glutSwapBuffers()
end

function Base.cconvert(::Type{Ref{GLFWimage}}, image::AbstractMatrix{NTuple{4,UInt8}})
    imaget = permutedims(image) # c libglfw expects row major matrix
    return Base.RefValue{GLFWimage}(GLFWimage(size(imaget)..., pointer(imaget)))
end

function Base.cconvert(::Type{Ref{GLFWimage}}, images::Vector{<:AbstractMatrix{NTuple{4,UInt8}}})
    imagest = permutedims.(images)
    out = Vector{GLFWimage}(undef, length(imagest))
    @inbounds for i in eachindex(imagest)
        out[i] = GLFWimage(size(imagest[i])..., pointer(imagest[i]))
    end
    return (out, imagest)
end

function Base.unsafe_convert(::Type{Ref{GLFWimage}}, data::Tuple{Vector{GLFWimage},Vector{<:AbstractMatrix{NTuple{4,UInt8}}}})
    Base.unsafe_convert(Ref{GLFWimage}, data[1])
end

function ImGui_ImplGlfw_UpdateMonitors_fixeddpiscale(ctx::ImGuiGLFWBackend.Context)
    platform_io::Ptr{ImGuiPlatformIO} = igGetPlatformIO()
    monitors_count = Cint(0)
    ptr = @c glfwGetMonitors(&monitors_count)
    glfw_monitors = unsafe_wrap(Array, ptr, monitors_count)
    monitors_ptr::Ptr{ImGuiPlatformMonitor} = Libc.malloc(monitors_count * sizeof(ImGuiPlatformMonitor))
    for i = 1:monitors_count
        glfw_monitor = glfw_monitors[i]
        mptr::Ptr{ImGuiPlatformMonitor} = monitors_ptr + (i - 1) * sizeof(ImGuiPlatformMonitor)

        x, y = Cint(0), Cint(0)
        @c glfwGetMonitorPos(glfw_monitor, &x, &y)
        vid_mode = unsafe_load(glfwGetVideoMode(glfw_monitor))
        mptr.MainPos = ImVec2(x, y)
        mptr.MainSize = ImVec2(vid_mode.width, vid_mode.height)
        mptr.WorkPos = ImVec2(x, y)
        mptr.WorkSize = ImVec2(vid_mode.width, vid_mode.height)

        w, h = Cint(0), Cint(0)
        @c glfwGetMonitorWorkarea(glfw_monitors[i], &x, &y, &w, &h)
        if w > 0 && h > 0
            mptr.WorkPos = ImVec2(Cfloat(x), Cfloat(y))
            mptr.WorkSize = ImVec2(Cfloat(w), Cfloat(h))
        end

        x_scale, y_scale = Cfloat(0), Cfloat(0)
        @c glfwGetMonitorContentScale(glfw_monitor, &x_scale, &y_scale)
        mptr.DpiScale = 1.0f0
    end

    platform_io.Monitors = ImVector_ImGuiPlatformMonitor(monitors_count, monitors_count, monitors_ptr)
    ctx.WantUpdateMonitors = false

    return nothing
end

function Update_DpiScale(x_scale_old::Ref{Cfloat})
    monitors_count = Cint(0)
    ptr = @c glfwGetMonitors(&monitors_count)
    glfw_monitors = unsafe_wrap(Array, ptr, monitors_count)
    x_scale, y_scale = Cfloat(0), Cfloat(0)
    @c glfwGetMonitorContentScale(glfw_monitors[1], &x_scale, &y_scale)
    if x_scale != x_scale_old[]
        ImGuiStyle_ScaleAllSizes(IMGUISTYLE, x_scale)
        CImGui.GetIO().FontGlobalScale = x_scale
        x_scale_old[] = x_scale
    end
end

# ImGuiIO = 5440 + 16 = 5456
# ImVector_ImWchar = 16
# ImGuiPlatformIO = 208 + 16 = 224
# ImVector_ImGuiViewportPtr = 16
# ImGuiStyle = 196 + 55 * 16 = 1076
# ImVec4 = 16
# ImGuiConfigFlags = 4
# ImDrawListSharedData = 508
# ImVec2 = 8
# ImDrawListFlags = 4
# ImU8 = 1
# ImGuiID = 4
# ImVector_ImGuiWindowPtr = 16
# ImGuiStorage = 16
# ImU32 = 4
# ImU64 = 8
# ImGuiInputSource = 4
# ImGuiNextWindowData = 148
# ImGuiNextItemData = 16 + 1
# ImGuiNextWindowDataFlags = 4
# ImGuiCond = 4
# ImRect = 16
# ImGuiSizeCallback = 8
# ImGuiWindowClass = 28 + 2
# ImVector_ImGuiColorMod = 16
# ImVector_ImGuiStyleMod = 16
# ImVector_ImFontPtr = 16
# ImVector_ImGuiID = 16
# ImVector_ImGuiItemFlags = 16
# ImVector_ImGuiGroupData = 16
# ImVector_ImGuiPopupData = 16
# ImVector_ImGuiViewportPPtr = 16
# ImGuiPlatformMonitor = 36