function CPUMonitor(p_open::Ref)
    CImGui.SetNextWindowSize((600, 300), CImGui.ImGuiCond_Once)
    if CImGui.Begin(stcstr(morestyle.Icons.CPUMonitor, " 仪器CPU监测"), p_open)
        CImGui.TextColored(morestyle.Colors.HighlightText, "ID: ")
        CImGui.SameLine()
        CImGui.Text(stcstr(CPU.id))
        CImGui.Spacing()
        CImGui.TextColored(morestyle.Colors.HighlightText, "状态")
        CImGui.Indent()
        if CPU.running[]
            CImGui.TextColored(morestyle.Colors.LogInfo, "运行中")
            CImGui.SameLine()
            if SyncStates[Int(isdaqtask_running)]
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_TextDisabled))
            end
            if CImGui.Button(stcstr(morestyle.Icons.InterruptTask, " 停止"))
                SyncStates[Int(isdaqtask_running)] || stop!(CPU)
            end
            SyncStates[Int(isdaqtask_running)] && CImGui.PopStyleColor()
            CImGui.SameLine(0, 4CImGui.GetFontSize())
            CPU.fast[] ? CImGui.Text("快速模式") : CImGui.Text("慢速模式")
            CImGui.SameLine()
            CImGui.Button(stcstr(morestyle.Icons.Convert, " 切换")) && (CPU.fast[] ⊻= true)
        else
            CImGui.TextColored(morestyle.Colors.LogError, "已停止")
            CImGui.SameLine()
            CImGui.Button(stcstr(morestyle.Icons.RunTask, " 重启")) && start!(CPU)
        end
        CImGui.Unindent()
        CImGui.Spacing()
        CImGui.TextColored(morestyle.Colors.HighlightText, "控制器")
        CImGui.SameLine()
        CImGui.Button(stcstr(morestyle.Icons.InstrumentsManualRef, " 重连")) && reconnect!(CPU)
        CImGui.Indent()
        cts = values(CPU.controllers)
        if isempty(cts)
            CImGui.TextDisabled("(空)")
        else
            for ct in cts
                @trypass showct(ct, CPU.taskhandlers[ct.addr], QInsControlCore.isconnected(CPU.instrs[ct.addr])) nothing
                CImGui.Spacing()
            end
        end
        CImGui.Unindent()
    end
    CImGui.End()
end

function showct(ct::Controller, running, connected)
    CImGui.TextColored(morestyle.Colors.HighlightText, "ID: ")
    CImGui.SameLine()
    CImGui.Text(stcstr(ct.id))
    CImGui.TextColored(morestyle.Colors.HighlightText, "状态")
    CImGui.Indent()
    if running
        CImGui.TextColored(morestyle.Colors.LogInfo, "运行中")
    else
        CImGui.TextColored(morestyle.Colors.LogError, "已停止")
    end
    CImGui.Unindent()
    CImGui.TextColored(morestyle.Colors.HighlightText, "仪器")
    CImGui.Indent()
    CImGui.Text(ct.instrnm)
    CImGui.SameLine(0, 4CImGui.GetFontSize())
    CImGui.Text(ct.addr)
    CImGui.SameLine()
    if connected
        CImGui.TextColored(morestyle.Colors.LogInfo, "已连接")
    else
        CImGui.TextColored(morestyle.Colors.LogError, "未连接")
    end
    CImGui.Unindent()
    CImGui.TextColored(morestyle.Colors.HighlightText, "缓存")
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
