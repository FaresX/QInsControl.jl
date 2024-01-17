@option mutable struct QuantityWidgetOption
    uitype::String = "none"
    globaloptions::Bool = false
    allowoverlap::Bool = false
    useimage::Bool = false
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
    comboflags::Cint = 0
    uv0::Vector{Cfloat} = [0, 0]
    uv1::Vector{Cfloat} = [1, 1]
    framepadding::Cfloat = -1
    trianglea::Vector{Cfloat} = [0, 0]
    triangleb::Vector{Cfloat} = [0, 0]
    trianglec::Vector{Cfloat} = [0, 0]
    circlesegments::Cint = 24
    starttext::String = "Start"
    stoptext::String = "Stop"
    bindingidx::Cint = 1
    selectornum::Cint = 1
    selectedidx::Cint = 1
    selectorlabels::Vector{String} = ["option 1"]
    selectorlist::Vector{Vector{String}} = []
    bindingqtwidxes::Vector{Vector{Cint}} = []
    bindingonoff::Vector{Cint} = [1, 2]
    textcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 1.000]
    hintcolor::Vector{Cfloat} = [0.600, 0.600, 0.600, 1.000]
    checkedcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 1.000]
    bgcolor::Vector{Cfloat} = [0.951, 0.951, 0.951, 1.000]
    popupcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 0.600]
    imgbgcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.000]
    imgtintcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    combobtcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.400]
    oncolor::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
    offcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.400]
    hoveredcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.800]
    activecolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.670]
    bdcolor::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.000]
    grabcolor::Vector{Cfloat} = [0.260, 0.590, 0.980, 0.780]
    grabactivecolor::Vector{Cfloat} = [0.460, 0.540, 0.800, 0.600]
end

@option mutable struct QuantityWidget
    name::String = ""
    alias::String = ""
    qtype::String = "none"
    numoptvs::Cint = 0
    options::QuantityWidgetOption = QuantityWidgetOption()
end

@option mutable struct InstrWidget
    instrnm::String = "VirtualInstr"
    name::String = "widget 1"
    qtws::Vector{Vector{QuantityWidget}} = []
    windowsize::Vector{Cfloat} = [600, 600]
    usewallpaper::Bool = false
    wallpaperpath::String = ""
    windowbgcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    bgtintcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    options::QuantityWidgetOption = QuantityWidgetOption()
    qtlist::Vector{String} = []
    draggable::Bool = false
end

const INSWCONF = OrderedDict{String,Vector{InstrWidget}}() #仪器注册表

function copyvars!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[1:32]
        fnm == :uitype && continue
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function copycolors!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[33:end]
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function edit(qtw::QuantityWidget, insbuf::InstrBuffer, instrnm, addr, gopts::QuantityWidgetOption)
    opts = qtw.options.globaloptions ? gopts : qtw.options
    scale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    opts.itemsize *= scale
    opts.cursorscreenpos *= scale
    qtw.options.globaloptions && copyvars!(opts, qtw.options)
    opts.cursorscreenpos == [0, 0] || CImGui.SetCursorScreenPos(CImGui.GetCursorScreenPos() .+ opts.cursorscreenpos)
    trig = if haskey(insbuf.quantities, qtw.name)
        qt = insbuf.quantities[qtw.name]
        edit(opts, qt, instrnm, addr, Val(Symbol(qtw.options.uitype)))
    elseif qtw.name == "_Panel_"
        editPanel(qtw, opts)
    elseif qtw.name == "_Shape_"
        editShape(opts, Val(Symbol(qtw.options.uitype)))
    elseif qtw.name == "_Image_"
        editImage(qtw, opts)
    elseif qtw.name == "_QuantitySelector_"
        editQuantitySelector(qtw, opts, Val(Symbol(qtw.options.uitype)))
    elseif qtw.name == "_SameLine_"
        editSameLine(opts)
    else
        false
    end
    opts.allowoverlap && CImGui.SetItemAllowOverlap()
    opts.itemsize ./= scale
    opts.cursorscreenpos ./= scale
    return trig
end

function editPanel(qtw::QuantityWidget, opts::QuantityWidgetOption)
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = ImageColoredButtonRect(
        mlstr(qtw.alias), qtw.alias, opts.useimage;
        size=opts.itemsize,
        uv0=opts.uv0,
        uv1=opts.uv1,
        frame_padding=opts.framepadding,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        bg_col=opts.imgbgcolor,
        tint_col=opts.imgtintcolor,
        colbt=opts.bgcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function editShape(opts::QuantityWidgetOption, ::Val{:rect})
    drawlist = CImGui.GetWindowDrawList()
    cspos = CImGui.GetCursorScreenPos()
    b = cspos .+ opts.itemsize
    CImGui.AddRectFilled(
        drawlist, cspos, b, CImGui.ColorConvertFloat4ToU32(opts.bgcolor),
        opts.rounding, ImDrawFlags_RoundCornersAll
    )
    CImGui.AddRect(
        drawlist, cspos, b, CImGui.ColorConvertFloat4ToU32(opts.bdcolor),
        opts.bdrounding, ImDrawFlags_RoundCornersAll, opts.bdthickness
    )
    return false
end

function editShape(opts::QuantityWidgetOption, ::Val{:triangle})
    drawlist = CImGui.GetWindowDrawList()
    cspos = CImGui.GetCursorScreenPos()
    a = cspos .+ opts.trianglea
    b = cspos .+ opts.triangleb
    c = cspos .+ opts.trianglec
    CImGui.AddTriangleFilled(drawlist, a, b, c, CImGui.ColorConvertFloat4ToU32(opts.bgcolor))
    CImGui.AddTriangle(drawlist, a, b, c, CImGui.ColorConvertFloat4ToU32(opts.bdcolor), opts.bdthickness)
    return false
end

function editShape(opts::QuantityWidgetOption, ::Val{:circle})
    drawlist = CImGui.GetWindowDrawList()
    cspos = CImGui.GetCursorScreenPos()
    O = cspos .+ opts.itemsize ./ 2
    r = min(opts.itemsize...) / 2
    CImGui.AddCircleFilled(drawlist, O, r, CImGui.ColorConvertFloat4ToU32(opts.bgcolor), opts.circlesegments)
    CImGui.AddCircle(drawlist, O, r, CImGui.ColorConvertFloat4ToU32(opts.bdcolor), opts.circlesegments, opts.bdthickness)
    return false
end

function editShape(opts::QuantityWidgetOption, ::Val{:line})
    drawlist = CImGui.GetWindowDrawList()
    cspos = CImGui.GetCursorScreenPos()
    a = cspos .+ opts.trianglea
    b = cspos .+ opts.triangleb
    CImGui.AddLine(drawlist, a, b, CImGui.ColorConvertFloat4ToU32(opts.bdcolor), opts.bdthickness)
    return false
end

function editImage(qtw::QuantityWidget, opts::QuantityWidgetOption)
    Image(
        qtw.alias;
        size=opts.itemsize,
        uv0=opts.uv0,
        uv1=opts.uv1,
        tint_col=opts.imgtintcolor,
        border_col=opts.bdcolor
    )
    return false
end

function editQuantitySelector(qtw::QuantityWidget, opts::QuantityWidgetOption, ::Val{:combo})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredCombo(
        stcstr("##selector", qtw.alias), &qtw.alias, opts.selectorlabels, opts.comboflags;
        width=opts.itemsize[1],
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colbt=opts.combobtcolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        colpopup=opts.popupcolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor
    )
    trig && (opts.selectedidx = findfirst(==(qtw.alias), opts.selectorlabels))
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function editQuantitySelector(qtw::QuantityWidget, opts::QuantityWidgetOption, ::Val{:slider})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredSlider(
        CImGui.SliderInt,
        stcstr(opts.textinside ? "##" : "", qtw.alias),
        &opts.selectedidx, 1, opts.selectornum, opts.textinside ? qtw.alias : "";
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
        colrect=opts.bdcolor
    )
    trig && (qtw.alias = opts.selectorlabels[opts.selectedidx])
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function editQuantitySelector(qtw::QuantityWidget, opts::QuantityWidgetOption, ::Val{:vslider})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredVSlider(
        CImGui.VSliderInt,
        stcstr(opts.textinside ? "##" : "", qtw.alias),
        &opts.selectedidx, 1, opts.selectornum, opts.textinside ? qtw.alias : "";
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
        colrect=opts.bdcolor
    )
    trig && (qtw.alias = opts.selectorlabels[opts.selectedidx])
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

editSameLine(opts::QuantityWidgetOption) = (CImGui.SameLine(opts.localposx, opts.spacingw); return false)

edit(::QuantityWidgetOption, ::AbstractQuantity, _, _, ::Val) = CImGui.Button(mlstr("Invalid UI Type"))

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:read})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = ColoredButtonRect(
        qt.showval;
        size=opts.itemsize,
        colbt=opts.bgcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    )
    if trig
        if qt.enable && addr != ""
            fetchdata = refresh_qt(instrnm, addr, qt.name)
            isnothing(fetchdata) || (qt.read = fetchdata)
            updatefront!(qt)
        end
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:unit})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = ColoredButtonRect(
        qt.showU;
        size=opts.itemsize,
        colbt=opts.bgcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    )
    trig && (qt.uindex += 1; getvalU!(qt); resolveunitlist(qt, instrnm, addr))
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:readunit})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = ColoredButtonRect(
        stcstr(qt.showval, " ", qt.showU);
        size=opts.itemsize,
        colbt=opts.bgcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    )
    if trig
        if qt.enable && addr != ""
            fetchdata = refresh_qt(instrnm, addr, qt.name)
            isnothing(fetchdata) || (qt.read = fetchdata)
            updatefront!(qt)
        end
    end
    CImGui.IsItemClicked(2) && (qt.uindex += 1; getvalU!(qt); resolveunitlist(qt, instrnm, addr))
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:inputstep})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredInputTextWithHintRSZ(
        "##step", mlstr("step"), &qt.step;
        size=opts.itemsize,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        coltxt=opts.textcolor,
        colhint=opts.hintcolor,
        colrect=opts.bdcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:inputstop})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredInputTextWithHintRSZ("##stop", mlstr("stop"), &qt.stop;
        size=opts.itemsize,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        coltxt=opts.textcolor,
        colhint=opts.hintcolor,
        colrect=opts.bdcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:dragdelay})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredDragWidget(
        CImGui.DragFloat,
        "##delay", &qt.delay, 0.01, 0.01, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp;
        size=opts.itemsize,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, instrnm, addr, ::Val{:ctrlsweep})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ToggleButtonRect(
        mlstr(qt.issweeping ? opts.stoptext : opts.starttext), &qt.issweeping;
        size=opts.itemsize,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colon=opts.oncolor,
        coloff=opts.offcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor,
    )
    trig && qt.issweeping && apply!(qt, instrnm, addr)
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    qt.issweeping && updatefront!(qt)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, _, _, ::Val{:inputset})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredInputTextWithHintRSZ("##set", mlstr("set"), &qt.set;
        size=opts.itemsize,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        coltxt=opts.textcolor,
        colhint=opts.hintcolor,
        colrect=opts.bdcolor
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:ctrlset})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = ColoredButtonRect(
        mlstr(opts.starttext);
        size=opts.itemsize,
        colbt=opts.bgcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    )
    trig && (apply!(qt, instrnm, addr); updatefront!(qt))
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:combo})
    presentv = qt.optkeys[qt.optedidx]
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredCombo(
        stcstr("##", qt.alias), &presentv, qt.optkeys, opts.comboflags;
        width=opts.itemsize[1],
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colbt=opts.combobtcolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        colpopup=opts.popupcolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor
    )
    if trig
        qt.optedidx = findfirst(==(presentv), qt.optkeys)
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
        updatefront!(qt)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:radio})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredRadioButton(
        qt.optkeys[opts.bindingidx], &qt.optedidx, opts.bindingidx;
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colckm=opts.checkedcolor,
        colfrm=opts.bgcolor,
        colfrmh=opts.hoveredcolor,
        colfrma=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor
    )
    if trig
        qt.optedidx = opts.bindingidx
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
        updatefront!(qt)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:slider})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredSlider(
        CImGui.SliderInt,
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
        colrect=opts.bdcolor
    )
    if trig
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
        updatefront!(qt)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:vslider})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ColoredVSlider(
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
        colrect=opts.bdcolor
    )
    if trig
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
        updatefront!(qt)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:toggle})
    ison = qt.optedidx == opts.bindingonoff[1]
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = @c ToggleButtonRect(
        qt.optkeys[opts.bindingonoff[ison ? 1 : 2]], &ison;
        size=opts.itemsize,
        colon=opts.oncolor,
        coloff=opts.offcolor,
        colbth=opts.hoveredcolor,
        colbta=opts.activecolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness
    )
    if trig
        qt.optedidx = opts.bindingonoff[ison ? 1 : 2]
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
        updatefront!(qt)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

let
    qtypes = ["sweep", "set", "read"]
    continuousuitypes = ["inputstep", "inputstop", "dragdelay", "inputset"]
    draglayers = Dict{Tuple,Union{DragRect,Vector{DragPoint}}}()
    global function edit(insw::InstrWidget, insbuf::InstrBuffer, addr, p_open, id)
        scale = unsafe_load(CImGui.GetIO().FontGlobalScale)
        CImGui.SetNextWindowSize(insw.windowsize * scale)
        CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, insw.windowbgcolor)
        if CImGui.Begin(
            stcstr(
                INSCONF[insw.instrnm].conf.icon, " ", insw.instrnm, " ", addr, " ", insw.name,
                "###", insw.instrnm, addr, id
            ),
            p_open,
            addr == "" ? CImGui.ImGuiWindowFlags_NoDocking : 0
        )
            isanyitemdragging = false
            insw.usewallpaper && SetWindowBgImage(insw.wallpaperpath; tint_col=insw.bgtintcolor)
            CImGui.BeginChild(stcstr(insw.instrnm, " ", insw.name, " ", addr))
            for (i, qtwg) in enumerate(insw.qtws)
                CImGui.PushID(i)
                length(qtwg) == 1 || CImGui.BeginGroup()
                for (j, qtw) in enumerate(qtwg)
                    CImGui.PushID(j)
                    insw.draggable && igBeginDisabled(true)
                    if edit(qtw, insbuf, insw.instrnm, addr, insw.options)
                        qtw.qtype in qtypes && qtw.options.uitype ∉ continuousuitypes && Threads.@spawn refresh1(insw, addr)
                        qtw.name == "_QuantitySelector_" && (trigselector!(qtw, insw); Threads.@spawn refresh1(insw, addr))
                    end
                    insw.draggable && igEndDisabled()
                    CImGui.PopID()
                    if insw.draggable && qtw.name != "_SameLine_"
                        if haskey(draglayers, (i, j))
                            if qtw.name == "_Shape_"
                                if qtw.options.uitype == "triangle"
                                    if draglayers[(i, j)] isa Vector && length(draglayers[(i, j)]) == 3
                                        cspos = CImGui.GetCursorScreenPos()
                                        dps = draglayers[(i, j)]
                                        dps[1].pos = cspos .+ qtw.options.trianglea
                                        dps[2].pos = cspos .+ qtw.options.triangleb
                                        dps[3].pos = cspos .+ qtw.options.trianglec
                                        for dp in dps
                                            isanyitemdragging && (dp.dragging = false)
                                            edit(dp)
                                            isanyitemdragging |= dp.dragging
                                        end
                                        qtw.options.trianglea .= dps[1].pos .- cspos
                                        qtw.options.triangleb .= dps[2].pos .- cspos
                                        qtw.options.trianglec .= dps[3].pos .- cspos
                                    else
                                        delete!(draglayers, (i, j))
                                    end
                                elseif qtw.options.uitype == "line"
                                    if draglayers[(i, j)] isa Vector && length(draglayers[(i, j)]) == 2
                                        cspos = CImGui.GetCursorScreenPos()
                                        dps = draglayers[(i, j)]
                                        dps[1].pos = cspos .+ qtw.options.trianglea
                                        dps[2].pos = cspos .+ qtw.options.triangleb
                                        for dp in dps
                                            isanyitemdragging && (dp.dragging = false)
                                            edit(dp)
                                            isanyitemdragging |= dp.dragging
                                        end
                                        qtw.options.trianglea .= dps[1].pos .- cspos
                                        qtw.options.triangleb .= dps[2].pos .- cspos
                                    else
                                        delete!(draglayers, (i, j))
                                    end
                                else
                                    if draglayers[(i, j)] isa DragRect
                                        cspos = CImGui.GetCursorScreenPos()
                                        dr = draglayers[(i, j)]
                                        dr.posmin = cspos
                                        dr.posmax = cspos .+ qtw.options.itemsize
                                        isanyitemdragging && (dr.dragging = false; dr.gripdragging = false)
                                        edit(dr)
                                        isanyitemdragging |= dr.dragging | dr.gripdragging
                                        qtw.options.itemsize = dr.posmax .- dr.posmin
                                        qtw.options.cursorscreenpos = qtw.options.cursorscreenpos .+ dr.posmin .- cspos
                                    else
                                        delete!(draglayers, (i, j))
                                    end
                                end
                            else
                                if draglayers[(i, j)] isa DragRect
                                    posmin = CImGui.GetItemRectMin()
                                    dr = draglayers[(i, j)]
                                    dr.posmin = posmin
                                    dr.posmax = CImGui.GetItemRectMax()
                                    isanyitemdragging && (dr.dragging = false; dr.gripdragging = false)
                                    edit(dr)
                                    isanyitemdragging |= dr.dragging | dr.gripdragging
                                    qtw.options.itemsize = dr.posmax .- dr.posmin
                                    qtw.options.cursorscreenpos = qtw.options.cursorscreenpos .+ dr.posmin .- posmin
                                else
                                    delete!(draglayers, (i, j))
                                end
                            end
                        else
                            push!(
                                draglayers,
                                (i, j) => if qtw.name == "_Shape_"
                                    if qtw.options.uitype == "triangle"
                                        [DragPoint(), DragPoint(), DragPoint()]
                                    elseif qtw.options.uitype == "line"
                                        [DragPoint(), DragPoint()]
                                    else
                                        DragRect()
                                    end
                                else
                                    DragRect()
                                end
                            )
                        end
                    end
                end
                length(qtwg) == 1 || CImGui.EndGroup()
                CImGui.PopID()
            end
            if insw.draggable
                CImGui.SetCursorPos(0, 0)
                ColoredButton("##max"; size=(-1, -1), colbt=(0, 0, 0, 0), colbth=(0, 0, 0, 0), colbta=(0, 0, 0, 0))
            end
            CImGui.EndChild()
        end
        CImGui.IsWindowCollapsed() || (insw.windowsize .= CImGui.GetWindowSize() ./ scale)
        CImGui.End()
        CImGui.PopStyleColor()
    end
end

function modify(qtw::QuantityWidget, id, showslnums, selectedqtw::Ref{Cint})
    label = if qtw.name == "_SameLine_"
        CImGui.SameLine()
        label = showslnums ? stcstr(id, " ", "Same\nLine") : "Same\nLine"
    elseif qtw.name == "_Panel_"
        if qtw.options.useimage
            showslnums ? stcstr(id, " ", "Image\nButton") : "Image\nButton"
        else
            stcstr(showslnums ? id : "", " Text", " \n ", mlstr(qtw.alias), "###", id)
        end
    elseif qtw.name == "_Shape_"
        stcstr(showslnums ? stcstr(id, " ") : "", "Shape\n", qtw.options.uitype)
    elseif qtw.name == "_Image_"
        showslnums ? stcstr(id, " Image\n ") : " Image\n "
    elseif qtw.name == "_QuantitySelector_"
        label = join([string('[', join(idxes, ' '), ']') for idxes in qtw.options.bindingqtwidxes], '\n')
        stcstr(showslnums ? stcstr(id, " ") : "", "Selector\n", label, "###", id)
    else
        stcstr(showslnums ? stcstr(id, " ") : "", qtw.alias, "\n", qtw.options.uitype)
    end
    ispushstylecol = selectedqtw[] == id
    ispushstylecol && CImGui.PushStyleColor(CImGui.ImGuiCol_Button, MORESTYLE.Colors.SelectedWidgetBt)
    CImGui.Button(label) && (selectedqtw[] = selectedqtw[] == id ? 0 : id)
    ispushstylecol && CImGui.PopStyleColor()
end

let
    copiedopts::Ref{QuantityWidgetOption} = QuantityWidgetOption()
    showslnums::Bool = false
    dragmode::String = ""
    dragmodes::Vector{String} = ["swap", "before", "after"]
    selectedqtw::Cint = 0
    acd::AnimateChild = AnimateChild(rate=(8, 12))
    fakewidget::QuantityWidget = QuantityWidget()
    maxwindowsize::CImGui.ImVec2 = (400, 600)
    windowpos::Bool = true # false left true right
    global function modify(insw::InstrWidget)
        openmodw = false
        dragmode == "" && (dragmode = mlstr("swap"))
        CImGui.BeginChild(stcstr(insw.instrnm, insw.name), (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Options"))
        @c CImGui.Checkbox(mlstr("Show Serial Numbers"), &showslnums)
        CImGui.SameLine()
        CImGui.PushItemWidth(6CImGui.GetFontSize())
        @c ComBoS(mlstr("Dragging Mode"), &dragmode, mlstr.(dragmodes))
        CImGui.PopItemWidth()
        CImGui.SameLine()
        @c CImGui.Checkbox(mlstr("Draggable"), &insw.draggable)
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Widgets"))
        for (i, qtwg) in enumerate(insw.qtws)
            CImGui.PushID(i)
            lqtwg = length(qtwg)
            btcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
            bthcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, isodd(i) ? btcol : bthcol)
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, isodd(i) ? bthcol : btcol)
            lqtwg == 1 && only(qtwg).name == "_SameLine_" && CImGui.SameLine()
            isbreak = false
            CImGui.BeginGroup()
            for (j, qtw) in enumerate(qtwg)
                CImGui.PushID(j)
                j > 1 && qtwg[j-1].name == "_SameLine_" && CImGui.SameLine()
                idx = sum(length.(@view(insw.qtws[1:i-1]))) + j
                @c modify(qtw, idx, showslnums, &selectedqtw)
                if CImGui.BeginPopupContextItem()
                    CImGui.PushID(idx)
                    SeparatorTextColored(MORESTYLE.Colors.HighlightText, stcstr("QT", " ", idx))
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy Options")))
                        copiedopts[] = deepcopy(qtw.options)
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste Options")))
                        copyvars!(qtw.options, copiedopts[])
                        copycolors!(qtw.options, copiedopts[])
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste Colors")))
                        copycolors!(qtw.options, copiedopts[])
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste Variables")))
                        copyvars!(qtw.options, copiedopts[])
                    end
                    newqtw = addwidgetmenu(insw; mode=:before)
                    isnothing(newqtw) || (insertwidget!(insw, newqtw, i, j, :before); isbreak = true; break)
                    newqtw = addwidgetmenu(insw; mode=:after)
                    isnothing(newqtw) || (insertwidget!(insw, newqtw, i, j, :after); isbreak = true; break)
                    newqtw = addwidgetmenu(insw; mode=:beforeg)
                    isnothing(newqtw) || (insertwidget!(insw, newqtw, i, j, :beforeg); isbreak = true; break)
                    newqtw = addwidgetmenu(insw; mode=:afterg)
                    isnothing(newqtw) || (insertwidget!(insw, newqtw, i, j, :afterg); isbreak = true; break)
                    convertmenu(insw, i, j)
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InsertUp, " ", mlstr("Merge Group Before")), C_NULL, false, i > 1)
                        append!(insw.qtws[i-1], insw.qtws[i])
                        deleteat!(insw.qtws, i)
                        isbreak = true
                        break
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InsertDown, " ", mlstr("Merge Group After")), C_NULL, false, i < length(insw.qtws))
                        append!(insw.qtws[i], insw.qtws[i+1])
                        deleteat!(insw.qtws, i + 1)
                        isbreak = true
                        break
                    end
                    if CImGui.MenuItem(
                        stcstr(MORESTYLE.Icons.InsertInside, " ", mlstr("Split Group")), C_NULL, false, lqtwg != 1
                    )
                        splitwidget!(insw, i, j)
                        isbreak = true
                        break
                    end
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")))
                        deletewidget!(insw, i, j)
                        isbreak = true
                        break
                    end
                    optionsmenu(qtw, insw.instrnm)
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
                            dragmodesym = if dragmode == mlstr("before")
                                :before
                            elseif dragmode == mlstr("after")
                                :after
                            else
                                :swap
                            end
                            if unsafe_load(CImGui.GetIO().KeyCtrl)
                                draggroup!(insw, payload_i, idx, Val(dragmodesym))
                            else
                                dragwidget!(insw, payload_i, idx, Val(dragmodesym))
                            end
                            isbreak = true
                            break
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
            CImGui.PopStyleColor(2)
            isbreak && break
            lqtwg == 1 && only(qtwg).name == "_SameLine_" && CImGui.SameLine()
            if i < length(insw.qtws)
                if !((lqtwg == 1 && only(qtwg).name == "_SameLine_") ||
                     (length(insw.qtws[i+1]) == 1 && only(insw.qtws[i+1]).name == "_SameLine_"))
                    CImGui.Separator()
                end
            end
            CImGui.PopID()
        end
        CImGui.EndChild()
        CImGui.IsItemClicked() && (selectedqtw = 0)
        if windowpos
            CImGui.SetCursorScreenPos(CImGui.GetItemRectMax() .- acd.presentsize)
        else
            rectmin = CImGui.GetItemRectMin()
            rectmax = CImGui.GetItemRectMax()
            CImGui.SetCursorScreenPos((rectmin.x, rectmax.y - acd.presentsize.y))
        end
        if all(acd.targetsize .== (4, 6)) && all(acd.presentsize .== (4, 6))
            selectedqtw[] == 0 || (acd.targetsize = maxwindowsize)
        else
            mainwindowsz = CImGui.GetItemRectSize()
            acd.targetsize = (2mainwindowsz.x / 5, 4mainwindowsz.y / 5)
            acd.rate = acd.targetsize ./ 20 * 60 / unsafe_load(CImGui.GetIO().Framerate)
            selectedqtw[] == 0 && (acd.targetsize = (4, 6))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg))
            changesize = false
            acd("optionsmenu", true, 0) do
                if windowpos
                    CImGui.Button(ICONS.ICON_LEFT_LONG) && (windowpos = false; changesize = true)
                    CImGui.SameLine()
                end
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, stcstr("QT ", selectedqtw[]))
                if !windowpos
                    CImGui.SameLine(0, CImGui.GetFontSize())
                    CImGui.Button(ICONS.ICON_RIGHT_LONG) && (windowpos = true; changesize = true)
                end
                CImGui.BeginChild("optionsmenu inside", (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
                if selectedqtw[] == 0
                    optionsmenu(fakewidget, "")
                else
                    ij = idxtoij(insw, selectedqtw[])
                    if !isnothing(ij)
                        i, j = ij
                        optionsmenu(insw.qtws[i][j], insw.instrnm)
                        fakewidget = insw.qtws[i][j]
                    end
                end
                CImGui.EndChild()
            end
            changesize && (acd.presentsize = (4, 6))
            CImGui.PopStyleColor()
        end

        openmodw && CImGui.OpenPopup(stcstr("modify widget", insw.instrnm, insw.name))
        if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
            CImGui.OpenPopupOnItemClick(stcstr("modify widget", insw.instrnm, insw.name))
        end
        if CImGui.BeginPopup(stcstr("modify widget", insw.instrnm, insw.name))
            addwidgetmenu(insw)
            CImGui.EndPopup()
        end
    end
end

function insertwidget!(insw::InstrWidget, qtw::QuantityWidget, i, j, mode)
    if mode == :before
        insert!(insw.qtws[i], j, qtw)
    elseif mode == :after
        insert!(insw.qtws[i], j + 1, qtw)
    elseif mode == :beforeg
        insert!(insw.qtws, i, [qtw])
    elseif mode == :afterg
        insert!(insw.qtws, i + 1, [qtw])
    end
end

function deletewidget!(insw::InstrWidget, i, j)
    deleteat!(insw.qtws[i], j)
    isempty(insw.qtws[i]) && deleteat!(insw.qtws, i)
end

function splitwidget!(insw::InstrWidget, i, j)
    popqtwg = popat!(insw.qtws, i)
    insert!(insw.qtws, i, popqtwg[1:j-1])
    insert!(insw.qtws, i + 1, popqtwg[j:end])
    isempty(insw.qtws[i]) && deleteat!(insw.qtws, i)
end

function dragwidget!(insw::InstrWidget, idx1, idx2, ::Val{:swap})
    spos = idxtoij(insw, idx1)
    tpos = idxtoij(insw, idx2)
    if !(isnothing(spos) | isnothing(tpos))
        tqtw = insw.qtws[tpos[1]][tpos[2]]
        insw.qtws[tpos[1]][tpos[2]] = insw.qtws[spos[1]][spos[2]]
        insw.qtws[spos[1]][spos[2]] = tqtw
    end
end

function dragwidget!(insw::InstrWidget, idx1, idx2, ::Val{:before})
    spos = idxtoij(insw, idx1)
    tpos = idxtoij(insw, idx2)
    if !(isnothing(spos) | isnothing(tpos))
        insert!(insw.qtws[tpos[1]], tpos[2], insw.qtws[spos[1]][spos[2]])
        if spos[1] == tpos[1]
            deleteat!(insw.qtws[spos[1]], spos[2] < tpos[2] ? spos[2] : spos[2] + 1)
        else
            deleteat!(insw.qtws[spos[1]], spos[2])
            isempty(insw.qtws[spos[1]]) && deleteat!(insw.qtws, spos[1])
        end
    end
end

function dragwidget!(insw::InstrWidget, idx1, idx2, ::Val{:after})
    spos = idxtoij(insw, idx1)
    tpos = idxtoij(insw, idx2)
    if !(isnothing(spos) | isnothing(tpos))
        insert!(insw.qtws[tpos[1]], tpos[2] + 1, insw.qtws[spos[1]][spos[2]])
        if spos[1] == tpos[1]
            deleteat!(insw.qtws[spos[1]], spos[2] < tpos[2] ? spos[2] : spos[2] + 1)
        else
            deleteat!(insw.qtws[spos[1]], spos[2])
            isempty(insw.qtws[spos[1]]) && deleteat!(insw.qtws, spos[1])
        end
    end
end

function draggroup!(insw::InstrWidget, idx1, idx2, ::Val{:swap})
    spos = idxtoij(insw, idx1)
    tpos = idxtoij(insw, idx2)
    if !(isnothing(spos) | isnothing(tpos)) && spos[1] != tpos[1]
        tqtws = insw.qtws[tpos[1]]
        insw.qtws[tpos[1]] = insw.qtws[spos[1]]
        insw.qtws[spos[1]] = tqtws
    end
end

function draggroup!(insw::InstrWidget, idx1, idx2, ::Val{:before})
    spos = idxtoij(insw, idx1)
    tpos = idxtoij(insw, idx2)
    if !(isnothing(spos) | isnothing(tpos)) && spos[1] != tpos[1]
        insert!(insw.qtws, tpos[1], insw.qtws[spos[1]])
        deleteat!(insw.qtws, spos[1] < tpos[1] ? spos[1] : spos[1] + 1)
    end
end

function draggroup!(insw::InstrWidget, idx1, idx2, ::Val{:after})
    spos = idxtoij(insw, idx1)
    tpos = idxtoij(insw, idx2)
    if !(isnothing(spos) | isnothing(tpos)) && spos[1] != tpos[1]
        insert!(insw.qtws, tpos[1] + 1, insw.qtws[spos[1]])
        deleteat!(insw.qtws, spos[1] < tpos[1] ? spos[1] : spos[1] + 1)
    end
end

function addwidgetmenu(insw::InstrWidget; mode=:addlastg)
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
        if CImGui.MenuItem(mlstr("Panel"))
            newqtw = QuantityWidget(name="_Panel_", alias="")
            mode == :addlastg && push!(insw.qtws, [newqtw])
        end
        if CImGui.MenuItem(mlstr("Shape"))
            newqtw = QuantityWidget(name="_Shape_", alias="")
            newqtw.options.globaloptions = false
            newqtw.options.uitype = "rect"
            newqtw.options.bdcolor = [0, 0, 0, 1]
            mode == :addlastg && push!(insw.qtws, [newqtw])
        end
        if CImGui.MenuItem(mlstr("Image"))
            newqtw = QuantityWidget(name="_Image_", alias="")
            mode == :addlastg && push!(insw.qtws, [newqtw])
        end
        if CImGui.MenuItem(mlstr("Selector"))
            newqtw = QuantityWidget(name="_QuantitySelector_", alias="")
            newqtw.options.uitype = "combo"
            mode == :addlastg && push!(insw.qtws, [newqtw])
        end
        if CImGui.MenuItem(mlstr("SameLine"))
            newqtw = QuantityWidget(name="_SameLine_", alias="SameLine")
            mode == :addlastg && push!(insw.qtws, [newqtw])
        end
        if CImGui.BeginMenu(mlstr("Sweep Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "sweep" || continue
                    if CImGui.MenuItem(qt.alias)
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias, qtype="sweep")
                        newqtw.options.uitype = "read"
                        mode == :addlastg && push!(insw.qtws, [newqtw])
                    end
                end
            end
            CImGui.EndMenu()
        end
        if CImGui.BeginMenu(mlstr("Set Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "set" || continue
                    if CImGui.MenuItem(qt.alias)
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias, qtype="set", numoptvs=length(qt.optvalues))
                        newqtw.options.uitype = "read"
                        mode == :addlastg && push!(insw.qtws, [newqtw])
                    end
                end
            end
            CImGui.EndMenu()
        end
        if CImGui.BeginMenu(mlstr("Read Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "read" || continue
                    if CImGui.MenuItem(qt.alias)
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias, qtype="read")
                        newqtw.options.uitype = "read"
                        mode == :addlastg && push!(insw.qtws, [newqtw])
                    end
                end
            end
            CImGui.EndMenu()
        end
        CImGui.EndMenu()
        return newqtw
    end
end

function convertmenu(insw::InstrWidget, i, j)
    if CImGui.BeginMenu(
        stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Convert to")),
        insw.qtws[i][j].name ∉ ["_Panel_", "_SameLine_"]
    )
        if CImGui.BeginMenu(mlstr("Sweep Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "sweep" || continue
                    if CImGui.MenuItem(qt.alias)
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
                    if CImGui.MenuItem(qt.alias)
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
                    if CImGui.MenuItem(qt.alias)
                        insw.qtws[i][j] = QuantityWidget(
                            name=qtnm,
                            alias=qt.alias,
                            qtype="read",
                            options=insw.qtws[i][j].options
                        )
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
    readuitypes = ["read", "unit", "readunit"]
    otheruitypes = ["none"]
    shapetypes = ["rect", "triangle", "circle", "line"]
    qtselectoruitypes = ["combo", "slider", "vslider"]
    # selectortypes = ["sweep", "set", "read"]
    textsizes = ["normal", "big"]
    manualinputalias::String = ""
    global function optionsmenu(qtw::QuantityWidget, instrnm)
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
                elseif qtw.qtype == "read"
                    readuitypes
                elseif qtw.name == "_Shape_"
                    shapetypes
                elseif qtw.name == "_QuantitySelector_"
                    qtselectoruitypes
                else
                    otheruitypes
                end
            )
            @c CImGui.Checkbox(mlstr("Global Options"), &qtw.options.globaloptions)
            @c CImGui.Checkbox(mlstr("Allow Overlap"), &qtw.options.allowoverlap)
            if qtw.name == "_Panel_"
                @c CImGui.Checkbox(mlstr("Use ImageButton"), &qtw.options.useimage)
                @c InputTextRSZ("##Text", &qtw.alias)
                CImGui.SameLine()
                iconstr = MORESTYLE.Icons.CopyIcon
                @c(IconSelector(mlstr("Text"), &iconstr)) && (qtw.alias *= iconstr)
            end
            if qtw.options.uitype in ["ctrlsweep", "ctrlset"]
                @c InputTextRSZ("##Start", &qtw.options.starttext)
                CImGui.SameLine()
                iconstr = MORESTYLE.Icons.CopyIcon
                @c(IconSelector(mlstr("Start"), &iconstr)) && (qtw.options.starttext *= iconstr)
                @c InputTextRSZ("##Stop", &qtw.options.stoptext)
                CImGui.SameLine()
                iconstr = MORESTYLE.Icons.CopyIcon
                @c(IconSelector(mlstr("Stop"), &iconstr)) && (qtw.options.stoptext *= iconstr)
            end
            @c ComBoS(mlstr("Text Size"), &qtw.options.textsize, textsizes)
            @c CImGui.DragFloat(
                mlstr("Text Scale"),
                &qtw.options.textscale,
                0.1, 0.1, 2, "%.1f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            qtw.options.uitype in ["slider", "vslider"] && @c CImGui.Checkbox("Text Inside", &qtw.options.textinside)
            qtw.options.uitype == "combo" && @c CImGui.CheckboxFlags(
                mlstr("No ArrowButton"), &qtw.options.comboflags, CImGui.ImGuiComboFlags_NoArrowButton
            )
            CImGui.DragFloat2(mlstr("Item Size"), qtw.options.itemsize)
            if qtw.options.uitype == "triangle"
                CImGui.DragFloat2(stcstr(mlstr("triangle"), " a"), qtw.options.trianglea)
                CImGui.DragFloat2(stcstr(mlstr("triangle"), " b"), qtw.options.triangleb)
                CImGui.DragFloat2(stcstr(mlstr("triangle"), " c"), qtw.options.trianglec)
            elseif qtw.options.uitype == "circle"
                @c CImGui.DragInt(
                    mlstr("segments"), &qtw.options.circlesegments, 1, 6, 60, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
            elseif qtw.options.uitype == "line"
                CImGui.DragFloat2(stcstr(mlstr("line"), " a"), qtw.options.trianglea)
                CImGui.DragFloat2(stcstr(mlstr("line"), " b"), qtw.options.triangleb)
            end
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
        if (qtw.name == "_Image_" || (qtw.name == "_Panel_" && qtw.options.useimage)) && CImGui.CollapsingHeader(mlstr("Image Options"))
            imgpath = qtw.alias
            inputimgpath = @c InputTextRSZ("##ImagePath", &imgpath)
            CImGui.SameLine()
            selectimgpath = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##ImagePath"))
            selectimgpath && (imgpath = pick_file(abspath(imgpath); filterlist="png,jpg,jpeg,tif,bmp"))
            CImGui.SameLine()
            CImGui.Text(mlstr("Image Path"))
            if inputimgpath || selectimgpath
                if isfile(imgpath)
                    qtw.alias = imgpath
                else
                    CImGui.SameLine()
                    CImGui.TextColored(MORESTYLE.Colors.LogError, mlstr("path does not exist!!!"))
                end
            end
            # CImGui.DragFloat2(mlstr("Image Size"), qtw.options.itemsize)
            @c CImGui.DragFloat(mlstr("Frame Padding"), &qtw.options.framepadding)
            CImGui.DragFloat2(mlstr("uv0"), qtw.options.uv0)
            CImGui.DragFloat2(mlstr("uv1"), qtw.options.uv1)
        end
        if qtw.name == "_SameLine_" && CImGui.CollapsingHeader(mlstr("SameLine Options"))
            @c CImGui.DragFloat(mlstr("Local Position X"), &qtw.options.localposx)
            @c CImGui.DragFloat(mlstr("Spacing Width"), &qtw.options.spacingw)
        end
        if qtw.qtype == "set" && CImGui.CollapsingHeader(mlstr("Binding Options"))
            @c CImGui.SliderInt("Binding Index to RadioButton", &qtw.options.bindingidx, 1, qtw.numoptvs)
            CImGui.SliderInt2("Bingding Index to ON/OFF", qtw.options.bindingonoff, 1, qtw.numoptvs)
        end
        if qtw.name == "_QuantitySelector_" && CImGui.CollapsingHeader(mlstr("Selector Options"))
            # @c ComBoS(mlstr("Selector Type"), &qtw.options.selectortype, selectortypes)
            @c CImGui.DragInt(
                mlstr("binding numbers"), &qtw.options.selectornum, 1, 1, 12, "%d",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            llbs = length(qtw.options.selectorlabels)
            if llbs != qtw.options.selectornum
                if llbs < qtw.options.selectornum
                    append!(qtw.options.selectorlabels, "option " .* string.(llbs+1:qtw.options.selectornum))
                else
                    resize!(qtw.options.selectorlabels, qtw.options.selectornum)
                end
            end
            for (i, lb) in enumerate(qtw.options.selectorlabels)
                @c(InputTextRSZ(stcstr(mlstr("option"), " ", i), &lb)) && (qtw.options.selectorlabels[i] = lb)
            end
            width = CImGui.GetContentRegionAvailWidth() / 3
            if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, "##addselectorgroup"), (width, Cfloat(0)))
                push!(qtw.options.selectorlist, [])
                push!(qtw.options.bindingqtwidxes, [])
            end
            CImGui.SameLine()
            if CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##deleteselectorgroup"), (width, Cfloat(0)))
                pop!(qtw.options.selectorlist)
                pop!(qtw.options.bindingqtwidxes)
            end
            for (i, group) in enumerate(qtw.options.selectorlist)
                CImGui.PushID(i)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg))
                CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_HeaderHovered))
                CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_HeaderActive))
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, unsafe_load(IMGUISTYLE.FramePadding) ./ 2)
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add")), length(group) < qtw.options.selectornum)
                    if CImGui.BeginMenu(mlstr("Sweep Quantity"))
                        if haskey(INSCONF, instrnm)
                            for (_, qt) in INSCONF[instrnm].quantities
                                qt.type == "sweep" || continue
                                CImGui.Button(qt.alias) && push!(group, qt.alias)
                            end
                        end
                        CImGui.EndMenu()
                    end
                    if CImGui.BeginMenu(mlstr("Set Quantity"))
                        if haskey(INSCONF, instrnm)
                            for (_, qt) in INSCONF[instrnm].quantities
                                qt.type == "set" || continue
                                CImGui.Button(qt.alias) && push!(group, qt.alias)
                            end
                        end
                        CImGui.EndMenu()
                    end
                    if CImGui.BeginMenu(mlstr("Read Quantity"))
                        if haskey(INSCONF, instrnm)
                            for (_, qt) in INSCONF[instrnm].quantities
                                qt.type == "read" || continue
                                CImGui.Button(qt.alias) && push!(group, qt.alias)
                            end
                        end
                        CImGui.EndMenu()
                    end
                    @c InputTextRSZ("##manualinput", &manualinputalias)
                    CImGui.SameLine()
                    CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, "##addalias")) && push!(group, manualinputalias)
                    CImGui.EndMenu()
                end
                CImGui.PopStyleVar()
                CImGui.PopStyleColor(3)
                for (j, alias) in enumerate(group)
                    CImGui.Selectable(alias)
                    if CImGui.BeginPopupContextItem()
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (deleteat!(group, j); break)
                        CImGui.EndPopup()
                    end
                    j % CONF.InsBuf.showcol != 0 && j != length(group) && CImGui.SameLine()
                end
                bindingqtwidxesstr = join(qtw.options.bindingqtwidxes[i], ',')
                if @c InputTextRSZ("Binding to Widgets", &bindingqtwidxesstr)
                    idxstrs = split(bindingqtwidxesstr, ',')
                    idxes = tryparse.(Int, idxstrs)
                    qtw.options.bindingqtwidxes[i] = idxes[findall(!isnothing, idxes)]
                end
                CImGui.PopID()
            end
        end
        if qtw.name != "_SameLine_" && CImGui.CollapsingHeader(mlstr("Color Options"))
            widgetcolormenu(qtw)
        end
    end
end

function widgetcolormenu(qtw::QuantityWidget)
    CImGui.ColorEdit4(
        mlstr("Text Color"),
        qtw.options.textcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Background Color"),
        qtw.options.bgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Border Color"),
        qtw.options.bdcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Hovered Color"),
        qtw.options.hoveredcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Actived Color"),
        qtw.options.activecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    if qtw.options.uitype in ["inputstep", "inputstop", "inputset"]
        CImGui.ColorEdit4(
            mlstr("Hint Text Color"),
            qtw.options.hintcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype == "combo"
        CImGui.ColorEdit4(
            mlstr("Combo Button Color"),
            qtw.options.combobtcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Popup Background Color"),
            qtw.options.popupcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.name == "_Image_"
        CImGui.ColorEdit4(
            mlstr("Image Background Color"),
            qtw.options.imgbgcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Image Tint Color"),
            qtw.options.imgtintcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype == "toggle"
        CImGui.ColorEdit4(
            mlstr("Toggle-on Color"),
            qtw.options.oncolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Toggle-off Color"),
            qtw.options.offcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype in ["slider", "vslider"]
        CImGui.ColorEdit4(
            mlstr("SliderGrab Color"),
            qtw.options.grabcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Active SliderGrab Color"),
            qtw.options.grabactivecolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
end

function widgetcolormenu(opts::QuantityWidgetOption)
    CImGui.ColorEdit4(
        mlstr("Text Color"),
        opts.textcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Background Color"),
        opts.bgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Border Color"),
        opts.bdcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Hovered Color"),
        opts.hoveredcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Actived Color"),
        opts.activecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Hint Text Color"),
        opts.hintcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Combo Button Color"),
        opts.combobtcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Popup Background Color"),
        opts.popupcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Image Background Color"),
        opts.imgbgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Image Tint Color"),
        opts.imgtintcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Toggle-on Color"),
        opts.oncolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Toggle-off Color"),
        opts.offcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("SliderGrab Color"),
        opts.grabcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Active SliderGrab Color"),
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

function initialize!(insw::InstrWidget, addr)
    insw.draggable = false
    empty!(insw.qtlist)
    qtlist = []
    for qtwg in insw.qtws
        for qtw in qtwg
            qtw.options.globaloptions && copycolors!(qtw.options, insw.options)
            qtw.options.globaloptions = false
            qtw.qtype in ["sweep", "set", "read"] && push!(qtlist, qtw.name)
        end
    end
    append!(insw.qtlist, Set(qtlist))
    refresh1(insw, addr)
end

function refresh1(insw::InstrWidget, addr)
    if haskey(INSTRBUFFERVIEWERS, insw.instrnm) && haskey(INSTRBUFFERVIEWERS[insw.instrnm], addr)
        fetchibvs = wait_remotecall_fetch(
            workers()[1], INSTRBUFFERVIEWERS, insw.instrnm, addr, insw.qtlist; timeout=120
        ) do ibvs, ins, addr, qtlist
            empty!(INSTRBUFFERVIEWERS)
            merge!(INSTRBUFFERVIEWERS, ibvs)
            ct = Controller(ins, addr)
            try
                login!(CPU, ct)
                for (qtnm, qt) in filter(x -> x.first in qtlist, INSTRBUFFERVIEWERS[ins][addr].insbuf.quantities)
                    getfunc = Symbol(ins, :_, qtnm, :_get) |> eval
                    qt.read = ct(getfunc, CPU, Val(:read))
                end
            catch e
                @error(
                    "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                    instrument = string(ins, ": ", addr),
                    exception = e
                )
            finally
                logout!(CPU, ct)
            end
            return INSTRBUFFERVIEWERS
        end
        Threads.@spawn if !isnothing(fetchibvs)
            for (qtnm, qt) in filter(x -> x.first in insw.qtlist, INSTRBUFFERVIEWERS[insw.instrnm][addr].insbuf.quantities)
                qt.read = fetchibvs[insw.instrnm][addr].insbuf.quantities[qtnm].read
                updatefront!(qt)
            end
        end
    end
end

function trigselector!(qtw::QuantityWidget, insw::InstrWidget)
    if !isempty(qtw.options.bindingqtwidxes)
        for (gi, idxes) in enumerate(qtw.options.bindingqtwidxes)
            if !isempty(idxes)
                list = qtw.options.selectorlist[gi]
                if !isempty(list)
                    alias = list[min(qtw.options.selectedidx, length(list))]
                    for idx in idxes
                        ij = idxtoij(insw, idx)
                        if !isnothing(ij)
                            i, j = ij
                            if i <= length(insw.qtws) && j <= length(insw.qtws[i])
                                if insw.qtws[i][j].name == "_Panel_"
                                    insw.qtws[i][j].alias = alias
                                else
                                    optv = [(qtnm, qt.type) for (qtnm, qt) in INSCONF[insw.instrnm].quantities if qt.alias == alias]
                                    if !isempty(optv)
                                        qtnm, type = only(optv)
                                        if type == insw.qtws[i][j].qtype
                                            insw.qtws[i][j].name = qtnm
                                            insw.qtws[i][j].alias = alias
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for qtwg in insw.qtws
        for qtw in filter(x -> x.name == "_QuantitySelector_", qtwg)
            if !isempty(qtw.options.bindingqtwidxes) && !isempty(qtw.options.bindingqtwidxes[1])
                ij = idxtoij(insw, qtw.options.bindingqtwidxes[1][1])
                if !isnothing(ij)
                    alias = insw.qtws[ij[1]][ij[2]].alias
                    selectedidx = findfirst(==(alias), qtw.options.selectorlist[1])
                    if !isnothing(selectedidx)
                        qtw.options.selectedidx = selectedidx
                        qtw.alias = qtw.options.selectorlabels[qtw.options.selectedidx]
                    end
                end
            end
        end
    end
end