# 轻量代码编辑器/查看器:DrawList 自绘渲染 + Julia 风格分词高亮
# 用于替代 InputTextMultiline 的代码编辑场景:后者强制自动换行且无法叠加语法高亮
# 编辑缓冲为纯 Julia 实现(光标/选区/撤销/自动缩进),字符输入读 InputQueueCharacters(与 IME 兼容),
# 剪贴板经 ImGui 接口与系统互通;编辑操作不依赖 ImGui,可独立单测
# 渲染不假设等宽字体:逐 token 实测宽度定位,分词与行切分仅在文本变化时重建

# ---------- 分词 ----------

struct CodeSpan
    first::Int32 #该行内起始字符索引(1-based,含)
    last::Int32 #结束字符索引(含)
    kind::UInt8
end

const CODE_NORMAL = 0x00
const CODE_KEYWORD = 0x01
const CODE_STRING = 0x02
const CODE_CHARLIT = 0x03
const CODE_COMMENT = 0x04
const CODE_NUMBER = 0x05
const CODE_MACRO = 0x06
const CODE_FUNC = 0x07
const CODE_OPERATOR = 0x08

const CODE_KEYWORDS = Set(split(
    "baremodule begin break catch const continue do else elseif end export false finally for function " *
    "global if import in isa let local macro module mutable new primitive quote return struct true try " *
    "type using where while abstract outer"
))

_isidentstart(c) = isletter(c) || c == '_'
_isidents(c) = isletter(c) || isdigit(c) || c == '_' || c == '!'
_iswordchar(c) = isletter(c) || isdigit(c) || c == '_'
_isplain(c) = !_isidentstart(c) && !isdigit(c) && c != '"' && c != '\'' && c != '#' && c != '@' && !isspace(c)

#单行分词,追加到 spans;state = (三引号字符串内, 块注释深度) 跨行携带
function codetokenize!(spans::Vector{CodeSpan}, cs::Vector{Char}, state::Ref{Tuple{Bool,Int}})
    empty!(spans)
    intriple, blockdepth = state[]
    n = length(cs)
    i = 1
    while i <= n
        if blockdepth > 0 #块注释内容,支持 #= 嵌套,行尾未闭合则延续到下一行
            j = i
            while j <= n
                if cs[j] == '#' && j < n && cs[j+1] == '='
                    blockdepth += 1
                    j += 2
                elseif cs[j] == '=' && j < n && cs[j+1] == '#'
                    blockdepth -= 1
                    j += 2
                    blockdepth == 0 && break
                else
                    j += 1
                end
            end
            push!(spans, CodeSpan(i, min(j, n), CODE_COMMENT))
            i = j
        elseif intriple #三引号字符串内容,行尾未闭合则延续
            j = i
            while j + 2 <= n && !(cs[j] == '"' && cs[j+1] == '"' && cs[j+2] == '"')
                j += 1
            end
            if j + 2 <= n
                j += 3
                intriple = false
            else
                j = n + 1
            end
            push!(spans, CodeSpan(i, min(j, n), CODE_STRING))
            i = j
        else
            c = cs[i]
            if c == '#' && i < n && cs[i+1] == '='
                blockdepth = 1
                i += 2
            elseif c == '#'
                push!(spans, CodeSpan(i, n, CODE_COMMENT))
                i = n + 1
            elseif c == '"' && i + 2 <= n && cs[i+1] == '"' && cs[i+2] == '"'
                j = i + 3
                while j + 2 <= n && !(cs[j] == '"' && cs[j+1] == '"' && cs[j+2] == '"')
                    j += 1
                end
                if j + 2 <= n
                    j += 3
                else
                    intriple = true
                    j = n + 1
                end
                push!(spans, CodeSpan(i, min(j, n), CODE_STRING))
                i = j
            elseif c == '"'
                j = i + 1
                while j <= n
                    if cs[j] == '\\'
                        j += 2
                    elseif cs[j] == '"' || cs[j] == '\n'
                        break
                    else
                        j += 1
                    end
                end
                j = min(j, n)
                cs[j] == '"' && (j += 1)
                push!(spans, CodeSpan(i, min(j, n), CODE_STRING))
                i = j
            elseif c == '\''
                j = i + 1
                while j <= n
                    if cs[j] == '\\'
                        j += 2
                    elseif cs[j] == '\'' || cs[j] == '\n'
                        break
                    else
                        j += 1
                    end
                end
                j = min(j, n)
                cs[j] == '\'' && (j += 1)
                push!(spans, CodeSpan(i, min(j, n), CODE_CHARLIT))
                i = j
            elseif isdigit(c)
                j = i + 1
                if c == '0' && j <= n && cs[j] in "xXbBoO"
                    hex = cs[j] in "xX"
                    j += 1
                    while j <= n && (isdigit(cs[j]) || (hex && cs[j] in "abcdefABCDEF") || cs[j] == '_')
                        j += 1
                    end
                else
                    while j <= n && (isdigit(cs[j]) || cs[j] in "_eE.")
                        j += 1
                    end
                end
                push!(spans, CodeSpan(i, j - 1, CODE_NUMBER))
                i = j
            elseif c == '@'
                j = i + 1
                while j <= n && _isidents(cs[j])
                    j += 1
                end
                push!(spans, CodeSpan(i, j - 1, CODE_MACRO))
                i = j
            elseif _isidentstart(c)
                j = i + 1
                while j <= n && _isidents(cs[j])
                    j += 1
                end
                kind = String(cs[i:j-1]) in CODE_KEYWORDS ? CODE_KEYWORD : CODE_NORMAL
                if kind == CODE_NORMAL #后随 "(" 视作函数调用
                    k = j
                    while k <= n && isspace(cs[k])
                        k += 1
                    end
                    k <= n && cs[k] == '(' && (kind = CODE_FUNC)
                end
                push!(spans, CodeSpan(i, j - 1, kind))
                i = j
            elseif isspace(c)
                push!(spans, CodeSpan(i, i, CODE_NORMAL))
                i += 1
            else #连续标点/运算符合并为一个 span
                j = i
                while j <= n && _isplain(cs[j])
                    j += 1
                end
                push!(spans, CodeSpan(i, j - 1, CODE_OPERATOR))
                i = j
            end
        end
    end
    state[] = (intriple, blockdepth)
    spans
end

codetokenize!(spans::Vector{CodeSpan}, line::AbstractString, state::Ref{Tuple{Bool,Int}}) =
    codetokenize!(spans, collect(line), state)

# ---------- 编辑器状态(纯 Julia,不依赖 ImGui) ----------

mutable struct CodeEditor
    buf::Vector{Char}
    cur::Int #光标插入点(1-based buf 索引,允许 length+1)
    anchor::Int #选区锚点(== cur 时无选区)
    dcol::Int #上下移动时的期望列
    rows::Int #翻页行数(渲染时按窗口高度更新)
    undos::Vector{Tuple{Vector{Char},Int,Int}} #(快照, cur, anchor)
    redos::Vector{Tuple{Vector{Char},Int,Int}}
    lastop::Float64
    lastmerge::Bool
    lastkind::Symbol
    active::Bool
    wantscroll::Bool #光标移动后需滚动可见
    valid::Bool #渲染缓存与 buf 同步
    lines::Vector{String}
    linestarts::Vector{Int} #各行在 buf 中的起始索引
    linebytes::Vector{Vector{Int}} #各行字符→字节偏移(渲染定位用)
    spans::Vector{Vector{CodeSpan}}
    buildid::Int
    measuredid::Int
    maxwidth::Float32
    ext::String #上次同步的外部字符串
end

function CodeEditor(text::AbstractString="")
    buf = collect(String(text))
    CodeEditor(
        buf, 1, 1, 1, 20, Tuple{Vector{Char},Int,Int}[], Tuple{Vector{Char},Int,Int}[],
        0.0, false, :other, false, false, false,
        [""], [1], [[ ]], [CodeSpan[]], 0, -1, 1.0f0, String(text)
    )
end

# ---------- 纯逻辑操作 ----------

_lcbuf(ed, ix) = begin
    line = 1
    start = 1
    @inbounds for i in 1:ix-1
        if ed.buf[i] == '\n'
            line += 1
            start = i + 1
        end
    end
    line, ix - start + 1
end
_colbuf(ed, ix) = _lcbuf(ed, ix)[2]

function _lineboundsbuf(ed, ix)
    ls = min(ix, length(ed.buf) + 1)
    while ls > 1 && ed.buf[ls-1] != '\n'
        ls -= 1
    end
    e = ix
    while e <= length(ed.buf) && ed.buf[e] != '\n'
        e += 1
    end
    ls, e - 1
end

_nlinesbuf(ed) = 1 + count(==('\n'), ed.buf)

function _indexofbuf(ed, line, col)
    ix = 1
    for _ in 2:line
        while ix <= length(ed.buf) && ed.buf[ix] != '\n'
            ix += 1
        end
        ix += 1
    end
    e = ix
    while e <= length(ed.buf) && ed.buf[e] != '\n'
        e += 1
    end
    ix + clamp(col - 1, 0, e - ix)
end

function _pushundo!(ed; merge=false, kind=:other)
    now = time()
    if merge && ed.lastmerge && kind == ed.lastkind && now - ed.lastop < 0.8
        ed.lastop = now
        return
    end
    push!(ed.undos, (copy(ed.buf), ed.cur, ed.anchor))
    length(ed.undos) > 128 && popfirst!(ed.undos)
    empty!(ed.redos)
    ed.lastop = now
    ed.lastmerge = merge
    ed.lastkind = kind
end

function _undo!(ed)
    isempty(ed.undos) && return false
    push!(ed.redos, (copy(ed.buf), ed.cur, ed.anchor))
    length(ed.redos) > 128 && popfirst!(ed.redos)
    ed.buf, ed.cur, ed.anchor = pop!(ed.undos)
    ed.valid = false
    ed.lastmerge = false
    ed.wantscroll = true
    true
end

function _redo!(ed)
    isempty(ed.redos) && return false
    push!(ed.undos, (copy(ed.buf), ed.cur, ed.anchor))
    ed.buf, ed.cur, ed.anchor = pop!(ed.redos)
    ed.valid = false
    ed.lastmerge = false
    ed.wantscroll = true
    true
end

function _deleterange!(ed; push=true)
    ed.anchor == ed.cur && return false
    push && _pushundo!(ed; kind=:del)
    lo = min(ed.anchor, ed.cur)
    hi = max(ed.anchor, ed.cur)
    deleteat!(ed.buf, lo:hi-1)
    ed.cur = lo
    ed.anchor = lo
    ed.valid = false
    ed.wantscroll = true
    true
end

function _inserttext!(ed, s::AbstractString)
    chars = collect(replace(replace(String(s), "\r\n" => "\n"), '\r' => '\n'))
    isempty(chars) && return false
    hadsel = ed.anchor != ed.cur
    _pushundo!(ed; merge=!hadsel && length(chars) == 1 && chars[1] ∉ ('\n', '\t'), kind=:ins)
    hadsel && _deleterange!(ed; push=false)
    splice!(ed.buf, ed.cur:ed.cur-1, chars)
    ed.cur += length(chars)
    ed.anchor = ed.cur
    ed.valid = false
    ed.wantscroll = true
    true
end

_inserttext!(ed, c::Char) = _inserttext!(ed, string(c))

function _backspace!(ed)
    if ed.anchor != ed.cur
        _pushundo!(ed; kind=:del)
        _deleterange!(ed; push=false)
        return true
    end
    ed.cur == 1 && return false
    _pushundo!(ed; merge=ed.buf[ed.cur-1] != '\n', kind=:del)
    deleteat!(ed.buf, ed.cur - 1)
    ed.cur -= 1
    ed.anchor = ed.cur
    ed.valid = false
    ed.wantscroll = true
    true
end

function _deletefwd!(ed)
    if ed.anchor != ed.cur
        _pushundo!(ed; kind=:del)
        _deleterange!(ed; push=false)
        return true
    end
    ed.cur > length(ed.buf) && return false
    _pushundo!(ed; merge=ed.buf[ed.cur] != '\n', kind=:del)
    deleteat!(ed.buf, ed.cur)
    ed.anchor = ed.cur
    ed.valid = false
    ed.wantscroll = true
    true
end

#换行 + 复制当前行缩进
function _newlinetext(ed)
    ls, le = _lineboundsbuf(ed, ed.cur)
    io = IOBuffer()
    print(io, '\n')
    for i in ls:min(le, ed.cur - 1)
        (ed.buf[i] == ' ' || ed.buf[i] == '\t') || break
        print(io, ed.buf[i])
    end
    String(take!(io))
end

#选区覆盖的行范围(选区终点恰在行首时不含末行,与 VS Code 一致)
function _sellines(ed)
    lo = min(ed.anchor, ed.cur)
    hi = max(ed.anchor, ed.cur)
    l1, _ = _lcbuf(ed, lo)
    l2, c2 = _lcbuf(ed, hi)
    c2 == 1 && hi > lo && (l2 -= 1)
    l1, l2, lo, hi
end

#按方向恢复选区(修改后 lo/hi 为选区两个端点)
function _restoresel!(ed, lo, hi)
    if ed.cur < ed.anchor
        ed.cur, ed.anchor = lo, hi
    else
        ed.cur, ed.anchor = hi, lo
    end
    ed.valid = false
    ed.wantscroll = true
    ed.lastmerge = false
    nothing
end

#Tab:选区内各行整体右缩进(VS Code)
function _indentlines!(ed)
    l1, l2, lo, hi = _sellines(ed)
    _pushundo!(ed; kind=:ins)
    for l in l2:-1:l1 #倒序插入,避免行首索引偏移
        ls = _indexofbuf(ed, l, 1)
        splice!(ed.buf, ls:ls-1, ['\t'])
        lo >= ls && (lo += 1)
        hi >= ls && (hi += 1)
    end
    _restoresel!(ed, lo, hi)
    true
end

#Shift+Tab:选区内各行整体左缩进(去掉一个 \t 或至多 4 个前导空格)
function _dedentlines!(ed)
    l1, l2, lo, hi = _sellines(ed)
    changed = false
    for l in l1:l2
        ls, le = _lineboundsbuf(ed, _indexofbuf(ed, l, 1))
        ls > le && continue
        n = if ed.buf[ls] == '\t'
            1
        else
            m = 0
            while m < 4 && ls + m <= le && ed.buf[ls+m] == ' '
                m += 1
            end
            m
        end
        n == 0 && continue
        changed || (_pushundo!(ed; kind=:del); changed = true)
        deleteat!(ed.buf, ls:ls+n-1)
        lo > ls && (lo = max(ls, lo - n))
        hi > ls && (hi = max(ls, hi - n))
    end
    changed || return false
    _restoresel!(ed, lo, hi)
    true
end

#Ctrl+/:切换选区内各行行注释(全部已注释则去注释,否则全部注释;空行跳过)
function _togglecomment!(ed)
    l1, l2, lo, hi = _sellines(ed)
    infos = Tuple{Int,Int,Int,Int,Bool}[]
    for l in l1:l2
        ls, le = _lineboundsbuf(ed, _indexofbuf(ed, l, 1))
        i = ls
        while i <= le && isspace(ed.buf[i])
            i += 1
        end
        i > le && continue
        push!(infos, (l, ls, le, i, ed.buf[i] == '#'))
    end
    isempty(infos) && return false
    allcommented = all(x -> x[5], infos)
    _pushundo!(ed; kind=:ins)
    for (_, ls, le, i, iscomment) in reverse(infos)
        if allcommented && iscomment
            n = i + 1 <= le && ed.buf[i+1] == ' ' ? 2 : 1 #连同 # 后的一个空格
            deleteat!(ed.buf, i:i+n-1)
            lo > i && (lo = max(ls, lo - n))
            hi > i && (hi = max(ls, hi - n))
        else
            splice!(ed.buf, i:i-1, ['#', ' '])
            lo >= i && (lo += 2)
            hi >= i && (hi += 2)
        end
    end
    _restoresel!(ed, lo, hi)
    true
end

function _move!(ed, ix; select=false)
    ed.cur = clamp(ix, 1, length(ed.buf) + 1)
    select || (ed.anchor = ed.cur)
    ed.dcol = _colbuf(ed, ed.cur)
    ed.wantscroll = true
    nothing
end

function _moveleft!(ed, select)
    if !select && ed.anchor != ed.cur
        ed.cur = min(ed.anchor, ed.cur)
    elseif ed.cur > 1
        ed.cur -= 1
    end
    select || (ed.anchor = ed.cur)
    ed.dcol = _colbuf(ed, ed.cur)
    ed.wantscroll = true
    nothing
end

function _moveright!(ed, select)
    if !select && ed.anchor != ed.cur
        ed.cur = max(ed.anchor, ed.cur)
    elseif ed.cur <= length(ed.buf)
        ed.cur += 1
    end
    select || (ed.anchor = ed.cur)
    ed.dcol = _colbuf(ed, ed.cur)
    ed.wantscroll = true
    nothing
end

function _vertical!(ed, delta, select)
    line, col = _lcbuf(ed, ed.cur)
    ed.dcol == 0 && (ed.dcol = col)
    tline = clamp(line + delta, 1, _nlinesbuf(ed))
    if tline == line
        select || (ed.anchor = ed.cur)
        return
    end
    ed.cur = _indexofbuf(ed, tline, ed.dcol)
    select || (ed.anchor = ed.cur)
    ed.wantscroll = true
    nothing
end

function _wordleftix(ed)
    i = ed.cur - 1
    while i > 1 && !_iswordchar(ed.buf[i])
        i -= 1
    end
    while i > 1 && _iswordchar(ed.buf[i-1])
        i -= 1
    end
    max(i, 1)
end

function _wordrightix(ed)
    n = length(ed.buf)
    i = ed.cur
    while i <= n && !_iswordchar(ed.buf[i])
        i += 1
    end
    while i <= n && _iswordchar(ed.buf[i])
        i += 1
    end
    min(i, n + 1)
end

function _selectword!(ed)
    n = length(ed.buf)
    (ed.cur <= n && _iswordchar(ed.buf[ed.cur])) || return false
    a = ed.cur
    while a > 1 && _iswordchar(ed.buf[a-1])
        a -= 1
    end
    b = ed.cur
    while b <= n && _iswordchar(ed.buf[b])
        b += 1
    end
    ed.anchor = a
    ed.cur = b
    true
end

function _selectiontext(ed)
    if ed.anchor == ed.cur #无选区时复制当前行
        ls, le = _lineboundsbuf(ed, ed.cur)
        return le < ls ? "" : String(ed.buf[ls:le])
    end
    String(ed.buf[min(ed.anchor, ed.cur):max(ed.anchor, ed.cur)-1])
end

#渲染缓存重建(纯 Julia,不含 ImGui 调用)
function _rebuild!(ed)
    text = String(ed.buf)
    ed.lines = String.(split(text, '\n'; keepempty=true))
    n = length(ed.lines)
    ed.linestarts = Vector{Int}(undef, n)
    ed.linebytes = Vector{Vector{Int}}(undef, n)
    ed.spans = [CodeSpan[] for _ in 1:n]
    state = Ref((false, 0))
    ix = 1
    for i in 1:n
        line = ed.lines[i]
        ed.linestarts[i] = ix
        ed.linebytes[i] = length(line) == 0 ? Int[] : [nextind(line, 0, c) for c in 1:length(line)]
        codetokenize!(ed.spans[i], line, state)
        ix += length(line) + 1
    end
    ed.buildid += 1
    ed.valid = true
    nothing
end

function _reload!(ed, text)
    ed.buf = collect(String(text))
    ed.cur = 1
    ed.anchor = 1
    ed.dcol = 1
    empty!(ed.undos)
    empty!(ed.redos)
    ed.valid = false
    ed.ext = String(text)
    nothing
end

# ---------- 渲染 ----------

#按编辑区背景亮度取深/浅两套配色(参考 VS Code Dark+/Light+)
function _codepalette(bg)
    lum = 0.2126bg[1] + 0.7152bg[2] + 0.0722bg[3]
    if lum < 0.5
        (
            keyword=(0.78, 0.53, 0.76), string=(0.81, 0.57, 0.47), charlit=(0.71, 0.72, 0.47),
            comment=(0.42, 0.6, 0.33), number=(0.71, 0.81, 0.66), mac=(0.31, 0.79, 0.69),
            func=(0.86, 0.86, 0.67)
        )
    else
        (
            keyword=(0.69, 0.05, 0.85), string=(0.64, 0.19, 0.08), charlit=(0.55, 0.35, 0.05),
            comment=(0.0, 0.48, 0.0), number=(0.04, 0.53, 0.35), mac=(0.15, 0.5, 0.6),
            func=(0.47, 0.37, 0.15)
        )
    end
end

function _codecolor(pal, kind, textu32)
    col = kind == CODE_KEYWORD ? pal.keyword :
        kind == CODE_STRING ? pal.string :
        kind == CODE_CHARLIT ? pal.charlit :
        kind == CODE_COMMENT ? pal.comment :
        kind == CODE_NUMBER ? pal.number :
        kind == CODE_MACRO ? pal.mac :
        kind == CODE_FUNC ? pal.func : nothing
    col === nothing && return textu32
    CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(col[1], col[2], col[3], 1))
end

_u32(c) = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(c[1], c[2], c[3], length(c) > 3 ? c[4] : 1))

#行内前 k 个字符的像素宽度(0 返回 0)
#注意:必须用 CalcTextSize(与 AddText 渲染同源),不要用烘焙字形 advance——
#多视口下后者含主视口 DPI 缩放,与子视口实际渲染尺寸不一致
function _prefixwidth(ed, row, k)
    k <= 0 && return 0.0f0
    line = ed.lines[row]
    bytes = ed.linebytes[row]
    #指针需越过第 k 个字符(bytes[k+1]),否则量到的是前 k-1 个字符,整体左移一格
    p = k >= length(line) ? sizeof(line) + 1 : bytes[k+1]
    CImGui.CalcTextSize(line, pointer(line, p)).x
end

const CODEEDITORS = Dict{UInt,CodeEditor}() #编辑器状态,按 ImGui ID 缓存
const CODEVIEWS = Dict{UInt,CodeEditor}()

#只读高亮查看器
function codeview(label, text::AbstractString, size=(0, 0); linenumbers=true)
    ed = get!(() -> CodeEditor(text), CODEVIEWS, CImGui.GetID(label))
    text == ed.ext || _reload!(ed, text)
    _drawcode!(ed, label, size; editable=false, linenumbers)
    nothing
end

#代码编辑器,绑定 Ref{String}(与 @c 宏的 &field 写回语义兼容),返回本帧内容是否有改动
function codeedit(label, str::Ref{String}, size=(0, 0); editable=true, linenumbers=true)
    ed = get!(() -> CodeEditor(str[]), CODEEDITORS, CImGui.GetID(label))
    str[] == ed.ext || _reload!(ed, str[])
    changed = _drawcode!(ed, label, size; editable, linenumbers)
    changed && (str[] = String(ed.buf))
    ed.ext = str[]
    changed
end

function _drawcode!(ed, label, size; editable, linenumbers=true)
    ed.valid || _rebuild!(ed)
    #等宽字体已配置时整个编辑器(测量与绘制)使用之:字符等宽,光标与字形严格对齐
    usemono = CODEFONT != C_NULL
    usemono && CImGui.PushFont(CODEFONT, 0)
    #文本未变化时跳过整行宽度测量
    if ed.measuredid != ed.buildid
        w = 1.0f0
        for line in ed.lines
            w = max(w, CImGui.CalcTextSize(line).x)
        end
        ed.maxwidth = w
        ed.measuredid = ed.buildid
    end
    lineheight = CImGui.GetTextLineHeight()
    framebg = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
    textcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    pal = _codepalette(framebg)
    textu32 = _u32(textcol)
    selu32 = _u32(CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextSelectedBg))
    curlineu32 = _u32(framebg .+ (textcol .- framebg) .* 0.07)
    gutteru32 = _u32(framebg .+ (textcol .- framebg) .* 0.45)
    blink = (CImGui.GetTime() * 1.4) % 1.2 < 0.8
    nlines = length(ed.lines)
    gw = Cfloat(0)
    if linenumbers
        gw = CImGui.CalcTextSize("0"^max(2, ndigits(nlines))).x + 2unsafe_load(IMGUISTYLE.ItemSpacing.x)
    end
    changed = false
    if CImGui.BeginChild(label, size, CImGui.ImGuiChildFlags_FrameStyle, CImGui.ImGuiWindowFlags_None)
        origin0 = CImGui.GetCursorScreenPos()
        CImGui.SetCursorPosX(gw) #行号栏留位
        cwin = CImGui.BeginChild(
            "##codearea", (0, 0), CImGui.ImGuiChildFlags_None, CImGui.ImGuiWindowFlags_HorizontalScrollbar
        )
        local origin
        local scrollY
        if cwin
            origin = CImGui.GetCursorScreenPos()
            availw = CImGui.GetContentRegionAvail().x
            # 内容至少填满可视高:不足一屏时内层底部会剩"最后不满一行"的余量,
            # 与顶部(仅外层 FrameStyle 的 FramePadding)不对称,视觉上是底部一块留白
            CImGui.InvisibleButton("##codearea", (max(ed.maxwidth + 2unsafe_load(IMGUISTYLE.FramePadding.x), availw), max(nlines * lineheight, CImGui.GetWindowSize().y)))
            ed.rows = max(3, floor(Int, CImGui.GetWindowSize().y / lineheight))
            editable && (changed = _handleitem!(ed, origin, lineheight))
            ed.valid || _rebuild!(ed)
            _drawlines!(ed, origin, lineheight; editable, pal, textu32, selu32, curlineu32, blink)
            editable && ed.active && ed.wantscroll && _scrolltocursor!(ed, lineheight)
            scrollY = CImGui.GetScrollY()
        end
        CImGui.EndChild()
        cwin && linenumbers && _drawgutter!(ed, origin, scrollY, gw, gutteru32, lineheight)
        CImGui.EndChild()
    else
        CImGui.EndChild()
    end
    usemono && CImGui.PopFont()
    changed
end

#可见行绘制:当前行高亮、选区、token 着色、光标
function _drawlines!(ed, origin, lineheight; editable, pal, textu32, selu32, curlineu32, blink)
    nlines = length(ed.lines)
    wpos = CImGui.GetWindowPos()
    wsz = CImGui.GetWindowSize()
    scrollY = CImGui.GetScrollY()
    firstline = max(1, floor(Int, scrollY / lineheight))
    lastline = min(nlines, firstline + ceil(Int, wsz.y / lineheight) + 1)
    dl = CImGui.GetWindowDrawList()
    hassel = ed.anchor != ed.cur
    lo = hassel ? min(ed.anchor, ed.cur) : 0
    hi = hassel ? max(ed.anchor, ed.cur) : 0
    curline = _lineof(ed)
    for i in firstline:lastline
        line = ed.lines[i]
        y = origin.y + (i - 1) * lineheight
        ls = ed.linestarts[i]
        le = ls + length(line)
        editable && ed.active && !hassel && i == curline &&
            CImGui.AddRectFilled(dl, (wpos.x, y), (wpos.x + wsz.x, y + lineheight), curlineu32)
        if hassel && hi >= ls && lo <= le + 1
            a = max(lo, ls)
            b = min(hi, le + 1)
            x0 = origin.x + _prefixwidth(ed, i, a - ls)
            x1 = origin.x + _prefixwidth(ed, i, b - ls)
            CImGui.AddRectFilled(dl, (x0, y), (x1, y + lineheight), selu32)
        end
        bytes = ed.linebytes[i]
        for sp in ed.spans[i]
            x0 = origin.x + _prefixwidth(ed, i, sp.first - 1)
            # pointer 返回 Ptr{UInt8},wrapper 的 text 参数只接受 Ptr{Int8}/Ptr{Nothing}
            #每个 span 只绘制自己的字节区间,避免相邻 span 重叠
            pb = reinterpret(Ptr{Cchar}, pointer(line, bytes[sp.first]))
            pe = sp.last >= length(line) ? sizeof(line) + 1 : bytes[sp.last+1]
            CImGui.AddText(dl, (x0, y), _codecolor(pal, sp.kind, textu32), pb, reinterpret(Ptr{Cchar}, pointer(line, pe)))
        end
    end
    if editable && ed.active && blink
        col = ed.cur - ed.linestarts[curline] + 1
        y = origin.y + (curline - 1) * lineheight
        x = origin.x + _prefixwidth(ed, curline, col - 1)
        cw = 1.5f0 * CImGui.GetWindowDpiScale()
        CImGui.AddRectFilled(dl, (x, y), (x + cw, y + lineheight), textu32)
    end
    nothing
end

_lineof(ed) = searchsortedlast(ed.linestarts, ed.cur)

#外层 child 上的行号栏(不随水平滚动)
function _drawgutter!(ed, origin, scrollY, gw, gutteru32, lineheight)
    gw == 0 && return
    nlines = length(ed.lines)
    dl = CImGui.GetWindowDrawList()
    firstline = max(1, floor(Int, scrollY / lineheight))
    lastline = min(nlines, firstline + ceil(Int, CImGui.GetWindowSize().y / lineheight) + 1)
    for i in firstline:lastline
        num = string(i)
        y = origin.y + (i - 1) * lineheight
        x = origin.x - unsafe_load(IMGUISTYLE.WindowPadding.x) - CImGui.CalcTextSize(num).x - 2
        CImGui.AddText(dl, (x, y), gutteru32, num)
    end
    nothing
end

function _scrolltocursor!(ed, lineheight)
    ed.wantscroll = false
    l = _lineof(ed)
    col = ed.cur - ed.linestarts[l] + 1
    y0 = (l - 1) * lineheight
    sy = CImGui.GetScrollY()
    h = CImGui.GetWindowSize().y
    y0 < sy ? CImGui.SetScrollY(y0) : (y0 + lineheight > sy + h) && CImGui.SetScrollY(y0 + lineheight - h)
    x0 = _prefixwidth(ed, l, col - 1)
    sx = CImGui.GetScrollX()
    w = CImGui.GetWindowSize().x
    x0 < sx ? CImGui.SetScrollX(max(0, x0 - 30)) : (x0 + 30 > sx + w) && CImGui.SetScrollX(x0 + 30 - w)
    nothing
end

# ---------- 交互输入 ----------

function _handleitem!(ed, origin, lineheight)
    changed = false
    if CImGui.IsItemHovered()
        if CImGui.IsItemActivated()
            ed.active = true
            _cursortomouse!(ed, origin, lineheight; anchor=true)
        elseif CImGui.IsItemActive() && CImGui.IsMouseDown(0)
            _cursortomouse!(ed, origin, lineheight; anchor=false) #拖拽选区
        end
        if CImGui.IsMouseDoubleClicked(0)
            _cursortomouse!(ed, origin, lineheight; anchor=true)
            _selectword!(ed)
        end
    end
    #点击编辑区外取消激活(滚动条等区域内点击除外)
    ed.active && CImGui.IsMouseClicked(0) && !CImGui.IsItemHovered() && !CImGui.IsWindowHovered() && (ed.active = false)
    ed.active || return changed
    changed = _handlekeys!(ed)
    CImGui.SetNextFrameWantCaptureKeyboard(true)
    _setimepos!(ed, origin, lineheight)
    changed
end

function _cursortomouse!(ed, origin, lineheight; anchor)
    m = CImGui.GetMousePos()
    row = clamp(floor(Int, (m.y - origin.y) / lineheight) + 1, 1, length(ed.lines))
    line = ed.lines[row]
    len = length(line)
    col = 1
    if len > 0
        dx = m.x - origin.x
        prev = 0.0f0
        for c in 1:len
            w = _prefixwidth(ed, row, c)
            dx < (prev + w) / 2 && break
            prev = w
            col = c + 1
        end
    end
    ed.cur = clamp(ed.linestarts[row] + col - 1, 1, length(ed.buf) + 1)
    anchor && (ed.anchor = ed.cur)
    nothing
end

function _inputchars!(ed)
    io = CImGui.GetIO()
    q = unsafe_load(io.InputQueueCharacters)
    q.Size == 0 && return false
    changed = false
    for i in 1:q.Size
        c = Char(unsafe_load(q.Data, i))
        c < ' ' && continue #控制字符(含 \t \n)由按键路径处理
        changed = _inserttext!(ed, c) || changed
    end
    changed
end

function _handlekeys!(ed)
    changed = false
    ctrl = CImGui.IsKeyDown(CImGui.ImGuiMod_Ctrl)
    shift = CImGui.IsKeyDown(CImGui.ImGuiMod_Shift)
    if ctrl
        CImGui.IsKeyPressed(CImGui.ImGuiKey_A) && (ed.anchor = 1; ed.cur = length(ed.buf) + 1; ed.wantscroll = true)
        CImGui.IsKeyPressed(CImGui.ImGuiKey_C) && CImGui.SetClipboardText(_selectiontext(ed))
        if CImGui.IsKeyPressed(CImGui.ImGuiKey_X)
            CImGui.SetClipboardText(_selectiontext(ed))
            if ed.anchor == ed.cur #无选区剪切整行
                ls, le = _lineboundsbuf(ed, ed.cur)
                ed.anchor = ls
                ed.cur = min(le + (le < length(ed.buf) ? 2 : 1), length(ed.buf) + 1)
            end
            changed = _deleterange!(ed) || changed
        end
        CImGui.IsKeyPressed(CImGui.ImGuiKey_V) && (changed = _inserttext!(ed, unsafe_string(CImGui.GetClipboardText())) || changed)
        CImGui.IsKeyPressed(CImGui.ImGuiKey_Z) && (shift ? _redo!(ed) : _undo!(ed))
        CImGui.IsKeyPressed(CImGui.ImGuiKey_Y) && _redo!(ed)
        CImGui.IsKeyPressed(CImGui.ImGuiKey_Home) && _move!(ed, 1; select=shift)
        CImGui.IsKeyPressed(CImGui.ImGuiKey_End) && _move!(ed, length(ed.buf) + 1; select=shift)
        CImGui.IsKeyPressed(CImGui.ImGuiKey_LeftArrow) && _move!(ed, _wordleftix(ed); select=shift)
        CImGui.IsKeyPressed(CImGui.ImGuiKey_RightArrow) && _move!(ed, _wordrightix(ed); select=shift)
        #Ctrl+/:切换行注释(VS Code 快捷键)
        CImGui.IsKeyPressed(CImGui.ImGuiKey_Slash, false) && (changed = _togglecomment!(ed) || changed)
        #AltGr 组合(_ctrl+alt)产生的合法字符不拦截
        ctrl && !CImGui.IsKeyDown(CImGui.ImGuiMod_Alt) && return changed
        return changed
    end
    CImGui.IsKeyPressed(CImGui.ImGuiKey_LeftArrow, true) && _moveleft!(ed, shift)
    CImGui.IsKeyPressed(CImGui.ImGuiKey_RightArrow, true) && _moveright!(ed, shift)
    CImGui.IsKeyPressed(CImGui.ImGuiKey_UpArrow, true) && _vertical!(ed, -1, shift)
    CImGui.IsKeyPressed(CImGui.ImGuiKey_DownArrow, true) && _vertical!(ed, 1, shift)
    CImGui.IsKeyPressed(CImGui.ImGuiKey_PageUp, true) && _vertical!(ed, -max(1, ed.rows - 1), shift)
    CImGui.IsKeyPressed(CImGui.ImGuiKey_PageDown, true) && _vertical!(ed, max(1, ed.rows - 1), shift)
    if CImGui.IsKeyPressed(CImGui.ImGuiKey_Home, true)
        _move!(ed, _lineboundsbuf(ed, ed.cur)[1]; select=shift)
    end
    if CImGui.IsKeyPressed(CImGui.ImGuiKey_End, true)
        _move!(ed, _lineboundsbuf(ed, ed.cur)[2] + 1; select=shift)
    end
    CImGui.IsKeyPressed(CImGui.ImGuiKey_Backspace, true) && (changed = _backspace!(ed) || changed)
    CImGui.IsKeyPressed(CImGui.ImGuiKey_Delete, true) && (changed = _deletefwd!(ed) || changed)
    CImGui.IsKeyPressed(CImGui.ImGuiKey_Enter, true) && (changed = _inserttext!(ed, _newlinetext(ed)) || changed)
    #Tab:有选区时各行整体右缩进,Shift+Tab 各行整体左缩进,无选区插入制表符(VS Code)
    CImGui.IsKeyPressed(CImGui.ImGuiKey_Tab, true) && (changed = shift ? _dedentlines!(ed) :
        (ed.anchor != ed.cur ? _indentlines!(ed) : _inserttext!(ed, "\t")) || changed)
    if CImGui.IsKeyPressed(CImGui.ImGuiKey_Escape)
        if ed.anchor != ed.cur
            ed.anchor = ed.cur
        else
            ed.active = false
        end
    end
    changed = _inputchars!(ed) || changed
    changed
end

#IME 候选窗跟随光标(部分后端不支持时静默跳过)
function _setimepos!(ed, origin, lineheight)
    l = _lineof(ed)
    col = ed.cur - ed.linestarts[l] + 1
    y = origin.y + (l - 1) * lineheight
    x = origin.x + _prefixwidth(ed, l, col - 1)
    try
        pio = CImGui.GetPlatformIO()
        ime = pio.PlatformImeData
        ime == C_NULL && return
        unsafe_store!(ime.WantVisible, true)
        unsafe_store!(ime.InputPos, CImGui.ImVec2(x, y + lineheight))
        unsafe_store!(ime.InputLineHeight, lineheight)
    catch
    end
    nothing
end
