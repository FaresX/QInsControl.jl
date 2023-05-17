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

resize(z, m, n; fillms=0) = if length(z) > m * n
    reshape(z[1:m*n], m, n)
else
    reshape([reshape(z, :); fill(fillms, m * n - length(z))], m, n)
end

inregion(location, region) = region[1] < location.x < region[3] && region[2] < location.y < region[4]
mousein(region) = inregion(CImGui.GetMousePos(), region)

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

function transposeimg(img)
    tpimg = similar(img, reverse(size(img))...)
    for j in axes(img, 2)
        @views tpimg[j, :] = img[:, j]
    end
    tpimg
end

lengthpr(c::Char) = ncodeunits(c) == 1 ? 1 : 2
lengthpr(s::AbstractString) = s == "" ? 0 : sum(lengthpr(c) for c in s)

function centermultiline(s)
    ss = split(s, '\n')
    ml = max(lengthpr.(ss)...)
    for (i, line) in enumerate(ss)
        line == "" && continue
        ss[i] = " "^((ml - lengthpr(line)) ÷ 2) * line
    end
    join(ss, '\n')
end

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

-(a::CImGui.ImVec2, b::CImGui.ImVec2) = CImGui.ImVec2(a.x - b.x, a.y - b.y)
+(a::CImGui.ImVec2, b::CImGui.ImVec2) = CImGui.ImVec2(a.x + b.x, a.y + b.y)
/(a::CImGui.ImVec2, b) = CImGui.ImVec2(a.x/b, a.y/b)


###Patch###
Base.convert(::Type{OrderedDict{String,T}}, vec::Vector{T}) where T = OrderedDict(string(i) => v for (i, v) in enumerate(vec))

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
    f === :colors && return Ptr{NTuple{16, Cuint}}(x + 60)
    return getfield(x, f)
end

function Base.setproperty!(x::Ptr{LibCImGui.Style}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
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