loadingtypes = [:OptBasic, :OptCommunication, :OptDtViewer, :OptDAQ, :OptInsBuf, :OptServer,
    :OptRegister, :OptFonts, :OptConsole, :OptLogs, :OptOneBGImage,
    :OptBGImage, :OptComAddr, :OptStyle, :Conf,
    :BasicConf, :QuantityConf,
    :InstrWidget, :QuantityWidget, :QuantityWidgetOption,
    :QImGuiColors, :QImGuiStyle, :QImNodesColors, :QImNodesStyle,
    :MoreStyleColor, :MoreStyleIcon, :MoreStyleVariable, :MoreStyle, :UnionStyle
]

for T in loadingtypes
    eval(
        quote
            function $T(conf::Dict)
                t = $T()
                for fdnm in fieldnames($T)
                    val = get!(conf, string(fdnm), getproperty(t, fdnm))
                    if val isa Dict
                        ft = fieldtype($T, fdnm)
                        if ft <: Dict
                            setproperty!(t, fdnm, val)
                        else
                            setproperty!(t, fdnm, ft(val))
                        end
                    elseif val isa Vector && fieldtype($T, fdnm).parameters[1] in [$(loadingtypes...)]
                        elft = fieldtype($T, fdnm).parameters[1]
                        setproperty!(t, fdnm, [elft(v) for v in val])
                    else
                        setproperty!(t, fdnm, val)
                    end
                end
                return t
            end
        end
    )
end

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
                        push!(Us, strtoU(U))
                    end
                    unitslist[Ut] = Us
                end
            end
            unitslist[""] = [""]
            conf_dict["U"] = unitslist
            Conf(conf_dict)
        end
    else
        Conf()
    end
    if !precompile
        isfile(CONF.Communication.visapath) || (CONF.Communication.visapath = QInsControlCore.find_visa())
        isfile(CONF.Communication.visapath) && QInsControlCore.set_libvisa(CONF.Communication.visapath)
    end
    isdir(CONF.Console.dir) || (CONF.Console.dir = joinpath(ENV["QInsControlAssets"], "IOs"))
    isdir(CONF.Logs.dir) || (CONF.Logs.dir = joinpath(ENV["QInsControlAssets"], "Logs"))
    isfile(CONF.BGImage.main.path) || (CONF.BGImage.main.path = joinpath(ENV["QInsControlAssets"], "Necessity/defaultwallpaper.png"))
    isfile(CONF.Style.dir) || (CONF.Style.dir = joinpath(ENV["QInsControlAssets"], "Styles"))

    ###### load language ######
    CONF.Basic.languages = languageinfo()
    haskey(CONF.Basic.languages, CONF.Basic.language) && loadlanguage(CONF.Basic.languages[CONF.Basic.language])

    ###### load INSTRCONF ######
    loadinsconf(false)

    ###### generate INSWCONF ######
    loadinswconf()

    ###### generate INSTRBUFFERVIEWERS ######
    for ins in keys(INSTRCONF)
        INSTRBUFFERVIEWERS[ins] = Dict{String,InstrBufferViewer}()
    end
    INSTRBUFFERVIEWERS["VirtualInstr"] = Dict("VirtualAddress" => InstrBufferViewer("VirtualInstr", "VirtualAddress"))

    ###### load style_conf ######
    loadstyles()

    ###### save conf.toml ######
    saveconf()

    return nothing
end

function loadinswconf()
    for file in readdir(joinpath(ENV["QInsControlAssets"], "Widgets"), join=true)
        bnm = basename(file)
        instrnm, filetype = split(bnm, '.')
        @trycatch mlstr("loading inswconf failed!!!") begin
            if filetype == "toml"
                widgets = TOML.parsefile(file)
                INSWCONF[instrnm] = []
                for (_, widget) in widgets
                    push!(INSWCONF[instrnm], InstrWidget(widget))
                end
            end
        end
    end
end

function loadstyles()
    for file in readdir(CONF.Style.dir, join=true)
        bnm = basename(file)
        @trycatch mlstr("loading style failed!!!") begin
            endswith(bnm, ".toml") && (STYLES[bnm[1:end-5]] = UnionStyle(TOML.parsefile(file)))
        end
    end
end

function saveconf()
    svconf = deepcopy(CONF)
    svconf.U = Dict(up.first => string.(up.second) for up in CONF.U)
    @trycatch mlstr("saving configurations failed!!!") to_toml(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"), svconf)
end

function loadinsconf(gen_func=true)
    for file in readdir(joinpath(ENV["QInsControlAssets"], "ExtraLoad"), join=true)
        @trycatch mlstr("loading drivers failed!!!") begin
            endswith(basename(file), ".jl") && gen_func && QInsControlCore.remote_include(file)
        end
    end
    for file in readdir(joinpath(ENV["QInsControlAssets"], "Confs"), join=true)
        bnm = basename(file)
        @trycatch mlstr("loading insconf failed!!!") begin
            endswith(bnm, ".toml") && gen_insconf(file; gen_func)
        end
    end
end

function gen_insconf(conf_file; gen_func=true)
    conf = TOML.parsefile(conf_file)
    instrnm = Symbol(split(basename(conf_file), '.')[1])
    cmdtype = conf["conf"]["cmdtype"]
    if !isempty(cmdtype)
        for pair in conf
            if pair.first != "conf" && !isempty(pair.second["cmdheader"])
                gen_func && QInsControlCore.gen_qtfunc(instrnm, pair.first, pair.second["cmdheader"], cmdtype)
            end
        end
    end
    oneinsconf = OneInstrConf()
    for cf in conf
        if cf.first == "conf"
            oneinsconf.conf = BasicConf(cf.second)
        else
            oneinsconf.quantities[cf.first] = QuantityConf(cf.second)
        end
    end
    INSTRCONF[string(instrnm)] = oneinsconf
end