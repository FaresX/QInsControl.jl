function CPUMonitor(p_open::Ref)
    CImGui.SetNextWindowSize((600, 300), CImGui.ImGuiCond_Once)
    if CImGui.Begin(stcstr(MORESTYLE.Icons.CPUMonitor, " ", mlstr("Instrument CPU Monitor")), p_open)
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, "ID: ")
        CImGui.SameLine()
        CImGui.Text(stcstr(remotecall_fetch(() -> CPU.id, workers()[1])))
        CImGui.Spacing()
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("status"))
        CImGui.Indent()
        if remotecall_fetch(() -> CPU.running, workers()[1])[]
            CImGui.TextColored(MORESTYLE.Colors.LogInfo, mlstr("running"))
            CImGui.SameLine()
            if SYNCSTATES[Int(IsDAQTaskRunning)]
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled))
            end
            if CImGui.Button(stcstr(MORESTYLE.Icons.InterruptTask, " ", mlstr("Stop")))
                SYNCSTATES[Int(IsDAQTaskRunning)] || remotecall_wait(() -> stop!(CPU), workers()[1])
            end
            SYNCSTATES[Int(IsDAQTaskRunning)] && CImGui.PopStyleColor()
            CImGui.SameLine(0, 4CImGui.GetFontSize())
            if remotecall_fetch(() -> CPU.fast, workers()[1])[]
                CImGui.Text(mlstr("fast mode"))
            else
                CImGui.Text(mlstr("slow mode"))
            end
            CImGui.SameLine()
            if CImGui.Button(stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Switch")))
                remotecall_wait(workers()[1]) do
                    CPU.fast[] ⊻= true
                end
            end
        else
            CImGui.TextColored(MORESTYLE.Colors.LogError, mlstr("stopped"))
            CImGui.SameLine()
            if CImGui.Button(stcstr(MORESTYLE.Icons.RunTask, " ", mlstr("Reboot")))
                remotecall_wait(() -> start!(CPU), workers()[1])
            end
        end
        CImGui.Unindent()
        CImGui.Spacing()
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("controllers"))
        CImGui.SameLine()
        CImGui.Button(
            stcstr(MORESTYLE.Icons.InstrumentsManualRef, " ", mlstr("Reconnect"))
        ) && remotecall_wait(() -> reconnect!(CPU), workers()[1])
        CImGui.Indent()
        cts = values(remotecall_fetch(() -> CPU.controllers, workers()[1]))
        if isempty(cts)
            CImGui.TextDisabled(stcstr("(", mlstr("null"), ")"))
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
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("status"))
    CImGui.Indent()
    if running
        CImGui.TextColored(MORESTYLE.Colors.LogInfo, mlstr("running"))
    else
        CImGui.TextColored(MORESTYLE.Colors.LogError, mlstr("stopped"))
    end
    CImGui.Unindent()
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("instrument"))
    CImGui.Indent()
    CImGui.Text(ct.instrnm)
    CImGui.SameLine(0, 4CImGui.GetFontSize())
    CImGui.Text(ct.addr)
    CImGui.SameLine()
    if connected
        CImGui.TextColored(MORESTYLE.Colors.LogInfo, mlstr("connected"))
    else
        CImGui.TextColored(MORESTYLE.Colors.LogError, mlstr("unconnected"))
    end
    CImGui.Unindent()
    CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("buffer"))
    CImGui.Indent()
    if isempty(ct.databuf)
        CImGui.TextDisabled(stcstr("(", mlstr("null"), ")"))
    else
        for (id, dt) in ct.databuf
            CImGui.Text(stcstr(id, " => ", dt))
        end
    end
    CImGui.Unindent()
end
