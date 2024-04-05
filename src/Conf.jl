function loadconf(precompile=false)
    ###### gennerate conf ######
    conf_file = joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml")
    global CONF = if isfile(conf_file)
        conf_dict = @trypasse TOML.parsefile(conf_file) nothing
        if isnothing(conf_dict)
            Conf()
        else
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
            try_from_dict(Conf, conf_dict)
        end
    else
        Conf()
    end
    if !precompile
        isfile(CONF.Communication.visapath) || (CONF.Communication.visapath = QInsControlCore.find_visa())
        isfile(CONF.Communication.visapath) && (QInsControlCore.Instruments.libvisa = CONF.Communication.visapath)
        QInsControlCore.VIASYNC = CONF.Communication.async
    end
    isdir(CONF.Fonts.dir) || (CONF.Fonts.dir = joinpath(ENV["QInsControlAssets"], "Fonts"))
    isdir(CONF.Console.dir) || (CONF.Console.dir = joinpath(ENV["QInsControlAssets"], "IOs"))
    isdir(CONF.Logs.dir) || (CONF.Logs.dir = joinpath(ENV["QInsControlAssets"], "Logs"))
    isfile(CONF.BGImage.path) || (CONF.BGImage.path = joinpath(ENV["QInsControlAssets"], "Necessity/defaultwallpaper.png"))
    isfile(CONF.Style.dir) || (CONF.Style.dir = joinpath(ENV["QInsControlAssets"], "Styles"))

    ###### load language ######
    CONF.Basic.languages = languageinfo()
    haskey(CONF.Basic.languages, CONF.Basic.language) && loadlanguage(CONF.Basic.languages[CONF.Basic.language])

    ###### generate INSCONF ######
    for file in readdir(joinpath(ENV["QInsControlAssets"], "ExtraLoad"), join=true)
        try
            endswith(basename(file), ".jl") && include(file)
        catch e
            @error mlstr("loading drivers failed!!!") exception = e file = file
        end
    end
    for file in readdir(joinpath(ENV["QInsControlAssets"], "Confs"), join=true)
        bnm = basename(file)
        try
            endswith(bnm, ".toml") && gen_insconf(file)
        catch e
            @error mlstr("loading file failed!!!") file = file excepiton = e
        end
    end

    ###### generate INSWCONF ######
    for file in readdir(joinpath(ENV["QInsControlAssets"], "Widgets"), join=true)
        bnm = basename(file)
        instrnm, filetype = split(bnm, '.')
        try
            if filetype == "toml"
                widgets = TOML.parsefile(file)
                push!(INSWCONF, instrnm => [])
                for (_, widget) in widgets
                    push!(INSWCONF[instrnm], try_from_dict(InstrWidget, widget))
                end
            end
        catch e
            @error mlstr("loading file failed!!!") file = file exception = e
        end
    end

    if myid() == 1
        ###### generate INSTRBUFFERVIEWERS ######
        for ins in keys(INSCONF)
            push!(INSTRBUFFERVIEWERS, ins => Dict{String,InstrBufferViewer}())
        end
        push!(INSTRBUFFERVIEWERS, "VirtualInstr" => Dict("VirtualAddress" => InstrBufferViewer("VirtualInstr", "VirtualAddress")))

        ###### load style_conf ######
        for file in readdir(CONF.Style.dir, join=true)
            bnm = basename(file)
            try
                endswith(bnm, ".sty") && merge!(STYLES, load(file))
            catch e
                @error mlstr("loading file failed!!!") file = file exception = e
            end
        end

        ###### save conf.toml ######
        svconf = deepcopy(CONF)
        svconf.U = Dict(up.first => string.(up.second) for up in CONF.U)
        to_toml(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"), svconf)
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
    conf = TOML.parsefile(conf_file)
    instrnm = Symbol(split(basename(conf_file), '.')[1])
    if !isempty(conf["conf"]["cmdtype"])
        cmdtype = Symbol("@", conf["conf"]["cmdtype"])
        for pair in conf
            if pair.first != "conf" && !isempty(pair.second["cmdheader"])
                Expr(
                    :macrocall,
                    cmdtype,
                    LineNumberNode(Base.@__LINE__, Base.@__FILE__),
                    instrnm,
                    pair.first,
                    pair.second["cmdheader"]
                ) |> eval
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
    push!(INSCONF, string(instrnm) => oneinsconf)
end

function try_from_dict(t::Type, dict)
    cf = t()
    try
        cf = from_dict(t, dict)
    catch e
        @error mlstr("invalid configuration file, trying refactoring") exception = e
        cfdict = to_dict(cf)
        cf = from_dict(t, mergeconf!(cfdict, dict))
    end
    return cf
end

function mergeconf!(cfdict, dict)
    for (key, val) in cfdict
        if haskey(dict, key)
            if val isa AbstractDict
                mergeconf!(val, dict[key])
            else
                oldval = @trypass convert(typeof(val), dict[key]) nothing
                isnothing(oldval) || (cfdict[key] = dict[key])
            end
        end
    end
    return cfdict
end