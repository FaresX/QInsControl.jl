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

function ShowProgressBar(; size=(-1, 0))
    lock(PROGRESSLIST) do PROGRESSLIST
        for (key, pgb) in PROGRESSLIST
            if pgb[2] == pgb[3]
                delete!(PROGRESSLIST, key)
            else
                CImGui.ProgressBar(calcfraction(pgb[2], pgb[3]), size, progressmark(pgb[2:4]...))
            end
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