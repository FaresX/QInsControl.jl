mutable struct LoopVector{T}
    data::Vector{T}
    index::Integer
    LoopVector{T}(::UndefInitializer, len) where {T} = new(Vector{T}(undef, len), 1)
    LoopVector(vec::Vector{T}) where {T} = new{T}(vec, 1)
end

Base.length(lv::LoopVector) = length(lv.data)
function __find_index(lv::LoopVector, i)
    l = length(lv)
    r = (i + lv.index) % l |> abs
    return r == 0 ? l : r
end
Base.getindex(lv::LoopVector, i=0) = lv.data[__find_index(lv, i)]
Base.setindex!(lv::LoopVector, x, i=0) = (lv.data[__find_index(lv, i)] = x)

move!(lv::LoopVector, i=1) = (lv.index += i)

Base.push!(lv::LoopVector, x) = push!(lv.data, x)