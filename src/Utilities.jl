macro trypasse(sv, default)
    code = string("@trypasse ", sv, " ", default)
    ex = quote
        let
            x = nothing
            try
                x = $sv
            catch e
                @error "$(now())\nerror in @trypass" exception = e code = $code
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
    for _ in 1:n
        isready(c) && push!(buf, take!(c))
    end
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
        haskey(oldtime, id) || push!(oldtime, id => time())
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
        ss[i] = " "^Int((ml - lengthpr(line)) ÷ 2spacel) * line
    end
    join(ss, '\n')
end

max_with_empty(x) = isempty(x) ? zero(eltype(x)) : max(x...)

function newkey!(dict::OrderedDict, oldkey, newkey)
    newdict = OrderedDict()
    for p in dict
        if p.first != oldkey
            push!(newdict, p)
        else
            push!(newdict, newkey => p.second)
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
            push!(newdict, key2 => dict[key2])
        elseif p.first == key2
            push!(newdict, key1 => dict[key1])
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

function Base.getproperty(x::Ptr{LibCImGui.Style}, f::Symbol)
    f === :grid_spacing && return Ptr{Cfloat}(x + 0)
    f === :node_corner_rounding && return Ptr{Cfloat}(x + 4)
    f === :node_padding_horizontal && return Ptr{Cfloat}(x + 8)
    f === :node_padding_vertical && return Ptr{Cfloat}(x + 12)
    f === :node_border_thickness && return Ptr{Cfloat}(x + 16)
    f === :link_thickness && return Ptr{Cfloat}(x + 20)
    f === :link_line_segments_per_length && return Ptr{Cfloat}(x + 24)
    f === :link_hover_distance && return Ptr{Cfloat}(x + 28)
    f === :pin_circle_radius && return Ptr{Cfloat}(x + 32)
    f === :pin_quad_side_length && return Ptr{Cfloat}(x + 36)
    f === :pin_triangle_side_length && return Ptr{Cfloat}(x + 40)
    f === :pin_line_thickness && return Ptr{Cfloat}(x + 44)
    f === :pin_hover_radius && return Ptr{Cfloat}(x + 48)
    f === :pin_offset && return Ptr{Cfloat}(x + 52)
    f === :flags && return Ptr{UInt32}(x + 56)
    f === :colors && return Ptr{NTuple{16,Cuint}}(x + 60)
    return getfield(x, f)
end

Base.setproperty!(x::Ptr{LibCImGui.Style}, f::Symbol, v) = unsafe_store!(getproperty(x, f), v)

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

function uniformz!(x, y, z)
    zyl, zxl = size(z)
    if length(y) == zyl
        miny, maxy = extrema(y)
        if miny != maxy
            @views for j in axes(z, 2)
                lineary = range(miny, maxy, length=zyl)
                interp = LinearInterpolation(z[:, j], y)
                z[:, j] = interp.(lineary)
            end
        end
    end
    if length(x) == zxl
        minx, maxx = extrema(x)
        if minx != maxx
            @views for i in axes(z, 1)
                linearx = range(minx, maxx, length=zxl)
                interp = LinearInterpolation(z[i, :], x)
                z[i, :] = interp.(linearx)
            end
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
    r = (i + lv.index - 1) % l |> abs
    return r == 0 ? l : r
end
Base.getindex(lv::LoopVector, i=1) = lv.data[__find_index(lv, i)]
Base.setindex!(lv::LoopVector, x, i=1) = (lv.data[__find_index(lv, i)] = x)

move!(lv::LoopVector, i=1) = (lv.index += i)

function waittofetch(f, δ=2; sleeptime=0.001)
    waittask = errormonitor(@async fetch(f))
    t1 = time()
    while time() - t1 < δ
        istaskdone(waittask) && return istaskfailed(waittask) ? nothing : fetch(waittask)
        sleep(sleeptime)
        yield()
    end
    return nothing
end