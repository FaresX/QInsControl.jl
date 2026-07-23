abstract type AbstractQuantity end
@kwdef mutable struct SweepQuantity <: AbstractQuantity
    # back end
    enable::Bool = true
    name::String = ""
    alias::String = ""
    timeoutw::Cfloat = 3
    timeoutr::Cfloat = 3
    step::String = ""
    stop::String = ""
    delay::Cfloat = 0.1
    read::String = ""
    utype::String = ""
    uindex::Int = 1
    separator::String = ""
    numread::Cint = 1
    help::String = ""
    refreshrate::Cfloat = 1
    isautorefresh::Bool = false
    issweeping::Bool = false
    # front end
    showval::Vector{String} = []
    showU::String = ""
    show_edit::String = ""
    show_view::String = ""
    passfilter::Bool = true
    lastrefresh::Float64 = 0
    refreshed::Bool = false
    nstep::Int = 0
    presenti::Int = 0
    elapsedtime::Float64 = 0
end

@kwdef mutable struct SetQuantity <: AbstractQuantity
    # back end
    enable::Bool = true
    name::String = ""
    alias::String = ""
    timeoutw::Cfloat = 3
    timeoutr::Cfloat = 3
    set::String = ""
    optkeys::Vector{String} = []
    optvalues::Vector{String} = []
    optedidx::Cint = 1
    read::String = ""
    utype::String = ""
    uindex::Int = 1
    separator::String = ""
    numread::Cint = 1
    help::String = ""
    refreshrate::Cfloat = 1
    isautorefresh::Bool = false
    # front end
    showval::Vector{String} = []
    showU::String = ""
    show_edit::String = ""
    show_view::String = ""
    passfilter::Bool = true
    lastrefresh::Float64 = 0
    refreshed::Bool = false
end

@kwdef mutable struct ReadQuantity <: AbstractQuantity
    # back end
    enable::Bool = true
    name::String = ""
    alias::String = ""
    timeoutr::Cfloat = 3
    read::String = ""
    utype::String = ""
    uindex::Int = 1
    separator::String = ""
    numread::Cint = 1
    help::String = ""
    refreshrate::Cfloat = 1
    isautorefresh::Bool = false
    # front end
    showval::Vector{String} = []
    showU::String = ""
    show_edit::String = ""
    show_view::String = ""
    passfilter::Bool = true
    lastrefresh::Float64 = 0
    refreshed::Bool = false
end

function Base.show(io::IO, qt::SweepQuantity)
    updatefront!(qt)
    str = """
    SweepQuantity :
                name : $(qt.name)
               alias : $(qt.alias)
            timeoutw : $(qt.timeoutw)
            timeoutr : $(qt.timeoutr)
                step : $(qt.step)
                stop : $(qt.stop)
               delay : $(qt.delay)
                read : $(join(qt.showval, qt.separator)) $(qt.showU)
        auto-refresh : $(qt.refreshrate) $(qt.isautorefresh)
            sweeping : $(qt.issweeping)
    """
    print(io, str)
end

function Base.show(io::IO, qt::SetQuantity)
    updatefront!(qt)
    str = """
    SetQuantity :
                name : $(qt.name)
               alias : $(qt.alias)
            timeoutw : $(qt.timeoutw)
            timeoutr : $(qt.timeoutr)
                 set : $(qt.set)
                read : $(join(qt.showval, qt.separator)) $(qt.showU)
        auto-refresh : $(qt.refreshrate) $(qt.isautorefresh)
    """
    print(io, str)
end

function Base.show(io::IO, qt::ReadQuantity)
    updatefront!(qt)
    str = """
    ReadQuantity :
                name : $(qt.name)
               alias : $(qt.alias)
            timeoutr : $(qt.timeoutr)
                read : $(join(qt.showval, qt.separator)) $(qt.showU)
        auto-refresh : $(qt.refreshrate) $(qt.isautorefresh)
    """
    print(io, str)
end

function quantity(name, qtcf::QuantityConf)
    return if qtcf.type == "sweep"
        SweepQuantity(
            name=name, alias=qtcf.alias, timeoutw=qtcf.timeoutw, timeoutr=qtcf.timeoutr, utype=qtcf.U,
            separator=qtcf.separator, numread=qtcf.numread, help=qtcf.help, showval=fill("", qtcf.numread)
        )
    elseif qtcf.type == "set"
        SetQuantity(
            name=name, alias=qtcf.alias, timeoutw=qtcf.timeoutw, timeoutr=qtcf.timeoutr,
            optkeys=qtcf.optkeys, optvalues=qtcf.optvalues, utype=qtcf.U,
            separator=qtcf.separator, numread=qtcf.numread, help=qtcf.help, showval=fill("", qtcf.numread)
        )
    elseif qtcf.type == "read"
        ReadQuantity(
            name=name, alias=qtcf.alias, timeoutr=qtcf.timeoutr, utype=qtcf.U,
            separator=qtcf.separator, numread=qtcf.numread, help=qtcf.help, showval=fill("", qtcf.numread)
        )
    end
end

@kwdef mutable struct InstrBuffer
    instrnm::String = ""
    quantities::OrderedDict{String,AbstractQuantity} = OrderedDict()
    isautorefresh::Bool = true
    filter::String = ""
    filtervarname::Bool = false
    showdisable::Bool = false
end

function InstrBuffer(instrnm)
    haskey(INSTRCONF, instrnm) || @error "[$(now())]\n$(mlstr("unsupported instrument!!!"))" instrument = instrnm
    sweepqts = [qt for qt in keys(INSTRCONF[instrnm].quantities) if INSTRCONF[instrnm].quantities[qt].type == "sweep"]
    setqts = [qt for qt in keys(INSTRCONF[instrnm].quantities) if INSTRCONF[instrnm].quantities[qt].type == "set"]
    readqts = [qt for qt in keys(INSTRCONF[instrnm].quantities) if INSTRCONF[instrnm].quantities[qt].type == "read"]
    quantities = [readqts; sweepqts; setqts]
    instrqts = OrderedDict()
    for qt in quantities
        alias = INSTRCONF[instrnm].quantities[qt].alias
        timeoutw = qt isa ReadQuantity ? 3 : INSTRCONF[instrnm].quantities[qt].timeoutw
        timeoutr = INSTRCONF[instrnm].quantities[qt].timeoutr
        optkeys = INSTRCONF[instrnm].quantities[qt].optkeys
        optvalues = INSTRCONF[instrnm].quantities[qt].optvalues
        utype = INSTRCONF[instrnm].quantities[qt].U
        type = INSTRCONF[instrnm].quantities[qt].type
        separator = INSTRCONF[instrnm].quantities[qt].separator
        numread = INSTRCONF[instrnm].quantities[qt].numread
        help = replace(INSTRCONF[instrnm].quantities[qt].help, "\\\n" => "")
        newqt = quantity(qt, QuantityConf(alias, timeoutw, timeoutr, utype, "", optkeys, optvalues, type, separator, numread, help))
        instrqts[qt] = newqt
    end
    InstrBuffer(instrnm=instrnm, quantities=instrqts)
end

@kwdef mutable struct InstrBufferViewer
    instrnm::String = ""
    addr::String = ""
    inputcmd::String = "*IDN?"
    reading::String = ""
    p_open::Bool = false
    insbuf::InstrBuffer = InstrBuffer()
end
function InstrBufferViewer(instrnm, addr)
    insbuf = InstrBuffer(instrnm)
    for (qtnm, qt) in insbuf.quantities
        if haskey(CONF.InsBuf.disablelist, instrnm) && haskey(CONF.InsBuf.disablelist[instrnm], addr)
            qt.enable = qtnm ∉ CONF.InsBuf.disablelist[instrnm][addr]
        end
        if haskey(CONF.InsBuf.unitlist, instrnm) && haskey(CONF.InsBuf.unitlist[instrnm], addr) &&
           haskey(CONF.InsBuf.unitlist[instrnm][addr], qtnm)
            qt.uindex = CONF.InsBuf.unitlist[instrnm][addr][qtnm]
        end
    end
    InstrBufferViewer(instrnm, addr, "*IDN?", "", false, insbuf)
end

const INSTRCONF = OrderedDict{String,OneInstrConf}()
const INSTRBUFFERVIEWERS::Dict{String,Dict{String,InstrBufferViewer}} = Dict()