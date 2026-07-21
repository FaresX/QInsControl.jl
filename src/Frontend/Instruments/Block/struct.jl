abstract type AbstractBlock end

struct NullBlock <: AbstractBlock end
skipnull(bkch::Vector{AbstractBlock}) = findall(bk -> !isa(bk, NullBlock), bkch)

@kwdef mutable struct CodeBlock <: AbstractBlock
    codes::String = ""
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct StrideCodeBlock <: AbstractBlock
    codes::String = ""
    level::Int = 1
    blocks::Vector{AbstractBlock} = AbstractBlock[]
    nohandler::Bool = false
    hideblocks::Bool = false
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct BranchBlock <: AbstractBlock
    codes::String = ""
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct SweepBlock <: AbstractBlock
    alias::String = mlstr("alias")
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("sweep")
    step::String = ""
    stop::String = ""
    delay::Cfloat = 0.1
    startdelay::Cfloat = 4
    ui::Int = 1
    rangemark::String = ""
    level::Int = 1
    blocks::Vector{AbstractBlock} = AbstractBlock[]
    istrycatch::Bool = true
    hideblocks::Bool = false
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct FreeSweepBlock <: AbstractBlock
    alias::String = mlstr("alias")
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("read")
    mode::String = "="
    stop::String = ""
    delay::Cfloat = 0.1
    delta::Cfloat = 0.001
    duration::Cfloat = 6
    ui::Int = 1
    level::Int = 1
    blocks::Vector{AbstractBlock} = AbstractBlock[]
    istrycatch::Bool = true
    hideblocks::Bool = false
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct SettingBlock <: AbstractBlock
    alias::String = mlstr("alias")
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("set")
    setvalue::String = ""
    delay::Cfloat = 0.1
    ui::Int = 1
    ischeck::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct ReadingBlock <: AbstractBlock
    alias::String = mlstr("alias")
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("read")
    index::String = ""
    mark::String = ""
    isasync::Bool = true
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct WriteBlock <: AbstractBlock
    alias::String = mlstr("alias")
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    cmd::String = ""
    isasync::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct QueryBlock <: AbstractBlock
    alias::String = mlstr("alias")
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    cmd::String = ""
    index::String = ""
    mark::String = ""
    isasync::Bool = true
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct ReadBlock <: AbstractBlock
    alias::String = mlstr("alias")
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    index::String = ""
    mark::String = ""
    isasync::Bool = false
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct FeedbackBlock <: AbstractBlock
    alias::String = mlstr("alias")
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    action::String = mlstr("Pause")
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

iscontainer(_) = false
iscontainer(bk::Union{StrideCodeBlock, SweepBlock, FreeSweepBlock}) = true
isinstr(_) = false
isinstr(bk::Union{SweepBlock, FreeSweepBlock, SettingBlock, ReadingBlock, WriteBlock, QueryBlock, ReadBlock, FeedbackBlock}) = true

function Base.isapprox(bk1::T1, bk2::T2) where {T1<:AbstractBlock} where {T2<:AbstractBlock}
    if T1 == T2
        return all(
            fnm == :blocks ? bk1.blocks ≈ bk2.blocks : getproperty(bk1, fnm) == getproperty(bk2, fnm)
            for fnm in fieldnames(T1)[1:end-2]
        )
    end
    return false
end
Base.isapprox(x::Vector{AbstractBlock}, y::Vector{AbstractBlock}) = length(x) == length(y) ? all(x .≈ y) : false

bkheight(::NullBlock) = zero(Float32)
function bkheight(bk::CodeBlock)
    (1 + length(findall("\n", bk.codes))) * CImGui.GetTextLineHeight() +
    2unsafe_load(IMGUISTYLE.FramePadding.y) +
    2unsafe_load(IMGUISTYLE.WindowPadding.y) + 1
end
function bkheight(bk::Union{StrideCodeBlock,SweepBlock,FreeSweepBlock})
    return isempty(skipnull(bk.blocks)) ? 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight() :
           bk.hideblocks ? 2MORESTYLE.Variables.ContainerBlockWindowPadding[2] + CImGui.GetFrameHeight() :
           2MORESTYLE.Variables.ContainerBlockWindowPadding[2] +
           CImGui.GetFrameHeight() +
           length(skipnull(bk.blocks)) * unsafe_load(IMGUISTYLE.ItemSpacing.y) +
           sum(bkheight.(bk.blocks))
end
bkheight(_) = 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight()

Base.show(io::IO, ::NullBlock) = print(io, "NullBlock")
function Base.show(io::IO, bk::CodeBlock)
    str = """
    CodeBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             codes : 
    """
    print(io, str)
    bk.codes == "" || print(io, string(bk.codes, "\n"))
end
function Base.show(io::IO, bk::StrideCodeBlock)
    str = """
    StrideCodeBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             level : $(bk.level)
        hideblocks : $(bk.hideblocks)
              head : $(bk.codes)
              body : 
    """
    print(io, str)
    for b in bk.blocks
        print(io, string("+"^64, "\n", "\t"^4))
        show(io, b)
    end
end
function Base.show(io::IO, bk::BranchBlock)
    str = """
    BranchBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             codes : 
    """
    print(io, str)
    bk.codes == "" || print(io, string(bk.codes, "\n"))
end
function Base.show(io::IO, bk::SweepBlock)
    Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
        INSTRCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
    str = """
    SweepBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             level : $(bk.level)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
              step : $(bk.step)
              stop : $(bk.stop)
              unit : $U
             delay : $(bk.delay)
        startdelay : $(bk.startdelay)
          trycatch : $(bk.istrycatch)
        hideblocks : $(bk.hideblocks)
              body :
    """
    print(io, str)
    for b in bk.blocks
        print(io, string("-"^64, "\n", "\t"^4))
        show(io, b)
    end
end
function Base.show(io::IO, bk::FreeSweepBlock)
    Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
        INSTRCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
    str = """
    FreeSweepBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             level : $(bk.level)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
              stop : $(bk.mode) $(bk.stop)
             delta : $(bk.delta)
          duration : $(bk.duration)
              unit : $U
             delay : $(bk.delay)
          trycatch : $(bk.istrycatch)
        hideblocks : $(bk.hideblocks)
              body :
    """
    print(io, str)
    for b in bk.blocks
        print(io, string("-"^64, "\n", "\t"^4))
        show(io, b)
    end
end
function Base.show(io::IO, bk::SettingBlock)
    Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
        INSTRCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
    str = """
    SettingBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
           ischeck : $(bk.ischeck)
         set value : $(bk.setvalue)
             delay : $(bk.delay)
              unit : $U
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::ReadingBlock)
    str = """
    ReadingBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::WriteBlock)
    str = """
    WriteBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
           command : $(bk.cmd)
             async : $(bk.isasync)
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::QueryBlock)
    str = """
    QueryBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
           command : $(bk.cmd)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::ReadBlock)
    str = """
    ReadBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::FeedbackBlock)
    str = """
     FeedbackBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
            action : $(bk.action)
    """
    print(io, str)
end