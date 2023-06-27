conf_path = joinpath(Base.@__DIR__, "../Assets/Necessity/conf.toml")
insconf_paths = readdir(joinpath(Base.@__DIR__, "../Assets/Confs"))
run(`attrib -R $conf_path`)
for insconf_path in insconf_paths run(`attrib -R $insconf_path`) end