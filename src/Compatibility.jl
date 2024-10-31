Base.convert(::Type{OrderedDict{String,T}}, vec::Vector{T}) where {T} = OrderedDict(string(i) => v for (i, v) in enumerate(vec))
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Vector{Node}) = OrderedDict(node.id => node for node in nodes)
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Type{OrderedDict{Cint,Node}}) = OrderedDict{Cint,AbstractNode}(node.id => node for node in nodes)

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
            for (ins, inses) in data[key]
                for (_, ibv) in inses
                    for (qtnm, qt) in ibv.insbuf.quantities
                        if qt isa InstrQuantity
                            fdnms = fieldnames(InstrQuantity)
                            if (haskey(INSCONF, ins) && haskey(INSCONF[ins].quantities, qtnm) && INSCONF[ins].quantities[qtnm].type == "set") || qt.set != "" || !isempty(qt.optkeys) || !isempty(qt.optvalues)
                                fdnmsset = fieldnames(SetQuantity)
                                newqt = SetQuantity()
                                for fdnm in fdnms
                                    fdnm in fdnmsset && setproperty!(newqt, fdnm, getproperty(qt, fdnm))
                                end
                                if isempty(newqt.optkeys) && !isempty(newqt.optvalues)
                                    if haskey(INSCONF, ins) && haskey(INSCONF[ins].quantities, qtnm) && INSCONF[ins].quantities[qtnm].type == "set"
                                        qtcf = INSCONF[ins].quantities[qtnm]
                                        lcf = length(qtcf.optkeys)
                                        lqt = length(newqt.optvalues)
                                        newqt.optkeys = if lcf == lqt
                                            qtcf.optkeys
                                        elseif lcf < lqt
                                            vcat(qtcf.optkeys, "key " .* string.(lcf+1:lqt))
                                        else
                                            qtcf.optkeys[1:lqt]
                                        end
                                    else
                                        append!(newqt.optkeys, "key " .* string.(1:length(newqt.optvalues)))
                                    end
                                    # @info newqt.optkeys
                                end
                            elseif (haskey(INSCONF, ins) && haskey(INSCONF[ins].quantities, qtnm) && INSCONF[ins].quantities[qtnm].type == "sweep") || qt.step != "" || qt.stop != ""
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

compattypes = [:InstrQuantity, :LogBlock, :SaveBlock, :SampleBaseNode]

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

function JLD2.rconvert(::Type{ImageRegion}, jld2obj::JLD2ImageRegion)
    obj = ImageRegion()
    fdnms = fieldnames(ImageRegion)
    for fdnm in keys(jld2obj.fieldnames_dict)
        fdnm == :image && jld2obj.fieldnames_dict[:image] isa Matrix && (obj.image = jpeg_encode(jld2obj.fieldnames_dict[:image]); continue)
        fdnm in fdnms && setproperty!(obj, fdnm, convert(fieldtype(ImageRegion, fdnm), jld2obj.fieldnames_dict[fdnm]))
    end
    return obj
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