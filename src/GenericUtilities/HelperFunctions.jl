macro trypasse(sv, default)
    code = string("@trypasse ", sv, " ", default)
    ex = quote
        let
            x = nothing
            try
                x = $sv
            catch e
                @error "[$(now())]\nerror in @trypasse" exception = e code = $code
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

function parsedollar(str)
    #把 "$var" 替换为插值表达式:按正则切分原文与变量名后交错拼接。
    #不能逐个 split 解包:变量重复出现时解包数量不定会抛错,且漏掉最后一个 $var
    ms = collect(eachmatch(r"\$\w+", str))
    if isempty(ms)
        return str
    else
        parts = split(str, r"\$\w+"; keepempty=true) #长度恒为 length(ms)+1
        sv = Expr(:string)
        for (i, m) in enumerate(ms)
            push!(sv.args, parts[i], Symbol(m.match[2:end]))
        end
        push!(sv.args, parts[end])
        return sv
    end
end

function resize(z, m, n; fillms=NaN)
    return if length(z) > m * n
        @views reshape(z[1:m*n], m, n)
    else
        @views reshape([reshape(z, :); fill(fillms, m * n - length(z))], m, n)
    end
end

inregion(location, regmin, regmax) = regmin[1] < location[1] < regmax[1] && regmin[2] < location[2] < regmax[2]
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

max_with_empty(x) = isempty(x) ? zero(eltype(x)) : max(x...)

function newkey!(dict::OrderedDict, oldkey, newkey)
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

function strtoU(ustr::AbstractString)
    str = occursin(" ", ustr) ? replace(ustr, " " => "*") : ustr
    str == "" ? "" : eval(:(@u_str($str)))
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

function equallen(x...)
    minl = minimum(length.(x))
    return Tuple(Base.view(xi, 1:minl) for xi in x)
end

function tohms(second)
    isnan(second) && return string("--", ":", "--", ":", "--")
    s = round(Int, second)
    m, s = divrem(s, 60)
    h, m = divrem(m, 60)
    s = round(Int, s)
    ss = s < 10 ? string(0, s) : string(s)
    ms = m < 10 ? string(0, m) : string(m)
    hs = h < 10 ? string(0, h) : string(h)
    string(hs, ":", ms, ":", ss)
end
