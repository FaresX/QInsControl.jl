# 会话数据结构与全局聊天状态(流式缓冲/工具步骤)+ markdown 存档

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
    CHAT.newtoken = true
    return
end

function deleteconversation!(i::Int)
    length(CHAT.conversations) > 1 || (CHAT.conversations[1] = Conversation(); CHAT.current = 1; return)
    deleteat!(CHAT.conversations, clamp(i, 1, length(CHAT.conversations)))
    CHAT.current = clamp(CHAT.current, 1, length(CHAT.conversations))
    return
end

"组装发给 API 的消息:system(提示词+快照) + 按轮数上限裁剪、对齐到 user 边界的历史"
function buildmessages(conv::Conversation; agent::Bool=false)
    sys = systemprompt(agent)
    aiconf().injectcontext && (sys *= "\n\n" * snapshot())
    msgs = ChatMessage[ChatMessage("system", sys)]
    hist = conv.messages
    isempty(hist) && return msgs
    maxn = max(2, aiconf().maxhistory)
    start = max(1, length(hist) - maxn + 1)
    if start > 1
        i = findnext(m -> m.role == "user", hist, start)
        start = i === nothing ? length(hist) + 1 : i
    end
    append!(msgs, view(hist, start:length(hist)))
    return msgs
end

"会话存档:markdown 落盘(人可读,可作实验记录附件)"
function savearchive(conv::Conversation)
    isempty(conv.messages) && return
    catchlog("failed to save conversation archive") do
        date = Dates.today()
        mdir = joinpath(aiconf().dir, string(Dates.year(date)), string(Dates.year(date), "-", Dates.month(date)))
        isdir(mdir) || mkpath(mdir)
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
