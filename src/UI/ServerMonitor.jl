let
    serverbuffer::QICServer = QICServer()
    global function ServerMonitor()
        refreshserverbuffer()
        @c(CImGui.DragInt(
            mlstr("port"),
            &CONF.Server.port,
            1.0, 1, 65535, "%d",
            CImGui.ImGuiSliderFlags_AlwaysClamp
        )) && timed_remotecall_wait(x -> (CONF.Server.port = x), workers()[1], CONF.Server.port)
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
        CImGui.SameLine()
        CImGui.Text(string(serverbuffer.port))
        CImGui.BeginChild("Clients Table", (Cfloat(0), 6CImGui.GetFrameHeight()))
        if CImGui.BeginTable(
            "Clients Table", 2,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
        )
            CImGui.TableSetupScrollFreeze(0, 1)
            CImGui.TableSetupColumn(mlstr("IP Address"), CImGui.ImGuiTableColumnFlags_WidthFixed, 8CImGui.GetFontSize())
            CImGui.TableSetupColumn(mlstr("Port"), CImGui.ImGuiTableColumnFlags_WidthStretch)
            CImGui.TableHeadersRow()

            @lock serverbuffer.clients for (ip, port) in serverbuffer.clients[]
                CImGui.TableNextRow()

                CImGui.TableSetColumnIndex(0)
                CImGui.Text(string(ip))

                CImGui.TableSetColumnIndex(1)
                CImGui.Text(string(port))
            end
            CImGui.EndTable()
        end
        CImGui.EndChild()
        if CImGui.BeginTable(
            "Server Buffer Table", 2,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
        )
            CImGui.TableSetupScrollFreeze(0, 1)
            CImGui.TableSetupColumn(mlstr("DateTime"), CImGui.ImGuiTableColumnFlags_WidthFixed, 6CImGui.GetFontSize())
            CImGui.TableSetupColumn(mlstr("Message"), CImGui.ImGuiTableColumnFlags_WidthStretch)
            CImGui.TableHeadersRow()

            @lock serverbuffer.buffer for (date, _, _, msg) in serverbuffer.buffer[]
                CImGui.TableNextRow()

                CImGui.TableSetColumnIndex(0)
                CImGui.Text(string(Time(date)))

                CImGui.TableSetColumnIndex(1)
                CImGui.Text(msg)
            end
            if serverbuffer.newmsg
                CImGui.SetScrollHereY(1)
                timed_remotecall_wait(() -> QICSERVER.newmsg = false, workers()[1])
            end
            CImGui.EndTable()
        end
    end

    function refreshserverbuffer()
        serverfetch = timed_remotecall_fetch(() -> QICSERVER, workers()[1]; timeout=0.03, quiet=true)
        isnothing(serverfetch) || (serverbuffer = serverfetch)
    end
end