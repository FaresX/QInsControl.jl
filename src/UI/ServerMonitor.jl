let
    serverbuffer::QICServer = QICServer()
    showmsg::Dict{String,Bool} = Dict()
    shownewest::Bool = true
    global function ServerMonitor()
        refreshserverbuffer()
        CImGui.SeparatorText(lastrefreshtime)
        @c(CImGui.DragInt(
            mlstr("port"),
            &CONF.Server.port,
            1.0, 1, 65535, "%d",
            CImGui.ImGuiSliderFlags_AlwaysClamp
        )) && timed_remotecall_wait(x -> (CONF.Server.port = x), workers()[1], CONF.Server.port)
        @c(CImGui.DragInt(
            mlstr("max clients"),
            &CONF.Server.maxclients,
            1.0, 1, 128, "%d",
            CImGui.ImGuiSliderFlags_AlwaysClamp
        )) && timed_remotecall_wait(workers()[1], CONF.Server.maxclients) do x
            QICSERVER.maxclients = CONF.Server.maxclients = x
        end
        @c(CImGui.DragInt(
            mlstr("buffer size"),
            &CONF.Server.buflen,
            1.0, 4, 4096, "%d",
            CImGui.ImGuiSliderFlags_AlwaysClamp
        )) && timed_remotecall_wait(x -> (QICSERVER.buflen = CONF.Server.buflen = x), workers()[1], CONF.Server.buflen)
        if ToggleButton(mlstr(serverbuffer.running ? "Running" : "Stopped"), Ref(serverbuffer.running))
            timed_remotecall_wait(running -> running ? stop!(QICSERVER) : start!(QICSERVER), workers()[1], serverbuffer.running)
        end
        CImGui.SameLine()
        if @c CImGui.Checkbox(mlstr(serverbuffer.fast ? "Fast Mode" : "Slow Mode"), &serverbuffer.fast)
            timed_remotecall_wait(isfast -> (QICSERVER.fast = isfast), workers()[1], serverbuffer.fast)
        end
        CImGui.SameLine(0, CImGui.GetFontSize())
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, string(serverbuffer.port))
        manageclients()
    end

    global function manageclients(; clientline=4, simplifiedmsg=true)
        simplifiedmsg || @c CImGui.Checkbox(mlstr("Newest Message"), &shownewest)
        CImGui.BeginChild("Clients Table", (Cfloat(0), clientline * CImGui.GetFrameHeightWithSpacing()))
        if CImGui.BeginTable(
            "Clients Table", 3,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
        )
            CImGui.TableSetupScrollFreeze(0, 1)
            CImGui.TableSetupColumn(mlstr("IP Address"))
            CImGui.TableSetupColumn(mlstr("Port"))
            CImGui.TableSetupColumn("")
            CImGui.TableHeadersRow()

            for client in serverbuffer.clients
                CImGui.TableNextRow()

                CImGui.TableSetColumnIndex(0)
                CImGui.Text(string(client.addr))

                CImGui.TableSetColumnIndex(1)
                CImGui.Text(string(client.port))

                CImGui.TableSetColumnIndex(2)
                addrstr = stcstr(client.addr, ":", client.port)
                haskey(showmsg, addrstr) || (showmsg[addrstr] = true)
                CImGui.Checkbox(stcstr("##", addrstr), Ref(showmsg[addrstr])) && (showmsg[addrstr] = !showmsg[addrstr])
                CImGui.SameLine()
                client.connected || CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ErrorText)
                if CImGui.Button(stcstr(MORESTYLE.Icons.Delete, "##", client.addr, ":", client.port))
                    timed_remotecall_wait(workers()[1], client.addr, client.port) do addr, port
                        for c in QICSERVER.clients
                            if string(c.addr) == string(addr) && c.port == port
                                c.connected = false
                                break
                            end
                        end
                    end
                end
                client.connected || CImGui.PopStyleColor()
            end
            CImGui.EndTable()
        end
        CImGui.EndChild()
        if CImGui.BeginTable(
            "Server Buffer Table", simplifiedmsg ? 2 : 4,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
        )
            CImGui.TableSetupScrollFreeze(0, 1)
            CImGui.TableSetupColumn(mlstr("DateTime"))
            simplifiedmsg || CImGui.TableSetupColumn(mlstr("Address"))
            CImGui.TableSetupColumn(mlstr("Command"))
            simplifiedmsg || CImGui.TableSetupColumn(mlstr("Action"))
            CImGui.TableHeadersRow()

            allmsg = vcat([client.buffer for client in serverbuffer.clients if showmsg[stcstr(client.addr, ":", client.port)]]...)
            dates = [msg[1] for msg in allmsg]
            sp = sortperm(dates)
            for (date, addr, cmd, action) in allmsg[sp]
                CImGui.TableNextRow()

                CImGui.TableSetColumnIndex(0)
                CImGui.Text(string(simplifiedmsg ? Time(date) : date))

                CImGui.TableSetColumnIndex(1)
                CImGui.Text(simplifiedmsg ? cmd : addr)

                if !simplifiedmsg
                    CImGui.TableSetColumnIndex(2)
                    CImGui.Text(cmd)

                    CImGui.TableSetColumnIndex(3)
                    CImGui.Text(action)
                end
            end
            if serverbuffer.newmsg
                shownewest && CImGui.SetScrollHereY(1)
                timed_remotecall_wait(() -> QICSERVER.newmsg = false, workers()[1])
            end
            CImGui.EndTable()
        end
    end

    refreshtask::Dict{String,Task} = Dict()
    lastrefreshtime::String = string(now())
    global function refreshserverbuffer()
        task = if haskey(refreshtask, "task")
            refreshtask["task"]
        else
            refreshtask["task"] = @async timed_remotecall_fetch(() -> QICSERVER, workers()[1]; timeout=1, quiet=true)
        end
        if istaskdone(task)
            serverfetch = istaskfailed(task) ? nothing : fetch(task)
            isnothing(serverfetch) || (serverbuffer = serverfetch; lastrefreshtime = string(now()))
            delete!(refreshtask, "task")
        end
    end
end