let
    firsttime::Bool = true
    logmsgshow = Tuple{String,String,String,CImGui.lib.ImVec4,Ref{Bool},String}[]
    showinfo::Bool = true
    showwarn::Bool = true
    showerror::Bool = true
    showstacktrace::Bool = false
    expandall::Bool = false
    serverbuffer::QICServer = QICServer()
    global function LogWindow(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin(
            stcstr(MORESTYLE.Icons.Logger, "  ", mlstr("Logger"), "###logger"),
            p_open,
            CImGui.ImGuiWindowFlags_HorizontalScrollbar
        )
            SetWindowBgImage(CONF.BGImage.logger.path; rate=CONF.BGImage.logger.rate, use=CONF.BGImage.logger.use)
            if SYNCSTATES[Int(NewLogging)] || waittime("Logger", CONF.Logs.refreshrate)
                empty!(logmsgshow)
                textbg = ImVec4(0, 0, 0, 0)
                texttype = "Info"
                markerlist = ["┌ Info", "┌ Warning", "┌ Error", "Stacktrace:"]
                date = today()
                logdir = joinpath(CONF.Logs.dir, string(year(date)), string(year(date), "-", month(date)))
                isdir(logdir) || mkpath(logdir)
                logfile = joinpath(logdir, string(date, ".log"))
                isfile(logfile) || open(file -> write(file, ""), logfile, "w")
                allmsg::Vector{String} = string.(split(read(logfile, String), '\n'))
                limitline::Int = length(allmsg) > CONF.Logs.showlogline ? CONF.Logs.showlogline : length(allmsg)
                logmsg = ""
                for (i, s) in enumerate(allmsg[end-limitline+1:end])
                    occursin(markerlist[1], s) && (textbg = ImVec4(MORESTYLE.Colors.InfoBg...); texttype = "Info")
                    occursin(markerlist[2], s) && (textbg = ImVec4(MORESTYLE.Colors.WarnBg...); texttype = "Warn")
                    occursin(markerlist[3], s) && (textbg = ImVec4(MORESTYLE.Colors.ErrorBg...); texttype = "Error")
                    occursin(markerlist[4], s) && (textbg = ImVec4(MORESTYLE.Colors.ErrorBg...); texttype = "Stacktrace")
                    length(s) > CONF.Logs.showloglength && (s = s[1:CONF.Logs.showloglength])
                    if occursin("└", s) || s == "\r"
                        logmsg *= @sprintf "%-8d%s\n\n" i s
                        matchdate = match(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3})", logmsg)
                        date = isnothing(matchdate) ? "none" : matchdate[1]
                        strs = split(logmsg, "\n")
                        n = min(length(strs), 3)
                        title = n == 0 ? "none" : join(strs[1:n], "\n")
                        push!(logmsgshow, (texttype, date, title, textbg, false, logmsg))
                        textbg = ImVec4(0, 0, 0, 0)
                        texttype = "Info"
                        logmsg = ""
                    else
                        logmsg *= @sprintf "%-8d%s\n" i s
                        matchdate = match(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3})", logmsg)
                        date = isnothing(matchdate) ? "none" : matchdate[1]
                        strs = split(logmsg, "\n")
                        n = min(length(strs), 3)
                        title = n == 0 ? "none" : join(strs[1:n], "\n")
                        i == limitline && push!(logmsgshow, (texttype, date, title, textbg, false, logmsg))
                    end
                end
            end
            if CImGui.BeginTabBar("Logging")
                if CImGui.BeginTabItem(mlstr("System Logs"))
                    @c(CImGui.Checkbox(mlstr("Info"), &showinfo)) && (SYNCSTATES[Int(NewLogging)] = true)
                    CImGui.SameLine()
                    @c(CImGui.Checkbox(mlstr("Warn"), &showwarn)) && (SYNCSTATES[Int(NewLogging)] = true)
                    CImGui.SameLine()
                    @c(CImGui.Checkbox(mlstr("Error"), &showerror)) && (SYNCSTATES[Int(NewLogging)] = true)
                    CImGui.SameLine()
                    @c(CImGui.Checkbox(mlstr("Stacktrace"), &showstacktrace)) && (SYNCSTATES[Int(NewLogging)] = true)
                    CImGui.SameLine()
                    @c(CImGui.Checkbox(mlstr("Expand All"), &expandall))
                    igSeparatorText("")

                    if CImGui.BeginTable(
                        "LogTable", 3,
                        CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
                    )
                        CImGui.TableSetupScrollFreeze(0, 1)
                        CImGui.TableSetupColumn(mlstr("Type"), CImGui.ImGuiTableColumnFlags_WidthFixed, 4CImGui.GetFontSize())
                        CImGui.TableSetupColumn(mlstr("Date"), CImGui.ImGuiTableColumnFlags_WidthFixed, 12CImGui.GetFontSize())
                        CImGui.TableSetupColumn(mlstr("Message"), CImGui.ImGuiTableColumnFlags_WidthStretch)
                        CImGui.TableHeadersRow()

                        for (type, date, title, col, expanded, msg) in logmsgshow
                            !showinfo && type == "Info" && continue
                            !showwarn && type == "Warn" && continue
                            !showerror && type == "Error" && continue
                            !showstacktrace && type == "Stacktrace" && continue
                            CImGui.TableNextRow()
                            CImGui.TableSetBgColor(CImGui.ImGuiTableBgTarget_RowBg0, CImGui.ColorConvertFloat4ToU32(col))

                            CImGui.TableSetColumnIndex(0)
                            CImGui.Text(type)

                            CImGui.TableSetColumnIndex(1)
                            CImGui.Text(date)

                            CImGui.TableSetColumnIndex(2)
                            CImGui.PushTextWrapPos(0)
                            CImGui.TextUnformatted(expandall || expanded[] ? msg : title)
                            CImGui.PopTextWrapPos()
                            CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (expanded[] = !expanded[])
                        end
                        SYNCSTATES[Int(NewLogging)] && (CImGui.SetScrollHereY(1); SYNCSTATES[Int(NewLogging)] = false)
                        firsttime && (CImGui.SetScrollHereY(1); firsttime = false)
                        CImGui.EndTable()
                    end
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem(mlstr("Server Logs"))
                    refreshserverbuffer()
                    if CImGui.BeginTable(
                        "Server Buffer Table", 4,
                        CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
                    )
                        CImGui.TableSetupScrollFreeze(0, 1)
                        CImGui.TableSetupColumn(mlstr("DateTime"), CImGui.ImGuiTableColumnFlags_WidthFixed, 12CImGui.GetFontSize())
                        CImGui.TableSetupColumn(mlstr("IP Address"), CImGui.ImGuiTableColumnFlags_WidthFixed, 6CImGui.GetFontSize())
                        CImGui.TableSetupColumn(mlstr("Port"), CImGui.ImGuiTableColumnFlags_WidthFixed, 4CImGui.GetFontSize())
                        CImGui.TableSetupColumn(mlstr("Message"), CImGui.ImGuiTableColumnFlags_WidthStretch)
                        CImGui.TableHeadersRow()

                        @lock serverbuffer.buffer for (date, ip, port, msg) in serverbuffer.buffer[]
                            CImGui.TableNextRow()

                            CImGui.TableSetColumnIndex(0)
                            CImGui.Text(string(date))

                            CImGui.TableSetColumnIndex(1)
                            CImGui.Text(string(ip))

                            CImGui.TableSetColumnIndex(2)
                            CImGui.Text(string(port))

                            CImGui.TableSetColumnIndex(3)
                            CImGui.Text(msg)
                        end
                        if serverbuffer.newmsg
                            CImGui.SetScrollHereY(1)
                            timed_remotecall_wait(() -> QICSERVER.newmsg = false, workers()[1])
                        end
                        CImGui.EndTable()
                    end
                    CImGui.EndTabItem()
                end
                CImGui.EndTabBar()
            end
        end
        CImGui.End()
        p_open.x || (firsttime = true)
    end
    function refreshserverbuffer()
        serverfetch = timed_remotecall_fetch(() -> QICSERVER, workers()[1]; timeout=0.03, quiet=true)
        isnothing(serverfetch) || (serverbuffer = serverfetch)
    end
end

function update_log(syncstates=SYNCSTATES)
    date = today()
    logdir = joinpath(CONF.Logs.dir, string(year(date)), string(year(date), "-", month(date)))
    isdir(logdir) || mkpath(logdir)
    logfile = joinpath(logdir, string(date, ".log"))
    if myid() == 1
        flush(LOGIO)
        msg = String(take!(LOGIO))
        isempty(msg) || (open(file -> write(file, msg), logfile, "a+"); syncstates[Int(NewLogging)] = true)
    else
        flush(LOGIO)
        msg = String(take!(LOGIO))
        if !isempty(msg)
            open(logfile, "a+") do file
                msgsp = split(msg, '\n')
                for (i, s) in enumerate(msgsp)
                    s == "" && (msgsp[i] = "\n")
                    s == "\r" && (msgsp[i] = "\n\r")
                    isempty(rstrip(s)) || (msgsp[i] = string("from worker $(myid()): ", msgsp[i], '\n'))
                end
                write(file, string(msgsp...))
            end
            syncstates[Int(NewLogging)] = true
        end
    end
end