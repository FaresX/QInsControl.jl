conf_path = joinpath(dirname(pathof(QInsControl)), "../Assets/Necessity/conf.toml")
insconf_paths = readdir(joinpath(dirname(pathof(QInsControl)), "../Assets/Confs"))
run(`attrib -R $conf_path`)
for insconf_path in insconf_paths run(`attrib -R $insconf_path`) end