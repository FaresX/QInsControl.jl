#数据文件(.qdt/.cfg 及其 cache)的格式版本:写入方打戳,读取方暂只容忍不校验;
#未来结构性变更据此走外置迁移脚本(与文件夹工程的 PROJ_FMT_VERSION 同思路,见 Windows/ProjectFolder.jl)
const QDTFMTVERSION = 1

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