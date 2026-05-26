module QInsControl

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using GLFW
using ModernGL
using CImGui.lib
using ColorTypes
using Configurations
import DefaultApplication
import FileIO
using GLMakie
using GitHub
# using MakieThemes
import ImageMagick
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
using Printf
using Statistics
using TOML
using UUIDs

using QInsControlCore
using QInsControlCore.LibSerialPort
import QInsControlCore: VISAInstrAttr, SerialInstrAttr, TCPSocketInstrAttr, VirtualInstrAttr
import QInsControlCore: SYNCSTATES, SyncStatesIndex
for item in instances(SyncStatesIndex)
    eval(:(import QInsControlCore: $(Symbol(item))))
end

@enum StatesIndex begin
    AutoDetecting = 1 #是否正在自动查询仪器
    AutoDetectDone
    AutoRefreshing
    NewVersion
    FatalError
    InValidFile
end
Base.getindex(x::AbstractVector{Bool}, i::StatesIndex) = x[Int(i)]
Base.setindex!(x::AbstractVector{Bool}, v::Bool, i::StatesIndex) = x[Int(i)] = v
const STATES = fill(false, length(instances(StatesIndex)))

# const CPU = Processor()
const DATABUF = Dict{String,Vector{String}}() #数据缓存
const DATABUFPARSED = Dict{String,VecOrMat{Cdouble}}()
const PROGRESSLIST = Base.Lockable(OrderedDict{UUID,Tuple{UUID,Int,Int,Float64}}()) #进度条缓存

global LOGIO = stdout

include("Utilities/Utilities.jl")
include("Utilities/LoopVector.jl")
include("Configurations.jl")
include("Utilities/StaticString.jl")
include("Utilities/FileInfo.jl")

include("UI/Extensions.jl")
include("UI/Block.jl")
include("UI/CustomWidgets/CustomWidgets.jl")
include("UI/DAQTask.jl")
include("UI/IconsFontAwesome6.jl")
include("UI/IconSelector.jl")
include("UI/CircuitEditor.jl")
include("UI/Instrument.jl")
include("UI/QPlot.jl")
include("UI/Progress.jl")
include("UI/DataPicker.jl")
include("UI/DataPlot.jl")
include("UI/InstrAlias.jl")

include("UI/DataViewer.jl")
include("UI/FileTree.jl")
include("UI/FileViewer.jl")
include("UI/OpenFileMonitor.jl")
include("UI/DataFormatter.jl")
include("UI/StyleEditor.jl")
include("UI/Preferences.jl")
include("UI/CPUMonitor.jl")
include("UI/InstrBuffer.jl")
include("UI/InstrumentMonitor.jl")
include("UI/ServerMonitor.jl")
include("UI/InstrRegister.jl")
include("UI/InstrWidget.jl")
include("UI/DAQ.jl")
include("UI/Console.jl")
include("UI/Logger.jl")
include("UI/ShowAbout.jl")
include("UI/Debugger.jl")
include("UI/MainWindow.jl")
include("UI/Renderer.jl")

include("Utilities/JLD2Struct.jl")
include("Utilities/ConfLoading.jl")
include("Conf.jl")

function julia_main()::Cint
    try
        initialize!()
        loadconf()
        if CONF.Basic.isremote
            ENV["JULIA_NUM_THREADS"] = CONF.Basic.nthreads_2
            nprocs() == 1 && addprocs(1)
        end
        @eval @everywhere using QInsControlCore
        
        startlogger(CONF.Logs.dir)

        QInsControlCore.REFRESHINRC = RemoteChannel(() -> Channel{Tuple{String,String,String,Cfloat}}(CONF.DAQ.channelsize))
        QInsControlCore.REFRESHOUTRC = RemoteChannel(() -> Channel{Tuple{String,String,String,String}}(CONF.DAQ.channelsize))
        QInsControlCore.DATABUFRC = RemoteChannel(() -> Channel{Vector{NTuple{2,String}}}(CONF.DAQ.channelsize))
        QInsControlCore.EXTRADATABUFRC = RemoteChannel(() -> Channel{Tuple{String,Vector{Any}}}(CONF.DAQ.channelsize))
        QInsControlCore.PROGRESSRC = RemoteChannel(() -> Channel{Vector{Tuple{UUID,Int,Int,Float64}}}(CONF.DAQ.channelsize))
        QInsControlCore.SYNCSTATES = QInsControlCore.SharedVector{Bool}(length(instances(QInsControlCore.SyncStatesIndex)))

        loadinsconf()

        jlverinfobuf = IOBuffer()
        versioninfo(jlverinfobuf)
        global JLVERINFO = wrapmultiline(String(take!(jlverinfobuf)), 48)
        @info ARGS
        isempty(ARGS) || @info reencoding.(ARGS, CONF.Basic.encoding)

        uitask = UI()
        
        remote_startcpu!()
        remote_startrefresh(CONF.DAQ.ctbuflen)
        startrefresh()
        @info "[$(now())]\n$(mlstr("successfully started!"))"
        if !isinteractive()
            wait(uitask)
            while SYNCSTATES[IsDAQTaskRunning]
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
    lock(empty!, PROGRESSLIST)
    empty!(STYLES)
    empty!(INSCONF)
    empty!(INSWCONF)
    empty!(INSTRBUFFERVIEWERS)
    empty!(IMAGES)
    empty!(FIGURES)
end

start() = (get!(ENV, "QInsControlAssets", joinpath(@__DIR__, "../Assets")); julia_main())

@compile_workload begin
    get!(ENV, "QInsControlAssets", joinpath(@__DIR__, "../Assets"))
    loadconf(true)
    try
        UI()
        sleep(6)
        window = CImGui.current_window()
        GLFW.HideWindow(window)
        sleep(6)
        GLFW.SetWindowShouldClose(window, true)
        sleep(1)
    catch
    end
end

end #QInsControl
