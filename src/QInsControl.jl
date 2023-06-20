# using Distributed
# nprocs() == 1 && addprocs(1)
# @everywhere ENV["QInsControlAssets"] = "Assets"
# @everywhere module QInsControl
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
# using QInsControlCore
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
# export start

@enum SyncStatesIndex begin
    autodetecting = 1 #是否正在自动查询仪器
    autodetect_done 
    isdaqtask_running 
    isdaqtask_done 
    isinterrupt 
    isblock
    isautorefresh
    newloging
end

global savingimg::Bool = false
const CPU = Processor()
const databuf = Dict{String,Vector{String}}() #数据缓存
const progresslist = Dict{UUID,Tuple{UUID,Int,Int,Float64}}() #进度条缓存

global syncstates::SharedVector{Bool}
global instrbuffer_rc::RemoteChannel{Channel{Vector{NTuple{4,String}}}}
global databuf_rc::RemoteChannel{Channel{Vector{NTuple{2,String}}}}
global progress_rc::RemoteChannel{Channel{Vector{Tuple{UUID,Int,Int,Float64}}}}

include("Configurations.jl")
include("Instrument.jl")
include("Utilities.jl")
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
        databuf_c::Channel{Vector{Tuple{String,String}}} = Channel{Vector{NTuple{2,String}}}(conf.DAQ.channel_size)
        progress_c::Channel{Vector{Tuple{UUID,Int,Int,Float64}}} = Channel{Vector{Tuple{UUID,Int,Int,Float64}}}(conf.DAQ.channel_size)
        global syncstates = SharedVector{Bool}(8)
        global databuf_rc = RemoteChannel(() -> databuf_c)
        global progress_rc = RemoteChannel(() -> progress_c)
        global logio = IOBuffer()
        global_logger(SimpleLogger(logio))
        errormonitor(@async while true
            sleep(1)
            update_log()
        end)
        @info ARGS
        isempty(ARGS) || @info reencoding.(ARGS, conf.Basic.encoding)
        uitask = UI()
        jlverinfobuf = IOBuffer()
        versioninfo(jlverinfobuf)
        global jlverinfo = wrapmultiline(String(take!(jlverinfobuf)), 48)
        if conf.Basic.isremote
            nprocs() == 1 && addprocs(1)
            @eval @everywhere using QInsControl
            syncstates = SharedVector{Bool}(8)
            databuf_rc = RemoteChannel(() -> databuf_c)
            progress_rc = RemoteChannel(() -> progress_c)
            remotecall_wait(workers()[1], syncstates) do syncstates
                loadconf()
                global logio = IOBuffer()
                global_logger(SimpleLogger(logio))
                errormonitor(@async while true
                    sleep(1)
                    update_log(syncstates=syncstates)
                end)
            end
        end
        remotecall_wait(()->start!(CPU), workers()[1])
        autorefresh()
        @info "[$(now())]\n启动成功！"
        if !isinteractive()
            wait(uitask)
            while syncstates[Int(isdaqtask_running)]
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
