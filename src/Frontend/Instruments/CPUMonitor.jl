let
    cpuinfo::Dict = Dict()
    lastrefreshtime::String = string(now())
    global function CPUMonitor()
        refreshcpuinfo()
        CImGui.SeparatorText(lastrefreshtime)
        isempty(cpuinfo) && return nothing
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Processor"))
        if cpuinfo[:running]
            igBeginDisabled(SYNCSTATES[IsDAQTaskRunning] || STATES[AutoRefreshing])
            ToggleButton(mlstr("Running"), Ref(true)) && remote_stopcpu!()
            igEndDisabled()
            CImGui.SameLine()
            ColoredButton(
                mlstr(cpuinfo[:taskfailed] ? "Failed" : "Well");
                colbt=cpuinfo[:taskfailed] ? MORESTYLE.Colors.ErrorBg : MORESTYLE.Colors.InfoBg,
                colbth=cpuinfo[:taskfailed] ? MORESTYLE.Colors.ErrorBg : MORESTYLE.Colors.InfoBg,
                colbta=cpuinfo[:taskfailed] ? MORESTYLE.Colors.ErrorBg : MORESTYLE.Colors.InfoBg
            )
            CImGui.SameLine()
            if CImGui.Checkbox(mlstr(cpuinfo[:fast] ? "Fast Mode" : "Slow Mode"), Ref(cpuinfo[:fast]))
                remote_cpumode!(!cpuinfo[:fast])
            end
            CImGui.SameLine()
            #传输模型指示:单线程 worker 为 vector 槽位模型,否则通道模型(由 worker 线程数决定)
            CImGui.TextDisabled(mlstr(cpuinfo[:vecmode] ? "Vector" : "Channel"))
        else
            ToggleButton(mlstr("Stopped"), Ref(false)) && remote_startcpu!()
        end
        CImGui.Spacing()
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Controllers"))
        if isempty(cpuinfo[:instrs])
            CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
        else
            instrtocontrollers = Dict()
            for ct in cpuinfo[:controllers]
                haskey(instrtocontrollers, ct.instrnm) || (instrtocontrollers[ct.instrnm] = Dict())
                haskey(instrtocontrollers[ct.instrnm], ct.addr) || (instrtocontrollers[ct.instrnm][ct.addr] = [])
                push!(instrtocontrollers[ct.instrnm][ct.addr], ct)
            end
            for (addr, ins) in cpuinfo[:instrs]
                haskey(instrtocontrollers, ins) || (instrtocontrollers[ins] = Dict())
                haskey(instrtocontrollers[ins], addr) || (instrtocontrollers[ins][addr] = [])
            end
            for (ins, inses) in instrtocontrollers
                hasct = !isempty(inses) && (|)(.!isempty.(values(inses))...)
                hasct && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.DAQTaskRunning)
                insnode = CImGui.TreeNode(ins)
                hasct && CImGui.PopStyleColor()
                if insnode
                    for (addr, cts) in inses
                        hasct = !isempty(cts)
                        haskey(cpuinfo[:taskbusy], addr) || continue
                        busyct = cpuinfo[:taskbusy][addr]
                        hasct && CImGui.PushStyleColor(
                            CImGui.ImGuiCol_Text,
                            busyct ? MORESTYLE.Colors.WarnText : MORESTYLE.Colors.DAQTaskRunning
                        )
                        addrnode = CImGui.TreeNode(addr)
                        hasct && CImGui.PopStyleColor()
                        if addrnode
                            CImGui.PushID(stcstr(ins, addr))
                            CImGui.TextColored(
                                cpuinfo[:isconnected][addr] ? MORESTYLE.Colors.InfoText : MORESTYLE.Colors.ErrorText,
                                mlstr(cpuinfo[:isconnected][addr] ? "Connected" : "Unconnected")
                            )
                            if !cpuinfo[:isconnected][addr]
                                CImGui.SameLine()
                                CImGui.Button(mlstr("Connect")) && remote_connect!(addr)
                                CImGui.SameLine()
                            end
                            CImGui.SameLine()
                            igBeginDisabled(SYNCSTATES[IsDAQTaskRunning] && hasct)
                            CImGui.Button(mlstr("Log Out")) && remote_logout!(addr)
                            igEndDisabled()
                            CImGui.Text(stcstr(mlstr("Status"), mlstr(": ")))
                            CImGui.SameLine()
                            CImGui.TextColored(
                                cpuinfo[:taskhandlers][addr] ? MORESTYLE.Colors.InfoText : MORESTYLE.Colors.ErrorText,
                                mlstr(cpuinfo[:taskhandlers][addr] ? "Running" : "Stopped")
                            )
                            CImGui.SameLine()
                            ColoredButton(
                                mlstr(cpuinfo[:tasksfailed][addr] ? "Failed" : cpuinfo[:taskbusy][addr] ? "Busy" : "Well");
                                colbt=if cpuinfo[:tasksfailed][addr]
                                    MORESTYLE.Colors.ErrorBg
                                else
                                    cpuinfo[:taskbusy][addr] ? MORESTYLE.Colors.WarnBg : MORESTYLE.Colors.InfoBg
                                end
                            ) && (cpuinfo[:taskbusy][addr] ? remote_unsetbusy!(addr) : remote_setbusy!(addr))
                            for ct in cts
                                idx = findfirst(==(ct), cpuinfo[:controllers])
                                CImGui.PushID(idx)
                                CImGui.BulletText(stcstr(mlstr("Controller"), " ", idx))
                                #vec 模式槽位缓冲对用户透明,仅展示基本参数
                                CImGui.Text(stcstr(mlstr("Busy Timeout"), mlstr(": "), ct.busytimeout, " s"))
                                CImGui.PopID()
                            end
                            CImGui.PopID()
                            CImGui.TreePop()
                        end
                    end
                    CImGui.TreePop()
                end
            end
        end
    end

    refreshtask::Dict{String,Task} = Dict()
    function refreshcpuinfo()
        task = if haskey(refreshtask, "task")
            refreshtask["task"]
        else
            refreshtask["task"] = @async remote_getcpuinfo()
        end
        if istaskdone(task)
            cpuinfofetch = istaskfailed(task) ? nothing : fetch(task)
            if !isnothing(cpuinfofetch)
                merge!(cpuinfo, cpuinfofetch)
                lastrefreshtime = string(now())
            end
            delete!(refreshtask, "task")
            dorender(6)
        end
    end
end