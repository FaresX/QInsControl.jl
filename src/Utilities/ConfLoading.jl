for T in [:OptBasic, :OptCommunication, :OptDtViewer, :OptDAQ, :OptInsBuf, :OptServer,
    :OptRegister, :OptFonts, :OptConsole, :OptLogs, :OptOneBGImage,
    :OptBGImage, :OptComAddr, :OptStyle, :Conf,
    :BasicConf, :QuantityConf,
    :InstrWidget, :QuantityWidget, :QuantityWidgetOption
]
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
                    else
                        setproperty!(t, fdnm, val)
                    end
                end
                return t
            end
        end
    )
end