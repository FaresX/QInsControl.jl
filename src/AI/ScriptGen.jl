# 脚本/绘图配置的提取、校验与摘要(供预览确认窗与 Agent 工具共用)

"提取回复中最长的 ```julia 围栏;无围栏时返回空串"
function extractcode(text::AbstractString)
    best = ""
    for m in eachmatch(r"```(?:julia)?\r?\n(.*?)```"s, text)
        cap = String(m.captures[1])
        length(cap) > length(best) && (best = cap)
    end
    return best
end

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

"修复轮的用户提示(校验失败时回喂模型)"
repairprompt(err::AbstractString) = string(
    "Your script failed to parse:\n", first(err, 600),
    "\nPlease output the corrected complete script as a single ```julia fenced block. ",
    "Remember: use only the aliases/quantities/units from the context, keep begin/end balanced, ",
    "and write boolean flags as true/false literals."
)
