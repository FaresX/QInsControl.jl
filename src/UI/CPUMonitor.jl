function CPUMonitor(p_open::Ref)
    CImGui.SetNextWindowSize((600, 300), CImGui.ImGuiCond_Once)
    if CImGui.Begin(stcstr(MORESTYLE.Icons.CPUMonitor, " 仪器CPU监测"), p_open)
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, "ID: ")
        CImGui.SameLine()
        CImGui.Text(stcstr(remotecall_fetch(() -> CPU.id, workers()[1])))
        CImGui.Spacing()
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, "状态")
        CImGui.Indent()
        if remotecall_fetch(() -> CPU.running, workers()[1])[]
            CImGui.TextColored(MORESTYLE.Colors.LogInfo, "运行中")
            CImGui.SameLine()
            if SYNCSTATES[Int(IsDAQTaskRunning)]
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled))
            end
            if CImGui.Button(stcstr(MORESTYLE.Icons.InterruptTask, " 停止"))
                SYNCSTATES[Int(IsDAQTaskRunning)] || remotecall_wait(() -> stop!(CPU), workers()[1])
            end
            SYNCSTATES[Int(IsDAQTaskRunning)] && CImGui.PopStyleColor()
            CImGui.SameLine(0, 4CImGui.GetFontSize())
            remotecall_fetch(() -> CPU.fast, workers()[1])[] ? CImGui.Text("快速模式") : CImGui.Text("慢速模式")
            CImGui.SameLine()
            if CImGui.Button(stcstr(MORESTYLE.Icons.Convert, " 切换"))
                remotecall_wait(workers()[1]) do
                    CPU.fast[] ⊻= true
                end
            end
        else
            CImGui.TextColored(MORESTYLE.Colors.LogError, "已停止")
            CImGui.SameLine()
            CImGui.Button(stcstr(MORESTYLE.Icons.RunTask, " 重启")) && remotecall_wait(() -> start!(CPU), workers()[1])
        end
        CImGui.Unindent()
        CImGui.Spacing()
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, "控制器")
        CImGui.SameLine()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.InstrumentsManualRef, " 重连")
        ) && remotecall_wait(() -> reconnect!(CPU), workers()[1])
        CImGui.Indent()
        cts = values(remotecall_fetch(() -> CPU.controllers, workers()[1]))
        if isempty(cts)
            CImGui.TextDisabled("(空)")
        else
            taskhandlers = remotecall_fetch(() -> CPU.taskhandlers, workers()[1])
            instrs = remotecall_fetch(() -> CPU.instrs, workers()[1])
            for ct in cts
                @trypass showct(ct, taskhandlers[ct.addr], QInsControlCore.isconnected(instrs[ct.addr])) nothing
                CImGui.Spacing()
            end
        end
        CImGui.Unindent()
    end
    CImGui.End()
end

function showct(ct::Controller, running, connected)
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, "ID: ")
    CImGui.SameLine()
    CImGui.Text(stcstr(ct.id))
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, "状态")
    CImGui.Indent()
    if running
        CImGui.TextColored(MORESTYLE.Colors.LogInfo, "运行中")
    else
        CImGui.TextColored(MORESTYLE.Colors.LogError, "已停止")
    end
    CImGui.Unindent()
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, "仪器")
    CImGui.Indent()
    CImGui.Text(ct.instrnm)
    CImGui.SameLine(0, 4CImGui.GetFontSize())
    CImGui.Text(ct.addr)
    CImGui.SameLine()
    if connected
        CImGui.TextColored(MORESTYLE.Colors.LogInfo, "已连接")
    else
        CImGui.TextColored(MORESTYLE.Colors.LogError, "未连接")
    end
    CImGui.Unindent()
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, "缓存")
    CImGui.Indent()
    if isempty(ct.databuf)
        CImGui.TextDisabled("(空)")
    else
        for (id, dt) in ct.databuf
            CImGui.Text(stcstr(id, " => ", dt))
        end
    end
    CImGui.Unindent()
end
