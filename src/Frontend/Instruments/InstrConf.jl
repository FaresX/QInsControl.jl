abstract type InstrConf end

@kwdef mutable struct BasicConf <: InstrConf
    icon::String = ICONS.ICON_MICROCHIP
    idn::String = "New Ins"
    cmdtype::String = "scpi"
    input_labels::Vector{String} = []
    output_labels::Vector{String} = []
end

@kwdef mutable struct QuantityConf <: InstrConf
    alias::String = "quantity"
    timeoutw::Cfloat = 3
    timeoutr::Cfloat = 3
    U::String = ""
    cmdheader::String = ""
    optkeys::Vector{String} = []
    optvalues::Vector{String} = []
    type::String = "set"
    separator::String = ""
    numread::Cint = 1
    help::String = ""
end

@kwdef mutable struct OneInstrConf
    conf::BasicConf = BasicConf()
    quantities::OrderedDict{String,QuantityConf} = Dict()
end

todict(cf::BasicConf) = Dict(string(fdnm) => getproperty(cf, fdnm) for fdnm in fieldnames(BasicConf))
todict(qtcf::QuantityConf) = Dict(string(fdnm) => getproperty(qtcf, fdnm) for fdnm in fieldnames(QuantityConf))
function todict(oneinscf::OneInstrConf)
    dict = Dict{String,Dict{String,Any}}("conf" => todict(oneinscf.conf))
    for (qt, qtcf) in oneinscf.quantities
        dict[qt] = todict(qtcf)
    end
    dict
end