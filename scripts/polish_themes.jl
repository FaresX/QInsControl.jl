# 主题批量打磨:为所有主题补全/统一以下内容——
#   ①现代圆角轮廓(Frame/Grab/Popup/Child/Tab/Scrollbar 圆角 + 无边框,与基准主题一致);
#   ②强调色族:从各主题既有语义色(IconButton/HighlightText/CheckMark…)中选最饱和者派生
#     AccentTop/AccentBottom,各主题保留自己的色彩个性;
#   ③补全 Success/Shadow/Card/Panel 等 A 方案新 token(按主题明暗取值);
#   ④ClearColor 与窗口底色联动(衬托卡片);⑤壁纸/Makie 主题按明暗配对。
# OceanBreeze / MidnightLab 为手工基准主题,默认跳过(--all 可强制)。
# 用法:julia scripts/polish_themes.jl [--all]
using TOML

repodir = normpath(joinpath(@__DIR__, "..", "..", "QInsControlAssets"))
assets = isdir(repodir) ? repodir : get(ENV, "QInsControlAssets", repodir)
styles = joinpath(assets, "Styles")
skip = Set(["OceanBreeze", "MidnightLab"])

rgba(c) = (c[1], c[2], c[3], length(c) >= 4 ? c[4] : 1.0)
lift(c, f) = begin
    r, g, b, a = rgba(c)
    [min(1.0, r + (1 - r) * f), min(1.0, g + (1 - g) * f), min(1.0, b + (1 - b) * f), a]
end
darken(c, f) = begin
    r, g, b, a = rgba(c)
    [r * (1 - f), g * (1 - f), b * (1 - f), a]
end
sat(c) = begin
    mx = max(c[1], c[2], c[3])
    mn = min(c[1], c[2], c[3])
    mx <= 0 ? 0.0 : (mx - mn) / mx
end
seta(c, a) = [Float64(c[1]), Float64(c[2]), Float64(c[3]), Float64(a)]
lum(c) = 0.2126c[1] + 0.7152c[2] + 0.0722c[3]

for file in sort(filter(f -> endswith(f, ".toml"), readdir(styles, join=true)))
    name = basename(file)[1:end-5]
    if name in skip && !("--all" in ARGS)
        println("skip (manual baseline)  ", name)
        continue
    end
    t = TOML.parsefile(file)
    is_ = get!(t, "imguistyle", Dict{String,Any}())
    ic = get!(is_, "Colors", Dict{String,Any}())
    ms = get!(t, "morestyle", Dict{String,Any}())
    v = get!(ms, "Variables", Dict{String,Any}())
    mc = get!(ms, "Colors", Dict{String,Any}())

    wb = collect(Float64, get(ic, "WindowBg", [0.1, 0.1, 0.12, 1.0]))
    isdark = lum(wb) < 0.5

    # ① 现代圆角轮廓(仅覆写已存在的字段,保持各主题文件结构)
    for (k, val) in (
        "WindowRounding" => 0.0, "WindowBorderSize" => 0.0, "ChildRounding" => 6.0,
        "PopupRounding" => 8.0, "FrameRounding" => 5.0, "FrameBorderSize" => 0.0,
        "ScrollbarRounding" => 6.0, "GrabRounding" => 6.0, "TabRounding" => 5.0,
        "TabBorderSize" => 0.0, "TreeLinesRounding" => 6.0, "DragDropTargetRounding" => 4.0,
    )
        haskey(is_, k) && (is_[k] = Float64(val))
    end

    # ② 强调色:依序在语义色里找第一个足够饱和的,clamp 后派生渐变对
    accent = nothing
    for src in ("IconButton", "HighlightText", "CheckMark", "TextLink", "SliderGrab", "TabSelectedOverline")
        c = get(mc, src, get(ic, src, nothing))
        c === nothing && continue
        if sat(c) > 0.22
            accent = clamp.(collect(Float64, c)[1:3], 0.0, 1.0)
            break
        end
    end
    accent === nothing && (accent = [0.30, 0.60, 0.90])
    mc["AccentTop"] = seta(lift(accent, 0.18), 1.0)
    mc["AccentBottom"] = seta(accent, 1.0)

    # ③④⑤ 新 token(按明暗)
    mc["SuccessText"] = isdark ? [0.35, 0.85, 0.55, 1.0] : [0.20, 0.66, 0.38, 1.0]
    mc["SuccessBg"] = isdark ? [0.35, 0.85, 0.55, 0.42] : [0.20, 0.66, 0.38, 0.40]
    mc["ShadowColor"] = isdark ? [0.0, 0.0, 0.0, 0.30] : [0.25, 0.32, 0.42, 0.20]
    mc["CardBg"] = isdark ? seta(lift(wb, 0.06), 1.0) : [1.0, 1.0, 1.0, 0.72]
    mc["CardBorder"] = isdark ? seta(lift(wb, 0.20), 0.28) : seta(darken(wb, 0.18), 0.22)
    mc["PanelBg"] = isdark ? seta(lift(wb, 0.11), 1.0) : [1.0, 1.0, 1.0, 0.95]
    mc["PanelBorder"] = isdark ? seta(lift(wb, 0.26), 0.12) : seta(darken(wb, 0.22), 0.10)
    mc["ClearColor"] = seta(darken(wb, isdark ? 0.30 : 0.045), 1.0)
    # 分隔线极淡发丝线:静止时不抢视觉(hover/active 保持各主题原有较强值)
    sep = isdark ? lift(wb, 0.16) : darken(wb, 0.14)
    ic["Separator"] = seta(sep, 0.45)

    # ⑥ 变量与联动
    v["ShadowRadius"] = 22.0
    v["CardRounding"] = 8.0
    v["CardPadding"] = [8.0, 8.0]
    v["AnimSpeed"] = 1.0
    v["ToastDuration"] = 4.0
    v["MakieTheme"] = isdark ? "black" : "light"
    v["Wallpaper"] = isdark ? "Styles/Backgrounds/wallpaper_dark.png" : "Styles/Backgrounds/wallpaper_light.png"

    open(file, "w") do io
        TOML.print(io, t)
    end
    println("polished  ", name, "  (", isdark ? "dark" : "light", ", accent=", round.(accent, digits=2), ")")
end
println("done")
