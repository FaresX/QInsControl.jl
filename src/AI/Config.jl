# AI 供应商与行为配置——独立于主程序 CONF,存于 <Assets>/Necessity/ai.toml
# (强隔离约束:不改主程序 Configurations.jl / Preferences.jl,设置 UI 在 AIAssistant 窗口内)

Configurations.@option mutable struct AIProvider
    name::String = "OpenAI"
    apitype::String = "openai"      # "openai"(兼容协议) | "anthropic"
    baseurl::String = "https://api.openai.com/v1"
    model::String = "gpt-4o"
    apikey::String = ""             # 明文,或 "env:VARNAME" 间接引用(推荐,避免落盘)
    temperature::Float64 = 0.7
    stream::Bool = true
end

function aipresets()
    AIProvider[
        AIProvider(name="DeepSeek", baseurl="https://api.deepseek.com/v1", model="deepseek-chat", apikey="env:DEEPSEEK_API_KEY"),
        AIProvider(name="Kimi", baseurl="https://api.moonshot.cn/v1", model="kimi-k2-0711-preview", apikey="env:MOONSHOT_API_KEY"),
        AIProvider(name="GLM", baseurl="https://open.bigmodel.cn/api/paas/v4", model="glm-4.5-air", apikey="env:ZHIPU_API_KEY"),
        AIProvider(name="Qwen", baseurl="https://dashscope.aliyuncs.com/compatible-mode/v1", model="qwen-plus", apikey="env:DASHSCOPE_API_KEY"),
        AIProvider(name="OpenAI", baseurl="https://api.openai.com/v1", model="gpt-4o", apikey="env:OPENAI_API_KEY"),
        AIProvider(name="Ollama(local)", baseurl="http://localhost:11434/v1", model="qwen3:8b", apikey=""),
    ]
end

Configurations.@option mutable struct OptAI
    enable::Bool = true
    default::String = "DeepSeek"        # 当前供应商名(窗口内可切换)
    injectcontext::Bool = true          # 每轮注入实验上下文快照
    withhelp::Bool = true               # 快照是否包含仪器量 help 字段
    maxhistory::Cint = 24                # 发送给模型的最大历史消息数(不含 system)
    maxtoolturns::Cint = 8               # Agent 工具循环轮数上限
    timeout::Cint = 180                  # HTTP readtimeout(秒)
    confirmwrites::Bool = true          # 写仪器/改工程前弹确认
    allowsrun::Bool = false             # 允许 AI 触发任务运行(默认焊死为 false)
    allowweb::Bool = true               # 允许 AI 联网搜索手册/抓取文档页(写驱动时查 SCPI)
    maxdatasample::Cint = 200            # 数据问答采样上限(点/行)
    dir::String = ""                    # 会话存档目录(空 = <Assets>/AI/Sessions)
    providers::Vector{AIProvider} = aipresets()
end

const AICONF = Ref{OptAI}(OptAI())
aiconf() = AICONF[]

assetsdir() =
    haskey(ENV, "QInsControlAssets") ? ENV["QInsControlAssets"] :
    normpath(joinpath(@__DIR__, "..", "..", "Assets"))
aiconfpath() = joinpath(assetsdir(), "Necessity", "ai.toml")

function loadconf_ai!()
    path = aiconfpath()
    conf = OptAI()
    if isfile(path)
        try
            conf = Configurations.from_toml(OptAI, path)
        catch e
            @error "[$(now())]\nfailed to load ai.toml, fallback to defaults" path exception = e
        end
    end
    isempty(conf.providers) && (conf.providers = aipresets())
    isempty(conf.dir) && (conf.dir = joinpath(assetsdir(), "AI", "Sessions"))
    isdir(conf.dir) || mkpath(conf.dir)
    haskey(ENV, "QInsControlAssets") || (ENV["QInsControlAssets"] = assetsdir())
    AICONF[] = conf
    saveconf_ai()   # 回写完整字段,方便用户在文件里看到全部可配置项
    return conf
end

function saveconf_ai()
    catchlog("failed to save ai.toml") do
        open(aiconfpath(), "w") do io
            print(io, Configurations.to_toml(aiconf()))
        end
    end
    return
end

# "env:VARNAME" 间接引用:运行时读环境变量,密钥不明文落盘
function resolvekey(p::AIProvider)
    k = p.apikey
    startswith(k, "env:") && (k = get(ENV, String(k[5:end]), ""))
    return String(k)
end

function getprovider(name::AbstractString=aiconf().default)
    ps = aiconf().providers
    i = findfirst(p -> p.name == String(name), ps)
    return i === nothing ? (isempty(ps) ? nothing : ps[1]) : ps[i]
end
