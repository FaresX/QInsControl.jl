module QInsControl

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui.ImGuiGLFWBackend
using CImGui.ImGuiOpenGLBackend
using CImGui.ImGuiGLFWBackend.LibGLFW
using CImGui.ImGuiOpenGLBackend.ModernGL
using CImGui.LibCImGui
using ImPlot
using NativeFileDialog
using Unitful
using MacroTools
import FileIO
using JLD2
using Configurations
using ColorTypes
using OrderedCollections
using StringEncodings
import ImageMagick
# using ImageIO

import Base: +, -, /
using Distributed
using SharedArrays
using TOML
using Dates
using UUIDs
using Printf
using InteractiveUtils
using Logging

include("QInsControlCore/QInsControlCore.jl")
using .QInsControlCore

@enum SyncStatesIndex begin
    autodetecting = 1 #是否正在自动查询仪器
    autodetect_done 
    isdaqtask_running 
    isdaqtask_done 
    isinterrupt 
    isblock
    isautorefresh
    newloging
    savingimg
end
const SyncStates::Vector{Bool} = falses(9)

const CPU = Processor()

include("Configurations.jl")
include("Instrument.jl")
include("Utilities.jl")
include("StaticString.jl")
include("UI/NodesEditor.jl")
include("UI/IconsFontAwesome6.jl")
include("UI/IconSelector.jl")
include("UI/UtilitiesForRenderer.jl")
include("UI/CombinedWidgets.jl")
include("UI/StyleEditor.jl")
include("UI/Progress.jl")
include("UI/FileTree.jl")
include("UI/Plot.jl")
include("UI/Block.jl")
include("UI/DataPicker.jl")
include("UI/DataViewer.jl")
include("UI/Preferences.jl")
include("UI/CPUMonitor.jl")
include("UI/InstrBuffer.jl")
include("UI/InstrRegister.jl")
include("UI/DAQTask.jl")
include("UI/DAQ.jl")
include("UI/Console.jl")
include("UI/Logger.jl")
# include("UI/HelpPad.jl")
include("UI/ShowAbout.jl")
include("UI/MainWindow.jl")
include("UI/Renderer.jl")
include("JLD2Struct.jl")
include("Conf.jl")

function julia_main()::Cint
    try
        loadconf()
        # global logio = IOBuffer()
        # global_logger(SimpleLogger(logio))
        # errormonitor(@async while true
        #     sleep(1)
        #     update_log()
        # end)
        @info ARGS
        isempty(ARGS) || @info reencoding.(ARGS, conf.Basic.encoding)
        uitask = UI()
        start!(CPU)
        jlverinfobuf = IOBuffer()
        versioninfo(jlverinfobuf)
        global jlverinfo = wrapmultiline(String(take!(jlverinfobuf)), 48)
        autorefresh()
        @info "[$(now())]\n启动成功！"
        if !isinteractive()
            wait(uitask)
            while SyncStates[Int(isdaqtask_running)]
                yield()
            end
            sleep(0.1)
            exit()
        end
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

function start()
    if !haskey(ENV, "QInsControlAssets")
        ENV["QInsControlAssets"] = joinpath(dirname(pathof(QInsControl)), "../Assets")
    end
    julia_main()
end

end #QInsControl
