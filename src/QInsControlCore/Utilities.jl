macro trycatch(msg, ex)
    esc(
        quote
            try
                $ex
            catch e
                @error string("[", now(), "]\n", $msg) exception = e
                showbacktrace()
            end
        end
    )
end
showbacktrace() = (Base.show_backtrace(LOGIO, catch_backtrace()); println(LOGIO, "\n\r"))
# showbacktrace() = Base.show_backtrace(stdout, catch_backtrace())

function timedwhile(f::Function, timeout::Real)
    t = time()
    while time() - t < timeout
        f() && return true
        yield()
    end
    return false
end

function timedwhilefetch(t::Task, timeout::Real; msg="force to stop task", throwerror=false)
    isok = timedwhile(() -> istaskdone(t), timeout)
    try
        isok || schedule(t, msg; error=true)
        return fetch(t)
    catch e
        @error "fetching task error" exception = e
        throwerror && rethrow()
        return nothing
    end
end
function timedwaitfetch(t::Task, timeout::Real; msg="force to stop", pollint=0.001, quiet=false)
    isok = timedwait(() -> istaskdone(t), timeout; pollint=pollint)
    try
        isok == :ok || schedule(t, msg; error=true)
        return fetch(t)
    catch e
        if !quiet
            @error "[$(now())]\nfetching task error" exception = e
            showbacktrace()
        end
        return nothing
    end
end
function timedwaitwait(t::Task, timeout::Real; msg="force to stop", pollint=0.001, quiet=false)
    isok = timedwait(() -> istaskdone(t), timeout; pollint=pollint)
    try
        isok == :ok || schedule(t, msg; error=true)
        return wait(t)
    catch e
        if !quiet
            @error "[$(now())]\nwaiting for task error" exception = e
            showbacktrace()
        end
        return nothing
    end
end
function timed_remotecall_fetch(f, pid, args...; timeout=2, pollint=0.001, quiet=false, kwargs...)
    future = remotecall(f, pid, args...; kwargs...)
    t = quiet ? @async(fetch(future)) : @async @trycatch "fetch task failed!!!" fetch(future)
    timedwaitfetch(t, timeout; msg="timeout waiting to fetch", pollint=pollint, quiet=quiet)
end
function timed_remotecall_wait(f, pid, args...; timeout=2, pollint=0.001, quiet=false, kwargs...)
    future = remotecall(f, pid, args...; kwargs...)
    t = quiet ? @async(wait(future)) : @async @trycatch "wait task failed!!!" wait(future)
    timedwaitwait(t, timeout; msg="timeout waiting to wait", pollint=pollint, quiet=quiet)
end

function copyattr!(attr1, attr2)
    for fdnm in fieldnames(typeof(attr1))
        setproperty!(attr2, fdnm, getproperty(attr1, fdnm))
    end
end

function packtake!(c, n=12)
    buf = eltype(c)[]
    taking = true
    t = errormonitor(
        @async begin
            t1 = time()
            while taking && time() - t1 < 0.1
                isready(c) ? push!(buf, take!(c)) : yield()
            end
        end
    )
    timedwait(() -> length(buf) > n, 0.01; pollint=0.001)
    taking = false
    wait(t)
    buf
end

macro progress(exfor)
    @gensym pgid pgi pgn tn
    ex = quote
        let
            $pgid = uuid4()
            $pgn = length($(exfor.args[1].args[2]))
            $pgi = 0
            put!(progress_lc, ($pgid, $pgi, $pgn, 0))
            $tn = time()
            for ($pgi, $(exfor.args[1].args[1])) in enumerate($(exfor.args[1].args[2]))
                $(exfor.args[2])
                put!(progress_lc, ($pgid, $pgi, $pgn, time() - $tn))
            end
        end
    end
    esc(ex)
end

macro progress(mark, exfor)
    @gensym pgid pgi pgn tn
    ex = quote
        let
            put!(extradatabuf_lc, ($(string("Marked ", mark)), string.(collect($(exfor.args[1].args[2])))))
            $pgid = uuid4()
            $pgn = length($(exfor.args[1].args[2]))
            $pgi = 0
            put!(progress_lc, ($pgid, $pgi, $pgn, 0))
            $tn = time()
            for ($pgi, $(exfor.args[1].args[1])) in enumerate($(exfor.args[1].args[2]))
                $(exfor.args[2])
                put!(progress_lc, ($pgid, $pgi, $pgn, time() - $tn))
            end
        end
    end
    esc(ex)
end

macro progress(observables, getdatacmd, stop, duration, exwhile)
    @gensym pgid pgi pgn tn fraction val path
    ex = quote
        let
            $val = tryparse(Float64, $getdatacmd)
            isnothing($val) || push!($observables, (time(), $val))
            $pgid = uuid4()
            $pgn = 100
            $pgi = 0
            put!(progress_lc, ($pgid, $pgi, $pgn, 0))
            $tn = time()
            $path = 0
            while $(exwhile.args[1])
                $(exwhile.args[2])
                if !isempty($observables) && time() - $observables[end][1] > $duration
                    $val = tryparse(Float64, $getdatacmd)
                    if !isnothing($val)
                        push!($observables, (time(), $val))
                        length($observables) > 1 && ($path += abs($observables[end][2] - $observables[end-1][2]))
                    end
                end
                $pgi += 1
                $fraction = $path / ($path + abs($stop - $observables[end][2]))
                $pgn = isinf($fraction) || isnan($fraction) || iszero($fraction) ? $pgi + 1 : ceil(Int, $pgi / $fraction)
                $pgi == $pgn && ($pgn = $pgi + 1)
                put!(progress_lc, ($pgid, $pgi, $pgn, time() - $tn))
            end
            put!(progress_lc, ($pgid, $pgn, $pgn, time() - $tn))
            empty!($observables)
        end
    end
    esc(ex)
end

macro gentrycatch(instrnm, addr, cmd, retrysendtimes, retryconnecttimes, len=0)
    esc(
        quote
            let
                state, getval = try
                    true, $cmd
                catch e
                    isbusy(CPU, $addr) || (setbusy!(CPU); unsetbusy!(CPU, $addr))
                    @error(
                        "[$(now())]\ninstrument communication failed!!!",
                        instrument = $(string(instrnm, ": ", addr)),
                        exception = e
                    )
                    showbacktrace()
                    false, $(len == 0 ? "" : fill("", len))
                end
                if !state
                    state, getval = counter($retryconnecttimes) do tout
                        @gencontroller(
                            "retry connecting to instrument", string($instrnm, " ", $addr),
                            (false, $(len == 0 ? "" : fill("", len))), true
                        )
                        state, getval = counter($retrysendtimes) do tin
                            @gencontroller(
                                "retry sending command", string($instrnm, " ", $addr),
                                (false, $(len == 0 ? "" : fill("", len))), true
                            )
                            @warn(
                                string(
                                    "[", now(), "]\n",
                                    "retry sending command", " ", tin, "\n",
                                    "retry reconnecting to instrument", " ", tout
                                ),
                                intrument = string($instrnm, "-", $addr)
                            )
                            state, getval = try
                                true, $cmd
                            catch e
                                @error(
                                    "[$(now())]\ninstrument communication failed!!!",
                                    instrument = $(string(instrnm, ": ", addr)),
                                    exception = e
                                )
                                showbacktrace()
                                false, $(len == 0 ? "" : fill("", len))
                            end
                            return state, getval
                        end
                        SYNCSTATES[IsInterrupted] && return state, getval
                        if !state
                            try
                                reconnect!(CPU)
                            catch
                            end
                        end
                        return state, getval
                    end
                    unsetbusy!(CPU)
                end
                if SYNCSTATES[IsInterrupted]
                    @warn(
                        "[$(now())]\ninterrupt!",
                        "retry connecting and sending command" = string($instrnm, " ", $addr)
                    )
                end
                state ? getval : error(string("instrument ", $instrnm, " ", $addr, " response time out!!!"))
            end
        end
    )
end

function counter(f, times::Integer=3)
    for t in 1:times
        state, val = f(t)
        state && return true, val
    end
    return false, ""
end

macro gencontroller(key, val, retval=nothing, quiet=false)
    esc(
        quote
            if SYNCSTATES[IsInterrupted]
                $quiet || @warn "[$(now())]\ninterrupt!" $key = $val
                return $retval
            elseif SYNCSTATES[IsBlocked]
                @warn "[$(now())]\npause!" $key = $val
                lock(() -> wait(BLOCK), BLOCK)
                @info "[$(now())]\ncontinue!" $key = $val
                if SYNCSTATES[IsInterrupted]
                    $quiet || @warn "[$(now())]\ninterrupt!" $key = $val
                    return $retval
                end
            end
        end
    )
end

logblock() = timed_remotecall_wait(() -> Main.QInsControl.log_instrbufferviewers(), 1; timeout=60)

macro saveblock(key, var)
    esc(
        :(put!(databuf_lc, ($key, string($var))))
    )
end

macro saveblock(var)
    key = string(var)
    esc(
        :(put!(databuf_lc, ($key, string($var))))
    )
end

macro psleep(seconds)
    s1 = floor(seconds)
    s2 = floor(seconds - s1; digits=3) * 1000
    esc(
        quote
            @progress for _ in 1:$s1
                @gencontroller psleep $seconds
                sleep(1)
            end
            for _ in 1:$s2
                sleep(0.001)
            end
        end
    )
end

function timeaverage(data, τ)
    idx = argmin(abs.([data[end][1] - d[1] for d in data] .- τ))
    datasubset = [d[2] for d in data[idx:end]]
    mv = mean(datasubset)
    stdv = stdm(datasubset, mv)
    return mv, stdv
end
function _ismoving(data, δ, τ)
    isempty(data) && return true
    δ, τ = abs(δ), abs(τ)
    data[end][1] - data[1][1] < τ && return true
    _, stdv = timeaverage(data, τ)
    return stdv > 5δ
end
function isarrived(data, target, δ, τ)
    isempty(data) && return false
    δ, τ = abs(δ), abs(τ)
    data[end][1] - data[1][1] < τ && return false
    mv, stdv = timeaverage(data, τ)
    arrive = abs(mv - target) < δ && stdv < 4δ
    arrive && return true
    data[end][1] - data[1][1] < 10τ && return false
    arrive |= abs(mv - target) < 5δ && all(abs.((mv, stdv) .- timeaverage(data, 10τ)) .< δ)
    return arrive
end
function isless(data, target, δ, τ)
    isempty(data) && return false
    δ, τ = abs(δ), abs(τ)
    data[end][1] - data[1][1] < τ && return false
    return timeaverage(data, τ)[1] - target < δ
end
function isgreater(data, target, δ, τ)
    isempty(data) && return false
    δ, τ = abs(δ), abs(τ)
    data[end][1] - data[1][1] < τ && return false
    return timeaverage(data, τ)[1] - target > -δ
end

newfile(filename="") = timed_remotecall_wait(filename -> Main.QInsControl.newfile(filename), 1, filename; timeout=60)

function gensweeplist(start, step, stop; equalstep=true)
    step == 0 && return [start]
    if equalstep
        rawsteps = abs((start - stop) / step)
        ceilsteps = ceil(Int, rawsteps)
        sweepsteps = rawsteps ≈ ceilsteps ? ceilsteps + 1 : ceilsteps
        sweepsteps = sweepsteps == 1 ? 2 : sweepsteps
        sweeplist = range(start, stop, length=sweepsteps)
    else
        step = start < stop ? abs(step) : -abs(step)
        sweeplist = collect(start:step:stop)
        sweeplist[end] == stop || push!(sweeplist, stop)
    end
    return sweeplist
end