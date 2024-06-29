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
using JpegTurbo
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
using .QInsControlCore.LibSerialPort
import .QInsControlCore: VISAInstrAttr, SerialInstrAttr, TCPSocketInstrAttr, VirtualInstrAttr

@enum SyncStatesIndex begin
    AutoDetecting = 1 #是否正在自动查询仪器
    AutoDetectDone
    IsDAQTaskRunning
    IsDAQTaskDone
    IsInterrupted
    IsBlocked
    IsAutoRefreshing
    NewLogging
end

const CPU = Processor()
const DATABUF = Dict{String,Vector{String}}() #数据缓存
const DATABUFPARSED = Dict{String,VecOrMat{Cdouble}}()
const PROGRESSLIST = OrderedDict{UUID,Tuple{UUID,Int,Int,Float64}}() #进度条缓存

global SYNCSTATES::SharedVector{Bool}
global DATABUFRC::RemoteChannel{Channel{Vector{NTuple{2,String}}}}
global PROGRESSRC::RemoteChannel{Channel{Vector{Tuple{UUID,Int,Int,Float64}}}}

global LOGIO = stdout

include("Utilities.jl")
include("Configurations.jl")
include("MultiLanguage.jl")
include("StaticString.jl")

include("UI/Block.jl")
include("UI/CustomWidgets/CustomWidgets.jl")
include("UI/DAQTask.jl")
include("UI/FileTree.jl")
include("UI/IconsFontAwesome6.jl")
include("UI/IconSelector.jl")
include("UI/NodesEditor.jl")
include("UI/Instrument.jl")
include("UI/Plot.jl")
include("UI/Progress.jl")
include("UI/DataPicker.jl")
include("UI/DataPlot.jl")
include("UI/UtilitiesForRenderer.jl")

include("UI/DataViewer.jl")
include("UI/DataFormatter.jl")
include("UI/StyleEditor.jl")
include("UI/Preferences.jl")
include("UI/CPUMonitor.jl")
include("UI/InstrBuffer.jl")
include("UI/InstrRegister.jl")
include("UI/InstrWidget.jl")
include("UI/DAQ.jl")
include("UI/Console.jl")
include("UI/Logger.jl")
include("UI/ShowAbout.jl")
include("UI/MainWindow.jl")
include("UI/Renderer.jl")

# include("AuxFunc.jl")
include("JLD2Struct.jl")
include("Conf.jl")

function julia_main()::Cint
    try
        initialize!()
        loadconf()
        databuf_c::Channel{Vector{Tuple{String,String}}} = Channel{Vector{NTuple{2,String}}}(CONF.DAQ.channelsize)
        progress_c::Channel{Vector{Tuple{UUID,Int,Int,Float64}}} = Channel{Vector{Tuple{UUID,Int,Int,Float64}}}(CONF.DAQ.channelsize)
        global SYNCSTATES = SharedVector{Bool}(8)
        global DATABUFRC = RemoteChannel(() -> databuf_c)
        global PROGRESSRC = RemoteChannel(() -> progress_c)
        global LOGIO = IOBuffer()
        global_logger(SimpleLogger(LOGIO))
        @async @trycatch mlstr("error in logging task") while true
            update_log()
            sleep(1)
        end
        jlverinfobuf = IOBuffer()
        versioninfo(jlverinfobuf)
        global JLVERINFO = wrapmultiline(String(take!(jlverinfobuf)), 48)
        @info ARGS
        isempty(ARGS) || @info reencoding.(ARGS, CONF.Basic.encoding)
        uitask = UI()
        if CONF.Basic.isremote
            ENV["JULIA_NUM_THREADS"] = CONF.Basic.nthreads_2
            nprocs() == 1 && addprocs(1)
            @eval @everywhere using QInsControl
            global SYNCSTATES = SharedVector{Bool}(8)
            global DATABUFRC = RemoteChannel(() -> databuf_c)
            global PROGRESSRC = RemoteChannel(() -> progress_c)
            remotecall_wait(workers()[1], SYNCSTATES) do syncstates
                initialize!()
                loadconf()
                global LOGIO = IOBuffer()
                global_logger(SimpleLogger(LOGIO))
                @async @trycatch mlstr("error in logging task") while true
                    update_log(syncstates)
                    sleep(1)
                end
            end
        end
        remotecall_wait(workers()[1]) do
            start!(CPU)
            @eval const SWEEPCTS = Dict{String,Dict{String,Tuple{Ref{Bool},Controller}}}()
            @eval const REFRESHCTS = Dict{String,Dict{String,Controller}}()
        end
        global AUTOREFRESHTASK = autorefresh()
        global UPDATEFRONTTASK = updatefronttask()
        @info "[$(now())]\n$(mlstr("successfully started!"))"
        if !isinteractive()
            wait(uitask)
            while SYNCSTATES[Int(IsDAQTaskRunning)]
                sleep(0.1)
            end
            sleep(0.1)
            exit()
        end
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        showbacktrace()
        return 1
    end
    return 0
end

function initialize!()
    empty!(DATABUF)
    empty!(DATABUFPARSED)
    empty!(PROGRESSLIST)
    empty!(STYLES)
    empty!(INSCONF)
    empty!(INSWCONF)
    empty!(INSTRBUFFERVIEWERS)
end

start() = (get!(ENV, "QInsControlAssets", joinpath(Base.@__DIR__, "../Assets")); julia_main())

@compile_workload begin
    get!(ENV, "QInsControlAssets", joinpath(Base.@__DIR__, "../Assets"))
    global SYNCSTATES = SharedVector{Bool}(8)
    loadconf(true)
    try
        window = UI()
        glfwHideWindow(window)
        sleep(6)
        glfwSetWindowShouldClose(window, true)
    catch
    end
end

end #QInsControl
