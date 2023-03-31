using TOML
for file in readdir(joinpath(ENV["QInsControlAssets"], "conf"), join=true)
    bnm = basename(file)
    if bnm != "conf.toml" && split(bnm, '.')[end] == "toml"
        conf_dict = TOML.parsefile(file)
        for cf in conf_dict
            if cf.first == "conf"
            else
                # push!(conf_dict[cf.first], "enable" => true)
                conf_dict[cf.first]["optvalues"] == "" && (conf_dict[cf.first]["optvalues"] = [])
            end
        end
        open(file, "w") do file
            TOML.print(file, conf_dict)
        end
    end
end