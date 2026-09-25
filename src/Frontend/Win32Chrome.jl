# Win32/DWM 窗口外观:系统圆角 + 随主题明暗的深色标题栏(仅 Windows 生效,其他平台 no-op)
# DWMWA_USE_IMMERSIVE_DARK_MODE 文档值 20(1809-1909 旧值为 19);DWMWA_WINDOW_CORNER_PREFERENCE = 33,DWMWCP_ROUND = 2
@static if Sys.iswindows()
    const DWMWA_USE_IMMERSIVE_DARK_MODE = 20
    const DWMWA_USE_IMMERSIVE_DARK_MODE_PRE1903 = 19
    const DWMWA_WINDOW_CORNER_PREFERENCE = 33
    const DWMWCP_DEFAULT = 0
    const DWMWCP_ROUND = 2

    function setdarktitlebar!(hwnd::Ptr{Cvoid}, dark::Bool)
        val = Cint(dark)
        for attr in (DWMWA_USE_IMMERSIVE_DARK_MODE, DWMWA_USE_IMMERSIVE_DARK_MODE_PRE1903)
            ccall((:DwmSetWindowAttribute, :dwmapi), Cint,
                (Ptr{Cvoid}, Cuint, Ref{Cint}, Cuint), hwnd, attr, Ref(val), sizeof(Cint)
            ) == 0 && return true
        end
        false
    end

    function setroundcorners!(hwnd::Ptr{Cvoid}, rounded::Bool = true)
        val = Cint(rounded ? DWMWCP_ROUND : DWMWCP_DEFAULT)
        ccall((:DwmSetWindowAttribute, :dwmapi), Cint,
            (Ptr{Cvoid}, Cuint, Ref{Cint}, Cuint), hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, Ref(val), sizeof(Cint)
        )
        return
    end
end

"""
    apply_win11_chrome!(win::GLFW.Window; dark::Bool)

应用 Win11 系统圆角与深色/浅色标题栏;非 Windows 或调用失败时静默跳过。幂等,主题切换后可重复调用。
"""
function apply_win11_chrome!(win::GLFW.Window; dark::Bool)
    @static if Sys.iswindows()
        hwnd = try
            GLFW.GetWin32Window(win)
        catch
            return
        end
        hwnd == C_NULL && return
        setroundcorners!(hwnd)
        setdarktitlebar!(hwnd, dark)
    end
    return
end

# 每个平台视口的 chrome 应用状态(id => 已应用的深色标题栏状态)
const CHROMEAPPLIED = Dict{UInt32,Bool}()
# 视口专属图标(id => 已应用的标题图标字符;"" = 应用图标)
const VIEWPORTICON = Dict{UInt32,String}()
# 视口装饰状态(id => 是否显示 OS 标题栏)
const VIEWPORTDECOR = Dict{UInt32,Bool}()
# 应用图标像素(由 Renderer 首帧填入),供拖出的新视口窗口补设
const APPICON = Ref{Any}(nothing)

# 系统标题栏没有图标字体:去掉 ImGui 标题里的 FontAwesome 私有区字符与 "###ID" 后缀
# (\x{...} 区间在 Julia 1.12 的 PCRE2 下报 "range out of order",改用 \u 形式)
cleantitle(s::AbstractString) = strip(replace(split(s, "###"; limit = 2)[1], r"[\uE000-\uF8FF]" => ""))

"""
    applyallchrome!(dark::Bool; force::Bool = false)

遍历 ImGui 所有平台视口(主窗口 + 拖出的独立 OS 窗口),对每个新出现或明暗状态变化的
视口应用 Win11 圆角与深色标题栏。渲染循环每帧调用(新视口在拖出时动态出现);
`force = true` 用于主题切换时全量重刷。
"""
function applyallchrome!(dark::Bool; force::Bool = false)
    @static if Sys.iswindows()
        pio = CImGui.GetPlatformIO()
        pio == C_NULL && return
        vps = unsafe_load(Ptr{CImGui.lib.ImGuiPlatformIO}(pio)).Viewports
        (vps.Size <= 0 || vps.Data == C_NULL) && return
        seen = UInt32[]
        for i in 1:vps.Size
            pvp = unsafe_load(vps.Data, i)
            pvp == C_NULL && continue
            vp = unsafe_load(pvp)
            hwnd = vp.PlatformHandleRaw
            (hwnd == C_NULL || hwnd === nothing) && continue
            id = UInt32(vp.ID)
            push!(seen, id)
            prev = get(CHROMEAPPLIED, id, missing)
            if force || prev === missing || prev != dark
                setroundcorners!(hwnd)
                setdarktitlebar!(hwnd, dark)
                CHROMEAPPLIED[id] = dark
            end
            # 新视口补设应用图标(OS 标题栏左上角)
            pglfw = vp.PlatformHandle
            if prev === missing && APPICON[] !== nothing && pglfw != C_NULL && pglfw !== nothing
                try
                    GLFW.SetWindowIcon(GLFW.Window(pglfw), APPICON[])
                catch
                end
            end
            # 标题清洗:OS 标题栏用系统字体渲染,私有区图标字符会变豆腐块
            if pglfw != C_NULL && pglfw !== nothing
                try
                    cur = unsafe_string(ccall((:glfwGetWindowTitle, GLFW.libglfw), Ptr{Cchar}, (Ptr{Cvoid},), pglfw))
                    clean = cleantitle(cur)
                    if !isempty(clean) && cur != clean
                        GLFW.SetWindowTitle(GLFW.Window(pglfw), clean)
                    end
                catch
                end
            end
            # 视口专属图标:取第一个登记到该视口的窗口标题图标,栅格化后设为 OS 图标
            # (主视口保持应用图标;glfwGetWindowTitle 不读,免每帧开销)
            pglfw2 = vp.PlatformHandle
            if pglfw2 != C_NULL && pglfw2 !== nothing
                icon = ""
                borderlesswin = false
                for (nm, vpid) in WINVIEWPORTS
                    if vpid == id
                        icon = get(WINTICONS, nm, "")
                        borderlesswin = borderless(nm)
                        (isempty(icon) && !borderlesswin) || break
                    end
                end
                previcon = get(VIEWPORTICON, id, missing)
                if previcon === missing || previcon != icon
                    bmp = isempty(icon) ? APPICON[] : faglyphbitmap(first(icon), dark)
                    if bmp !== nothing
                        try
                            GLFW.SetWindowIcon(GLFW.Window(pglfw2), bmp)
                            VIEWPORTICON[id] = icon
                        catch
                        end
                    end
                end
                # 视口装饰切换:无标题自绘窗口(NoTitleBar/setborderless!)拖出时
                # 隐藏 OS 标题栏;主视口永不改动。注意弹窗/tooltip 超出主窗口时
                # ImGui 会为其创建独立视口并刻意标记 NoDecoration,这类视口必须
                # 保持无边框,否则会长出 GLFW 标题栏
                if id != UInt32(unsafe_load(CImGui.GetMainViewport()).ID)
                    nodecor = (vp.Flags & CImGui.lib.ImGuiViewportFlags_NoDecoration) != 0
                    want = !borderlesswin && !nodecor
                    prevdec = get(VIEWPORTDECOR, id, missing)
                    if prevdec === missing || prevdec != want
                        try
                            GLFW.SetWindowAttrib(GLFW.Window(pglfw2), GLFW.DECORATED, want ? 1 : 0)
                            VIEWPORTDECOR[id] = want
                        catch
                        end
                    end
                end
            end
        end
        for id in collect(keys(CHROMEAPPLIED))
            id in seen || delete!(CHROMEAPPLIED, id)
        end
        for id in collect(keys(VIEWPORTICON))
            id in seen || delete!(VIEWPORTICON, id)
        end
        for id in collect(keys(VIEWPORTDECOR))
            id in seen || delete!(VIEWPORTDECOR, id)
        end
    end
    return
end

isthemedark(color::Vector{Cfloat}) = (0.2126color[1] + 0.7152color[2] + 0.0722color[3]) < 0.5

function currentglfwwindow()
    ext = Base.get_extension(CImGui, :GlfwOpenGLBackend)
    isnothing(ext) && return nothing
    w = ext._window
    return (w isa GLFW.Window && w.handle != C_NULL) ? w : nothing
end
