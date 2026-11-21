@option mutable struct OptBasic
    waitevents::Bool = true
    isremote::Bool = true
    viewportenable::Bool = true
    holdmainwindow::Bool = true
    hidemainwindow::Bool = false
    hideglfwwindow::Bool = false
    hideimguititlebar::Bool = true
    lowestframerate::Cint = 4
    nthreads::Cint = 2
    nthreads_2::Cint = 2
    windowsize::Vector{Cint} = [864, 486]
    openglversion::String = "4.6"
    encoding::String = "GBK"
    editor::String = "notepad"
    language::String = "简体中文"
    maincolsplit::Float64 = 0.66 #主界面左右卡片占比(DAQ 主区域宽度的比例)
    languages::Dict{String,String} = Dict()
    mcp::Bool = false        # MCP (Model Context Protocol) 端点：让外部 agent 软件（Claude Code/Cursor 等）操控 QInsControl（写操作仍走桌面确认门）
    mcpport::Cint = 8090
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
    highspeeddatatransfer::Bool = false
    savetime::Cint = 1
    cuttingfile::Cint = 2000000
    channelsize::Cint = 512
    packsize::Cint = 6
    ctbuflen::Cint = 4
    historylen::Cint = 120
    retrysendtimes::Cint = 1
    retryconnecttimes::Cint = 6
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
    maxclients::Cint = 36
    buflen::Cint = 64
end

@option mutable struct OptRegister
    historylen::Cint = 120
end

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
    default::String = "OceanBreeze"
end

@option mutable struct OptWebDashboard
    enable::Bool = false
    port::Cint = 8088
end

@option mutable struct Conf
    Basic::OptBasic = OptBasic()
    Communication::OptCommunication = OptCommunication()
    DtViewer::OptDtViewer = OptDtViewer()
    DAQ::OptDAQ = OptDAQ()
    InsBuf::OptInsBuf = OptInsBuf()
    Server::OptServer = OptServer()
    WebDashboard::OptWebDashboard = OptWebDashboard()
    Register::OptRegister = OptRegister()
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