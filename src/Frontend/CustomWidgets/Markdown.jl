# 轻量 Markdown 渲染器:块级解析(纯 Julia,可独立单测)+ ImGui 渲染,公共 API 为
#   parsemarkdown(content) -> Vector{MDBlock}   解析为块结构
#   markdownview(label, content)                渲染到当前窗口(按 label 缓存解析结果,流式内容只在其变化时重解析)
#   codeblockview(label, code; lang)            代码块查看器(Julia 走 codeview 高亮,其余等宽纯文本)
# 复用 CodeEditor.codeview/_codepalette;标题字号用 PushFont(C_NULL, FontSizeBase*倍率)(ImGui 1.92+ 动态字号,
# 注意必须取 FontSizeBase 而非 GetFontSize(),后者含全局缩放,回传会二次缩放)。
# 支持:ATX 标题、段落、围栏代码块(可未闭合以适配流式输出)、有序/无序列表(嵌套+懒续行)、
#       引用、GFM 表格、分隔线;行内 **粗体** *斜体* ~~删除~~ `行内代码` [链接](url) 与反斜杠转义。
# 单字体限制:粗体用双重描画模拟(仅限未换行片段),斜体不单独着色,删除线/链接下划线用 DrawList 叠画。

struct MDSpan
    text::String
    style::Symbol   #:normal :bold :italic :code :strike :link
    url::String
end
MDSpan(text::AbstractString, style::Symbol=:normal) = MDSpan(String(text), style, "")

abstract type MDBlock end
struct MDParagraph <: MDBlock
    spans::Vector{MDSpan}
end
struct MDHeading <: MDBlock
    level::Int
    spans::Vector{MDSpan}
end
struct MDCode <: MDBlock
    lang::String
    code::String
end
struct MDQuote <: MDBlock
    spans::Vector{MDSpan}
end
struct MDHR <: MDBlock end
struct MDListItem
    level::Int      #0 起嵌套层级
    marker::String  #"-"/"1."等,渲染时原样显示
    spans::Vector{MDSpan}
end
struct MDList <: MDBlock
    items::Vector{MDListItem}
end
struct MDTable <: MDBlock
    header::Vector{Vector{MDSpan}}
    rows::Vector{Vector{Vector{MDSpan}}}
end

# ---------- 行内解析 ----------

_mdwordchar(c) = isletter(c) || isdigit(c) || c == '_'

#标记内容是否为词内位置(词内下划线不作斜体,如 foo_bar_baz)
_mdintraword(s, i) =
    (i > firstindex(s) && _mdwordchar(s[prevind(s, i)])) ||
    (nextind(s, i) <= lastindex(s) && _mdwordchar(s[nextind(s, i)]))

function _mdspans!(spans::Vector{MDSpan}, s::String, style::Symbol, url::String)
    i = firstindex(s)
    n = lastindex(s)
    plainstart = i
    flushplain() = i > plainstart && push!(spans, MDSpan(s[plainstart:prevind(s, i)], style, url))
    while i <= n
        c = s[i]
        if c == '\\' && i < n && s[nextind(s, i)] in "\\`*_[]~("
            flushplain()
            push!(spans, MDSpan(string(s[nextind(s, i)]), style, url))
            i = nextind(s, nextind(s, i))
            plainstart = i
            continue
        elseif c == '`' #反引号串必须等长闭合(findnext 对字符串模式返回匹配区间)
            j = i
            while j <= n && s[j] == '`'
                j = nextind(s, j)
            end
            tick = s[i:prevind(s, j)]
            kr = findnext(tick, s, j)
            if !isnothing(kr)
                flushplain()
                push!(spans, MDSpan(String(strip(s[j:prevind(s, first(kr))])), :code))
                i = nextind(s, last(kr))
                plainstart = i
                continue
            end
        elseif c == '[' #链接 [text](url)
            r = findnext(']', s, nextind(s, i))
            if !isnothing(r)
                after = nextind(s, r)
                p = after <= n && s[after] == '(' ? findnext(')', s, nextind(s, after)) : nothing
                if !isnothing(p)
                    flushplain()
                    _mdspans!(spans, s[nextind(s, i):prevind(s, r)], :link, String(s[nextind(s, after):prevind(s, p)]))
                    i = nextind(s, p)
                    plainstart = i
                    continue
                end
            end
        elseif (c == '*' || c == '_') && i < n && s[nextind(s, i)] == c #**粗体** / __粗体__
            cr = findnext(string(c, c), s, nextind(s, nextind(s, i)))
            if !isnothing(cr)
                flushplain()
                _mdspans!(spans, s[nextind(s, nextind(s, i)):prevind(s, first(cr))], :bold, url)
                i = nextind(s, last(cr))
                plainstart = i
                continue
            end
        elseif c == '~' && i < n && s[nextind(s, i)] == '~' #~~删除~~
            cr = findnext("~~", s, nextind(s, nextind(s, i)))
            if !isnothing(cr)
                flushplain()
                _mdspans!(spans, s[nextind(s, nextind(s, i)):prevind(s, first(cr))], :strike, url)
                i = nextind(s, last(cr))
                plainstart = i
                continue
            end
        elseif (c == '*' || c == '_') && !(c == '_' && _mdintraword(s, i)) #单字符斜体
            closer = findnext(c, s, nextind(s, i))
            if !isnothing(closer)
                inner = s[nextind(s, i):prevind(s, closer)]
                if !isempty(strip(inner)) && !occursin('\n', inner)
                    flushplain()
                    _mdspans!(spans, inner, :italic, url)
                    i = nextind(s, closer)
                    plainstart = i
                    continue
                end
            end
        end
        i = nextind(s, i)
    end
    flushplain()
    spans
end

_mdparseinline(s::AbstractString) = _mdspans!(MDSpan[], String(s), :normal, "")

# ---------- 块级解析 ----------

_mdtablesep(l) = begin
    cells = split(l, '|')
    nonempty = filter(c -> !isempty(strip(c)), cells)
    length(nonempty) >= 1 && all(c -> !isnothing(match(r"^:?-+:?$", strip(c))), nonempty)
end

function _mdcells(l)
    s = String(strip(l))
    startswith(s, '|') && (s = s[nextind(s, firstindex(s)):end])
    endswith(s, '|') && !isempty(s) && (s = s[1:prevind(s, lastindex(s))])
    [_mdparseinline(strip(c)) for c in split(s, '|')]
end

#块起始行:空行/标题/围栏/引用/分隔线/列表项(段落与列表懒续行的终止条件)
_mdblockstart(l) =
    isempty(strip(l)) ||
    !isnothing(match(r"^\s{0,3}(#{1,6}\s|```|>|(?:[-*_]\s*){3,}$|[-*+]\s|\d{1,9}[.)]\s)", l))

function parsemarkdown(content::AbstractString)
    text = replace(String(content), "\r\n" => "\n")
    lines = split(text, '\n'; keepempty=true)
    blocks = MDBlock[]
    n = length(lines)
    i = 1
    while i <= n
        line = lines[i]
        isempty(strip(line)) && (i += 1; continue)
        m = match(r"^\s{0,3}```+\s*([[:alnum:]#+-]*)\s*$", line) #围栏代码块(允许未闭合以适配流式输出)
        if !isnothing(m)
            lang = String(m[1])
            i += 1
            buf = String[]
            while i <= n && isnothing(match(r"^\s{0,3}```+\s*$", lines[i]))
                push!(buf, String(lines[i]))
                i += 1
            end
            i <= n && (i += 1)
            push!(blocks, MDCode(lang, join(buf, '\n')))
            continue
        end
        m = match(r"^\s{0,3}(#{1,6})\s+(.+?)(?:\s+#+\s*)?$", line) #ATX 标题,允许尾部井号闭合
        if !isnothing(m)
            push!(blocks, MDHeading(length(m[1]), _mdparseinline(String(m[2]))))
            i += 1
            continue
        end
        if occursin('|', line) && i < n && _mdtablesep(lines[i + 1]) #GFM 表格
            header = _mdcells(line)
            i += 2
            rows = Vector{Vector{MDSpan}}[]
            while i <= n && !isempty(strip(lines[i])) && occursin('|', lines[i])
                push!(rows, _mdcells(lines[i]))
                i += 1
            end
            push!(blocks, MDTable(header, rows))
            continue
        end
        if !isnothing(match(r"^\s{0,3}([-*_])(?:\s*\1){2,}\s*$", line)) #分隔线
            push!(blocks, MDHR())
            i += 1
            continue
        end
        if !isnothing(match(r"^\s{0,3}>", line)) #引用(连续行并为一段)
            buf = String[]
            while i <= n && !isnothing(match(r"^\s{0,3}>", lines[i]))
                push!(buf, strip(replace(String(lines[i]), r"^\s{0,3}>\s?" => "")))
                i += 1
            end
            push!(blocks, MDQuote(_mdparseinline(join(filter(!isempty, buf), " "))))
            continue
        end
        m = match(r"^(\s*)([-*+]|\d{1,9}[.)])(\s+)(.*)$", String(line)) #列表(嵌套+懒续行)
        if !isnothing(m)
            items = MDListItem[]
            while i <= n
                mi = match(r"^(\s*)([-*+]|\d{1,9}[.)])(\s+)(.*)$", String(lines[i]))
                if !isnothing(mi)
                    indent = mapreduce(c -> c == '\t' ? 4 : 1, +, collect(mi[1]); init=0)
                    push!(items, MDListItem(min(div(indent, 2), 3), String(mi[2]), _mdparseinline(String(mi[4]))))
                    i += 1
                elseif !isempty(strip(lines[i])) && !_mdblockstart(lines[i]) && !isempty(items)
                    last = items[end]
                    push!(last.spans, MDSpan(" "))
                    append!(last.spans, _mdparseinline(String(strip(lines[i]))))
                    i += 1
                else
                    break
                end
            end
            push!(blocks, MDList(items))
            continue
        end
        buf = String[String(strip(line))] #段落:连续非空行并入,空行/块起始/表格头终止
        i += 1
        while i <= n && !isempty(strip(lines[i])) && !_mdblockstart(lines[i]) &&
              !(occursin('|', lines[i]) && i < n && _mdtablesep(lines[i + 1]))
            push!(buf, String(strip(lines[i])))
            i += 1
        end
        push!(blocks, MDParagraph(_mdparseinline(join(buf, " "))))
    end
    blocks
end

# ---------- 渲染 ----------

const MDVIEWS = Dict{UInt,Tuple{UInt,Vector{MDBlock}}}() #解析缓存,按 ImGui ID 缓存(内容哈希,变更才重解析)

_mdbasefont() = unsafe_load(IMGUISTYLE.FontSizeBase)

function markdownview(label, content::AbstractString)
    id = CImGui.GetID(label)
    h = hash(content)
    cached = get(MDVIEWS, id, nothing)
    if isnothing(cached) || cached[1] != h
        length(MDVIEWS) > 96 && empty!(MDVIEWS)
        cached = (h, parsemarkdown(content))
        MDVIEWS[id] = cached
    end
    CImGui.PushID(label)
    CImGui.PushTextWrapPos()
    for b in cached[2]
        _mdrender!(b)
    end
    CImGui.PopTextWrapPos()
    CImGui.PopID()
    nothing
end

#把行内文本切成最小断行单元:ASCII 连续段为一词(标点粘连成词),非 ASCII(CJK/符号)逐字可断,空格折叠
#按片段文本缓存切分结果(渲染每帧执行,长对话下避免重复切分与分配)
const MDTOKENS = Dict{String,Vector{Tuple{String,Bool}}}()
function _mdtokens(s::AbstractString)
    get!(MDTOKENS, String(s)) do
        length(MDTOKENS) > 8192 && empty!(MDTOKENS)
        toks = Tuple{String,Bool}[] #(文本, 是否空格)
        buf = IOBuffer()
        flush() = position(buf) == 0 || push!(toks, (String(take!(buf)), false))
        for c in s
            if c == ' ' || c == '\t'
                flush()
                (isempty(toks) || !toks[end][2]) && push!(toks, (" ", true))
            elseif c < Char(0x80)
                print(buf, c)
            else
                flush()
                push!(toks, (string(c), false))
            end
        end
        flush()
        toks
    end
end

#token 宽度缓存:流式会话每帧都要重新排版,按(字号,文本)缓存测量结果
const MDWIDTHS = Dict{Tuple{Cfloat,String},Cfloat}()
function _mdwidth(tok::String, fs::Cfloat)
    get!(MDWIDTHS, (fs, tok)) do
        length(MDWIDTHS) > 16384 && empty!(MDWIDTHS)
        CImGui.CalcTextSize(tok).x
    end
end

#行内片段序列渲染:自行断行排版。不用 ImGui 的跨行 Text/SameLine 续行(两者都会把续行
#画在片段起始 x 或首行 y 上,见 AIAssistant 文件头注释),而是把文本切成最小断行单元,
#逐词实测宽度、行满显式 NewLine()——每个 Text 片段都保证单行,续行恒从行首开始。
function _mdrenderline!(spans::Vector{MDSpan})
    isempty(spans) && return
    textcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    linkcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextLink)
    framebg = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
    codecol = [_codepalette(framebg).string..., 1.0]
    fs = CImGui.GetFontSize()
    linew = 0.0f0     #当前行已用宽度
    budget = 0.0f0    #当前行可用宽度(行首时读取)
    linestart = true
    for sp in spans
        col = sp.style == :code ? codecol :
              sp.style == :link ? linkcol :
              sp.style == :strike ? textcol .* 0.65 .+ framebg .* 0.35 : textcol
        for (tok, isspace) in _mdtokens(sp.text)
            w = _mdwidth(tok, fs)
            if !linestart && linew + w > budget + 0.5f0
                #上个 Text 渲染完光标已自动落到下一行行首(y 已加行高+ItemSpacing.y),
                #此处只回退行间 ItemSpacing.y,使行距与原生 Text 内部换行一致;不可再调 NewLine(会双重行进)
                CImGui.SetCursorPosY(CImGui.GetCursorPosY() - unsafe_load(IMGUISTYLE.ItemSpacing.y))
                linestart = true
                isspace && continue #断行处的空格丢弃
            end
            if linestart
                budget = CImGui.GetContentRegionAvail().x
                isspace && continue #行首空格丢弃
                linew = 0.0f0
            else
                CImGui.SameLine(0, 0)
            end
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, col)
            CImGui.Text(tok)
            CImGui.PopStyleColor()
            linew += w
            linestart = false
            rmin = CImGui.GetItemRectMin()
            rmax = CImGui.GetItemRectMax()
            dl = CImGui.GetWindowDrawList()
            if sp.style == :bold
                CImGui.AddText(
                    dl, (rmin.x + 0.7f0, rmin.y), _u32(col),
                    reinterpret(Ptr{Cchar}, pointer(tok)),
                    reinterpret(Ptr{Cchar}, pointer(tok, sizeof(tok) + 1))
                )
            elseif sp.style == :strike
                y = (rmin.y + rmax.y) / 2
                CImGui.AddLine(dl, (rmin.x, y), (rmax.x, y), _u32(col))
            elseif sp.style == :link
                CImGui.AddLine(dl, (rmin.x, rmax.y - 1), (rmax.x, rmax.y - 1), _u32(linkcol))
                if CImGui.IsItemHovered()
                    isempty(sp.url) || CImGui.SetItemTooltip(sp.url)
                    CImGui.IsMouseClicked(0) && !isempty(sp.url) && Threads.@spawn DefaultApplication.open(sp.url)
                end
            end
        end
    end
    nothing
end

_mdspacing!() = CImGui.Dummy((Cfloat(0), CImGui.GetFontSize() * 0.3f0))

function _mdrender!(p::MDParagraph)
    _mdrenderline!(p.spans)
    _mdspacing!()
end

function _mdrender!(h::MDHeading)
    base = _mdbasefont()
    f = (1.5, 1.34, 1.2, 1.1, 1.0, 1.0)[clamp(h.level, 1, 6)]
    CImGui.PushFont(C_NULL, base * f)
    _mdrenderline!(h.spans)
    CImGui.PopFont()
    CImGui.Dummy((Cfloat(0), base * 0.25f0))
end

function _mdrender!(q::MDQuote)
    isempty(q.spans) && return
    p0 = CImGui.GetCursorScreenPos()
    CImGui.Indent(CImGui.GetFontSize())
    textcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    framebg = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, textcol .* 0.8 .+ framebg .* 0.2)
    _mdrenderline!(q.spans)
    CImGui.PopStyleColor()
    CImGui.Unindent()
    p1 = CImGui.GetCursorScreenPos()
    CImGui.AddRectFilled(
        CImGui.GetWindowDrawList(), p0, (p0.x + 3, p1.y - unsafe_load(IMGUISTYLE.ItemSpacing.y)),
        _u32(CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextLink))
    )
    _mdspacing!()
end

function _mdrender!(l::MDList)
    base = CImGui.GetFontSize()
    lastlevel = 0
    for item in l.items
        item.level > lastlevel && CImGui.Indent(base * (item.level - lastlevel) * 1.5)
        item.level < lastlevel && CImGui.Unindent(base * (lastlevel - item.level) * 1.5)
        lastlevel = item.level
        occursin(r"^\d", item.marker) ? CImGui.Text(item.marker) : CImGui.Bullet()
        CImGui.SameLine(0, 0)
        _mdrenderline!(item.spans)
    end
    lastlevel > 0 && CImGui.Unindent(base * lastlevel * 1.5)
    _mdspacing!()
end

function _mdrender!(t::MDTable)
    ncols = length(t.header)
    ncols == 0 && return
    if CImGui.BeginTable(
        "##mdtable", ncols,
        CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_RowBg | CImGui.ImGuiTableFlags_SizingStretchProp
    )
        CImGui.TableNextRow()
        for (j, cell) in enumerate(t.header)
            CImGui.TableSetColumnIndex(j - 1) && _mdrenderline!(cell)
        end
        for row in t.rows
            CImGui.TableNextRow()
            for j in 1:ncols
                CImGui.TableSetColumnIndex(j - 1) && (j <= length(row) && _mdrenderline!(row[j]))
            end
        end
        CImGui.EndTable()
    end
    _mdspacing!()
end

_mdrender!(::MDHR) = CImGui.Separator()

"代码块查看器:Julia 系走 codeview 高亮,其余等宽字体纯文本;高度自适应,超 24 行框内滚动"
function codeblockview(label, code::AbstractString; lang="")
    body = replace(rstrip(String(code), ['\n', '\r']), "\r\n" => "\n")
    nlines = count('\n', body) + 1
    h = min(nlines, 24) * Cfloat(CImGui.GetTextLineHeight()) + 2unsafe_load(IMGUISTYLE.FramePadding.y) + 2f0
    if lowercase(strip(lang)) in ("julia", "jl")
        codeview(label, body, (Cfloat(0), Cfloat(h)); linenumbers=false)
    else
        usemono = CODEFONT != C_NULL
        usemono && CImGui.PushFont(CODEFONT, 0)
        CImGui.BeginChild(label, (Cfloat(0), Cfloat(h)), CImGui.ImGuiChildFlags_FrameStyle, CImGui.ImGuiWindowFlags_None)
        CImGui.TextUnformatted(body)
        CImGui.EndChild()
        usemono && CImGui.PopFont()
    end
    nothing
end

function _mdrender!(c::MDCode)
    codeblockview("##mdcode", c.code; lang=c.lang)
    _mdspacing!()
end
