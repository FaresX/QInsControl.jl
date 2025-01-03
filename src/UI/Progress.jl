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

function update_progress()
    if isready(PROGRESSRC)
        packpb = take!(PROGRESSRC)
        for pb in packpb
            haskey(PROGRESSLIST, pb[1]) || (PROGRESSLIST[pb[1]] = pb)
            PROGRESSLIST[pb[1]] = pb
        end
    end
end

let
    dellist::Vector{UUID} = []
    global function ShowProgressBar(; size=(-1, 0))
        for (key, pgb) in PROGRESSLIST
            if pgb[2] == pgb[3]
                push!(dellist, key)
            else
                CImGui.ProgressBar(calcfraction(pgb[2], pgb[3]), size, progressmark(pgb[2:4]...))
            end
        end
        isempty(dellist) || (map(x -> delete!(PROGRESSLIST, x), dellist); empty!(dellist))
    end
end

calcfraction(i, n) = n == 0 ? 0 : i / n
function progressmark(i, n, t; notimes=false, notime=false)
    if notimes && !notime
        string(tohms(t), "/", tohms(n * t / i))
    elseif !notimes && notime
        string(i, "/", n)
    elseif notimes && notime
        ""
    else
        string(i, "/", n, "(", tohms(t), "/", tohms(n * t / i), ")")
    end
end