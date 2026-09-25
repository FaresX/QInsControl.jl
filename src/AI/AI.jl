# QInsControlAI——QInsControl 的 AI 能力后端子模块(强隔离:单文件夹,Bridge 白名单边界)。
# 前端视图在 src/Frontend/Windows/AIAssistant.jl(主模块命名空间,经 QInsControlAI. 限定名
# 调用后端);本模块不含任何 CImGui/UI 代码。
# 集成方式(全部触碰点见 ai/ai-integration/03-architecture.md §2):
#   src/QInsControl.jl:include + using + julia_main 中一行 initialize_ai!();
#   Windows/AIAssistant.jl:视图;MainWindow.jl:窗口开关/渲染调用/帧首 drain_ui!();
#   DAQ.jl:一行 taskroot() 访问器;Project.toml:HTTP/JSON 依赖。
# 删除 include 与调用两行 + 本文件夹与 AIAssistant.jl 即完全移除 AI 功能。

module QInsControlAI

import HTTP
import JSON
import Dates
import UUIDs
import TOML
import Configurations
using Dates: now

import Logging: @error, @info, @warn
import ..QInsControlCore: showbacktrace, mlstr, @async_record, @spawn_record, RECORDTASKS, RECORDTASKSLOCK
import ..QInsControl: OLDI

export initialize_ai!, drain_ui!, sendchat!, testconnection!

# 自包含的错误处理(AI 层任何异常不得炸渲染循环,同项目 @trypasse/@trycatch 策略)
function catchlog(f::Function, msg::AbstractString)
    try
        f()
    catch e
        @error "[$(now())]\n$msg" exception = e
        showbacktrace()
    end
end

include("Config.jl")          # AIProvider/OptAI + ai.toml 独立读写
include("Client/Client.jl")   # 纯 LLM 客户端(OpenAI 兼容 + Anthropic,零主模块依赖)
include("Bridge.jl")          # ★ 唯一对外引用边界:白名单 + ai_* 适配函数
include("Prompts.jl")         # 系统提示词(DSL 参考)
include("Context.jl")         # 实验上下文快照
include("Conversation.jl")    # 会话/流式状态 + markdown 存档
include("ScriptGen.jl")       # 脚本/绘图配置提取、校验、摘要
include("Tools.jl")           # Agent 工具注册表 + 聊天执行链路
# AIAssistant 窗口(前端视图)在 src/Frontend/Windows/AIAssistant.jl

initialize_ai!() = loadconf_ai!()

end # module QInsControlAI
