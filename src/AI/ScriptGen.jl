# 脚本/绘图配置的提取、校验与摘要(供预览确认窗与 Agent 工具共用)

"提取 ```json 围栏(绘图配置);失败时尝试裸 {...}"
function extractplotcfg(text::AbstractString)
    raw = ""
    for m in eachmatch(r"```(?:json)?\r?\n(.*?)```"s, text)
        occursin('"', m.captures[1]) && (raw = String(m.captures[1]); break)
    end
    if raw == ""
        i = findfirst('{', text)
        i === nothing && return nothing
        raw = text[i:end]
    end
    cfg = try
        JSON.parse(raw)
    catch
        return nothing
    end
    return cfg isa AbstractDict ? cfg : nothing
end

"提取 ```tool 围栏的文本回退工具调用(弱模型无原生 function calling 时)"
function extracttoolcall(text::AbstractString)
    m = match(r"```tool\r?\n(.*?)```"s, text)
    m === nothing && return nothing
    obj = try
        JSON.parse(String(m.captures[1]))
    catch
        return nothing
    end
    (obj isa AbstractDict && haskey(obj, "tool")) || return nothing
    return obj
end

"JSON 1.7 的 JSON.parse 返回只读 JSON.Object(非 Dict);工具链与 applyplotcfg 全按可变 Dict
约定(要 setproperty!/push!),这里递归归一化——正是历史上 calltool 误杀所有调用的那类回归"
function normalizejson(x)
    x isa AbstractDict && return Dict{String,Any}(String(k) => normalizejson(v) for (k, v) in x)
    x isa AbstractVector && return Any[normalizejson(v) for v in x]
    return x
end
