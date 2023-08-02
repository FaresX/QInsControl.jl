let
    edithelp::Bool = false
    global function edit(qtcf::QuantityConf, instrnm)
        @c CImGui.Checkbox(qtcf.enable ? mlstr("enable") : mlstr("disable"), &qtcf.enable)
        # @c InputTextRSZ("变量名", &qtcf.name)
        @c InputTextRSZ(mlstr("alias"), &qtcf.alias)
        @c ComBoS(mlstr("unit type"), &qtcf.U, keys(CONF.U))
        @c InputTextRSZ(mlstr("command"), &qtcf.cmdheader)
        width = CImGui.GetItemRectSize().x / 2 - 2CImGui.CalcTextSize(" =>  ").x
        CImGui.SameLine()
        if CImGui.Button("Driver")
            driverfile = joinpath(ENV["QInsControlAssets"], "ExtraLoad/$instrnm.jl") |> abspath
            if !isfile(driverfile)
                open(joinpath(ENV["QInsControlAssets"], "ExtraLoad/extraload.jl"), "a+") do file
                    write(file, "\ninclude(\"$instrnm.jl\")")
                end
            end
            @async try
                Base.run(Cmd([CONF.Basic.editor, driverfile]))
            catch e
                @error "[$(now())]\n$(mlstr("error editing text!!!"))" exception = e
            end
        end
        CImGui.SameLine()
        if CImGui.Button(MORESTYLE.Icons.InstrumentsManualRef)
            remotecall_wait(include, workers()[1], joinpath(ENV["QInsControlAssets"], "ExtraLoad/extraload.jl"))
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
        @c ComBoS(mlstr("variable type"), &qtcf.type, ["sweep", "set", "read"])
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
            region = TextRect(replace(string(qtcf.help, "\n "), "\\\n" => ""))
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
    editqt::QuantityConf = QuantityConf(true, "", "", "", [], [], "set", "")
    global function InstrRegister(p_open::Ref)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)

        if CImGui.Begin(
            stcstr(MORESTYLE.Icons.InstrumentsRegister, "  ", mlstr("Instrument Registration"), "###ins reg"),
            p_open
        )
            CImGui.Columns(2)
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            CImGui.BeginChild("InstrumentsOverview", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))
            for (oldinsnm, inscf) in insconf
                oldinsnm == "Others" && continue
                haskey(isrename, oldinsnm) || push!(isrename, oldinsnm => false)
                renamei = isrename[oldinsnm]
                CImGui.PushID(oldinsnm)
                CImGui.Text(inscf.conf.icon)
                CImGui.SameLine(0, CImGui.GetFontSize() / 2)
                CImGui.PushItemWidth(-1)
                newinsnm = oldinsnm
                if @c RenameSelectable("##RenameInsConf", &renamei, &newinsnm, selectedins == oldinsnm)
                    selectedins = oldinsnm
                    selectedqt = ""
                end
                CImGui.PopItemWidth()
                if !(newinsnm == "" || haskey(insconf, newinsnm))
                    if isrename[oldinsnm] && !renamei
                        setvalue!(insconf, oldinsnm, newinsnm => inscf)
                        remotecall_wait(workers()[1], oldinsnm, newinsnm, inscf) do oldinsnm, newinsnm, inscf
                            setvalue!(insconf, oldinsnm, newinsnm => inscf)
                        end
                        push!(INSTRBUFFERVIEWERS, newinsnm => pop!(INSTRBUFFERVIEWERS, oldinsnm))
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
                        stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"), "##insconf"),
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
                    pop!(insconf, oldinsnm, 0)
                    remotecall_wait(workers()[1], oldinsnm) do oldinsnm
                        pop!(insconf, oldinsnm, 0)
                    end
                    pop!(INSTRBUFFERVIEWERS, oldinsnm, 0)
                    selectedins = ""
                end
                deldialog && (CImGui.OpenPopup(stcstr("##if delete ins conf", oldinsnm));
                deldialog = false)
                CImGui.PopID()
            end

            CImGui.EndChild()
            if CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save"), "##qtcf to toml"))
                conffiles = readdir(joinpath(ENV["QInsControlAssets"], "Confs"))
                allins = keys(insconf)
                for cf in conffiles
                    filename, filetype = split(cf, '.')
                    filetype != "toml" && continue
                    filename == "conf" && continue
                    filename ∉ allins && Base.Filesystem.rm(joinpath(ENV["QInsControlAssets"], "Confs/$cf"))
                end
                for (ins, inscf) in insconf
                    open(joinpath(ENV["QInsControlAssets"], "Confs/$ins.toml"), "w") do file
                        TOML.print(file, todict(inscf))
                    end
                end
            end

            CImGui.SameLine(CImGui.GetColumnOffset(1) - CImGui.GetItemRectSize().x - unsafe_load(IMGUISTYLE.WindowPadding.x))

            if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New")))
                newins = OneInsConf(
                    BasicConf(
                        Dict(
                            "icon" => ICONS.ICON_MICROCHIP,
                            "cmdtype" => "scpi",
                            "idn" => "New Ins",
                            "input_labels" => [],
                            "output_labels" => []
                        )
                    ),
                    OrderedDict(
                        "quantity" => QuantityConf(
                            Dict(
                                "enable" => true,
                                "alias" => "quantity",
                                "U" => "",
                                "cmdheader" => "",
                                "cmdheader" => "",
                                "optkeys" => [],
                                "optvalues" => [],
                                "type" => "set",
                                "help" => ""
                            )
                        )
                    )
                )
                # push!(insconf, "New Ins" => newins)
                synccall_wait(workers(), newins) do newins
                    push!(insconf, "New Ins" => newins)
                end
                push!(INSTRBUFFERVIEWERS, "New Ins" => Dict{String,InstrBufferViewer}())
            end
            CImGui.NextColumn()

            CImGui.BeginChild("edit qt")
            if selectedins != ""
                selectedinscf = insconf[selectedins]
                ###conf###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("Basic"))
                @c IconSelector(mlstr("icon"), &selectedinscf.conf.icon)
                @c InputTextRSZ(mlstr("identification string"), &selectedinscf.conf.idn)
                @c ComBoS(mlstr("command type"), &selectedinscf.conf.cmdtype, ["scpi", "tsp", ""])
                width = CImGui.GetItemRectSize().x / 3
                CImGui.TextColored(MORESTYLE.Colors.LogInfo, mlstr("interface"))
                CImGui.BeginGroup()
                if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("input")))
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
                if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("output")))
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
                CImGui.Separator()

                ###quantities###
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("Variables"))
                if @c ComBoS(mlstr("variables"), &selectedqt, keys(selectedinscf.quantities))
                    if selectedqt != "" && haskey(selectedinscf.quantities, selectedqt)
                        qtname = selectedqt
                        editqt = deepcopy(selectedinscf.quantities[selectedqt])
                    end
                end
                CImGui.SameLine()
                if CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##QuantityConf"))
                    pop!(selectedinscf.quantities, selectedqt, 0)
                    remotecall_wait(workers()[1], selectedins, selectedqt) do selectedins, selectedqt
                        pop!(insconf[selectedins].quantities, selectedqt, 0)
                    end
                    for ibv in values(INSTRBUFFERVIEWERS[selectedins])
                        pop!(ibv.insbuf.quantities, qtname, 0)
                    end
                    selectedqt = ""
                end
                CImGui.Text(" ") #空行
                CImGui.Separator()
                CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("Edit"))
                CImGui.SameLine()
                if CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, "##QuantityConf to insconf"))
                    push!(selectedinscf.quantities, qtname => deepcopy(editqt))
                    remotecall_wait(workers()[1], selectedins, qtname, editqt) do selectedins, qtname, editqt
                        push!(insconf[selectedins].quantities, qtname => editqt)
                    end
                    cmdtype = Symbol("@", insconf[selectedins].conf.cmdtype)
                    synccall_wait(workers(), selectedins, cmdtype, qtname, editqt.cmdheader) do instrnm, cmdtype, qtname, cmd
                        try
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
                        catch e
                            @error "[$(now())]\n$(mlstr("instrument registration failed!!!"))" exception = e
                        end
                    end
                    for ibv in values(INSTRBUFFERVIEWERS[selectedins])
                        push!(ibv.insbuf.quantities, qtname => InstrQuantity(qtname, deepcopy(editqt)))
                        updatefront!(ibv.insbuf.quantities[qtname])
                    end
                end
                @c InputTextRSZ(mlstr("variable name"), &qtname)
                edit(editqt, selectedins)
            end
            CImGui.EndChild()
        end
        CImGui.End()
    end
end #let