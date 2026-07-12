function edit(bk::CodeBlock, openpopup::Ref{Bool}=Ref(false))
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.BeginChild("##CodeBlock", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.CodeBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    @c InputTextMultilineRSZ("##CodeBlock", &bk.codes, (-1, -1), ImGuiInputTextFlags_AllowTabInput)
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function edit(bk::StrideCodeBlock, openpopup::Ref{Bool}=Ref(false))
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    isemptybks = isempty(skipnull(bk.blocks))
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        isemptybks ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border) : MORESTYLE.Colors.StrideCodeBlockBorder
    )
    wp = unsafe_load(IMGUISTYLE.WindowPadding)
    bkh = bkheight(bk)
    CImGui.PushStyleVar(
        CImGui.ImGuiStyleVar_WindowPadding,
        bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
    )
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, isemptybks ? 1 : MORESTYLE.Variables.BlockBorderSize)
    CImGui.BeginChild("##StrideCodeBlock", (Float32(0), bkh), true)
    CImGui.PopStyleVar()
    ColoredButton(
        MORESTYLE.Icons.StrideCodeBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.nohandler ? MORESTYLE.Colors.StrideCodeBlockBorder : MORESTYLE.Colors.BlockIcons
    ) && (bk.hideblocks ⊻= true)
    if CImGui.BeginPopupContextItem("##StrideCodeBlockiconmenu")
        openpopup[] = true
        @c CImGui.Checkbox(mlstr(bk.nohandler ? "Without Handler" : "Within Handler"), &bk.nohandler)
        CImGui.EndPopup()
    end
    CImGui.SameLine()
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##code header", mlstr("code header"), &bk.codes)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
    bk.hideblocks || isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar(2)
end

function edit(bk::BranchBlock, openpopup::Ref{Bool}=Ref(false))
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.BeginChild("##BranchBlock", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.BranchBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##BranchBlock", mlstr("code branch"), &bk.codes)
    CImGui.PopItemWidth()
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

let
    filter::String = ""
    alias::String = ""
    global function edit(bk::SweepBlock, openpopup::Ref{Bool}=Ref(false))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
        isemptybks = isempty(skipnull(bk.blocks))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Border,
            isemptybks ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border) : MORESTYLE.Colors.SweepBlockBorder
        )
        wp = unsafe_load(IMGUISTYLE.WindowPadding)
        bkh = bkheight(bk)
        CImGui.PushStyleVar(
            CImGui.ImGuiStyleVar_WindowPadding,
            bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
        )
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, isemptybks ? 1 : MORESTYLE.Variables.BlockBorderSize)
        CImGui.BeginChild("##SweepBlock", (Float32(0), bkh), true)
        CImGui.PopStyleVar(2)
        ColoredButton(
            bk.rangemark == "" ? MORESTYLE.Icons.SweepBlock : bk.rangemark;
            size=length(bk.rangemark) < 3 ? (CImGui.GetFrameHeight(), Cfloat(0)) : (0, 0),
            colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
            coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
        ) && (bk.hideblocks ⊻= true)
        if CImGui.BeginPopupContextItem("##SweepBlockiconmenu")
            openpopup[] = true
            @c CImGui.Checkbox(mlstr("Try-Catch"), &bk.istrycatch)
            @c InputTextRSZ(mlstr("Mark"), &bk.rangemark)
            CImGui.EndPopup()
        end
        CImGui.SameLine()
        width = CImGui.GetContentRegionAvail().x / 5
        CImGui.PushItemWidth(width)
        if @c(ComboSFiltered("##SweepBlock alias", &bk.alias, keys(INSTRALIASLIST), CImGui.ImGuiComboFlags_NoArrowButton))
            bk.instrnm = INSTRALIASLIST[bk.alias].instrnm
            bk.addr = INSTRALIASLIST[bk.alias].addr
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()
        # CImGui.PushItemWidth(width)
        # inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
        # @c ComboSFiltered("##SweepBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()

        # inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        # bk.addr = inlist ? bk.addr : mlstr("address")
        # addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
        # CImGui.PushItemWidth(width)
        # @c ComboS("##SweepBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()

        showqt = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
            INSTRCONF[bk.instrnm].quantities[bk.quantity].alias
        else
            mlstr("sweep")
        end
        CImGui.PushItemWidth(width)
        if CImGui.BeginCombo("##SweepBlock sweep", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
            qtlist = haskey(INSTRCONF, bk.instrnm) ? keys(INSTRCONF[bk.instrnm].quantities) : Set{String}()
            qts = if haskey(INSTRCONF, bk.instrnm)
                [qt for qt in qtlist if INSTRCONF[bk.instrnm].quantities[qt].type == "sweep"]
            else
                String[]
            end
            @c InputTextWithHintRSZ("##SweepBlock sweep", mlstr("Filter"), &filter)
            sp = sortperm([INSTRCONF[bk.instrnm].quantities[qt].alias for qt in qts])
            for qt in qts[sp]
                showqt = INSTRCONF[bk.instrnm].quantities[qt].alias
                (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(showqt))) || continue
                selected = bk.quantity == qt
                CImGui.Selectable(showqt, selected, 0) && (bk.quantity = qt)
                selected && CImGui.SetItemDefaultFocus()
            end
            CImGui.EndCombo()
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()

        CImGui.PushItemWidth(width)
        @c InputTextWithHintRSZ("##SweepBlock step", mlstr("step"), &bk.step)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(width - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c InputTextWithHintRSZ("##SweepBlock stop", mlstr("stop"), &bk.stop)
        CImGui.PopItemWidth()
        CImGui.SameLine()

        Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
            INSTRCONF[bk.instrnm].quantities[bk.quantity].U
        else
            ""
        end
        CImGui.PushItemWidth(2width / 3)
        @c ShowUnit("##SweepBlock", Ut, &bk.ui)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(-1)
        @c CImGui.DragFloat("##SweepBlock delay", &bk.delay, 0.01, 0, 9.99, "%g", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()

        CImGui.PopStyleColor()
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
        bk.hideblocks || isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
        CImGui.EndChild()
        CImGui.PopStyleVar(3)
    end
end

let
    filter::String = ""
    global function edit(bk::FreeSweepBlock, openpopup::Ref{Bool}=Ref(false))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
        isemptybks = isempty(skipnull(bk.blocks))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Border,
            isemptybks ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border) : MORESTYLE.Colors.FreeSweepBlockBorder
        )
        wp = unsafe_load(IMGUISTYLE.WindowPadding)
        bkh = bkheight(bk)
        CImGui.PushStyleVar(
            CImGui.ImGuiStyleVar_WindowPadding,
            bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
        )
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, isemptybks ? 1 : MORESTYLE.Variables.BlockBorderSize)
        CImGui.BeginChild("##FreeSweepBlock", (Float32(0), bkh), true)
        CImGui.PopStyleVar(2)
        ColoredButton(
            MORESTYLE.Icons.FreeSweepBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
            colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
            coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
        ) && (bk.hideblocks ⊻= true)
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
        if CImGui.BeginPopupContextItem("##FreeSweepBlockiconmenu")
            openpopup[] = true
            @c CImGui.Checkbox(mlstr("Try-Catch"), &bk.istrycatch)
            @c CImGui.DragFloat(
                mlstr("decision duration"), &bk.duration, 1, 1, 3600, "%g",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            CImGui.EndPopup()
        end
        CImGui.SameLine()
        width = CImGui.GetContentRegionAvail().x / 5
        CImGui.PushItemWidth(width)
        if @c(ComboSFiltered("##FreeSweepBlock alias", &bk.alias, keys(INSTRALIASLIST), CImGui.ImGuiComboFlags_NoArrowButton))
            bk.instrnm = INSTRALIASLIST[bk.alias].instrnm
            bk.addr = INSTRALIASLIST[bk.alias].addr
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()
        # CImGui.PushItemWidth(width)
        # inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
        # @c ComboSFiltered("##FreeSweepBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()

        # inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        # bk.addr = inlist ? bk.addr : mlstr("address")
        # addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
        # CImGui.PushItemWidth(width)
        # @c ComboS("##FreeSweepBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()

        showqt = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
            INSTRCONF[bk.instrnm].quantities[bk.quantity].alias
        else
            mlstr("sweep")
        end
        CImGui.PushItemWidth(width)
        if CImGui.BeginCombo("##FreeSweepBlock sweep", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
            qtlist = haskey(INSTRCONF, bk.instrnm) ? keys(INSTRCONF[bk.instrnm].quantities) : Set{String}()
            qts = collect(qtlist)
            @c InputTextWithHintRSZ("##FreeSweepBlock sweep", mlstr("Filter"), &filter)
            sp = sortperm([INSTRCONF[bk.instrnm].quantities[qt].alias for qt in qts])
            for qt in qts[sp]
                showqt = INSTRCONF[bk.instrnm].quantities[qt].alias
                (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(showqt))) || continue
                selected = bk.quantity == qt
                CImGui.Selectable(showqt, selected, 0) && (bk.quantity = qt)
                selected && CImGui.SetItemDefaultFocus()
            end
            CImGui.EndCombo()
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()

        CImGui.PushItemWidth(CImGui.GetFrameHeight())
        @c ComboS("##FreeSweepBlock mode", &bk.mode, ["=", "<", ">"], CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(width - CImGui.GetItemRectSize().x - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c InputTextWithHintRSZ("##FreeSweepBlock stop", mlstr("stop"), &bk.stop)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(width)
        if @c CImGui.InputFloat("##FreeSweepBlock delta", &bk.delta, 0, 0, "%g")
            bk.delta <= 0 && (bk.delta = 0.001)
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()
        Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
            INSTRCONF[bk.instrnm].quantities[bk.quantity].U
        else
            ""
        end
        CImGui.PushItemWidth(2width / 3)
        @c ShowUnit("##FreeSweepBlock", Ut, &bk.ui)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(-1)
        @c CImGui.DragFloat("##FreeSweepBlock delay", &bk.delay, 0.01, 0, 9.99, "%g", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()

        CImGui.PopStyleColor()
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
        bk.hideblocks || isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
        CImGui.EndChild()
        CImGui.PopStyleVar(3)
    end
end

let
    filter::String = ""
    global function edit(bk::SettingBlock, openpopup::Ref{Bool}=Ref(false))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
        CImGui.BeginChild("##SettingBlock", (Float32(0), bkheight(bk)), true)
        ColoredButton(
            MORESTYLE.Icons.SettingBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
            colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
            coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
        )
        if CImGui.BeginPopupContextItem("##SettingBlockiconmenu")
            openpopup[] = true
            @c CImGui.Checkbox(mlstr("Try-Catch"), &bk.istrycatch)
            CImGui.EndPopup()
        end
        CImGui.SameLine()
        width = CImGui.GetContentRegionAvail().x / 5
        CImGui.PushItemWidth(width)
        if @c(ComboSFiltered("##SettingBlock alias", &bk.alias, keys(INSTRALIASLIST), CImGui.ImGuiComboFlags_NoArrowButton))
            bk.instrnm = INSTRALIASLIST[bk.alias].instrnm
            bk.addr = INSTRALIASLIST[bk.alias].addr
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()
        # CImGui.PushItemWidth(width)
        # inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
        # @c ComboSFiltered("##SettingBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()

        # inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        # bk.addr = inlist ? bk.addr : mlstr("address")
        # addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
        # CImGui.PushItemWidth(width)
        # @c ComboS("##SettingBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()

        showqt = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
            INSTRCONF[bk.instrnm].quantities[bk.quantity].alias
        else
            mlstr("set")
        end
        CImGui.PushItemWidth(width)
        if CImGui.BeginCombo("##SettingBlock set", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
            qtlist = haskey(INSTRCONF, bk.instrnm) ? keys(INSTRCONF[bk.instrnm].quantities) : Set{String}()
            sts = if haskey(INSTRCONF, bk.instrnm)
                [qt for qt in qtlist if INSTRCONF[bk.instrnm].quantities[qt].type in ["set", "sweep"]]
            else
                String[]
            end
            @c InputTextWithHintRSZ("##SettingBlock set", mlstr("Filter"), &filter)
            sp = sortperm([INSTRCONF[bk.instrnm].quantities[qt].alias for qt in sts])
            for st in sts[sp]
                showqt = INSTRCONF[bk.instrnm].quantities[st].alias
                (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(showqt))) || continue
                selected = bk.quantity == st
                CImGui.Selectable(showqt, selected, 0) && (bk.quantity = st)
                selected && CImGui.SetItemDefaultFocus()
            end
            CImGui.EndCombo()
        end
        CImGui.PopItemWidth()

        CImGui.SameLine()
        @c CImGui.Checkbox("##SettingBlock ischeck", &bk.ischeck)
        CImGui.SameLine()
        CImGui.PushItemWidth(2width - CImGui.GetItemRectSize().x - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c InputTextWithHintRSZ("##SettingBlock set value", mlstr("set value"), &bk.setvalue)
        CImGui.PopItemWidth()
        if CImGui.BeginPopupContextItem("select set value")
            openpopup[] = true
            optklist = @trypass INSTRCONF[bk.instrnm].quantities[bk.quantity].optkeys []
            optvlist = @trypass INSTRCONF[bk.instrnm].quantities[bk.quantity].optvalues []
            isempty(optklist) && CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("unavailable options!"))
            for (i, optv) in enumerate(optvlist)
                optv == "" && continue
                CImGui.MenuItem(optklist[i]) && (bk.setvalue = optv)
            end
            CImGui.EndPopup()
        end
        CImGui.SameLine()

        Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
            INSTRCONF[bk.instrnm].quantities[bk.quantity].U
        else
            ""
        end
        CImGui.PushItemWidth(2width / 3)
        @c ShowUnit("SettingBlock", Ut, &bk.ui)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(-1)
        @c CImGui.DragFloat("##SettingBlock delay", &bk.delay, 0.01, 0, 9.99, "%g", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()

        CImGui.EndChild()
        CImGui.PopStyleVar(2)
    end
end

let
    filter::String = ""
    keysbuf::String = ""
    global function edit(bk::ReadingBlock, openpopup::Ref{Bool}=Ref(false))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, bk.isasync ? MORESTYLE.Variables.BlockBorderSize : 1)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Border,
            if bk.isasync && !bk.isobserve
                MORESTYLE.Colors.BlockAsyncBorder
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
            end
        )
        CImGui.BeginChild("##ReadingBlock", (Float32(0), bkheight(bk)), true)
        ColoredButton(
            MORESTYLE.Icons.ReadingBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
            colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
            coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
        )
        if CImGui.BeginPopupContextItem("##ReadingBlockiconmenu")
            openpopup[] = true
            @c CImGui.Checkbox(mlstr("Try-Catch"), &bk.istrycatch)
            @c CImGui.Checkbox(mlstr("Async"), &bk.isasync)
            if CImGui.Button(mlstr("Generate Keys"))
                index = genindex(bk)
                keysbuf = isnothing(index) ? genkey(bk) : join(genkeys(bk, index), '\n')
            end
            y = length(split(keysbuf, '\n')) * CImGui.GetTextLineHeight() +
                2unsafe_load(IMGUISTYLE.FramePadding.y)
            CImGui.InputTextMultiline(
                "##generatedkeys", keysbuf, length(keysbuf), (Cfloat(0), y),
                CImGui.ImGuiInputTextFlags_ReadOnly
            )
            CImGui.EndPopup()
        end
        CImGui.SameLine()
        width = CImGui.GetContentRegionAvail().x / 5
        CImGui.PushItemWidth(width)
        if @c(ComboSFiltered("##ReadingBlock alias", &bk.alias, keys(INSTRALIASLIST), CImGui.ImGuiComboFlags_NoArrowButton))
            bk.instrnm = INSTRALIASLIST[bk.alias].instrnm
            bk.addr = INSTRALIASLIST[bk.alias].addr
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()
        # CImGui.PushItemWidth(width)
        # inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
        # @c ComboSFiltered("##ReadingBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()

        # inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        # bk.addr = inlist ? bk.addr : mlstr("address")
        # addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) String[]
        # CImGui.PushItemWidth(width)
        # @c ComboS("##ReadingBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()
        hasqt = haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
        showqt = hasqt ? INSTRCONF[bk.instrnm].quantities[bk.quantity].alias : mlstr("read")
        CImGui.PushItemWidth(width)
        if CImGui.BeginCombo("##ReadingBlock read", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
            qtlist = haskey(INSTRCONF, bk.instrnm) ? keys(INSTRCONF[bk.instrnm].quantities) : Set{String}()
            qts = collect(qtlist)
            @c InputTextWithHintRSZ("##ReadingBlock read", mlstr("Filter"), &filter)
            sp = sortperm([INSTRCONF[bk.instrnm].quantities[qt].alias for qt in qts])
            for qt in qts[sp]
                showqt = INSTRCONF[bk.instrnm].quantities[qt].alias
                (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(showqt))) || continue
                selected = bk.quantity == qt
                CImGui.Selectable(showqt, selected, 0) && (bk.quantity = qt)
                selected && CImGui.SetItemDefaultFocus()
            end
            CImGui.EndCombo()
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()

        igBeginDisabled((!hasqt || (hasqt && INSTRCONF[bk.instrnm].quantities[bk.quantity].numread == 1)))
        CImGui.PushItemWidth(width)
        @c InputTextWithHintRSZ("##ReadingBlock index", mlstr("index"), &bk.index)
        CImGui.PopItemWidth()
        igEndDisabled()
        CImGui.SameLine()

        markc = if bk.isobserve
            ImVec4(MORESTYLE.Colors.BlockObserveBG...)
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
        end
        bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
        CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
        CImGui.PushItemWidth(-1)
        @c InputTextWithHintRSZ("##ReadingBlock mark", mlstr("mark"), &bk.mark)
        CImGui.PopItemWidth()
        CImGui.PopStyleColor()
        if CImGui.BeginPopupContextItem("##ReadingBlock mark")
            openpopup[] = true
            @c CImGui.Checkbox(mlstr("Observable"), &bk.isobserve)
            bk.isobserve && @c CImGui.Checkbox(mlstr("Save Reading"), &bk.isreading)
            CImGui.EndPopup()
        end

        CImGui.EndChild()
        CImGui.PopStyleColor()
        CImGui.PopStyleVar(3)
    end
end

function edit(bk::WriteBlock, openpopup::Ref{Bool}=Ref(false))
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        bk.isasync ? MORESTYLE.Colors.BlockAsyncBorder : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
    )
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, bk.isasync ? MORESTYLE.Variables.BlockBorderSize : 1)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.BeginChild("##WriteBlock", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.WriteBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    if CImGui.BeginPopupContextItem("##WriteBlockiconmenu")
        openpopup[] = true
        @c CImGui.Checkbox(mlstr("Try-Catch"), &bk.istrycatch)
        @c CImGui.Checkbox(mlstr("Async"), &bk.isasync)
        CImGui.EndPopup()
    end
    CImGui.SameLine()
    width = CImGui.GetContentRegionAvail().x / 5
    CImGui.PushItemWidth(width)
    if @c(ComboSFiltered("##WriteBlock alias", &bk.alias, keys(INSTRALIASLIST), CImGui.ImGuiComboFlags_NoArrowButton))
        bk.instrnm = INSTRALIASLIST[bk.alias].instrnm
        bk.addr = INSTRALIASLIST[bk.alias].addr
    end
    CImGui.PopItemWidth()
    CImGui.SameLine()
    # CImGui.PushItemWidth(width)
    # inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
    # @c ComboSFiltered("##WriteBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
    # CImGui.PopItemWidth()
    # CImGui.SameLine() #选仪器

    # inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    # bk.addr = inlist ? bk.addr : mlstr("address")
    # addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) Set{String}()
    # CImGui.PushItemWidth(width)
    # @c ComboS("##WriteBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
    # CImGui.PopItemWidth()
    # CImGui.SameLine() #选地址

    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##WriteBlock CMD", mlstr("command"), &bk.cmd)
    CImGui.PopItemWidth() #命令

    CImGui.EndChild()
    CImGui.PopStyleVar(3)
    CImGui.PopStyleColor()
end

function edit(bk::QueryBlock, openpopup::Ref{Bool}=Ref(false))
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, bk.isasync ? MORESTYLE.Variables.BlockBorderSize : 1)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.BeginChild("##QueryBlock", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.QueryBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    if CImGui.BeginPopupContextItem("##QueryBlockiconmenu")
        openpopup[] = true
        @c CImGui.Checkbox(mlstr("Try-Catch"), &bk.istrycatch)
        @c CImGui.Checkbox(mlstr("Async"), &bk.isasync)
        CImGui.EndPopup()
    end
    CImGui.SameLine()
    width = CImGui.GetContentRegionAvail().x / 5
    CImGui.PushItemWidth(width)
    if @c(ComboSFiltered("##QueryBlock alias", &bk.alias, keys(INSTRALIASLIST), CImGui.ImGuiComboFlags_NoArrowButton))
        bk.instrnm = INSTRALIASLIST[bk.alias].instrnm
        bk.addr = INSTRALIASLIST[bk.alias].addr
    end
    CImGui.PopItemWidth()
    CImGui.SameLine()
    # CImGui.PushItemWidth(width)
    # inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
    # @c ComboSFiltered("##QueryBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
    # CImGui.PopItemWidth()
    # CImGui.SameLine() #选仪器

    # inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    # bk.addr = inlist ? bk.addr : mlstr("address")
    # addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) Set{String}()
    # CImGui.PushItemWidth(width)
    # @c ComboS("##QueryBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
    # CImGui.PopItemWidth()
    # CImGui.SameLine() #选地址WriteBlock

    CImGui.PushItemWidth(2width + unsafe_load(IMGUISTYLE.ItemSpacing.x))
    @c InputTextWithHintRSZ("##QueryBlock CMD", mlstr("command"), &bk.cmd)
    CImGui.PopItemWidth()
    CImGui.SameLine() #命令

    CImGui.PushItemWidth(2width / 3)
    @c InputTextWithHintRSZ("##QueryBlock索引", mlstr("index"), &bk.index)
    CImGui.PopItemWidth()
    CImGui.SameLine() #索引

    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##QueryBlock mark", mlstr("mark"), &bk.mark)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor() #标注
    if CImGui.BeginPopupContextItem("##QueryBlock mark")
        openpopup[] = true
        @c CImGui.Checkbox(mlstr("Observable"), &bk.isobserve)
        bk.isobserve && @c CImGui.Checkbox(mlstr("Save Reading"), &bk.isreading)
        CImGui.EndPopup()
    end

    CImGui.EndChild()
    CImGui.PopStyleVar(3)
    CImGui.PopStyleColor()
end

function edit(bk::ReadBlock, openpopup::Ref{Bool}=Ref(false))
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, bk.isasync ? MORESTYLE.Variables.BlockBorderSize : 1)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.BeginChild("##ReadBlock", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.ReadBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    if CImGui.BeginPopupContextItem("##ReadBlockiconmenu")
        openpopup[] = true
        @c CImGui.Checkbox(mlstr("Try-Catch"), &bk.istrycatch)
        @c CImGui.Checkbox(mlstr("Async"), &bk.isasync)
        CImGui.EndPopup()
    end
    CImGui.SameLine()
    width = CImGui.GetContentRegionAvail().x / 5
    CImGui.PushItemWidth(width)
    if @c(ComboSFiltered("##ReadBlock alias", &bk.alias, keys(INSTRALIASLIST), CImGui.ImGuiComboFlags_NoArrowButton))
        bk.instrnm = INSTRALIASLIST[bk.alias].instrnm
        bk.addr = INSTRALIASLIST[bk.alias].addr
    end
    CImGui.PopItemWidth()
    CImGui.SameLine()
    # CImGui.PushItemWidth(width)
    # inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
    # @c ComboSFiltered("##ReadBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
    # CImGui.PopItemWidth()
    # CImGui.SameLine() #选仪器

    # inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    # bk.addr = inlist ? bk.addr : mlstr("address")
    # addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
    # CImGui.PushItemWidth(width)
    # @c ComboS("##ReadBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
    # CImGui.PopItemWidth()
    # CImGui.SameLine() #选地址

    CImGui.PushItemWidth(width)
    @c InputTextWithHintRSZ("##ReadBlock index", mlstr("index"), &bk.index)
    CImGui.PopItemWidth()
    CImGui.SameLine() #索引

    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##ReadBlock mark", mlstr("mark"), &bk.mark)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor() #标注
    if CImGui.BeginPopupContextItem("##ReadBlock mark")
        openpopup[] = true
        @c CImGui.Checkbox(mlstr("Observable"), &bk.isobserve)
        bk.isobserve && @c CImGui.Checkbox(mlstr("Save Reading"), &bk.isreading)
        CImGui.EndPopup()
    end

    CImGui.EndChild()
    CImGui.PopStyleVar(3)
    CImGui.PopStyleColor()
end

let
    actions::Vector{String} = ["Pause", "Interrupt", "Continue"]
    global function edit(bk::FeedbackBlock, openpopup::Ref{Bool}=Ref(false))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
        CImGui.BeginChild("##FeedbackBlock", (Float32(0), bkheight(bk)), true)
        ColoredButton(
            MORESTYLE.Icons.FeedbackBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
            colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
            coltxt=MORESTYLE.Colors.BlockIcons
        )
        CImGui.SameLine()
        width = CImGui.GetContentRegionAvail().x / 5
        CImGui.PushItemWidth(width)
        if @c(ComboSFiltered("##FeedbackBlock alias", &bk.alias, keys(INSTRALIASLIST), CImGui.ImGuiComboFlags_NoArrowButton))
            bk.instrnm = INSTRALIASLIST[bk.alias].instrnm
            bk.addr = INSTRALIASLIST[bk.alias].addr
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()
        # CImGui.PushItemWidth(width)
        # inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
        # @c ComboSFiltered("##FeedbackBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine() #选仪器

        # inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        # bk.addr = inlist ? bk.addr : mlstr("address")
        # addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
        # CImGui.PushItemWidth(width)
        # @c ComboS("##FeedbackBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
        # CImGui.PopItemWidth()
        # CImGui.SameLine() #选地址

        CImGui.PushItemWidth(-1)
        @c ComboS("##FeedbackBlock action", &bk.action, mlstr.(actions), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth() #action

        CImGui.EndChild()
        CImGui.PopStyleVar(2)
    end
end

function mousein(bk::AbstractBlock, total=false)::Bool
    if total
        mousein(bk.regmin, bk.regmax) || (typeof(bk) in [SweepBlock, StrideCodeBlock] && true in mousein.(bk.blocks, true))
    else
        mousein(bk.regmin, bk.regmax)
    end
end
mousein(::NullBlock, total=false) = false

let
    isdragging::Bool = false
    addmode::Bool = false
    draggingid = 0
    presentid = 0
    dragblock = AbstractBlock[]
    dropblock = AbstractBlock[]
    copyblock::AbstractBlock = NullBlock()
    selectedblock::Cint = 0
    allblocks::Vector{Symbol} = [:CodeBlock, :StrideCodeBlock, :BranchBlock, :SweepBlock, :FreeSweepBlock,
        :SettingBlock, :ReadingBlock, :WriteBlock, :QueryBlock, :ReadBlock, :FeedbackBlock]

    global function dragblockmenu(id)
        presentid = id
        originfontsize = unsafe_load(IMGUISTYLE.FontSizeBase)
        CImGui.PushFont(C_NULL, MORESTYLE.Variables.BigIconSize)
        ftsz = CImGui.GetFontSize()
        lbk = length(allblocks)
        availw = CImGui.GetContentRegionAvail().x / lbk - unsafe_load(IMGUISTYLE.ItemSpacing.x)
        for (i, bk) in enumerate(allblocks)
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.BlockIcons)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            CImGui.Selectable(getproperty(MORESTYLE.Icons, bk), false, 0, (availw, 2ftsz))
            CImGui.PopStyleVar()
            CImGui.PopStyleColor()
            CImGui.PushFont(C_NULL, originfontsize)
            ItemTooltip(mlstr(stcstr(bk)))
            CImGui.PopFont()
            if CImGui.IsItemActive() && !isdragging && isempty(dragblock)
                push!(dragblock, eval(bk)())
                isdragging = true
                addmode = true
                draggingid = presentid
            end
            i == lbk || CImGui.SameLine()
        end
        CImGui.PopFont()
        if isdragging && draggingid == presentid && length(dragblock) == 1
            CImGui.BeginTooltip()
            CImGui.Text(mlstr(split(string(typeof(only(dragblock))), '.')[end]))
            CImGui.EndTooltip()
        end
    end

    global function edit(blocks::Vector{AbstractBlock}, n::Int, id=0)
        n == 1 && (presentid = id)
        for (i, bk) in enumerate(blocks)
            bk isa NullBlock && continue
            if isdragging && draggingid == presentid && mousein(bk)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Separator, MORESTYLE.Colors.HighlightText)
                draw_list = CImGui.GetWindowDrawList()
                CImGui.AddRectFilled(draw_list, bk.regmin, bk.regmax, MORESTYLE.Colors.BlockDragdrop, 0.0, 0)
                CImGui.AddRect(
                    draw_list, bk.regmin, bk.regmax, MORESTYLE.Colors.BlockDragdropBorder,
                    0.0, MORESTYLE.Variables.BlockDragdropBorderSize
                )
                CImGui.PopStyleColor()
            end
            CImGui.PushID(i)
            openpopup = false
            @c edit(bk, &openpopup)
            id = stcstr(CImGui.igGetItemID())
            if iscontainer(bk) && !isempty(skipnull(bk.blocks))
                bk.regmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
                wph = unsafe_load(IMGUISTYLE.WindowPadding.y)
                extraheight = isempty(bk.blocks) ? 2wph : MORESTYLE.Variables.ContainerBlockWindowPadding[2] + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2
                bk.regmax = [rmax[1], bk.regmin[2] + CImGui.GetFrameHeight() + extraheight]
            else
                bk.regmin, bk.regmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
            end
            CImGui.PopID()
            if CImGui.IsMouseDown(0)
                if CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) > 0.2 && !isdragging && mousein(bk) && isempty(dragblock)
                    push!(dragblock, bk)
                    isdragging = true
                    addmode = false
                    draggingid = presentid
                end
            else
                if isdragging && draggingid == presentid && mousein(bk) && isempty(dropblock)
                    push!(dropblock, bk)
                    isdragging = false
                end
            end
            !openpopup && mousein(bk) && CImGui.OpenPopupOnItemClick(id, 1)
            if CImGui.BeginPopup(id)
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertUp, " ", mlstr("Insert Above")))
                    newblock = addblockmenu(n)
                    isnothing(newblock) || insert!(blocks, i, newblock)
                    CImGui.EndMenu()
                end
                if iscontainer(bk) && isempty(skipnull(bk.blocks))
                    if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertInside, " ", mlstr("Insert Inside")), bk.level < 6)
                        newblock = addblockmenu(n)
                        isnothing(newblock) || push!(bk.blocks, newblock)
                        CImGui.EndMenu()
                    end
                end
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertDown, " ", mlstr("Insert Below")))
                    newblock = addblockmenu(n)
                    isnothing(newblock) || insert!(blocks, i + 1, newblock)
                    CImGui.EndMenu()
                end
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Convert to")))
                    newblock = addblockmenu(n)
                    if !(isnothing(newblock) || newblock isa typeof(bk))
                        if newblock isa StrideCodeBlock
                            iscontainer(bk) && (newblock.blocks = bk.blocks)
                        elseif iscontainer(newblock) && isinstr(newblock)
                            if bk isa StrideCodeBlock
                                newblock.blocks = bk.blocks
                            elseif iscontainer(bk) && isinstr(bk)
                                newblock.instrnm = bk.instrnm
                                newblock.addr = bk.addr
                                newblock.blocks = bk.blocks
                            elseif isinstr(bk)
                                newblock.instrnm = bk.instrnm
                                newblock.addr = bk.addr
                            end
                        elseif isinstr(newblock)
                            isinstr(bk) && (newblock.instrnm = bk.instrnm; newblock.addr = bk.addr)
                        end
                        blocks[i] = newblock
                    end
                    CImGui.EndMenu()
                end
                CImGui.Separator()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy"))) && (copyblock = deepcopy(blocks[i]))
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste"))) && insert!(blocks, i + 1, deepcopy(copyblock))
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && (blocks[i] = NullBlock())
                if typeof(bk) in [CodeBlock, StrideCodeBlock]
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Clear"))) && (bk.codes = "")
                end
                CImGui.EndPopup()
            end
        end
        if n == 1 && draggingid == presentid
            if isdragging && !CImGui.IsMouseDown(0)
                isdragging = false
            elseif !isdragging
                if !isempty(dragblock)
                    if isempty(dropblock)
                        CImGui.IsAnyItemHovered() || (addmode && CImGui.IsWindowHovered() && push!(blocks, only(dragblock)))
                    else
                        swapblock(blocks, only(dragblock), only(dropblock), addmode)
                    end
                end
                empty!(dragblock)
                empty!(dropblock)
            end
        end
        for (i, bk) in enumerate(blocks)
            bk isa NullBlock && deleteat!(blocks, i)
        end
    end
end #let

function addblockmenu(n)
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CodeBlock, " ", mlstr("CodeBlock"))) && return CodeBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.StrideCodeBlock, " ", mlstr("StrideCodeBlock"))) && return StrideCodeBlock(level=n)
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.BranchBlock, " ", mlstr("BranchBlock"))) && return BranchBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SweepBlock, " ", mlstr("SweepBlock"))) && return SweepBlock(level=n)
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.FreeSweepBlock, " ", mlstr("FreeSweepBlock"))) && return FreeSweepBlock(level=n)
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SettingBlock, " ", mlstr("SettingBlock"))) && return SettingBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadingBlock, " ", mlstr("ReadingBlock"))) && return ReadingBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.WriteBlock, " ", mlstr("WriteBlock"))) && return WriteBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.QueryBlock, " ", mlstr("QueryBlock"))) && return QueryBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadBlock, " ", mlstr("ReadBlock"))) && return ReadBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.FeedbackBlock, " ", mlstr("FeedbackBlock"))) && return FeedbackBlock()
    return nothing
end

function swapblock(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock, dropbk::AbstractBlock, addmode)
    (dragbk == dropbk || isininnerblocks(dropbk, dragbk)) && return
    disable_drag(blocks, dragbk)
    if iscontainer(dropbk) && unsafe_load(CImGui.GetIO().KeyCtrl)
        push!(dropbk.blocks, dragbk)
        return
    end
    insert_drop(blocks, dragbk, dropbk, addmode)
end

function isininnerblocks(dropbk::AbstractBlock, dragbk::AbstractBlock)
    if iscontainer(dragbk)
        return dropbk in dragbk.blocks || true in [isininnerblocks(dropbk, bk) for bk in dragbk.blocks]
    else
        return false
    end
end

function disable_drag(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock)
    for (i, bk) in enumerate(blocks)
        bk == dragbk && (blocks[i] = NullBlock(); return true)
        iscontainer(bk) && disable_drag(bk.blocks, dragbk) && return true
    end
    return false
end

function insert_drop(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock, dropbk::AbstractBlock, addmode)
    for (i, bk) in enumerate(blocks)
        bk == dropbk && (insert!(blocks, addmode ? i + 1 : i, dragbk); return true)
        iscontainer(bk) && insert_drop(bk.blocks, dragbk, dropbk, addmode) && return true
    end
    return false
end