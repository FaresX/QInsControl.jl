let
    jlverinfobuf = IOBuffer()
    versioninfo(jlverinfobuf)
    jlverinfo = String(take!(jlverinfobuf))
    global function fileinfo()
        OrderedDict(
            "QInsControl version" => pkgversion(QInsControl),
            "JLD2 version" => pkgversion(JLD2),
            "Julia version" => jlverinfo
        )
    end
end