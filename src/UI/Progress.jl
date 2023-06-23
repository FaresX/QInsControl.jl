macro progress(exfor)
    @gensym pgid pgi pgn tn
    ex = quote
        let
            $pgid = uuid4()
            $pgn = length(collect($(exfor.args[1].args[2])))
            $pgi = 0
            $tn = time()
            for $(exfor.args[1].args[1]) in $(exfor.args[1].args[2])
                $(exfor.args[2])
                $pgi += 1
                put!(progress_lc, ($pgid, $pgi, $pgn, time() - $tn))
            end
        end
    end
    esc(ex)
end

function tohms(second)
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
    if isready(progress_lc)
        pb = take!(progress_lc)
        haskey(progresslist, pb[1]) || push!(progresslist, pb[1] => pb)
        progresslist[pb[1]] = pb
    end
end
