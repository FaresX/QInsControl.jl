# Toast 通知:右上角滑入/淡出的非阻塞消息,任何线程可投递(线程安全队列 + dorender 供帧)
struct Toast
    type::Symbol      # :info / :success / :warn / :error
    title::String
    msg::String
    t0::Float64
    duration::Float64
end

const toasticons = Dict(
    :info => ICONS.ICON_CIRCLE_INFO,
    :success => ICONS.ICON_CIRCLE_CHECK,
    :warn => ICONS.ICON_TRIANGLE_EXCLAMATION,
    :error => ICONS.ICON_CIRCLE_EXCLAMATION,
)

# 与 @trycatch 相同的错误处理,额外投递一条 error toast
macro toastcatch(msg, ex)
    esc(
        quote
            try
                $ex
            catch e
                @error string("[", now(), "]\n", $msg) exception = e
                showbacktrace()
                toast(:error, String($msg), sprint(showerror, e))
            end
        end
    )
end

let
    toasts = Vector{Toast}()
    toastlock = ReentrantLock()
    lastheights = Float32[]  # 上一帧各 toast 高度,用于本帧堆叠定位(高度变化只跳一次)

    global function toast(type::Symbol, title::AbstractString, msg::AbstractString = ""; duration::Real = MORESTYLE.Variables.ToastDuration)
        type in keys(toasticons) || (type = :info)
        lock(toastlock) do
            push!(toasts, Toast(type, String(title), String(msg), time(), Float64(duration)))
            length(toasts) > 8 && popfirst!(toasts)
        end
        dorender()
        return
    end

    global function rendernotifications()
        nowt = time()
        alive = lock(toastlock) do
            filter!(t -> nowt - t.t0 < t.duration, toasts)
            copy(toasts)
        end
        isempty(alive) && (empty!(lastheights); return)
        dorender()  # 动画存活期间持续申请渲染帧

        speed = MORESTYLE.Variables.AnimSpeed
        vp = CImGui.GetMainViewport()
        dpi = unsafe_load(vp.DpiScale)  # 本函数在窗口作用域外调用,GetWindowDpiScale 会断言失败,必须用视口的
        W = 340f0 * dpi
        margin = 10f0 * dpi
        wpos, wsz = unsafe_load(vp.Pos), unsafe_load(vp.Size)  # 主视口(应用全区)右上角为锚点
        basex = wpos[1] + wsz[1] - W - margin
        basey = wpos[2] + margin
        height_of(i) = (i <= length(lastheights) ? lastheights[i] : 60f0 * dpi)
        flags = CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoResize |
                CImGui.ImGuiWindowFlags_NoMove | CImGui.ImGuiWindowFlags_NoCollapse |
                CImGui.ImGuiWindowFlags_NoSavedSettings | CImGui.ImGuiWindowFlags_NoFocusOnAppearing |
                CImGui.ImGuiWindowFlags_NoNav | CImGui.ImGuiWindowFlags_NoDocking |
                CImGui.ImGuiWindowFlags_NoScrollbar
        heights = Float32[]
        for (i, t) in enumerate(alive)
            age = nowt - t.t0
            if speed <= 0
                tin = fade = 1.0
            else
                tin = clamp(age / (0.25 / speed), 0.0, 1.0)
                fade = clamp((t.duration - age) / (0.5 / speed), 0.0, 1.0)
            end
            alpha = Cfloat(min(tin, fade))
            dx = (1 - tin) * (W + 2margin)
            y = basey + sum(height_of(j) for j in 1:(i - 1); init = 0.0f0) + (i - 1) * margin
            ctext, cbg = typecolors(t.type)
            CImGui.SetNextWindowPos((Cfloat(basex + dx), y), CImGui.ImGuiCond_Always)
            CImGui.SetNextWindowSize((W, Cfloat(0)), CImGui.ImGuiCond_Always)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_Alpha, alpha)
            if CImGui.Begin(stcstr("##toast", t.t0, i), C_NULL, flags)
                SetWindowShadow(0.8 * alpha)
                h = CImGui.GetFrameHeight()
                wpos0 = CImGui.GetWindowPos()
                # 标题条渐变(主题 AccentTop==AccentBottom 同色时退化为单色)
                gradientfill(
                    CImGui.GetWindowDrawList(), wpos0, wpos0 .+ (W, h),
                    [cbg[1], cbg[2], cbg[3], min(0.9, cbg[4])], [cbg[1] * 0.7, cbg[2] * 0.8, cbg[3] * 0.9, min(0.9, cbg[4])];
                    dir = :h
                )
                CImGui.TextColored(ctext, stcstr(toasticons[t.type], " ", t.title))
                !isempty(t.msg) && CImGui.TextWrapped(t.msg)
                push!(heights, CImGui.GetWindowSize()[2])
            end
            CImGui.End()
            CImGui.PopStyleVar()
        end
        empty!(lastheights)
        append!(lastheights, heights)
        return
    end
end

function typecolors(type::Symbol)
    type === :success && return (MORESTYLE.Colors.SuccessText, MORESTYLE.Colors.SuccessBg)
    type === :warn && return (MORESTYLE.Colors.WarnText, MORESTYLE.Colors.WarnBg)
    type === :error && return (MORESTYLE.Colors.ErrorText, MORESTYLE.Colors.ErrorBg)
    (MORESTYLE.Colors.InfoText, MORESTYLE.Colors.InfoBg)
end
