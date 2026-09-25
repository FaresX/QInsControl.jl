# 依赖 CImGui 或前端配置 CONF 的通用辅助函数。
# 约束：GenericUtilities 必须保持零 CImGui/CONF 依赖（否则 QInsControlCore 无法
# 引用底层工具、只能复制实现，timedwaitfetch/packtake! 的双份定义就是这么来的），
# 因此凡是碰到 GUI API 或 CONF 的函数一律放本文件。

mousein(regmin, regmax) = inregion(CImGui.GetMousePos(), regmin, regmax)

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

"估算文本按可用宽度自动换行后的行数"
function wraplines(text::AbstractString, availw::Cfloat)
    n = 0
    for para in split(text, '\n')
        n += para == "" ? 1 :
             max(1, ceil(Int, CImGui.CalcTextSize(para).x / max(availw, 50.0f0)))
    end
    return max(n, 1)
end

function isvalidpath(path; file=true)
    if file ? isfile(path) : isdir(path)
        return true
    else
        CImGui.SameLine()
        CImGui.TextColored(
            MORESTYLE.Colors.ErrorText, file ? mlstr("file does not exist!!!") : mlstr("path does not exist!!!")
        )
        return false
    end
end
