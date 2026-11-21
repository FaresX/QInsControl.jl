# 会话数据结构与全局聊天状态(流式缓冲/工具步骤)+ markdown 存档

const TOOLKEEPFULL = 6   #发给模型的工具结果中,最近 N 条保留全文,更早的按 TOOLCLIPLEN 截断
const TOOLCLIPLEN = 200  #旧工具结果的保留长度(字符)
const CONTEXTMULT = Ref(1.0)  #上下文超限自愈:maxhistory 的临时折减系数,命中后减半重试

mutable struct Conversation
    id::UUIDs.UUID
    title::String
    messages::Vector{ChatMessage}
    provider::String
end
Conversation() = Conversation(UUIDs.uuid4(), mlstr("New Conversation"), ChatMessage[], "")

"全局聊天状态:窗口(UI 线程)与请求任务(AI 线程)共享,写经 CHATLOCK,读为展示用尽力而为"
mutable struct ChatState
    conversations::Vector{Conversation}
    current::Int
    busy::Bool
    stop::Bool
    inflight::String                                # 流式中的 assistant 文本
    reasoning::String                               # 流式中的思维链
    toolsteps::Vector{Tuple{String,String,String}}  # (name, arguments, result)
    newtoken::Bool                                  # 有新增量(驱动重绘/滚底)
end
const CHAT = ChatState([Conversation()], 1, false, false, "", "", Tuple{String,String,String}[], true)
const CHATLOCK = ReentrantLock()

currentconv() = CHAT.conversations[clamp(CHAT.current, 1, length(CHAT.conversations))]

function pushmessage!(conv::Conversation, m::ChatMessage)
    #写入必须持 CHATLOCK(ChatState 注释的设计约束):AI 任务线程 push! 与 UI 线程渲染迭代并发
    lock(CHATLOCK) do
        push!(conv.messages, m)
        if m.role == "user" && length(filter(c -> c.role == "user", conv.messages)) == 1
            t = strip(split(m.content, '\n')[1])
            conv.title = length(t) > 40 ? first(t, 40) * "…" : (isempty(t) ? conv.title : t)
        end
    end
    return
end

function newconversation!()
    push!(CHAT.conversations, Conversation())
    CHAT.current = length(CHAT.conversations)
    CHAT.inflight = ""
    CHAT.reasoning = ""
    empty!(CHAT.toolsteps)
    CONTEXTMULT[] = 1.0   #新会话重置上下文折减
    CHAT.newtoken = true
    return
end

function deleteconversation!(i::Int)
    length(CHAT.conversations) > 1 || (CHAT.conversations[1] = Conversation(); CHAT.current = 1; return)
    deleteat!(CHAT.conversations, clamp(i, 1, length(CHAT.conversations)))
    CHAT.current = clamp(CHAT.current, 1, length(CHAT.conversations))
    return
end

"组装发给 API 的消息:system(提示词+快照) + 按轮数上限裁剪、对齐到 user 边界的历史。
较早的工具结果全文截断,控制上下文膨胀(最近 TOOLKEEPFULL 条保留原文)"
function buildmessages(conv::Conversation; agent::Bool=false)
    sys = systemprompt(agent)
    aiconf().injectcontext && (sys *= "\n\n" * snapshot())
    msgs = ChatMessage[ChatMessage("system", sys)]
    hist = conv.messages
    isempty(hist) && return msgs
    maxn = max(2, round(Int, aiconf().maxhistory * CONTEXTMULT[]))
    start = max(1, length(hist) - maxn + 1)
    if start > 1
        #窗口起点必须落在 user 边界(否则 tool 消息失去前导配对,严格校验的供应商直接 400);
        #尾窗里找不到 user 时回退到最后一条 user 消息——agent 工具链超窗时若整段丢弃,
        #请求会只剩 system,模型中途失忆,Anthropic 更会因空 messages 数组报错
        i = findnext(m -> m.role == "user", hist, start)
        start = i === nothing ? findlast(m -> m.role == "user", hist) : i
        start === nothing && (start = 1)
    end
    for i in start:length(hist)
        m = hist[i]
        if m.role == "tool" && i <= length(hist) - TOOLKEEPFULL && length(m.content) > TOOLCLIPLEN
            push!(msgs, ChatMessage("tool", first(m.content, TOOLCLIPLEN) * "…[clipped]"; toolcallid=m.toolcallid))
        else
            push!(msgs, m)
        end
    end
    return msgs
end

"会话存档:JSON(可载回 UI,含 toolcalls/reasoning)+ markdown(人可读导出)双写"
function savearchive(conv::Conversation)
    isempty(conv.messages) && return
    catchlog("failed to save conversation archive") do
        date = Dates.today()
        mdir = joinpath(aiconf().dir, string(Dates.year(date)), string(Dates.year(date), "-", Dates.month(date)))
        isdir(mdir) || mkpath(mdir)
        #JSON 存档(启动时载回 History)
        jpath = joinpath(mdir, "conv_$(conv.id).json")
        obj = Dict{String,Any}(
            "id" => string(conv.id),
            "title" => conv.title,
            "provider" => conv.provider,
            "messages" => Any[Dict{String,Any}(
                "role" => m.role,
                "content" => m.content,
                "reasoning" => m.reasoning,
                "toolcallid" => m.toolcallid,
                "toolcalls" => m.toolcalls,
            ) for m in conv.messages if m.role != "system"],
        )
        open(jpath, "w") do io
            print(io, JSON.json(obj))
        end
        #markdown 存档(人可读,可作实验记录附件)
        path = joinpath(mdir, "conv_$(conv.id).md")
        open(path, "w") do io
            println(io, "# ", conv.title)
            println(io, "- saved: ", Dates.now())
            println(io, "- provider: ", conv.provider)
            for m in conv.messages
                m.role == "system" && continue
                println(io, "\n## ", uppercase(m.role), "\n")
                println(io, m.content)
                for tc in m.toolcalls
                    println(io, "\n> tool call: `", tc["name"], "` arguments: `", tc["arguments"], "`")
                end
            end
        end
    end
    return
end

"启动载入:扫 <dir>/<年>/<年-月>/conv_*.json,按目录倒序取最近 n 份回填 History"
function loadarchives!(n::Int = 20)
    root = aiconf().dir
    isdir(root) || return
    files = String[]
    for y in sort!(readdir(root); rev = true)
        yd = joinpath(root, y)
        isdir(yd) || continue
        for m in sort!(readdir(yd); rev = true)
            md = joinpath(yd, m)
            isdir(md) || continue
            for f in readdir(md)
                startswith(f, "conv_") && endswith(f, ".json") && push!(files, joinpath(md, f))
            end
        end
        length(files) >= n && break
    end
    isempty(files) && return
    convs = Conversation[]
    for f in first(files, n)
        catchlog("failed to load conversation archive $f") do
            obj = normalizejson(JSON.parse(read(f, String)))
            obj isa AbstractDict || return
            id = tryparse(UUIDs.UUID, String(get(obj, "id", "")))
            conv = Conversation(id === nothing ? UUIDs.uuid4() : id,
                String(get(obj, "title", "...")), ChatMessage[], String(get(obj, "provider", "")))
            for m in get(obj, "messages", Any[])
                m isa AbstractDict || continue
                push!(conv.messages, ChatMessage(
                    String(get(m, "role", "user")),
                    String(get(m, "content", ""));
                    toolcalls = get(m, "toolcalls", Any[]),
                    toolcallid = String(get(m, "toolcallid", "")),
                    reasoning = String(get(m, "reasoning", "")),
                ))
            end
            isempty(conv.messages) || push!(convs, conv)
        end
    end
    isempty(convs) || (CHAT.conversations = convs; CHAT.current = 1; CHAT.newtoken = true)
    return
end
