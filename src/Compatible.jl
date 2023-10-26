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
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.LogBlock)
    CImGui.SameLine()
    CImGui.Button("LogBlock", (-1, 0))
    CImGui.EndChild()
end

function view(bk::SaveBlock)
    CImGui.BeginChild("##SaveBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.SaveBlock)
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

compattypes = [:InstrQuantity, :LogBlock, :SaveBlock]

for T in compattypes
    JLD2T = Symbol(:JLD2, T)
    eval(quote
        struct $JLD2T
            fieldnames_dict::Dict
        end
        JLD2.writeas(::Type{$T}) = $JLD2T
        JLD2.wconvert(::Type{$JLD2T}, obj::$T) = $JLD2T(Dict(fdnm => getproperty(obj, fdnm) for fdnm in fieldnames($T)))
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