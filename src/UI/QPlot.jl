@kwdef mutable struct QPlot
    id::String = ""
end

const FIGURES::Dict{String,Figure} = Dict()

function QPlot(plt::QPlot, id; auto_resize_x=true, auto_resize_y=true, tooltip=false, stats=false)
    plt.id = id
    haskey(FIGURES, id) || (FIGURES[id] = Figure())
    CImGui.MakieFigure(
        id, FIGURES[id];
        auto_resize_x=auto_resize_x, auto_resize_y=auto_resize_y, tooltip=tooltip, stats=stats
    )
end

function toimguitheme!(theme)
    theme.GLMakie = Makie.Attributes(fxaa=false)
    Makie.set_theme!(theme)
    return theme
end

const MAKIETHEMES = Dict(
    "default" => Theme(),
    "ggplot2" => theme_ggplot2(),
    "black" => theme_black(),
    "light" => theme_light(),
    "dark" => theme_dark(),
    "latexfonts" => theme_latexfonts()
)