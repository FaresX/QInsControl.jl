# 生成主题壁纸(浅色/深色/中性)到 QInsControlAssets/Styles/Backgrounds/
# 用法:julia --project=. scripts/make_wallpapers.jl
using FileIO
using ColorTypes
# N0f8 来自间接依赖 FixedPointNumbers(已随 ColorTypes 加载),从已加载模块表中取
const N0f8 = getfield(
    first(m for (id, m) in Base.loaded_modules if id.name == "FixedPointNumbers"), :N0f8
)

function gradient_image(w, h, c1, c2; glow_center=(0.75, 0.2), glow_color=(1.0, 1.0, 1.0), glow_strength=0.5, glow_radius=0.45)
    img = Matrix{RGBA{N0f8}}(undef, h, w)
    for y in 1:h, x in 1:w
        t = 0.5 * (x / w + y / h)  # 对角渐变
        r = c1[1] + (c2[1] - c1[1]) * t
        g = c1[2] + (c2[2] - c1[2]) * t
        b = c1[3] + (c2[3] - c1[3]) * t
        # 大半径柔和径向光晕
        d = hypot((x - 1) / w - glow_center[1], (y - 1) / h - glow_center[2])
        f = glow_strength * exp(-(d / glow_radius)^2)
        r += (glow_color[1] - r) * f
        g += (glow_color[2] - g) * f
        b += (glow_color[3] - b) * f
        img[y, x] = RGBA{N0f8}(r, g, b, 1.0)
    end
    img
end

const W, H = 1600, 900
const outdir = joinpath(@__DIR__, "../../QInsControlAssets/Styles/Backgrounds")
isdir(outdir) || mkpath(outdir)

wallpapers = Dict(
    "wallpaper_light.png" => (c1=(0.965, 0.975, 0.988), c2=(0.845, 0.900, 0.955),
        glow_color=(1.0, 1.0, 1.0), glow_strength=0.5, glow_radius=0.45),
    "wallpaper_dark.png" => (c1=(0.055, 0.075, 0.115), c2=(0.105, 0.145, 0.215),
        glow_color=(0.12, 0.38, 0.60), glow_strength=0.5, glow_radius=0.42),
    "wallpaper_neutral.png" => (c1=(0.930, 0.940, 0.960), c2=(0.775, 0.820, 0.880),
        glow_color=(1.0, 1.0, 1.0), glow_strength=0.35, glow_radius=0.5),
)

for (name, kw) in wallpapers
    path = joinpath(outdir, name)
    FileIO.save(path, gradient_image(W, H, kw.c1, kw.c2; glow_color=kw.glow_color, glow_strength=kw.glow_strength, glow_radius=kw.glow_radius))
    println("saved ", path)
end
