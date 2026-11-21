"""
    Controller(instrnm, addr)

construct a Controller to send commands to the instrument determined by (instrnm, addr). A Controller has three ways to
send commands to the Processor: wirte read query.
```julia
julia> ct(write, cpu, "*IDN?", Val(:write))
""

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
    databuf::Vector{String} #槽位结果缓冲:仅 vec 模式使用,通道模式闲置
    available::Vector{Bool} #槽位空闲标志
    ready::Vector{Int} #槽位就绪序列号(0=未就绪):存序列号而非 Bool,超时孤儿的迟到结果写回旧序列号后与新命令的等待条件不等,不会串扰后续命令
    busytimeout::Float64
    #buflen:槽位池长度(vec 模式按它分配);通道模式下仅作兼容参数保留
    Controller(instrnm, addr; buflen=16, busytimeout=54) =
        new(instrnm, addr, fill("", buflen), fill(true, buflen), zeros(Int, buflen), busytimeout)
end
function Base.show(io::IO, ct::Controller)
    str = """
       instrnm : $(ct.instrnm)
       address : $(ct.addr)
    """
    print(io, str)
end

#一条仪器命令:(控制器, 执行函数, 参数, 模式, 响应通道)。响应通道由每次调用新建并随命令
#携带,执行结果 put! 回该通道——超时孤儿命令的迟到结果写入的是被放弃的通道,不可能串扰到
#后续调用。Val(:stop) 为停止唤醒命令,用于让阻塞在 take! 上的任务正常退出而非被强杀
#(timedwhilefetch 的强杀会留错误日志)
const INSTRCMD = Tuple{Controller,Function,String,Val,Channel{String}}
_stopcmd() = (Controller("", ""), identity, "", Val(:stop), Channel{String}(1))

#vec 模式的一条仪器命令:(控制器, 执行函数, 参数, 模式, 槽位号, 就绪序列号)。前四元与
#INSTRCMD 同序,末两位取代响应通道:执行结果写进槽位 databuf[i] 并置 ready[i] = 序列号
const INSTRCMDV = Tuple{Controller,Function,String,Val,Int,Int}

"""
    Processor()

construct a Processor to deal with the commands sended into by Controllers.
"""
struct Processor
    lock::ReentrantLock #保护 controllers/instrs/exechannels/tasks/taskhandlers/taskbusy 的结构与查取;通道的 put!/take! 自身线程安全,一律在锁外
    qlock::ReentrantLock #保护 vec 模式队列的结构性操作(cmdqueue/execqueues 的 push!/popfirst!/empty!/delete! 与抢槽扫描):引用元素数组的并发结构操作会撕裂出 #undef 槽位(UndefRefError,现场实测复现过),无竞争时开销仅 ~几十 ns。锁序:先 lock 后 qlock,绝不反序
    controllers::Vector{Controller}
    cmdchannel::Channel{INSTRCMD}
    exechannels::Dict{String,Channel{INSTRCMD}}
    cmdqueue::Vector{INSTRCMDV} #vec 模式全局命令队列(通道模式闲置)
    execqueues::Dict{String,Vector{INSTRCMDV}} #vec 模式每仪器执行队列(通道模式闲置)
    cmdserial::Threads.Atomic{Int} #vec 模式命令序列号计数器(原子递增:即使出现并行也不会重复序列号,杜绝结果静默错配)
    vecmode::Ref{Bool} #true=vector 槽位模型:运行进程单线程,协作调度保证两次让出之间原子;false=通道模型。由 init! 按运行进程线程数一次确定,运行期不变
    processtask::Ref{Task}
    tasks::Dict{String,Task}
    taskhandlers::Dict{String,Bool}
    taskbusy::Dict{String,Bool}
    resourcemanager::Ref{UInt32}
    instrs::Dict{String,Lockable}
    running::Ref{Bool}
    fast::Ref{Bool}
    Processor() = new(
        ReentrantLock(), ReentrantLock(), [], Channel{INSTRCMD}(Inf), Dict{String,Channel{INSTRCMD}}(),
        Vector{INSTRCMDV}(), Dict{String,Vector{INSTRCMDV}}(), Threads.Atomic{Int}(0), false,
        Ref{Task}(), Dict(), Dict(), Dict(), 0, Dict(), false, false
    )
end

function Base.show(io::IO, cpu::Processor)
    str1 = """
           running : $(cpu.running[])
              mode : $(cpu.fast[] ? "fast" : "slow")
         transport : $(cpu.vecmode[] ? "vector" : "channel")
   ResourceManager : $(cpu.resourcemanager[])
       controllers :
    """
    print(io, str1)
    for ct in collect(cpu.controllers)
        print(io, "\t\t\tController\n")
        print(io, ct)
        # ct_strs = split(string(ct), '\n')[1:end-1]
        # print(io, string(join(fill("\t\t", 4) .* ct_strs, "\n"), "\n\n"))
    end
    str2 = """
              tasks :
    """
    print(io, str2)
    for (addr, state) in collect(cpu.taskhandlers)
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
                    if cpu.vecmode[]
                        lock(cpu.qlock) do #与 routetask 的 haskey+push 同锁,Dict 插入不被并发读撞上
                            cpu.execqueues[ct.addr] = Vector{INSTRCMDV}()
                        end
                    else
                        cpu.exechannels[ct.addr] = Channel{INSTRCMD}(Inf)
                    end
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
        #停止标志与等待必须在 cpu.lock 之外:monitor 循环体要拿 cpu.lock 查状态,
        #持锁等它退出会互相卡到 6s 强杀(与 stop! 是同坑,见 stop! 内注释)
        lock(cpu.lock) do
            haskey(cpu.taskhandlers, addr) && (cpu.taskhandlers[addr] = false)
            #vec 模式的 monitor 轮询标志,下一轮询周期自行退出,未执行命令随队列在下方清理;
            #通道模式 monitor 阻塞在 take! 上,须投递停止命令唤醒使其正常退出
            !cpu.vecmode[] && haskey(cpu.exechannels, addr) && put!(cpu.exechannels[addr], _stopcmd())
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
                lock(cpu.qlock) do #与 routetask 的 haskey+push!/monitor 的 pop 互斥,避免命令投进已删队列
                    delete!(cpu.execqueues, addr)
                end
                disconnect!(instr)
                pop!(cpu.instrs, addr)
            end
            delete_instr(addr)
        end
    end
end

"三个 (ct::Controller)(...) 入口的公共实现(write/read/query 仅差命令元组与错误文案):
超时即视为仪器故障(不再等迟到数据);需要更长等待时应调大仪器驱动的 timeout 字段,而不是在此补偿。
等待一律用 timedwhile(yield 忙轮询)而非 timedwait(定时 sleep):后者每查一次睡 1ms,单命令凭空
多出 1-2ms 延迟,高速采集下是致命回归(通道化时曾误改,已修复)"
function _ctrequest(f::Function, cpu::Processor, ct::Controller, val::String, mode::Val, timeout, errdesc)
    cpu.vecmode[] && return _ctrequestv(f, cpu, ct, val, mode, timeout, errdesc)
    @assert lock(() -> ct in cpu.controllers, cpu.lock) "Controller is not logged in"
    @assert cpu.running[] "Processor is not running"
    resp = Channel{String}(1)
    put!(cpu.cmdchannel, (ct, f, val, mode, resp)) #Channel(Inf),入队永不阻塞,与原 Vector 语义一致
    #taskbusy 会被 rminstr!/logout! 持锁 delete!,读必须持锁;地址已注销时立即视为空闲
    timedwhile(() -> !lock(() -> get(cpu.taskbusy, ct.addr, false), cpu.lock), ct.busytimeout)
    isok = timedwhile(() -> isready(resp), timeout)
    return isok ? take!(resp) : error(errdesc)
end

"vec 模式实现:单线程下协作调度保证两次让出之间的操作原子;队列的结构性操作与抢槽扫描经
qlock 互斥(无竞争 ~几十 ns,IO 一律锁外),即使异常地出现并行也不会撕裂队列。槽位字交换
(ready/databuf/available)保持无锁:字读写硬件原子,序列号设计使迟到写自然失效。
流程:抢空闲槽位 → 命令带(槽位号,序列号)入队 → 轮询槽位序列号取结果 → 归还槽位"
function _ctrequestv(f::Function, cpu::Processor, ct::Controller, val::String, mode::Val, timeout, errdesc)
    @assert ct in cpu.controllers "Controller is not logged in"
    @assert cpu.running[] "Processor is not running"
    i = 0
    isok = timedwhile(() -> lock(cpu.qlock) do #timeout 内抢一个空闲槽位,扫描经 qlock 互斥,绝不两人抢到同槽
        for (j, avail) in enumerate(ct.available)
            avail || continue
            ct.available[j] = false
            ct.ready[j] = 0
            i = j
            return true
        end
        return false
    end, timeout)
    isok || error("timeout without available buffer")
    serial = Threads.atomic_add!(cpu.cmdserial, 1) + 1
    lock(cpu.qlock) do
        push!(cpu.cmdqueue, (ct, f, val, mode, i, serial))
    end
    #taskbusy 由 setbusy!/unsetbusy!/rminstr! 在其它任务的让出点改动,读不撕裂;地址已注销时立即视为空闲
    timedwhile(() -> !get(cpu.taskbusy, ct.addr, false), ct.busytimeout)
    isok = timedwhile(() -> ct.ready[i] == serial, timeout)
    ct.available[i] = true #无论成败归还槽位;迟到结果因序列号不符而失效
    return isok ? ct.databuf[i] : error(errdesc)
end

(ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:write}; timeout=1) =
    _ctrequest(f, cpu, ct, val, Val(:write), timeout, "write timeout with ($f, $val)")
(ct::Controller)(f::Function, cpu::Processor, ::Val{:read}; timeout=1) =
    _ctrequest(f, cpu, ct, "", Val(:read), timeout, "read timeout with $f")
(ct::Controller)(f::Function, cpu::Processor, val::String, ::Val{:query}; timeout=1) =
    _ctrequest(f, cpu, ct, val, Val(:query), timeout, "query timeout with ($f, $val)")

function runcmd(cpu::Processor, ct::Controller, f::Function, val::String, ::Val{:write}, resp::Channel{String})
    instrlocked = lock(() -> cpu.instrs[ct.addr], cpu.lock) #锁内取引用:防与 logout 的 pop!(cpu.instrs, addr) 并发损坏 Dict
    #invokelatest:f 可能是 monitor 任务启动之后才定义的运行时函数(gen_qtfunc 远程 eval、
    #DAQ 生成代码),长驻任务阻塞恢复后的世界年龄追不上新方法,直接调用会报
    #"method too new to be called from this world context"
    fetch(Threads.@spawn lock(instr -> Base.invokelatest(f, instr, val), instrlocked))
    put!(resp, "") #write 不回传执行结果(各驱动返回值不一,与原槽位机制行为一致)
end
function runcmd(cpu::Processor, ct::Controller, f::Function, ::String, ::Val{:read}, resp::Channel{String})
    instrlocked = lock(() -> cpu.instrs[ct.addr], cpu.lock)
    put!(resp, fetch(Threads.@spawn lock(instr -> Base.invokelatest(f, instr), instrlocked)))
end
function runcmd(cpu::Processor, ct::Controller, f::Function, val::String, ::Val{:query}, resp::Channel{String})
    instrlocked = lock(() -> cpu.instrs[ct.addr], cpu.lock)
    put!(resp, fetch(Threads.@spawn lock(instr -> Base.invokelatest(f, instr, val), instrlocked)))
end

#以下三个为 vec 模式执行端:monitorinstr 是该地址命令的唯一执行者,运行进程单线程,协作调度
#下直接执行安全;不 @spawn 省两次任务切换,不取仪器锁省零竞争的锁开销。instrs 的 Dict 读经
#cpu.lock(防与 login!/rminstr! 的插入删除撞车,无竞争 ~几十 ns);`.value` 直接读 Lockable
#内层字段完成无锁解包(getindex 带 assert_havelock 断言,不能用于无锁场景)
function runcmd(cpu::Processor, ct::Controller, f::Function, val::String, ::Val{:write}, i::Int, serial::Int)
    instr = lock(() -> cpu.instrs[ct.addr], cpu.lock).value
    Base.invokelatest(f, instr, val)
    ct.databuf[i] = "" #write 不回传执行结果(各驱动返回值不一,与通道模式行为一致)
    ct.ready[i] = serial
end
function runcmd(cpu::Processor, ct::Controller, f::Function, ::String, ::Val{:read}, i::Int, serial::Int)
    ct.databuf[i] = Base.invokelatest(f, lock(() -> cpu.instrs[ct.addr], cpu.lock).value)
    ct.ready[i] = serial
end
function runcmd(cpu::Processor, ct::Controller, f::Function, val::String, ::Val{:query}, i::Int, serial::Int)
    ct.databuf[i] = Base.invokelatest(f, lock(() -> cpu.instrs[ct.addr], cpu.lock).value, val)
    ct.ready[i] = serial
end

function init!(cpu::Processor)
    if !cpu.running[]
        lock(cpu.lock) do
            cpu.fast[] = false
            #模式按运行进程的线程数一次确定:单线程走 vector 槽位模型(队列结构操作经 qlock,
            #协作调度+互斥保证安全),多线程走通道模型(通道自带的锁与阻塞唤醒换并发安全)。
            #运行期不可切换(进程线程数不可变)
            cpu.vecmode[] = Threads.nthreads() == 1
            @info "Processor transport: $(cpu.vecmode[] ? "vector" : "channel") (nthreads=$(Threads.nthreads()))"
            lock(cpu.qlock) do
                empty!(cpu.cmdqueue) #排空残留命令(此时无任务在跑,残留只会是上次停止的未路由命令)
                empty!(cpu.execqueues)
            end
            if !cpu.vecmode[]
                #Channel 无 empty!:排空残留命令(此时无任务在跑,残留只会是上次停止的唤醒命令)
                while isready(cpu.cmdchannel)
                    take!(cpu.cmdchannel)
                end
                empty!(cpu.exechannels)
            end
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
                if cpu.vecmode[]
                    cpu.execqueues[addr] = Vector{INSTRCMDV}()
                else
                    cpu.exechannels[addr] = Channel{INSTRCMD}(Inf)
                end
                cpu.taskhandlers[addr] = false
                cpu.taskbusy[addr] = false
            end
        end
    end
end

"命令分发任务:通道模式从 cmdchannel 阻塞取出命令,按地址投入对应 exechannel——阻塞 take!
取代旧的 1ms 轮询:空闲零 CPU,命令到达即唤醒;vec 模式轮询 cmdqueue 按地址投入 execqueues"
function _routetask(cpu::Processor)
    @async_record "processing task" while cpu.running[]
        if cpu.vecmode[]
            routed = lock(cpu.qlock) do #队列结构操作经 qlock,与 rminstr! 的删除互斥不被拆散
                if isempty(cpu.cmdqueue)
                    false
                else
                    cmd = popfirst!(cpu.cmdqueue)
                    #注销中的地址其队列已随 rminstr! 清理,haskey 检查使命令随注销一并丢弃
                    haskey(cpu.execqueues, cmd[1].addr) && push!(cpu.execqueues[cmd[1].addr], cmd)
                    true
                end
            end
            routed || (cpu.fast[] ? yield() : sleep(0.001)) #空闲忙轮询:fast 让出即时响应,slow 睡眠降 CPU
        else
            cmd = take!(cpu.cmdchannel)
            cmd[4] === Val(:stop) && break #stop! 投递的唤醒命令
            lock(cpu.lock) do
                haskey(cpu.exechannels, cmd[1].addr) && put!(cpu.exechannels[cmd[1].addr], cmd)
            end
        end
    end
end

function run!(cpu::Processor)
    if !cpu.running[]
        cpu.running[] = true
        cpu.processtask[] = errormonitor(_routetask(cpu))
        execs = cpu.vecmode[] ? cpu.execqueues : cpu.exechannels #按模式取待启动的执行队列
        for addr in collect(keys(execs)) #快照迭代:login! 会并发插入新键
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
                        cpu.processtask[] = errormonitor(_routetask(cpu))
                        @info "processing task has been recreated"
                    end
                    for (addr, t) in collect(cpu.tasks) #快照迭代:登录/重建会并发插入,Dict 重哈希会损坏迭代器
                        if istaskfailed(t) && lock(() ->
                           (cpu.vecmode[] ? haskey(cpu.execqueues, addr) : haskey(cpu.exechannels, addr)) &&
                           haskey(cpu.taskhandlers, addr), cpu.lock)
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
        @async_record "monitor task $(addr)" if cpu.vecmode[]
            #vec 模式:轮询执行队列,空闲忙轮询;本任务是该地址命令的唯一执行者(串行化保证)。
            #取命令经 qlock(与 routetask 的 push 互斥,防引用数组撕裂),执行(IO)一律在锁外
            q = lock(() -> cpu.execqueues[addr], cpu.qlock) #取一次队列引用:Dict 增删不换队列本体
            while get(cpu.taskhandlers, addr, false)
                cmd = lock(cpu.qlock) do
                    (isempty(q) || get(cpu.taskbusy, addr, false)) ? nothing : popfirst!(q)
                end
                if isnothing(cmd)
                    #空闲或重试逻辑(@gentrycatch)进行中:忙轮询等 busy 解除
                    cpu.fast[] ? yield() : sleep(0.001)
                else
                    runcmd(cpu, cmd...)
                end
            end
        else
            ch = lock(() -> cpu.exechannels[addr], cpu.lock) #取一次通道引用:Dict 增删不换通道本体
            while lock(() -> get(cpu.taskhandlers, addr, false), cpu.lock)
                cmd = take!(ch) #阻塞等待,空闲零开销;唤醒途径:新命令或注销/停止投递的 Val(:stop)
                cmd[4] === Val(:stop) && break
                #重试逻辑(@gentrycatch)进行中:暂缓执行新命令,等 busy 解除
                while lock(() -> get(cpu.taskbusy, addr, false), cpu.lock) &&
                      lock(() -> get(cpu.taskhandlers, addr, false), cpu.lock)
                    cpu.fast[] ? yield() : sleep(0.001)
                end
                lock(() -> get(cpu.taskhandlers, addr, false), cpu.lock) && runcmd(cpu, cmd...)
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
        lock(cpu.lock) do #只置停止标志并投递唤醒命令:通道模式任务阻塞在 take! 上,须唤醒才能正常退出
            for addr in collect(keys(cpu.taskhandlers))
                cpu.taskbusy[addr] = false
                cpu.taskhandlers[addr] = false
                !cpu.vecmode[] && haskey(cpu.exechannels, addr) && put!(cpu.exechannels[addr], _stopcmd())
            end
            !cpu.vecmode[] && put!(cpu.cmdchannel, _stopcmd()) #唤醒阻塞在 take! 上的分发任务
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
            #cmdchannel 无 empty!:残留的唤醒命令/未路由命令由下次 init! 排空
            empty!(cpu.exechannels)
            lock(cpu.qlock) do
                empty!(cpu.cmdqueue)
                empty!(cpu.execqueues)
            end
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
    instrlocked = lock(() -> haskey(cpu.instrs, addr) ? cpu.instrs[addr] : nothing, cpu.lock)
    isnothing(instrlocked) || lock(instrlocked) do instr
        disconnect!(instr)
        connect!(cpu.resourcemanager[], instr)
    end
end
reconnect!(cpu::Processor) = map(addr -> reconnect!(cpu, addr), collect(keys(cpu.instrs)))

"""
    slow!(cpu::Processor)

change the cpu mode to slow mode. Default mode is slow mode, which decrease the cpu cost.

该模式控制各忙轮询点的等待方式:fast 让出(yield,低延迟高 CPU),slow 睡眠(降 CPU)。
vec 模式下命令提交/分发/执行/取结果各环节均为轮询;通道模式下仅影响 monitor 暂缓执行期间。
"""
slow!(cpu::Processor) = lock(() -> cpu.fast[] = false, cpu.lock)

"""
    fast!(cpu::Processor)

change the cpu mode to fast mode. Default mode is slow mode. The fast mode is not necessary in most cases.
"""
fast!(cpu::Processor) = lock(() -> cpu.fast[] = true, cpu.lock)

function setbusy!(cpu::Processor, addr::String)
    lock(() -> haskey(cpu.taskbusy, addr), cpu.lock) || return
    lock(() -> cpu.taskbusy[addr] = true, cpu.lock)
    @warn "set busy for $addr"
end
function unsetbusy!(cpu::Processor, addr::String)
    lock(() -> haskey(cpu.taskbusy, addr), cpu.lock) || return
    lock(() -> cpu.taskbusy[addr] = false, cpu.lock)
    @info "unset busy for $addr"
end
setbusy!(cpu::Processor) = map(addr -> setbusy!(cpu, addr), collect(keys(cpu.taskbusy)))
unsetbusy!(cpu::Processor) = map(addr -> unsetbusy!(cpu, addr), collect(keys(cpu.taskbusy)))
isbusy(cpu::Processor, addr::String) = lock(() -> get(cpu.taskbusy, addr, false), cpu.lock)
