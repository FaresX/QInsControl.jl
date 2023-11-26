@option mutable struct QuantityWidgetOption
    uitype::String = "text"
    text::String = ""
    textsize::String = "normal"
    textscale::Cfloat = 1
    textinside::Bool = true
    itemsize::Vector{Cfloat} = [0, 0]
    rounding::Cfloat = 4
    grabrounding::Cfloat = 6
    bdrounding::Cfloat = 0
    bdthickness::Cfloat = 0
    localposx::Cfloat = 0
    spacingw::Cfloat = -1
    bindingidx::Cint = 1
    bindingonoff::Vector{Cint} = [1, 2]
    textcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 1.000]
    hintcolor::Vector{Cfloat} = [0.600, 0.600, 0.600, 1.000]
    checkedcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 1.000]
    bgcolor::Vector{Cfloat} = [0.951, 0.951, 0.951, 1.000]
    oncolor::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
    offcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.400]
    hoveredcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.400]
    activecolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.670]
    rectcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.000]
end

@option mutable struct QuantityWidget
    name::String = ""
    alias::String = ""
    qtype::String = "read"
    numoptvs::Cint = 0
    options::QuantityWidgetOption = QuantityWidgetOption()
end

@option mutable struct InstrWidget
    instrnm::String = "VirtualInstr"
    name::String = "widget 1"
    cols::Vector{Cint} = []
    showcolbd::Bool = true
    qtws::Vector{QuantityWidget} = []
    groups::Vector{Tuple{Int,Int}} = []
    dividedidx::Vector{Vector{Int}} = []
    windowsize::Vector{Cfloat} = [600, 600]
    coloffsets::Matrix{Cfloat} = Matrix{Cfloat}(undef, 0, 0)
    rowh::Vector{Cfloat} = []
end

const INSWCONF = OrderedDict{String,Vector{InstrWidget}}() #仪器注册表

function edit(qtw::QuantityWidget, insbuf::InstrBuffer, instrnm, addr)
    if haskey(insbuf.quantities, qtw.name)
        qt = insbuf.quantities[qtw.name]
        edit(qtw.options, qt, instrnm, addr, Val(Symbol(qtw.options.uitype)))
    elseif qtw.name == "_Text_"
        qtw.options.textsize == "big" && CImGui.PushFont(PLOTFONT)
        originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
        CImGui.SetWindowFontScale(qtw.options.textscale)
        ColoredButtonRect(
            qtw.options.text;
            size=qtw.options.itemsize,
            colbt=qtw.options.bgcolor,
            colbth=qtw.options.hoveredcolor,
            colbta=qtw.options.activecolor,
            coltxt=qtw.options.textcolor,
            colrect=qtw.options.rectcolor,
            rounding=qtw.options.rounding,
            bdrounding=qtw.options.bdrounding,
            thickness=qtw.options.bdthickness
        )
        qtw.options.textsize == "big" && CImGui.PopFont()
        CImGui.SetWindowFontScale(originscale)
    elseif qtw.name == "_SameLine_"
        CImGui.SameLine(qtw.options.localposx, qtw.options.spacingw)
    end
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, _, _, ::Val)
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    ColoredButtonRect(
        qt.read;
        size=opts.itemsize,
        colbt=opts.bgcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:inputstep})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    @c ColoredInputTextWithHintRSZ(
        "##step", mlstr("step"), &qt.step;
        width=opts.itemsize[1],
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        coltxt=opts.textcolor,
        colhint=opts.hintcolor,
        colrect=opts.rectcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:inputstop})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    @c ColoredInputTextWithHintRSZ("##stop", mlstr("stop"), &qt.stop;
        width=opts.itemsize[1],
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        coltxt=opts.textcolor,
        colhint=opts.hintcolor,
        colrect=opts.rectcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:dragdelay})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    @c ColoredDragWidget(
        CImGui.DragFloat,
        "##delay", &qt.delay, 0.01, 0, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp;
        width=opts.itemsize[1],
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, instrnm, addr, ::Val{:ctrlsweep})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    ColoredButtonRect(
        mlstr(qt.issweeping ? " Stop " : " Start ");
        size=opts.itemsize,
        colbt=opts.bgcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    ) && (qt.issweeping ? qt.issweeping = false : apply!(qt, instrnm, addr))
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, _, _, ::Val{:inputset})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    @c ColoredInputTextWithHintRSZ("##set", mlstr("set"), &qt.set;
        width=opts.itemsize[1],
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        coltxt=opts.textcolor,
        colhint=opts.hintcolor,
        colrect=opts.rectcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:ctrlset})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    ColoredButtonRect(
        mlstr(" Confirm ");
        size=opts.itemsize,
        colbt=opts.bgcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    ) && apply!(qt, instrnm, addr)
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:combo})
    presentv = qt.optkeys[qt.optedidx]
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if @c ColoredCombo(
        qt.alias, &presentv, qt.optkeys;
        width=opts.itemsize[1],
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor
    )
        qt.optedidx = findfirst(==(presentv), qt.optkeys)
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:radio})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if @c ColoredRadioButton(
        qt.optkeys[opts.bindingidx], &qt.optedidx, opts.bindingidx;
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colckm=opts.checkedcolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor
    )
        qt.optedidx = opts.bindingidx
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:slider})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if @c ColoredSlider(
        CImGui.SliderInt,
        qt.optkeys[qt.optedidx], &qt.optedidx, 1, length(qt.optvalues), "";
        width=opts.itemsize[1],
        rounding=opts.rounding,
        grabrounding=opts.grabrounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colgrab=opts.checkedcolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor
    )
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:vslider})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if @c ColoredVSlider(
        CImGui.VSliderInt,
        stcstr(opts.textinside ? "##" : "", qt.optkeys[qt.optedidx]),
        &qt.optedidx, 1, length(qt.optvalues), opts.textinside ? qt.optkeys[qt.optedidx] : "";
        size=opts.itemsize,
        rounding=opts.rounding,
        grabrounding=opts.grabrounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colgrab=opts.checkedcolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor
    )
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:toggle})
    ison = qt.optedidx == opts.bindingonoff[1]
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if @c ToggleButtonRect(
        qt.optkeys[opts.bindingonoff[ison ? 1 : 2]], &ison;
        size=opts.itemsize,
        colon=opts.oncolor,
        coloff=opts.offcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    )
        qt.optedidx = opts.bindingonoff[ison ? 1 : 2]
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(insw::InstrWidget, insbuf::InstrBuffer, addr, p_open)
    CImGui.SetNextWindowSize(insw.windowsize)
    if CImGui.Begin(stcstr(INSCONF[insw.instrnm].conf.icon, " ", insw.instrnm, " ", addr, " ", insw.name), p_open)
        CImGui.BeginChild(stcstr(insw.instrnm, " ", insw.name, " ", addr))
        l = length(insw.dividedidx)
        n = insw.cols
        m = ceil(Int, l / n)
        n = m == 1 ? l : n
        lh = length(insw.rowh)
        lh == m || (resize!(insw.rowh, m); lh < m && (insw.rowh[lh+1:end] .= 0))
        szco = size(insw.coloffsets)
        if szco != (m, n)
            newco = zeros(Cfloat, m, n)
            coverrange = (1:min(szco[1], m), 1:min(szco[2], n))
            newco[coverrange...] = insw.coloffsets[coverrange...]
            insw.coloffsets = newco
        end
        for i in 1:m
            CImGui.BeginChild(stcstr("row", i), (Cfloat(0), insw.rowh[i]))
            CImGui.Columns(insw.cols, C_NULL, insw.showcolbd)
            for j in 1:n
                idx = (i - 1) * n + j
                if idx <= l
                    insw.showcolbd || CImGui.SetColumnOffset(j, insw.coloffsets[i, j])
                    CImGui.BeginGroup()
                    for k in insw.dividedidx[idx]
                        CImGui.PushID(k)
                        edit(insw.qtws[k], insbuf, insw.instrnm, addr)
                        CImGui.PopID()
                    end
                    CImGui.EndGroup()
                    CImGui.NextColumn()
                    insw.coloffsets[i, j] = CImGui.GetColumnOffset(j)
                end
            end
            CImGui.EndChild()
        end
        CImGui.EndChild()
        if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
            CImGui.IsMouseClicked(1) && CImGui.OpenPopup(stcstr("edit widget", insw.instrnm, insw.name))
        end
        if CImGui.BeginPopup(stcstr("edit widget", insw.instrnm, insw.name))
            @c CImGui.Checkbox(mlstr("show column border"), &insw.showcolbd)
            CImGui.EndPopup()
        end
    end
    CImGui.IsWindowCollapsed() || (insw.windowsize .= CImGui.GetWindowSize())
    CImGui.End()
end

function modify(qtw::QuantityWidget)
    CImGui.Button(stcstr(qtw.alias, " ", qtw.options.uitype), (-1, 0))
end


function modify(insw::InstrWidget)
    CImGui.BeginChild(stcstr(insw.instrnm, insw.name))
    CImGui.Columns(insw.cols, C_NULL, false)
    dividegroups!(insw)
    delete_i = 0
    for idx in insw.dividedidx
        lidx = length(idx)
        gw = 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight() * lidx +
             (lidx - 1) * unsafe_load(IMGUISTYLE.ItemSpacing.y)
        CImGui.BeginChild(idx[1], (Cfloat(0), lidx == 1 ? CImGui.GetFrameHeight() : gw), lidx != 1)
        CImGui.BeginGroup()
        for i in idx
            CImGui.PushID(i)
            qtw = insw.qtws[i]
            modify(qtw)
            if CImGui.BeginPopupContextItem()
                CImGui.PushID(qtw.alias)
                optionsmenu(qtw)
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InsertDown, " ", mlstr("Split Group")), C_NULL, false, lidx != 1)
                    gi, gin = whichg(i, insw.groups)
                    if gi != 0
                        deleteat!(insw.groups, gi)
                        push!(insw.groups, (gin[1], i - 1))
                        push!(insw.groups, (i, gin[2]))
                        dividegroups!(insw)
                    end
                end
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("delete"))) && (delete_i = i)
                CImGui.PopID()
                CImGui.EndPopup()
            end
            CImGui.Indent()
            if CImGui.BeginDragDropSource(0)
                @c CImGui.SetDragDropPayload("Swap Widgets", &i, sizeof(Cint))
                CImGui.Text(qtw.alias)
                CImGui.EndDragDropSource()
            end
            if CImGui.BeginDragDropTarget()
                payload = CImGui.AcceptDragDropPayload("Swap Widgets")
                if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                    payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                    if i != payload_i
                        if unsafe_load(CImGui.GetIO().KeyCtrl)
                            gi, gin = whichg(i, insw.groups)
                            push!(insw.groups, gi == 0 ? (i, i + 1) : payload_i < i ? (gin[1]-1, gin[2]) : (gin[1], gin[2]+1))
                            insert!(insw.qtws, i, insw.qtws[payload_i])
                            deleteat!(insw.qtws, payload_i < i ? payload_i : payload_i + 1)
                        else
                            insw.qtws[i] = insw.qtws[payload_i]
                            insw.qtws[payload_i] = qtw
                        end
                        dividegroups!(insw)
                    end
                end
                CImGui.EndDragDropTarget()
            end
            CImGui.Unindent()
            CImGui.PopID()
        end
        CImGui.EndGroup()
        CImGui.EndChild()
        CImGui.NextColumn()
    end
    delete_i == 0 || (deleteat!(insw.qtws, delete_i); dividegroups!(insw))
    CImGui.EndChild()
    if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
        CImGui.OpenPopupOnItemClick(stcstr("modify widget", insw.instrnm, insw.name))
    end
    if CImGui.BeginPopup(stcstr("modify widget", insw.instrnm, insw.name))
        if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add")))
            CImGui.MenuItem(mlstr("Text")) && push!(insw.qtws, QuantityWidget(name="_Text_", alias=mlstr("Text")))
            CImGui.MenuItem(mlstr("SameLine")) && push!(insw.qtws, QuantityWidget(name="_SameLine_", alias=mlstr("SameLine")))
            if CImGui.BeginMenu(mlstr("Sweep Quantity"))
                if haskey(INSCONF, insw.instrnm)
                    for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                        qt.type == "sweep" || continue
                        if CImGui.MenuItem(qtnm)
                            push!(insw.qtws, QuantityWidget(name=qtnm, alias=qt.alias, qtype="sweep"))
                        end
                    end
                end
                CImGui.EndMenu()
            end
            if CImGui.BeginMenu(mlstr("Set Quantity"))
                if haskey(INSCONF, insw.instrnm)
                    for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                        qt.type == "set" || continue
                        if CImGui.MenuItem(qtnm)
                            push!(
                                insw.qtws,
                                QuantityWidget(name=qtnm, alias=qt.alias, qtype="set", numoptvs=length(qt.optvalues))
                            )
                        end
                    end
                end
                CImGui.EndMenu()
            end
            if CImGui.BeginMenu(mlstr("Read Quantity"))
                if haskey(INSCONF, insw.instrnm)
                    for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                        qt.type == "read" || continue
                        CImGui.MenuItem(qtnm) && push!(insw.qtws, QuantityWidget(name=qtnm, alias=qt.alias))
                    end
                end
                CImGui.EndMenu()
            end
            CImGui.EndMenu()
        end
        CImGui.PushItemWidth(12CImGui.GetFontSize())
        @c CImGui.DragInt(
            mlstr("display columns"),
            &insw.cols,
            1.0, 1, 24, "%d",
            CImGui.ImGuiSliderFlags_AlwaysClamp
        )
        CImGui.PopItemWidth()
        CImGui.PushItemWidth(12CImGui.GetFontSize())
        @c InputTextRSZ(mlstr("Rename"), &insw.name)
        CImGui.PopItemWidth()
        CImGui.EndPopup()
    end
end

let
    sweepuitypes = ["text", "inputstep", "inputstop", "dragdelay", "ctrlsweep"]
    setuitypesall = ["text", "inputset", "ctrlset", "combo", "radio", "slider", "vslider", "toggle"]
    setuitypesnoopts = ["text", "inputset", "ctrlset"]
    setuitypesno2opts = ["text", "inputset", "ctrlset", "combo", "radio", "slider", "vslider"]
    readuitypes = ["text"]
    textsizes = ["normal", "big"]
    global function optionsmenu(qtw::QuantityWidget)
        @c ComBoS(
            mlstr("UI type"),
            &qtw.options.uitype,
            if qtw.qtype == "sweep"
                sweepuitypes
            elseif qtw.qtype == "set"
                if qtw.numoptvs == 0
                    setuitypesnoopts
                elseif qtw.numoptvs == 2
                    setuitypesall
                else
                    setuitypesall
                end
            else
                readuitypes
            end
        )
        if CImGui.CollapsingHeader(mlstr("Options"))
            @c InputTextRSZ("Text", &qtw.options.text)
            @c ComBoS(mlstr("Text Size"), &qtw.options.textsize, textsizes)
            @c CImGui.DragFloat(
                mlstr("Text Scale"),
                &qtw.options.textscale,
                0.1, 0.1, 2, "%.1f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            @c CImGui.Checkbox("Text Inside", &qtw.options.textinside)
            CImGui.DragFloat2(mlstr("Btton Size"), qtw.options.itemsize)
            @c CImGui.DragFloat(
                mlstr("Frame Rounding"),
                &qtw.options.rounding,
                1, 0, 60, "%.3f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            @c CImGui.DragFloat(
                mlstr("Grab Rounding"),
                &qtw.options.grabrounding,
                1, 0, 60, "%.3f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            @c CImGui.DragFloat(
                mlstr("Border Rounding"),
                &qtw.options.bdrounding,
                1, 0, 60, "%.3f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            @c CImGui.DragFloat(
                mlstr("Border Thickness"),
                &qtw.options.bdthickness,
                1, 0, 60, "%.3f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            @c CImGui.SliderInt("Binding Index to RadioButton", &qtw.options.bindingidx, 1, qtw.numoptvs)
            CImGui.SliderInt2("Bingding Index to ON/OFF", qtw.options.bindingonoff, 1, qtw.numoptvs)
            @c CImGui.DragFloat(mlstr("Local Position X"), &qtw.options.localposx)
            @c CImGui.DragFloat(mlstr("Spacing Width"), &qtw.options.spacingw)
            CImGui.ColorEdit4(
                stcstr(mlstr("Text Color")),
                qtw.options.textcolor,
                CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
            )
            CImGui.ColorEdit4(
                stcstr(mlstr("Hint Text Color")),
                qtw.options.hintcolor,
                CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
            )
            CImGui.ColorEdit4(
                stcstr(mlstr("Background Color")),
                qtw.options.bgcolor,
                CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
            )
            CImGui.ColorEdit4(
                stcstr(mlstr("Toggle-on Color")),
                qtw.options.oncolor,
                CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
            )
            CImGui.ColorEdit4(
                stcstr(mlstr("Toggle-off Color")),
                qtw.options.offcolor,
                CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
            )
            CImGui.ColorEdit4(
                stcstr(mlstr("Hovered Button Color")),
                qtw.options.hoveredcolor,
                CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
            )
            CImGui.ColorEdit4(
                stcstr(mlstr("Active Button Color")),
                qtw.options.activecolor,
                CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
            )
            CImGui.ColorEdit4(
                stcstr(mlstr("Border Color")),
                qtw.options.rectcolor,
                CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
            )
        end
    end
end

function checkgroups!(insw::InstrWidget)
    headidx = [g[1] for g in insw.groups]
    if !issorted(headidx)
        sp = sortperm(headidx)
        insw.groups = insw.groups[sp]
    end
    ckedgps = []
    for g in insw.groups
        g[2] > g[1] > 0 || continue
        lg = length(insw.qtws)
        g[1] >= lg && continue
        if isempty(ckedgps) || ckedgps[end][2] < g[1]
            push!(ckedgps, (g[1], min(g[2], lg)))
        elseif g[1] <= ckedgps[end][2] < g[2]
            lastg = pop!(ckedgps)
            push!(ckedgps, (lastg[1], min(g[2], lg)))
        end
    end
    insw.groups = ckedgps
end

function dividegroups!(insw::InstrWidget)
    if isempty(insw.groups)
        insw.dividedidx = [[i] for i in eachindex(insw.qtws)]
    else
        checkgroups!(insw)
        gcopy = copy(insw.groups)
        empty!(insw.dividedidx)
        for i in eachindex(insw.qtws)
            if isempty(gcopy) || i < gcopy[1][1]
                push!(insw.dividedidx, [i])
            elseif i == gcopy[1][1]
                push!(insw.dividedidx, collect(gcopy[1][1]:gcopy[1][2]))
            elseif i == gcopy[1][2]
                popfirst!(gcopy)
            end
        end
    end
end

function whichg(i, groups)
    for (j, g) in enumerate(groups)
        g[1] <= i <= g[2] && return j, g
    end
    return 0, (0, 0)
end
