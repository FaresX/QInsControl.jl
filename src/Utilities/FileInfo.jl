let
    jlverinfobuf = IOBuffer()
    versioninfo(jlverinfobuf)
    jlverinfo = wrapmultiline(String(take!(jlverinfobuf)), 48)
    QInsControlVersion = pkgversion(QInsControl)
    JLD2Version = pkgversion(JLD2)
    global FILEINFO::OrderedDict{String,Union{VersionNumber, String}} = OrderedDict(
        "QInsControl version" => QInsControlVersion,
        "JLD2 version" => JLD2Version,
        "Julia version" => jlverinfo
    )
end