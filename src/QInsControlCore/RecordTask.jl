const RECORDTASKS = Tuple{String,Task}[]
const RECORDTASKSLOCK = ReentrantLock() #任务创建可来自多线程,push 需持锁,迭代侧用 collect 快照

macro async_record(name, ex)
    return esc(
        quote
            task = @async $(ex)
            lock(() -> push!(RECORDTASKS, ($name, task)), RECORDTASKSLOCK)
            task
        end
    )
end

macro spawn_record(name, ex)
    return esc(
        quote
            task = Threads.@spawn $(ex)
            lock(() -> push!(RECORDTASKS, ($name, task)), RECORDTASKSLOCK)
            task
        end
    )
end