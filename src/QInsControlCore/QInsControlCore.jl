module QInsControlCore
using BinDeps
using Distributed
using Dates
using Instruments
using Instruments: viSetAttribute
using LibSerialPort
using Logging
using SharedArrays
using Sockets
using Statistics
using TOML
using UUIDs
# import Base: Lockable
# export Lockable

export VI_ASRL_PAR
export VI_ASRL_PAR_NONE, VI_ASRL_PAR_ODD, VI_ASRL_PAR_EVEN, VI_ASRL_PAR_MARK, VI_ASRL_PAR_SPACE
export VI_ASRL_STOP
export VI_ASRL_STOP_ONE, VI_ASRL_STOP_ONE5, VI_ASRL_STOP_TWO
export TERMCHARDICT, TERMCHARDICTINV

export Controller, Processor
export login!, logout!, start!, stop!, reconnect!, find_resources, slow!, fast!, isbusy, setbusy!, unsetbusy!
export instrument, connect!, disconnect!, write, read, query, idn
export @trycatch, showbacktrace, gensweeplist
export mlstr, languageinfo, loadlanguage, initialize_qinscontrolcore!

export QICClient, QICServer

include("MultiLanguage.jl")
include("SyncStates.jl")
include("Utilities.jl")
include("VISA.jl")
include("constants.jl")
include("Instruments.jl")
include("DataStream.jl")
include("QICServer.jl")
include("Remote.jl")

function initialize_qinscontrolcore!(channelsize=64)
    empty!(MLSTRINGS)
    global REFRESHINRC = RemoteChannel(() -> Channel{Tuple{String,String,String,Cfloat}}(channelsize))
    global REFRESHOUTRC = RemoteChannel(() -> Channel{Tuple{String,String,String,String}}(channelsize))
    global DATABUFRC = RemoteChannel(() -> Channel{Vector{NTuple{2,String}}}(channelsize))
    global EXTRADATABUFRC = RemoteChannel(() -> Channel{Tuple{String,Vector{Any}}}(channelsize))
    global PROGRESSRC = RemoteChannel(() -> Channel{Vector{Tuple{UUID,Int,Int,Float64}}}(channelsize))
    global SYNCSTATES = Lockable(SharedVector{Bool}(length(instances(SyncStatesIndex))))
end

end # module QInsControlCore
