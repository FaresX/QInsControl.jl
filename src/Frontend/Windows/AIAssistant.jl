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
    provsel::Ref{String} = Ref("")
    agentmode::Ref{Bool} = Ref(false)
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
            mode=:task, script=String(code), ok=ok, blocks=blocks, err=err, cfg=nothing,
            target=Ref(0), namebuf=Ref("AI Task")
        )
        wantpreview = true
    end

    function wantplot(code::AbstractString)
        cfg = QInsControlAI.extractplotcfg(code)
        if cfg === nothing
            scriptmodal = (mode=:plot, script=String(code), ok=false, blocks=nothing,
                err="no valid JSON plot configuration found", cfg=nothing,
                target=Ref(0), namebuf=Ref("AI Plot"))
        else
            err = QInsControlAI.ai_validate_plotcfg(cfg)
            scriptmodal = (mode=:plot, script=String(code), ok=err == "", blocks=nothing, err=err,
                cfg=cfg, target=Ref(0), namebuf=Ref("AI Plot"))
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
        pnames = String[p.name for p in QInsControlAI.aiconf().providers]
        provname[] = QInsControlAI.aiconf().default
        isempty(pnames) || begin
            if @c ComboS("##aiprovider", &provname[], pnames)
                QInsControlAI.aiconf().default = provname[]
            end
        end
        CImGui.SameLine()
        @c CImGui.Checkbox(stcstr(mlstr("Agent"), "##aiagentmode"), &agentmode[])
        ItemTooltip(mlstr("Let AI write to instruments or projects (read-only tools are always available)"))
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Conversation"))) && newconversation!()
        QInsControlAI.aiconf().enable || CImGui.TextDisabled(stcstr("⚠ ", mlstr("AI is disabled in Settings")))
        # 消息区
        ftsz = CImGui.GetFontSize()
        lineheigth = (1 + count('\n', inputbuf)) * ftsz + 2unsafe_load(IMGUISTYLE.FramePadding.y)
        CImGui.BeginChild("##aimsgs", (Cfloat(0), -lineheigth - unsafe_load(IMGUISTYLE.ItemSpacing.y)), false)
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
                isempty(QInsControlAI.CHAT.reasoning) || CImGui.TextDisabled(stcstr("· reasoning (", length(QInsControlAI.CHAT.reasoning), " chars) ·"))
                isempty(QInsControlAI.CHAT.inflight) || renderassistant(QInsControlAI.CHAT.inflight, "", "streaming")
                (isempty(QInsControlAI.CHAT.inflight) && isempty(QInsControlAI.CHAT.reasoning) && isempty(QInsControlAI.CHAT.toolsteps)) && CImGui.TextDisabled("…")
            end
        end
        scrollbottom && (CImGui.SetScrollHereY(1); scrollbottom = false)
        CImGui.EndChild()
        # 输入区(Console 同款:自适应行高 + Ctrl+Enter 发送 + Up/Down 历史)
        lineheigth = (1 + count('\n', inputbuf)) * ftsz + 2unsafe_load(IMGUISTYLE.FramePadding.y)
        CImGui.igBeginDisabled(QInsControlAI.aiconf().enable ? QInsControlAI.CHAT.busy : true)
        @c InputTextMultilineRSZ("##aiinput", &inputbuf, (Cfloat(0), Cfloat(lineheigth)))
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
            CImGui.Button(stcstr(MORESTYLE.Icons.InterruptTask, " ", mlstr("Stop"))) && stopchat!()
        else
            send = CImGui.Button(stcstr(MORESTYLE.Icons.SendMsg, " ", mlstr("Send"))) ||
                   (unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyDown(CImGui.ImGuiKey_Enter))
            if send && strip(inputbuf) != ""
                text = String(strip(inputbuf))
                move!(inputhistory, historymax)
                inputhistory[] = text
                move!(inputhistory)
                historymax = 0
                inputbuf = ""
                scrollbottom = true
                sendchat!(text; agent=agentmode[])
            end
        end
        return
    end

    # ============ History 页 ============
    function rendertabhistory()
        CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Conversation"))) && newconversation!()
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && deleteconversation!(QInsControlAI.CHAT.current)
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
            push!(conf.providers, QInsControlAI.AIProvider(name="New Provider"))
            provsel[] = "New Provider"
        end
        CImGui.SameLine()
        if CImGui.Button(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && length(conf.providers) > 1
            di = findfirst(p -> p.name == provsel[], conf.providers)
            di === nothing || deleteat!(conf.providers, di)
            provsel[] = conf.providers[1].name
        end
        isempty(conf.providers) && return
        pnames = String[p.name for p in conf.providers]
        provsel[] == "" && (provsel[] = conf.default in pnames ? conf.default : conf.providers[1].name)
        @c ComboS("##aiprovedit", &provsel[], pnames)
        pi = findfirst(p -> p.name == provsel[], conf.providers)
        pi === nothing && return
        p = conf.providers[pi]
        CImGui.Separator()
        @c InputTextRSZ(mlstr("Name"), &p.name)
        @c ComboS("API", &p.apitype, ["openai", "anthropic"])
        @c InputTextRSZ("Base URL", &p.baseurl)
        @c InputTextRSZ(mlstr("Model"), &p.model)
        @c InputTextRSZ("API Key", &p.apikey, CImGui.ImGuiInputTextFlags_Password)
        ItemTooltip(mlstr("Paste a key or env:VARIABLENAME to read it from the environment"))
        @c CImGui.InputDouble(mlstr("Temperature"), &p.temperature)
        @c CImGui.Checkbox(mlstr("Stream"), &p.stream)
        CImGui.Separator()
        if !testbusy[]
            CImGui.Button(stcstr(MORESTYLE.Icons.ServerMonitor, " ", mlstr("Test"))) &&
            testconnection!(teststatus, testbusy)
            CImGui.SameLine()
        end
        CImGui.Text(stcstr(mlstr("Test Connection"), ": ", teststatus[]))
        CImGui.Separator()
        @c CImGui.Checkbox(stcstr(mlstr("Inject experiment context"), "##aiinj"), &conf.injectcontext)
        @c CImGui.Checkbox(stcstr(mlstr("Include quantity help in context"), "##aihelp"), &conf.withhelp)
        @c CImGui.Checkbox(stcstr(mlstr("Confirm before writing instruments/projects"), "##aicfm"), &conf.confirmwrites)
        @c CImGui.Checkbox(stcstr(mlstr("Allow AI to run tasks (NOT recommended)"), "##airun"), &conf.allowsrun)
        @c CImGui.Checkbox(stcstr(mlstr("Allow web access for manuals (search/fetch)"), "##aiweb"), &conf.allowweb)
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
                    if sm.mode == :task
                        if sm.target[] == 0
                            QInsControlAI.ai_add_task(sm.namebuf[], sm.script, sm.blocks)
                        elseif sm.target[] - 1 <= length(names)
                            QInsControlAI.ai_update_task(names[sm.target[]-1], sm.script, sm.blocks)
                        end
                    else
                        if sm.target[] == 0
                            QInsControlAI.ai_add_plot(sm.namebuf[], sm.cfg)
                        elseif sm.target[] - 1 <= length(names)
                            QInsControlAI.ai_update_plot(names[sm.target[]-1], sm.cfg)
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
