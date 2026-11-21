@kwdef mutable struct QPlot
    id::String = ""
    size::Vector{Float64} = [600, 400]
end

const FIGURES::Dict{String,Figure} = Dict()

# —— WGL BUSY 兜底 ——
#新浮动视口创建与 GLMakie GPU 资源注册(字形图集 TextureAtlas 有独立上下文,上传任务并发
#切换)并发时,偶发 "WGL: Failed to make context current: 请求的资源在使用中"(上下文仍被
#另一线程短暂持有,连开两个绘图窗口时最易触发)。GLMakie/扩展内部直接抛 GLFWError,一帧
#报废并连锁 closeallwindows,把刚打开的绘图又全部关掉。
#注:无法在运行期拦截依赖包内部的切换调用——world age 决定预编译方法体内的调用点永远指向
#旧世界,运行期 @eval 覆盖对它们无效。所以兜底做在应用侧唯一调用点:捕获 GLFWError 后销毁
#半创建的 screen(figure 内容原样保留),等占用释放后同帧重建;重试耗尽也不再向上传播,下一
#帧会自然再试。
function remakiecontext(fig)
    ext = Base.get_extension(CImGui, :MakieIntegration)
    isnothing(ext) && return
    #push_screen! 会递归传播到所有子 Scene,摘除也必须同样递归,否则残留的旧 screen 会让
    #重试 display 报 "can not display a scene in multiple Screens"
    popscreens!(Makie.get_scene(fig))
    for (mid, imfig) in ext.makie_context
        imfig.figure === fig || continue
        try
            GLMakie.destroy!(imfig.screen)
        catch
        end
        delete!(ext.makie_context, mid)
        break
    end
    nothing
end

function popscreens!(scene)
    filter!(s -> !(s isa GLMakie.Screen), scene.current_screens)
    for child in scene.children
        popscreens!(child)
    end
    nothing
end

function makiemfigure(id, fig; kwargs...)
    result = nothing
    attempt = 0
    while true
        attempt += 1
        try
            result = CImGui.MakieFigure(id, fig; kwargs...)
            break
        catch e
            #绘图帧的任何异常(WGL BUSY / multiple Screens / ComputeEdge 包装错误)都不该
            #炸整帧并连锁 closeallwindows:清理半创建状态后重试,耗尽也只 warn 不传播,下一
            #帧会自然重建
            remakiecontext(fig)
            attempt < 3 || begin
                @warn "[$(now())]\n$(mlstr("plotting data failed!!!"))" exception = e attempt =
                    attempt screens = repr(Makie.get_scene(fig).current_screens)
                return nothing
            end
            sleep(0.01) #等 WGL 占用释放
        end
    end
    # GLMakie 0.13 的 render_frame(resize_buffers=false)不再随 scene 尺寸调整 framebuffer
    # (扩展依赖旧版行为),拉伸绘图窗口后纹理会停在旧尺寸;这里手动补齐,复刻
    # render_frame(resize_buffers=true) 的调整逻辑,拖拽手势下一帧纹理即跟随
    try
        ext = Base.get_extension(CImGui, :MakieIntegration)
        if !isnothing(ext)
            for (mid, imfig) in ext.makie_context
                imfig.figure === fig || continue
                scene = imfig.screen.scene
                isnothing(scene) && break
                target = round.(Int, imfig.screen.px_per_unit[] .* size(scene))
                size(imfig.screen.framebuffer) == target ||
                    resize!(imfig.screen.framebuffer, target...)
                break
            end
        end
    catch
    end
    return result
end

function QPlot(plt::QPlot, id; auto_resize_x=true, auto_resize_y=true, tooltip=false, stats=false)
    id == "" && return nothing
    plt.id = id
    plt.size = [CImGui.GetContentRegionAvail()...]
    haskey(FIGURES, id) || (FIGURES[id] = Figure())
    makiemfigure(
        id, FIGURES[id];
        auto_resize_x=auto_resize_x, auto_resize_y=auto_resize_y, tooltip=tooltip, stats=stats
    )
end

function toimguitheme!(theme)
    theme.GLMakie = Makie.Attributes(fxaa=false)
    fontsize = unsafe_load(IMGUISTYLE.FontSizeBase) * CImGui.GetWindowDpiScale()
    new_theme = merge(theme, Theme(fontsize=fontsize))
    Makie.set_theme!(new_theme)
    GLMakie.activate!(scalefactor=1)
    return new_theme
end

function rmplot!(plt::QPlot)
    if haskey(FIGURES, plt.id)
        figure = FIGURES[plt.id]
        empty!(figure)
        extension_module = Base.get_extension(CImGui, :MakieIntegration)
        for (id, imfig) in extension_module.makie_context
            imfig.figure == figure && (delete!(extension_module.makie_context, id); break)
        end
        delete!(FIGURES, plt.id)
    end
end

const MAKIETHEMES = Dict(
    "default" => Theme(),
    "ggplot2" => theme_ggplot2(),
    "black" => theme_black(),
    "light" => theme_light(),
    "dark" => theme_dark(),
    # "latexfonts" => theme_latexfonts(),
    # "bbc" => theme_bbc(),
    # "ggthemr_flat" => ggthemr(:flat),
    # "ggthemr_dust" => ggthemr(:dust),
    # "ggthemr_fresh" => ggthemr(:fresh),
    # "ggthemr_carrot" => ggthemr(:carrot),
    # "ggthemr_flat_dark" => ggthemr(:flat_dark),
    # "ggthemr_sky" => ggthemr(:sky),
    # "ggthemr_copper" => ggthemr(:copper),
    # "ggthemr_light" => ggthemr(:light),
    # "ggthemr_pale" => ggthemr(:pale),
    # "ggthemr_solarized" => ggthemr(:solarized),
    # "ggthemr_sea" => ggthemr(:sea),
    # "ggthemr_chalk" => ggthemr(:chalk),
    # "ggthemr_greyscale" => ggthemr(:greyscale),
    # "ggthemr_earth" => ggthemr(:earth),
    # "ggthemr_lilac" => ggthemr(:lilac),
    # "ggthemr_grass" => ggthemr(:grass),
    # "ggthemr_grape" => ggthemr(:grape),
)