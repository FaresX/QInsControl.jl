let
    buffer::String = ""
    historyins::Vector{String} = [""]
    historyins_i::Int = 1
    iomsgshow = Tuple{CImGui.LibCImGui.ImVec4,String}[]
    iofile::String = ""
    newmsg::Bool = true
    newmsg_updated::Bool = false
    global function ShowConsole(p_open::Ref{Bool})
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((600, 400), CImGui.ImGuiCond_Once)
        if CImGui.Begin(stcstr(morestyle.Icons.Console, "  控制台"), p_open)
            if newmsg || waittime("Console", conf.Console.refreshrate)
                empty!(iomsgshow)
                textc = CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
                markerlist = ["[IN Begin]", "[OUT Begin]"]
                date = today()
                iodir = joinpath(conf.Console.dir, string(year(date)), string(year(date), "-", month(date)))
                isdir(iodir) || mkpath(iodir)
                iofile = joinpath(iodir, string(date, ".out"))
                isfile(iofile) || open(file -> write(file, ""), iofile, "w")
                allmsg::Vector{String} = string.(split(read(iofile, String), '\n'))
                limitline::Int = length(allmsg) > conf.Console.showioline ? conf.Console.showioline : length(allmsg)
                iomsg = ""
                isinblock = false
                for (i, s) in enumerate(allmsg[end-limitline+1:end])
                    occursin(markerlist[1], s) && (textc = ImVec4(morestyle.Colors.HighlightText...))
                    occursin(markerlist[2], s) && (textc = ImVec4(morestyle.Colors.LogInfo...))
                    if occursin("[End]", s)
                        isinblock || (iomsg *= "\n")
                        push!(iomsgshow, (textc, iomsg))
                        textc = CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
                        iomsg = ""
                    elseif occursin(markerlist[1], s)
                        iomsg *= "IN:\n"
                        isinblock = true
                    elseif occursin(markerlist[2], s)
                        iomsg *= "OUT:\n"
                        isinblock = false
                    else
                        rstrip(s, ' ') == "" && continue
                        iomsg *= string("\t\t\t", s, "\n")
                        i == limitline && push!(iomsgshow, (textc, iomsg))
                    end
                end
                newmsg && (newmsg_updated = true; newmsg = false)
            end
            lineheigth = (1 + length(findall('\n', buffer))) * CImGui.GetTextLineHeight() + 2unsafe_load(imguistyle.FramePadding.y)
            CImGui.BeginChild("STD OUT", (Float32(0), -lineheigth - unsafe_load(imguistyle.ItemSpacing.y)))
            for (col, msg) in iomsgshow
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, col)
                CImGui.PushTextWrapPos(0)
                CImGui.TextUnformatted(msg)
                CImGui.PopTextWrapPos()
                CImGui.PopStyleColor()
            end
            newmsg_updated && (CImGui.SetScrollHereY(1); newmsg_updated = false)
            CImGui.EndChild()
            @c InputTextMultilineRSZ("输入", &buffer, (Cfloat(0), lineheigth))
            if CImGui.IsItemHovered() && !CImGui.IsItemActive()
                if CImGui.IsKeyPressed(265)
                    historyins_i < length(historyins) && (historyins_i += 1)
                    buffer = historyins[historyins_i]
                elseif CImGui.IsKeyPressed(264)
                    historyins_i > 0 && (historyins_i -= 1)
                    buffer = historyins_i == 0 ? "" : historyins[historyins_i]
                end
            end
            CImGui.SameLine()
            if CImGui.Button(stcstr(morestyle.Icons.SendMsg, " 发送")) ||
               ((CImGui.IsKeyDown(341) || CImGui.IsKeyDown(345)) && (CImGui.IsKeyDown(257) || CImGui.IsKeyDown(335)))
                if buffer != ""
                    iofile_open = open(iofile, "a+")
                    try
                        write(iofile_open, "\n[IN Begin]$(now())\n")
                        write(iofile_open, buffer)
                        write(iofile_open, "\n[End]\n")
                        write(iofile_open, "\n[OUT Begin]\n")
                        try
                            redirect_stdout(iofile_open) do
                                codes = Meta.parseall(buffer)
                                @eval Main print($codes)
                            end
                        catch e
                            @error exception = e
                        end
                        write(iofile_open, "\n[End]\n")
                    catch e
                        @error exception = e
                    finally
                        flush(iofile_open)
                        close(iofile_open)
                    end
                    if buffer ∉ historyins
                        if length(historyins) == conf.Console.historylen
                            push!(historyins, buffer)
                            popfirst!(historyins)
                        else
                            push!(historyins, buffer)
                        end
                    end
                    historyins_i = 1
                    buffer = ""
                    newmsg = true
                end
            end
            CImGui.SameLine()
            if CImGui.Button(ICONS.ICON_CARET_LEFT)
                historyins_i > 0 && (historyins_i -= 1)
                buffer = historyins_i == 0 ? "" : historyins[historyins_i]
            end
            CImGui.SameLine()
            if CImGui.Button(ICONS.ICON_CARET_RIGHT)
                historyins_i < length(historyins) && (historyins_i += 1)
                buffer = historyins[historyins_i]
            end
        end
        CImGui.End()
    end
end