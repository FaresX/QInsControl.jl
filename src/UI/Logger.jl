let
    firsttime::Bool = true
    logmsgshow = Tuple{CImGui.LibCImGui.ImVec4,String}[]
    global function LogWindow(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin(morestyle.Icons.Logger * "  日志", p_open, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
            if waittime("Logger", conf.Logs.refreshrate)
                empty!(logmsgshow)
                textc = CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
                markerlist = ["┌ Info", "┌ Warning", "┌ Error"]
                date = today()
                logdir = joinpath(conf.Logs.dir, string(year(date)), string(year(date), "-", month(date)))
                isdir(logdir) || mkpath(logdir)
                logfile = joinpath(logdir, string(date, ".log"))
                isfile(logfile) || open(file -> write(file, ""), logfile, "w")
                allmsg::Vector{String} = string.(split(read(logfile, String), '\n'))
                limitline::Int = length(allmsg) > conf.Logs.showlogline ? conf.Logs.showlogline : length(allmsg)
                logmsg = ""
                for (i, s) in enumerate(allmsg[end-limitline+1:end])
                    occursin(markerlist[1], s) && (textc = ImVec4(morestyle.Colors.LogInfo...))
                    occursin(markerlist[2], s) && (textc = ImVec4(morestyle.Colors.LogWarn...))
                    occursin(markerlist[3], s) && (textc = ImVec4(morestyle.Colors.LogError...))
                    if occursin("└", s)
                        logmsg *= @sprintf "%-8d%s\n\n" i s
                        push!(logmsgshow, (textc, logmsg))
                        textc = CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
                        logmsg = ""
                    else
                        logmsg *= @sprintf "%-8d%s\n" i s
                        i == limitline && push!(logmsgshow, (textc, logmsg))
                    end
                end
            end
            CImGui.BeginChild("WrapLog")
            for (col, msg) in logmsgshow
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, col)
                CImGui.PushTextWrapPos(0)
                CImGui.TextUnformatted(msg)
                CImGui.PopTextWrapPos()
                CImGui.PopStyleColor()
            end
            firsttime && (CImGui.SetScrollHereY(1); firsttime = false)
            CImGui.EndChild()
        end
        CImGui.End()
        p_open.x || (firsttime = true)
    end
end