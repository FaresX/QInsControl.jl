
export remote_startcpu!, remote_stopcpu!, remote_cpumode!, remote_find_resources!, remote_connect!, remote_logout!
export remote_setbusy!, remote_unsetbusy!, remote_getcpuinfo
export remote_write, remote_query, remote_read, remote_qtread, remote_qtset, remote_qtsweep, remote_idn_get
export remote_setport!, remote_setmaxclients!, remote_setbuflen!, remote_startserver!, remote_stopserver!
export remote_servermode!, remote_deleteclient!, remote_servernewmsg!, remote_fetchserver
export remote_startrefresh, remote_stoprefresh, putinput!, takeoutput!, isoutputready
export remote_continue, remote_check_instr, remote_def_prog, remote_runtask
export isready_databufrc, isready_extradatabufrc, isready_progressrc, take_databufrc!, take_extradatabufrc!, take_progressrc!
export loadattr, syncattr, getattr
export startlogger, stoplogger


const LOGIO = IOBuffer()
const LOGGERTASK = Ref{Task}()

const CPU = Processor()
const QICSERVER = QICServer()

@enum SyncStatesIndex begin
    IsDAQTaskRunning = 1
    IsDAQTaskDone
    IsInterrupted
    IsBlocked
    IsRefreshing
    IsLogging
    IsNewLogging
end
Base.getindex(x::AbstractVector{Bool}, i::SyncStatesIndex) = x[Int(i)]
Base.setindex!(x::AbstractVector{Bool}, v::Bool, i::SyncStatesIndex) = x[Int(i)] = v
global SYNCSTATES::SharedVector{Bool} = SharedVector{Bool}(length(instances(SyncStatesIndex)))

const SWEEPCTS = Dict{String,Dict{String,Dict{String,Tuple{Ref{Bool},Controller}}}}()
const REFRESHCTS = Dict{String,Dict{String,Controller}}()
const REFRESHTASK = Ref{Task}()
global REFRESHINRC::RemoteChannel{Channel{Tuple{String,String,String,Cfloat}}}
global REFRESHOUTRC::RemoteChannel{Channel{Tuple{String,String,String,String}}}

const BLOCK = Threads.Condition()
global DATABUFRC::RemoteChannel{Channel{Vector{NTuple{2,String}}}}
global EXTRADATABUFRC::RemoteChannel{Channel{Tuple{String,Vector{Any}}}}
global PROGRESSRC::RemoteChannel{Channel{Vector{Tuple{UUID,Int,Int,Float64}}}}

###### Logger ######
function startlogger(dir)
    SYNCSTATES[IsLogging] = true
    global_logger(SimpleLogger(LOGIO))
    LOGGERTASK[] = errormonitor(
        Threads.@spawn @trycatch mlstr("error in local logging task") while SYNCSTATES[IsLogging]
            update_log(dir, SYNCSTATES)
            sleep(1)
        end
    )
    sleep(0.1)
    if istaskstarted(LOGGERTASK[])
        @info mlstr("local logging task started")
    else
        @warn mlstr("local logging task not started")
    end
    remotecall_wait(workers()[1], SYNCSTATES, dir) do SYNCSTATES, dir
        global_logger(SimpleLogger(LOGIO))
        LOGGERTASK[] = errormonitor(
            Threads.@spawn @trycatch mlstr("error in remote logging task") while SYNCSTATES[IsLogging]
                update_log(dir, SYNCSTATES)
                sleep(1)
            end
        )
        sleep(0.1)
        if istaskstarted(LOGGERTASK[])
            @info mlstr("remote logging task started")
        else
            @warn mlstr("remote logging task not started")
        end
    end
end
function stoplogger()
    SYNCSTATES[IsLogging] = false
    @sync begin
        @async if isassigned(LOGGERTASK)
            sleep(0.1)
            istaskdone(LOGGERTASK[]) || schedule(LOGGERTASK[], mlstr("Stop local logging task"); error=true)
            if istaskdone(LOGGERTASK[])
                @info mlstr("local logging task stopped")
            else
                @warn mlstr("local logging task not stopped")
            end
        end
        @async remotecall_wait(workers()[1]) do
            if isassigned(LOGGERTASK)
                sleep(0.1)
                istaskdone(LOGGERTASK[]) || schedule(LOGGERTASK[], mlstr("Stop remote logging task"); error=true)
                if istaskdone(LOGGERTASK[])
                    @info mlstr("remote logging task stopped")
                else
                    @warn mlstr("remote logging task not stopped")
                end
            end
        end
    end
end
function update_log(dir, syncstates)
    date = today()
    logdir = joinpath(dir, string(year(date)), string(year(date), "-", month(date)))
    isdir(logdir) || mkpath(logdir)
    logfile = joinpath(logdir, string(date, ".log"))
    if myid() == 1
        flush(LOGIO)
        msg = String(take!(LOGIO))
        isempty(msg) || (open(file -> write(file, msg), logfile, "a+"); syncstates[IsNewLogging] = true)
    else
        flush(LOGIO)
        msg = String(take!(LOGIO))
        if !isempty(msg)
            open(logfile, "a+") do file
                msgsp = split(msg, '\n')
                for (i, s) in enumerate(msgsp)
                    s == "" && (msgsp[i] = "\n")
                    s == "\r" && (msgsp[i] = "\n\r")
                    isempty(rstrip(s)) || (msgsp[i] = string("from worker $(myid()): ", msgsp[i], '\n'))
                end
                write(file, string(msgsp...))
            end
            syncstates[IsNewLogging] = true
        end
    end
end

###### Load ######
remote_include(file) = remotecall_wait(include, workers()[1], file)

function gen_qtfunc(instrnm, quantity, cmdheader, cmdtype)
    ex = if cmdtype == "scpi"
        scpi_expr(instrnm, quantity, cmdheader)
    elseif cmdtype == "tsp"
        tsp_expr(instrnm, quantity, cmdheader)
    end
    remotecall_wait(eval, workers()[1], ex)
end

function scpi_expr(instrnm, quantity, scpistr)
    get = Symbol(instrnm, :_, quantity, :_get)
    occursin("?", scpistr) && return quote
        $get(instr) = query(instr, $scpistr)
    end
    scpistrs = split(scpistr, " ")
    exget = if length(scpistrs) == 1
        quote
            $get(instr) = query(instr, string($scpistr, "?"))
        end
    elseif length(scpistrs) == 2
        quote
            $get(instr) = query(instr, string($(scpistrs[1]), "? ", $(scpistrs[2])))
        end
    end
    set = Symbol(instrnm, :_, quantity, :_set)
    exset = if length(scpistrs) == 1
        quote
            $set(instr, val) = write(instr, string($scpistr, " ", val))
        end
    elseif length(scpistrs) == 2
        quote
            $set(instr, val) = write(instr, string($scpistr, ", ", val))
        end
    end
    return Expr(:block, exget, exset)
end

function tsp_expr(instrnm, quantity, tspstr)
    get = Symbol(instrnm, :_, quantity, :_get)
    tspstr[end-1:end] == "()" && return quote
        $get(instr) = query(instr, string("print(", $tspstr, ")"))
    end
    set = Symbol(instrnm, :_, quantity, :_set)
    ex = quote
        function $set(instr, val)
            write(instr, string($tspstr, "=", val))
        end
        function $get(instr)
            query(instr, string("print(", $tspstr, ")"))
        end
    end
    return ex
end

###### CPU Monitor ######
remote_set_libvisa!(visapath) = timed_remotecall_wait(visapath -> set_libvisa(visapath), workers()[1], visapath)
remote_startcpu!() = timed_remotecall_wait(() -> start!(CPU), workers()[1])
remote_stopcpu!() = timed_remotecall_wait(() -> stop!(CPU), workers()[1])
remote_cpumode!(mode) = timed_remotecall_wait(mode -> CPU.fast[] = mode, workers()[1], mode)
remote_connect!(addr) = timed_remotecall_wait(addr -> connect!(CPU.resourcemanager[], CPU.instrs[addr]), workers()[1], addr)
remote_find_resources!() = remotecall_fetch(() -> find_resources(CPU), workers()[1])
remote_logout!(addr) = timed_remotecall_wait(addr -> logout!(CPU, addr), workers()[1], addr)
function remote_logout!()
    timed_remotecall_wait(workers()[1]) do
        for instr in keys(CPU.instrs)
            logout!(CPU, instr)
        end
    end
end
remote_setbusy!(addr) = timed_remotecall_wait(addr -> setbusy!(CPU, addr), workers()[1], addr)
remote_unsetbusy!(addr) = timed_remotecall_wait(addr -> unsetbusy!(CPU, addr), workers()[1], addr)
remote_unsetbusy!() = timed_remotecall_wait(() -> unsetbusy!(CPU), workers()[1])
function remote_getcpuinfo()
    timed_remotecall_fetch(workers()[1]; timeout=1, quiet=true) do
        lock(CPU.lock) do
            Dict(
                :running => CPU.running[],
                :taskfailed => istaskfailed(CPU.processtask[]),
                :fast => CPU.fast[],
                :resourcemanager => CPU.resourcemanager[],
                :instrs => Dict(ins.addr => ins.name for ins in values(CPU.instrs)),
                :isconnected => Dict(addr => QInsControlCore.isconnected(instr) for (addr, instr) in CPU.instrs),
                :controllers => CPU.controllers,
                :taskhandlers => CPU.taskhandlers,
                :taskbusy => CPU.taskbusy,
                :tasksfailed => Dict(addr => istaskfailed(task) for (addr, task) in CPU.tasks)
            )
        end
    end
end

###### QIC Server Monitor ######
remote_setport!(port) = timed_remotecall_wait(port -> QICSERVER.port = port, workers()[1], port)
remote_setmaxclients!(maxclients) = timed_remotecall_wait(maxclients -> QICSERVER.maxclients = maxclients, workers()[1], maxclients)
remote_setbuflen!(buflen) = timed_remotecall_wait(buflen -> QICSERVER.buflen = buflen, workers()[1], buflen)
remote_startserver!(buflen=4) = timed_remotecall_wait(() -> start!(QICSERVER; buflen=buflen), workers()[1])
remote_stopserver!() = timed_remotecall_wait(() -> stop!(QICSERVER), workers()[1])
remote_servermode!(mode) = timed_remotecall_wait(mode -> QICSERVER.fast = mode, workers()[1], mode)
function remote_deleteclient!(addr, port)
    timed_remotecall_wait(workers()[1], addr, port) do addr, port
        for c in QICSERVER.clients
            if string(c.addr) == string(addr) && c.port == port
                c.connected = false
                break
            end
        end
    end
end
remote_servernewmsg!(hasnew) = timed_remotecall_wait(hasnew -> QICSERVER.newmsg = hasnew, workers()[1], hasnew)
remote_fetchserver() = timed_remotecall_fetch(() -> QICSERVER, workers()[1]; timeout=1, quiet=true)

###### Instrument Attribute ######
let
    spattrs::Dict{String,SerialInstrAttr} = Dict()
    tcpipattrs::Dict{String,TCPSocketInstrAttr} = Dict()
    virtualattrs::Dict{String,VirtualInstrAttr} = Dict("VirtualAddress" => VirtualInstrAttr())
    visaattrs::Dict{String,VISAInstrAttr} = Dict()
    global function getattr(addr)
        return if occursin("SERIAL", addr)
            haskey(spattrs, addr) || (spattrs[addr] = SerialInstrAttr())
            spattrs[addr]
        elseif occursin("TCPSOCKET", addr)
            haskey(tcpipattrs, addr) || (tcpipattrs[addr] = TCPSocketInstrAttr())
            tcpipattrs[addr]
        elseif occursin("VIRTUAL", split(addr, "::")[1])
            haskey(virtualattrs, addr) || (virtualattrs[addr] = VirtualInstrAttr())
            virtualattrs[addr]
        else
            haskey(visaattrs, addr) || (visaattrs[addr] = VISAInstrAttr())
            visaattrs[addr]
        end
    end

    global function loadattr(attrlist, addr)
        if haskey(attrlist, addr)
            attr = attrfromdict(attrlist[addr])
            attr isa SerialInstrAttr && (spattrs[addr] = attr)
            attr isa TCPSocketInstrAttr && (tcpipattrs[addr] = attr)
            attr isa VirtualInstrAttr && (virtualattrs[addr] = attr)
            attr isa VISAInstrAttr && (visaattrs[addr] = attr)
        end
    end

    global syncattr(addr) = remotecall_wait(attr -> copyattr!(attr, getattr(addr)), workers()[1], getattr(addr))

    function attrfromdict(attrdict)
        type = Symbol(attrdict["attrtype"]) |> eval
        attr = type()
        for (key, val) in attrdict
            key == "attrtype" && continue
            fdnm, ftype = split(key, "::")
            if hasfield(type, Symbol(fdnm))
                if ftype in ["Number", "String"]
                    setproperty!(attr, Symbol(fdnm), val)
                elseif ftype == "Char"
                    setproperty!(attr, Symbol(fdnm), val[1])
                elseif ftype == "Any"
                    setproperty!(attr, Symbol(fdnm), eval(Meta.parse(val)))
                end
            end
        end
        return attr
    end
end

###### Remote Communication ######

function remote_write(instrnm, addr, cmd, buflen)
    timed_remotecall_wait(
        workers()[1], instrnm, addr, cmd, buflen; timeout=getattr(addr).timeoutw
    ) do instrnm, addr, cmd, buflen
        ct = Controller(instrnm, addr; buflen=buflen)
        try
            attr = getattr(addr)
            login!(CPU, ct; attr=attr)
            ct(write, CPU, cmd, Val(:write); timeout=attr.timeoutw)
        catch e
            @error(
                "[$(now())]\ninstrument communication failed!!!",
                instrument = string(instrnm, ": ", addr),
                command = cmd,
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, ct)
        end
    end
end

function remote_query(instrnm, addr, cmd, buflen)
    attr = getattr(addr)
    timed_remotecall_fetch(
        workers()[1], instrnm, addr, cmd, buflen; timeout=attr.timeoutw + attr.timeoutr
    ) do instrnm, addr, cmd, buflen
        ct = Controller(instrnm, addr; buflen=buflen)
        try
            attr = getattr(addr)
            login!(CPU, ct; attr=attr)
            ct(query, CPU, cmd, Val(:query); timeout=attr.timeoutw + attr.timeoutr)
        catch e
            @error(
                "[$(now())]\ninstrument communication failed!!!",
                instrument = string(instrnm, ": ", addr),
                command = cmd,
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, ct)
        end
    end
end

function remote_read(instrnm, addr, buflen)
    timed_remotecall_fetch(workers()[1], instrnm, addr, buflen; timeout=getattr(addr).timeoutr) do instrnm, addr, buflen
        ct = Controller(instrnm, addr; buflen=buflen)
        try
            attr = getattr(addr)
            login!(CPU, ct; attr=attr)
            ct(read, CPU, Val(:read); timeout=attr.timeoutr)
        catch e
            @error(
                "[$(now())]\ninstrument communication failed!!!",
                instrument = string(instrnm, ": ", addr),
                command = "read",
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, ct)
        end
    end
end

function remote_qtread(instrnm, addr, qtnm, buflen, timeout)
    timed_remotecall_fetch(
        workers()[1], instrnm, addr, qtnm, buflen, timeout; timeout=timeout
    ) do instrnm, addr, qtnm, buflen, timeout
        ct = Controller(instrnm, addr; buflen=buflen)
        try
            getfunc = Symbol(instrnm, :_, qtnm, :_get) |> eval
            login!(CPU, ct; attr=getattr(addr))
            ct(getfunc, CPU, Val(:read); timeout=timeout)
        catch e
            @error(
                "[$(now())]\ninstrument communication failed!!!",
                instrument = string(instrnm, ": ", addr),
                quantity = qtnm,
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, ct)
        end
    end
end

function remote_qtset(instrnm, addr, qtnm, sv, buflen, timeoutw, timeoutr; retreading=false)
    timed_remotecall_fetch(
        workers()[1], instrnm, addr, qtnm, sv, buflen, timeoutw, timeoutr; timeout=timeoutw + timeoutr
    ) do instrnm, addr, qtnm, sv, buflen, timeoutw, timeoutr
        ct = Controller(instrnm, addr; buflen=buflen)
        try
            setfunc = Symbol(instrnm, :_, qtnm, :_set) |> eval
            getfunc = Symbol(instrnm, :_, qtnm, :_get) |> eval
            login!(CPU, ct; attr=getattr(addr))
            ct(setfunc, CPU, sv, Val(:write); timeout=timeoutw)
            if retreading
                ct(CPU, Val(:read); timeout=timeoutr) do instr
                    sleep(instr.attr.querydelay)
                    getfunc(instr)
                end
            else
                string(sv)
            end
        catch e
            @error(
                "[$(now())]\ninstrument communication failed!!!",
                instrument = string(instrnm, ": ", addr),
                quantity = qtnm,
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, ct)
        end
    end
end

function remote_qtsweep(
    instrnm, addr, qtnm, sweeplist, buflen, timeoutw, timeoutr, delay,
    issweeping::Ref{Bool}, presenti::Ref{Int}, elapsedtime::Ref{Float64}, read::Ref{String};
    channelsize=512, packsize=6, retreading=false
)
    issweeping[] = true
    sweep_c = Channel{Vector{String}}(channelsize)
    sweep_rc = RemoteChannel(() -> sweep_c)
    idxbuf = SharedVector{Int}(1)
    timebuf = SharedVector{Float64}(1)
    presenti[] = 0
    elapsedtime[] = 0
    sweepcalltask = @async @trycatch "remote sweeping task failed!!!" remotecall_wait(
        workers()[1], instrnm, addr, sweeplist, sweep_rc, qtnm, delay, idxbuf, timebuf
    ) do instrnm, addr, sweeplist, sweep_rc, qtnm, delay, idxbuf, timebuf
        haskey(SWEEPCTS, instrnm) || (SWEEPCTS[instrnm] = Dict())
        haskey(SWEEPCTS[instrnm], addr) || (SWEEPCTS[instrnm][addr] = Dict())
        if haskey(SWEEPCTS[instrnm][addr], qtnm)
            SWEEPCTS[instrnm][addr][qtnm][1][] = true
        else
            SWEEPCTS[instrnm][addr][qtnm] = (Ref(true), Controller(instrnm, addr; buflen=buflen))
        end
        sweep_lc = Channel{String}(channelsize)
        login!(CPU, SWEEPCTS[instrnm][addr][qtnm][2]; quiet=false, attr=getattr(addr))
        try
            setfunc = Symbol(instrnm, :_, qtnm, :_set) |> eval
            getfunc = Symbol(instrnm, :_, qtnm, :_get) |> eval
            @sync begin
                sweeptask = @async @trycatch "sweeping task failed!!!" begin
                    tstart = time()
                    ctpair = SWEEPCTS[instrnm][addr][qtnm]
                    for (i, sv) in enumerate(sweeplist)
                        ctpair[1][] || break
                        ctpair[2](setfunc, CPU, string(sv), Val(:write); timeout=timeoutw)
                        sleep(delay)
                        put!(sweep_lc, retreading ? ctpair[2](getfunc, CPU, Val(:read); timeout=timeoutr) : string(sv))
                        idxbuf[1] = i
                        timebuf[1] = time() - tstart
                    end
                end
                @async @trycatch "transfering sweeping data failed!!!" while !istaskdone(sweeptask) || isready(sweep_lc)
                    isready(sweep_lc) ? put!(sweep_rc, packtake!(sweep_lc, packsize)) : sleep(delay / 2)
                end
            end
        catch e
            @error(
                "[$(now())]\ninstrument communication failed!!!",
                instrument = string(instrnm, ": ", addr),
                quantity = qtnm,
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, SWEEPCTS[instrnm][addr][qtnm][2]; quiet=false)
            SWEEPCTS[instrnm][addr][qtnm][1][] = false
        end
    end
    ## local
    while !istaskdone(sweepcalltask) || isready(sweep_rc)
        issweeping[] || timed_remotecall_wait(workers()[1], instrnm, addr, qtnm) do instrnm, addr, qtnm
            SWEEPCTS[instrnm][addr][qtnm][1][] = false
        end
        isready(sweep_rc) ? for val in take!(sweep_rc)
            read[] = val
            presenti[] = idxbuf[1]
            elapsedtime[] = timebuf[1]
        end : sleep(delay / 2)
    end
    issweeping[] = false
end

idn_get(instr) = eval(Symbol(instr.attr.idnfunc))(instr)

function remote_idn_get(addr)
    timed_remotecall_fetch(workers()[1], addr; timeout=getattr(addr).timeoutr) do addr
        ct = Controller("", addr; buflen=1)
        try
            attr = getattr(addr)
            login!(CPU, ct; attr=attr)
            return ct(idn_get, CPU, Val(:read); timeout=attr.timeoutr)
        catch e
            @error(
                "[$(now())]\ninstrument communication failed during idn_get!!!",
                instrument_address = addr,
                exception = e
            )
            showbacktrace()
        finally
            logout!(CPU, ct)
        end
    end
end

###### Auto Refresh ######

putinput!(instrnm, addr, qtnm, timeoutr) = put!(REFRESHINRC, (instrnm, addr, qtnm, timeoutr))
takeoutput!() = take!(REFRESHOUTRC)
isoutputready() = isready(REFRESHOUTRC)
function remote_startrefresh(buflen=4)
    remote_do(
        workers()[1], REFRESHINRC, REFRESHOUTRC, SYNCSTATES, buflen
    ) do REFRESHINRC, REFRESHOUTRC, SYNCSTATES, buflen
        SYNCSTATES[IsRefreshing] = true
        REFRESHTASK[] = errormonitor(
            Threads.@spawn while SYNCSTATES[IsRefreshing]
                if isready(REFRESHINRC)
                    instrnm, addr, qtnm, timeoutr = take!(REFRESHINRC)
                    haskey(REFRESHCTS, instrnm) || (REFRESHCTS[instrnm] = Dict())
                    if !haskey(REFRESHCTS[instrnm], addr)
                        REFRESHCTS[instrnm][addr] = Controller(instrnm, addr; buflen=buflen)
                    end
                    ct = REFRESHCTS[instrnm][addr]
                    try
                        getfunc = Symbol(instrnm, :_, qtnm, :_get) |> eval
                        login!(CPU, ct; attr=getattr(addr))
                        read = ct(getfunc, CPU, Val(:read); timeout=timeoutr)
                        put!(REFRESHOUTRC, (instrnm, addr, qtnm, read))
                    catch e
                        @error(
                            "[$(now())]\ninstrument communication failed!!!",
                            instrument = string(instrnm, ": ", addr),
                            quantity = qtnm,
                            exception = e
                        )
                        logout!(CPU, ct)
                        showbacktrace()
                    end
                    yield()
                else
                    sleep(0.001)
                end
            end
        )
        sleep(0.1)
        if istaskstarted(REFRESHTASK[])
            @info "remote instrument autorefresh task started"
        else
            @warn "remote instrument autorefresh task not started"
        end
    end
end
function remote_stoprefresh()
    SYNCSTATES[IsRefreshing] = false
    remotecall_wait(workers()[1]) do
        isassigned(REFRESHTASK) || return nothing
        sleep(0.1)
        istaskdone(REFRESHTASK[]) || schedule(REFRESHTASK[], "Stop remote refresh"; error=true)
        if istaskdone(REFRESHTASK[])
            @info "remote instrument autorefresh task stopped"
        else
            @warn "remote instrument autorefresh task not stopped"
        end
    end
end

###### Run Task ######
function remote_continue()
    remote_do(workers()[1]) do
        lock(() -> notify(BLOCK), BLOCK)
    end
end

function remote_check_instr(instrnm, addr, buflen, retryconnecttimes, retrysendtimes)
    timed_remotecall_fetch(
        workers()[1], instrnm, addr, buflen, retryconnecttimes, retrysendtimes; timeout=getattr(addr).timeoutr
    ) do instrnm, addr, buflen, retryconnecttimes, retrysendtimes
        attr = getattr(addr)
        ct = Controller(
            instrnm, addr;
            buflen=buflen,
            busytimeout=attr.timeoutr * retryconnecttimes * retrysendtimes
        )
        try
            login!(CPU, ct; attr=attr)
            ct(idn_get, CPU, Val(:read); timeout=attr.timeoutr)
            return ct, true
        catch e
            @error(
                "[$(now())]\nincorrect instrument settings!!!",
                instrument = string(instrnm, ": ", addr),
                exception = e
            )
            showbacktrace()
            return nothing, false
        finally
            logout!(CPU, ct)
        end
    end
end

function remote_def_prog(func)
    timed_remotecall_wait(workers()[1], func, SYNCSTATES; timeout=60) do func, SYNCSTATES
        try
            eval(func)
        catch e
            SYNCSTATES[IsDAQTaskDone] = true
            @error "[$(now())]\nerrors in program definition!!!" exception = e
            showbacktrace()
        end
    end
end

function remote_runtask(rn)
    remote_do(
        workers()[1], DATABUFRC, PROGRESSRC, EXTRADATABUFRC, SYNCSTATES, rn
    ) do databuf_rc, progress_rc, extradatabuf_rc, syncstates, rn
        try
            remote_do_block(databuf_rc, progress_rc, extradatabuf_rc, syncstates, rn)
        catch e
            syncstates[IsDAQTaskDone] = true
            @error "[$(now())]\nexecuting program failed!!!" exception = e
            showbacktrace()
        end
    end
end

isready_databufrc() = isready(DATABUFRC)
isready_extradatabufrc() = isready(EXTRADATABUFRC)
isready_progressrc() = isready(PROGRESSRC)

take_databufrc!() = take!(DATABUFRC)
take_extradatabufrc!() = take!(EXTRADATABUFRC)
take_progressrc!() = take!(PROGRESSRC)
