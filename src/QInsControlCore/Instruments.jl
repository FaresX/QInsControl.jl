abstract type Instrument end
abstract type InstrAttr end

@kwdef mutable struct VISAInstrAttr <: InstrAttr
    #ASRL
    baudrate::Integer = 9600
    ndatabits::Integer = 8
    parity::VI_ASRL_PAR = VI_ASRL_PAR_NONE
    nstopbits::VI_ASRL_STOP = VI_ASRL_STOP_ONE
    #Common
    async::Bool = false
    idnfunc::String = "idn"
    timeoutw::Real = 0.1
    timeoutr::Real = 1
    querydelay::Real = 0
    termchar::Char = '\n'
    clearbuffer::Bool = true
end

@kwdef mutable struct SerialInstrAttr <: InstrAttr
    baudrate::Integer = 9600
    mode::SPMode = SP_MODE_READ_WRITE
    ndatabits::Integer = 8
    parity::SPParity = SP_PARITY_NONE
    nstopbits::Integer = 1
    rts::SPrts = SP_RTS_OFF
    cts::SPcts = SP_CTS_IGNORE
    dtr::SPdtr = SP_DTR_OFF
    dsr::SPdsr = SP_DSR_IGNORE
    xonxoff::SPXonXoff = SP_XONXOFF_DISABLED
    idnfunc::String = "idn"
    timeoutw::Real = 0.1
    timeoutr::Real = 1
    querydelay::Real = 0
    termchar::Char = '\n'
    clearbuffer::Bool = true
end

@kwdef mutable struct TCPSocketInstrAttr <: InstrAttr
    idnfunc::String = "idn"
    timeoutw::Real = 0.1
    timeoutr::Real = 1
    querydelay::Real = 0
    termchar::Char = '\n'
    clearbuffer::Bool = true
end

@kwdef mutable struct VirtualInstrAttr <: InstrAttr
    idnfunc::String = "idn"
    timeoutw::Real = 0.1
    timeoutr::Real = 1
    querydelay::Real = 0
    termchar::Char = '\n'
    clearbuffer::Bool = true
end

struct VISAInstr <: Instrument
    name::String
    addr::String
    handle::GenericInstrument
    connected::Ref{Bool}
    attr::VISAInstrAttr
end

struct SerialInstr <: Instrument
    name::String
    addr::String
    port::String
    handle::SerialPort
    connected::Ref{Bool}
    attr::SerialInstrAttr
end

mutable struct TCPSocketInstr <: Instrument
    name::String
    addr::String
    ip::IPv4
    port::Int
    handle::TCPSocket
    connected::Ref{Bool}
    attr::TCPSocketInstrAttr
end

@kwdef struct VirtualInstr <: Instrument
    name::String = "VirtualInstr"
    addr::String = "VirtualAddress"
    handle::Ref{Any} = nothing
    connected::Ref{Bool} = false
    attr::VirtualInstrAttr = VirtualInstrAttr()
end

@kwdef mutable struct ISOBUSInstr{T<:Instrument} <: Instrument
    name::String
    addr::String
    rootaddr::String
    subaddr::Int
    handle::T
    connected::Ref{Bool}
    attr::InstrAttr
end

@kwdef mutable struct QICInstr{T<:Instrument} <: Instrument
    name::String
    addr::String
    rootaddr::String
    subaddr::String
    handle::T
    connected::Ref{Bool}
    attr::InstrAttr
end

const PROXYSTATES = Dict{String,Bool}()
const PROXYTIMEOUT = 6
macro proxy(instr, ex)
    esc(
        quote
            isok = timedwhile(PROXYTIMEOUT) do
                avail = PROXYSTATES[$instr.rootaddr]
                avail && (PROXYSTATES[$instr.rootaddr] = false)
                return avail
            end
            if isok
                result = try
                    $ex
                catch e
                    rethrow(e)
                finally
                    PROXYSTATES[$instr.rootaddr] = true
                end
                return result
            else
                error(string($instr.addr, " timeout"))
            end
        end
    )
end

"""
    instrument(name, addr)

generate an instrument with (name, addr) which automatically determines the type of this instrument.
"""
function instrument(name, addr; attr=VirtualInstrAttr())
    if occursin("QIC", addr)
        try
            strs = split(addr, "::QIC::")
            rootaddr = strs[1]
            subaddr = length(strs) == 2 ? strs[2] : join(strs[2:end], "::QIC::")
            instr = instrument(name, rootaddr; attr=attr)
            return QICInstr{typeof(instr)}(name, addr, rootaddr, subaddr, instr, false, instr.attr)
        catch e
            @error "address $addr is not valid" exception = e
            setattr = isnothing(attr) || !isa(attr, VISAInstrAttr) ? VISAInstrAttr() : attr
            return VISAInstr(name, addr, GenericInstrument(), false, setattr)
        end
    elseif occursin("ISOBUS", addr)
        try
            strs = split(addr, "::ISOBUS::")
            rootaddr = strs[1]
            subaddr = parse(Int, strs[2])
            instr = instrument(name, rootaddr; attr=attr)
            get!(PROXYSTATES, rootaddr, true)
            return ISOBUSInstr{typeof(instr)}(name, addr, rootaddr, subaddr, instr, false, instr.attr)
        catch e
            @error "address $addr is not valid" exception = e
            setattr = isnothing(attr) || !isa(attr, VISAInstrAttr) ? VISAInstrAttr() : attr
            return VISAInstr(name, addr, GenericInstrument(), false, setattr)
        end
    elseif occursin("SERIAL", addr)
        try
            _, portstr = split(addr, "::")
            setattr = isnothing(attr) || !isa(attr, SerialInstrAttr) ? SerialInstrAttr() : attr
            return SerialInstr(name, addr, portstr, SerialPort(portstr), false, setattr)
        catch e
            @error "address $addr is not valid" execption = e
            setattr = isnothing(attr) || !isa(attr, VISAInstrAttr) ? VISAInstrAttr() : attr
            return VISAInstr(name, addr, GenericInstrument(), false, setattr)
        end
    elseif occursin("TCPSOCKET", addr)
        try
            _, ipstr, portstr = split(addr, "::")
            port = parse(Int, portstr)
            ip = try
                IPv4(ipstr)
            catch
            end
            isnothing(ip) && (ip = try
                IPv6(ipstr)
            catch
            end)
            return if isnothing(ip)
                setattr = isnothing(attr) || !isa(attr, VISAInstrAttr) ? VISAInstrAttr() : attr
                VISAInstr(name, addr, GenericInstrument(), false, setattr)
            else
                setattr = isnothing(attr) || !isa(attr, TCPSocketInstrAttr) ? TCPSocketInstrAttr() : attr
                TCPSocketInstr(name, addr, ip, port, TCPSocket(), false, setattr)
            end
        catch e
            @error "address $addr is not valid" execption = e
            setattr = isnothing(attr) || !isa(attr, VISAInstrAttr) ? VISAInstrAttr() : attr
            return VISAInstr(name, addr, GenericInstrument(), false, setattr)
        end
    elseif name == "VirtualInstr"
        return VirtualInstr()
    elseif occursin("VIRTUAL", split(addr, "::")[1])
        setattr = isnothing(attr) || !isa(attr, VirtualInstrAttr) ? VirtualInstrAttr() : attr
        return VirtualInstr(name=split(addr, "::")[end], addr=addr, attr=setattr)
    else
        setattr = isnothing(attr) || !isa(attr, VISAInstrAttr) ? VISAInstrAttr() : attr
        return VISAInstr(name, addr, GenericInstrument(), false, setattr)
    end
end

"""
    connect!(rm, instr)

connect to an instrument with given ResourceManager rm.

    connect!(instr)

same but with auto-generated ResourceManager.
"""
function connect!(rm, instr::VISAInstr)
    if !instr.connected[]
        Instruments.connect!(rm, instr.handle, instr.addr)
        instr.connected[] = instr.handle.connected
        if occursin("ASRL", instr.addr)
            viSetAttribute(instr.handle.handle, Instruments.VI_ATTR_ASRL_BAUD, UInt(instr.attr.baudrate))
            viSetAttribute(instr.handle.handle, Instruments.VI_ATTR_ASRL_DATA_BITS, UInt(instr.attr.ndatabits))
            viSetAttribute(instr.handle.handle, Instruments.VI_ATTR_ASRL_PARITY, UInt(instr.attr.parity))
            viSetAttribute(instr.handle.handle, Instruments.VI_ATTR_ASRL_STOP_BITS, UInt(instr.attr.nstopbits))
            viSetAttribute(instr.handle.handle, Instruments.VI_ATTR_TERMCHAR, UInt(instr.attr.termchar))
        end
    end
    return instr.connected[]
end
function connect!(_, instr::SerialInstr)
    if !instr.connected[]
        LibSerialPort.open(instr.handle; mode=instr.attr.mode)
        instr.connected[] = true
        set_speed(instr.handle, instr.attr.baudrate)
        set_frame(instr.handle; ndatabits=instr.attr.ndatabits, parity=instr.attr.parity, nstopbits=instr.attr.nstopbits)
        set_flow_control(
            instr.handle;
            rts=instr.attr.rts, cts=instr.attr.cts, dtr=instr.attr.dtr, dsr=instr.attr.dsr, xonxoff=instr.attr.xonxoff
        )
        set_write_timeout(instr.handle, instr.attr.timeoutw)
        set_read_timeout(instr.handle, instr.attr.timeoutr)
    end
    return instr.connected[]
end
function connect!(_, instr::TCPSocketInstr)
    if !instr.connected[]
        instr.handle = connect(instr.ip, instr.port)
        instr.connected[] = true
    end
    return instr.connected[]
end
connect!(_, instr::VirtualInstr) = instr.connected[] = true
connect!(rm, instr::ISOBUSInstr) = instr.connected[] = connect!(rm, instr.handle)
connect!(rm, instr::QICInstr) = instr.connected[] = connect!(rm, instr.handle)

"""
    disconnect!(instr)

disconnect the instrument.
"""
function disconnect!(instr::Instrument)
    if instr.connected[]
        close(instr.handle)
        instr.connected[] = false
    end
    return instr.connected[]
end
disconnect!(instr::VISAInstr) = (Instruments.disconnect!(instr.handle); instr.connected[] = instr.handle.connected)
disconnect!(instr::VirtualInstr) = instr.connected[] = false
disconnect!(instr::ISOBUSInstr) = instr.connected[] = disconnect!(instr.handle)
disconnect!(instr::QICInstr) = instr.connected[] = disconnect!(instr.handle)

"""
    write(instr, msg)

write some message string to the instrument.
"""
Base.write(instr::Instrument, msg::AbstractString) = write(instr.handle, string(msg, instr.attr.termchar))
Base.write(instr::VISAInstr, msg::AbstractString) = (instr.attr.async ? writeasync : Instruments.write)(instr.handle, string(msg, instr.attr.termchar))
Base.write(::VirtualInstr, ::AbstractString) = nothing
Base.write(instr::ISOBUSInstr, msg::AbstractString) = @proxy instr write(instr.handle, string("@", instr.subaddr, msg))
Base.write(instr::QICInstr, msg::AbstractString) = write(instr.handle, string(instr.subaddr, ":Q:", msg, ":Q:W"))

"""
    read(instr)

read the instrument.
"""
function Base.read(instr::Instrument)
    t = @async readuntil(instr.handle, instr.attr.termchar)
    timedwhilefetch(t, instr.attr.timeoutr; msg="read $(instr.addr) timeout", throwerror=true)
end
Base.read(instr::VISAInstr) = (instr.attr.async ? readasync : Instruments.read)(instr.handle)
Base.read(::VirtualInstr) = "read"
Base.read(instr::ISOBUSInstr) = @proxy instr read(instr.handle)
function Base.read(instr::QICInstr)
    write(instr.handle, string(instr.subaddr, ":Q::Q:R"))
    yield()
    read(instr.handle)
end

"""
    query(instr, msg; delay=0)

query the instrument with some message string.
"""
function _query_(instr::Instrument, msg::AbstractString; delay=0)
    write(instr, msg)
    delay < 0.001 ? yield() : sleep(delay)
    read(instr)
end
function query(instr::VISAInstr, msg::AbstractString; delay=instr.attr.querydelay)
    instr.attr.async ? queryasync(instr.handle, msg; delay=delay) : _query_(instr, msg; delay=delay)
end
query(instr::SerialInstr, msg::AbstractString; delay=instr.attr.querydelay) = _query_(instr, msg; delay=delay)
query(instr::TCPSocketInstr, msg::AbstractString; delay=instr.attr.querydelay) = _query_(instr, msg; delay=delay)
query(::VirtualInstr, ::AbstractString; delay=0) = "query"
function query(instr::ISOBUSInstr, msg::AbstractString; delay=0)
    @proxy instr begin
        write(instr.handle, string("@", instr.subaddr, msg))
        delay < 0.001 ? yield() : sleep(delay)
        read(instr.handle)
    end
end
function query(instr::QICInstr, msg::AbstractString; delay=0)
    write(instr.handle, string(instr.subaddr, ":Q:", msg, ":Q:Q"))
    delay < 0.001 ? yield() : sleep(delay)
    read(instr.handle)
end

"""
    isconnected(instr)

determine if the instrument is connected.
"""
isconnected(instr::Instrument) = instr.connected[]

function clearbuffer(instr::Instrument)
    for _ in 1:6
        try
            read(instr)
        catch
            break
        end
        yield()
    end
end
function clearbuffer(instr::QICInstr)
    for _ in 1:6
        try
            read(instr.handle)
        catch
            break
        end
        yield()
    end
end

idn(instr) = query(instr, "*IDN?")