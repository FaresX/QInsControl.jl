const RECORDTASKS = Tuple{String, Task}[]

macro async_record(name, ex)
    return esc(
        quote
            task = @async $(ex)
            push!(RECORDTASKS, ($name, task))
            task
        end
    )
end

macro spawn_record(name, ex)
    return esc(
        quote
            task = Threads.@spawn $(ex)
            push!(RECORDTASKS, ($name, task))
            task
        end
    )
end