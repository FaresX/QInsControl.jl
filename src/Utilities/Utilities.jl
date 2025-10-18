macro trypasse(sv, default)
    code = string("@trypasse ", sv, " ", default)
    ex = quote
        let
            x = nothing
            try
                x = $sv
            catch e
                @error "[$(now())]\nerror in @trypass" exception = e code = $code
                showbacktrace()
                x = $default
            end
            x
        end
    end
    esc(ex)
end
macro trypass(sv, default)
    ex = quote
        let
            x = nothing
            try
                x = $sv
            catch
                x = $default
            end
            x
        end
    end
    esc(ex)
end
showbacktrace() = (Base.show_backtrace(LOGIO, catch_backtrace()); println(LOGIO, "\n\r"))
# showbacktrace() = rethrow()
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

function parsedollar(str)
    ms = collect(eachmatch(r"(\$\w*)", str))
    if isempty(ms)
        return str
    else
        ls, rs = split(str, ms[1][1])
        sv = Expr(:string, ls, Symbol(lstrip(ms[1][1], '\$')))
        for m in ms[2:end-1]
            ls, rs = split(rs, m[1])
            sv = Expr(:string, sv, ls, Symbol(lstrip(m[1], '\$')))
        end
        sv = Expr(:string, sv, rs)
        return sv
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

function resize(z, m, n; fillms=NaN)
    return if length(z) > m * n
        @views reshape(z[1:m*n], m, n)
    else
        @views reshape([reshape(z, :); fill(fillms, m * n - length(z))], m, n)
    end
end

inregion(location, regmin, regmax) = regmin[1] < location[1] < regmax[1] && regmin[2] < location[2] < regmax[2]
mousein(regmin, regmax) = inregion(CImGui.GetMousePos(), regmin, regmax)
function cutoff(location, regmin, regmax)
    x = if location[1] < regmin[1]
        regmin[1]
    elseif regmin[1] <= location[1] < regmax[1]
        location[1]
    else
        regmax[1]
    end
    y = if location[2] < regmin[2]
        regmin[2]
    elseif regmin[2] <= location[2] < regmax[2]
        location[2]
    else
        regmax[2]
    end
    return [x, y]
end

let
    oldtime::Dict{String,Float64} = Dict()
    global function waittime(id, δt=1)
        haskey(oldtime, id) || (oldtime[id] = time(); return true)
        newtime = time()
        trig = newtime - oldtime[id] > δt
        trig && (oldtime[id] = newtime)
        trig
    end
end

function wrapmultiline(s::AbstractString, n)
    msg = split(s, '\n')
    for (i, s) in enumerate(msg)
        length(s) > n && (msg[i] = wrapmsg(s, n))
    end
    join(msg, '\n')
end

function wrapmsg(s::AbstractString, n)
    ss = String[]
    sbf = ""
    for c in s
        sbf *= c
        if length(sbf) >= n
            push!(ss, sbf)
            sbf = ""
        end
    end
    sbf == "" || push!(ss, sbf)
    return join(ss, '\n')
end

# lengthpr(c::Char) = ncodeunits(c) == 1 ? 1 : 2
# lengthpr(s::AbstractString) = s == "" ? 0 : sum(lengthpr(c) for c in s)
lengthpr(s::AbstractString) = s == "" ? Cfloat(0) : CImGui.CalcTextSize(s).x / CImGui.GetFontSize()

function centermultiline(s)
    ss = string.(split(s, '\n'))
    ml = max_with_empty(lengthpr.(ss))
    spacel = CImGui.CalcTextSize(" ").x / CImGui.GetFontSize()
    for (i, line) in enumerate(ss)
        line == "" && continue
        ns = (ml - lengthpr(line)) ÷ 2spacel
        ss[i] = " "^(isnan(ns) || ns < 0 ? 0 : round(Int, ns)) * line
    end
    join(ss, '\n')
end

max_with_empty(x) = isempty(x) ? zero(eltype(x)) : max(x...)

function newkey!(dict::AbstractDict, oldkey, newkey)
    newdict = typeof(dict)()
    for p in dict
        if p.first != oldkey
            push!(newdict, p)
        else
            newdict[newkey] = p.second
        end
    end
    empty!(dict)
    merge!(dict, newdict)
end

function Base.insert!(dict::OrderedDict, key, item; after=false)
    newdict = OrderedDict()
    for p in dict
        if p.first != key
            push!(newdict, p)
        else
            if after
                push!(newdict, p)
                push!(newdict, item)
            else
                push!(newdict, item)
                push!(newdict, p)
            end
        end
    end
    empty!(dict)
    merge!(dict, newdict)
end

function idxkey(dict::OrderedDict, idx)
    for (i, p) in enumerate(dict)
        i == idx && return p.first
    end
end

function setvalue!(dict::OrderedDict, key, item)
    newdict = OrderedDict()
    for p in dict
        if p.first == key
            push!(newdict, item)
        else
            push!(newdict, p)
        end
    end
    empty!(dict)
    merge!(dict, newdict)
end

function swapvalue!(dict::OrderedDict, key1, key2)
    newdict = OrderedDict()
    for p in dict
        if p.first == key1
            newdict[key2] = dict[key2]
        elseif p.first == key2
            newdict[key1] = dict[key1]
        else
            push!(newdict, p)
        end
    end
    empty!(dict)
    merge!(dict, newdict)
end

function newtuple(t::Tuple, i, v)
    newt = []
    for (j, val) in enumerate(t)
        if j == i
            push!(newt, v)
        else
            push!(newt, val)
        end
    end
    return (newt...,)
end

reencoding(s, encoding) = @trypasse decode(unsafe_wrap(Array, pointer(s), ncodeunits(s)), encoding) s

function synccall_wait(f, ids, args...; timeout=2)
    f(args...)
    for i in ids
        timed_remotecall_wait(f, i, args...; timeout=timeout)
    end
end

function timed_remotecall_fetch(f, id::Integer, args...; timeout=2, pollint=0.001, quiet=false, kwargs...)
    future = remotecall(f, id, args...; kwargs...)
    t = quiet ? @async(fetch(future)) : @async @trycatch mlstr("fetch task failed!!!") fetch(future)
    timedwaitfetch(t, timeout; msg=mlstr("timeout waiting to fetch"), pollint=pollint, quiet=quiet)
end

function timed_remotecall_wait(f, id::Integer, args...; timeout=2, pollint=0.001, quiet=false, kwargs...)
    future = remotecall(f, id, args...; kwargs...)
    t = quiet ? @async(fetch(future)) : @async @trycatch mlstr("fetch task failed!!!") wait(future)
    timedwaitfetch(t, timeout; msg=mlstr("timeout waiting for future"), pollint=pollint, quiet=quiet)
end

function counter(f, times::Integer=3)
    for t in 1:times
        state, val = f(t)
        state && return true, val
    end
    return false, ""
end

function gensweeplist(start, step, stop)
    if CONF.DAQ.equalstep
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

function strtoU(ustr::AbstractString)
    str = occursin(" ", ustr) ? replace(ustr, " " => "*") : ustr
    str == "" ? "" : eval(:(@u_str($str)))
end

function getU(utype, uidx::Ref{Int})
    Us = haskey(CONF.U, utype) ? CONF.U[utype] : [""]
    if uidx[] == 0
        uidx[] = 1
    elseif abs(uidx[]) > length(Us)
        uidx[] = abs(uidx[]) % length(Us)
        uidx[] == 0 && (uidx[] = length(Us))
    end
    return Us[uidx[]], Us
end

function calcmaxwidth(labels, padding=0)
    maxwidth = max([CImGui.CalcTextSize(label).x for label in labels]...) + padding
    availwidth = CImGui.GetContentRegionAvail().x
    itemspacing = unsafe_load(IMGUISTYLE.ItemSpacing)
    cols = floor(Int, availwidth / (maxwidth + itemspacing.x))
    cols == 0 && (cols = 1)
    lb = length(labels)
    labelwidth = cols > lb ? maxwidth : (availwidth - (cols - 1) * itemspacing.x) / cols
    return cols, labelwidth
end

function resizefill!(sv::Vector{String}, n; fillv="")
    resize!(sv, n)
    for i in eachindex(sv)
        isassigned(sv, i) || (sv[i] = fillv)
    end
end

function resizebool!(v::Vector{Bool}, n)
    lv = length(v)
    resize!(v, n)
    lv < n && @views v[lv+1:n] .= false
    return v
end