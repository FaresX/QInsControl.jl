using Distributed
nprocs() == 1 && addprocs(1)
@everywhere ENV["QInsControlAssets"] = "Assets"
@everywhere module QInsControl
# module QInsControl

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
import FileIO: load
using JLD2
using QInsControlCore
using Instruments
using Configurations
using ColorTypes
using OrderedCollections
# using ImageMagick
# using ImageIO
# using Logging

import Base: +, -, /
using Distributed
using SharedArrays
using TOML
using Dates
using UUIDs
using Printf
using InteractiveUtils
using Sockets

export julia_main

const instrlist = Dict{String,Vector{String}}() #仪器列表

@enum SyncStatesIndex begin 
    autodetecting = 1 #是否正在自动查询仪器
    autodetect_done 
    isdaqtask_running 
    isdaqtask_done 
    isinterrupt 
    isblock
    isautorefresh
end

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
include("UI/InstrBuffer.jl")
include("UI/InstrRegister.jl")
include("UI/DAQTask.jl")
include("UI/DAQ.jl")
include("UI/Logger.jl")
include("UI/HelpPad.jl")
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
        global syncstates = SharedVector{Bool}(7)
        global databuf_rc = RemoteChannel(() -> databuf_c)
        global progress_rc = RemoteChannel(() -> progress_c)
        uitask = UI()
        # include("Logger.jl")
        jlverinfobuf = IOBuffer()
        versioninfo(jlverinfobuf)
        global jlverinfo = wrapmultiline(String(take!(jlverinfobuf)), 48)
        if conf.Init.isremote
            nprocs() == 1 && addprocs(1)
            syncstates = SharedVector{Bool}(7)
            databuf_rc = RemoteChannel(() -> databuf_c)
            progress_rc = RemoteChannel(() -> progress_c)
            remote_do(loadconf, workers()[1])
            # remote_do(include, workers()[1], "Logger.jl")
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


end #QInsControl