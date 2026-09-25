function ShowProgressBar(; size=(-1, 0))
    lock(PROGRESSLIST) do PROGRESSLIST
        for key in collect(keys(PROGRESSLIST)) #快照遍历:循环体内 delete! 会打断 Dict 迭代
            pgb = PROGRESSLIST[key]
            if pgb[2] == pgb[3]
                delete!(PROGRESSLIST, key)
            else
                # 显示值指数趋近真实进度,进度条平滑推进(AnimSpeed=0 时直达);
                # 填充部分叠加 AccentTop→AccentBottom 渐变,与 Sweep 按钮进度一致
                sfrac = animto(string(key), calcfraction(pgb[2], pgb[3]))
                ColoredProgressBarRect(
                    sfrac, progressmark(pgb[2:4]...); size,
                    colbara = MORESTYLE.Colors.AccentTop, colbara2 = MORESTYLE.Colors.AccentBottom
                )
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