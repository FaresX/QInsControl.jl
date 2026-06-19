@enum StatesIndex begin
    AutoDetecting = 1
    AutoDetectDone
    AutoRefreshing
    NewVersion
    FatalError
    InValidFile
end
Base.getindex(x::AbstractVector{Bool}, i::StatesIndex) = x[Int(i)]
Base.setindex!(x::AbstractVector{Bool}, v::Bool, i::StatesIndex) = x[Int(i)] = v

const STATES = Lockable(fill(false, length(instances(StatesIndex))))

Base.getindex(x::Lockable{Vector{Bool},ReentrantLock}, i::StatesIndex) = lock(x -> x[i], x)
Base.setindex!(x::Lockable{Vector{Bool},ReentrantLock}, v::Bool, i::StatesIndex) = lock(x -> x[i] = v, x)
