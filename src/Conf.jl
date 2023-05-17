function loadconf()
    ######gennerate conf######
    conf_dict = TOML.parsefile(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"))
    unitslist = Dict("" => [])
    for Ut::String in keys(conf_dict["U"])
        if Ut != ""
            Us = []
            for U in conf_dict["U"][Ut]
                ustr = occursin(" ", U) ? replace(U, " " => "*") : U
                push!(Us, eval(:(@u_str($ustr))))
            end
            push!(unitslist, Ut => Us)
        end
    end
    push!(unitslist, "" => [""])
    push!(conf_dict, "U" => unitslist)
    global conf = from_dict(Conf, conf_dict)
    isdir(conf.Fonts.dir) || (conf.Fonts.dir = joinpath(ENV["QInsControlAssets"], "Fonts"))
    isdir(conf.Logs.dir) || (conf.Logs.dir = joinpath(ENV["QInsControlAssets"], "Logs"))
    isfile(conf.BGImage.path) || (conf.BGImage.path = joinpath(ENV["QInsControlAssets"], "Necessity/defaultwallpaper.bmp"))
    isfile(conf.Style.dir) || (conf.Style.dir = joinpath(ENV["QInsControlAssets"], "Styles"))

    ######generate insconf######
    include(joinpath(ENV["QInsControlAssets"], "Confs/extra_conf.jl"))
    for file in readdir(joinpath(ENV["QInsControlAssets"], "Confs"), join=true)
        bnm = basename(file)
        split(bnm, '.')[end] != "toml" || gen_insconf(file)
    end

    ######generate instrbufferviewers######
    for key in keys(insconf)
        push!(instrbufferviewers, key => Dict{String,InstrBufferViewer}())
    end
    push!(instrbufferviewers, "VirtualInstr" => Dict("VirtualAddress" => InstrBufferViewer("VirtualInstr", "VirtualAddress")))

    ######load style_conf######
    for file in readdir(conf.Style.dir, join=true)
        bnm = basename(file)
        split(bnm, '.')[end] == "sty" && merge!(styles, load(file))
    end

    return nothing
end

macro scpi(instrnm, quantity, scpistr)
    get = Symbol(instrnm, :_, quantity, :_get)
    occursin("?", scpistr) && return esc(quote
        $get(instr) = query(instr, $scpistr)
    end)
    scpistrs = split(scpistr, " ")
    exget = if length(scpistrs) == 1
        quote
            $get(instr) = query(instr, string($scpistr, "?"))
        end
    elseif length(scpistrs) == 2
        quote
            $get(instr) = query(instr, string($(scpistrs[1]), "? ", $(scpistrs[2])))
        end
    end
    set = Symbol(instrnm, :_, quantity, :_set)
    exset = if length(scpistrs) == 1
        quote
            $set(instr, val) = write(instr, string($scpistr, " ", val))
        end
    elseif length(scpistrs) == 2
        quote
            $set(instr, val) = write(instr, string($scpistr, ", ", val))
        end
    end
    esc(Expr(:block, exget, exset))
end

macro tsp(instrnm, quantity, tspstr)
    get = Symbol(instrnm, :_, quantity, :_get)
    tspstr[end-1:end] == "()" && return esc(quote
        $get(instr) = query(instr, string("print(", $tspstr, ")"))
    end)
    set = Symbol(instrnm, :_, quantity, :_set)
    ex = quote
        function $set(instr, val)
            write(instr, string($tspstr, "=", val))
        end
        function $get(instr)
            query(instr, string("print(", $tspstr, ")"))
        end
    end
    esc(ex)
end

function gen_insconf(conf_file)
    local conf = TOML.parsefile(conf_file)
    instrnm = Symbol(split(basename(conf_file), ".")[1])
    if !isempty(conf["conf"]["cmdtype"])
        cmdtype = Symbol("@", conf["conf"]["cmdtype"])
        for pair in conf
            if pair.first != "conf" && !isempty(pair.second["cmdheader"])
                eval(Expr(:macrocall, cmdtype, LineNumberNode(Base.@__LINE__, Base.@__FILE__), instrnm, pair.first, pair.second["cmdheader"]))
            end
        end
    end
    oneinsconf = OneInsConf()
    for cf in conf
        if cf.first == "conf"
            oneinsconf.conf = BasicConf(cf.second)
        else
            push!(oneinsconf.quantities, cf.first => QuantityConf(cf.second))
        end
    end
    push!(insconf, string(instrnm) => oneinsconf)
end
