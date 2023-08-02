# conf_path = joinpath(Base.@__DIR__, "../Assets/Necessity/conf.toml")
# insconf_paths = readdir(joinpath(Base.@__DIR__, "../Assets/Confs"); join=true)
# if Sys.iswindows()
#     # run(`attrib -R $conf_path`)
#     # run(`Icacls $conf_path /grant Everyone:F`)
#     for insconf_path in insconf_paths
#         run(`attrib -R $insconf_path`)
#         run(`Icacls $insconf_path /grant Everyone:F`)
#     end
# elseif Sys.islinux()
# end

using ZipFile
url = "https://github.com/FaresX/QInsControlAssets/archive/refs/heads/main.zip"
zipfilepath = joinpath(Base.@__DIR__, "main.zip")
download(url, zipfilepath)
zipfile = ZipFile.Reader(zipfilepath)
for f in zipfile.files
    if f.method == ZipFile.Store
        ispath(joinpath(Base.@__DIR__, f.name)) || mkpath(f.name)
    elseif f.method == ZipFile.Deflate
        open(joinpath(Base.@__DIR__, f.name), "w") do file
            write(file, read(f, String))
        end
    end
end
close(zipfile)
Base.Filesystem.mv(joinpath(Base.@__DIR__, "QInsControlAssets-main"), joinpath(Base.@__DIR__, "../Assets"); force=true)
Base.Filesystem.rm(zipfilepath; force=true)