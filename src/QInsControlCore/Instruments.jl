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
    timeoutw::Real = 0.3
    timeoutr::Real = 3
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
    timeoutw::Real = 0.3
    timeoutr::Real = 3
    querydelay::Real = 0
    termchar::Char = '\n'
    clearbuffer::Bool = true
end

@kwdef mutable struct TCPSocketInstrAttr <: InstrAttr
    idnfunc::String = "idn"
    timeoutw::Real = 0.3
    timeoutr::Real = 3
    querydelay::Real = 0
    termchar::Char = '\n'
    clearbuffer::Bool = true
end

@kwdef mutable struct VirtualInstrAttr <: InstrAttr
    idnfunc::String = "idn"
    timeoutw::Real = 0.3
    timeoutr::Real = 3
    querydelay::Real = 0
    termchar::Char = '\n'
    clearbuffer::Bool = true
end

@kwdef mutable struct ISOBUSInstrAttr{T<:InstrAttr} <: InstrAttr
    attr::T = T()
end

@kwdef mutable struct QICInstrAttr{T<:InstrAttr} <: InstrAttr
    attr::T = T()
end

function Base.getproperty(attr::Union{ISOBUSInstrAttr,QICInstrAttr}, name::Symbol)
    return name == :attr ? getfield(attr, :attr) : getproperty(getfield(attr, :attr), name)
end
function Base.setproperty!(attr::Union{ISOBUSInstrAttr,QICInstrAttr}, name::Symbol, value)
    return name == :attr ? setfield!(attr, :attr, value) : setfield!(attr.attr, name, value)
end

struct VISAInstr <: Instrument
    name::String
    addr::String
    handle::GenericInstrument
    connected::Ref{Bool}
    attr::VISAInstrAttr
end

"""SERIAL::port"""
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
    ip::Union{IPv4, IPv6}
    port::Int
    handle::TCPSocket
    connected::Ref{Bool}
    attr::TCPSocketInstrAttr
end

"""VIRTUAL::INFO"""
@kwdef struct VirtualInstr <: Instrument
    name::String = "VirtualInstr"
    addr::String = "VIRTUAL::ADDRESS"
    handle::Ref{Any} = nothing
    connected::Ref{Bool} = false
    attr::VirtualInstrAttr = VirtualInstrAttr()
end

"""rootaddr::ISOBUS::subaddr"""
mutable struct ISOBUSInstr{T<:Instrument} <: Instrument
    name::String
    addr::String
    rootaddr::String
    subaddr::Int
    handle::Lockable{T,ReentrantLock}
    connected::Ref{Bool}
    attr::ISOBUSInstrAttr
end

"""rootaddr::QIC::subaddr"""
mutable struct QICInstr{T<:Instrument} <: Instrument
    name::String
    addr::String
    rootaddr::String
    subaddr::String
    handle::Lockable{T,ReentrantLock}
    connected::Ref{Bool}
    attr::QICInstrAttr
end

const ROOTHANDLES = Dict{String,Lockable}()
const INSTRUMENTS = Dict{String,Lockable}()
"""
    instrument(addr)

generate an instrument with addr which automatically determines the type of this instrument.
"""
function instrument(name, addr)
    try
        if occursin("QIC", addr)
            strs = split(addr, "::QIC::")
            rootaddr = strs[1]
            subaddr = length(strs) == 2 ? strs[2] : join(strs[2:end], "::QIC::")
            handlelocked = get!(ROOTHANDLES, rootaddr, instrument(name, rootaddr))
            handle = @lock handlelocked handlelocked[]
            attr = QICInstrAttr(handle.attr)
            get!(INSTRUMENTS, addr, Lockable(QICInstr{typeof(handle)}(name, addr, rootaddr, subaddr, handlelocked, false, attr)))
        elseif occursin("ISOBUS", addr)
            strs = split(addr, "::ISOBUS::")
            rootaddr = strs[1]
            subaddr = parse(Int, strs[2])
            handlelocked = get!(ROOTHANDLES, rootaddr, instrument(name, rootaddr))
            handle = @lock handlelocked handlelocked[]
            attr = ISOBUSInstrAttr(handle.attr)
            get!(INSTRUMENTS, addr, Lockable(ISOBUSInstr{typeof(handle)}(name, addr, rootaddr, subaddr, handlelocked, false, attr)))
        elseif occursin("SERIAL", addr)
            _, portstr = split(addr, "::")
            attr = SerialInstrAttr()
            get!(INSTRUMENTS, addr, Lockable(SerialInstr(name, addr, portstr, SerialPort(portstr), false, attr)))
        elseif occursin("TCPSOCKET", addr)
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
            @assert !isnothing(ip) "ip $ipstr is not valid"
            attr = TCPSocketInstrAttr()
            get!(INSTRUMENTS, addr, Lockable(TCPSocketInstr(name, addr, ip, port, TCPSocket(), false, attr)))
        elseif occursin("VIRTUAL", split(addr, "::")[1])
            attr = VirtualInstrAttr()
            get!(INSTRUMENTS, addr, Lockable(VirtualInstr(name=name, addr=addr, attr=attr)))
        else
            attr = VISAInstrAttr()
            get!(INSTRUMENTS, addr, Lockable(VISAInstr(name, addr, GenericInstrument(), false, attr)))
        end
    catch e
        @error "address $addr is not valid" exception = e
        showbacktrace()
        get!(INSTRUMENTS, addr, Lockable(VirtualInstr(name=name, addr=addr)))
    end
end

function delete_instr(addr)
    if haskey(INSTRUMENTS, addr)
        instrlocked = pop!(INSTRUMENTS, addr)
        lock(instrlocked) do instr
            disconnect!(instr)
            if instr isa ISOBUSInstr || instr isa QICInstr
                hasanother = false
                for instrlocked in values(INSTRUMENTS)
                    lock(instrlocked) do ins
                        hasanother = (ins isa ISOBUSInstr || ins isa QICInstr) && instr.rootaddr == ins.rootaddr
                    end
                end
                hasanother || delete!(ROOTHANDLES, instr.rootaddr)
            end
        end
    end
end

function attrtodict(attr::Union{ISOBUSInstrAttr,QICInstrAttr})
    attrdict = Dict{String,Any}("attrtype" => split(split(string(typeof(attr)), '{')[1], '.')[end])
    attrdict["attr::InstrAttr"] = attrtodict(attr.attr)
    return attrdict
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

attrfromdict(attrdict) = haskey(attrdict, "attrtype") ? attrfromdict(eval(Symbol(attrdict["attrtype"])), attrdict) : nothing
function attrfromdict(type::Union{Type{ISOBUSInstrAttr},Type{QICInstrAttr}}, attrdict)
    attr = type(attrfromdict(attrdict["attr::InstrAttr"]))
    return attr
end
function attrfromdict(type, attrdict)
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
# end

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
connect!(rm, instr::ISOBUSInstr) = instr.connected[] = @lock instr.handle connect!(rm, instr.handle[])
connect!(rm, instr::QICInstr) = instr.connected[] = @lock instr.handle connect!(rm, instr.handle[])

"""
    disconnect!(instr)

disconnect the instrument.
"""
disconnect!(instr::VISAInstr) = (Instruments.disconnect!(instr.handle); instr.connected[] = instr.handle.connected)
function disconnect!(instr::Union{SerialInstr,TCPSocketInstr})
    if instr.connected[]
        close(instr.handle)
        instr.connected[] = false
    end
    return instr.connected[]
end
disconnect!(instr::VirtualInstr) = instr.connected[] = false
disconnect!(instr::ISOBUSInstr) = instr.connected[] = @lock instr.handle disconnect!(instr.handle[])
disconnect!(instr::QICInstr) = instr.connected[] = @lock instr.handle disconnect!(instr.handle[])

"""
    write(instr, msg)

write some message string to the instrument.
"""
Base.write(instr::VISAInstr, msg::AbstractString) = (instr.attr.async ? writeasync : Instruments.write)(instr.handle, string(msg, instr.attr.termchar))
Base.write(instr::Union{SerialInstr,TCPSocketInstr}, msg::AbstractString) = write(instr.handle, string(msg, instr.attr.termchar))
Base.write(::VirtualInstr, ::AbstractString) = nothing
Base.write(instr::ISOBUSInstr, msg::AbstractString) = @lock instr.handle write(instr.handle[], string("@", instr.subaddr, msg))
Base.write(instr::QICInstr, msg::AbstractString) = @lock instr.handle write(instr.handle[], string(instr.subaddr, ":Q:", msg, ":Q:W"))

"""
    read(instr)

read the instrument.
"""
Base.read(instr::VISAInstr) = (instr.attr.async ? readasync : Instruments.read)(instr.handle)
function Base.read(instr::Union{SerialInstr,TCPSocketInstr})
    t = @async readuntil(instr.handle, instr.attr.termchar)
    timedwhilefetch(t, instr.attr.timeoutr; msg="read $(instr.addr) timeout", throwerror=true)
end
Base.read(::VirtualInstr) = "read"
Base.read(instr::ISOBUSInstr) = @lock instr.handle read(instr.handle[])
function Base.read(instr::QICInstr)
    lock(instr.handle) do handle
        write(handle, string(instr.subaddr, ":Q::Q:R"))
        yield()
        read(handle)
    end
end

"""
    query(instr, msg; delay=0)

query the instrument with some message string.
"""
function _query_(instr::Instrument, msg::AbstractString)
    write(instr, msg)
    sleep(instr.attr.querydelay)
    read(instr)
end
function query(instr::VISAInstr, msg::AbstractString)
    instr.attr.async ? queryasync(instr.handle, msg; delay=instr.attr.querydelay) : _query_(instr, msg)
end
query(instr::SerialInstr, msg::AbstractString) = _query_(instr, msg)
query(instr::TCPSocketInstr, msg::AbstractString) = _query_(instr, msg)
query(::VirtualInstr, ::AbstractString) = "query"
function query(instr::ISOBUSInstr, msg::AbstractString)
    lock(instr.handle) do handle
        write(handle, string("@", instr.subaddr, msg))
        sleep(instr.attr.querydelay)
        read(handle)
    end
end
function query(instr::QICInstr, msg::AbstractString)
    lock(instr.handle) do handle
        write(handle, string(instr.subaddr, ":Q:", msg, ":Q:Q"))
        sleep(instr.attr.querydelay)
        read(handle)
    end
end

"""
    isconnected(instr)

determine if the instrument is connected.
"""
isconnected(instr) = instr.connected[]

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
            @lock instr.handle read(instr.handle[])
        catch
            break
        end
        yield()
    end
end

idn(instr) = query(instr, "*IDN?")

idn_get(instr) = eval(Symbol(instr.attr.idnfunc))(instr)