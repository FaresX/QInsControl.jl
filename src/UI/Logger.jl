let
    firsttime::Bool = true
    logmsgshow = Tuple{CImGui.LibCImGui.ImVec4,String}[]
    global function LogWindow(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin(
            stcstr(MORESTYLE.Icons.Logger, "  ", mlstr("Logger"), "###logger"),
            p_open,
            CImGui.ImGuiWindowFlags_HorizontalScrollbar
        )
            SetWindowBgImage()
            if SYNCSTATES[Int(NewLogging)] || waittime("Logger", CONF.Logs.refreshrate)
                empty!(logmsgshow)
                textc = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
                markerlist = ["┌ Info", "┌ Warning", "┌ Error"]
                date = today()
                logdir = joinpath(CONF.Logs.dir, string(year(date)), string(year(date), "-", month(date)))
                isdir(logdir) || mkpath(logdir)
                logfile = joinpath(logdir, string(date, ".log"))
                isfile(logfile) || open(file -> write(file, ""), logfile, "w")
                allmsg::Vector{String} = string.(split(read(logfile, String), '\n'))
                limitline::Int = length(allmsg) > CONF.Logs.showlogline ? CONF.Logs.showlogline : length(allmsg)
                logmsg = ""
                for (i, s) in enumerate(allmsg[end-limitline+1:end])
                    occursin(markerlist[1], s) && (textc = ImVec4(MORESTYLE.Colors.LogInfo...))
                    occursin(markerlist[2], s) && (textc = ImVec4(MORESTYLE.Colors.LogWarn...))
                    occursin(markerlist[3], s) && (textc = ImVec4(MORESTYLE.Colors.LogError...))
                    length(s) > CONF.Logs.showloglength && (s = s[1:CONF.Logs.showloglength])
                    if occursin("└", s)
                        logmsg *= @sprintf "%-8d%s\n\n" i s
                        push!(logmsgshow, (textc, logmsg))
                        textc = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
                        logmsg = ""
                    else
                        logmsg *= @sprintf "%-8d%s\n" i s
                        i == limitline && push!(logmsgshow, (textc, logmsg))
                    end
                end
            end
            CImGui.BeginChild("WrapIOs")
            for (col, msg) in logmsgshow
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, col)
                CImGui.PushTextWrapPos(0)
                CImGui.TextUnformatted(msg)
                CImGui.PopTextWrapPos()
                CImGui.PopStyleColor()
            end
            SYNCSTATES[Int(NewLogging)] && (CImGui.SetScrollHereY(1); SYNCSTATES[Int(NewLogging)] = false)
            firsttime && (CImGui.SetScrollHereY(1); firsttime = false)
            CImGui.EndChild()
        end
        CImGui.End()
        p_open.x || (firsttime = true)
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
                    isempty(rstrip(s)) || (msgsp[i] = string("from worker $(myid()): ", msgsp[i], '\n'))
                end
                write(file, string(msgsp...))
            end
            syncstates[Int(NewLogging)] = true
        end
    end
end