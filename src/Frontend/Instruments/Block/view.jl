function view(bk::CodeBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.BeginChild("##CodeBlockViewer", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.CodeBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(bk.codes, (-1, 0))
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function view(bk::StrideCodeBlock)
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
    CImGui.BeginChild("##StrideCodeBlockViewer", (Float32(0), bkh), true)
    CImGui.PopStyleVar()
    ColoredButton(
        MORESTYLE.Icons.StrideCodeBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.nohandler ? MORESTYLE.Colors.StrideCodeBlockBorder : MORESTYLE.Colors.BlockIcons
    ) && (bk.hideblocks ⊻= true)
    CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(bk.codes, (-1, 0))
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
    bk.hideblocks || isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar(2)
end

function view(bk::BranchBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.BeginChild("##BranchBlockViewer", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.BranchBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(bk.codes, (-1, 0))
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function view(bk::SweepBlock)
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
    CImGui.BeginChild("##SweepBlockViewer", (Float32(0), bkh), true)
    CImGui.PopStyleVar()
    instrnm = bk.instrnm
    addr = bk.addr
    quantity = @trypass INSTRCONF[bk.instrnm].quantities[bk.quantity].alias ""
    Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
        INSTRCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
    ColoredButton(
        bk.rangemark == "" ? MORESTYLE.Icons.SweepBlock : bk.rangemark;
        size=length(bk.rangemark) < 3 ? (CImGui.GetFrameHeight(), Cfloat(0)) : (0, 0),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", instrnm,
            "\t", mlstr("address"), ": ", addr,
            "\t", mlstr("sweep"), ": ", quantity,
            "\t", mlstr("step"), ": ", bk.step, U,
            "\t", mlstr("stop"), ": ", bk.stop, U,
            "\t", mlstr("delay"), ": ", bk.delay
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
    bk.hideblocks || isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar(3)
end

function view(bk::FreeSweepBlock)
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
    CImGui.BeginChild("##FreeSweepBlockViewer", (Float32(0), bkh), true)
    CImGui.PopStyleVar()
    instrnm = bk.instrnm
    addr = bk.addr
    quantity = @trypass INSTRCONF[bk.instrnm].quantities[bk.quantity].alias ""
    Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
        INSTRCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
    ColoredButton(
        MORESTYLE.Icons.FreeSweepBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", instrnm,
            "\t", mlstr("address"), ": ", addr,
            "\t", mlstr("sweep"), ": ", quantity,
            "\t", mlstr("stop"), ": ", bk.mode, " ", bk.stop, U,
            "\t", mlstr("delay"), ": ", bk.delay,
            "\t", mlstr("δ"), ": ", bk.delta,
            "\t", mlstr("duration"), ": ", bk.duration
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
    bk.hideblocks || isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar(3)
end

function view(bk::SettingBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.BeginChild("##SettingBlockViewer", (Float32(0), bkheight(bk)), true)
    instrnm = bk.instrnm
    addr = bk.addr
    quantity = @trypass INSTRCONF[bk.instrnm].quantities[bk.quantity].alias ""
    Ut = if haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity)
        INSTRCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
    ColoredButton(
        MORESTYLE.Icons.SettingBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", instrnm,
            "\t", mlstr("address"), ": ", addr,
            "\t", bk.ischeck ? mlstr("check") : "", " ", mlstr("set"), ": ", quantity,
            "\t", mlstr("set value"), ": ", bk.setvalue, U
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function view(bk::ReadingBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, bk.isasync ? MORESTYLE.Variables.BlockBorderSize : 1)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.BeginChild("##ReadingBlockViewer", (Float32(0), bkheight(bk)), true)
    quantity = @trypass INSTRCONF[bk.instrnm].quantities[bk.quantity].alias ""
    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    ColoredButton(
        MORESTYLE.Icons.ReadingBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("read"), ": ", quantity,
            "\t", mlstr("index"), ": ", bk.index,
            "\t", mlstr("mark"), ": ", bk.mark
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.EndChild()
    CImGui.PopStyleColor()
    CImGui.PopStyleVar(2)
end

function view(bk::WriteBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        bk.isasync ? MORESTYLE.Colors.BlockAsyncBorder : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
    )
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, bk.isasync ? MORESTYLE.Variables.BlockBorderSize : 1)
    CImGui.BeginChild("##WriteBlockViewer", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.WriteBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("command"), ": ", bk.cmd
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleColor()
    CImGui.PopStyleVar(2)
end

function view(bk::QueryBlock)
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
    CImGui.BeginChild("##QueryBlockViewer", (Float32(0), bkheight(bk)), true)
    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    ColoredButton(
        MORESTYLE.Icons.QueryBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("command"), ": ", bk.cmd,
            "\t", mlstr("index"), ": ", bk.index,
            "\t", mlstr("mark"), ": ", bk.mark
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.EndChild()
    CImGui.PopStyleColor()
    CImGui.PopStyleVar(2)
end

function view(bk::ReadBlock)
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
    CImGui.BeginChild("##ReadBlockViewer", (Float32(0), bkheight(bk)), true)
    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    ColoredButton(
        MORESTYLE.Icons.ReadBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("index"), ": ", bk.index,
            "\t", mlstr("mark"), ": ", bk.mark
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.EndChild()
    CImGui.PopStyleColor()
    CImGui.PopStyleVar(2)
end

function view(bk::FeedbackBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameBorderSize, 0)
    CImGui.BeginChild("##FeedbackBlockViewer", (Float32(0), bkheight(bk)), true)
    ColoredButton(
        MORESTYLE.Icons.FeedbackBlock; size=(CImGui.GetFrameHeight(), Cfloat(0)),
        colbt=[0, 0, 0, 0], colbta=[0, 0, 0, 0], colbth=[0, 0, 0, 0],
        coltxt=MORESTYLE.Colors.BlockIcons
    )
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("action"), ": ", bk.action
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function view(blocks::Vector{AbstractBlock})
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.NormalBlockBorder)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
    for (i, bk) in enumerate(blocks)
        bk isa NullBlock && continue
        CImGui.PushID(i)
        view(bk)
        CImGui.PopID()
    end
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end