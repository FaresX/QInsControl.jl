conf_path = joinpath(Base.@__DIR__, "../Assets/Necessity/conf.toml")
insconf_paths = readdir(joinpath(Base.@__DIR__, "../Assets/Confs"))
run(`attrib -R $conf_path`)
run(`CACLS $conf_path /p Everyone:W`)
for insconf_path in insconf_paths
    run(`attrib -R $insconf_path`)
    run(`CACLS $insconf_path /p Everyone:W`)
end