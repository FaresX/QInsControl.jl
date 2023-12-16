@kwdef mutable struct PlotStates
    id::String = ""
    xhv::Bool = false
    yhv::Bool = false
    chv::Bool = false
    phv::Bool = false
    showtooltip::Bool = true
    mspos::ImPlot.ImPlotPoint = ImPlot.ImPlotPoint(0, 0)
    plotpos::CImGui.ImVec2 = (0, 0)
    plotsize::CImGui.ImVec2 = (0, 0)
end

@kwdef mutable struct Annotation
    label::String = "Ann"
    posx::Cdouble = 0
    posy::Cdouble = 0
    offsetx::Cdouble = 0
    offsety::Cdouble = 0
    color::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    possz::Cfloat = 4
end
Annotation(label, posx, posy) = Annotation(label, posx, posy, posx, posy, [1.000, 1.000, 1.000, 1.000], 4)

@kwdef mutable struct Linecut
    ptype::String = "line"
    vline::Bool = true
    pos::Cdouble = 0
end

@kwdef mutable struct PlotSeries
    x::Vector{Tx} where {Tx <: Real}
    y::Vector{Ty} where {Ty <: Real}
    z::Vector{Tz} where {Tz <: Real}
    ptype::AbstractString = "line"
    
end

@kwdef mutable struct Plots
    x::Vector{Tx} where {Tx<:Union{Real,String}} = Union{Real,String}[]
    y::Vector{Vector{Ty}} where {Ty<:Real} = [Real[]]
    z::Matrix{Tz} where {Tz<:Float64} = Matrix{Float64}(undef, 0, 0)
    ptype::String = "line"
    title::String = "title"
    xlabel::String = "x"
    ylabel::String = "y"
    zlabel::String = "z"
    legends::Vector{String} = [string("y", i) for i in eachindex(y)]
    cmap::Cint = 4
    anns::Vector{Annotation} = Annotation[]
    linecuts::Vector{Linecut} = Linecut[]
    ps::PlotStates = PlotStates()
end
UIPlot(x, y, z) = UIPlot(x=x, y=y, z=z)