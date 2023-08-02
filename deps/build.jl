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

url = "https://github.com/FaresX/QInsControlAssets/archive/refs/heads/main.zip"
rootpath = joinpath(Base.@__DIR__, "..")
zipfilepath = download(url, joinpath(rootpath, "main.zip"))
zipfile = ZipFile.Reader(zipfilepath)
for f in zipfile.files
    if f.method == ZipFile.Store
        ispath(joinpath(rootpath, f.name)) || mkpath(f.name)
    elseif f.method == ZipFile.Deflate
        open(joinpath(rootpath, f.name), "w") do file
            write(file, read(f, String))
        end
    end
end
Base.Filesystem.rm(zipfilepath; force=true)