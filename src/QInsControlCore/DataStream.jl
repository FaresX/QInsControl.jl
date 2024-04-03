"""
    Controller(instrnm, addr)

construct a Controller to send commands to the instrument determined by (instrnm, addr). A Controller has three ways to
send commands to the Processor: wirte read query.
```julia
julia> ct(write, cpu, "*IDN?", Val(:write))
"done"

julia> ct(read, cpu, Val(:read))
"read"

julia> ct(query, cpu, "*IDN?", Val(:query))
"query"
```

the commands needed to execute is not necessary to be wirte, read or query.

```julia
julia> idn_get(instr) = query(instr, "*IDN?")
idn_get (generic function with 1 method)

julia> ct(idn_get, cpu, Val(:read))
"query"
```
the definition of function idn_get must happen before the Controller ct is logged in or one can log out and log in again.
"""
struct Controller
    instrnm::String
    addr::String
    databuf::Vector{String}
    available::Vector{Bool}
    ready::Vector{Bool}
    Controller(instrnm, addr; buflen=16) = new(instrnm, addr, fill("", buflen), trues(buflen), falses(buflen))
end
function Base.show(io::IO, ct::Controller)
    str = """
       instrnm : $(ct.instrnm)
       address : $(ct.addr)
        buffer : $(ct.databuf[])
    """
    print(io, str)
end

"""
    Processor()

construct a Processor to deal with the commands sended into by Controllers.
"""
struct Processor
    controllers::Vector{Controller}
    cmdchannel::Vector{Tuple{Controller,Int,Function,String,Val}}
    exechannels::Dict{String,Vector{Tuple{Controller,Int,Function,String,Val}}}
    processtask::Ref{Task}
    tasks::Dict{String,Task}
    taskhandlers::Dict{String,Bool}
    resourcemanager::Ref{UInt32}
    instrs::Dict{String,Instrument}
    running::Ref{Bool}
    fast::Ref{Bool}
    Processor() = new([], [], Dict(), Ref{Task}(), Dict(), Dict(), 0, Dict(), false, false)
end
function Base.show(io::IO, cpu::Processor)
    str1 = """
           running : $(cpu.running[])
              mode : $(cpu.fast[] ? "fast" : "slow")
   ResourceManager : $(cpu.resourcemanager[])
       controllers :
    """
    print(io, str1)
    for ct in cpu.controllers
        print(io, "\t\t\tController\n")
        ct_strs = split(string(ct), '\n')[1:end-1]
        print(io, string(join(fill("\t\t", 4) .* ct_strs, "\n"), "\n\n"))
    end
    str2 = """
              tasks : 
    """
    print(io, str2)
    for (addr, state) in cpu.taskhandlers
        l = length(addr)
        if l < 26
            print(io, string(" "^(26 - length(addr)), addr, " : ", state))
        else
            print(io, string(addr, " : ", state))
        end
    end
end

"""
    find_resources(cpu::Processor)

auto-detect available instruments.
"""
find_resources(cpu::Processor) = Instruments.find_resources(cpu.resourcemanager[])

"""
    login!(cpu::Processor, ct::Controller)

log the Controller in the Processor which can be done before and after the cpu started.
"""
function login!(cpu::Processor, ct::Controller; quiet=true)
    ct in cpu.controllers || push!(cpu.controllers, ct)
    if cpu.running[]
        if !haskey(cpu.instrs, ct.addr)
            push!(cpu.instrs, ct.addr => instrument(ct.instrnm, ct.addr))
            push!(cpu.exechannels, ct.addr => [])
            push!(cpu.taskhandlers, ct.addr => true)
            push!(
                cpu.tasks, ct.addr => errormonitor(
                    @async while cpu.taskhandlers[ct.addr]
                        if isempty(cpu.exechannels[ct.addr])
                            cpu.fast[] ? yield() : sleep(0.001)
                        else
                            runcmd(cpu, popfirst!(cpu.exechannels[ct.addr])...)
                        end
                    end
                )
            )
            connect!(cpu.resourcemanager[], cpu.instrs[ct.addr])
        end
    else
        haskey(cpu.instrs, ct.addr) || push!(cpu.instrs, ct.addr => instrument(ct.instrnm, ct.addr))
    end
    quiet || @info "[$(now())]\ncontroller $(findfirst(==(ct), cpu.controllers)) has logged in"
    return nothing
end

"""
    logout!(cpu::Processor, ct::Controller)

log the Controller out the Processor.

    logout!(cpu::Processor, addr::String)

log all the Controllers that control the instrument with address addr out the Processor.
"""
function logout!(cpu::Processor, ct::Controller; quiet=true)
    if ct in cpu.controllers
        if ct.addr ∉ [ct.addr for ct in cpu.controllers]
            popinstr = pop!(cpu.instrs, ct.addr)
            if cpu.running[]
                cpu.taskhandlers[popinstr.addr] = false
                try
                    haskey(cpu.tasks, popinstr.addr) && wait(cpu.tasks[popinstr.addr])
                catch e
                    @error "[$(now())]\nan error occurs during logging out" exception = e
                end
                delete!(cpu.taskhandlers, popinstr.addr)
                delete!(cpu.tasks, popinstr.addr)
                delete!(cpu.exechannels, popinstr.addr)
                disconnect!(popinstr)
            end
        end
        idx = findfirst(==(ct), cpu.controllers)
        deleteat!(cpu.controllers, idx)
        quiet || @info "[$(now())]\ncontroller $idx has logged out"
    end
    return nothing
end
function logout!(cpu::Processor, addr::String; quiet=true)
    for ct in cpu.controllers
        ct.addr == addr && logout!(cpu, ct; quiet=quiet)
    end
end

function timedwhile(f::Function, timeout::Real)
    t = time()
    while time() - t < timeout
        f() && return true
        yield()
    end
    return false
end
function (ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:write}; timeout=6)
    @assert ct in cpu.controllers "[$(now())]\nController is not logged in"
    @assert cpu.running[] "[$(now())]\nProcessor is not running"
    availi = Ref{Int}(0)
    isok = timedwhile(timeout) do
        for (i, avail) in enumerate(ct.available)
            avail && (ct.available[i] = false; availi[] = i; return true)
        end
        return false
    end
    isok || error("[$(now())]\ntimeout without available buffer")
    i = availi[] 
    ct.ready[i] = false
    push!(cpu.cmdchannel, (ct, i, f, val, Val(:write)))
    isok = timedwhile(() -> ct.ready[i], timeout)
    ct.available[i] = true
    return isok ? ct.databuf[i] : error("[$(now())]\ntimeout")
end
function (ct::Controller)(f::Function, cpu::Processor, ::Val{:read}; timeout=6)
    @assert ct in cpu.controllers "[$(now())]\nController is not logged in"
    @assert cpu.running[] "[$(now())]\nProcessor is not running"
    availi = Ref{Int}(0)
    isok = timedwhile(timeout) do
        for (i, avail) in enumerate(ct.available)
            avail && (ct.available[i] = false; availi[] = i; return true)
        end
        return false
    end
    isok || error("[$(now())]\ntimeout without available buffer")
    i = availi[] 
    ct.ready[i] = false
    push!(cpu.cmdchannel, (ct, i, f, "", Val(:read)))
    isok = timedwhile(() -> ct.ready[i], timeout)
    ct.available[i] = true
    return isok ? ct.databuf[i] : error("[$(now())]\ntimeout")
end
function (ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:query}; timeout=6)
    @assert ct in cpu.controllers "[$(now())]\nController is not logged in"
    @assert cpu.running[] "[$(now())]\nProcessor is not running"
    availi = Ref{Int}(0)
    isok = timedwhile(timeout) do
        for (i, avail) in enumerate(ct.available)
            avail && (ct.available[i] = false; availi[] = i; return true)
        end
        return false
    end
    isok || error("[$(now())]\ntimeout without available buffer")
    i = availi[] 
    ct.ready[i] = false
    push!(cpu.cmdchannel, (ct, i, f, val, Val(:query)))
    isok = timedwhile(() -> ct.ready[i], timeout)
    ct.available[i] = true
    return isok ? ct.databuf[i] : error("[$(now())]\ntimeout")
end

function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, val::String, ::Val{:write})
    f(cpu.instrs[ct.addr], val)
    ct.ready[i] = true
    return nothing
end
function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, ::String, ::Val{:read})
    ct.databuf[i] = f(cpu.instrs[ct.addr])
    ct.ready[i] = true
    return nothing
end
function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, val::String, ::Val{:query})
    ct.databuf[i] = f(cpu.instrs[ct.addr], val)
    ct.ready[i] = true
    return nothing
end

function init!(cpu::Processor)
    if !cpu.running[]
        cpu.fast[] = false
        empty!(cpu.cmdchannel)
        empty!(cpu.exechannels)
        empty!(cpu.tasks)
        empty!(cpu.taskhandlers)
        cpu.resourcemanager[] = try
            ResourceManager()
        catch e
            @error "[$(now())]\ncreating resourcemanager failed!!!" exception = e
            1
        end
        for (addr, instr) in cpu.instrs
            try
                connect!(cpu.resourcemanager[], instr)
            catch e
                @error "[$(now())]\nconnecting to $addr failed" exception = e
            end
            push!(cpu.exechannels, addr => [])
            push!(cpu.taskhandlers, addr => false)
        end
        cpu.running[] = false
    end
    return nothing
end

function run!(cpu::Processor)
    if !cpu.running[]
        cpu.running[] = true
        cpu.processtask[] = errormonitor(
            @async while cpu.running[]
                if isempty(cpu.cmdchannel)
                    cpu.fast[] ? yield() : sleep(0.001)
                else
                    cmd = popfirst!(cpu.cmdchannel)
                    push!(cpu.exechannels[cmd[1].addr], cmd)
                end
            end
        )
        for (addr, exec) in cpu.exechannels
            cpu.taskhandlers[addr] = true
            t = @async while cpu.taskhandlers[addr]
                isempty(exec) ? (cpu.fast[] ? yield() : sleep(0.001)) : runcmd(cpu, popfirst!(exec)...)
            end
            @info "[$(now())]\ntask(address: $addr) has been created"
            push!(cpu.tasks, addr => errormonitor(t))
        end
        errormonitor(
            @async while cpu.running[]
                try
                    if istaskfailed(cpu.processtask[])
                        @warn "[$(now())]\nprocessing task failed, recreating..."
                        cpu.processtask[] = errormonitor(
                            @async while cpu.running[]
                                if isempty(cpu.cmdchannel)
                                    cpu.fast[] ? yield() : sleep(0.001)
                                else
                                    cmd = popfirst!(cpu.cmdchannel)
                                    push!(cpu.exechannels[cmd[1].addr], cmd)
                                end
                            end
                        )
                        @info "[$(now())]\nprocessing task has been recreated"
                    end
                    for (addr, t) in cpu.tasks
                        if istaskfailed(t) && haskey(cpu.exechannels, addr) && haskey(cpu.taskhandlers, addr)
                            @warn "[$(now())]\ntask(address: $addr) failed, recreating..."
                            push!(
                                cpu.tasks,
                                addr => errormonitor(
                                    @async while cpu.taskhandlers[addr]
                                        if isempty(cpu.exechannels[addr])
                                            cpu.fast[] ? yield() : sleep(0.001)
                                        else
                                            runcmd(cpu, popfirst!(cpu.exechannels[addr])...)
                                        end
                                    end
                                )
                            )
                            @info "[$(now())]\ntask(address: $addr) has been recreated"
                        end
                    end
                catch e
                    @error "[$(now())]\nan error occurs during task monitoring"
                end
                sleep(0.01)
            end
        )
    end
    return nothing
end

"""
    stop!(cpu::Processor)

stop the Processor.
"""
function stop!(cpu::Processor)
    if cpu.running[]
        cpu.running[] = false
        cpu.fast[] = false
        for addr in keys(cpu.taskhandlers)
            cpu.taskhandlers[addr] = false
        end
        for t in values(cpu.tasks)
            try
                wait(t)
            catch e
                @error "[$(now())]\nan error occurs during stopping Processor:\n$cpu" exception = e
            end
        end
        for instr in values(cpu.instrs)
            disconnect!(instr)
        end
        empty!(cpu.controllers)
        empty!(cpu.cmdchannel)
        empty!(cpu.exechannels)
        empty!(cpu.taskhandlers)
        empty!(cpu.tasks)
        empty!(cpu.instrs)
    end
    return nothing
end

"""
    start!(cpu::Processor)

start the Processor.
"""
start!(cpu::Processor) = (init!(cpu); run!(cpu))

"""
    reconnect!(cpu::Processor)

reconnect the instruments that log in the Processor.
"""
reconnect!(cpu::Processor) = connect!.(cpu.resourcemanager[], values(cpu.instrs))

"""
    slow!(cpu::Processor)

change the cpu mode to slow mode. Default mode is slow mode, which decrease the cpu cost.
"""
slow!(cpu::Processor) = cpu.fast[] = false

"""
    fast!(cpu::Processor)

change the cpu mode to fast mode. Default mode is slow mode. The fast mode is not necessary in most cases.
"""
fast!(cpu::Processor) = cpu.fast[] = true