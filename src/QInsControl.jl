module QInsControl

using AbstractTrees
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
import .QInsControlCore: VISAInstrAttr, SerialInstrAttr, TCPSocketInstrAttr, VirtualInstrAttr, ISOBUSInstrAttr, QICInstrAttr
import .QInsControlCore: SYNCSTATES, SyncStatesIndex
import .QInsControlCore: timedwaitfetch, packtake!
for item in instances(SyncStatesIndex)
    eval(:(import .QInsControlCore: $(Symbol(item))))
end

include("GenericUtilities/GenericUtilities.jl")
include("Frontend/Frontend.jl")
include("AI/AI.jl")                 # AI 能力子模块(独立文件夹,触碰点见 ai/ai-integration 文档)
using .QInsControlAI
include("WebDashboard/WebDashboard.jl") # Web 仪表盘(只读伴生前端,独立任务,详见 ai/11-web-dashboard-plan.md)

function julia_main(; engine=nothing)::Cint
    try
        initialize_genericutilities!()
        initialize_frontend!()
        initialize_ai!()                # AI 子模块初始化(独立 ai.toml,失败不影响主程序)
        isnothing(engine) || (CONF.Basic.lowestframerate = 60)
        if CONF.Basic.isremote
            ENV["JULIA_NUM_THREADS"] = CONF.Basic.nthreads_2
            nprocs() == 1 && addprocs(1)
        end
        @eval @everywhere using QInsControl
        initialize_qinscontrolcore!(CONF.DAQ.channelsize)
        remotecall_wait(cs -> initialize_qinscontrolcore!(cs), workers()[1], CONF.DAQ.channelsize)
        startlogger(CONF.Logs.dir)
        loadinsconf()
        @info ARGS
        isempty(ARGS) || @info reencoding.(ARGS, CONF.Basic.encoding)
        uitask = UI(; engine)
        remote_startcpu!()
        remote_startrefresh(CONF.DAQ.ctbuflen)
        startrefresh()
        CONF.WebDashboard.enable && startwebdashboard!()
        @info "[$(now())]\n$(mlstr("successfully started!"))"
        wait(uitask)
        if !isinteractive()
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
        uitask = UI()
        sleep(6)
        window = CImGui.current_window()
        GLFW.HideWindow(window)
        sleep(6)
        GLFW.SetWindowShouldClose(window, true)
        wait(uitask)
        sleep(1)
    catch
    end
    # 工作负载期间启动的后台任务(监视/刷新等经 @async_record 登记进 RECORDTASKS、
    # 记入 CPU.tasks)若残留在包镜像可达的全局里,保存时抛 "Task cannot be
    # serialized" 使预编译崩溃;结束后清空这些运行时任务引用
    try
        empty!(RECORDTASKS)
        empty!(QInsControlCore.CPU.tasks)
        isassigned(QInsControlCore.LOGGERTASK) && (QInsControlCore.LOGGERTASK[] = Task(() -> nothing))
        isassigned(QInsControlCore.REFRESHTASK) && (QInsControlCore.REFRESHTASK[] = Task(() -> nothing))
    catch
    end
end

end #QInsControl
