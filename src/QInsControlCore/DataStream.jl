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
    lock::ReentrantLock
    databuf::Vector{String}
    available::Vector{Bool}
    ready::Vector{Bool}
    busytimeout::Float64
    Controller(instrnm, addr; buflen=16, busytimeout=54) = new(
        instrnm, addr, ReentrantLock(), fill("", buflen), trues(buflen), falses(buflen), busytimeout
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
    #整段登录必须原子:原先"锁外判重 + 锁内 push!"会让并发的两个任务都判定未登录,
    #从而重复创建仪器、重复登记 controller(且 haskey(cpu.instrs) 也是无锁读)
    lock(cpu.lock) do
        ct in cpu.controllers && return
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
        push!(cpu.controllers, ct) #controllers 增删查都要持锁
        quiet || @info "controller $(findfirst(==(ct), cpu.controllers)) has logged in"
    end
end

"""
    logout!(cpu::Processor, ct::Controller)

log the Controller out the Processor.

    logout!(cpu::Processor, addr::String)

log all the Controllers that control the instrument with address addr out the Processor.
"""
function logout!(cpu::Processor, ct::Controller; quiet=true)
    idx = lock(() -> findfirst(==(ct), cpu.controllers), cpu.lock) #controllers 增删查都要持锁
    if idx !== nothing
        ct.instrnm == "" && lock(() -> ct.addr ∉ [c.addr for c in cpu.controllers if c != ct], cpu.lock) &&
            rminstr!(cpu, ct.addr)
        #删除前必须重新定位:查找与删除之间其它任务的 login!/logout! 会改动 controllers,
        #直接 deleteat!(idx) 会错位删掉另一个 controller
        lock(cpu.lock) do
            idxnow = findfirst(==(ct), cpu.controllers)
            idxnow === nothing || deleteat!(cpu.controllers, idxnow)
        end
        quiet || @info "controller $idx has logged out"
    end
end
function logout!(cpu::Processor, addr::String; quiet=true)
    for ct in lock(() -> collect(cpu.controllers), cpu.lock) #快照遍历:循环体里 logout!(cpu, ct) 会 deleteat! 本体
        ct.addr == addr && logout!(cpu, ct; quiet=quiet)
    end
    if haskey(cpu.instrs, addr)
        rminstr!(cpu, addr)
        @warn "instrument $(addr) has been logged out"
    end
end

function rminstr!(cpu::Processor, addr::String)
    haskey(cpu.instrs, addr) || return
    if cpu.running[]
        #停止标志与等待必须在 cpu.lock 之外:monitor 循环体要拿 cpu.lock 弹命令,
        #持锁等它退出会互相卡到 6s 强杀(与 stop! 是同坑,见 stop! 内注释)
        lock(cpu.lock) do
            haskey(cpu.taskhandlers, addr) && (cpu.taskhandlers[addr] = false)
        end
        task = lock(() -> get(cpu.tasks, addr, nothing), cpu.lock)
        task === nothing || timedwhilefetch(task, 6; msg="force to stop task for $(addr)")
    end
    lock(cpu.lock) do
        lock(cpu.instrs[addr]) do instr
            if cpu.running[]
                delete!(cpu.taskbusy, addr)
                delete!(cpu.taskhandlers, addr)
                delete!(cpu.tasks, addr)
                delete!(cpu.exechannels, addr)
                disconnect!(instr)
                pop!(cpu.instrs, addr)
            end
            delete_instr(addr)
        end
    end
end

"三个 (ct::Controller)(...) 入口的公共实现(write/read/query 仅差命令元组与错误文案):
抢占槽位 → 命令入队 → 等结果取回。超时即视为仪器故障(不再等迟到数据),槽位立即释放;
需要更长等待时应调大仪器驱动的 timeout 字段,而不是在此补偿"
function _ctrequest(f::Function, cpu::Processor, ct::Controller, val::String, mode::Val, timeout, errdesc)
    @assert ct in cpu.controllers "Controller is not logged in"
    @assert cpu.running[] "Processor is not running"
    availi = Ref{Int}(0)
    isok = timedwhile(timeout) do
        lock(ct.lock) do #并发调用必须原子地整段扫描抢占,否则会同抢一个槽位
            for (i, avail) in enumerate(ct.available)
                avail && (ct.available[i] = false; availi[] = i; return true)
            end
            return false
        end
    end
    isok || error("timeout without available buffer")
    i = availi[]
    lock(() -> ct.ready[i] = false, ct.lock)
    lock(() -> push!(cpu.cmdchannel, (ct, i, f, val, mode)), cpu.lock)
    #taskbusy 会被 rminstr!/logout! 持锁 delete!,无锁读既可能读到撕裂值也可能 KeyError
    timedwhile(() -> !lock(() -> get(cpu.taskbusy, ct.addr, false), cpu.lock), ct.busytimeout)
    isok = timedwhile(() -> ct.ready[i], timeout)
    buf = lock(ct.lock) do #先取结果再释放槽位:释放后新命令可立即改写 databuf,与本读并发会撕裂
        b = ct.databuf[i]
        ct.available[i] = true
        b
    end
    return isok ? buf : error(errdesc)
end

(ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:write}; timeout=1) =
    _ctrequest(f, cpu, ct, val, Val(:write), timeout, "write timeout with ($f, $val)")
(ct::Controller)(f::Function, cpu::Processor, ::Val{:read}; timeout=1) =
    _ctrequest(f, cpu, ct, "", Val(:read), timeout, "read timeout with $f")
(ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:query}; timeout=1) =
    _ctrequest(f, cpu, ct, val, Val(:query), timeout, "query timeout with ($f, $val)")

function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, val::String, ::Val{:write})
    instrlocked = lock(() -> cpu.instrs[ct.addr], cpu.lock) #锁内取引用:防与 logout 的 pop!(cpu.instrs, addr) 并发损坏 Dict
    wait(Threads.@spawn lock(instr -> f(instr, val), instrlocked))
    lock(ct.lock) do
        if !ct.ready[i] && !ct.available[i]
            ct.ready[i] = true
        end
    end
end
function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, ::String, ::Val{:read})
    instrlocked = lock(() -> cpu.instrs[ct.addr], cpu.lock)
    buf = fetch(Threads.@spawn lock(instr -> f(instr), instrlocked))
    lock(ct.lock) do
        if !ct.ready[i] && !ct.available[i]
            ct.databuf[i] = buf
            ct.ready[i] = true
        end
    end
end
function runcmd(cpu::Processor, ct::Controller, i::Int, f::Function, val::String, ::Val{:query})
    instrlocked = lock(() -> cpu.instrs[ct.addr], cpu.lock)
    buf = fetch(Threads.@spawn lock(instr -> f(instr, val), instrlocked))
    lock(ct.lock) do
        if !ct.ready[i] && !ct.available[i]
            ct.databuf[i] = buf
            ct.ready[i] = true
        end
    end
end

function init!(cpu::Processor)
    if !cpu.running[]
        lock(cpu.lock) do
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
        end
    end
end

function run!(cpu::Processor)
    if !cpu.running[]
        cpu.running[] = true
        cpu.processtask[] = errormonitor(
            @async_record "processing task" while cpu.running[]
                if isempty(cpu.cmdchannel)
                    cpu.fast[] ? yield() : sleep(0.001)
                else
                    lock(cpu.lock) do
                        cmd = popfirst!(cpu.cmdchannel)
                        push!(cpu.exechannels[cmd[1].addr], cmd)
                    end
                end
            end
        )
        for addr in collect(keys(cpu.exechannels)) #快照迭代:login! 会并发插入新键
            lock(cpu.lock) do
                cpu.taskhandlers[addr] = true
                cpu.taskbusy[addr] = false
                t = monitorinstr(cpu, addr)
                @info "task(address: $addr) has been created"
                cpu.tasks[addr] = errormonitor(t)
            end
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
                                    lock(cpu.lock) do
                                        cmd = popfirst!(cpu.cmdchannel)
                                        push!(cpu.exechannels[cmd[1].addr], cmd)
                                    end
                                end
                            end
                        )
                        @info "processing task has been recreated"
                    end
                    for (addr, t) in collect(cpu.tasks) #快照迭代:登录/重建会并发插入,Dict 重哈希会损坏迭代器
                        if istaskfailed(t) && haskey(cpu.exechannels, addr) && haskey(cpu.taskhandlers, addr)
                            setbusy!(cpu, addr)
                            @warn "task(address: $addr) failed, clearing buffer and recreating..."
                            lock(cpu.instrs[addr]) do instr
                                instr.attr.clearbuffer && clearbuffer(instr)
                            end
                            lock(() -> cpu.tasks[addr] = monitorinstr(cpu, addr), cpu.lock)
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
        @async_record "monitor task $(addr)" while lock(() -> get(cpu.taskhandlers, addr, false), cpu.lock)
            cmd = lock(cpu.lock) do #检查+弹出原子化,防与 logout 删 Dict、Controller push 竞争
                haskey(cpu.exechannels, addr) && !isempty(cpu.exechannels[addr]) &&
                    !cpu.taskbusy[addr] ? popfirst!(cpu.exechannels[addr]) : nothing
            end
            if isnothing(cmd) #runcmd 含阻塞的仪器 I/O,必须在 cpu.lock 之外执行
                cpu.fast[] ? yield() : sleep(0.001)
            else
                runcmd(cpu, cmd...)
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
        lock(cpu.lock) do #只置停止标志:processtask/monitor 的循环体要拿 cpu.lock,持锁等待会互相卡到 6s 强杀
            for addr in keys(cpu.taskhandlers)
                cpu.taskbusy[addr] = false
                cpu.taskhandlers[addr] = false
            end
            cpu.running[] = false
            cpu.fast[] = false
        end
        for t in collect(values(cpu.tasks))
            timedwhilefetch(t, 6)
        end
        timedwhilefetch(cpu.processtask[], 6; msg="force to stop processing task")
        lock(cpu.lock) do
            for instrlocked in collect(values(cpu.instrs))
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
    end
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
slow!(cpu::Processor) = lock(() -> cpu.fast[] = false, cpu.lock)

"""
    fast!(cpu::Processor)

change the cpu mode to fast mode. Default mode is slow mode. The fast mode is not necessary in most cases.
"""
fast!(cpu::Processor) = lock(() -> cpu.fast[] = true, cpu.lock)

function setbusy!(cpu::Processor, addr::String)
    if haskey(cpu.taskbusy, addr)
        lock(() -> cpu.taskbusy[addr] = true, cpu.lock)
        @warn "set busy for $addr"
    end
end
function unsetbusy!(cpu::Processor, addr::String)
    if haskey(cpu.taskbusy, addr)
        lock(() -> cpu.taskbusy[addr] = false, cpu.lock)
        @info "unset busy for $addr"
    end
end
setbusy!(cpu::Processor) = map(addr -> setbusy!(cpu, addr), collect(keys(cpu.taskbusy)))
unsetbusy!(cpu::Processor) = map(addr -> unsetbusy!(cpu, addr), collect(keys(cpu.taskbusy)))
isbusy(cpu::Processor, addr::String) = haskey(cpu.taskbusy, addr) && cpu.taskbusy[addr]