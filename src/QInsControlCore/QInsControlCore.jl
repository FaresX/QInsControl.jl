module QInsControlCore
using BinDeps
using Instruments
using Instruments: viSetAttribute
using LibSerialPort
using Sockets
using UUIDs

export VI_ASRL_PAR
export VI_ASRL_PAR_NONE, VI_ASRL_PAR_ODD, VI_ASRL_PAR_EVEN, VI_ASRL_PAR_MARK, VI_ASRL_PAR_SPACE
export VI_ASRL_STOP
export VI_ASRL_STOP_ONE, VI_ASRL_STOP_ONE5, VI_ASRL_STOP_TWO
export TERMCHARDICT, TERMCHARDICTINV

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
