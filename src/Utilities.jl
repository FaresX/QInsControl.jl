macro trypasse(sv, default)
    code = string("@trypasse ", sv, " ", default)
    ex = quote
        let
            x = nothing
            try
                x = $sv
            catch e
                @error "$(now())\nerror in @trypass" exception = e code = $code
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

function packtake!(c, n=12)
    buf = eltype(c)[]
    taking = true
    t = errormonitor(
        @async while taking
            isready(c) ? push!(buf, take!(c)) : yield()
        end
    )
    timedwait(() -> length(buf) > n, 0.01; pollint=0.001)
    taking = false
    wait(t)
    buf
end

function resize(z, m, n; fillms=0)
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
    return (x, y)
end

let
    oldtime::Dict{String,Float64} = Dict()
    global function waittime(id, δt=1)
        haskey(oldtime, id) || (oldtime[id] = time())
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

function Base.iterate(v::Union{ImVec2,ImPlot.ImPlotPoint}, state=1)
    if state == 1
        return v.x, 2
    elseif state == 2
        return v.y, 3
    else
        return nothing
    end
end
function Base.getindex(v::Union{ImVec2,ImPlot.ImPlotPoint}, i)
    if i == 1
        return v.x
    elseif i == 2
        return v.y
    else
        throw(BoundsError(v, i))
    end
end
Base.length(::Union{ImVec2,ImPlot.ImPlotPoint}) = 2
function Base.getindex(v::ImVec4, i)
    if i == 1
        return v.x
    elseif i == 2
        return v.y
    elseif i == 3
        return v.z
    elseif i == 4
        return v.w
    else
        throw(BoundsError(v, i))
    end
end

function Base.getproperty(x::Ptr{LibCImGui.ImNodesStyle}, f::Symbol)
    f === :GridSpacing && return Ptr{Cfloat}(x + 0)
    f === :NodeCornerRounding && return Ptr{Cfloat}(x + 4)
    f === :NodePadding && return Ptr{ImVec2}(x + 8)
    f === :NodeBorderThickness && return Ptr{Cfloat}(x + 16)
    f === :LinkThickness && return Ptr{Cfloat}(x + 20)
    f === :LinkLineSegmentsPerLength && return Ptr{Cfloat}(x + 24)
    f === :LinkHoverDistance && return Ptr{Cfloat}(x + 28)
    f === :PinCircleRadius && return Ptr{Cfloat}(x + 32)
    f === :PinQuadSideLength && return Ptr{Cfloat}(x + 36)
    f === :PinTriangleSideLength && return Ptr{Cfloat}(x + 40)
    f === :PinLineThickness && return Ptr{Cfloat}(x + 44)
    f === :PinHoverRadius && return Ptr{Cfloat}(x + 48)
    f === :PinOffset && return Ptr{Cfloat}(x + 52)
    f === :MiniMapPadding && return Ptr{ImVec2}(x + 56)
    f === :MiniMapOffset && return Ptr{ImVec2}(x + 64)
    f === :Flags && return Ptr{UInt32}(x + 72)
    f === :Colors && return Ptr{NTuple{29,Cuint}}(x + 76)
    return getfield(x, f)
end

Base.setproperty!(x::Ptr{LibCImGui.ImNodesStyle}, f::Symbol, v) = unsafe_store!(getproperty(x, f), v)

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

function synccall_wait(f, ids, args...)
    f(args...)
    for i in ids
        remotecall_wait(f, i, args...)
    end
end

function uniformx!(x, z)
    zxl = size(z, 2)
    if length(x) == zxl
        linearx = range(extrema(x)..., length=zxl)
        @views for i in axes(z, 1)
            interp = LinearInterpolation(z[i, :], x; extrapolate=true)
            z[i, :] = interp.(linearx)
        end
    end
end

function uniformy!(y, z)
    zyl = size(z, 1)
    if length(y) == zyl
        lineary = range(extrema(y)..., length=zyl)
        @views for j in axes(z, 2)
            interp = LinearInterpolation(z[:, j], y; extrapolate=true)
            z[:, j] = interp.(lineary)
        end
    end
end

mutable struct LoopVector{T}
    data::Vector{T}
    index::Integer
    LoopVector{T}(::UndefInitializer, len) where {T} = new(Vector{T}(undef, len), 1)
    LoopVector(vec::Vector{T}) where {T} = new{T}(vec, 1)
end

Base.length(lv::LoopVector) = length(lv.data)
function __find_index(lv::LoopVector, i)
    l = length(lv)
    r = (i + lv.index) % l |> abs
    return r == 0 ? l : r
end
Base.getindex(lv::LoopVector, i=0) = lv.data[__find_index(lv, i)]
Base.setindex!(lv::LoopVector, x, i=0) = (lv.data[__find_index(lv, i)] = x)

move!(lv::LoopVector, i=1) = (lv.index += i)

Base.push!(lv::LoopVector, x) = push!(lv.data, x)

function waittofetch(f, timeout=2; pollint=0.001)
    waittask = errormonitor(@async fetch(f))
    isok = timedwait(() -> istaskdone(waittask), timeout; pollint=pollint)
    isok == :ok && return fetch(waittask)
    return nothing
end

function wait_remotecall_fetch(f, id::Integer, args...; timeout=2, pollint=0.001, kwargs...)
    future = remotecall_fetch(f, id, args...; kwargs...)
    waittask = @async @trycatch mlstr("fetch task failed!!!") fetch(future)
    isok = timedwait(() -> istaskdone(waittask), timeout; pollint=pollint)
    isok == :ok && return fetch(waittask)
    return nothing
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
function isarrived(data, target, δ, τ)
    data[end][1] - data[1][1] < τ && return false
    arrive = abs(timeaverage(data, τ)[1] - target) < δ
    arrive && return true
    data[end][1] - data[1][1] < 10τ && return false
    arrive |= abs(timeaverage(data, τ)[1] - target) < 5δ && all(abs.(timeaverage(data, τ) .- timeaverage(data, 10τ)) .< δ)
    return arrive
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
    availwidth = CImGui.GetContentRegionAvailWidth()
    itemspacing = unsafe_load(IMGUISTYLE.ItemSpacing)
    cols = floor(Int, availwidth / (maxwidth + itemspacing.x))
    cols == 0 && (cols = 1)
    lb = length(labels)
    labelwidth = cols > lb ? maxwidth : (availwidth - (cols - 1) * itemspacing.x) / cols
    return cols, labelwidth
end

function imgsampling(x, y; num=100000)
    if num > 1000
        xl, yl = length(x), length(y)
        xidxleft = round.(Int, range(1, xl, length=min(num, xl)))
        yidxleft = round.(Int, range(1, yl, length=min(num, yl)))
        return x[xidxleft], y[yidxleft]
    else
        return x, y
    end
end

function imgsampling(x, y, z; num=100000)
    if num > 1000
        scale = √(num / length(z))
        xl, yl = size(z)
        nxl, nyl = round.(Int, (xl, yl) .* scale)
        z_reducex = similar(z, nxl, yl)
        linearx = range(extrema(x)..., length=nxl)
        @views for i in axes(z, 2)
            interp = LinearInterpolation(z[:, i], x; extrapolate=true)
            z_reducex[:, i] = interp.(linearx)
        end
        nz = similar(z_reducex, nxl, nyl)
        lineary = range(extrema(y)..., length=nyl)
        @views for j in axes(z_reducex, 1)
            interp = LinearInterpolation(z_reducex[j, :], y; extrapolate=true)
            nz[j, :] = interp.(lineary)
        end
        return linearx, lineary, nz
    else
        return x, y, z
    end
end

function resizefill!(sv::Vector{String}, n; fillv="")
    resize!(sv, n)
    for i in eachindex(sv)
        isassigned(sv, i) || (sv[i] = fillv)
    end
end