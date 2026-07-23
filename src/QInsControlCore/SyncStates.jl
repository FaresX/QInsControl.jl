@enum SyncStatesIndex begin
    IsDAQTaskRunning = 1
    IsDAQTaskDone
    IsInterrupted
    IsBlocked
    IsRefreshing
    IsLogging
    IsNewLogging
    IsNewFile
end
Base.getindex(x::AbstractVector{Bool}, i::SyncStatesIndex) = x[Int(i)]
Base.setindex!(x::AbstractVector{Bool}, v::Bool, i::SyncStatesIndex) = x[Int(i)] = v

global SYNCSTATES::Lockable{SharedVector{Bool},ReentrantLock} = Lockable(SharedVector{Bool}(length(instances(SyncStatesIndex))))

Base.getindex(x::Lockable{SharedVector{Bool},ReentrantLock}, i::SyncStatesIndex) = lock(x -> x[i], x)
Base.setindex!(x::Lockable{SharedVector{Bool},ReentrantLock}, v::Bool, i::SyncStatesIndex) = lock(x -> x[i] = v, x)
