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
    busytimeout::Float64
    Controller(instrnm, addr; buflen=16, busytimeout=54) = new(
        instrnm, addr, fill("", buflen), trues(buflen), falses(buflen), busytimeout
    )
end
function Base.show(io::IO, ct::Controller)
    str = """
       instrnm : $(ct.instrnm)
       address : $(ct.addr)
        buffer : $(ct.databuf)
    """
    print(io, str)
end

"""
    Processor()

construct a Processor to deal with the commands sended into by Controllers.
"""
struct Processor
    lock::ReentrantLock
    controllers::Vector{Controller}
    cmdchannel::Vector{Tuple{Controller,Int,Function,String,Val}}
    exechannels::Dict{String,Vector{Tuple{Controller,Int,Function,String,Val}}}
    processtask::Ref{Task}
    tasks::Dict{String,Task}
    taskhandlers::Dict{String,Bool}
    taskbusy::Dict{String,Bool}
    resourcemanager::Ref{UInt32}
    instrs::Dict{String,Lockable}
    running::Ref{Bool}
    fast::Ref{Bool}
    Processor() = new(ReentrantLock(), [], [], Dict(), Ref{Task}(), Dict(), Dict(), Dict(), 0, Dict(), false, false)
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
        print(io, ct)
        # ct_strs = split(string(ct), '\n')[1:end-1]
        # print(io, string(join(fill("\t\t", 4) .* ct_strs, "\n"), "\n\n"))
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

function lockinstr(f, cpu::Processor, addr, args...)
    lock(cpu.lock) do
        lock(cpu.instrs[addr]) do instr
            f(instr, args...)
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
function login!(cpu::Processor, ct::Controller; attrlist=Dict(), quiet=true)
    lock(cpu.lock) do
        if ct ∉ cpu.controllers
            if !haskey(cpu.instrs, ct.addr)
                instrlocked = instrument(ct.instrnm, ct.addr)
                lock(instrlocked) do instr
                    deepcopy!(instr.attr, getattr(ct.addr, attrlist; delete=false))
                    if cpu.running[]
                        try
                            connect!(cpu.resourcemanager[], instr)
                        catch e
                            @error "an error occurs during connecting" exception = e
                        end
                        cpu.exechannels[ct.addr] = []
                        cpu.taskhandlers[ct.addr] = true
                        cpu.taskbusy[ct.addr] = false
                        cpu.tasks[ct.addr] = monitorinstr(cpu, ct.addr)
                        cpu.instrs[ct.addr] = instrlocked
                    end
                end
            end
            push!(cpu.controllers, ct)
            quiet || @info "controller $(findfirst(==(ct), cpu.controllers)) has logged in"
        end
    end
end

"""
    logout!(cpu::Processor, ct::Controller)

log the Controller out the Processor.

    logout!(cpu::Processor, addr::String)

log all the Controllers that control the instrument with address addr out the Processor.
"""
function logout!(cpu::Processor, ct::Controller; quiet=true)
    lock(cpu.lock) do
        if ct in cpu.controllers
            ct.instrnm == "" && ct.addr ∉ [c.addr for c in cpu.controllers if c != ct] && rminstr!(cpu, ct.addr)
            idx = findfirst(==(ct), cpu.controllers)
            deleteat!(cpu.controllers, idx)
            quiet || @info "controller $idx has logged out"
        end
    end
end
function logout!(cpu::Processor, addr::String; quiet=true)
    lock(cpu.lock) do
        for ct in cpu.controllers
            ct.addr == addr && logout!(cpu, ct; quiet=quiet)
        end
        if haskey(cpu.instrs, addr)
            rminstr!(cpu, addr)
            @warn "instrument $(addr) has been logged out"
        end
    end
end

function rminstr!(cpu::Processor, addr::String)
    lock(cpu.instrs[addr]) do instr
        if cpu.running[]
            cpu.taskhandlers[addr] = false
            haskey(cpu.tasks, addr) && timedwhilefetch(
                cpu.tasks[addr], 6; msg="force to stop task for $(addr)"
            )
            delete!(cpu.taskbusy, addr)
            delete!(cpu.taskhandlers, addr)
            delete!(cpu.tasks, addr)
            delete!(cpu.exechannels, addr)
            disconnect!(instr)
            pop!(cpu.instrs, addr)
            delete_instr(addr)
        end
    end
end

function (ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:write}; timeout=1)
    @assert ct in cpu.controllers "Controller is not logged in"
    @assert cpu.running[] "Processor is not running"
    availi = Ref{Int}(0)
    isok = timedwhile(timeout) do
        for (i, avail) in enumerate(ct.available)
            avail && (ct.available[i] = false; availi[] = i; return true)
        end
        return false
    end
    isok || error("timeout without available buffer")
    i = availi[]
    ct.ready[i] = false
    push!(cpu.cmdchannel, (ct, i, f, val, Val(:write)))
    timedwhile(() -> !cpu.taskbusy[ct.addr], ct.busytimeout)
    isok = timedwhile(() -> ct.ready[i], timeout)
    ct.available[i] = true
    return isok ? ct.databuf[i] : error("write timeout with ($f, $val)")
end
function (ct::Controller)(f::Function, cpu::Processor, ::Val{:read}; timeout=1)
    @assert ct in cpu.controllers "Controller is not logged in"
    @assert cpu.running[] "Processor is not running"
    availi = Ref{Int}(0)
    isok = timedwhile(timeout) do
        for (i, avail) in enumerate(ct.available)
            avail && (ct.available[i] = false; availi[] = i; return true)
        end
        return false
    end
    isok || error("timeout without available buffer")
    i = availi[]
    ct.ready[i] = false
    push!(cpu.cmdchannel, (ct, i, f, "", Val(:read)))
    timedwhile(() -> !cpu.taskbusy[ct.addr], ct.busytimeout)
    isok = timedwhile(() -> ct.ready[i], timeout)
    ct.available[i] = true
    return isok ? ct.databuf[i] : error("read timeout with $f")
end
function (ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:query}; timeout=1)
    @assert ct in cpu.controllers "Controller is not logged in"
    @assert cpu.running[] "Processor is not running"
    availi = Ref{Int}(0)
    isok = timedwhile(timeout) do
        for (i, avail) in enumerate(ct.available)
            avail && (ct.available[i] = false; availi[] = i; return true)
        end
        return false
    end
    isok || error("timeout without available buffer")
    i = availi[]
    ct.ready[i] = false
    push!(cpu.cmdchannel, (ct, i, f, val, Val(:query)))
    timedwhile(() -> !cpu.taskbusy[ct.addr], ct.busytimeout)
    isok = timedwhile(() -> ct.ready[i], timeout)
    ct.available[i] = true
    return isok ? ct.databuf[i] : error("query timeout with ($f, $val)")
end

function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, val::String, ::Val{:write})
    wait(Threads.@spawn lockinstr(instr -> f(instr, val), cpu, ct.addr))
    ct.ready[i] = true
end
function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, ::String, ::Val{:read})
    ct.databuf[i] = fetch(Threads.@spawn lockinstr(instr -> f(instr), cpu, ct.addr))
    ct.ready[i] = true
end
function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, val::String, ::Val{:query})
    ct.databuf[i] = fetch(Threads.@spawn lockinstr(instr -> f(instr, val), cpu, ct.addr))
    ct.ready[i] = true
end

function init!(cpu::Processor)
    if !cpu.running[]
        cpu.fast[] = false
        empty!(cpu.cmdchannel)
        empty!(cpu.exechannels)
        empty!(cpu.tasks)
        empty!(cpu.taskhandlers)
        empty!(cpu.taskbusy)
        cpu.resourcemanager[] = try
            ResourceManager()
        catch e
            @error "creating resourcemanager failed!!!" exception = e
            1
        end
        for (addr, instrlocked) in cpu.instrs
            try
                lock(instr -> connect!(cpu.resourcemanager[], instr), instrlocked)
            catch e
                @error "connecting to $addr failed" exception = e
            end
            cpu.exechannels[addr] = []
            cpu.taskhandlers[addr] = false
            cpu.taskbusy[addr] = false
        end
        cpu.running[] = false
    end
    return nothing
end

function run!(cpu::Processor)
    if !cpu.running[]
        cpu.running[] = true
        cpu.processtask[] = errormonitor(
            @async_record "processing task" while cpu.running[]
                if isempty(cpu.cmdchannel)
                    cpu.fast[] ? yield() : sleep(0.001)
                else
                    cmd = popfirst!(cpu.cmdchannel)
                    push!(cpu.exechannels[cmd[1].addr], cmd)
                end
            end
        )
        for addr in keys(cpu.exechannels)
            cpu.taskhandlers[addr] = true
            cpu.taskbusy[addr] = false
            t = monitorinstr(cpu, addr)
            @info "task(address: $addr) has been created"
            cpu.tasks[addr] = errormonitor(t)
        end
        errormonitor(
            @async_record "monitor processing task" while cpu.running[]
                try
                    if istaskfailed(cpu.processtask[])
                        @warn "processing task failed, recreating..."
                        cpu.processtask[] = errormonitor(
                            @async_record "processing task" while cpu.running[]
                                if isempty(cpu.cmdchannel)
                                    cpu.fast[] ? yield() : sleep(0.001)
                                else
                                    cmd = popfirst!(cpu.cmdchannel)
                                    push!(cpu.exechannels[cmd[1].addr], cmd)
                                end
                            end
                        )
                        @info "processing task has been recreated"
                    end
                    for (addr, t) in cpu.tasks
                        if istaskfailed(t) && haskey(cpu.exechannels, addr) && haskey(cpu.taskhandlers, addr)
                            setbusy!(cpu, addr)
                            @warn "task(address: $addr) failed, clearing buffer and recreating..."
                            lock(cpu.instrs[addr]) do instr
                                instr.attr.clearbuffer && clearbuffer(instr)
                            end
                            cpu.tasks[addr] = monitorinstr(cpu, addr)
                            @info "task(address: $addr) has been recreated"
                            unsetbusy!(cpu, addr)
                        end
                    end
                catch e
                    @error "an error occurs during task monitoring"
                end
                sleep(0.01)
            end
        )
    end
    return nothing
end

function monitorinstr(cpu::Processor, addr::String)
    errormonitor(
        @async_record "monitor task $(addr)" while cpu.taskhandlers[addr]
            if isempty(cpu.exechannels[addr]) || cpu.taskbusy[addr]
                cpu.fast[] ? yield() : sleep(0.001)
            else
                runcmd(cpu, popfirst!(cpu.exechannels[addr])...)
            end
        end
    )
end

"""
    stop!(cpu::Processor)

stop the Processor.
"""
function stop!(cpu::Processor)
    if cpu.running[]
        for addr in keys(cpu.taskhandlers)
            cpu.taskbusy[addr] = false
            cpu.taskhandlers[addr] = false
        end
        for t in values(cpu.tasks)
            timedwhilefetch(t, 6)
        end
        cpu.running[] = false
        cpu.fast[] = false
        timedwhilefetch(cpu.processtask[], 6; msg="force to stop processing task")
        for instrlocked in values(cpu.instrs)
            lock(disconnect!, instrlocked)
        end
        empty!(cpu.controllers)
        empty!(cpu.cmdchannel)
        empty!(cpu.exechannels)
        empty!(cpu.taskhandlers)
        empty!(cpu.taskbusy)
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
function reconnect!(cpu::Processor, addr::String)
    if haskey(cpu.instrs, addr)
        lock(cpu.instrs[addr]) do instr
            disconnect!(instr)
            connect!(cpu.resourcemanager[], instr)
        end
    end
end
reconnect!(cpu::Processor) = map(addr -> reconnect!(cpu, addr), collect(keys(cpu.instrs)))

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

setbusy!(cpu::Processor, addr::String) = haskey(cpu.taskbusy, addr) && (cpu.taskbusy[addr] = true; @warn "set busy for $addr")
unsetbusy!(cpu::Processor, addr::String) = haskey(cpu.taskbusy, addr) && (cpu.taskbusy[addr] = false; @info "unset busy for $addr")
setbusy!(cpu::Processor) = map(addr -> setbusy!(cpu, addr), collect(keys(cpu.taskbusy)))
unsetbusy!(cpu::Processor) = map(addr -> unsetbusy!(cpu, addr), collect(keys(cpu.taskbusy)))
isbusy(cpu::Processor, addr::String) = haskey(cpu.taskbusy, addr) && cpu.taskbusy[addr]