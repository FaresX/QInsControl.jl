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
import ImageMagick
using JLD2
using JpegTurbo
using MacroTools
using NativeFileDialog
using OrderedCollections
using PrecompileTools
using StringEncodings
using Unitful

using Dates
using Distributed
using InteractiveUtils
using Printf
using Statistics
using TOML
using UUIDs

include("QInsControlCore/QInsControlCore.jl")
using .QInsControlCore
using .QInsControlCore.LibSerialPort
import .QInsControlCore: VISAInstrAttr, SerialInstrAttr, TCPSocketInstrAttr, VirtualInstrAttr
import .QInsControlCore: SYNCSTATES, SyncStatesIndex
for item in instances(SyncStatesIndex)
    eval(:(import .QInsControlCore: $(Symbol(item))))
end

include("GenericUtilities/GenericUtilites.jl")
include("Frontend/Frontend.jl")

function julia_main()::Cint
    try
        initialize_qinscontrolcore!()
        initialize_genericutilities!()
        initialize_frontend!()
        # loadconf()
        if CONF.Basic.isremote
            ENV["JULIA_NUM_THREADS"] = CONF.Basic.nthreads_2
            nprocs() == 1 && addprocs(1)
        end
        @eval @everywhere using QInsControl

        QInsControlCore.REFRESHINRC = RemoteChannel(() -> Channel{Tuple{String,String,String,Cfloat}}(CONF.DAQ.channelsize))
        QInsControlCore.REFRESHOUTRC = RemoteChannel(() -> Channel{Tuple{String,String,String,String}}(CONF.DAQ.channelsize))
        QInsControlCore.DATABUFRC = RemoteChannel(() -> Channel{Vector{NTuple{2,String}}}(CONF.DAQ.channelsize))
        QInsControlCore.EXTRADATABUFRC = RemoteChannel(() -> Channel{Tuple{String,Vector{Any}}}(CONF.DAQ.channelsize))
        QInsControlCore.PROGRESSRC = RemoteChannel(() -> Channel{Vector{Tuple{UUID,Int,Int,Float64}}}(CONF.DAQ.channelsize))
        QInsControlCore.SYNCSTATES = QInsControlCore.SharedVector{Bool}(length(instances(QInsControlCore.SyncStatesIndex)))

        startlogger(CONF.Logs.dir)

        loadinsconf()

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

start() = (get!(ENV, "QInsControlAssets", joinpath(@__DIR__, "../Assets")); julia_main())
stop() = GLFW.SetWindowShouldClose(CImGui.current_window(), true)

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
