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
    GLMakie.activate!(scalefactor=unsafe_load(CImGui.GetIO().FontGlobalScale))
    return theme
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
    "bbc" => theme_bbc(),
    "ggthemr_flat" => ggthemr(:flat),
    "ggthemr_dust" => ggthemr(:dust),
    "ggthemr_fresh" => ggthemr(:fresh),
    "ggthemr_carrot" => ggthemr(:carrot),
    "ggthemr_flat_dark" => ggthemr(:flat_dark),
    "ggthemr_sky" => ggthemr(:sky),
    "ggthemr_copper" => ggthemr(:copper),
    "ggthemr_light" => ggthemr(:light),
    "ggthemr_pale" => ggthemr(:pale),
    "ggthemr_solarized" => ggthemr(:solarized),
    "ggthemr_sea" => ggthemr(:sea),
    "ggthemr_chalk" => ggthemr(:chalk),
    "ggthemr_greyscale" => ggthemr(:greyscale),
    "ggthemr_earth" => ggthemr(:earth),
    "ggthemr_lilac" => ggthemr(:lilac),
    "ggthemr_grass" => ggthemr(:grass),
    "ggthemr_grape" => ggthemr(:grape),
)