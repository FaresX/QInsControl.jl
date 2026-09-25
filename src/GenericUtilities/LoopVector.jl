mutable struct LoopVector{T}
    data::Vector{T}
    index::Integer
    LoopVector{T}(::UndefInitializer, len) where {T} = new(Vector{T}(undef, len), 1)
    LoopVector(vec::Vector{T}) where {T} = new{T}(vec, 1)
end

Base.length(lv::LoopVector) = length(lv.data)
function __find_index(lv::LoopVector, i)
    l = length(lv)
    #必须用 mod:%/rem 是截断取余(符号随被除数),abs(rem(x,l)) 在 x<0 时给出镜像索引而非回绕
    r = mod(i + lv.index, l)
    return r == 0 ? l : r
end
Base.getindex(lv::LoopVector, i=0) = lv.data[__find_index(lv, i)]
Base.setindex!(lv::LoopVector, x, i=0) = (lv.data[__find_index(lv, i)] = x)

move!(lv::LoopVector, i=1) = (lv.index += i)

Base.push!(lv::LoopVector, x) = push!(lv.data, x)