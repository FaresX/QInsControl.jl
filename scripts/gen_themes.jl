# 主题调色板生成器:以基础主题为底,给定一个强调色派生整套强调色族 token,输出新主题 toml
# 用法:
#   julia --project=. scripts/gen_themes.jl <BaseTheme> <NewName> <R,G,B>   # R,G,B ∈ 0..1
# 示例:
#   julia --project=. scripts/gen_themes.jl OceanBreeze SkyBlue "0.30,0.60,0.90"
#   julia --project=. scripts/gen_themes.jl MidnightLab Violet "0.60,0.40,0.90"
# 说明:只重着色强调色族(渐变对/图标/链接/勾选/选中线等),其余配色沿用基础主题;
#      新文件写入 QInsControlAssets/Styles/<NewName>.toml,重启或 StyleEditor reload 后可选。
using TOML

if length(ARGS) < 3
    println("usage: julia --project=. scripts/gen_themes.jl <BaseTheme> <NewName> <R,G,B>")
    exit(1)
end
base, newname = ARGS[1], ARGS[2]
accent = try
    Tuple(parse(Float64, x) for x in split(ARGS[3], ","))
catch
    println("accent must be \"R,G,B\" with values in 0..1")
    exit(1)
end
length(accent) == 3 || exit(1)

# 开发脚本优先仓库旁的 QInsControlAssets(系统环境变量可能指向已安装版本)
repodir = normpath(joinpath(@__DIR__, "..", "..", "QInsControlAssets"))
assets = isdir(repodir) ? repodir : get(ENV, "QInsControlAssets", repodir)
basepath = joinpath(assets, "Styles", "$base.toml")
isfile(basepath) || error("base theme not found: $basepath")
theme = TOML.parsefile(basepath)

lum(c, f) = [clamp(c[1] * f, 0.0, 1.0), clamp(c[2] * f, 0.0, 1.0), clamp(c[3] * f, 0.0, 1.0)]
# (路径段…, 字段, 亮度系数, alpha 覆盖;alpha≤0 表示保留原字段 alpha)
ACCENT_TOKENS = [
    ("morestyle", "Colors", "AccentTop", 1.15, 1.0),
    ("morestyle", "Colors", "AccentBottom", 1.0, 1.0),
    ("morestyle", "Colors", "IconButton", 1.0, 1.0),
    ("morestyle", "Colors", "HighlightText", 1.18, 1.0),
    ("morestyle", "Colors", "FormatDataGroupBorder", 1.0, 1.0),
    ("morestyle", "Colors", "WidgetBorderSelected", 0.85, 1.0),
    ("morestyle", "Colors", "WidgetBorderHovered", 1.0, 0.0),
    ("morestyle", "Colors", "WidgetBorderDragging", 1.0, 0.0),
    ("morestyle", "Colors", "WidgetRectHovered", 1.0, 0.0),
    ("morestyle", "Colors", "WidgetRectDragging", 1.0, 0.0),
    ("morestyle", "Colors", "BlockDragdrop", 1.0, 0.0),
    ("morestyle", "Colors", "BlockDragdropBorder", 1.1, 1.0),
    ("imguistyle", "Colors", "TextLink", 1.0, 1.0),
    ("imguistyle", "Colors", "CheckMark", 1.0, 1.0),
    ("imguistyle", "Colors", "SliderGrab", 1.0, 0.0),
    ("imguistyle", "Colors", "SliderGrabActive", 1.2, 0.0),
    ("imguistyle", "Colors", "InputTextCursor", 1.0, 1.0),
    ("imguistyle", "Colors", "TabSelectedOverline", 1.0, 1.0),
    ("imguistyle", "Colors", "NavCursor", 1.0, 1.0),
    ("imguistyle", "Colors", "DockingPreview", 1.0, 0.45),
    ("imguistyle", "Colors", "TextSelectedBg", 1.0, 0.35),
    ("imguistyle", "Colors", "TreeLines", 1.0, 0.0),
    ("imguistyle", "Colors", "SeparatorHovered", 1.0, 0.0),
    ("imguistyle", "Colors", "SeparatorActive", 1.2, 0.0),
    ("imguistyle", "Colors", "ResizeGrip", 1.0, 0.0),
    ("imguistyle", "Colors", "ResizeGripHovered", 1.0, 0.0),
    ("imguistyle", "Colors", "ResizeGripActive", 1.2, 0.0),
    ("imnodesstyle", "Colors", "Link", 1.0, 0.0),
    ("imnodesstyle", "Colors", "LinkHovered", 1.0, 0.0),
    ("imnodesstyle", "Colors", "LinkSelected", 1.0, 0.0),
    ("imnodesstyle", "Colors", "Pin", 1.0, 0.0),
    ("imnodesstyle", "Colors", "PinHovered", 1.2, 1.0),
    ("imnodesstyle", "Colors", "BoxSelector", 1.0, 0.0),
    ("imnodesstyle", "Colors", "BoxSelectorOutline", 1.0, 0.0),
]

for (path..., field, factor, alpha) in ACCENT_TOKENS
    sect = theme
    for p in path
        sect = get!(sect, p, Dict{String,Any}())
    end
    haskey(sect, field) || continue  # 基础主题缺字段则跳过(新字段回落代码默认值)
    orig = collect(Float64, sect[field])
    col = lum(accent, factor)
    sect[field] = Any[col[1], col[2], col[3], alpha > 0 ? alpha : orig[4]]
end

outpath = joinpath(assets, "Styles", "$newname.toml")
open(outpath, "w") do io
    TOML.print(io, theme)
end
println("saved $outpath (accent=$accent, base=$base)")
