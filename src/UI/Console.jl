let
    buffer::String = ""
    historycmd::LoopVector{String} = LoopVector([""])
    historycmd_max::Int = 0
    iomsgshow = Tuple{CImGui.lib.ImVec4,String}[]
    iofile::String = ""
    newmsg::Bool = true
    newmsg_updated::Bool = false
    global function ShowConsole(p_open::Ref{Bool})
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((600, 400), CImGui.ImGuiCond_Once)
        if CImGui.Begin(stcstr(MORESTYLE.Icons.Console, "  ", mlstr("Console"), "###console"), p_open)
            SetWindowBgImage(CONF.BGImage.console.path; rate=CONF.BGImage.console.rate, use=CONF.BGImage.console.use)
            if length(historycmd) != CONF.Console.historylen
                resize!(historycmd.data, CONF.Console.historylen)
                fill!(historycmd.data, "")
            end
            if newmsg || waittime("Console", CONF.Console.refreshrate)
                empty!(iomsgshow)
                textc = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
                markerlist = ["[IN Begin]", "[OUT Begin]"]
                date = today()
                iodir = joinpath(CONF.Console.dir, string(year(date)), string(year(date), "-", month(date)))
                isdir(iodir) || mkpath(iodir)
                iofile = joinpath(iodir, string(date, ".out"))
                isfile(iofile) || open(file -> write(file, ""), iofile, "w")
                allmsg::Vector{String} = string.(split(read(iofile, String), '\n'))
                limitline::Int = length(allmsg) > CONF.Console.showioline ? CONF.Console.showioline : length(allmsg)
                iomsg = ""
                isinblock = false
                for (i, s) in enumerate(allmsg[end-limitline+1:end])
                    occursin(markerlist[1], s) && (textc = ImVec4(MORESTYLE.Colors.HighlightText...))
                    length(s) > CONF.Console.showiolength && (s = s[1:CONF.Console.showiolength])
                    if occursin("[End]", s)
                        isinblock || (iomsg *= "\n")
                        push!(iomsgshow, (textc, iomsg))
                        textc = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
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
            lineheigth = (1 + length(findall('\n', buffer))) * CImGui.GetTextLineHeight() +
                         2unsafe_load(IMGUISTYLE.FramePadding.y)
            CImGui.BeginChild("STD OUT", (Float32(0), -lineheigth - unsafe_load(IMGUISTYLE.ItemSpacing.y)))
            for (i, (col, msg)) in enumerate(iomsgshow)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, col)
                CImGui.PushTextWrapPos(0)
                CopyableText(
                    stcstr("##consolemsg", i), msg;
                    size=(Cfloat(-1), (1 + length(findall("\n", msg))) * CImGui.GetTextLineHeightWithSpacing())
                )
                CImGui.PopTextWrapPos()
                CImGui.PopStyleColor()
            end
            newmsg_updated && (CImGui.SetScrollHereY(1); newmsg_updated = false)
            CImGui.EndChild()
            @c InputTextMultilineRSZ("##input cmd", &buffer, (Cfloat(0), lineheigth))
            if CImGui.IsItemHovered() && !CImGui.IsItemActive()
                if CImGui.IsKeyReleased(ImGuiKey_UpArrow) && historycmd[-1] != ""
                    move!(historycmd, -1)
                    historycmd_max += 1
                    buffer = historycmd[]
                elseif CImGui.IsKeyReleased(ImGuiKey_DownArrow) && historycmd[1] != ""
                    move!(historycmd)
                    historycmd_max -= 1
                    buffer = historycmd[]
                end
            end
            CImGui.SameLine()
            if CImGui.Button(stcstr(MORESTYLE.Icons.SendMsg, " ", mlstr("Send"))) ||
               unsafe_load(CImGui.GetIO().KeyCtrl) && CImGui.IsKeyDown(ImGuiKey_Enter)
                if buffer != ""
                    writetoiofile(iofile, buffer)
                    move!(historycmd, historycmd_max)
                    historycmd[] = buffer
                    move!(historycmd)
                    historycmd_max = 0
                    buffer = ""
                    newmsg = true
                end
            end
            CImGui.SameLine()
            if CImGui.Button(ICONS.ICON_CARET_LEFT) && historycmd[-1] != ""
                move!(historycmd, -1)
                historycmd_max += 1
                buffer = historycmd[]
            end
            CImGui.SameLine()
            if CImGui.Button(ICONS.ICON_CARET_RIGHT) && historycmd[1] != ""
                move!(historycmd)
                historycmd_max -= 1
                buffer = historycmd[]
            end
        end
        CImGui.End()
    end
end

function writetoiofile(iofile, buffer)
    iofile_open = open(iofile, "a+")
    try
        write(iofile_open, "\n[IN Begin]$(now())\n")
        write(iofile_open, buffer)
        write(iofile_open, "\n[End]\n")
        write(iofile_open, "\n[OUT Begin]\n")
        @trycatch mlstr("error parsing codes") redirect_stdout(iofile_open) do
            codes = Meta.parseall(buffer)
            @eval Main print($codes)
        end
        write(iofile_open, "\n[End]\n")
    catch e
        @error string("[", now(), "]\n", mlstr("error writing to file")) exception = e
        showbacktrace()
    finally
        flush(iofile_open)
        close(iofile_open)
    end
end