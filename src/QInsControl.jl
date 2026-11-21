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
using JSON
using MacroTools
using NativeFileDialog
using OrderedCollections
using PrecompileTools
using StringEncodings
using Unitful

using Dates
using Distributed
using Downloads
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
include("Updater/Updater.jl")       # 应用内更新(检查/下载补丁链;安装由退出后的启动器链完成)
include("Frontend/Frontend.jl")
include("AI/AI.jl")                 # AI 能力子模块(独立文件夹,触碰点见 ai/ai-integration 文档)
using .QInsControlAI
include("WebDashboard/WebDashboard.jl") # Web 仪表盘(只读伴生前端,独立任务,详见 ai/11-web-dashboard-plan.md)

#doexit=false 供测试套件调用:不 exit 进程,让 Test 的汇总与退出码正常产生(runtests.jl)
function julia_main(; engine=nothing, doexit=true)::Cint
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
        isfile(CONF.Communication.visapath) && QInsControlCore.remote_set_libvisa(CONF.Communication.visapath)
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
            doexit && exit()
        end
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        showbacktrace()
        return 1
    end
    return 0
end

start() = (get!(ENV, "QInsControlAssets", joinpath(@__DIR__, "../QInsControlAssets")); julia_main())
stop() = GLFW.SetWindowShouldClose(CImGui.current_window(), true)

@compile_workload begin
    get!(ENV, "QInsControlAssets", joinpath(@__DIR__, "../QInsControlAssets"))
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
    # 注:绘图引擎预热实验已撤销 —— 无论预编译 worker 还是运行时,创建第二个 GL
    # 上下文都会在本机 AMD 驱动(atio6axx.dll)上 ACCESS_VIOLATION 硬崩溃;
    # 绘图首用编译成本保留在首次打开绘图窗口时发生。
    # 后台线程预热则违反 GLFW 主线程专属约束(上下文占住死线程 → 运行时 WGL BUSY)。
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

#Ctrl+C 等中断可能落在非主线程的任务收尾钩子(task_done_hook)上,Julia 兜底退出会在那个线程
#跑 atexit:GLFW.jl 自带的 Terminate 钩子有主线程断言,会抛 ThreadAssertionError 把进程打成
#fatal("no exception handler available")。本钩子注册晚于 GLFW 的(LIFO 先执行),仅在这种
#异常退出路径放开断言,把收尾降级为尽力而为;正常退出(主线程)不受影响。
#必须放 __init__ 而非模块顶层:顶层语句只在预编译构建进程执行,缓存加载不重放,用户会话里
#根本不会注册
function __init__()
    atexit() do
        Threads.threadid() == 1 && return
        isdefined(GLFW, :ENABLE_THREAD_ASSERTIONS) && (GLFW.ENABLE_THREAD_ASSERTIONS[] = false)
    end
end

end #QInsControl
