module QInsControl

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui.ImGuiGLFWBackend
using CImGui.ImGuiOpenGLBackend
using CImGui.ImGuiGLFWBackend.LibGLFW
using CImGui.ImGuiOpenGLBackend.ModernGL
using CImGui.LibCImGui
using ColorTypes
using Configurations
using DataInterpolations
import FileIO
import ImageMagick
using ImPlot
using JLD2
using MacroTools
using NativeFileDialog
using OrderedCollections
using PrecompileTools
using StringEncodings
using Unitful
# using ImageIO

using Dates
using Distributed
using InteractiveUtils
using Logging
using Printf
using SharedArrays
using TOML
using UUIDs

include("QInsControlCore/QInsControlCore.jl")
using .QInsControlCore

@enum SyncStatesIndex begin
    AutoDetecting = 1 #是否正在自动查询仪器
    AutoDetectDone
    IsDAQTaskRunning
    IsDAQTaskDone
    IsInterrupted
    IsBlocked
    IsAutoRefreshing
    NewLogging
    SavingImg
end

const CPU = Processor()
const DATABUF = Dict{String,Vector{String}}() #数据缓存
const DATABUFPARSED = Dict{String,Vector{Float64}}()
const PROGRESSLIST = OrderedDict{UUID,Tuple{UUID,Int,Int,Float64}}() #进度条缓存

global SYNCSTATES::SharedVector{Bool}
global DATABUFRC::RemoteChannel{Channel{Vector{NTuple{2,String}}}}
global PROGRESSRC::RemoteChannel{Channel{Vector{Tuple{UUID,Int,Int,Float64}}}}

include("Configurations.jl")
include("MultiLanguage.jl")
include("StaticString.jl")
include("Utilities.jl")

include("UI/Block.jl")
include("UI/CombinedWidgets.jl")
include("UI/DAQTask.jl")
include("UI/FileTree.jl")
include("UI/IconsFontAwesome6.jl")
include("UI/IconSelector.jl")
include("UI/NodesEditor.jl")
include("UI/Instrument.jl")
include("UI/Plot.jl")
include("UI/Progress.jl")
include("UI/DataPicker.jl")
include("UI/UtilitiesForRenderer.jl")

include("UI/DataViewer.jl")
include("UI/StyleEditor.jl")
include("UI/Preferences.jl")
include("UI/InstrRegister.jl")
include("UI/CPUMonitor.jl")
include("UI/InstrBuffer.jl")
include("UI/DAQ.jl")
include("UI/Console.jl")
include("UI/Logger.jl")
include("UI/ShowAbout.jl")
include("UI/MainWindow.jl")
include("UI/Renderer.jl")

# include("AuxFunc.jl")
include("JLD2Struct.jl")
include("Conf.jl")
include("Compatible.jl")

function julia_main()::Cint
    try
        loadconf()
        databuf_c::Channel{Vector{Tuple{String,String}}} = Channel{Vector{NTuple{2,String}}}(CONF.DAQ.channel_size)
        progress_c::Channel{Vector{Tuple{UUID,Int,Int,Float64}}} = Channel{Vector{Tuple{UUID,Int,Int,Float64}}}(CONF.DAQ.channel_size)
        global SYNCSTATES = SharedVector{Bool}(9)
        global DATABUFRC = RemoteChannel(() -> databuf_c)
        global PROGRESSRC = RemoteChannel(() -> progress_c)
        global LOGIO = IOBuffer()
        global_logger(SimpleLogger(LOGIO))
        errormonitor(@async while true
            sleep(1)
            update_log()
        end)
        @info ARGS
        isempty(ARGS) || @info reencoding.(ARGS, CONF.Basic.encoding)
        uitask = UI()
        jlverinfobuf = IOBuffer()
        versioninfo(jlverinfobuf)
        global JLVERINFO = wrapmultiline(String(take!(jlverinfobuf)), 48)
        if CONF.Basic.isremote
            nprocs() == 1 && addprocs(1)
            @eval @everywhere using QInsControl
            SYNCSTATES = SharedVector{Bool}(9)
            DATABUFRC = RemoteChannel(() -> databuf_c)
            PROGRESSRC = RemoteChannel(() -> progress_c)
            remotecall_wait(workers()[1], SYNCSTATES) do syncstates
                loadconf()
                global LOGIO = IOBuffer()
                global_logger(SimpleLogger(LOGIO))
                errormonitor(@async while true
                    sleep(1)
                    update_log(syncstates=syncstates)
                end)
            end
            ENV["JULIA_NUM_THREADS"] = CONF.Basic.nthreads
            CONF.Basic.remoteprocessdata && nprocs() == 2 && addprocs(1)
        end
        remotecall_wait(() -> start!(CPU), workers()[1])
        autorefresh()
        @info "[$(now())]\n$(mlstr("successfully started!"))"
        if !isinteractive()
            wait(uitask)
            while SYNCSTATES[Int(IsDAQTaskRunning)]
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
    get!(ENV, "QInsControlAssets", joinpath(Base.@__DIR__, "../Assets"))
    julia_main()
end

@compile_workload begin
    get!(ENV, "QInsControlAssets", joinpath(Base.@__DIR__, "../Assets"))
    global SYNCSTATES = SharedVector{Bool}(9)
    loadconf()
    try
        UI(precompile=true) |> wait
    catch
    end
end

end #QInsControl
