function edit(qtcf::QuantityConf)
    if qtcf.enable
        @c CImGui.Checkbox("启用", &qtcf.enable)
    else
        @c CImGui.Checkbox("停用", &qtcf.enable)
    end
    # @c InputTextRSZ("变量名", &qtcf.name)
    @c InputTextRSZ("别称", &qtcf.alias)
    @c ComBoS("单位类型", &qtcf.U, keys(conf.U))
    @c InputTextRSZ("命令", &qtcf.cmdheader)
    optvalues = join(qtcf.optvalues, ";")
    @c(InputTextRSZ("可选值", &optvalues)) && (qtcf.optvalues = split(optvalues, ';'))
    @c ComBoS("变量类型", &qtcf.type, ["sweep", "set", "read"])
    @cstatic edithelp::Bool = false begin
        CImGui.TextColored(morestyle.Colors.LogInfo, "帮助文档")
        if edithelp
            x = max(ncodeunits.(split(qtcf.help, '\n'))...) * CImGui.GetFontSize() ÷ 2
            width = CImGui.GetContentRegionAvailWidth()
            x = x > width ? x : width
            y = (1 + length(findall("\n", qtcf.help))) * CImGui.GetTextLineHeight() + 2unsafe_load(imguistyle.FramePadding.y)
            CImGui.BeginChild("编辑帮助文档", (Cfloat(0), y), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
            @c InputTextMultilineRSZ("##帮助文档", &qtcf.help, (x, y))
            !CImGui.IsItemHovered() && !CImGui.IsItemActive() && CImGui.IsMouseClicked(0) && (edithelp = false)
            CImGui.EndChild()
        else
            region = TextRect(replace(string(qtcf.help, "\n "), "\\\n" => ""))
            CImGui.IsMouseDoubleClicked(0) && mousein(region) && (edithelp = true)
        end
    end
end

let
    selectedins::String = ""
    selectedqt::String = ""
    deldialog::Bool = false
    isrename::Dict{String,Bool} = Dict()
    yesnodialog_ids::Dict{String,String} = Dict()
    global function InstrRegister(p_open::Ref)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)

        if CImGui.Begin(morestyle.Icons.InstrumentsRegister * "  仪器注册", p_open)
            CImGui.Columns(2)
            @cstatic firsttime::Bool = true begin
                firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            end
            CImGui.BeginChild("仪器", (Float32(0), -CImGui.GetFrameHeightWithSpacing()))
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
                        push!(instrbufferviewers, newinsnm => pop!(instrbufferviewers, oldinsnm))
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
                        morestyle.Icons.CloseFile * " 删除##insconf",
                        C_NULL,
                        false,
                        !in(oldinsnm, ["VirtualInstr", "Others"])
                    ) && (deldialog = true)
                    CImGui.EndPopup()
                end
                haskey(yesnodialog_ids, oldinsnm) || push!(yesnodialog_ids, oldinsnm => "##是否删除仪器配置$oldinsnm")
                if YesNoDialog(yesnodialog_ids[oldinsnm], "确认删除？", CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                    pop!(insconf, oldinsnm, 0)
                    remotecall_wait(workers()[1], oldinsnm) do oldinsnm
                        pop!(insconf, oldinsnm, 0)
                    end
                    pop!(instrbufferviewers, oldinsnm, 0)
                    selectedins = ""
                end
                deldialog && (CImGui.OpenPopup(yesnodialog_ids[oldinsnm]);
                deldialog = false)
                CImGui.PopID()
            end

            CImGui.EndChild()
            if CImGui.Button(morestyle.Icons.SaveButton * " 保存##Write QuantityConf to toml")
                conffiles = readdir(joinpath(ENV["QInsControlAssets"], "Confs"))
                allins = keys(insconf)
                for cf in conffiles
                    filename, filetype = split(cf, '.')
                    filetype != "toml" && continue
                    filename == "conf" && continue
                    !in(filename, allins) && Base.Filesystem.rm(joinpath(ENV["QInsControlAssets"], "Confs/$cf"))
                end
                for (ins, inscf) in insconf
                    open(joinpath(ENV["QInsControlAssets"], "Confs/$ins.toml"), "w") do file
                        TOML.print(file, todict(inscf))
                    end
                end
            end

            CImGui.SameLine(CImGui.GetColumnOffset(1) - CImGui.GetItemRectSize().x - unsafe_load(imguistyle.WindowPadding.x))

            if CImGui.Button(morestyle.Icons.NewFile * " 新建")
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
                                "alias" => "变量",
                                "U" => "",
                                "cmdheader" => "",
                                "cmdheader" => "",
                                "optvalues" => [],
                                "type" => "set",
                                "help" => ""
                            )
                        )
                    )
                )
                push!(insconf, "New Ins" => newins)
                remotecall_wait(workers()[1], newins) do newins
                    push!(insconf, "New Ins" => newins)
                end
                push!(instrbufferviewers, "New Ins" => Dict{String,InstrBufferViewer}())
            end
            CImGui.NextColumn()

            CImGui.BeginChild("编辑变量")
            if selectedins != ""
                selectedinscf = insconf[selectedins]
                ###conf###
                CImGui.TextColored(morestyle.Colors.HighlightText, "基本")
                @c IconSelector("图标", &selectedinscf.conf.icon)
                @c InputTextRSZ("识别字符", &selectedinscf.conf.idn)
                @c ComBoS("命令类型", &selectedinscf.conf.cmdtype, ["scpi", "tsp", ""])
                width = CImGui.GetItemRectSize().x / 3
                CImGui.Text("接口")
                CImGui.BeginGroup()
                if CImGui.Button(morestyle.Icons.NewFile * " 输入")
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
                    CImGui.Button(morestyle.Icons.CloseFile) && (deleteat!(selectedinscf.conf.input_labels, i); break)
                    CImGui.PopID()
                    CImGui.PopID()
                end
                CImGui.EndGroup()
                CImGui.SameLine()
                CImGui.BeginGroup()
                if CImGui.Button(morestyle.Icons.NewFile * " 输出")
                    push!(selectedinscf.conf.output_labels, string("Output ", length(selectedinscf.conf.output_labels) + 1))
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
                    CImGui.Button(morestyle.Icons.CloseFile) && (deleteat!(selectedinscf.conf.output_labels, i); break)
                    CImGui.PopID()
                    CImGui.PopID()
                end
                CImGui.EndGroup()
                CImGui.Text(" ") #空行
                CImGui.Separator()

                ###quantities###
                @cstatic qtname::String = "" editqt::QuantityConf = QuantityConf(true, "", "", "", [""], "set", "") begin
                    CImGui.TextColored(morestyle.Colors.HighlightText, "变量")
                    if @c ComBoS("变量", &selectedqt, keys(selectedinscf.quantities))
                        if selectedqt != "" && haskey(selectedinscf.quantities, selectedqt)
                            qtname = selectedqt
                            editqt = QuantityConf(todict(selectedinscf.quantities[selectedqt]))
                        end
                    end
                    CImGui.SameLine()
                    if CImGui.Button(morestyle.Icons.CloseFile * "##QuantityConf")
                        pop!(selectedinscf.quantities, selectedqt, 0)
                        remotecall_wait(workers()[1], selectedins, selectedqt) do selectedins, selectedqt
                            pop!(insconf[selectedins].quantities, selectedqt, 0)
                        end
                        for ibv in values(instrbufferviewers[selectedins])
                            pop!(ibv.insbuf.quantities, qtname, 0)
                        end
                        selectedqt = ""
                    end
                    CImGui.Text(" ") #空行
                    CImGui.Separator()
                    CImGui.TextColored(morestyle.Colors.HighlightText, "编辑")
                    CImGui.SameLine()
                    if CImGui.Button(morestyle.Icons.SaveButton * "##QuantityConf to insconf")
                        push!(selectedinscf.quantities, qtname => editqt)
                        remotecall_wait(workers()[1], selectedins, qtname, editqt) do selectedins, qtname, editqt
                            push!(insconf[selectedins].quantities, qtname => editqt)
                        end
                        for ibv in values(instrbufferviewers[selectedins])
                            push!(ibv.insbuf.quantities, qtname => InstrQuantity(qtname, editqt))
                        end
                    end
                    @c InputTextRSZ("变量名", &qtname)
                    edit(editqt)
                end
            end
            CImGui.EndChild()
        end
        CImGui.End()
    end
end #let