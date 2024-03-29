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
            haskey(PROGRESSLIST, pb[1]) || push!(PROGRESSLIST, pb[1] => pb)
            PROGRESSLIST[pb[1]] = pb
        end
    end
end

function ShowProgressBar(; size=(-1, 0))
    for pgb in values(PROGRESSLIST)
        if pgb[2] == pgb[3]
            delete!(PROGRESSLIST, pgb[1])
        else
            CImGui.ProgressBar(calcfraction(pgb[2], pgb[3]), size, progressmark(pgb[2:4]...))
        end
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