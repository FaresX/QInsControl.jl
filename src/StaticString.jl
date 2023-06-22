mutable struct StaticString
    str::String
    update::Bool
end

const STATICSTRINGS = Dict{Tuple,StaticString}()

function stcstr(args...)
    haskey(STATICSTRINGS, (args...,)) || push!(STATICSTRINGS, (args...,) => StaticString(string(args...), true))
    ss = STATICSTRINGS[(args...,)]
    ss.update = true
    return ss.str
end

function checklifetime()
    for (key, ss) in STATICSTRINGS
        ss.update ? (ss.update = false) : delete!(STATICSTRINGS, key)
    end
end