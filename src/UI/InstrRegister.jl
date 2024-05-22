let
    edithelp::Bool = false
    global function edit(qtcf::QuantityConf, instrnm)
        @c InputTextRSZ(mlstr("alias"), &qtcf.alias)
        @c ComboS(mlstr("unit type"), &qtcf.U, keys(CONF.U))
        @c InputTextRSZ(mlstr("command"), &qtcf.cmdheader)
        width = CImGui.GetItemRectSize().x / 2 - 2CImGui.CalcTextSize(" =>  ").x
        CImGui.SameLine()
        if CImGui.Button(mlstr("Drivers"))
            driverfile = joinpath(ENV["QInsControlAssets"], "ExtraLoad/$instrnm.jl") |> abspath
            Threads.@spawn @trycatch mlstr("error editing text!!!") Base.run(Cmd([CONF.Basic.editor, driverfile]))
        end
        CImGui.SameLine()
        if CImGui.Button(MORESTYLE.Icons.InstrumentsManualRef)
            for file in readdir(joinpath(ENV["QInsControlAssets"], "ExtraLoad"), join=true)
                try
                    endswith(basename(file), ".jl") && remotecall_wait(include, workers()[1], file)
                catch e
                    @error mlstr("reloading drivers failed") exception = e file = file
                    showbacktrace()
                end
            end
        end
        # optkeys = join(qtcf.optkeys, "\n")
        # optvalues = join(qtcf.optvalues, "\n")
        # @c(InputTextRSZ("可选值", &optkeys)) && (qtcf.optkeys = split(optkeys, '\n'))
        # @c(InputTextRSZ("可选值", &optvalues)) && (qtcf.optvalues = split(optvalues, '\n'))
        CImGui.BeginGroup()

        CImGui.BeginGroup()
        for (i, key) in enumerate(qtcf.optkeys)
            CImGui.PushID(i)
            CImGui.PushItemWidth(width)
            if @c InputTextRSZ("##optkey", &key)
                key == "" || (qtcf.optkeys[i] = key)
            end
            CImGui.PopItemWidth()
            CImGui.SameLine()
            CImGui.Text(" => ")
            CImGui.SameLine()
            CImGui.PushItemWidth(width)
            val = qtcf.optvalues[i]
            if @c InputTextRSZ("##optvalue", &val)
                val == "" || (qtcf.optvalues[i] = val)
            end
            CImGui.PopItemWidth()
            CImGui.SameLine()
            CImGui.PushID("optvalue")
            if CImGui.Button(MORESTYLE.Icons.CloseFile)
                deleteat!(qtcf.optkeys, i)
                deleteat!(qtcf.optvalues, i)
                break
            end
            CImGui.PopID()
            CImGui.PopID()
        end
        CImGui.EndGroup()

        CImGui.EndGroup()
        CImGui.SameLine()
        CImGui.PushID("addopt")
        if CImGui.Button(MORESTYLE.Icons.NewFile)
            push!(qtcf.optkeys, string("key", length(qtcf.optkeys) + 1))
            push!(qtcf.optvalues, "")
        end
        CImGui.PopID()
        CImGui.SameLine()
        CImGui.Text(mlstr("optional values"))
        @c ComboS(mlstr("variable type"), &qtcf.type, ["sweep", "set", "read"])
        CImGui.PushItemWidth((CImGui.CalcItemWidth() - unsafe_load(IMGUISTYLE.ItemSpacing.x)) / 2)
        @c InputTextRSZ(mlstr("##separator"), &qtcf.separator)
        CImGui.SameLine()
        @c CImGui.DragInt(mlstr("separator"), &qtcf.numread, 1, 1, 36, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()
        CImGui.TextColored(MORESTYLE.Colors.LogInfo, mlstr("help document"))
        if edithelp
            lines = split(qtcf.help, '\n')
            x = CImGui.CalcTextSize(lines[argmax(lengthpr.(lines))]).x
            width = CImGui.GetContentRegionAvailWidth()
            x = x > width ? x : width
            y = (1 + length(findall("\n", qtcf.help))) * CImGui.GetTextLineHeight() + 2unsafe_load(IMGUISTYLE.FramePadding.y)
            CImGui.BeginChild("edit help", (Cfloat(0), y), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
            @c InputTextMultilineRSZ("##help doc", &qtcf.help, (x, y))
            !CImGui.IsItemHovered() && !CImGui.IsItemActive() && CImGui.IsMouseClicked(0) && (edithelp = false)
            CImGui.EndChild()
        else
            region = TextRect(replace(string(qtcf.help, "\n "), "\\\n" => ""); nochild=true)
            CImGui.IsMouseDoubleClicked(0) && mousein(region...) && (edithelp = true)
        end
    end
end

let
    firsttime::Bool = true
    selectedins::String = ""
    selectedqt::String = ""
    deldialog::Bool = false
    isrename::Dict{String,Bool} = Dict()
    qtname::String = ""
    editqt::QuantityConf = QuantityConf()
    default_insbufs = Dict{String,InstrBuffer}()
    global function InstrRegister(p_open::Ref)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)

        if CImGui.Begin(
            stcstr(MORESTYLE.Icons.InstrumentsRegister, "  ", mlstr("Instrument Registration"), "###ins reg"),
            p_open
        )
            SetWindowBgImage()
            CImGui.Columns(2)
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, MORESTYLE.Colors.ToolBarBg)
            CImGui.BeginChild("Toolbar")
            CImGui.PopStyleColor()
            CImGui.BeginChild("Instruments", (Cfloat(0), -2CImGui.GetFrameHeight() - 2unsafe_load(IMGUISTYLE.ItemSpacing.y)))
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            for (oldinsnm, inscf) in INSCONF
                oldinsnm == "Others" && continue
                haskey(isrename, oldinsnm) || (isrename[oldinsnm] = false)
                renamei = isrename[oldinsnm]
                CImGui.PushID(oldinsnm)
                newinsnm = oldinsnm
                CImGui.PushItemWidth(-1)
                if @c RenameSelectable(
                    "##RenameInsConf", &renamei, &newinsnm, selectedins == oldinsnm,
                    0, (Cfloat(0), 3CImGui.GetFrameHeight() / 2);
                    size2=(Cfloat(-1), 3CImGui.GetFrameHeight() / 2),
                    fixedlabel=stcstr(inscf.conf.icon, " ")
                )
                    selectedins = oldinsnm
                    selectedqt = ""
                end
                CImGui.PopItemWidth()
                if !(newinsnm == "" || haskey(INSCONF, newinsnm))
                    if isrename[oldinsnm] && !renamei
                        setvalue!(INSCONF, oldinsnm, newinsnm => inscf)
                        remotecall_wait(workers()[1], oldinsnm, newinsnm, inscf) do oldinsnm, newinsnm, inscf
                            setvalue!(INSCONF, oldinsnm, newinsnm => inscf)
                        end
                        INSTRBUFFERVIEWERS[newinsnm] = pop!(INSTRBUFFERVIEWERS, oldinsnm)
                        selectedins = newinsnm
                        isrename[newinsnm] = renamei
                    else
                        isrename[oldinsnm] = renamei
                    end
                else
                    isrename[oldinsnm] = renamei
                end
                if CImGui.BeginPopupContextItem()
                    CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"), "##INSCONF"),
                        C_NULL,
                        false,
                        oldinsnm ∉ ["VirtualInstr", "Others"]
                    ) && (deldialog = true)
                    CImGui.EndPopup()
                end
                if YesNoDialog(
                    stcstr("##if delete ins conf", oldinsnm),
                    mlstr("Confirm delete?"),
                    CImGui.ImGuiWindowFlags_AlwaysAutoResize
                )
                    pop!(INSCONF, oldinsnm, 0)
                    remotecall_wait(workers()[1], oldinsnm) do oldinsnm
                        pop!(INSCONF, oldinsnm, 0)
                    end
                    pop!(INSTRBUFFERVIEWERS, oldinsnm, 0)
                    selectedins = ""
                end
                deldialog && (CImGui.OpenPopup(stcstr("##if delete ins conf", oldinsnm));
                deldialog = false)
                CImGui.PopID()
            end
            CImGui.PopStyleVar()
            CImGui.EndChild()
            btwidth = CImGui.GetContentRegionAvailWidth() - unsafe_load(IMGUISTYLE.ItemSpacing.x)
            CImGui.SetCursorPosY(
                CImGui.GetWindowContentRegionMax().y - 2CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y)
            )
            CImGui.Separator()
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
            CImGui.Button(
                stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save"), "##qtcf to toml"),
                (btwidth / 2, 2CImGui.GetFrameHeight())
            ) && saveinsconf()

            CImGui.SameLine()

            if CImGui.Button(
                stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New")),
                (btwidth / 2, 2CImGui.GetFrameHeight())
            )
                synccall_wait([workers()[1]]) do
                    INSCONF["New Ins"] = OneInsConf()
                end
                INSTRBUFFERVIEWERS["New Ins"] = Dict{String,InstrBufferViewer}()
            end
            CImGui.PopStyleColor()
            CImGui.EndChild()
            CImGui.NextColumn()

            CImGui.BeginChild("edit qts")
            if selectedins != ""
                if CImGui.BeginTabBar("edit confs and widgets")
                    if CImGui.BeginTabItem(mlstr("Configurations"))
                        CImGui.BeginChild("Configurations")
                        selectedinscf = INSCONF[selectedins]
                        ###conf###
                        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Basic"))
                        @c IconSelector(mlstr("icon"), &selectedinscf.conf.icon)
                        if @c InputTextRSZ(mlstr("identification string"), &selectedinscf.conf.idn)
                            lstrip(selectedinscf.conf.idn) == "" && (selectedinscf.conf.idn = selectedins)
                        end
                        @c ComboS(mlstr("command type"), &selectedinscf.conf.cmdtype, ["scpi", "tsp", ""])
                        width = CImGui.GetItemRectSize().x / 3
                        CImGui.TextColored(MORESTYLE.Colors.LogInfo, mlstr("interface"))
                        CImGui.BeginGroup()
                        if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("input")), (width, Cfloat(0)))
                            push!(selectedinscf.conf.input_labels, string("Input ", length(selectedinscf.conf.input_labels) + 1))
                        end
                        for (i, input) in enumerate(selectedinscf.conf.input_labels)
                            CImGui.PushID(i)
                            CImGui.PushItemWidth(width)
                            if @c InputTextRSZ("##Input", &input)
                                input == "" || (selectedinscf.conf.input_labels[i] = input)
                            end
                            CImGui.PopItemWidth()
                            CImGui.SameLine()
                            CImGui.PushID("Input")
                            CImGui.Button(MORESTYLE.Icons.CloseFile) && (deleteat!(selectedinscf.conf.input_labels, i); break)
                            CImGui.PopID()
                            CImGui.PopID()
                        end
                        CImGui.EndGroup()
                        CImGui.SameLine()
                        CImGui.BeginGroup()
                        if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("output")), (width, Cfloat(0)))
                            push!(
                                selectedinscf.conf.output_labels,
                                string("Output ", length(selectedinscf.conf.output_labels) + 1)
                            )
                        end
                        for (i, output) in enumerate(selectedinscf.conf.output_labels)
                            CImGui.PushID(i)
                            CImGui.PushItemWidth(width)
                            if @c InputTextRSZ("##Output", &output)
                                output == "" || (selectedinscf.conf.output_labels[i] = output)
                            end
                            CImGui.PopItemWidth()
                            CImGui.SameLine()
                            CImGui.PushID("Output")
                            CImGui.Button(MORESTYLE.Icons.CloseFile) && (deleteat!(selectedinscf.conf.output_labels, i); break)
                            CImGui.PopID()
                            CImGui.PopID()
                        end
                        CImGui.EndGroup()
                        CImGui.Text(" ") #空行

                        ###quantities###
                        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Variables"))
                        if @c ComboS(mlstr("variables"), &selectedqt, sort(collect(keys(selectedinscf.quantities))))
                            if selectedqt != "" && haskey(selectedinscf.quantities, selectedqt)
                                qtname = selectedqt
                                editqt = deepcopy(selectedinscf.quantities[selectedqt])
                            end
                        end
                        CImGui.SameLine()
                        if CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##QuantityConf"))
                            pop!(selectedinscf.quantities, selectedqt, 0)
                            remotecall_wait(workers()[1], selectedins, selectedqt) do selectedins, selectedqt
                                pop!(INSCONF[selectedins].quantities, selectedqt, 0)
                            end
                            for ibv in values(INSTRBUFFERVIEWERS[selectedins])
                                pop!(ibv.insbuf.quantities, qtname, 0)
                            end
                            selectedqt = ""
                        end
                        CImGui.Text(" ") #空行

                        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Edit"))
                        # CImGui.SameLine()
                        if CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save"), "##QuantityConf to INSCONF"))
                            selectedinscf.quantities[qtname] = deepcopy(editqt)
                            remotecall_wait(workers()[1], selectedins, qtname, editqt) do selectedins, qtname, editqt
                                INSCONF[selectedins].quantities[qtname] = editqt
                            end
                            cmdtype = Symbol("@", INSCONF[selectedins].conf.cmdtype)
                            synccall_wait([workers()[1]], selectedins, cmdtype, qtname, editqt.cmdheader) do instrnm, cmdtype, qtname, cmd
                                @trycatch mlstr("instrument registration failed!!!") begin
                                    if cmd != ""
                                        Expr(
                                            :macrocall,
                                            cmdtype,
                                            LineNumberNode(Base.@__LINE__, Base.@__FILE__),
                                            instrnm,
                                            qtname,
                                            cmd
                                        ) |> eval
                                    end
                                end
                            end
                            for ibv in values(INSTRBUFFERVIEWERS[selectedins])
                                ibv.insbuf.quantities[qtname] = quantity(qtname, deepcopy(editqt))
                            end
                            haskey(default_insbufs, selectedins) && (
                                default_insbufs[selectedins].quantities[qtname] = quantity(qtname, deepcopy(editqt))
                            )
                        end
                        @c InputTextRSZ(mlstr("variable name"), &qtname)
                        edit(editqt, selectedins)
                        CImGui.EndChild()
                        CImGui.EndTabItem()
                    end
                    if haskey(INSWCONF, selectedins)
                        for (i, widget) in enumerate(INSWCONF[selectedins])
                            ispreserve = true
                            if @c CImGui.BeginTabItem(stcstr(mlstr("Widget"), " ", i), &ispreserve)
                                if CImGui.BeginPopupContextItem()
                                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy")))
                                        wcopy = deepcopy(widget)
                                        wcopy.name *= " " * mlstr("Copy")
                                        push!(INSWCONF[selectedins], wcopy)
                                    end
                                    CImGui.EndPopup()
                                end
                                # CImGui.BeginChild(stcstr("Widget", i))
                                view(widget)
                                if !haskey(default_insbufs, selectedins)
                                    default_insbufs[selectedins] = InstrBuffer(selectedins)
                                    for (_, qt) in default_insbufs[selectedins].quantities
                                        qt.read = "123456.7890"
                                        if qt isa SweepQuantity
                                            qt.nstep = 100
                                            qt.presenti = 60
                                            qt.elapsedtime = 66.6
                                        end
                                        updatefront!(qt)
                                    end
                                end
                                edit(widget, default_insbufs[selectedins], "", C_NULL, i)
                                # CImGui.EndChild()
                                CImGui.EndTabItem()
                            end
                            ispreserve || CImGui.OpenPopup(stcstr("delete widget ", i))
                            if YesNoDialog(
                                stcstr("delete widget ", i),
                                mlstr("Confirm delete?"),
                                CImGui.ImGuiWindowFlags_AlwaysAutoResize
                            )
                                deleteat!(INSWCONF[selectedins], i)
                            end
                        end
                    end
                    if igTabItemButton(MORESTYLE.Icons.NewFile, ImGuiTabItemFlags_Trailing | ImGuiTabItemFlags_NoTooltip)
                        haskey(INSWCONF, selectedins) || (INSWCONF[selectedins] = [])
                        newwnm = "new widget $(length(INSWCONF[selectedins])+1)"
                        push!(INSWCONF[selectedins], InstrWidget(instrnm=selectedins, name=newwnm))
                    end
                    CImGui.EndTabBar()
                end
            end
            CImGui.EndChild()
        end
        CImGui.End()
    end
end #let

function saveinsconf()
    conffiles = readdir(joinpath(ENV["QInsControlAssets"], "Confs"))
    allins = keys(INSCONF)
    for cf in conffiles
        filename, filetype = split(cf, '.')
        filetype != "toml" && continue
        filename ∉ allins && Base.Filesystem.rm(joinpath(ENV["QInsControlAssets"], "Confs/$cf"))
    end
    extrafiles = readdir(joinpath(ENV["QInsControlAssets"], "ExtraLoad"))
    for ef in extrafiles
        filename, filetype = split(ef, '.')
        filetype != "jl" && continue
        filename == "extraload" && continue
        filename ∉ allins && Base.Filesystem.rm(joinpath(ENV["QInsControlAssets"], "ExtraLoad/$ef"))
    end
    for (ins, inscf) in INSCONF
        cfpath = joinpath(ENV["QInsControlAssets"], "Confs/$ins.toml")
        readcf = @trypasse TOML.parsefile(cfpath) nothing
        savingcf = todict(inscf)
        if readcf != savingcf
            @trycatch mlstr("saving INSCONF failed!!!") begin
                open(cfpath, "w") do file
                    TOML.print(file, savingcf)
                end
            end
        end
    end
    saveinswconf()
end

function saveinswconf()
    widgetfiles = readdir(joinpath(ENV["QInsControlAssets"], "Widgets"))
    allins = keys(INSWCONF)
    for cf in widgetfiles
        filename, filetype = split(cf, '.')
        filetype != "toml" && continue
        filename ∉ allins && Base.Filesystem.rm(joinpath(ENV["QInsControlAssets"], "Widgets/$cf"))
    end
    for (ins, widgets) in INSWCONF
        cfpath = joinpath(ENV["QInsControlAssets"], "Widgets/$ins.toml")
        readcf = @trypasse TOML.parsefile(cfpath) nothing
        if readcf != Dict(w => Dict(to_dict(w)) for w in widgets)
            @trycatch mlstr("saving INSWCONF failed!!!") begin
                open(cfpath, "w") do file
                    TOML.print(file, Dict(w.name => to_dict(w) for w in widgets))
                end
            end
        end
    end
end