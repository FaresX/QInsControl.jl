let
    cpuinfo::Dict = Dict()
    lastrefreshtime::String = string(now())
    global function CPUMonitor()
        refreshcpuinfo()
        CImGui.SeparatorText(lastrefreshtime)
        isempty(cpuinfo) && return nothing
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Processor"))
        CImGui.Indent()
        if cpuinfo[:running]
            igBeginDisabled(SYNCSTATES[Int(IsDAQTaskRunning)] || SYNCSTATES[Int(IsAutoRefreshing)])
            ToggleButton(mlstr("Running"), Ref(true)) && timed_remotecall_wait(() -> stop!(CPU), workers()[1])
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
                timed_remotecall_wait((isfast) -> CPU.fast[] = !isfast, workers()[1], cpuinfo[:fast])
            end
        else
            ToggleButton(mlstr("Stopped"), Ref(false)) && timed_remotecall_wait(() -> start!(CPU), workers()[1])
        end
        CImGui.Unindent()
        CImGui.Spacing()
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Controllers"))
        CImGui.Indent()
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
                                CImGui.Button(mlstr("Connect")) && timed_remotecall_wait(workers()[1], addr) do addr
                                    @trycatch mlstr("connection failded!!!") QInsControlCore.connect!(
                                        CPU.resourcemanager[], CPU.instrs[addr]
                                    )
                                end
                                CImGui.SameLine()
                            end
                            CImGui.SameLine()
                            igBeginDisabled(SYNCSTATES[Int(IsDAQTaskRunning)] && hasct)
                            CImGui.Button(mlstr("Log Out")) && timed_remotecall_wait(addr -> logout!(CPU, addr), workers()[1], addr)
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
                            ) && timed_remotecall_wait(workers()[1], cpuinfo[:taskbusy][addr], addr) do busy, addr
                                busy ? unsetbusy!(CPU, addr) : setbusy!(CPU, addr)
                            end
                            for ct in cts
                                idx = findfirst(==(ct), cpuinfo[:controllers])
                                CImGui.PushID(idx)
                                CImGui.BulletText(stcstr(mlstr("Controller"), " ", idx))
                                @cstatic cols::Cint = 2 begin
                                    CImGui.PushItemWidth(6CImGui.GetFontSize())
                                    @c CImGui.DragInt(mlstr("Buffer"), &cols, 1, 1, 64, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                                    CImGui.PopItemWidth()
                                    CImGui.BeginTable(stcstr("Controller", idx), cols, CImGui.ImGuiTableFlags_Borders)
                                    for idxes in Iterators.partition(eachindex(ct.databuf), cols)
                                        CImGui.TableNextRow()
                                        for i in idxes
                                            CImGui.TableSetColumnIndex((i - 1) % cols)
                                            CImGui.Text(ct.databuf[i])
                                            ct.available[i] || CImGui.TableSetBgColor(
                                                CImGui.ImGuiTableBgTarget_CellBg,
                                                CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.ErrorBg)
                                            )
                                        end
                                    end
                                    CImGui.EndTable()
                                end
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
        CImGui.Unindent()
    end

    refreshtask::Dict{String,Task} = Dict()
    function refreshcpuinfo()
        task = if haskey(refreshtask, "task")
            refreshtask["task"]
        else
            refreshtask["task"] = @async timed_remotecall_fetch(workers()[1]; timeout=1, quiet=true) do
                lock(CPU.lock) do
                    Dict(
                        :running => CPU.running[],
                        :taskfailed => istaskfailed(CPU.processtask[]),
                        :fast => CPU.fast[],
                        :resourcemanager => CPU.resourcemanager[],
                        :instrs => Dict(ins.addr => ins.name for ins in values(CPU.instrs)),
                        :isconnected => Dict(addr => QInsControlCore.isconnected(instr) for (addr, instr) in CPU.instrs),
                        :controllers => CPU.controllers,
                        :taskhandlers => CPU.taskhandlers,
                        :taskbusy => CPU.taskbusy,
                        :tasksfailed => Dict(addr => istaskfailed(task) for (addr, task) in CPU.tasks)
                    )
                end
            end
        end
        if istaskdone(task)
            cpuinfofetch = istaskfailed(task) ? nothing : fetch(task)
            if !isnothing(cpuinfofetch)
                empty!(cpuinfo)
                merge!(cpuinfo, cpuinfofetch)
                lastrefreshtime = string(now())
            end
            delete!(refreshtask, "task")
        end
    end
end