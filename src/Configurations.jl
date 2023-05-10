@option mutable struct OptInit
    isremote::Bool
    windowsize::Vector{Cint}
    viewportenable::Bool
end

@option mutable struct OptDAQ
    savetime::Cint
    channel_size::Cint
    packsize::Cint
end

@option mutable struct OptInsBuf
    showcol::Cint
    showhelp::Bool
end

@option mutable struct OptFonts
    dir::String
    size::Cint
    first::String
    second::String
end

@option mutable struct OptIcons
    size::Cint
end

@option mutable struct OptLogs
    dir::String
    refreshrate::Cint
    showlogline::Cint
end

@option mutable struct OptBGImage
    path::String
end

@option mutable struct OptComAddr
    addrs::Vector{String}
end

@option mutable struct OptStyle
    dir::String
    default::String
end

@option mutable struct Conf
    U::OrderedDict{String,Vector}
    Init::OptInit
    DAQ::OptDAQ
    InsBuf::OptInsBuf
    Fonts::OptFonts
    Icons::OptIcons
    Logs::OptLogs
    BGImage::OptBGImage
    ComAddr::OptComAddr
    Style::OptStyle
end

global conf::Conf

abstract type InsConf end

mutable struct BasicConf <: InsConf
    icon::String
    idn::String
    cmdtype::String
    input_labels::Vector{String}
    output_labels::Vector{String}
end
BasicConf(conf::Dict) = BasicConf(conf["icon"], conf["idn"], conf["cmdtype"], conf["input_labels"], conf["output_labels"])

mutable struct QuantityConf <: InsConf
    enable::Bool
    alias::String
    U::String
    cmdheader::String
    optvalues::Vector{String}
    type::String
    help::String
end
QuantityConf(qt::Dict) = QuantityConf(qt["enable"], qt["alias"], qt["U"], qt["cmdheader"], qt["optvalues"], qt["type"], qt["help"])

mutable struct OneInsConf
    conf::BasicConf
    quantities::OrderedDict{String,QuantityConf}
end
OneInsConf() = OneInsConf(BasicConf("", "", "", [], []), OrderedDict())

todict(cf::BasicConf) = Dict("icon" => cf.icon, "idn" => cf.idn, "cmdtype" => cf.cmdtype, "input_labels" => cf.input_labels, "output_labels" => cf.output_labels)
todict(qtcf::QuantityConf) = Dict("enable" => qtcf.enable, "alias" => qtcf.alias, "U" => qtcf.U, "cmdheader" => qtcf.cmdheader, "optvalues" => qtcf.optvalues, "type" => qtcf.type, "help" => qtcf.help)
todict(oneinscf::OneInsConf) = (dict = Dict{String,Dict{String,Any}}("conf" => todict(oneinscf.conf)); for (qt, qtcf) in oneinscf.quantities
    push!(dict, qt => todict(qtcf))
end; dict)

const insconf = OrderedDict{String,OneInsConf}() #仪器注册表