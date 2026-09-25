function ShowHelpMarker(desc)
    CImGui.TextDisabled("(?)")
    if CImGui.IsItemHovered()
        CImGui.BeginTooltip()
        CImGui.PushTextWrapPos(CImGui.GetFontSize() * 36.0)
        CImGui.TextUnformatted(desc)
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
end

function ShowUnit(id, utype, ui::Ref{Int}, flags=CImGui.ImGuiComboFlags_NoArrowButton)
    Us = string.(haskey(CONF.U, utype) ? CONF.U[utype] : [""])
    (ui[] > length(Us) || ui[] < 1) && (ui[] = 1)
    U = Us[ui[]]
    begincombo = CImGui.BeginCombo(stcstr("##unit", id), U, flags)
    if begincombo
        for u in eachindex(Us)
            local selected = ui[] == u
            CImGui.Selectable(Us[u], selected) && (ui[] = u)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    return begincombo
end

function YesNoDialog(id, msg, flags=0)::Bool
    retval = false
    if CImGui.BeginPopupModal(id, C_NULL, flags)
        ftsz = CImGui.GetFontSize()
        CImGui.Text("\n")
        CImGui.PushFont(C_NULL, 2unsafe_load(IMGUISTYLE.FontSizeBase))
        CImGui.SetCursorPosX(CImGui.GetCursorPosX() + (CImGui.GetContentRegionAvail().x - CImGui.CalcTextSize(msg).x) / 2)
        CImGui.TextColored(MORESTYLE.Colors.WarnText, msg)
        CImGui.PopFont()
        CImGui.Text("\n\n")
        CImGui.Button(mlstr("Confirm"), (4ftsz, Cfloat(0))) && (CImGui.CloseCurrentPopup(); retval = true)
        CImGui.SameLine(0, CImGui.CalcTextSize(msg).x + 2ftsz)
        CImGui.Button(mlstr("Cancel"), (4ftsz, Cfloat(0))) && CImGui.CloseCurrentPopup()
        CImGui.EndPopup()
    end
    return retval
end

function TextRect(
    str, update=false;
    size=(0, 0),
    nochild=false,
    bdrounding=MORESTYLE.Variables.TextRectRounding,
    thickness=MORESTYLE.Variables.TextRectThickness,
    padding=MORESTYLE.Variables.TextRectPadding,
    coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
)
    draw_list = CImGui.GetWindowDrawList()
    availwidth = CImGui.GetContentRegionAvail().x
    nochild || CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ padding)
    nochild || CImGui.BeginChild("TextRect", size .- 2padding, ImGuiChildFlags_None)
    CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ padding .+ thickness)
    CImGui.PushTextWrapPos(nochild ? availwidth - padding[1] : 0)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, coltxt)
    CImGui.TextUnformatted(str)
    CImGui.PopStyleColor()
    CImGui.PopTextWrapPos()
    nochild || (update && CImGui.SetScrollHereY(1))
    nochild || CImGui.EndChild()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    nochild && ColoredButton(""; size=(Cfloat(0), thickness + padding[2]), colbt=[0, 0, 0, 0], colbth=[0, 0, 0, 0], colbta=[0, 0, 0, 0])
    recta = nochild ? rmin .- padding : rmin .- padding .+ thickness
    rectb = nochild ? CImGui.ImVec2(rmin.x + availwidth .- 2padding[1] .- 2thickness, rmax.y + padding[2]) : rmax .+ padding .- thickness
    CImGui.AddRect(draw_list, recta, rectb, MORESTYLE.Colors.ShowTextRect, bdrounding, thickness)
    recta, rectb
end

function ItemTooltip(tipstr, wrappos=36CImGui.GetFontSize())
    if CImGui.IsItemHovered()
        CImGui.BeginTooltip()
        CImGui.PushTextWrapPos(wrappos)
        CImGui.TextUnformatted(tipstr)
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
end

function ItemTooltipNoHovered(tipstr, wrappos=36CImGui.GetFontSize())
    CImGui.BeginTooltip()
    CImGui.PushTextWrapPos(wrappos)
    CImGui.TextUnformatted(tipstr)
    CImGui.PopTextWrapPos()
    CImGui.EndTooltip()
end

function SeparatorTextColored(col, label)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, col)
    igSeparatorText(label)
    CImGui.PopStyleColor()
end

function BoxTextColored(
    label;
    size=(0, 0),
    col=CImGui.c_get(IMGUISTYLE.Colors, ImGuiCol_Text),
    colbd=MORESTYLE.Colors.ItemBorder
)
    nonecol = [0, 0, 0, 0]
    ColoredButtonRect(
        label; size=size, thickness=1, colbt=nonecol, colbth=nonecol, colbta=nonecol, coltxt=col, colrect=colbd
    )
end

@kwdef mutable struct AnimateChild
    presentsize::CImGui.ImVec2 = (0, 0)
    targetsize::CImGui.ImVec2 = (400, 600)
    rate::CImGui.ImVec2 = (4, 6)
end

function (acd::AnimateChild)(f, id, border, flags, args...; kwargs...)
    CImGui.BeginChild(id, acd.presentsize, border, flags)
    f(args...; kwargs...)
    CImGui.EndChild()
    acd.presentsize = CImGui.GetItemRectSize()
    if all(acd.presentsize .== acd.targetsize)
    else
        rate = sign.(acd.targetsize .- acd.presentsize) .* abs.(acd.rate)
        gap = abs.(acd.presentsize .- acd.targetsize)
        newsize = acd.presentsize .+ rate
        acd.presentsize = (
            gap[1] < abs(acd.rate[1]) ? acd.targetsize[1] : newsize[1],
            gap[2] < abs(acd.rate[2]) ? acd.targetsize[2] : newsize[2]
        )
    end
end

@kwdef mutable struct DragPoint
    pos::Vector{Cfloat} = [0, 0]
    limmin::Vector{Cfloat} = [0, 0]
    limmax::Vector{Cfloat} = [Inf, Inf]
    radius::Cfloat = 6
    segments::Cint = 12
    col::Vector{Cfloat} = [1, 1, 1, 0.6]
    colh::Vector{Cfloat} = [1, 1, 1, 1]
    cola::Vector{Cfloat} = [0, 1, 0, 1]
    hovered::Bool = false
    dragging::Bool = false
end

function draw(dp::DragPoint)
    CImGui.AddCircleFilled(
        CImGui.GetWindowDrawList(), dp.pos, dp.radius,
        dp.dragging ? dp.cola : dp.hovered ? dp.colh : dp.col
    )
end

function update_state!(dp::DragPoint)
    mspos = CImGui.GetMousePos()
    dp.hovered = sum(abs2.(mspos .- dp.pos)) < abs2(dp.radius)
    if dp.dragging
        CImGui.IsMouseDown(0) ? dp.pos = cutoff(mspos, dp.limmin, dp.limmax) : dp.dragging = false
    else
        dp.hovered && CImGui.IsMouseDown(0) && CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) < 0.1 && (dp.dragging = true)
    end
end

function edit(dp::DragPoint)
    update_state!(dp)
    draw(dp)
end

@kwdef mutable struct DragRect
    posmin::Vector{Cfloat} = [0, 0]
    posmax::Vector{Cfloat} = [100, 100]
    dragpos::Vector{Cfloat} = [0, 0]
    rszgripsize::Cfloat = 24
    limmin::Vector{Cfloat} = [0, 0]
    limmax::Vector{Cfloat} = [Inf, Inf]
    limminsize::Vector{Cfloat} = [0, 0]
    limmaxsize::Vector{Cfloat} = [Inf, Inf]
    scale::Cfloat = 1
    rounding::Cfloat = 0
    bdrounding::Cfloat = 0
    thickness::Cfloat = 2
    col::Vector{Cfloat} = [1, 1, 1, 0.6]
    colh::Vector{Cfloat} = [1, 1, 1, 1]
    cola::Vector{Cfloat} = [0, 1, 0, 1]
    colbd::Vector{Cfloat} = [0, 0, 0, 1]
    colbdh::Vector{Cfloat} = [0, 0, 0, 1]
    colbda::Vector{Cfloat} = [0, 0, 0, 1]
    hovered::Bool = false
    dragging::Bool = false
    griphovered::Bool = false
    gripdragging::Bool = false
end
function pushscale!(dr::DragRect)
    # dr.posmin .*= dr.scale
    dr.posmax .= dr.posmin .+ (dr.posmax .- dr.posmin) * dr.scale
    dr.dragpos .*= dr.scale
    dr.rszgripsize *= dr.scale
    dr.limmin .*= dr.scale
    dr.limmax .*= dr.scale
    dr.limminsize .*= dr.scale
    dr.limmaxsize .*= dr.scale
    dr.rounding *= dr.scale
    dr.bdrounding *= dr.scale
    dr.thickness *= dr.scale
end
function endscale!(dr::DragRect)
    # dr.posmin ./= dr.scale
    dr.posmax .= dr.posmin .+ (dr.posmax .- dr.posmin) / dr.scale
    dr.dragpos ./= dr.scale
    dr.rszgripsize /= dr.scale
    dr.limmin ./= dr.scale
    dr.limmax ./= dr.scale
    dr.limminsize ./= dr.scale
    dr.limmaxsize ./= dr.scale
    dr.rounding /= dr.scale
    dr.bdrounding /= dr.scale
    dr.thickness /= dr.scale
end

function draw(dr::DragRect)
    drawlist = CImGui.GetWindowDrawList()
    CImGui.AddRectFilled(
        drawlist, dr.posmin, dr.posmax,
        dr.dragging ? dr.cola : dr.hovered && !dr.griphovered && !dr.gripdragging ? dr.colh : dr.col,
        dr.rounding
    )
    CImGui.AddTriangleFilled(
        drawlist,
        (dr.posmax[1] - dr.rszgripsize, dr.posmax[2]), dr.posmax, (dr.posmax[1], dr.posmax[2] - dr.rszgripsize),
        CImGui.c_get(
            IMGUISTYLE.Colors,
            dr.gripdragging ? ImGuiCol_ResizeGripActive : dr.griphovered ? ImGuiCol_ResizeGripHovered : ImGuiCol_ResizeGrip
        )
    )
    CImGui.AddRect(
        drawlist, dr.posmin, dr.posmax,
        dr.dragging ? dr.colbda : dr.hovered && !dr.griphovered && !dr.gripdragging ? dr.colbdh : dr.colbd,
        dr.bdrounding, dr.thickness, ImDrawFlags_RoundCornersAll
    )
end

function update_state!(dr::DragRect)
    mspos = CImGui.GetMousePos()
    dr.griphovered = inregion(mspos, dr.posmax .- dr.rszgripsize, dr.posmax)
    dr.griphovered &= -(mspos.x - dr.posmax[1] + dr.rszgripsize) < mspos.y - dr.posmax[2]
    dr.hovered = inregion(mspos, dr.posmin, dr.posmax)
    if dr.gripdragging
        if CImGui.IsMouseDown(0)
            if CImGui.IsMouseDragging(0)
                dr.posmax = cutoff(mspos, dr.posmin .+ dr.limminsize, dr.posmin .+ dr.limmaxsize) .+ dr.rszgripsize ./ 4
            end
        else
            dr.gripdragging = false
        end
    else
        dr.griphovered && !dr.dragging && CImGui.IsMouseDown(0) && CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) < 0.1 && (dr.gripdragging = true)
    end
    if dr.dragging
        if CImGui.IsMouseDown(0)
            drsize = dr.posmax .- dr.posmin
            dr.posmin = cutoff(mspos .- dr.dragpos, dr.limmin, dr.limmax .- drsize)
            dr.posmax = dr.posmin .+ drsize
        else
            dr.dragging = false
        end
    else
        if dr.hovered && !dr.gripdragging && CImGui.IsMouseDown(0) && CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) < 0.1
            dr.dragging = true
            dr.dragpos = mspos .- dr.posmin
        end
    end
end

function edit(dr::DragRect)
    pushscale!(dr)
    update_state!(dr)
    draw(dr)
    endscale!(dr)
end

let
    framecount::Cint = 0
    global function SetWindowBgImage(
        path=CONF.BGImage.main.path;
        rate=CONF.BGImage.main.rate, use=CONF.BGImage.main.use, tint_col=MORESTYLE.Colors.BgImageTint
    )
        if use
            wpos = CImGui.GetWindowPos()
            wsz = CImGui.GetWindowSize()
            haskey(IMAGES, path) || createimage(path; showsize=wsz)
            if length(IMAGES[path]) > 1 && framecount != CImGui.GetFrameCount()
                framecount = CImGui.GetFrameCount()
                framecount % rate == 0 && move!(IMAGES[path])
            end
            CImGui.AddImage(
                CImGui.GetWindowDrawList(), IMAGES[path][], wpos, wpos .+ wsz, (0, 0), (1, 1),
                tint_col
            )
        end
    end
end

# —— 窗口阴影:预渲染高斯角部纹理 + 9-patch 拼贴(4 角 + 4 边,UV 翻转复用一张纹理)——
# 纹理为白色 + alpha 高斯衰减,经 tint 染成 MORESTYLE.Colors.ShadowColor。
# 历史:单张径向纹理拉伸方案在宽面板边缘 alpha≈0(不可见);8 层堆叠矩形描边有色带且像发光边框,
# 均已废弃。9-patch:角部保真、边缘 1D 衰减,任意尺寸无畸变,每帧 9 次 AddImage。
const SHADOWTEX = Ref{Union{Nothing,CImGui.ImTextureRef}}(nothing)
const SHADOWKEY = Ref{Tuple{Float32,Float32}}((0f0, 0f0))

function shadowtexture(radius::Real, rounding::Real)
    key = (Cfloat(radius), Cfloat(rounding))
    if SHADOWTEX[] === nothing || SHADOWKEY[] != key
        m = max(8, ceil(Int, radius * 1.4) + 1)  # 纹理边长覆盖最大方向性展开(底部 1.25r)
        σ = radius * 0.5
        rr = min(rounding, radius)         # 圆角 SDF 用的圆角半径
        img = Matrix{RGBA{Float32}}(undef, m, m)
        for j in 1:m, i in 1:m
            dx = m - i  # 距面板左边缘的外向距离(0=贴边, m=最远)
            dy = m - j  # 距面板上边缘的外向距离
            u, v = dx - rr, dy - rr
            d = (u > 0 && v > 0) ? hypot(u, v) : Float32(max(dx, dy))  # 圆角矩形 SDF
            # 峰值 0.62:贴边处不过浓(避免"深色描边"感),向外高斯衰减
            img[j, i] = RGBA{Float32}(1.0f0, 1.0f0, 1.0f0, Float32(0.62 * exp(-((d / σ)^2))))
        end
        tex = CImGui.create_image_texture(m, m)
        CImGui.update_image_texture(tex, img, m, m; type=ModernGL.GL_FLOAT)
        SHADOWTEX[] = tex
        SHADOWKEY[] = key
    end
    SHADOWTEX[]
end

function destroyshadowtexture!()
    SHADOWTEX[] === nothing || (destroytexture!(SHADOWTEX[]); SHADOWTEX[] = nothing)
    return
end

resetshadowtexture!() = (SHADOWTEX[] = nothing; SHADOWKEY[] = (0f0, 0f0); nothing)  # GL 上下文销毁后仅清引用

# —— 微动画基元:指数趋近插值。MORESTYLE.Variables.AnimSpeed = 0 时全部动画直达 ——
let
    animstates = Dict{String,Float32}()
    global animfrom(key::String) = get!(animstates, key, 0.0f0)  # 从 0 起步(窗口淡入用)
    global function animto(key::String, target::Real; speed::Real=8.0)
        speed <= 0 && return Float32(target)
        cur = get!(animstates, key, Float32(target))
        cur == target && return cur
        dt = unsafe_load(CImGui.GetIO().DeltaTime) * MORESTYLE.Variables.AnimSpeed
        newv = Float32(cur + (target - cur) * clamp(1 - exp(-speed * dt), 0.0, 1.0))
        if abs(newv - target) < 1e-4
            delete!(animstates, key)
            dorender()
            return Float32(target)
        end
        animstates[key] = newv
        dorender()  # 动画未收敛,申请下一帧
        return newv
    end
end

"""
    SetWindowShadow(strength = 1.0; radius = MORESTYLE.Variables.ShadowRadius)

在 BackgroundDrawList 上为当前窗口画外扩径向阴影;须在 Begin 之后调用。
阴影画在所有窗口之下(无裁剪),多视口模式下浮动 OS 窗口的阴影不会跟随其视口。
"""
function SetWindowShadow(strength::Real=1.0; radius::Real=MORESTYLE.Variables.ShadowRadius)
    wpos = CImGui.GetWindowPos()
    drawshadow!(
        CImGui.GetBackgroundDrawList(), wpos, wpos .+ CImGui.GetWindowSize();
        strength, radius, rounding=unsafe_load(IMGUISTYLE.WindowRounding)
    )
end

# 9-patch 拼贴:u0 = 纹理中"贴边"一列/一行的 UV;四角全纹理映射、四边采样贴边行列并拉伸。
# 方向性展开(光源在上方):顶部收窄、底部舒展、左右居中——符合自然落影,消除"环绕光晕"感。
# 注意:①pmin/pmax 可能是 ImVec2 也可能是广播产生的 Vector,坐标一律用下标而非 .x/.y;
# ②所有坐标/UV/颜色元组必须同质 Float32(异构元组不匹配 wrapper 的 NTuple{N},见 ai/08 坑 31)。
function drawshadow!(dl, pmin, pmax; strength::Real=1.0, radius::Real=MORESTYLE.Variables.ShadowRadius, rounding::Real=0)
    (radius <= 0 || strength <= 0) && return
    dpi = CImGui.GetWindowDpiScale()
    m = max(8, ceil(Int, radius * 1.4) + 1)
    tex = shadowtexture(radius, rounding)
    u0 = Float32((m - 1) / m)
    c = MORESTYLE.Colors.ShadowColor
    tint = (c[1], c[2], c[3], Float32(c[4] * strength))
    st = Float32(radius * 0.45 * dpi)   # 顶部展开(窄)
    sb = Float32(radius * 1.25 * dpi)   # 底部展开(宽)
    sx = Float32(radius * 0.85 * dpi)   # 左右展开
    L, T = Float32(pmin[1]), Float32(pmin[2])
    R, B = Float32(pmax[1]), Float32(pmax[2])
    # 四角(全纹理;按方位 UV 翻转;纵向随 st/sb 非均匀拉伸)
    CImGui.AddImage(dl, tex, (L - sx, T - st), (L, T), (0f0, 0f0), (1f0, 1f0), tint)          # 左上
    CImGui.AddImage(dl, tex, (R, T - st), (R + sx, T), (1f0, 0f0), (0f0, 1f0), tint)         # 右上
    CImGui.AddImage(dl, tex, (L - sx, B), (L, B + sb), (0f0, 1f0), (1f0, 0f0), tint)         # 左下
    CImGui.AddImage(dl, tex, (R, B), (R + sx, B + sb), (1f0, 1f0), (0f0, 0f0), tint)         # 右下
    # 四边(采样贴边一行/一列,拉伸)
    CImGui.AddImage(dl, tex, (L, T - st), (R, T), (u0, 0f0), (1f0, 1f0), tint)               # 上
    CImGui.AddImage(dl, tex, (L, B), (R, B + sb), (u0, 1f0), (1f0, 0f0), tint)               # 下
    CImGui.AddImage(dl, tex, (L - sx, T), (L, B), (0f0, u0), (1f0, 1f0), tint)               # 左
    CImGui.AddImage(dl, tex, (R, T), (R + sx, B), (1f0, u0), (0f0, 1f0), tint)               # 右
end

# —— 深度体系:表面按"高度"分层,同层内从主题 token 取色,token 缺省(alpha≤0)时从
# WindowBg 自动派生(暗底逐级提亮、亮底逐级压白),旧主题无需更新即有正确层级 ——
_rgba(c) = c isa CImGui.ImVec4 ? (c.x, c.y, c.z, c.w) : (c[1], c[2], c[3], c[4])
liftcolor(c, f::Real) = begin
    r, g, b, a = _rgba(c)
    Float32[min(1.0, r + (1 - r) * f), min(1.0, g + (1 - g) * f), min(1.0, b + (1 - b) * f), a]
end
darkencolor(c, f::Real) = begin
    r, g, b, a = _rgba(c)
    Float32[r*(1-f), g*(1-f), b*(1-f), a]
end

function surfacestyle(level::Integer=1)
    wb = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_WindowBg)
    isdark = isthemedark([wb.x, wb.y, wb.z, wb.w])
    if level >= 2  # 卡片上的子面板:再高一层(边框极淡,分层主要靠表面色差)
        bgc, bdc = MORESTYLE.Colors.PanelBg, MORESTYLE.Colors.PanelBorder
        autobg = isdark ? liftcolor(wb, 0.11) : Float32[1.0, 1.0, 1.0, 0.95]
        b = isdark ? liftcolor(wb, 0.26) : darkencolor(wb, 0.22)
        autobd = Float32[b[1], b[2], b[3], 0.12]
    else           # 一级卡片
        bgc, bdc = MORESTYLE.Colors.CardBg, MORESTYLE.Colors.CardBorder
        autobg = isdark ? liftcolor(wb, 0.06) : darkencolor(wb, 0.04)
        b = isdark ? liftcolor(wb, 0.20) : darkencolor(wb, 0.18)
        autobd = Float32[b[1], b[2], b[3], 0.22]
    end
    bg = bgc[4] > 0 ? bgc : autobg
    bd = bdc[4] > 0 ? bdc : autobd
    bg, bd
end

"""
    CardChild(id, size = (0, 0); rounding, shadow = false, level = 1, bg = nothing, border = nothing)

卡片容器:先在父 DrawList 上绘制底色/描边(可选阴影),再以透明 ChildBg 开启同尺寸子区。
`level = 1` 一级卡片(CardBg/CardBorder),`level = 2` 子面板(PanelBg,默认无描边)。
**主窗口内部默认不画阴影**——同一 GL 表面内多层半透明叠加会产生脏边,边缘虚化交给 OS
合成器(主窗口/浮窗的 DWM 阴影);确需应用内阴影时显式传 `shadow = true`。
`bg`/`border` 可显式覆盖(传颜色)。负尺寸沿用 ImGui 惯例。配对 `EndCard()` 结束。
"""
function CardChild(id, size=(0, 0); rounding=MORESTYLE.Variables.CardRounding, level=1, shadow=false, bg=nothing, border=nothing)
    avail = CImGui.GetContentRegionAvail()
    w = Cfloat(size[1] > 0 ? size[1] : max(0, avail.x + size[1]))
    h = Cfloat(size[2] > 0 ? size[2] : max(0, avail.y + size[2]))
    pos = CImGui.GetCursorScreenPos()
    rmax = (pos.x + w, pos.y + h)
    dl = CImGui.GetWindowDrawList()
    sbg, sbd = surfacestyle(level)
    bg === nothing || (sbg = bg)
    border === nothing || (sbd = border)
    shadow && drawshadow!(dl, pos, rmax; strength=1.0, rounding=Cfloat(rounding))
    CImGui.AddRectFilled(dl, pos, rmax, sbg, Cfloat(rounding))
    sbd[4] > 0 && CImGui.AddRect(dl, pos, rmax, sbd, Cfloat(rounding))
    # 内边距让内容与卡片边框脱开,强化"浮在面板之上"的层次感。
    # 1.92 起 child 默认无边距:WindowPadding 样式仅在 Borders 或 AlwaysUseWindowPadding
    # 标志置位时生效,故必须带 AlwaysUseWindowPadding(它按设计采用当前样式值,CardPadding
    # 经 PushStyleVar 传入);快照后立即弹栈,不影响卡片内嵌套的子面板
    pad = MORESTYLE.Variables.CardPadding .* CImGui.GetWindowDpiScale()
    CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, (0, 0, 0, 0))
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, (pad[1], pad[2]))
    CImGui.BeginChild(id, (w, h), CImGui.ImGuiChildFlags_AlwaysUseWindowPadding)
    CImGui.PopStyleVar()
    return
end

EndCard() = (CImGui.EndChild(); CImGui.PopStyleColor(); nothing)

# —— 独立视口(OS)窗口的关闭钮去重:OS 标题栏有关闭钮时隐藏 ImGui 自绘的 ——
# WINVIEWPORTS 记录各窗口上一帧所在视口;CLOSEPENDING 是本帧有 OS 关闭请求的视口
const WINVIEWPORTS = Dict{String,UInt32}()
const CLOSEPENDING = Set{UInt32}()

function syncviewportcloses!()
    empty!(CLOSEPENDING)
    pio = CImGui.GetPlatformIO()
    pio == C_NULL && return
    vps = unsafe_load(Ptr{CImGui.lib.ImGuiPlatformIO}(pio)).Viewports
    (vps.Size <= 0 || vps.Data == C_NULL) && return
    for i in 1:vps.Size
        pvp = unsafe_load(vps.Data, i)
        pvp == C_NULL && continue
        vp = unsafe_load(pvp)
        vp.PlatformRequestClose && push!(CLOSEPENDING, UInt32(vp.ID))
    end
    return
end

# 注意:绑定的 Ptr 上 getproperty 返回字段指针(如 Ptr{Bool}(x+115)),必须 unsafe_load
# 后再做字段访问,`.ID` 才是值而非指针
isownwindow(name::String) = get(WINVIEWPORTS, name, unsafe_load(CImGui.GetMainViewport()).ID) != unsafe_load(CImGui.GetMainViewport()).ID
wantosclose(name::String) = isownwindow(name) && (get(WINVIEWPORTS, name, 0) in CLOSEPENDING)
const WINTICONS = Dict{String,String}()
# 边框隐藏(拖出时隐藏 OS 标题栏,视口级 DECORATED 运行时切换):
# AUTO 按 ImGui 窗口 NoTitleBar 旗标自动判定;SET 为手动覆盖(setborderless!),优先级更高
const WINBORDERLESS_AUTO = Dict{String,Bool}()
const WINBORDERLESS_SET = Dict{String,Bool}()
borderless(name::AbstractString) =
    get(WINBORDERLESS_SET, String(name), get(WINBORDERLESS_AUTO, String(name), false))

"""
    setborderless!(name, v = true)

把窗口 `name` 标记为"拖出时隐藏 OS 标题栏"(GLFW DECORATED 运行时切换,按视口生效)。
`name` 为含 `###` ID 的完整窗口标题;被标记窗口浮动时保留 ImGui 自绘关闭钮。
"""
setborderless!(name::AbstractString, v::Bool = true) = (WINBORDERLESS_SET[String(name)] = v; nothing)

function registerwindow(name)
    s = String(name)
    WINVIEWPORTS[s] = unsafe_load(CImGui.GetWindowViewport()).ID
    # 标题首字符若在 FontAwesome 私有区(PUA)即为窗口图标,供 OS 标题栏使用
    isempty(s) && return
    c = UInt32(first(s))
    WINTICONS[s] = (0xE000 <= c <= 0xF8FF) ? string(first(s)) : ""
    WINBORDERLESS_AUTO[s] = begin
        # 无公开 GetWindowFlags 绑定,经 igGetCurrentWindowRead 的 Flags 字段取
        # (registerwindow 在 Begin 作用域内调用,当前窗口即本窗口)
        flags = unsafe_load(getproperty(CImGui.lib.igGetCurrentWindowRead(), :Flags))
        (flags & CImGui.ImGuiWindowFlags_NoTitleBar) != 0
    end
    return
end

# —— OS 标题栏窗口图标:把标题里的 FontAwesome 字形栅格化成 32×32 位图 ——
# OS 标题栏不能渲染字体,glfwSetWindowIcon 只认位图;用 Makie 字体栈(FreeTypeAbstraction,
# 随 GLMakie 已加载)栅格化,按 (明暗, 字符) 缓存。暗标题栏用白字形,亮标题栏用深字形。
const FAGLYPHCACHE = Dict{Tuple{Bool,String},Any}()

function faglyphbitmap(ch::Union{Char,AbstractString}, dark::Bool)
    key = (dark, string(ch))
    haskey(FAGLYPHCACHE, key) && return FAGLYPHCACHE[key]
    result = nothing
    try
        c = first(ch)
        FTA = first(mm for (id, mm) in Base.loaded_modules if id.name == "FreeTypeAbstraction")
        col = dark ? 0xff : 0x26
        for rel in ("Necessity/fa-solid-900.ttf", "Necessity/fa-regular-400.ttf")
            path = joinpath(ENV["QInsControlAssets"], rel)
            isfile(path) || continue
            font = FTA.FTFont(path)
            img, _ = FTA.renderface(font, c, 30)
            count(>(0x20), img) == 0 && continue  # 缺字(空字形)→ 换下一个字体
            # renderface 输出为 [x, y] 布局(宽在前),按 [行, 列] 用会旋转 90°
            w, h = size(img)
            # 宽字形(如 credit-card/robot 超 32px)按比例缩小重渲,避免写矩阵越界
            (w > 30 || h > 30) && begin
                img, _ = FTA.renderface(font, c, max(10, floor(Int, 30 * 30 / max(w, h))))
                w, h = size(img)
            end
            m = 32
            ox = clamp((m - w) ÷ 2 + 1, 1, m)
            oy = clamp((m - h) ÷ 2 + 1, 1, m)
            mat = fill((0x00, 0x00, 0x00, 0x00), m, m)
            for i in 1:w, j in 1:h
                a = img[i, j]
                a > 0 && (mat[oy+j-1, ox+i-1] = (col, col, col, a))
            end
            result = mat
            break
        end
    catch
    end
    FAGLYPHCACHE[key] = result
    result
end

function BeginNoClose(name, p_open, borderless=false, flags=0; hastitle=false)
    if CONF.Basic.hideglfwwindow
        begun = CImGui.Begin(name, p_open)
        registerwindow(name)  # 注册与关闭钮处理无关(图标/边框跟踪),两个分支都需要
        return begun, nothing, nothing
    else
        wantosclose(name) && (p_open[] = false)
        setborderless!(name, borderless)
        popenarg, own = beginpopenargs(name, p_open[])
        flags |= CONF.Basic.hideimguititlebar && !hastitle ? CImGui.ImGuiWindowFlags_NoTitleBar : 0
        begun = CImGui.Begin(name, popenarg, flags)
        registerwindow(name)
        return begun, own, popenarg
    end
end
function EndNoClose(own, p_open, popenarg)
    CImGui.End()
    if !(CONF.Basic.hideglfwwindow || isnothing(own) || isnothing(popenarg))
        own || (p_open[] = popenarg[])
    end
end

"""
    beginpopenargs(name, p_open::Bool) -> (arg, isown)

浮窗 Begin 的 p_open 参数:窗口位于独立 OS 视口时返回 C_NULL(隐藏 ImGui 自绘关闭钮),
否则返回 `Ref(p_open)`(保留停靠态的关闭钮)。用法:

    wantosclose(nm) && (p_open = false)      # 响应 OS 标题栏关闭请求
    popenarg, own = beginpopenargs(nm, p_open)
    begun = CImGui.Begin(nm, popenarg); registerwindow(nm)
    begun && …content…; CImGui.End()
    own || (p_open = popenarg[])             # 停靠态下回写 X 点击
"""
function beginpopenargs(name::AbstractString, p_open::Bool)
    # 边框隐藏窗口浮动时 OS 标题栏(含关闭钮)不可见,必须保留 ImGui 自绘 X
    own = isownwindow(String(name)) && !borderless(String(name))
    return (own ? C_NULL : Ref(p_open), own)
end

let
    states::Dict{String,Bool} = Dict()
    global function CopyableText(label, text; size=(0, 0))
        haskey(states, label) || (states[label] = false)
        if states[label]
            CImGui.InputTextMultiline(
                label, text, ncodeunits(text), size, CImGui.ImGuiInputTextFlags_ReadOnly #buf_size 按字节:传字符数会把中文截成 1/3
            )
            CImGui.IsItemDeactivated() && (states[label] = false)
        else
            CImGui.TextUnformatted(text)
            CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (states[label] = true)
        end
    end
end