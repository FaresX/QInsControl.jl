# conf_path = joinpath(Base.@__DIR__, "../Assets/Necessity/conf.toml")
insconf_paths = readdir(joinpath(Base.@__DIR__, "../Assets/Confs"); join=true)
if Sys.iswindows()
    # run(`attrib -R $conf_path`)
    # run(`Icacls $conf_path /grant Everyone:F`)
    for insconf_path in insconf_paths
        run(`attrib -R $insconf_path`)
        run(`Icacls $insconf_path /grant Everyone:F`)
    end
elseif Sys.islinux()
end