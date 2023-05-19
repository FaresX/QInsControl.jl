using TOML
using PackageCompiler

# ENV["QInsControlAssets"] = "Assets"
app_source_dir = Base.@__DIR__
app_compiled_dir = "C:\\Users\\22112\\Desktop\\QInsControl"
# create_app(app_source_dir, app_compiled_dir, precompile_execution_file=joinpath(app_source_dir, "precompile.jl"), filter_stdlibs=true)
# compiletask = @async create_app(app_source_dir, app_compiled_dir, precompile_execution_file=joinpath(app_source_dir, "precompile.jl"), force=true, include_lazy_artifacts=true)
# compiletask = @async create_app(app_source_dir, app_compiled_dir, precompile_execution_file=joinpath(app_source_dir, "precompile.jl"), force=true)
compiletask = @async create_app(app_source_dir, app_compiled_dir, precompile_execution_file=joinpath(app_source_dir, "precompile.jl"), force=true, include_lazy_artifacts=true, sysimage_build_args=`--cpu-target="$(PackageCompiler.default_app_cpu_target())"`)
errormonitor(compiletask)

cptask = @async begin
    sleep(120)
    # Base.Filesystem.rm(app_compiled_dir, force=true, recursive=true)
    # ispath(joinpath(app_compiled_dir, "bin\\conf\\")) || mkpath(joinpath(app_compiled_dir, "bin\\conf\\"))
    # ispath(joinpath(app_compiled_dir, "fonts")) || mkpath(joinpath(app_compiled_dir, "fonts"))
    # ispath(joinpath(app_compiled_dir, "bin\\Assets")) || mkpath(joinpath(app_compiled_dir, "bin\\Assets"))
    cpsourcedir = joinpath(app_source_dir, "Assets")
    cpdstdir = joinpath(app_compiled_dir, "Assets")
    run(`xcopy $cpsourcedir $cpdstdir /E/Y/i`)
    Base.Filesystem.rm(joinpath(cpdstdir, "Logs"), recursive=true, force=true)
    # for conf in readdir(joinpath(app_source_dir, "conf"), join=true)
    #     Base.Filesystem.cp(conf, joinpath(app_compiled_dir, "bin\\conf", basename(conf)), force=true)
    # end
    # for font in readdir(joinpath(app_source_dir, "fonts"), join=true)
    #     Base.Filesystem.cp(font, joinpath(app_compiled_dir, "fonts", basename(font)), force=true)
    # end
    Base.Filesystem.cp(joinpath(app_source_dir, "src/UI/QInsControl.ico"), joinpath(app_compiled_dir, "bin\\QInsControl.ico"), force=true)
    Base.Filesystem.cp(joinpath(app_source_dir, "src/defaultwallpaper.bmp"), joinpath(app_compiled_dir, "bin\\defaultwallpaper.bmp"), force=true)
    Base.Filesystem.cp(joinpath(app_source_dir, "src/Logger.jl"), joinpath(app_compiled_dir, "bin\\Logger.jl"), force=true)
    Base.Filesystem.cp(joinpath(app_source_dir, "src/UI/fa-regular-400.ttf"), joinpath(app_compiled_dir, "bin\\fa-regular-400.ttf"), force=true)
    Base.Filesystem.cp(joinpath(app_source_dir, "src/UI/fa-solid-900.ttf"), joinpath(app_compiled_dir, "bin\\fa-solid-900.ttf"), force=true)
    # Base.Filesystem.cp(joinpath(app_source_dir, "settinglogsdir.bat"), joinpath(app_compiled_dir, "settinglogsdir.bat"), force=true)
    # Base.Filesystem.cp(joinpath(app_source_dir, "settinglogsdir.jl"), joinpath(app_compiled_dir, "settinglogsdir.jl"), force=true)
    # Base.Filesystem.cp(joinpath(app_source_dir, "imgui.ini"), joinpath(app_compiled_dir, "bin\\imgui.ini"), force=true)
    # Base.Filesystem.cp(joinpath(app_source_dir, "conf/style_conf.sty"), joinpath(app_compiled_dir, "bin\\conf\\style_conf.sty"))
    # conf = TOML.parsefile(joinpath(app_compiled_dir, "bin\\conf\\conf.toml"))
    # conf["Fonts"]["dir"] = "../fonts"
    # conf["Logs"]["dir"] = "../Logs"
    # conf["Style"]["dir"] = "conf"
    # open(joinpath(app_compiled_dir, "bin\\conf\\conf.toml"), "w") do file
    #     TOML.print(file, conf)
    # end
end
errormonitor(cptask)
wait(compiletask)