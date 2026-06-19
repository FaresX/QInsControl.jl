include("States.jl")
include("HelperFunctions.jl")
include("LoopVector.jl")
include("LockableDict.jl")
include("StaticString.jl")
include("FileInfo.jl")

function initialize_genericutilities!()
    empty!(STATICSTRINGS)
end