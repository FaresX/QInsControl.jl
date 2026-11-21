# AIAssistant 窗口(AI 的前端视图层,归属 Frontend/Windows,与其它窗口同级)——
# AI 的全部交互(聊天/历史/设置/脚本预览确认/工具确认)都在本窗口。
# 后端(LLM 客户端/工具/会话/配置)在 src/AI/ 的 QInsControlAI 模块,经限定名调用;
# 本文件不做任何 AI 逻辑,只做 UI 绑定。
# 消息正文默认 PushTextWrapPos 自动换行显示;双击切换只读多行框拖选复制(InputTextMultiline
# 不支持自动换行,不能常驻);头部有整段 Copy 按钮。不要用 SameLine 拼内联样式——
# 长行换行后 SameLine 会把片段推到屏侧形成双列错位与大片空白,已踩坑。
# 助手消息正文经 markdownview 渲染(CustomWidgets/Markdown.jl),代码围栏由本文件拆出以挂
# To Task/To Plot 按钮;用户消息保持纯文本 messagetext(可拖选复制)。

const aicodefence = r"```([a-z]*)[ \t]*\r?\n(.*?)```"s


let
    inputbuf::String = ""
    inputhistory::LoopVector{String} = LoopVector([""])
    historymax::Int = 0
    scrollbottom::Bool = true
    provname::Ref{String} = Ref("")
    provthink::Ref{String} = Ref("default")   #聊天页思考强度快捷切换的显示值(default/off/low/medium/high)
    provmodel::Ref{String} = Ref("")          #聊天页模型下拉的显示值
    modelsbuf::Ref{String} = Ref("")          #Settings 模型列表的逗号分隔编辑缓冲
    modelsbufidx::Ref{Int} = Ref(0)           #缓冲对应的 provider 索引(0=未加载)
    fetchstat::Ref{String} = Ref("")          #模型列表拉取状态
    provseli::Ref{Cint} = Ref(Cint(1))   #Settings 页选中 provider 的 1 基索引(按索引而非名字,改名不错乱)
    agentmode::Ref{Bool} = Ref(false)
    pendingimgs::Vector{NTuple{3,String}} = Vector{NTuple{3,String}}()   #待发图片(mime, b64, name)
    teststatus::Ref{String} = Ref("")
    testbusy::Ref{Bool} = Ref(false)
    wantpreview::Bool = false
    scriptmodal = nothing                 # NamedTuple(mode, script, ok, blocks, err, cfg, target::Ref{Int}, namebuf::Ref{String})
    activeconfirm = nothing               # ConfirmRequest
    textviewmode::Dict{String,Bool} = Dict()  # 消息文本的选择模式状态(双击切换,CopyableText 同款交互)

    """
        messagetext(label, text)

    默认按窗口宽度自动换行显示;双击该段切换为只读多行输入框(可拖选/Ctrl+C,失焦退出;
    InputTextMultiline 本身不支持自动换行,故不作常驻显示)。每条消息头部另有整段 Copy 按钮。
    """
    function messagetext(label, text::AbstractString)
        isempty(text) && return
        if get!(textviewmode, label, false)
            availw = CImGui.GetContentRegionAvail().x
            pad = 2unsafe_load(IMGUISTYLE.FramePadding.x)
            n = wraplines(text, availw - pad)
            h = n * unsafe_load(IMGUISTYLE.FontSizeBase) + 2unsafe_load(IMGUISTYLE.FramePadding.y)
            CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, (0f0, 0f0, 0f0, 0f0))
            CImGui.InputTextMultiline(
                label, String(text), sizeof(text), (Cfloat(availw), Cfloat(h)),
                CImGui.ImGuiInputTextFlags_ReadOnly
            )
            CImGui.PopStyleColor()
            CImGui.IsItemDeactivated() && (textviewmode[label] = false)
        else
            CImGui.PushTextWrapPos(0)
            CImGui.TextUnformatted(text)
            CImGui.PopTextWrapPos()
            CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (textviewmode[label] = true)
        end
        return
    end

    "消息头部的小复制按钮(调用处用 PushID 消歧)"
    function copybtn(text::AbstractString)
        CImGui.SmallButton(MORESTYLE.Icons.Copy) && CImGui.SetClipboardText(text)
        ItemTooltip(mlstr("Copy"))
        return
    end

    function rendercode(code::AbstractString, id, isjson::Bool)
        #代码框着色/高度自适应由 codeblockview 负责;复制与按钮动作在本地做去尾换行
        body = replace(rstrip(code, ['\n', '\r']), "\r\n" => "\n")
        codeblockview(stcstr("##code", id), code; lang=isjson ? "json" : "julia")
        CImGui.PushID(id)
        CImGui.SmallButton(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy"))) && CImGui.SetClipboardText(body)
        if isjson
            CImGui.SameLine()
            CImGui.SmallButton(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("To Plot"))) && wantplot(String(code))
        else
            CImGui.SameLine()
            CImGui.SmallButton(stcstr(MORESTYLE.Icons.TaskButton, " ", mlstr("To Task"))) && wanttask(String(code))
        end
        CImGui.PopID()
        CImGui.Dummy((Cfloat(0), unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2))
    end

    function renderassistant(content::AbstractString, reasoning::AbstractString, uid)
        isempty(reasoning) || CImGui.TextDisabled(stcstr("· reasoning (", length(reasoning), " chars) ·"))
        codeid = 0
        # findall 返回合法字符索引区间;不要用 m.offset + length(m.match) 手工推算——
        # 含多字节(中文)内容时会算进匹配区内部,导致代码尾部作为正文重复渲染(已踩坑)
        pos = firstindex(content)
        for r in findall(aicodefence, content)
            r.start > pos &&
                markdownview(stcstr("##aimd", uid, "-", pos), content[pos:prevind(content, r.start)])
            codeid += 1
            cm = match(aicodefence, content[r])
            rendercode(String(cm.captures[2]), stcstr(uid, "-c", codeid), String(cm.captures[1]) == "json")
            pos = last(r) < lastindex(content) ? nextind(content, last(r)) : lastindex(content) + 1
        end
        pos <= lastindex(content) && markdownview(stcstr("##aimd", uid, "-", pos), content[pos:end])
        return
    end

    # —— 代码块按钮动作:校验并打开预览确认模态 ——
    function wanttask(code::AbstractString)
        ok, blocks, err = QInsControlAI.ai_validate_script(code)
        scriptmodal = (
            mode=:task, script=String(code), ok=ok, blocks=blocks, err=err, warn="", cfg=nothing,
            target=Ref(0), namebuf=Ref("AI Task")
        )
        wantpreview = true
    end

    function wantplot(code::AbstractString)
        cfg = QInsControlAI.extractplotcfg(code)
        if cfg === nothing
            scriptmodal = (mode=:plot, script=String(code), ok=false, blocks=nothing,
                err="no valid JSON plot configuration found", warn="", cfg=nothing,
                target=Ref(0), namebuf=Ref("AI Plot"))
        else
            err, warn = QInsControlAI.ai_validate_plotcfg(cfg)
            scriptmodal = (mode=:plot, script=String(code), ok=err == "", blocks=nothing,
                err=err, warn=warn, cfg=cfg, target=Ref(0), namebuf=Ref("AI Plot"))
        end
        wantpreview = true
    end

    global function ShowAIAssistant(p_open::Ref{Bool})
        QInsControlAI.CHAT.busy && dorender()   # 流式期间申请渲染帧(帧率泵,同 Dashboard 动画)
        lock(QInsControlAI.CHATLOCK) do
            QInsControlAI.CHAT.newtoken && (scrollbottom = true; QInsControlAI.CHAT.newtoken = false)
        end
        CImGui.SetNextWindowSize((760, 680) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Once)
        nm = stcstr(MORESTYLE.Icons.AIAssistant, " ", mlstr("AI Assistant"), "###AIAssistant")
        begun, own, popenarg = BeginNoClose(nm, p_open)
        if begun
            if CImGui.BeginTabBar("##aitabs")
                if CImGui.BeginTabItem(stcstr(ICONS.ICON_COMMENTS, " ", mlstr("Chat")))
                    rendertabchat()
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem(stcstr(MORESTYLE.Icons.File, " ", mlstr("History")))
                    rendertabhistory()
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem(stcstr(MORESTYLE.Icons.Preferences, " ", mlstr("Settings")))
                    rendertabsettings()
                    CImGui.EndTabItem()
                end
                CImGui.EndTabBar()
            end
            # —— 模态:脚本/绘图预览确认(工具确认模态在 RenderAIConfirm,由 MainWindow 每帧驱动) ——
            scriptmodal !== nothing && renderscriptmodal()
        end
        EndNoClose(own, p_open, popenarg)
        return
    end

    """
        RenderAIConfirm()

    工具写操作确认模态。必须由 MainWindow 每帧无条件调用,不能只在 ShowAIAssistant 内渲染:
    AI 窗口关闭时(含 WebDashboard 驱动的会话)确认队列会无人消费,每次写操作阻塞 120s,
    32 条后 put! 永久挂起、CHAT.busy 永不复位。模态与 AI 窗口可见性无关(ImGui 弹窗是全屏居中覆盖层)。
    """
    global function RenderAIConfirm()
        if activeconfirm === nothing
            req = QInsControlAI.takedisplaysreq()
            req === nothing || (activeconfirm = req; CImGui.OpenPopup("##aiconfirm"))
        end
        if activeconfirm !== nothing
            CImGui.SetNextWindowSize((560, 0) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Appearing)
            if CImGui.BeginPopupModal("##aiconfirm", C_NULL, CImGui.ImGuiWindowFlags_NoSavedSettings)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.WarnText)
                CImGui.TextUnformatted(activeconfirm.title)
                CImGui.PopStyleColor()
                CImGui.Separator()
                CImGui.PushTextWrapPos(0)
                CImGui.TextUnformatted(activeconfirm.detail)
                CImGui.PopTextWrapPos()
                ftsz = CImGui.GetFontSize()
                if CImGui.Button(mlstr("Confirm"), (4ftsz, Cfloat(0)))
                    activeconfirm.answer[] = true
                    activeconfirm = nothing
                    CImGui.CloseCurrentPopup()
                end
                CImGui.SameLine()
                if CImGui.Button(mlstr("Cancel"), (4ftsz, Cfloat(0)))
                    activeconfirm.answer[] = false
                    activeconfirm = nothing
                    CImGui.CloseCurrentPopup()
                end
                CImGui.EndPopup()
            elseif !CImGui.IsPopupOpen("##aiconfirm")
                activeconfirm = nothing   # 被其他方式关闭;不置 answer → 120s 超时按拒绝兜底
            end
        end
        return
    end

    # ============ Chat 页 ============
    function rendertabchat()
        conv = QInsControlAI.currentconv()
        #仪器窗口"Ask AI"按钮的回灌:把手工摸出的命令/响应序列追加进输入框
        !isempty(QInsControlAI.AIINJECT[]) && begin
            inject = QInsControlAI.AIINJECT[]
            QInsControlAI.AIINJECT[] = ""
            inputbuf = inputbuf == "" ? inject : inputbuf * "\n\n" * inject
        end
        #附件队列:文件选择器(后台线程)/绘图截图按钮推入,这里取走
        isempty(QInsControlAI.AIATTACH[]) || (append!(pendingimgs, QInsControlAI.AIATTACH[]); empty!(QInsControlAI.AIATTACH[]))
        pnames = String[p.name for p in QInsControlAI.aiconf().providers]
        provname[] = QInsControlAI.aiconf().default
        isempty(pnames) || begin
            CImGui.SetNextItemWidth(230)
            if @c ComboS("##aiprovider", &provname[], pnames)
                QInsControlAI.aiconf().default = provname[]
            end
        end
        CImGui.SameLine()
        #当前供应商的模型下拉(供应商下挂模型列表;列表为空时只显示 model 单值)
        prov = QInsControlAI.getprovider()
        if prov !== nothing
            mlist = unique(vcat(prov.models, isempty(prov.model) ? String[] : [prov.model]))
            if length(mlist) > 1
                provmodel[] = prov.model
                CImGui.SetNextItemWidth(190)
                if @c ComboS("##aimodel", &provmodel[], mlist)
                    prov.model = provmodel[]
                end
                CImGui.SameLine()
            end
        end
        CImGui.SameLine()
        #思考强度快捷切换(主流 agent 工具的做法):写当前默认供应商的 think 字段,随选随用;
        #"default" 不发送参数,跟随该供应商/模型的自身默认
        provthink[] = prov === nothing ? "default" : (prov.think == "" ? "default" : prov.think)
        CImGui.SetNextItemWidth(110)
        thinkchanged = @c ComboS("##thinksel", &provthink[], ["default", "off", "low", "medium", "high"])
        thinkchanged && prov !== nothing && (prov.think = provthink[] == "default" ? "" : provthink[])
        CImGui.SameLine()
        @c CImGui.Checkbox(stcstr(mlstr("Agent"), "##aiagentmode"), &agentmode[])
        ItemTooltip(mlstr("Let AI write to instruments or projects (read-only tools are always available)"))
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Conversation"))) && QInsControlAI.newconversation!()
        QInsControlAI.aiconf().enable || CImGui.TextDisabled(stcstr("⚠ ", mlstr("AI is disabled in Settings")))
        # 消息区
        ftsz = CImGui.GetFontSize()
        inputh = (1 + count('\n', inputbuf)) * ftsz + 2unsafe_load(IMGUISTYLE.FramePadding.y)
        #底部保留 = 输入框行 + 附件/chips 常驻行(frameheight) + child/附件行/输入行三处行间距
        reserveh = inputh + CImGui.GetFrameHeight() + 3unsafe_load(IMGUISTYLE.ItemSpacing.y)
        CImGui.BeginChild("##aimsgs", (Cfloat(0), -reserveh), false)
        msgs = lock(() -> copy(conv.messages), QInsControlAI.CHATLOCK) #快照:AI 线程正持 CHATLOCK push!,直接迭代会与扩容竞争
        for (i, m) in enumerate(msgs)
            m.role == "system" && continue
            CImGui.PushID(i)
            if m.role == "user"
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
                CImGui.Text(stcstr(MORESTYLE.Icons.SendMsg, " ", mlstr("You")))
                CImGui.PopStyleColor()
                CImGui.SameLine()
                copybtn(m.content)
                CImGui.Indent()
                messagetext(stcstr("##aiuser", i), m.content)
                for (mime, _, name) in m.images
                    CImGui.TextDisabled(stcstr("🖼 ", name, " (", mime, ")"))
                end
                CImGui.Unindent()
            elseif m.role == "assistant"
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.InfoText)
                CImGui.Text(stcstr(ICONS.ICON_ROBOT, " ", mlstr("Assistant")))
                CImGui.PopStyleColor()
                CImGui.SameLine()
                copybtn(m.content)
                CImGui.Indent()
                renderassistant(m.content, m.reasoning, stcstr("m", i))
                for tc in m.toolcalls
                    CImGui.TextDisabled(stcstr("🔧 ", get(tc, "name", "?"), "()"))
                end
                CImGui.Unindent()
            elseif m.role == "tool"
                CImGui.TextDisabled(stcstr("   ↳ ", mlstr("tool result"), ": ", first(m.content, 120)))
            end
            CImGui.PopID()
            CImGui.Dummy((Cfloat(0), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
        end
        if QInsControlAI.CHAT.busy
            lock(QInsControlAI.CHATLOCK) do
                for (nm, args, result) in QInsControlAI.CHAT.toolsteps
                    CImGui.TextDisabled(stcstr("🔧 ", nm, "(", first(args, 60), ") → ", first(result, 80)))
                end
                isempty(QInsControlAI.CHAT.reasoning) || CImGui.TextDisabled(stcstr("· ", mlstr("reasoning"), " (", length(QInsControlAI.CHAT.reasoning), " ", mlstr("chars"), ") ·"))
                isempty(QInsControlAI.CHAT.inflight) || renderassistant(QInsControlAI.CHAT.inflight, "", "streaming")
                (isempty(QInsControlAI.CHAT.inflight) && isempty(QInsControlAI.CHAT.reasoning) && isempty(QInsControlAI.CHAT.toolsteps)) && CImGui.TextDisabled("…")
            end
        end
        scrollbottom && (CImGui.SetScrollHereY(1); scrollbottom = false)
        CImGui.EndChild()
        # 输入区(Console 同款:自适应行高 + Ctrl+Enter 发送 + Up/Down 历史)
        #附件/chips 行常驻占一行(高度已在 reserveh 预留,与输入框高度分开计算)
        # 待发图片 chips(附件按钮/绘图截图推入)+ 附件选择
        for (i, im) in enumerate(pendingimgs)
            CImGui.TextDisabled(stcstr("🖼 ", im[3]))
            CImGui.SameLine()
            CImGui.PushID(stcstr("##rmpimg", i))
            CImGui.SmallButton(MORESTYLE.Icons.Delete) && begin
                deleteat!(pendingimgs, i)
                CImGui.PopID()
                break
            end
            CImGui.PopID()
        end
        #SameLine 只在已有 chips 时调用:空行上调 SameLine 会把按钮挤到消息区右侧屏幕外
        isempty(pendingimgs) || CImGui.SameLine()
        (CImGui.SmallButton(stcstr(MORESTYLE.Icons.OpenFile, " ", mlstr("Attach Image")))) && Threads.@spawn begin
            for f in pick_multi_file(filterlist = "png,jpg,jpeg")
                enc = QInsControlAI.ai_encodefile(f)
                enc === nothing || push!(QInsControlAI.AIATTACH[], enc)
            end
        end
        CImGui.igBeginDisabled(QInsControlAI.aiconf().enable ? QInsControlAI.CHAT.busy : true)
        @c InputTextMultilineRSZ("##aiinput", &inputbuf, (Cfloat(0), Cfloat(inputh)))
        CImGui.igEndDisabled()
        if CImGui.IsItemHovered() && !CImGui.IsItemActive()
            if CImGui.IsKeyReleased(CImGui.ImGuiKey_UpArrow) && inputhistory[-1] != ""
                move!(inputhistory, -1)
                historymax += 1
                inputbuf = inputhistory[]
            elseif CImGui.IsKeyReleased(CImGui.ImGuiKey_DownArrow) && inputhistory[1] != ""
                move!(inputhistory)
                historymax -= 1
                inputbuf = inputhistory[]
            end
        end
        CImGui.SameLine()
        if QInsControlAI.CHAT.busy
            CImGui.Button(stcstr(MORESTYLE.Icons.InterruptTask, " ", mlstr("Stop"))) && QInsControlAI.stopchat!()
        else
            send = CImGui.Button(stcstr(MORESTYLE.Icons.SendMsg, " ", mlstr("Send"))) ||
                   (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyDown(CImGui.ImGuiKey_Enter))
            if send && (strip(inputbuf) != "" || !isempty(pendingimgs))
                text = String(strip(inputbuf))
                move!(inputhistory, historymax)
                isempty(text) || (inputhistory[] = text; move!(inputhistory))
                historymax = 0
                inputbuf = ""
                imgs = copy(pendingimgs)
                empty!(pendingimgs)
                scrollbottom = true
                sendchat!(text; agent=agentmode[], images=imgs)
            end
        end
        return
    end

    # ============ History 页 ============
    function rendertabhistory()
        CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Conversation"))) && QInsControlAI.newconversation!()
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && QInsControlAI.deleteconversation!(QInsControlAI.CHAT.current)
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, " ", mlstr("Open Folder"))) &&
            DefaultApplication.open(QInsControlAI.aiconf().dir)
        CImGui.Separator()
        for (i, c) in enumerate(QInsControlAI.CHAT.conversations)
            CImGui.PushID(stcstr("##aiconv", i))
            CImGui.Selectable(stcstr(c.title, " (", length(c.messages), ")"), i == QInsControlAI.CHAT.current) &&
                (QInsControlAI.CHAT.current = i; scrollbottom = true)
            CImGui.PopID()
        end
        return
    end

    # ============ Settings 页 ============
    function rendertabsettings()
        conf = QInsControlAI.aiconf()
        BoxTextColored(mlstr("Providers"); col=MORESTYLE.Colors.HighlightText)
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New"))) && begin
            #名字必须唯一:findfirst/Combo 都按名字定位,重名会让编辑与选择错乱
            nm = mlstr("New Provider")
            k = 2
            while any(p -> p.name == nm, conf.providers)
                nm = stcstr(mlstr("New Provider"), " ", k)
                k += 1
            end
            push!(conf.providers, QInsControlAI.AIProvider(name = nm))
            provseli[] = length(conf.providers)
            modelsbufidx[] = 0   #触发模型列表缓冲重载
        end
        CImGui.SameLine()
        if CImGui.Button(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && length(conf.providers) > 1
            deleteat!(conf.providers, provseli[])
            provseli[] = clamp(provseli[], 1, length(conf.providers))
            conf.default in (x.name for x in conf.providers) || (conf.default = conf.providers[1].name)
            modelsbufidx[] = 0   #触发模型列表缓冲重载
        end
        isempty(conf.providers) && return
        pnames = String[p.name for p in conf.providers]
        #按索引选择:provider 改名不影响选中项(旧的按 name findfirst 方案在改名瞬间失配错乱)
        provseli[] = clamp(provseli[], 1, length(conf.providers))
        provnameedit = pnames[provseli[]]
        combochanged = @c ComboS("##aiprovedit", &provnameedit, pnames)
        combochanged && (provseli[] = something(findfirst(==(provnameedit), pnames), provseli[]))
        p = conf.providers[provseli[]]
        CImGui.Separator()
        oldname = p.name
        namechanged = @c InputTextRSZ(mlstr("Name"), &p.name)
        #改名同步:default 指向旧名时跟新,否则保存后默认供应商失效
        namechanged && conf.default == oldname && !isempty(p.name) && (conf.default = p.name)
        @c ComboS("API", &p.apitype, ["openai", "anthropic"])
        @c InputTextRSZ(mlstr("Base URL"), &p.baseurl)
        #模型列表:逗号分隔编辑(聊天页下拉切换用);缓冲跟随选中的 provider 索引
        modelsbufidx[] != provseli[] && (modelsbuf[] = join(p.models, ", "); modelsbufidx[] = provseli[])
        @c InputTextRSZ(stcstr(mlstr("Models"), " (,)"), &modelsbuf[])
        p.models = filter(!isempty, [strip(x) for x in split(modelsbuf[], ",")])
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.ServerMonitor, " ", mlstr("Fetch"))) && begin
            fetchstat[] = mlstr("fetching…")
            pname = p.name
            Threads.@spawn begin
                out = QInsControlAI.ai_fetch_models(pname)
                if startswith(out, "fetch failed") || startswith(out, "unexpected") || out == "provider returned no models"
                    fetchstat[] = out
                else
                    ids = [strip(x) for x in split(out, '\n')]
                    QInsControlAI.ai_ui_enqueue() do
                        idx = clamp(provseli[], 1, length(conf.providers))
                        conf.providers[idx].models = ids
                        modelsbufidx[] = 0   #强制缓冲重载
                        fetchstat[] = stcstr(mlstr("fetched "), length(ids), " ", mlstr("models"))
                    end
                end
            end
        end
        isempty(fetchstat[]) || (CImGui.SameLine(); CImGui.TextDisabled(fetchstat[]))
        #当前模型:从候选列表下拉选择(model 字段始终保留在选项里,兼容不在列表中的旧配置)
        curmodels = unique(vcat(p.models, isempty(p.model) ? String[] : [p.model]))
        @c ComboS(mlstr("Current model"), &p.model, curmodels)
        @c InputTextRSZ(mlstr("API Key"), &p.apikey, CImGui.ImGuiInputTextFlags_Password)
        ItemTooltip(mlstr("Paste a key or env:VARIABLENAME to read it from the environment"))
        @c CImGui.InputDouble(mlstr("Temperature"), &p.temperature)
        @c CImGui.Checkbox(mlstr("Stream"), &p.stream)
        @c ComboS(mlstr("Thinking effort"), &p.think, ["", "off", "low", "medium", "high"])
        ItemTooltip(mlstr(
            "low/medium/high: OpenAI protocol sends reasoning_effort (StepFun step_plan, OpenAI o/gpt-5 series); Anthropic protocol enables thinking with a token budget. Empty = provider default. 'off' = omit (OpenAI protocol has no unified off switch)."
        ))
        @c InputTextRSZ(mlstr("Extra body JSON"), &p.extra)
        ItemTooltip(mlstr(
            "Optional JSON object merged into the request top level - for vendor-specific fields, e.g. {\"thinking\":{\"type\":\"enabled\"}} (GLM) or {\"enable_thinking\":true} (Qwen). Keys here override defaults."
        ))
        CImGui.Separator()
        if !testbusy[]
            CImGui.Button(stcstr(MORESTYLE.Icons.ServerMonitor, " ", mlstr("Test"))) &&
            testconnection!(teststatus, testbusy, p.name)   #测当前编辑的供应商,而非全局默认
            CImGui.SameLine()
        end
        CImGui.Text(stcstr(mlstr("Test Connection"), ": ", teststatus[]))
        CImGui.Separator()
        @c CImGui.Checkbox(stcstr(mlstr("Inject experiment context"), "##aiinj"), &conf.injectcontext)
        @c CImGui.Checkbox(stcstr(mlstr("Include quantity help in context"), "##aihelp"), &conf.withhelp)
        @c CImGui.Checkbox(stcstr(mlstr("Confirm before writing instruments/projects"), "##aicfm"), &conf.confirmwrites)
        conf.confirmwrites || CImGui.TextDisabled(mlstr("auto-action mode: writes run without confirmation, a toast notification is shown instead (applies to built-in chat and MCP)"))
        @c CImGui.Checkbox(stcstr(mlstr("Allow web access for manuals (search/fetch)"), "##aiweb"), &conf.allowweb)
        @c CImGui.Checkbox(stcstr(mlstr("Encrypt stored API keys (Windows DPAPI)"), "##aienc"), &conf.encryptkeys)
        @c CImGui.InputInt(mlstr("Max history messages"), &conf.maxhistory)
        @c CImGui.InputInt(mlstr("Max tool turns"), &conf.maxtoolturns)
        @c CImGui.InputInt(stcstr(mlstr("Timeout"), " (s)"), &conf.timeout)
        @c CImGui.InputInt(mlstr("Max data sample"), &conf.maxdatasample)
        @c ComboS(mlstr("Default provider"), &conf.default, pnames)
        CImGui.Separator()
        CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save"))) && begin
            QInsControlAI.saveconf_ai()
            @info "[$(Dates.now())]\n$(mlstr("AI configuration saved"))" path = QInsControlAI.aiconfpath()
        end
        return
    end

    # ============ 脚本/绘图预览确认模态 ============
    function renderscriptmodal()
        wantpreview && (CImGui.OpenPopup(stcstr(mlstr("AI Result Preview"), "##aiscriptpreview")); wantpreview = false)
        CImGui.SetNextWindowSize((680, 560) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Appearing)
        sm = scriptmodal
        if CImGui.BeginPopupModal(
            stcstr(mlstr("AI Result Preview"), "##aiscriptpreview"), C_NULL, CImGui.ImGuiWindowFlags_NoSavedSettings
        )
            if sm.ok
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.InfoText)
                CImGui.Text(sm.mode == :task ?
                            stcstr("✓ ", mlstr("parsed to "), length(sm.blocks), " ", mlstr("blocks")) :
                            stcstr("✓ ", mlstr("plot configuration validated")))
            else
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ErrorText)
                CImGui.Text(stcstr("✗ ", mlstr("validation failed")))
            end
            CImGui.PopStyleColor()
            if !sm.ok
                CImGui.PushTextWrapPos(0)
                CImGui.TextUnformatted(sm.err)
                CImGui.PopTextWrapPos()
            elseif sm.warn != ""
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.WarnText)
                CImGui.PushTextWrapPos(0)
                CImGui.TextUnformatted(sm.warn)
                CImGui.PopTextWrapPos()
                CImGui.PopStyleColor()
            end
            CImGui.BeginChild(
                "##aiscripttext",
                (Cfloat(0), -5unsafe_load(IMGUISTYLE.FramePadding.y) - 3CImGui.GetFrameHeight()), true
            )
            CImGui.PushTextWrapPos(0)
            CImGui.TextUnformatted(sm.mode == :task ? sm.script :
                                   stcstr(sm.script, "\n\n", sm.cfg === nothing ? "" : first(sprint(show, sm.cfg), 600)))
            CImGui.PopTextWrapPos()
            CImGui.EndChild()
            if sm.ok
                names = sm.mode == :task ? QInsControlAI.ai_task_names() : QInsControlAI.ai_plot_names()
                CImGui.Text(mlstr("Target"))
                CImGui.SameLine()
                targetlist = vcat([stcstr("+ ", mlstr("New"))], names)
                ti = sm.target[] + 1
                name = targetlist[ti]
                if @c ComboS("##aitarget", &name, targetlist)
                    ti = findfirst(==(name), targetlist)
                    sm.target[] = ti - 1
                end
                CImGui.Text(mlstr("Name"))
                CImGui.SameLine()
                @c InputTextRSZ("##aisavename", &sm.namebuf[])
                ftsz = CImGui.GetFontSize()
                if CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")), (5ftsz, Cfloat(0)))
                    #target[] 是 targetlist("+ 新" + names)的 0 基下标,1..n 直接对应 names 的 1..n:
                    #任务按索引更新(ai_task_names 是显示名,反查 t.name 永不匹配);绘图按真名更新
                    if sm.mode == :task
                        if sm.target[] == 0
                            QInsControlAI.ai_add_task(sm.namebuf[], sm.script, sm.blocks)
                        elseif sm.target[] <= length(names)
                            QInsControlAI.ai_update_task_byindex(sm.target[], sm.script, sm.blocks)
                        end
                    else
                        if sm.target[] == 0
                            QInsControlAI.ai_add_plot(sm.namebuf[], sm.cfg)
                        elseif sm.target[] <= length(names)
                            QInsControlAI.ai_update_plot(names[sm.target[]], sm.cfg)
                        end
                    end
                    scriptmodal = nothing
                    CImGui.CloseCurrentPopup()
                end
                CImGui.SameLine()
            end
            if CImGui.Button(mlstr("Cancel"), (4CImGui.GetFontSize(), Cfloat(0)))
                scriptmodal = nothing
                CImGui.CloseCurrentPopup()
            end
            CImGui.EndPopup()
        elseif !wantpreview && !CImGui.IsPopupOpen(stcstr(mlstr("AI Result Preview"), "##aiscriptpreview"))
            scriptmodal = nothing
        end
        return
    end
end
