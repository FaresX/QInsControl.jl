const QINSCONTROLVERSION = pkgversion(QInsControl)
const JLD2VERSION = pkgversion(JLD2)

let
    jlverinfobuf = IOBuffer()
    versioninfo(jlverinfobuf)
    jlverinfo = String(take!(jlverinfobuf))
    global function fileinfo()
        OrderedDict(
            "QInsControl version" => QINSCONTROLVERSION,
            "JLD2 version" => JLD2VERSION,
            "Julia version" => jlverinfo
        )
    end
end