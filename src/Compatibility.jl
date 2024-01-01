Base.convert(::Type{OrderedDict{String,T}}, vec::Vector{T}) where {T} = OrderedDict(string(i) => v for (i, v) in enumerate(vec))
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Vector{Node}) = OrderedDict(node.id => node for node in nodes)
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Type{OrderedDict{Cint,Node}}) = OrderedDict{Cint,AbstractNode}(node.id => node for node in nodes)

@kwdef mutable struct InstrQuantity <: AbstractQuantity
    # back end
    enable::Bool = true
    name::String = ""
    alias::String = ""
    step::String = ""
    stop::String = ""
    delay::Cfloat = 0.1
    set::String = ""
    optkeys::Vector{String} = []
    optvalues::Vector{String} = []
    optedidx::Cint = 1
    read::String = ""
    utype::String = ""
    uindex::Int = 1
    type::Symbol = :set
    help::String = ""
    isautorefresh::Bool = false
    issweeping::Bool = false
    # front end
    showval::String = ""
    showU::String = ""
    show_edit::String = ""
    show_view::String = ""
    passfilter::Bool = false
end

@kwdef mutable struct LogBlock <: AbstractBlock
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct SaveBlock <: AbstractBlock
    varname::String = ""
    mark::String = ""
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

# tocodes(::LogBlock) = :(remotecall_wait(eval, 1, :(log_instrbufferviewers())))

# function tocodes(bk::SaveBlock)
#     var = Symbol(bk.varname)
#     return if rstrip(bk.mark, ' ') == ""
#         :(put!(databuf_lc, ($(bk.varname), string($var))))
#     else
#         :(put!(databuf_lc, ($(bk.mark), string($var))))
#     end
# end

# function edit(bk::LogBlock)
#     CImGui.BeginChild("##LogBlock", (Float32(0), bkheight(bk)), true)
#     CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.LogBlock)
#     CImGui.SameLine()
#     CImGui.Button("LogBlock##", (-1, 0))
#     CImGui.EndChild()
# end

# function edit(bk::SaveBlock)
#     CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
#     CImGui.BeginChild("##SaveBlock", (Float32(0), bkheight(bk)), true)
#     CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.SaveBlock)
#     CImGui.SameLine()
#     CImGui.PushItemWidth(CImGui.GetContentRegionAvailWidth() / 2)
#     @c InputTextWithHintRSZ("##SaveBlock mark", mlstr("mark"), &bk.mark)
#     CImGui.PopItemWidth()
#     CImGui.SameLine()
#     CImGui.PushItemWidth(-1)
#     @c InputTextWithHintRSZ("##SaveBlock var", mlstr("variable"), &bk.varname)
#     CImGui.PopItemWidth()
#     CImGui.EndChild()
#     CImGui.PopStyleVar()
# end

# function view(logbk::LogBlock)
#     CImGui.BeginChild("##LogBlock", (Float32(0), bkheight(logbk)), true)
#     CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.Console)
#     CImGui.SameLine()
#     CImGui.Button("LogBlock", (-1, 0))
#     CImGui.EndChild()
# end

# function view(bk::SaveBlock)
#     CImGui.BeginChild("##SaveBlock", (Float32(0), bkheight(bk)), true)
#     CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.SaveButton)
#     CImGui.SameLine()
#     CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
#     CImGui.Button(stcstr(mlstr("mark"), ": ", bk.mark, "\t", mlstr("variable"), ": ", bk.varname), (-1, 0))
#     CImGui.PopStyleVar()
#     CImGui.EndChild()
# end

# function Base.show(io::IO, bk::LogBlock)
#     str = """
#     LogBlock :
#         region min : $(bk.regmin)
#         region max : $(bk.regmax)
#     """
#     print(io, str)
# end

# function Base.show(io::IO, bk::SaveBlock)
#     str = """
#     SaveBlock :
#         region min : $(bk.regmin)
#         region max : $(bk.regmax)
#               mark : $(bk.mark)
#                var : $(bk.varname)
#     """
#     print(io, str)
# end

function compatload(path)
    data = load(path)
    @info keys(data)
    if haskey(data, "uiplots")
        uiplots = data["uiplots"]
        dtpks = data["datapickers"]
        layout = data["plotlayout"]
        delete!(data, "uiplots")
        delete!(data, "datapickers")
        delete!(data, "plotlayout")
        push!(data, "dataplot" => DataPlot(plots=uiplots, dtpks=dtpks, layout=layout))
    end
    for key in keys(data)
        if occursin("instrbuffer", key)
            instrbuffer = pop!(data, key)
            instrbufferviewers = Dict{String,Dict{String,InstrBufferViewer}}()
            for (ins, inses) in instrbuffer
                push!(instrbufferviewers, ins => Dict{String,InstrBufferViewer}())
                for (addr, insbuf) in inses
                    # @info insbuf
                    if insbuf isa InstrBuffer
                        push!(instrbufferviewers[ins], addr => InstrBufferViewer(instrnm=ins, addr=addr, insbuf=insbuf))
                    elseif insbuf isa InstrBufferViewer
                        push!(instrbufferviewers[ins], addr => insbuf)
                    end
                end
            end
            if occursin("instrbufferviewers", key)
                push!(data, key => instrbufferviewers)
            elseif occursin("instrbufferviewer", key)
                push!(data, replace(key, "instrbufferviewer" => "instrbufferviewers") => instrbufferviewers)
            else
                push!(data, replace(key, "instrbuffer" => "instrbufferviewers") => instrbufferviewers)
            end
        end
    end
    for key in keys(data)
        if occursin("instrbufferviewers", key)
            for (_, inses) in data[key]
                for (_, ibv) in inses
                    for (qtnm, qt) in ibv.insbuf.quantities
                        if qt isa InstrQuantity
                            fdnms = fieldnames(InstrQuantity)
                            if qt.set != ""
                                fdnmsset = fieldnames(SetQuantity)
                                newqt = SetQuantity()
                                for fdnm in fdnms
                                    fdnm in fdnmsset && setproperty!(newqt, fdnm, getproperty(qt, fdnm))
                                end
                            elseif qt.step != "" || qt.stop != ""
                                fdnmssweep = fieldnames(SweepQuantity)
                                newqt = SweepQuantity()
                                for fdnm in fdnms
                                    fdnm in fdnmssweep && setproperty!(newqt, fdnm, getproperty(qt, fdnm))
                                end
                            else
                                fdnmsread = fieldnames(ReadQuantity)
                                newqt = ReadQuantity()
                                for fdnm in fdnms
                                    fdnm in fdnmsread && setproperty!(newqt, fdnm, getproperty(qt, fdnm))
                                end
                            end
                            push!(ibv.insbuf.quantities, qtnm => newqt)
                        end
                    end
                end
            end
        end
    end
    if haskey(data, "daqtask")
        task = pop!(data, "daqtask")
        convertbk!(task.blocks)
        push!(data, "daqtask" => convert(DAQTask, task))
    end
    if !haskey(data, "circuit")
        push!(data, "circuit" => NodeEditor())
    end
    if !haskey(data, "dataplot")
        push!(data, "dataplot" => DataPlot())
    end
    return data
end

function convertbk!(bks::Vector{AbstractBlock})
    for (i, bk) in enumerate(bks)
        if bk isa LogBlock
            bks[i] = CodeBlock(codes="@logblock")
        elseif bk isa SaveBlock
            codes = if bk.mark == ""
                "@saveblock $(bk.varname)"
            else
                "@saveblock $(bk.mark) $(bk.varname)"
            end
            bks[i] = CodeBlock(codes=codes)
        elseif bk isa StrideCodeBlock || bk isa SweepBlock
            convertbk!(bk.blocks)
        end
    end
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
    dict = OrderedDict{Int32,AbstractNode}()
    for (id, node) in nodes
        push!(dict, id => node)
    end
    return dict
end

function Base.convert(::Type{OrderedDict{String,AbstractQuantity}}, qts::Vector{Pair{String,AbstractQuantity}})
    dict = OrderedDict{String,AbstractQuantity}()
    for (id, qt) in qts
        push!(dict, id => qt)
    end
    return dict
end

function Base.convert(::Type{OrderedDict{String,AbstractQuantity}}, qts::Vector{InstrQuantity})
    dict = OrderedDict{String,AbstractQuantity}()
    for qt in qts
        push!(dict, qt.name => qt)
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
            haskey(jld2obj.fieldnames_dict, :w) && true in jld2obj.fieldnames_dict[:w] && (dtss.w = dtpk.datalist[findfirst(jld2obj.fieldnames_dict[:w])])
            haskey(jld2obj.fieldnames_dict, :aux) && true in jld2obj.fieldnames_dict[:aux] && (dtss.aux = dtpk.datalist[findfirst(jld2obj.fieldnames_dict[:aux])])
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


function JLD2.rconvert(::Type{Layout}, jld2obj::JLD2Layout)
    obj = Layout()
    fdnms = fieldnames(Layout)
    for fdnm in keys(jld2obj.fieldnames_dict)
        fdnm in fdnms && setproperty!(obj, fdnm, convert(fieldtype(Layout, fdnm), jld2obj.fieldnames_dict[fdnm]))
    end
    length(obj.marks) == length(obj.labels) || append!(obj.marks, fill("", length(obj.labels) - length(obj.marks)))
    return obj
end

function JLD2.rconvert(::Type{StrideCodeBlock}, jld2obj::JLD2StrideCodeBlock)
    obj = StrideCodeBlock()
    fdnms = fieldnames(StrideCodeBlock)
    for fdnm in keys(jld2obj.fieldnames_dict)
        fdnm in fdnms && setproperty!(obj, fdnm, convert(fieldtype(StrideCodeBlock, fdnm), jld2obj.fieldnames_dict[fdnm]))
    end
    haskey(jld2obj.fieldnames_dict, :head) && (obj.codes = jld2obj.fieldnames_dict[:head])
    return obj
end

function JLD2.rconvert(::Type{DAQTask}, jld2obj::JLD2StrideCodeBlock)
    obj = StrideCodeBlock()
    fdnms = fieldnames(StrideCodeBlock)
    for fdnm in keys(jld2obj.fieldnames_dict)
        fdnm in fdnms && setproperty!(obj, fdnm, convert(fieldtype(StrideCodeBlock, fdnm), jld2obj.fieldnames_dict[fdnm]))
    end
    haskey(jld2obj.fieldnames_dict, :head) && (obj.codes = jld2obj.fieldnames_dict[:head])
    return obj
end

# function view(instrbufferviewers_local::Dict{String,Dict{String,InstrBuffer}})
#     for (ins, inses) in filter(x -> !isempty(x.second), instrbufferviewers_local)
#         ins == "Others" && continue
#         for (addr, ib) in inses
#             CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(ins, "：", addr))
#             CImGui.PushID(addr)
#             view(ib)
#             CImGui.PopID()
#         end
#     end
# end

function Base.convert(::Type{AbstractBlock}, bk::JLD2.ReconstructedMutable{Symbol("QInsControl.CodeBlock"),(:codes, :region),Tuple{String,Any}})
    newbk = CodeBlock()
    loadfields = JLD2.ReconstructedMutable{Symbol("QInsControl.CodeBlock"),(:codes, :region),Tuple{String,Any}}.parameters[2]
    newfields = fieldnames(CodeBlock)
    for fdnm in loadfields
        fdnm in newfields && setproperty!(newbk, fdnm, convert(fieldtype(CodeBlock, fdnm), getproperty(bk, fdnm)))
    end
    return newbk
end

function Base.convert(::Type{AbstractBlock}, bk::JLD2.ReconstructedMutable{Symbol("QInsControl.SweepBlock"),(:instrnm, :addr, :quantity, :step, :stop, :level, :blocks, :ui, :region),Tuple{String,String,String,String,String,Int64,Any,Int64,Any}})
    newbk = SweepBlock()
    loadfields = JLD2.ReconstructedMutable{Symbol("QInsControl.SweepBlock"),(:instrnm, :addr, :quantity, :step, :stop, :level, :blocks, :ui, :region),Tuple{String,String,String,String,String,Int64,Any,Int64,Any}}.parameters[2]
    newfields = fieldnames(SweepBlock)
    for fdnm in loadfields
        fdnm in newfields && setproperty!(newbk, fdnm, convert(fieldtype(SweepBlock, fdnm), getproperty(bk, fdnm)))
    end
    return newbk
end

function Base.convert(::Type{AbstractBlock}, bk::JLD2.ReconstructedMutable{Symbol("QInsControl.SettingBlock"),(:instrnm, :addr, :quantity, :setvalue, :ui, :region),Tuple{String,String,String,String,Int64,Any}})
    newbk = SettingBlock()
    loadfields = JLD2.ReconstructedMutable{Symbol("QInsControl.SettingBlock"),(:instrnm, :addr, :quantity, :setvalue, :ui, :region),Tuple{String,String,String,String,Int64,Any}}.parameters[2]
    newfields = fieldnames(SettingBlock)
    for fdnm in loadfields
        fdnm in newfields && setproperty!(newbk, fdnm, convert(fieldtype(SettingBlock, fdnm), getproperty(bk, fdnm)))
    end
    return newbk
end

function Base.convert(::Type{AbstractBlock}, bk::JLD2.ReconstructedMutable{Symbol("QInsControl.ReadingBlock"),(:instrnm, :mark, :addr, :quantity, :index, :isasync, :region),Tuple{String,String,String,String,String,Bool,Any}})
    newbk = ReadingBlock()
    loadfields = JLD2.ReconstructedMutable{Symbol("QInsControl.ReadingBlock"),(:instrnm, :mark, :addr, :quantity, :index, :isasync, :region),Tuple{String,String,String,String,String,Bool,Any}}.parameters[2]
    newfields = fieldnames(ReadingBlock)
    for fdnm in loadfields
        fdnm in newfields && setproperty!(newbk, fdnm, convert(fieldtype(ReadingBlock, fdnm), getproperty(bk, fdnm)))
    end
    return newbk
end

function Base.convert(::Type{InstrQuantity}, qt::JLD2.ReconstructedMutable{Symbol("QInsControl.InstrQuantity"),(:name, :alias, :step, :stop, :delay, :set, :read, :utype, :uindex, :type, :help),Tuple{String,String,String,String,Float32,String,String,String,Int64,Symbol,String}})
    newqt = InstrQuantity()
    loadfields = JLD2.ReconstructedMutable{Symbol("QInsControl.InstrQuantity"),(:name, :alias, :step, :stop, :delay, :set, :read, :utype, :uindex, :type, :help),Tuple{String,String,String,String,Float32,String,String,String,Int64,Symbol,String}}.parameters[2]
    newfields = fieldnames(InstrQuantity)
    for fdnm in loadfields
        fdnm in newfields && setproperty!(newqt, fdnm, convert(fieldtype(InstrQuantity, fdnm), getproperty(qt, fdnm)))
    end
    return newqt
end

function Base.convert(::Type{InstrBuffer}, ib::JLD2.ReconstructedMutable{Symbol("QInsControl.InstrBuffer"), (:instrnm, :qtindex, :quantities), Tuple{String, Dict{String, Int64}, Any}})
    newib = InstrBuffer()
    loadfields = JLD2.ReconstructedMutable{Symbol("QInsControl.InstrBuffer"), (:instrnm, :qtindex, :quantities), Tuple{String, Dict{String, Int64}, Any}}.parameters[2]
    newfields = fieldnames(InstrBuffer)
    for fdnm in loadfields
        fdnm in newfields && setproperty!(newib, fdnm, convert(fieldtype(InstrBuffer, fdnm), getproperty(ib, fdnm)))
    end
    return newib
end

function Base.convert(::Type{DAQTask}, task::JLD2.ReconstructedMutable{Symbol("QInsControl.DAQTask"), (:name, :explog, :blocks, :enable), Tuple{String, String, Any, Bool}})
    newtask = DAQTask()
    loadfields = JLD2.ReconstructedMutable{Symbol("QInsControl.DAQTask"), (:name, :explog, :blocks, :enable), Tuple{String, String, Any, Bool}}.parameters[2]
    newfields = fieldnames(DAQTask)
    for fdnm in loadfields
        fdnm in newfields && setproperty!(newtask, fdnm, convert(fieldtype(DAQTask, fdnm), getproperty(task, fdnm)))
    end
    return newtask
end