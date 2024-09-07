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