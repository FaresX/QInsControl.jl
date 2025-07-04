@option mutable struct OptBasic
    isremote::Bool = true
    viewportenable::Bool = true
    holdmainwindow::Bool = true
    # scale::Bool = false
    hidewindow::Bool = false
    nthreads::Cint = 2
    nthreads_2::Cint = 1
    # noactionswapinterval::Cint = 6
    # samplingthreshold::Cint = 200000
    windowsize::Vector{Cint} = [960, 540]
    openglversion::String = "4.6"
    encoding::String = "GBK"
    editor::String = "notepad"
    language::String = "English"
    languages::Dict{String,String} = Dict()
end

@option mutable struct OptCommunication
    visapath::String = ""
    attrlist::Dict{String,Dict} = Dict()
end

@option mutable struct OptDtViewer
    showdatarow::Cint = 10000
end

@option mutable struct OptDAQ
    savetype::String = "String"
    logall::Bool = false
    equalstep::Bool = true
    externaleval::Bool = false
    savetime::Cint = 1
    cuttingfile::Cint = 2000000
    channelsize::Cint = 512
    packsize::Cint = 6
    ctbuflen::Cint = 4
    cttimeout::Cfloat = 4
    historylen::Cint = 120
    retrysendtimes::Cint = 3
    retryconnecttimes::Cint = 3
end

@option mutable struct OptInsBuf
    retreading::Bool = false
    showhelp::Bool = false
    showcol::Cint = 3
    disablelist::Dict{String,Dict{String,Vector{String}}} = Dict()
    unitlist::Dict{String,Dict{String,Dict{String,Int}}} = Dict()
end

@option mutable struct OptServer
    port::Cint = 6060
    buflen::Cint = 1024
end

@option mutable struct OptRegister
    historylen::Cint = 120
end

@option mutable struct OptFonts
    dir::String = ""
    size::Cint = 18
    plotfontsize::Cint = 30
    first::String = "HarmonyOS_Sans_SC_Regular.subset.ttf"
    second::String = "arial.ttf"
    bigfont::String = "arial.ttf"
end

# @option mutable struct OptIcons
#     size::Cint = 18
# end

@option mutable struct OptConsole
    dir::String = ""
    refreshrate::Cfloat = 60
    showioline::Cint = 100
    showiolength::Cint = 1000
    historylen::Cint = 120
end

@option mutable struct OptLogs
    dir::String = ""
    refreshrate::Cfloat = 60
    showlogline::Cint = 600
    showloglength::Cint = 1000
end

@option mutable struct OptOneBGImage
    path::String = ""
    rate::Cint = 1
    use::Bool = false
end
@option mutable struct OptBGImage
    main::OptOneBGImage = OptOneBGImage(path=joinpath(ENV["QInsControlAssets"], "Necessity/defaultwallpaper.png"), use=true)
    circuit::OptOneBGImage = OptOneBGImage()
    instrbufferviewer::OptOneBGImage = OptOneBGImage()
    registration::OptOneBGImage = OptOneBGImage()
    filetree::OptOneBGImage = OptOneBGImage()
    fileviewer::OptOneBGImage = OptOneBGImage()
    formatter::OptOneBGImage = OptOneBGImage()
    console::OptOneBGImage = OptOneBGImage()
    logger::OptOneBGImage = OptOneBGImage()
    preferences::OptOneBGImage = OptOneBGImage()
end

@option mutable struct OptComAddr
    addrs::Vector{String} = []
end

@option mutable struct OptStyle
    dir::String = ""
    default::String = "Dark"
end

@option mutable struct Conf
    Basic::OptBasic = OptBasic()
    Communication::OptCommunication = OptCommunication()
    DtViewer::OptDtViewer = OptDtViewer()
    DAQ::OptDAQ = OptDAQ()
    InsBuf::OptInsBuf = OptInsBuf()
    Server::OptServer = OptServer()
    Register::OptRegister = OptRegister()
    Fonts::OptFonts = OptFonts()
    # Icons::OptIcons = OptIcons()
    Console::OptConsole = OptConsole()
    Logs::OptLogs = OptLogs()
    BGImage::OptBGImage = OptBGImage()
    ComAddr::OptComAddr = OptComAddr()
    Style::OptStyle = OptStyle()
    U::OrderedDict{String,Vector} = OrderedDict(
        "T/min" => [u"T/minute"],
        "A" => [u"A", u"mA", u"μA", u"nA"],
        "T" => [u"T", u"mT", u"Gauss"],
        "dBm" => [u"dBm"],
        "°" => [u"°", u"rad"],
        "V" => [u"V", u"mV", u"μV", u"nV"],
        "" => [""],
        "K" => [u"K", u"mK"],
        "s" => [u"s", u"minute", u"hr", u"d", u"ms", u"μs"],
        "Hz" => [u"Hz", u"kHz", u"MHz", u"GHz"],
        "Ω" => [u"Ω", u"kΩ", u"MΩ"]
    )
end

global CONF::Conf

abstract type InsConf end

@kwdef mutable struct BasicConf <: InsConf
    icon::String = ICONS.ICON_MICROCHIP
    idn::String = "New Ins"
    cmdtype::String = "scpi"
    input_labels::Vector{String} = []
    output_labels::Vector{String} = []
end
BasicConf(conf::Dict) = BasicConf(
    conf["icon"],
    conf["idn"],
    conf["cmdtype"],
    conf["input_labels"],
    conf["output_labels"]
)

@kwdef mutable struct QuantityConf <: InsConf
    alias::String = "quantity"
    U::String = ""
    cmdheader::String = ""
    optkeys::Vector{String} = []
    optvalues::Vector{String} = []
    type::String = "set"
    separator::String = ""
    numread::Cint = 1
    help::String = ""
end
QuantityConf(qt::Dict) = QuantityConf(
    qt["alias"],
    qt["U"],
    qt["cmdheader"],
    qt["optkeys"],
    qt["optvalues"],
    qt["type"],
    qt["separator"],
    qt["numread"],
    qt["help"]
)

@kwdef mutable struct OneInsConf
    conf::BasicConf = BasicConf()
    quantities::OrderedDict{String,QuantityConf} = Dict()
end

todict(cf::BasicConf) = Dict(
    "icon" => cf.icon,
    "idn" => cf.idn,
    "cmdtype" => cf.cmdtype,
    "input_labels" => cf.input_labels,
    "output_labels" => cf.output_labels
)
todict(qtcf::QuantityConf) = Dict(
    "alias" => qtcf.alias,
    "U" => qtcf.U,
    "cmdheader" => qtcf.cmdheader,
    "optkeys" => qtcf.optkeys,
    "optvalues" => qtcf.optvalues,
    "type" => qtcf.type,
    "separator" => qtcf.separator,
    "numread" => qtcf.numread,
    "help" => qtcf.help
)
function todict(oneinscf::OneInsConf)
    dict = Dict{String,Dict{String,Any}}("conf" => todict(oneinscf.conf))
    for (qt, qtcf) in oneinscf.quantities
        dict[qt] = todict(qtcf)
    end
    dict
end

const INSCONF = OrderedDict{String,OneInsConf}() #仪器注册表