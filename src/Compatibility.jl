Base.convert(::Type{OrderedDict{String,T}}, vec::Vector{T}) where {T} = OrderedDict(string(i) => v for (i, v) in enumerate(vec))
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Vector{Node}) = OrderedDict(node.id => node for node in nodes)
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Type{OrderedDict{Cint,Node}}) = OrderedDict{Cint,AbstractNode}(node.id => node for node in nodes)

mutable struct InstrQuantity <: AbstractQuantity
    # back end
    enable::Bool
    name::String
    alias::String
    step::String
    stop::String
    delay::Cfloat
    set::String
    optkeys::Vector{String}
    optvalues::Vector{String}
    optedidx::Cint
    read::String
    utype::String
    uindex::Int
    type::Symbol
    help::String
    isautorefresh::Bool
    issweeping::Bool
    # front end
    show_edit::String
    show_view::String
    passfilter::Bool
end

InstrQuantity() = InstrQuantity(
    true, "", "", "", "", Cfloat(0.1), "", [], [], 1, "", "", 1, :set, "", false, false,
    "", "", true
)

mutable struct LogBlock <: AbstractBlock
    regmin::ImVec2
    regmax::ImVec2
end
LogBlock() = LogBlock((0, 0), (0, 0))

mutable struct SaveBlock <: AbstractBlock
    varname::String
    mark::String
    regmin::ImVec2
    regmax::ImVec2
end
SaveBlock() = SaveBlock("", "", (0, 0), (0, 0))

tocodes(::LogBlock) = :(remotecall_wait(eval, 1, :(log_instrbufferviewers())))

function tocodes(bk::SaveBlock)
    var = Symbol(bk.varname)
    return if rstrip(bk.mark, ' ') == ""
        :(put!(databuf_lc, ($(bk.varname), string($var))))
    else
        :(put!(databuf_lc, ($(bk.mark), string($var))))
    end
end

function edit(bk::LogBlock)
    CImGui.BeginChild("##LogBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.LogBlock)
    CImGui.SameLine()
    CImGui.Button("LogBlock##", (-1, 0))
    CImGui.EndChild()
end

function edit(bk::SaveBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.BeginChild("##SaveBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.SaveBlock)
    CImGui.SameLine()
    CImGui.PushItemWidth(CImGui.GetContentRegionAvailWidth() / 2)
    @c InputTextWithHintRSZ("##SaveBlock mark", mlstr("mark"), &bk.mark)
    CImGui.PopItemWidth()
    CImGui.SameLine()
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##SaveBlock var", mlstr("variable"), &bk.varname)
    CImGui.PopItemWidth()
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function view(logbk::LogBlock)
    CImGui.BeginChild("##LogBlock", (Float32(0), bkheight(logbk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.Console)
    CImGui.SameLine()
    CImGui.Button("LogBlock", (-1, 0))
    CImGui.EndChild()
end

function view(bk::SaveBlock)
    CImGui.BeginChild("##SaveBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.SaveButton)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(stcstr(mlstr("mark"), ": ", bk.mark, "\t", mlstr("variable"), ": ", bk.varname), (-1, 0))
    CImGui.PopStyleVar()
    CImGui.EndChild()
end

function Base.show(io::IO, bk::LogBlock)
    str = """
    LogBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
    """
    print(io, str)
end

function Base.show(io::IO, bk::SaveBlock)
    str = """
    SaveBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
              mark : $(bk.mark)
               var : $(bk.varname)
    """
    print(io, str)
end

function combotodataplot(dtviewer::DataViewer)
    datakeys = keys(dtviewer.data)
    if "uiplots" in datakeys
        dtviewer.dtp.uiplots = @trypasse dtviewer.data["uiplots"] dtviewer.dtp.uiplots
        "datapickers" in datakeys && (dtviewer.dtp.dtpks = @trypasse dtviewer.data["datapickers"] dtviewer.dtp.dtpks)
        "plotlayout" in datakeys && (dtviewer.dtp.layout = @trypasse dtviewer.data["plotlayout"] dtviewer.dtp.layout)
    else
        dtviewer.dtp = DataPlot()
    end
    return nothing
end

function compatload(path)
    data = load(path)
    if haskey(data, "uiplots")
        uiplots = data["uiplots"]
        dtpks = data["datapickers"]
        layout = data["plotlayout"]
        delete!(data, "uiplots")
        delete!(data, "datapickers")
        delete!(data, "plotlayout")
        push!(data, "dataplot" => DataPlot(plots=uiplots, dtpks=dtpks, layout=layout))
    end
    return data
end

Base.@kwdef mutable struct PlotState
    id::String = ""
    xhv::Bool = false
    yhv::Bool = false
    phv::Bool = false
    annhv::Bool = false
    annhv_i::Cint = 1
    showtooltip::Bool = true
    mspos::ImPlot.ImPlotPoint = ImPlot.ImPlotPoint(0, 0)
    plotpos::CImGui.ImVec2 = (0, 0)
    plotsize::CImGui.ImVec2 = (0, 0)
end

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

@kwdef mutable struct UIPlot
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

function Base.convert(::Type{PlotStates}, x::PlotState)
    ps = PlotStates()
    for fnm in fieldnames(PlotState)
        fnm in fieldnames(PlotStates) && setproperty!(ps, fnm, getproperty(x, fnm))
    end
    return ps
end

function Base.convert(::Type{Plot}, uip::UIPlot)
    plt = Plot()
    plt.id = uip.ps.id
    plt.title = uip.title
    plt.anns = uip.anns
    plt.linecuts = uip.linecuts
    if uip.ptype == "heatmap"
        pss = PlotSeries()
        pss.ptype = uip.ptype
        isempty(uip.legends) || (pss.legend = uip.legends[1])
        pss.x = eltype(uip.x) <: String ? Cdouble[] : uip.x
        pss.y = isempty(uip.y) ? [] : uip.y[1]
        pss.z = uip.z
        pss.axis.xaxis.label = uip.xlabel
        pss.axis.yaxis.label = uip.ylabel
        pss.axis.zaxis.label = uip.zlabel
        pss.axis.zaxis.colormap = uip.cmap
    else
        for i in eachindex(uip.y)
            pss = PlotSeries()
            pss.ptype = uip.ptype
            isempty(uip.legends) || (pss.legend = uip.legends[i])
            pss.x = eltype(uip.x) <: String ? Cdouble[] : copy(uip.x)
            pss.y = isempty(uip.y) ? [] : uip.y[i]
            pss.axis.xaxis.label = uip.xlabel
            pss.axis.yaxis.label = uip.ylabel
            push!(plt.series, pss)
        end
    end
    return plt
end

function Base.convert(::Type{OrderedDict{Int32,AbstractNode}}, nodes::Vector{Pair{Int32,AbstractNode}})
    dict = OrderedDict{Int32, AbstractNode}()
    for (id, node) in nodes
        push!(dict, id => node)
    end
    return dict
end

function Base.convert(::Type{OrderedDict{String,AbstractQuantity}}, qts::Vector{Pair{String,AbstractQuantity}})
    dict = OrderedDict{String, AbstractQuantity}()
    for (id, qt) in qts
        push!(dict, id => qt)
    end
    return dict
end

SampleBaseNode = SampleHolderNode

compattypes = [:InstrQuantity, :LogBlock, :SaveBlock, :SampleBaseNode, :PlotState, :PlotStates, :UIPlot]

for T in compattypes
    JLD2T = Symbol(:JLD2, T)
    eval(quote
        struct $JLD2T
            fieldnames_dict::Dict
        end
        # JLD2.writeas(::Type{$T}) = $JLD2T
        # JLD2.wconvert(::Type{$JLD2T}, obj::$T) = $JLD2T(Dict(fdnm => getproperty(obj, fdnm) for fdnm in fieldnames($T)))
        function JLD2.rconvert(::Type{$T}, jld2obj::$JLD2T)
            obj = $T()
            fdnms = fieldnames($T)
            for fdnm in keys(jld2obj.fieldnames_dict)
                fdnm in fdnms && setproperty!(obj, fdnm, convert(fieldtype($T, fdnm), jld2obj.fieldnames_dict[fdnm]))
            end
            obj
        end
    end)
end

function JLD2.rconvert(::Type{SampleHolderNode}, jld2obj::JLD2SampleBaseNode)
    obj = SampleHolderNode()
    fdnms = fieldnames(SampleHolderNode)
    for fdnm in keys(jld2obj.fieldnames_dict)
        fdnm in fdnms && setproperty!(obj, fdnm, convert(fieldtype(SampleHolderNode, fdnm), jld2obj.fieldnames_dict[fdnm]))
    end
    return obj
end

function JLD2.rconvert(::Type{DataPlot}, jld2obj::JLD2DataPlot)
    obj = DataPlot()
    fdnms = fieldnames(DataPlot)
    for fdnm in keys(jld2obj.fieldnames_dict)
        fdnm == :uiplots && append!(obj.plots, jld2obj.fieldnames_dict[fdnm])
        fdnm in fdnms && setproperty!(obj, fdnm, convert(fieldtype(DataPlot, fdnm), jld2obj.fieldnames_dict[fdnm]))
    end
    obj
end

function JLD2.rconvert(::Type{DataPicker}, jld2obj::JLD2DataPicker)
    dtpk = DataPicker()
    empty!(dtpk.series)
    if haskey(jld2obj.fieldnames_dict, :series)
        fdnms = fieldnames(DataPicker)
        for fdnm in keys(jld2obj.fieldnames_dict)
            fdnm in fdnms && setproperty!(dtpk, fdnm, convert(fieldtype(DataPicker, fdnm), jld2obj.fieldnames_dict[fdnm]))
        end
    else
        dtpk.datalist = jld2obj.fieldnames_dict[:datalist]
        for i in eachindex(jld2obj.fieldnames_dict[:y])
            jld2obj.fieldnames_dict[:y][i] || continue
            dtss = DataSeries()
            haskey(jld2obj.fieldnames_dict, :ptype) && (dtss.ptype = jld2obj.fieldnames_dict[:ptype])
            haskey(jld2obj.fieldnames_dict, :x) && (dtss.x = jld2obj.fieldnames_dict[:x])
            dtss.y = dtpk.datalist[i]
            haskey(jld2obj.fieldnames_dict, :z) && (dtss.z = jld2obj.fieldnames_dict[:z])
            true in jld2obj.fieldnames_dict[:w] && (dtss.w = dtpk.datalist[findfirst(jld2obj.fieldnames_dict[:w])])
            true in jld2obj.fieldnames_dict[:aux] && (dtss.aux = dtpk.datalist[findfirst(jld2obj.fieldnames_dict[:aux])])
            haskey(jld2obj.fieldnames_dict, :xtype) && (dtss.xtype = jld2obj.fieldnames_dict[:xtype])
            haskey(jld2obj.fieldnames_dict, :zsize) && (dtss.zsize = jld2obj.fieldnames_dict[:zsize])
            haskey(jld2obj.fieldnames_dict, :vflipz) && (dtss.vflipz = jld2obj.fieldnames_dict[:vflipz])
            haskey(jld2obj.fieldnames_dict, :hflipz) && (dtss.hflipz = jld2obj.fieldnames_dict[:hflipz])
            haskey(jld2obj.fieldnames_dict, :codes) && (dtss.codes = jld2obj.fieldnames_dict[:codes])
            push!(dtpk.series, dtss)
        end
    end
    return dtpk
end