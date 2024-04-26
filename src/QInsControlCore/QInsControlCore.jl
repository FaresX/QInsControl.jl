module QInsControlCore
using BinDeps
using Instruments
using Instruments: viSetAttribute
using LibSerialPort
using Sockets
using UUIDs


export Controller, Processor
export login!, logout!, start!, stop!, reconnect!, find_resources, slow!, fast!
export instrument, connect!, disconnect!, write, read, query

function timedwhile(f::Function, timeout::Real)
    t = time()
    while time() - t < timeout
        f() && return true
        yield()
    end
    return false
end

include("VISA.jl")
include("constants.jl")
include("Instruments.jl")
include("DataStream.jl")
end # module QInsControlCore
