abstract type AbstractQuantity end
@kwdef mutable struct SweepQuantity <: AbstractQuantity
    # back end
    enable::Bool = true
    name::String = ""
    alias::String = ""
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
                read : $(join(qt.showval, qt.separator)) $(qt.showU)
        auto-refresh : $(qt.refreshrate) $(qt.isautorefresh)
    """
    print(io, str)
end

function quantity(name, qtcf::QuantityConf)
    return if qtcf.type == "sweep"
        SweepQuantity(
            name=name, alias=qtcf.alias, utype=qtcf.U,
            separator=qtcf.separator, numread=qtcf.numread, help=qtcf.help, showval=fill("", qtcf.numread)
        )
    elseif qtcf.type == "set"
        SetQuantity(
            name=name, alias=qtcf.alias, optkeys=qtcf.optkeys, optvalues=qtcf.optvalues, utype=qtcf.U,
            separator=qtcf.separator, numread=qtcf.numread, help=qtcf.help, showval=fill("", qtcf.numread)
        )
    elseif qtcf.type == "read"
        ReadQuantity(
            name=name, alias=qtcf.alias, utype=qtcf.U,
            separator=qtcf.separator, numread=qtcf.numread, help=qtcf.help, showval=fill("", qtcf.numread)
        )
    end
end

function getvalU!(qt::AbstractQuantity)
    U, Us = @c getU(qt.utype, &qt.uindex)
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    if qt.separator == ""
        length(qt.showval) == qt.numread || resizefill!(qt.showval, qt.numread)
        qt.showval[1] = U == "" ? qt.read : @trypass @sprintf("%g", parse(Float64, qt.read) / Uchange) qt.read
    else
        # splitread = split(qt.read, qt.separator)
        # qt.showval = U == "" ? splitread : [@trypass @sprintf("%g", parse(Float64, r) / Uchange) r for r in splitread]
        qt.showval = split(qt.read, qt.separator)
        length(qt.showval) == qt.numread || resizefill!(qt.showval, qt.numread)
    end
    qt.showU = string(U)
end

function updatefront!(qt::SweepQuantity)
    getvalU!(qt)
    qt.show_edit = string("\n", qt.alias, "\n \n", join(qt.showval, qt.separator), " ", qt.showU, "\n ")
end

function updateoptvalue!(qt::SetQuantity)
    if qt.showU == ""
        if qt.read in qt.optvalues
            qt.optedidx = findfirst(==(qt.read), qt.optvalues)
            length(qt.showval) == qt.numread || resizefill!(qt.showval, qt.numread)
            qt.showval[1] = string(qt.optkeys[qt.optedidx], " => ", qt.read)
        end
    else
        floatread = tryparse(Float64, qt.read)
        if !isnothing(floatread)
            floatoptvalues = replace(tryparse.(Float64, qt.optvalues), nothing => NaN)
            if true in Bool.(floatread .≈ floatoptvalues)
                qt.optedidx = findfirst(floatread .≈ floatoptvalues)
                length(qt.showval) == qt.numread || resizefill!(qt.showval, qt.numread)
                qt.showval[1] = string(qt.optkeys[qt.optedidx], " => ", qt.showval[1])
            end
        end
    end
end

function updatefront!(qt::SetQuantity)
    getvalU!(qt)
    updateoptvalue!(qt)
    qt.show_edit = string("\n", qt.alias, "\n \n", join(qt.showval, qt.separator), " ", qt.showU, "\n ")
end

function updatefront!(qt::ReadQuantity)
    getvalU!(qt)
    qt.show_edit = string("\n", qt.alias, "\n \n", join(qt.showval, qt.separator), " ", qt.showU, "\n ")
end

function updatefront!(qt::AbstractQuantity; show_edit=true)
    if show_edit
        updatefront!(qt)
    else
        getvalU!(qt)
        qt isa SetQuantity && updateoptvalue!(qt)
        qt.show_view = string(qt.alias, "\n", join(qt.showval, qt.separator), " ", qt.showU)
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
    haskey(INSCONF, instrnm) || @error "[$(now())]\n$(mlstr("unsupported instrument!!!"))" instrument = instrnm
    sweepqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "sweep"]
    setqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "set"]
    readqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "read"]
    quantities = [readqts; sweepqts; setqts]
    instrqts = OrderedDict()
    for qt in quantities
        alias = INSCONF[instrnm].quantities[qt].alias
        optkeys = INSCONF[instrnm].quantities[qt].optkeys
        optvalues = INSCONF[instrnm].quantities[qt].optvalues
        utype = INSCONF[instrnm].quantities[qt].U
        type = INSCONF[instrnm].quantities[qt].type
        separator = INSCONF[instrnm].quantities[qt].separator
        numread = INSCONF[instrnm].quantities[qt].numread
        help = replace(INSCONF[instrnm].quantities[qt].help, "\\\n" => "")
        newqt = quantity(qt, QuantityConf(alias, utype, "", optkeys, optvalues, type, separator, numread, help))
        instrqts[qt] = newqt
    end
    InstrBuffer(instrnm=instrnm, quantities=instrqts)
end

function update_passfilter!(insbuf::InstrBuffer)
    for (qtnm, qt) in insbuf.quantities
        if insbuf.filter != "" && isvalid(insbuf.filter)
            qt.passfilter = if insbuf.filtervarname
                occursin(lowercase(insbuf.filter), lowercase(qtnm))
            else
                occursin(lowercase(insbuf.filter), lowercase(qt.alias))
            end
        else
            qt.passfilter = true
        end
    end
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

const INSTRBUFFERVIEWERS::Dict{String,Dict{String,InstrBufferViewer}} = Dict()

function edit(ibv::InstrBufferViewer)
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
    ins, addr = ibv.instrnm, ibv.addr
    if @c CImGui.Begin(stcstr(INSCONF[ins].conf.icon, "  ", ins, "  ", addr), &ibv.p_open)
        SetWindowBgImage()
        @c testcmd(ins, addr, &ibv.inputcmd, &ibv.reading)
        edit(ibv.insbuf, addr)
        CImGui.IsKeyPressed(ImGuiKey_F5, false) && refresh1(true)
    end
    CImGui.End()
end

let
    newcmd::Ref{Tuple{String,Bool}} = ("", false)
    global function testcmd(ins, addr, inputcmd::Ref{String}, reading::Ref{String})
        if CImGui.CollapsingHeader(stcstr("\t", mlstr("Communication Test")))
            if CImGui.BeginTabBar("communication")
                if CImGui.BeginTabItem(mlstr("Command Test"))
                    y = (1 + length(findall("\n", inputcmd[]))) * CImGui.GetTextLineHeight() +
                        2unsafe_load(IMGUISTYLE.FramePadding.y)
                    InputTextMultilineRSZ("##input cmd", inputcmd, (Cfloat(0), y))
                    if CImGui.BeginPopupContextItem()
                        CImGui.MenuItem(mlstr("Clear")) && (inputcmd[] = "")
                        CImGui.EndPopup()
                    end
                    CImGui.SameLine()
                    CImGui.Button(mlstr("Clear History")) && (reading[] = "")
                    updatecontent = newcmd[][1] == addr ? newcmd[][2] : false
                    updatecontent && (newcmd[] = ("", false))
                    TextRect(stcstr(reading[], "\n "), updatecontent; size=(Cfloat(0), 12CImGui.GetFontSize()))
                    CImGui.Spacing()
                    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, 24)
                    btw = (CImGui.GetContentRegionAvail().x - 2unsafe_load(IMGUISTYLE.ItemSpacing.x)) / 3
                    bth = 2CImGui.GetFrameHeight()
                    if CImGui.Button(stcstr(MORESTYLE.Icons.WriteBlock, "  ", mlstr("Write")), (btw, bth))
                        if addr != ""
                            reading[] *= string("Write: ", inputcmd[], "\n\n")
                            remote_do(workers()[1], ins, addr, inputcmd[]) do ins, addr, inputcmd
                                ct = Controller(ins, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
                                try
                                    login!(CPU, ct; attr=getattr(addr))
                                    ct(write, CPU, inputcmd, Val(:write))
                                catch e
                                    @error(
                                        "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                                        instrument = string(ins, ": ", addr),
                                        exception = e
                                    )
                                    showbacktrace()
                                finally
                                    logout!(CPU, ct)
                                end
                            end
                            newcmd[] = (addr, true)
                        end
                    end
                    CImGui.SameLine()
                    if CImGui.Button(stcstr(MORESTYLE.Icons.QueryBlock, "  ", mlstr("Query")), (btw, bth))
                        if addr != ""
                            reading[] *= string("Write: ", inputcmd[], "\n")
                            fetchdata = timed_remotecall_fetch(
                                workers()[1], ins, addr, inputcmd[]; timeout=CONF.DAQ.cttimeout
                            ) do ins, addr, inputcmd
                                ct = Controller(ins, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
                                try
                                    login!(CPU, ct; attr=getattr(addr))
                                    ct(query, CPU, inputcmd, Val(:query))
                                catch e
                                    @error(
                                        "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                                        instrument = string(ins, ": ", addr),
                                        exception = e
                                    )
                                    showbacktrace()
                                finally
                                    logout!(CPU, ct)
                                end
                            end
                            isnothing(fetchdata) || (reading[] *= string("Read: \n\t\t", fetchdata, "\n\n"))
                            newcmd[] = (addr, true)
                        end
                    end
                    CImGui.SameLine()
                    if CImGui.Button(stcstr(MORESTYLE.Icons.ReadBlock, "  ", mlstr("Read")), (btw, bth))
                        if addr != ""
                            fetchdata = timed_remotecall_fetch(
                                workers()[1], ins, addr; timeout=CONF.DAQ.cttimeout
                            ) do ins, addr
                                ct = Controller(ins, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
                                try
                                    login!(CPU, ct; attr=getattr(addr))
                                    ct(read, CPU, Val(:read))
                                catch e
                                    @error(
                                        "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                                        instrument = string(ins, ": ", addr),
                                        exception = e
                                    )
                                    showbacktrace()
                                finally
                                    logout!(CPU, ct)
                                end
                            end
                            isnothing(fetchdata) || (reading[] *= string("Read: \n\t\t", fetchdata, "\n\n"))
                            newcmd[] = (addr, true)
                        end
                    end
                    CImGui.PopStyleVar()
                    CImGui.EndTabItem()
                end
                if ins != "VirtualInstr" && CImGui.BeginTabItem(mlstr("Settings"))
                    comsettings(addr)
                    CImGui.EndTabItem()
                    igTabItemButton(mlstr("Save"), 0) && saveattr(addr)
                end
                CImGui.EndTabBar()
            end
            CImGui.Separator()
        end
    end
end

let
    spattrs::Dict{String,SerialInstrAttr} = Dict()
    tcpipattrs::Dict{String,TCPSocketInstrAttr} = Dict()
    virtualattrs::Dict{String,VirtualInstrAttr} = Dict()
    visaattrs::Dict{String,VISAInstrAttr} = Dict()
    global function comsettings(addr)
        if addr != "VirtualAddress"
            if occursin("SERIAL", addr)
                haskey(spattrs, addr) || (spattrs[addr] = SerialInstrAttr())
                serialsettings(spattrs[addr])
            elseif occursin("TCPSOCKET", addr)
                haskey(tcpipattrs, addr) || (tcpipattrs[addr] = TCPSocketInstrAttr())
                tcpipsettings(tcpipattrs[addr])
            elseif occursin("VIRTUAL", split(addr, "::")[1])
                haskey(virtualattrs, addr) || (virtualattrs[addr] = VirtualInstrAttr())
                virtualsettings(virtualattrs[addr])
            else
                haskey(visaattrs, addr) || (visaattrs[addr] = VISAInstrAttr())
                visasettings(visaattrs[addr])
            end
        end
    end

    global function getattr(addr)
        if myid() == 1
            return if occursin("SERIAL", addr)
                haskey(spattrs, addr) ? deepcopy(spattrs[addr]) : nothing
            elseif occursin("TCPSOCKET", addr)
                haskey(tcpipattrs, addr) ? deepcopy(tcpipattrs[addr]) : nothing
            elseif occursin("VIRTUAL", split(addr, "::")[1])
                haskey(virtualattrs, addr) ? deepcopy(virtualattrs[addr]) : nothing
            else
                haskey(visaattrs, addr) ? deepcopy(visaattrs[addr]) : nothing
            end
        else
            return remotecall_fetch(getattr, 1, addr)
        end
    end

    global function loadattr(addr)
        if haskey(CONF.Communication.attrlist, addr)
            attr = attrfromdict(CONF.Communication.attrlist[addr])
            attr isa SerialInstrAttr && (spattrs[addr] = attr)
            attr isa TCPSocketInstrAttr && (tcpipattrs[addr] = attr)
            attr isa VirtualInstrAttr && (virtualattrs[addr] = attr)
            attr isa VISAInstrAttr && (visaattrs[addr] = attr)
        end
    end
end

function saveattr(addr)
    CONF.Communication.attrlist[addr] = attrtodict(getattr(addr))
    saveconf()
end

function attrtodict(attr)
    attrdict = Dict{String,Any}("attrtype" => split(string(typeof(attr)), '.')[end])
    for fdnm in fieldnames(typeof(attr))
        val = getproperty(attr, fdnm)
        if val isa Number
            attrdict[string(fdnm, "::Number")] = val
        elseif val isa AbstractString
            attrdict[string(fdnm, "::String")] = string(val)
        elseif val isa AbstractChar
            attrdict[string(fdnm, "::Char")] = string(val)
        else
            attrdict[string(fdnm, "::Any")] = string(val)
        end
    end
    return attrdict
end

function attrfromdict(attrdict)
    type = Symbol(attrdict["attrtype"]) |> eval
    attr = type()
    for (key, val) in attrdict
        key == "attrtype" && continue
        fdnm, ftype = split(key, "::")
        if hasfield(type, Symbol(fdnm))
            if ftype in ["Number", "String"]
                setproperty!(attr, Symbol(fdnm), val)
            elseif ftype == "Char"
                setproperty!(attr, Symbol(fdnm), val[1])
            elseif ftype == "Any"
                setproperty!(attr, Symbol(fdnm), eval(Meta.parse(val)))
            end
        end
    end
    return attr
end

function serialsettings(attr::SerialInstrAttr)
    baudrate = Cint(attr.baudrate)
    @c(CImGui.InputInt(mlstr("Baud Rate"), &baudrate)) && baudrate > 0 && (attr.baudrate = baudrate)
    mode = string(attr.mode)
    @c(ComboS(mlstr("Mode"), &mode, string.(instances(SPMode)))) && (attr.mode = getproperty(LibSerialPort, Symbol(mode)))
    ndatabits = Cint(attr.ndatabits)
    @c(igSliderInt(mlstr("Data Bits"), &ndatabits, 5, 8, "%d", 0)) && (attr.ndatabits = ndatabits)
    parity = string(attr.parity)
    @c(ComboS(mlstr("Parity"), &parity, string.(instances(SPParity)))) && (attr.parity = getproperty(LibSerialPort, Symbol(parity)))
    nstopbits = Cint(attr.nstopbits)
    @c(igSliderInt(mlstr("Stop Bits"), &nstopbits, 1, 2, "%d", 0)) && (attr.nstopbits = nstopbits)
    rts = string(attr.rts)
    @c(ComboS(mlstr("Ready to Send"), &rts, string.(instances(SPrts)))) && (attr.rts = getproperty(LibSerialPort, Symbol(rts)))
    cts = string(attr.cts)
    @c(ComboS(mlstr("Clear to Send"), &cts, string.(instances(SPcts)))) && (attr.cts = getproperty(LibSerialPort, Symbol(cts)))
    dtr = string(attr.dtr)
    @c(ComboS(mlstr("Data Terminal Ready"), &dtr, string.(instances(SPdtr)))) && (attr.dtr = getproperty(LibSerialPort, Symbol(dtr)))
    dsr = string(attr.dsr)
    @c(ComboS(mlstr("Data Set Ready"), &dsr, string.(instances(SPdsr)))) && (attr.dsr = getproperty(LibSerialPort, Symbol(dsr)))
    xonxoff = string(attr.xonxoff)
    @c(ComboS(mlstr("XON/XOFF"), &xonxoff, string.(instances(SPXonXoff)))) && (attr.xonxoff = getproperty(LibSerialPort, Symbol(xonxoff)))
    timeoutw = Cfloat(attr.timeoutw)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Write Timeout"), " (s)"), &timeoutw,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutw = timeoutw)
    timeoutr = Cfloat(attr.timeoutr)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Read Timeout"), " (s)"), &timeoutr,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutr = timeoutr)
    querydelay = Cfloat(attr.querydelay)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Query Delay"), " (s)"), &querydelay,
        1, 0, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.querydelay = querydelay)
    termchar = TERMCHARDICTINV[attr.termchar]
    @c(ComboS(mlstr("Termination Character"), &termchar, keys(TERMCHARDICT))) && (attr.termchar = TERMCHARDICT[termchar])
end
function tcpipsettings(attr::TCPSocketInstrAttr)
    timeoutw = Cfloat(attr.timeoutw)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Write Timeout"), " (s)"), &timeoutw,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutw = timeoutw)
    timeoutr = Cfloat(attr.timeoutr)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Read Timeout"), " (s)"), &timeoutr,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutr = timeoutr)
    querydelay = Cfloat(attr.querydelay)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Query Delay"), " (s)"), &querydelay,
        1, 0, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.querydelay = querydelay)
    termchar = TERMCHARDICTINV[attr.termchar]
    @c(ComboS(mlstr("Termination Character"), &termchar, keys(TERMCHARDICT))) && (attr.termchar = TERMCHARDICT[termchar])
end
function virtualsettings(attr::VirtualInstrAttr)
    querydelay = Cfloat(attr.querydelay)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Query Delay"), " (s)"), &querydelay,
        1, 0, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.querydelay = querydelay)
    termchar = TERMCHARDICTINV[attr.termchar]
    @c(ComboS(mlstr("Termination Character"), &termchar, keys(TERMCHARDICT))) && (attr.termchar = TERMCHARDICT[termchar])
end
function visasettings(attr::VISAInstrAttr)
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, "ASRL")
    baudrate = Cint(attr.baudrate)
    @c(CImGui.InputInt(mlstr("Baud Rate"), &baudrate)) && baudrate > 0 && (attr.baudrate = baudrate)
    ndatabits = Cint(attr.ndatabits)
    @c(igSliderInt(mlstr("Data Bits"), &ndatabits, 5, 8, "%d", 0)) && (attr.ndatabits = ndatabits)
    parity = string(attr.parity)
    @c(ComboS(mlstr("Parity"), &parity, string.(instances(QInsControlCore.VI_ASRL_PAR)))) && (attr.parity = getproperty(QInsControlCore, Symbol(parity)))
    nstopbits = string(attr.nstopbits)
    @c(ComboS(mlstr("Stop Bits"), &nstopbits, string.(instances(QInsControlCore.VI_ASRL_STOP)))) && (attr.nstopbits = getproperty(QInsControlCore, Symbol(nstopbits)))
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Common"))
    @c CImGui.Checkbox(mlstr(attr.async ? "Asynchronous" : "Synchronous"), &attr.async)
    querydelay = Cfloat(attr.querydelay)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Query Delay"), " (s)"), &querydelay,
        1, 0, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.querydelay = querydelay)
    termchar = TERMCHARDICTINV[attr.termchar]
    @c(ComboS(mlstr("Termination Character"), &termchar, keys(TERMCHARDICT))) && (attr.termchar = TERMCHARDICT[termchar])
end

function edit(insbuf::InstrBuffer, addr)
    CImGui.PushID(insbuf.instrnm)
    CImGui.PushID(addr)
    @c(InputTextRSZ("##filterqt", &insbuf.filter)) && update_passfilter!(insbuf)
    CImGui.SameLine()
    @c(CImGui.Checkbox(
        insbuf.filtervarname ? mlstr("Filter variables") : mlstr("Filter aliases"),
        &insbuf.filtervarname
    )) && update_passfilter!(insbuf)
    CImGui.BeginChild("InstrBuffer")
    btsize = (CImGui.GetContentRegionAvail().x - unsafe_load(IMGUISTYLE.ItemSpacing.x) * (CONF.InsBuf.showcol - 1)) / CONF.InsBuf.showcol
    showi = 0
    for (i, qt) in enumerate(values(insbuf.quantities))
        qt.enable || insbuf.showdisable || continue
        qt.passfilter || continue
        showi += 1
        CImGui.PushID(qt.name)
        CONF.InsBuf.showcol == 1 || showi % CONF.InsBuf.showcol == 1 || showi == 1 || CImGui.SameLine()
        edit(qt, insbuf.instrnm, addr; btsize=(btsize, Cfloat(0)))
        CImGui.PopID()
        CImGui.Indent()
        if CImGui.BeginDragDropSource(0)
            @c CImGui.SetDragDropPayload("Swap DAQTask", &i, sizeof(Cint))
            CImGui.Text(qt.alias)
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Swap DAQTask")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                if i != payload_i
                    key_i = idxkey(insbuf.quantities, i)
                    key_payload_i = idxkey(insbuf.quantities, payload_i)
                    swapvalue!(insbuf.quantities, key_i, key_payload_i)
                end
            end
            CImGui.EndDragDropTarget()
        end
        CImGui.Unindent()
    end
    CImGui.EndChild()
    CImGui.PopID()
    CImGui.PopID()
    if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
        CImGui.OpenPopupOnItemClick(stcstr("rightclick", insbuf.instrnm, addr))
    end
    if CImGui.BeginPopup(stcstr("rightclick", insbuf.instrnm, addr))
        if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InstrumentsManualRef, " ", mlstr("Manual Refresh")), "F5")
            insbuf.isautorefresh = true
            refresh1(true)
        end
        CImGui.Text(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Auto Refresh")))
        CImGui.SameLine()
        isautoref = SYNCSTATES[Int(IsAutoRefreshing)]
        @c CImGui.Checkbox("##auto refresh", &isautoref)
        SYNCSTATES[Int(IsAutoRefreshing)] = isautoref
        insbuf.isautorefresh = SYNCSTATES[Int(IsAutoRefreshing)]
        CImGui.Text(stcstr(MORESTYLE.Icons.ShowCol, " ", mlstr("Display Columns")))
        CImGui.SameLine()
        CImGui.PushItemWidth(3CImGui.GetFontSize() / 2)
        @c CImGui.DragInt(
            "##display columns",
            &CONF.InsBuf.showcol, 1, 1, 12, "%d",
            CImGui.ImGuiSliderFlags_AlwaysClamp
        )
        CImGui.PopItemWidth()
        CImGui.Text(stcstr(MORESTYLE.Icons.View, " ", mlstr("Show Disabled")))
        CImGui.SameLine()
        @c CImGui.Checkbox("##show disabled", &insbuf.showdisable)
        CImGui.EndPopup()
    end
    CImGui.IsKeyPressed(ImGuiKey_F5, false) && refresh1(true)
end

let
    stbtsz::Float32 = 0
    closepopup::Bool = false
    global function edit(qt::SweepQuantity, instrnm, addr; btsize=(-1, 0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.SweepQuantityTxt)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(
                IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered
            )
        )
        qt.show_edit == "" && updatefront!(qt)
        # CImGui.PushFont(BIGFONT)
        ColoredButton(
            stcstr(centermultiline(qt.show_edit), "###for refresh");
            size=btsize,
            colbt=if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.SweepQuantityBt
            else
                MORESTYLE.Colors.LogError
            end
        ) && Threads.@spawn @trycatch mlstr("reading task failed!!!") getread!(qt, instrnm, addr)
        if qt.issweeping
            rmin = CImGui.GetItemRectMin()
            rsz = CImGui.GetItemRectSize()
            frac = Cfloat(calcfraction(qt.presenti, qt.nstep))
            phcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PlotHistogram)
            pgcol = [phcol.x, phcol.y, phcol.z, min(0.6, phcol.w)]
            CImGui.AddRectFilled(
                CImGui.GetWindowDrawList(), rmin, (rmin.x + frac * rsz.x, rmin.y + rsz.y),
                pgcol, unsafe_load(IMGUISTYLE.FrameRounding)
            )
            if CImGui.IsItemHovered() && CImGui.BeginTooltip()
                CImGui.ProgressBar(
                    calcfraction(qt.presenti, qt.nstep), (0, 0),
                    progressmark(qt.presenti, qt.nstep, qt.elapsedtime)
                )
                CImGui.EndTooltip()
            end
        end
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        if CImGui.BeginPopupContextItem()
            if qt.enable
                ftsz = CImGui.GetFontSize()
                itemw = CImGui.CalcItemWidth()
                CImGui.BeginGroup()
                CImGui.PushItemWidth(2itemw / 3)
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Cfloat(0), Cfloat(0)))
                @c InputTextWithHintRSZ("##step", mlstr("step"), &qt.step)
                CImGui.PopStyleVar()
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Cfloat(0), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
                @c InputTextWithHintRSZ("##stop", mlstr("stop"), &qt.stop)
                CImGui.PopItemWidth()
                CImGui.EndGroup()
                CImGui.SameLine()
                CImGui.PushStyleVar(
                    CImGui.ImGuiStyleVar_FramePadding,
                    (unsafe_load(IMGUISTYLE.FramePadding.x), CImGui.GetFrameHeight() - ftsz / 2)
                )
                CImGui.PushItemWidth(itemw / 3)
                @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
                CImGui.PopItemWidth()
                CImGui.PopStyleVar(2)
                @c CImGui.DragFloat("##delay", &qt.delay, 1.0, 0.01, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                if qt.issweeping
                    if CImGui.Button(
                        mlstr(" Stop "), (itemw, Cfloat(0))
                    ) || CImGui.IsKeyPressed(ImGuiKey_Enter, false)
                        qt.issweeping = false
                    end
                else
                    if CImGui.Button(
                        mlstr("Start"), (itemw, Cfloat(0))
                    ) || CImGui.IsKeyPressed(ImGuiKey_Enter, false)
                        apply!(qt, instrnm, addr)
                        closepopup = true
                    end
                end
                if closepopup && !CImGui.IsKeyDown(ImGuiKey_Enter)
                    CImGui.CloseCurrentPopup()
                    closepopup = false
                end
            end
            if qt.isautorefresh
                CImGui.PushItemWidth(4CImGui.GetFontSize())
                @c CImGui.DragFloat(
                    "##refreshrate", &qt.refreshrate, 0.1, 0.1, 360, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.PopItemWidth()
                CImGui.SameLine()
            end
            @c CImGui.Checkbox(stcstr(mlstr("refresh"), qt.isautorefresh ? " (s)" : ""), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
        end
    end
end #let

let
    triggerset::Bool = false
    popup_before_list::Dict{String,Dict{String,Dict{String,Bool}}} = Dict()
    popup_now::Bool = false
    closepopup::Bool = false
    global function edit(qt::SetQuantity, instrnm, addr; btsize=(-1, 0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.SetQuantityTxt)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
        )
        qt.show_edit == "" && updatefront!(qt)
        # CImGui.PushFont(BIGFONT)
        ColoredButton(
            stcstr(centermultiline(qt.show_edit), "###for refresh");
            size=btsize,
            colbt=if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.SetQuantityBt
            else
                MORESTYLE.Colors.LogError
            end
        ) && Threads.@spawn @trycatch mlstr("reading task failed!!!") getread!(qt, instrnm, addr)
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        haskey(popup_before_list, instrnm) || (popup_before_list[instrnm] = Dict())
        haskey(popup_before_list[instrnm], addr) || (popup_before_list[instrnm][addr] = Dict())
        haskey(popup_before_list[instrnm][addr], qt.name) || (popup_before_list[instrnm][addr][qt.name] = false)
        popup_now = CImGui.BeginPopupContextItem()
        popup_before = popup_before_list[instrnm][addr][qt.name]
        !popup_now && popup_before && (popup_before_list[instrnm][addr][qt.name] = false)
        if popup_now
            if qt.enable
                ftsz = CImGui.GetFontSize()
                itemw = CImGui.CalcItemWidth()
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Cfloat(0), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
                CImGui.PushItemWidth(2itemw / 3)
                @c InputTextWithHintRSZ("##set", mlstr("set value"), &qt.set)
                CImGui.PopItemWidth()
                CImGui.SameLine()
                CImGui.PushItemWidth(itemw / 3)
                @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
                CImGui.PopItemWidth()
                CImGui.PopStyleVar()
                if CImGui.Button(
                       mlstr("Confirm"), (itemw, Cfloat(0))
                   ) || triggerset || CImGui.IsKeyPressed(ImGuiKey_Enter, false)
                    triggerset && (qt.set = qt.optvalues[qt.optedidx])
                    apply!(qt, instrnm, addr, triggerset)
                    triggerset = false
                    closepopup = true
                end
                if closepopup && !CImGui.IsKeyDown(ImGuiKey_Enter)
                    CImGui.CloseCurrentPopup()
                    closepopup = false
                end
                if !isempty(qt.optkeys) && !popup_before && addr != ""
                    fetchdata = refresh_qt(instrnm, addr, qt.name)
                    if !isnothing(fetchdata)
                        fetchdata in qt.optvalues && (qt.optedidx = findfirst(==(fetchdata), qt.optvalues))
                    end
                end
                CImGui.BeginGroup()
                for (i, optv) in enumerate(qt.optvalues)
                    (iseven(i) || optv == "") && continue
                    @c(CImGui.RadioButton(qt.optkeys[i], &qt.optedidx, i)) && (triggerset = true)
                end
                CImGui.EndGroup()
                CImGui.SameLine(0, 2CImGui.GetFontSize())
                CImGui.BeginGroup()
                for (i, optv) in enumerate(qt.optvalues)
                    (isodd(i) || optv == "") && continue
                    @c(CImGui.RadioButton(qt.optkeys[i], &qt.optedidx, i)) && (triggerset = true)
                end
                CImGui.EndGroup()
            end
            if qt.isautorefresh
                CImGui.PushItemWidth(4CImGui.GetFontSize())
                @c CImGui.DragFloat(
                    "##refreshrate", &qt.refreshrate, 0.1, 0.1, 360, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.PopItemWidth()
                CImGui.SameLine()
            end
            @c CImGui.Checkbox(stcstr(mlstr("refresh"), qt.isautorefresh ? " (s)" : ""), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
            popup_before_list[instrnm][addr][qt.name] = true
        end
    end
end

let
    refbtsz::Float32 = 0
    global function edit(qt::ReadQuantity, instrnm, addr; btsize=(-1, 0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ReadQuantityTxt)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
        )
        qt.show_edit == "" && updatefront!(qt)
        # CImGui.PushFont(BIGFONT)
        ColoredButton(
            stcstr(centermultiline(qt.show_edit), "###for refresh");
            size=btsize,
            colbt=if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.ReadQuantityBt
            else
                MORESTYLE.Colors.LogError
            end
        ) && Threads.@spawn @trycatch mlstr("reading task failed!!!") getread!(qt, instrnm, addr)
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        if CImGui.BeginPopupContextItem()
            CImGui.Text(stcstr(mlstr("unit"), " "))
            CImGui.SameLine()
            CImGui.PushItemWidth(4CImGui.GetFontSize())
            @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
            CImGui.PopItemWidth()
            CImGui.SameLine()
            CImGui.PushItemWidth(2CImGui.GetFontSize())
            qt.isautorefresh && @c CImGui.DragFloat(
                "##refreshrate", &qt.refreshrate, 0.1, 0.1, 360, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            CImGui.PopItemWidth()
            CImGui.SameLine()
            @c CImGui.Checkbox(stcstr(mlstr("refresh"), qt.isautorefresh ? " (s)" : ""), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
        end
    end
end

function view(instrbufferviewers_local)
    for (ins, inses) in filter(x -> !isempty(x.second), instrbufferviewers_local)
        ins == "Others" && continue
        for (addr, ibv) in inses
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(ins, "：", addr))
            CImGui.PushID(addr)
            view(ibv.insbuf)
            CImGui.PopID()
        end
    end
end

function view(insbuf::InstrBuffer)
    y = ceil(Int, length(insbuf.quantities) / CONF.InsBuf.showcol) * 2CImGui.GetFrameHeight()
    CImGui.BeginChild("view insbuf", (Float32(0), y))
    CImGui.Columns(CONF.InsBuf.showcol, C_NULL, false)
    CImGui.PushID(insbuf.instrnm)
    for (name, qt) in insbuf.quantities
        CImGui.PushID(name)
        view(qt)
        CImGui.NextColumn()
        CImGui.PopID()
    end
    CImGui.PopID()
    CImGui.EndChild()
end

function view(qt::AbstractQuantity, size=(-1, 0))
    qt.show_view == "" && updatefront!(qt; show_edit=false)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Button,
        qt.enable ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button) : MORESTYLE.Colors.LogError
    )
    if CImGui.Button(centermultiline(qt.show_view), size)
        _, Us = @c getU(qt.utype, &qt.uindex)
        uindex = findfirst(==(qt.showU), string.(Us))
        if !isnothing(uindex)
            uindexo = qt.uindex
            qt.uindex = uindex + 1
            updatefront!(qt; show_edit=false)
            qt.uindex = uindexo
        end
    end
    CImGui.PopStyleColor()
    if CImGui.IsItemHovered() && !(qt isa ReadQuantity)
        CImGui.BeginTooltip()
        CImGui.PushTextWrapPos(CImGui.GetFontSize() * 36.0)
        U, _ = @c getU(qt.utype, &qt.uindex)
        if qt isa SweepQuantity
            CImGui.Text(stcstr(mlstr("step"), mlstr(": "), qt.step, U))
            CImGui.Text(stcstr(mlstr("stop"), mlstr(": "), qt.stop, U))
            CImGui.Text(stcstr(mlstr("delay"), mlstr(": "), qt.delay, "s"))
        elseif qt isa SetQuantity
            CImGui.Text(stcstr(mlstr("set"), mlstr(": "), qt.set, U))
        end
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
end

function apply!(qt::SweepQuantity, instrnm, addr)
    addr == "" && return nothing
    U, Us = @c getU(qt.utype, &qt.uindex)
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    start = timed_remotecall_fetch(
        workers()[1], instrnm, addr; timeout=CONF.DAQ.cttimeout
    ) do instrnm, addr
        ct = Controller(instrnm, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
        try
            getfunc = Symbol(instrnm, :_, qt.name, :_get) |> eval
            login!(CPU, ct; attr=getattr(addr))
            parse(Float64, ct(getfunc, CPU, Val(:read)))
        catch e
            @error(
                "[$(now())]\n$(mlstr("error getting start value!!!"))",
                instrument = string(instrnm, "-", addr),
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, ct)
        end
    end
    step = @trypasse eval(Meta.parse(qt.step)) * Uchange begin
        @error "[$(now())]\n$(mlstr("error parsing step value!!!"))" step = qt.step
    end
    stop = @trypasse eval(Meta.parse(qt.stop)) * Uchange begin
        @error "[$(now())]\n$(mlstr("error parsing stop value!!!"))" stop = qt.stop
    end
    if !(isnothing(start) | isnothing(step) | isnothing(stop))
        sweeplist = gensweeplist(start, step, stop)
        Threads.@spawn @trycatch mlstr("sweeping task failed!!!") begin
            qt.issweeping = true
            @info "[$(now())]\nBefore sweeping" instrument = instrnm address = addr quantity = qt
            actionidx = 1
            SYNCSTATES[Int(IsDAQTaskRunning)] && (actionidx = logaction(qt, instrnm, addr))
            sweep_c = Channel{Vector{String}}(CONF.DAQ.channelsize)
            sweep_rc = RemoteChannel(() -> sweep_c)
            idxbuf = SharedVector{Int}(1)
            timebuf = SharedVector{Float64}(1)
            qt.nstep = length(sweeplist)
            qt.presenti = 0
            qt.elapsedtime = 0
            sweepcalltask = @async @trycatch mlstr("remote sweeping task failed!!!") remotecall_wait(
                workers()[1], instrnm, addr, sweeplist, sweep_rc, qt.name, qt.delay, idxbuf, timebuf
            ) do instrnm, addr, sweeplist, sweep_rc, qtnm, delay, idxbuf, timebuf
                haskey(SWEEPCTS, instrnm) || (SWEEPCTS[instrnm] = Dict())
                haskey(SWEEPCTS[instrnm], addr) || (SWEEPCTS[instrnm][addr] = Dict())
                if haskey(SWEEPCTS[instrnm][addr], qt.name)
                    SWEEPCTS[instrnm][addr][qt.name][1][] = true
                else
                    SWEEPCTS[instrnm][addr][qt.name] = (
                        Ref(true),
                        Controller(instrnm, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
                    )
                end
                sweep_lc = Channel{String}(CONF.DAQ.channelsize)
                login!(CPU, SWEEPCTS[instrnm][addr][qt.name][2]; quiet=false, attr=getattr(addr))
                try
                    setfunc = Symbol(instrnm, :_, qtnm, :_set) |> eval
                    getfunc = Symbol(instrnm, :_, qtnm, :_get) |> eval
                    @sync begin
                        sweeptask = @async @trycatch mlstr("sweeping task failed!!!") begin
                            tstart = time()
                            for (i, sv) in enumerate(sweeplist)
                                SWEEPCTS[instrnm][addr][qt.name][1][] || break
                                SWEEPCTS[instrnm][addr][qt.name][2](setfunc, CPU, string(sv), Val(:write))
                                sleep(delay)
                                put!(sweep_lc, CONF.InsBuf.retreading ? SWEEPCTS[instrnm][addr][qt.name][2](getfunc, CPU, Val(:read)) : string(sv))
                                idxbuf[1] = i
                                timebuf[1] = time() - tstart
                            end
                        end
                        @async @trycatch mlstr("transfering sweeping data failed!!!") while !istaskdone(sweeptask) || isready(sweep_lc)
                            isready(sweep_lc) ? put!(sweep_rc, packtake!(sweep_lc, CONF.DAQ.packsize)) : sleep(delay / 10)
                        end
                    end
                catch e
                    @error(
                        "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                        instrument = string(instrnm, ": ", addr),
                        quantity = qtnm,
                        exception = e
                    )
                    showbacktrace()
                finally
                    logout!(CPU, SWEEPCTS[instrnm][addr][qt.name][2]; quiet=false)
                    SWEEPCTS[instrnm][addr][qt.name][1][] = false
                end
            end
            ## local
            while !istaskdone(sweepcalltask) || isready(sweep_rc)
                qt.issweeping || remotecall_wait(workers()[1], instrnm, addr) do instrnm, addr
                    SWEEPCTS[instrnm][addr][qt.name][1][] = false
                end
                isready(sweep_rc) ? for val in take!(sweep_rc)
                    qt.read = val
                    qt.presenti = idxbuf[1]
                    qt.elapsedtime = timebuf[1]
                    updatefront!(qt)
                end : sleep(qt.delay / 10)
            end
            qt.issweeping = false
            @info "[$(now())]\nAfter sweeping" instrument = instrnm address = addr quantity = qt
            SYNCSTATES[Int(IsDAQTaskRunning)] && logaction(qt, instrnm, addr, actionidx)
        end
    else
        qt.issweeping = false
    end
    return nothing
end

function apply!(qt::SetQuantity, instrnm, addr, byoptvalues=false)
    addr == "" && return nothing
    U, Us = @c getU(qt.utype, &qt.uindex)
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    sv = (U == "" || byoptvalues) ? qt.set : @trypasse string(float(eval(Meta.parse(qt.set)) * Uchange)) qt.set
    sv = string(lstrip(rstrip(sv)))
    if byoptvalues || (U == "" && sv != "") || !isnothing(tryparse(Float64, sv))
        @info "[$(now())]\nBefore setting" instrument = instrnm address = addr quantity = qt
        actionidx = 1
        SYNCSTATES[Int(IsDAQTaskRunning)] && (actionidx = logaction(qt, instrnm, addr))
        fetchdata = timed_remotecall_fetch(
            workers()[1], instrnm, addr, sv; timeout=CONF.DAQ.cttimeout
        ) do instrnm, addr, sv
            ct = Controller(instrnm, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
            try
                setfunc = Symbol(instrnm, :_, qt.name, :_set) |> eval
                getfunc = Symbol(instrnm, :_, qt.name, :_get) |> eval
                login!(CPU, ct; attr=getattr(addr))
                ct(CPU, sv, Val(:query)) do instr, sv
                    setfunc(instr, sv)
                    instr.attr.querydelay < 0.001 ? yield() : sleep(instr.attr.querydelay)
                    getfunc(instr)
                end
            catch e
                @error(
                    "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                    instrument = string(instrnm, ": ", addr),
                    quantity = qt.name,
                    exception = e
                )
                showbacktrace()
            finally
                logout!(CPU, ct)
            end
        end
        isnothing(fetchdata) || (qt.read = fetchdata; updatefront!(qt))
        @info "[$(now())]\nAfter setting" instrument = instrnm address = addr quantity = qt
        SYNCSTATES[Int(IsDAQTaskRunning)] && logaction(qt, instrnm, addr, actionidx)
    else
        @warn "[$(now())]\n$(mlstr("invalid inputs!"))"
    end
    return nothing
end

function logaction(qt::AbstractQuantity, instrnm, addr)
    haskey(CFGBUF, "actions") || (CFGBUF["actions"] = Vector{Tuple{DateTime,String,String,AbstractQuantity}}[])
    push!(CFGBUF["actions"], Tuple{DateTime,String,String,AbstractQuantity}[])
    push!(CFGBUF["actions"][end], (now(), instrnm, addr, deepcopy(qt)))
    return length(CFGBUF["actions"])
end
function logaction(qt::AbstractQuantity, instrnm, addr, idx)
    haskey(CFGBUF, "actions") || (CFGBUF["actions"] = Vector{Tuple{DateTime,String,String,AbstractQuantity}}[])
    if idx > length(CFGBUF["actions"])
        push!(CFGBUF["actions"], Tuple{DateTime,String,String,AbstractQuantity}[])
        push!(CFGBUF["actions"][end], (DateTime(0), instrnm, addr, deepcopy(qt)))
        push!(CFGBUF["actions"][end], (now(), instrnm, addr, deepcopy(qt)))
    else
        push!(CFGBUF["actions"][idx], (now(), instrnm, addr, deepcopy(qt)))
    end
end

function viewactions(actions::Vector{Vector{Tuple{DateTime,String,String,AbstractQuantity}}})
    CImGui.BeginChild("viewactions")
    CImGui.Columns(CONF.InsBuf.showcol, C_NULL, false)
    for (i, action) in enumerate(actions)
        CImGui.PushID(i)
        viewactions(action)
        CImGui.NextColumn()
        CImGui.PopID()
    end
    CImGui.EndChild()
end
function viewactions(actions::Vector{Tuple{DateTime,String,String,AbstractQuantity}})
    sz1 = CImGui.CalcTextSize(mlstr("B\ne\nf\no\nr\ne")).y
    sz2 = CImGui.CalcTextSize(mlstr("A\nf\nt\ne\nr")).y
    y = sz1 + sz2 + 4unsafe_load(IMGUISTYLE.FramePadding.y) + 2unsafe_load(IMGUISTYLE.WindowPadding.y) +
        unsafe_load(IMGUISTYLE.ItemSpacing.y) + CImGui.GetFrameHeightWithSpacing()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
    CImGui.BeginChild("action", (Cfloat(-1), y), true)
    ColoredButton(
        stcstr(actions[1][2], ": ", actions[1][3]);
        size=(-1, 0), colbt=(0, 0, 0, 0), colbth=(0, 0, 0, 0), colbta=(0, 0, 0, 0)
    )
    if length(actions) == 1
        CImGui.Button(mlstr("B\ne\nf\no\nr\ne"), (2CImGui.GetFontSize(), Cfloat(0)))
        CImGui.SameLine()
        viewaction(actions[1], sz1 + 2unsafe_load(IMGUISTYLE.FramePadding.y))
        CImGui.Button(mlstr("A\nf\nt\ne\nr"), (2CImGui.GetFontSize(), Cfloat(0)))
        CImGui.SameLine()
        CImGui.Button(mlstr("Unrecorded"), (-1, -1))
    elseif length(actions) == 2
        CImGui.PushID("before")
        CImGui.Button(mlstr("B\ne\nf\no\nr\ne"), (2CImGui.GetFontSize(), Cfloat(0)))
        CImGui.SameLine()
        viewaction(actions[1], sz1 + 2unsafe_load(IMGUISTYLE.FramePadding.y))
        CImGui.PopID()
        CImGui.PushID("after")
        CImGui.Button(mlstr("A\nf\nt\ne\nr"), (2CImGui.GetFontSize(), Cfloat(0)))
        CImGui.SameLine()
        viewaction(actions[2], sz2 + 2unsafe_load(IMGUISTYLE.FramePadding.y))
        CImGui.PopID()
    end
    CImGui.EndChild()
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end
function viewaction(action::Tuple{DateTime,String,String,AbstractQuantity}, totalheight)
    if action[1] == DateTime(0)
        CImGui.Button(mlstr("Unrecorded"), (Cfloat(-1), totalheight))
    else
        CImGui.BeginGroup()
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
        CImGui.Button(string(action[1]), (Cfloat(-1), 2CImGui.GetFontSize()))
        view(action[4], (Cfloat(-1), totalheight - CImGui.GetItemRectSize().y))
        CImGui.PopStyleVar()
        CImGui.EndGroup()
    end
end

function resolvedisablelist(qt::AbstractQuantity, instrnm, addr)
    haskey(CONF.InsBuf.disablelist, instrnm) || (CONF.InsBuf.disablelist[instrnm] = Dict())
    haskey(CONF.InsBuf.disablelist[instrnm], addr) || (CONF.InsBuf.disablelist[instrnm][addr] = [])
    disablelist = CONF.InsBuf.disablelist[instrnm][addr]
    if qt.enable
        qt.name in disablelist && deleteat!(disablelist, findfirst(==(qt.name), disablelist))
    else
        qt.name in disablelist || push!(disablelist, qt.name)
    end
    saveconf()
end

function resolveunitlist(qt::AbstractQuantity, instrnm, addr)
    haskey(CONF.InsBuf.unitlist, instrnm) || (CONF.InsBuf.unitlist[instrnm] = Dict())
    haskey(CONF.InsBuf.unitlist[instrnm], addr) || (CONF.InsBuf.unitlist[instrnm][addr] = Dict())
    unitlist = CONF.InsBuf.unitlist[instrnm][addr]
    haskey(unitlist, qt.name) || (unitlist[qt.name] = qt.uindex)
    unitlist[qt.name] != qt.uindex && (unitlist[qt.name] = qt.uindex; saveconf())
end

function getread!(qt::AbstractQuantity, instrnm, addr)
    if qt.enable && addr != ""
        fetchdata = refresh_qt(instrnm, addr, qt.name)
        isnothing(fetchdata) || (qt.read = fetchdata)
        updatefront!(qt)
    end
end

function refresh_qt(instrnm, addr, qtnm)
    timed_remotecall_fetch(workers()[1], instrnm, addr; timeout=CONF.DAQ.cttimeout) do instrnm, addr
        ct = Controller(instrnm, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
        try
            getfunc = Symbol(instrnm, :_, qtnm, :_get) |> eval
            login!(CPU, ct; attr=getattr(addr))
            ct(getfunc, CPU, Val(:read))
        catch e
            @error(
                "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                instrument = string(instrnm, ": ", addr),
                quantity = qtnm,
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, ct)
        end
    end
end

function log_instrbufferviewers()
    refresh1(true)
    CFGBUF["instrbufferviewers/[$(now())]"] = deepcopy(INSTRBUFFERVIEWERS)
end

const REFRESHLOCK = Threads.Condition()
function refresh1(log=false; instrlist=keys(INSTRBUFFERVIEWERS))
    fetchibvs = lock(REFRESHLOCK) do
        timed_remotecall_fetch(workers()[1], INSTRBUFFERVIEWERS; timeout=120) do ibvs
            merge!(INSTRBUFFERVIEWERS, ibvs)
            for (ins, inses) in filter(x -> x.first in instrlist && !isempty(x.second), INSTRBUFFERVIEWERS)
                ins == "Others" && continue
                for (addr, ibv) in inses
                    if ibv.insbuf.isautorefresh || log
                        haskey(REFRESHCTS, ins) || (REFRESHCTS[ins] = Dict())
                        haskey(REFRESHCTS[ins], addr) || (REFRESHCTS[ins][addr] = Controller(
                            ins, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout
                        )
                        )
                        ct = REFRESHCTS[ins][addr]
                        try
                            login!(CPU, ct; attr=getattr(addr))
                            for (qtnm, qt) in ibv.insbuf.quantities
                                if log && (CONF.DAQ.logall || qt.enable)
                                    getfunc = Symbol(ins, :_, qtnm, :_get) |> eval
                                    qt.read = ct(getfunc, CPU, Val(:read))
                                    qt.refreshed = true
                                    myid() == 1 && updatefront!(qt)
                                elseif qt.enable && qt.isautorefresh
                                    t = time()
                                    δt = t - qt.lastrefresh
                                    if δt > qt.refreshrate - 0.005
                                        qt.lastrefresh = t
                                        getfunc = Symbol(ins, :_, qtnm, :_get) |> eval
                                        qt.read = ct(getfunc, CPU, Val(:read))
                                        qt.refreshed = true
                                        myid() == 1 && updatefront!(qt)
                                    end
                                end
                            end
                        catch e
                            @error(
                                "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                                instrument = string(ins, ": ", addr),
                                exception = e
                            )
                            showbacktrace()
                        finally
                            logout!(CPU, ct)
                        end
                    end
                end
            end
            return INSTRBUFFERVIEWERS
        end
    end
    if CONF.Basic.isremote && !isnothing(fetchibvs)
        for (ins, inses) in filter(x -> !isempty(x.second), INSTRBUFFERVIEWERS)
            for (addr, ibv) in filter(x -> x.second.insbuf.isautorefresh || log, inses)
                if haskey(fetchibvs, ins) && haskey(fetchibvs[ins], addr)
                    reflist = if log
                        CONF.DAQ.logall ? ibv.insbuf.quantities : filter(x -> x.second.enable, ibv.insbuf.quantities)
                    else
                        filter(ibv.insbuf.quantities) do qtpair
                            qt = qtpair.second
                            fetchqt = fetchibvs[ins][addr].insbuf.quantities[qtpair.first]
                            fetchqt.refreshed && (qt.refreshed = false)
                            qt.enable && qt.isautorefresh && fetchqt.refreshed
                        end
                    end
                    for (qtnm, qt) in reflist
                        qt.read = fetchibvs[ins][addr].insbuf.quantities[qtnm].read
                        qt.lastrefresh = fetchibvs[ins][addr].insbuf.quantities[qtnm].lastrefresh
                        updatefront!(qt)
                    end
                end
            end
        end
    end
end

let
    task::Ref{Task} = Ref{Task}()
    monitortask::Ref{Task} = Ref{Task}()
    stoptask::Bool = false
    global function stoprefresh()
        stoptask = true
        sleep(0.1)
        istaskdone(task[]) && istaskdone(monitortask[]) || schedule(task[], mlstr("Stop"); error=true)
    end
    global function autorefresh()
        stoptask = false
        task[] = errormonitor(
            Threads.@spawn while !stoptask
                SYNCSTATES[Int(IsAutoRefreshing)] && checkrefresh() && refresh1()
                sleep(0.01)
            end
        )
        monitortask[] = @async @trycatch mlstr("instrument autorefresh task failed!!!") while !stoptask
            if istaskfailed(task[])
                task[] = errormonitor(
                    Threads.@spawn while !stoptask
                        SYNCSTATES[Int(IsAutoRefreshing)] && checkrefresh() && refresh1()
                        sleep(0.01)
                    end
                )
            end
            sleep(0.1)
        end
    end
end

function checkrefresh()
    for (ins, inses) in INSTRBUFFERVIEWERS
        ins == "Others" && continue
        for ibv in values(inses)
            for qt in values(ibv.insbuf.quantities)
                qt.enable && qt.isautorefresh && time() - qt.lastrefresh > qt.refreshrate - 0.005 && return true
            end
        end
    end
    return false
end