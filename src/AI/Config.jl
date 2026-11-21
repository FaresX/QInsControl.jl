# AI 供应商与行为配置——独立于主程序 CONF,存于 <Assets>/Necessity/ai.toml
# (强隔离约束:不改主程序 Configurations.jl / Preferences.jl,设置 UI 在 AIAssistant 窗口内)

Configurations.@option mutable struct AIProvider
    name::String = "OpenAI"
    apitype::String = "openai"      # "openai"(兼容协议) | "anthropic"
    baseurl::String = "https://api.openai.com/v1"
    model::String = "gpt-4o"
    models::Vector{String} = String[]   # 可选模型列表(聊天页下拉切换;Settings 逗号分隔编辑或从 /models 拉取)
    apikey::String = ""             # 明文,或 "env:VARNAME"/"dpapi:<b64>" 间接引用(推荐,避免落盘)
    temperature::Float64 = 0.7
    stream::Bool = true
    think::String = ""              # 思考挡位: ""=不发送(供应商默认) | off | low | medium | high
    extra::String = ""              # 供应商特有参数:JSON 对象,合并进请求 body 顶层(键覆盖默认)
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
    maxtoolturns::Cint = 36              # Agent 工具循环轮数上限(完整仪器构建流程 10+ 次调用,8 轮不够)
    timeout::Cint = 180                  # HTTP readtimeout(秒)
    confirmwrites::Bool = true          # 写仪器/改工程前弹确认
    allowweb::Bool = true               # 允许 AI 联网搜索手册/抓取文档页(写驱动时查 SCPI)
    encryptkeys::Bool = true            # ai.toml 落盘时对明文 apikey 做 DPAPI 加密(Windows)
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
        conf = aiconf()
        if conf.encryptkeys
            #落盘加密:非 env:/dpapi: 的明文密钥在文件里替换为 dpapi:<b64>(内存保持原值,UI 与解析不受影响;
            #只绑定本机当前用户,Assets 目录随 OneDrive/拷贝外流也不可用)
            conf = deepcopy(conf)
            for p in conf.providers
                (isempty(p.apikey) || startswith(p.apikey, "env:") || startswith(p.apikey, "dpapi:")) && continue
                b64 = dpapi_encrypt(p.apikey)
                if b64 === nothing
                    @warn "[$(now())]\nDPAPI unavailable on this platform - apikey stored in PLAINTEXT in ai.toml" provider = p.name
                else
                    p.apikey = "dpapi:" * b64
                end
            end
        end
        open(aiconfpath(), "w") do io
            print(io, Configurations.to_toml(conf))
        end
    end
    return
end

# —— 密钥间接引用:"env:VARNAME" 读环境变量,"dpapi:<b64>" Windows DPAPI 解密 ——

struct _DATABLOB
    cbData::Culong
    pbData::Ptr{Cuchar}
end

"DPAPI 输出块 → Julia 字节向量:拷贝后 LocalFree(Crypt*Data 用 LocalAlloc 分配,
不能用 own=true 让 Julia 的分配器接管——谁分配谁释放)"
function _blobbytes(blob::_DATABLOB)
    n = Int(blob.cbData)
    out = Vector{UInt8}(undef, n)
    wrap = unsafe_wrap(Array, blob.pbData, n)
    copyto!(out, wrap)
    ccall((:LocalFree, "kernel32"), Ptr{Cvoid}, (Ptr{Cvoid},), blob.pbData)
    return out
end

"Windows DPAPI(CryptProtectData):本机当前用户可解;非 Windows 或失败返回 nothing(调用方回退明文+警告)"
function dpapi_encrypt(plain::String)
    Sys.iswindows() || return nothing
    inb = transcode(UInt8, plain)
    pin = GC.@preserve inb _DATABLOB(Culong(length(inb)), pointer(inb))
    pout = Ref(_DATABLOB(0, C_NULL))
    ok = ccall((:CryptProtectData, "crypt32"), Cint,
        (Ref{_DATABLOB}, Ptr{Cvoid}, Ptr{_DATABLOB}, Ptr{Cvoid}, Ptr{Cvoid}, Culong, Ref{_DATABLOB}),
        pin, C_NULL, C_NULL, C_NULL, C_NULL, 0, pout)
    ok == 0 && return nothing
    return Base64.base64encode(_blobbytes(pout[]))
end

"DPAPI 解密:跨机器/跨用户/损坏的 dpapi: 值一律返回空串(模型看到密钥缺失而非报错炸穿)"
function dpapi_decrypt(b64::String)
    Sys.iswindows() || return ""
    inb = try
        Base64.base64decode(b64)
    catch
        return ""
    end
    pin = GC.@preserve inb _DATABLOB(Culong(length(inb)), pointer(inb))
    pout = Ref(_DATABLOB(0, C_NULL))
    ok = ccall((:CryptUnprotectData, "crypt32"), Cint,
        (Ref{_DATABLOB}, Ptr{Ptr{UInt16}}, Ptr{_DATABLOB}, Ptr{Cvoid}, Ptr{Cvoid}, Culong, Ref{_DATABLOB}),
        pin, C_NULL, C_NULL, C_NULL, C_NULL, 0, pout)
    ok == 0 && return ""
    return transcode(String, _blobbytes(pout[]))
end

function resolvekey(p::AIProvider)
    k = p.apikey
    startswith(k, "env:") && (k = get(ENV, String(k[5:end]), ""))
    startswith(k, "dpapi:") && (k = dpapi_decrypt(String(k[7:end])))
    return String(k)
end

function getprovider(name::AbstractString=aiconf().default)
    ps = aiconf().providers
    i = findfirst(p -> p.name == String(name), ps)
    return i === nothing ? (isempty(ps) ? nothing : ps[1]) : ps[i]
end
