@option mutable struct QuantityWidgetOption
    uitype::String = "read"
    globaloptions::Bool = true
    allowoverlap::Bool = false
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
    cursorscreenpos::Vector{Cfloat} = [0, 0]
    bindingidx::Cint = 1
    bindingonoff::Vector{Cint} = [1, 2]
    textcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 1.000]
    hintcolor::Vector{Cfloat} = [0.600, 0.600, 0.600, 1.000]
    checkedcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 1.000]
    bgcolor::Vector{Cfloat} = [0.951, 0.951, 0.951, 1.000]
    combobtcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.400]
    oncolor::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
    offcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.400]
    hoveredcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.800]
    activecolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.670]
    rectcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.000]
    grabcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.780]
    grabactivecolor::Vector{Cfloat} = [0.460, 0.540, 0.800, 0.600]
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
    qtws::Vector{Vector{QuantityWidget}} = []
    windowsize::Vector{Cfloat} = [600, 600]
    windowbgcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    options::QuantityWidgetOption = QuantityWidgetOption()
end

const INSWCONF = OrderedDict{String,Vector{InstrWidget}}() #仪器注册表

function copyvars!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[1:15]
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function copycolors!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[16:end]
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function edit(qtw::QuantityWidget, insbuf::InstrBuffer, instrnm, addr, gopts::QuantityWidgetOption)
    opts = qtw.options.globaloptions ? gopts : qtw.options
    qtw.options.globaloptions && copyvars!(opts, qtw.options)
    opts.cursorscreenpos == [0, 0] || CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ opts.cursorscreenpos)
    if haskey(insbuf.quantities, qtw.name)
        qt = insbuf.quantities[qtw.name]
        edit(opts, qt, instrnm, addr, Val(Symbol(qtw.options.uitype)))
    elseif qtw.name == "_Text_"
        opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
        originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
        CImGui.SetWindowFontScale(opts.textscale)
        ColoredButtonRect(
            qtw.alias;
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
    elseif qtw.name == "_SameLine_"
        CImGui.SameLine(opts.localposx, opts.spacingw)
    end
    opts.allowoverlap && CImGui.SetItemAllowOverlap()
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:read})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if ColoredButtonRect(
        qt.showval;
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
        if qt.enable && addr != ""
            fetchdata = refresh_qt(instrnm, addr, qt.name)
            isnothing(fetchdata) || (qt.read = fetchdata)
            updatefront!(qt)
        end
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, _, _, ::Val{:unit})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if ColoredButtonRect(
        qt.showU;
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
        Us = CONF.U[qt.utype]
        qt.uindex = (qt.uindex + 1) % length(Us)
        qt.uindex == 0 && (qt.uindex = length(Us))
        getvalU!(qt)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:readunit})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if ColoredButtonRect(
        stcstr(qt.showval, " ", qt.showU);
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
        if qt.enable && addr != ""
            fetchdata = refresh_qt(instrnm, addr, qt.name)
            isnothing(fetchdata) || (qt.read = fetchdata)
            updatefront!(qt)
        end
    end
    if CImGui.IsItemClicked(2)
        Us = CONF.U[qt.utype]
        qt.uindex = (qt.uindex + 1) % length(Us)
        qt.uindex == 0 && (qt.uindex = length(Us))
        getvalU!(qt)
    end
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
        "##delay", &qt.delay, 0.01, 0.01, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp;
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
    @c(ToggleButtonRect(
            mlstr(qt.issweeping ? " Stop " : " Start "), &qt.issweeping;
            size=opts.itemsize,
            rounding=opts.rounding,
            bdrounding=opts.bdrounding,
            thickness=opts.bdthickness,
            colon=opts.oncolor,
            coloff=opts.offcolor,
            colbth=opts.hoveredcolor,
            colbta=opts.activecolor,
            coltxt=opts.textcolor,
            colrect=opts.rectcolor,
        )) && qt.issweeping && apply!(qt, instrnm, addr)
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    qt.issweeping && updatefront!(qt)
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
    ) && (apply!(qt, instrnm, addr); updatefront!(qt))
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:combo})
    presentv = qt.optkeys[qt.optedidx]
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if @c ColoredCombo(
        stcstr("##", qt.alias), &presentv, qt.optkeys;
        width=opts.itemsize[1],
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colbt=opts.combobtcolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor
    )
        qt.optedidx = findfirst(==(presentv), qt.optkeys)
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
        updatefront!(qt)
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
        updatefront!(qt)
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
        stcstr(opts.textinside ? "##" : "", qt.optkeys[qt.optedidx]),
        &qt.optedidx, 1, length(qt.optvalues), opts.textinside ? qt.optkeys[qt.optedidx] : "";
        width=opts.itemsize[1],
        rounding=opts.rounding,
        grabrounding=opts.grabrounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colgrab=opts.grabcolor,
        colgraba=opts.grabactivecolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor
    )
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
        updatefront!(qt)
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
        colgrab=opts.grabcolor,
        colgraba=opts.grabactivecolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.rectcolor
    )
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
        updatefront!(qt)
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
        updatefront!(qt)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
end

function edit(insw::InstrWidget, insbuf::InstrBuffer, addr, p_open, id)
    CImGui.SetNextWindowSize(insw.windowsize)
    CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, insw.windowbgcolor)
    if CImGui.Begin(
        stcstr(
            INSCONF[insw.instrnm].conf.icon, " ", insw.instrnm, " ", addr, " ", insw.name,
            "###", insw.instrnm, addr, id
        ),
        p_open,
        addr == "" ? CImGui.ImGuiWindowFlags_NoDocking : 0
    )
        CImGui.BeginChild(stcstr(insw.instrnm, " ", insw.name, " ", addr))
        for (i, qtwg) in enumerate(insw.qtws)
            CImGui.PushID(i)
            length(qtwg) == 1 || CImGui.BeginGroup()
            for (j, qtw) in enumerate(qtwg)
                CImGui.PushID(j)
                edit(qtw, insbuf, insw.instrnm, addr, insw.options)
                CImGui.PopID()
            end
            length(qtwg) == 1 || CImGui.EndGroup()
            CImGui.PopID()
        end
        CImGui.EndChild()
        if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
            CImGui.IsMouseClicked(1) && CImGui.OpenPopup(stcstr("edit widget", insw.instrnm, insw.name))
        end
    end
    CImGui.IsWindowCollapsed() || (insw.windowsize .= CImGui.GetWindowSize())
    CImGui.End()
    CImGui.PopStyleColor()
end

function modify(qtw::QuantityWidget, id)
    if qtw.name == "_SameLine_"
        CImGui.SameLine()
        CImGui.Button("Same\nLine")
    elseif qtw.name == "_Text_"
        CImGui.Button(stcstr(" Text", " \n ", qtw.alias, "###", id))
    else
        CImGui.Button(stcstr(qtw.alias, "\n", qtw.options.uitype))
    end
end

let
    copiedopts::Ref{QuantityWidgetOption} = QuantityWidgetOption()
    global function modify(insw::InstrWidget)
        insert_ij = ((0, 0), (:before, QuantityWidget()))
        delete_ij = (0, 0)
        split_ij = (0, 0)
        swap_idx12 = (0, 0)
        group_idx12 = (0, 0)
        openmodw = false
        CImGui.BeginChild(stcstr(insw.instrnm, insw.name))
        for (i, qtwg) in enumerate(insw.qtws)
            CImGui.PushID(i)
            lqtwg = length(qtwg)
            btcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
            bthcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, isodd(i) ? btcol : bthcol)
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, isodd(i) ? bthcol : btcol)
            lqtwg == 1 && only(qtwg).name == "_SameLine_" && CImGui.SameLine()
            CImGui.BeginGroup()
            for (j, qtw) in enumerate(qtwg)
                CImGui.PushID(j)
                j > 1 && qtwg[j-1].name == "_SameLine_" && CImGui.SameLine()
                idx = sum(length.(@view(insw.qtws[1:i-1]))) + j
                modify(qtw, idx)
                if CImGui.BeginPopupContextItem()
                    CImGui.PushID(idx)
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy Options")))
                        copiedopts[] = deepcopy(qtw.options)
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste Options")))
                        qtw.options = deepcopy(copiedopts[])
                    end
                    newqtw = addmenu(insw, true; mode=:before)
                    isnothing(newqtw) || isnothing(newqtw[2]) || (insert_ij = ((i, j), newqtw))
                    newqtw = addmenu(insw, true; mode=:after)
                    isnothing(newqtw) || isnothing(newqtw[2]) || (insert_ij = ((i, j), newqtw))
                    newqtw = addmenu(insw, true; mode=:beforeg)
                    isnothing(newqtw) || isnothing(newqtw[2]) || (insert_ij = ((i, j), newqtw))
                    newqtw = addmenu(insw, true; mode=:afterg)
                    isnothing(newqtw) || isnothing(newqtw[2]) || (insert_ij = ((i, j), newqtw))
                    convertmenu(insw, i, j)
                    if CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.InsertDown, " ", mlstr("Split Group")),
                        C_NULL,
                        false,
                        lqtwg != 1
                    )
                        split_ij = (i, j)
                    end
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("delete"))) && (delete_ij = (i, j))
                    optionsmenu(qtw)
                    CImGui.PopID()
                    CImGui.EndPopup()
                end
                CImGui.Indent()
                if CImGui.BeginDragDropSource(0)
                    @c CImGui.SetDragDropPayload("Swap Widgets", &idx, sizeof(Cint))
                    CImGui.Text(qtw.alias)
                    CImGui.EndDragDropSource()
                end
                if CImGui.BeginDragDropTarget()
                    payload = CImGui.AcceptDragDropPayload("Swap Widgets")
                    if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                        payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                        if idx != payload_i
                            if unsafe_load(CImGui.GetIO().KeyCtrl)
                                group_idx12 = (payload_i, idx)
                            else
                                swap_idx12 = (payload_i, idx)
                            end
                        end
                    end
                    CImGui.EndDragDropTarget()
                end
                CImGui.Unindent()
                if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
                    CImGui.IsMouseClicked(1) && (openmodw = true)
                end
                CImGui.PopID()
            end
            CImGui.EndGroup()
            lqtwg == 1 && only(qtwg).name == "_SameLine_" && CImGui.SameLine()
            CImGui.PopStyleColor(2)
            if i < length(insw.qtws)
                if !((lqtwg == 1 && only(qtwg).name == "_SameLine_") ||
                     (length(insw.qtws[i+1]) == 1 && only(insw.qtws[i+1]).name == "_SameLine_"))
                    CImGui.Separator()
                end
            end
            CImGui.PopID()
        end
        CImGui.EndChild()

        if insert_ij[1] != (0, 0)
            if insert_ij[2][1] == :before
                insert!(insw.qtws[insert_ij[1][1]], insert_ij[1][2], insert_ij[2][2])
            elseif insert_ij[2][1] == :after
                insert!(insw.qtws[insert_ij[1][1]], insert_ij[1][2] + 1, insert_ij[2][2])
            elseif insert_ij[2][1] == :beforeg
                insert!(insw.qtws, insert_ij[1][1], [insert_ij[2][2]])
            elseif insert_ij[2][1] == :afterg
                insert!(insw.qtws, insert_ij[1][1] + 1, [insert_ij[2][2]])
            end
        end
        if delete_ij != (0, 0)
            deleteat!(insw.qtws[delete_ij[1]], delete_ij[2])
            isempty(insw.qtws[delete_ij[1]]) && deleteat!(insw.qtws, delete_ij[1])
        end
        if split_ij != (0, 0)
            popqtwg = popat!(insw.qtws, split_ij[1])
            insert!(insw.qtws, split_ij[1], popqtwg[1:split_ij[2]-1])
            insert!(insw.qtws, split_ij[1] + 1, popqtwg[split_ij[2]:end])
            isempty(insw.qtws[split_ij[1]]) && deleteat!(insw.qtws, split_ij[1])
        end
        if swap_idx12 != (0, 0)
            spos = idxtoij(insw, swap_idx12[1])
            tpos = idxtoij(insw, swap_idx12[2])
            tqtw = insw.qtws[tpos[1]][tpos[2]]
            insw.qtws[tpos[1]][tpos[2]] = insw.qtws[spos[1]][spos[2]]
            insw.qtws[spos[1]][spos[2]] = tqtw
        end
        if group_idx12 != (0, 0)
            spos = idxtoij(insw, group_idx12[1])
            tpos = idxtoij(insw, group_idx12[2])
            insert!(insw.qtws[tpos[1]], tpos[2], insw.qtws[spos[1]][spos[2]])
            deleteat!(insw.qtws[spos[1]], spos[2])
            isempty(insw.qtws[spos[1]]) && deleteat!(insw.qtws, spos[1])
        end

        openmodw && CImGui.OpenPopup(stcstr("modify widget", insw.instrnm, insw.name))
        if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
            CImGui.OpenPopupOnItemClick(stcstr("modify widget", insw.instrnm, insw.name))
        end
        if CImGui.BeginPopup(stcstr("modify widget", insw.instrnm, insw.name))
            addmenu(insw)
            CImGui.EndPopup()
        end
    end
end

function addmenu(insw::InstrWidget, onqtw=false; mode=:addlastg)
    if CImGui.BeginMenu(
        stcstr(
            MORESTYLE.Icons.NewFile, " ",
            mlstr(
                if mode == :addlastg
                    "Add"
                elseif mode == :before
                    "Add Before"
                elseif mode == :after
                    "Add After"
                elseif mode == :beforeg
                    "Add Group Before"
                elseif mode == :afterg
                    "Add Group After"
                end
            )
        )
    )
        newqtw = nothing
        if CImGui.MenuItem(mlstr("Text"))
            newqtw = QuantityWidget(name="_Text_", alias="")
            onqtw || push!(insw.qtws, [newqtw])
        end
        if CImGui.MenuItem(mlstr("SameLine"))
            newqtw = QuantityWidget(name="_SameLine_", alias=mlstr("SameLine"))
            onqtw || push!(insw.qtws, [newqtw])
        end
        if CImGui.BeginMenu(mlstr("Sweep Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "sweep" || continue
                    if CImGui.MenuItem(qtnm)
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias, qtype="sweep")
                        onqtw || push!(insw.qtws, [newqtw])
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
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias, qtype="set", numoptvs=length(qt.optvalues))
                        onqtw || push!(insw.qtws, [newqtw])
                    end
                end
            end
            CImGui.EndMenu()
        end
        if CImGui.BeginMenu(mlstr("Read Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "read" || continue
                    if CImGui.MenuItem(qtnm)
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias)
                        onqtw || push!(insw.qtws, [newqtw])
                    end
                end
            end
            CImGui.EndMenu()
        end
        CImGui.EndMenu()
        return mode, newqtw
    end
end

function convertmenu(insw::InstrWidget, i, j)
    if CImGui.BeginMenu(
        stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Convert to")),
        insw.qtws[i][j].name ∉ ["_Text_", "_SameLine_"]
    )
        if CImGui.BeginMenu(mlstr("Sweep Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "sweep" || continue
                    if CImGui.MenuItem(qtnm)
                        insw.qtws[i][j] = QuantityWidget(
                            name=qtnm,
                            alias=qt.alias,
                            qtype="sweep",
                            options=insw.qtws[i][j].options
                        )
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
                        insw.qtws[i][j] = QuantityWidget(
                            name=qtnm,
                            alias=qt.alias,
                            qtype="set",
                            numoptvs=length(qt.optvalues),
                            options=insw.qtws[i][j].options
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
                    if CImGui.MenuItem(qtnm)
                        insw.qtws[i][j] = QuantityWidget(name=qtnm, alias=qt.alias, options=insw.qtws[i][j].options)
                    end
                end
            end
            CImGui.EndMenu()
        end
        CImGui.EndMenu()
    end
end

let
    sweepuitypes = ["read", "unit", "readunit", "inputstep", "inputstop", "dragdelay", "ctrlsweep"]
    setuitypesall = ["read", "unit", "readunit", "inputset", "ctrlset", "combo", "radio", "slider", "vslider", "toggle"]
    setuitypesnoopts = ["read", "unit", "readunit", "inputset", "ctrlset"]
    setuitypesno2opts = ["read", "unit", "readunit", "inputset", "ctrlset", "combo", "radio", "slider", "vslider"]
    readuitypes = ["text"]
    textsizes = ["normal", "big"]
    global function optionsmenu(qtw::QuantityWidget)
        if qtw.name != "_SameLine_" && CImGui.CollapsingHeader(mlstr("Variable Options"))
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
            @c CImGui.Checkbox(mlstr("Global Options"), &qtw.options.globaloptions)
            @c CImGui.Checkbox(mlstr("Allow Overlap"), &qtw.options.allowoverlap)
            qtw.name == "_Text_" && @c InputTextRSZ(mlstr("Text"), &qtw.alias)
            @c ComBoS(mlstr("Text Size"), &qtw.options.textsize, textsizes)
            @c CImGui.DragFloat(
                mlstr("Text Scale"),
                &qtw.options.textscale,
                0.1, 0.1, 2, "%.1f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            @c CImGui.Checkbox("Text Inside", &qtw.options.textinside)
            CImGui.DragFloat2(mlstr("Btton Size"), qtw.options.itemsize)
            CImGui.DragFloat2(mlstr("CursorScreenPos"), qtw.options.cursorscreenpos)
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
        end
        if qtw.qtype == "set" && CImGui.CollapsingHeader(mlstr("Binding Options"))
            @c CImGui.SliderInt("Binding Index to RadioButton", &qtw.options.bindingidx, 1, qtw.numoptvs)
            CImGui.SliderInt2("Bingding Index to ON/OFF", qtw.options.bindingonoff, 1, qtw.numoptvs)
        end
        if qtw.name == "_SameLine_" && CImGui.CollapsingHeader(mlstr("SameLine Options"))
            @c CImGui.DragFloat(mlstr("Local Position X"), &qtw.options.localposx)
            @c CImGui.DragFloat(mlstr("Spacing Width"), &qtw.options.spacingw)
        end
        if qtw.name != "_SameLine_" && CImGui.CollapsingHeader(mlstr("Color Options"))
            widgetcolormenu(qtw.options)
        end
    end
end

function widgetcolormenu(opts::QuantityWidgetOption)
    CImGui.ColorEdit4(
        stcstr(mlstr("Text Color")),
        opts.textcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Hint Text Color")),
        opts.hintcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Background Color")),
        opts.bgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Combo Button Color")),
        opts.combobtcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Toggle-on Color")),
        opts.oncolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Toggle-off Color")),
        opts.offcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Hovered Button Color")),
        opts.hoveredcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Active Button Color")),
        opts.activecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Border Color")),
        opts.rectcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("SliderGrab Color")),
        opts.grabcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        stcstr(mlstr("Active SliderGrab Color")),
        opts.grabactivecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
end

function idxtoij(insw, idx)
    ls = 0
    for (i, l) in enumerate(length.(insw.qtws))
        lso = ls
        ls += l
        ls >= idx && return (i, idx - lso)
    end
end