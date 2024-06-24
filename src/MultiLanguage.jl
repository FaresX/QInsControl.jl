const MLSTRINGS = Dict{String,String}()

mlstr(str::AbstractString) = get!(MLSTRINGS, str, str)

function languageinfo()
    languages = Dict()
    for file in readdir(joinpath(ENV["QInsControlAssets"], "Languages"); join=true)
        bnm = basename(file)
        if endswith(bnm, ".toml") && bnm != "default.toml"
            languages[TOML.parsefile(file)["__language_name"]] = file
        end
    end
    return languages
end

function loadlanguage(file)
    @trycatch mlstr("loading language failed!!!") begin
        empty!(MLSTRINGS)
        merge!(MLSTRINGS, TOML.parsefile(file))
        delete!(MLSTRINGS, "__language_name")
    end
end

function gen_template()
    open(joinpath(ENV["QInsControlAssets"], "Languages/default.toml"), "w") do file
        TOML.print(file, Dict("__language_name" => "default"))
        TOML.print(file, MLSTRINGS)
    end
end
