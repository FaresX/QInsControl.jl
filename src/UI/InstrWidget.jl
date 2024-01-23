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
    hold::Bool = false
    options::QuantityWidgetOption = QuantityWidgetOption()
end

@option mutable struct InstrWidget
    instrnm::String = "VirtualInstr"
    name::String = "widget 1"
    qtws::Vector{QuantityWidget} = []
    windowsize::Vector{Cfloat} = [600, 600]
    usewallpaper::Bool = false
    wallpaperpath::String = ""
    windowbgcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    bgtintcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    options::QuantityWidgetOption = QuantityWidgetOption()
    qtlist::Vector{String} = []
    showcols::Cint = 6
    draggable::Bool = false
end

const INSWCONF = OrderedDict{String,Vector{InstrWidget}}() #仪器注册表

function copyvars!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[1:30]
        fnm == :uitype && continue
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function copycolors!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[31:end]
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function edit(qtw::QuantityWidget, insbuf::InstrBuffer, instrnm, addr, gopts::QuantityWidgetOption)
    opts = qtw.options.globaloptions ? gopts : qtw.options
    scale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    opts.itemsize *= scale
    opts.cursorscreenpos *= scale
    qtw.options.globaloptions && copyvars!(opts, qtw.options)
    CImGui.SetCursorScreenPos(CImGui.GetWindowPos() .+ opts.cursorscreenpos)
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
        size=opts.itemsize,
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
        size=opts.itemsize,
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
    qtypes::Vector{String} = ["sweep", "set", "read"]
    continuousuitypes::Vector{String} = ["inputstep", "inputstop", "dragdelay", "inputset"]
    draglayers::Dict{Int,Union{DragRect,Vector{DragPoint}}} = Dict()
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
            for (i, qtw) in enumerate(insw.qtws)
                CImGui.PushID(i)
                insw.draggable && igBeginDisabled(true)
                if edit(qtw, insbuf, insw.instrnm, addr, insw.options)
                    qtw.qtype in qtypes && qtw.options.uitype ∉ continuousuitypes && Threads.@spawn refresh1(insw, addr)
                    qtw.name == "_QuantitySelector_" && (trigselector!(qtw, insw); Threads.@spawn refresh1(insw, addr))
                end
                insw.draggable && igEndDisabled()
                if insw.draggable
                    if haskey(draglayers, i)
                        ishovered = false
                        if qtw.name == "_Shape_"
                            if qtw.options.uitype == "triangle"
                                if draglayers[i] isa Vector && length(draglayers[i]) == 3
                                    cspos = CImGui.GetWindowPos() .+ qtw.options.cursorscreenpos
                                    dps = draglayers[i]
                                    dps[1].pos = cspos .+ qtw.options.trianglea
                                    dps[2].pos = cspos .+ qtw.options.triangleb
                                    dps[3].pos = cspos .+ qtw.options.trianglec
                                    for dp in dps
                                        (isanyitemdragging || qtw.hold) && (dp.dragging = false)
                                        edit(dp)
                                        isanyitemdragging |= dp.dragging
                                    end
                                    qtw.options.trianglea .= dps[1].pos .- cspos
                                    qtw.options.triangleb .= dps[2].pos .- cspos
                                    qtw.options.trianglec .= dps[3].pos .- cspos
                                    ishovered = dps[1].hovered || dps[2].hovered || dps[3].hovered
                                else
                                    delete!(draglayers, i)
                                end
                            elseif qtw.options.uitype == "line"
                                if draglayers[i] isa Vector && length(draglayers[i]) == 2
                                    cspos = CImGui.GetWindowPos() .+ qtw.options.cursorscreenpos
                                    dps = draglayers[i]
                                    dps[1].pos = cspos .+ qtw.options.trianglea
                                    dps[2].pos = cspos .+ qtw.options.triangleb
                                    for dp in dps
                                        (isanyitemdragging || qtw.hold) && (dp.dragging = false)
                                        edit(dp)
                                        isanyitemdragging |= dp.dragging
                                    end
                                    qtw.options.trianglea .= dps[1].pos .- cspos
                                    qtw.options.triangleb .= dps[2].pos .- cspos
                                    ishovered = dps[1].hovered || dps[2].hovered
                                else
                                    delete!(draglayers, i)
                                end
                            else
                                if draglayers[i] isa DragRect
                                    cspos = CImGui.GetWindowPos()
                                    dr = draglayers[i]
                                    dr.posmin = cspos .+ qtw.options.cursorscreenpos
                                    dr.posmax = dr.posmin .+ qtw.options.itemsize
                                    (isanyitemdragging || qtw.hold) && (dr.dragging = false; dr.gripdragging = false)
                                    edit(dr)
                                    isanyitemdragging |= dr.dragging | dr.gripdragging
                                    qtw.options.itemsize = dr.posmax .- dr.posmin
                                    qtw.options.cursorscreenpos = dr.posmin .- cspos
                                    ishovered = dr.hovered || dr.griphovered
                                else
                                    delete!(draglayers, i)
                                end
                            end
                        else
                            if draglayers[i] isa DragRect
                                cspos = CImGui.GetWindowPos()
                                dr = draglayers[i]
                                dr.posmin = CImGui.GetItemRectMin()
                                dr.posmax = CImGui.GetItemRectMax()
                                (isanyitemdragging || qtw.hold) && (dr.dragging = false; dr.gripdragging = false)
                                edit(dr)
                                isanyitemdragging |= dr.dragging | dr.gripdragging
                                qtw.options.itemsize = dr.posmax .- dr.posmin
                                qtw.options.cursorscreenpos = dr.posmin .- cspos
                                ishovered = dr.hovered || dr.griphovered
                            else
                                delete!(draglayers, i)
                            end
                        end
                        ishovered && CImGui.IsMouseClicked(0) && (selectedqtw = i)
                    else
                        newlayer = if qtw.name == "_Shape_"
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
                        if newlayer isa Vector
                            for dp in newlayer
                                dp.col = MORESTYLE.Colors.WidgetRect
                                dp.colh = MORESTYLE.Colors.WidgetRectHovered
                                dp.cola = MORESTYLE.Colors.WidgetRectDragging
                            end
                        else
                            newlayer.col = MORESTYLE.Colors.WidgetRect
                            newlayer.colh = MORESTYLE.Colors.WidgetRectHovered
                            newlayer.cola = MORESTYLE.Colors.WidgetRectDragging
                            newlayer.colbd = MORESTYLE.Colors.WidgetBorder
                            newlayer.colbdh = MORESTYLE.Colors.WidgetBorderHovered
                            newlayer.colbda = MORESTYLE.Colors.WidgetBorderDragging
                        end
                        push!(draglayers, i => newlayer)
                    end
                end
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

    copiedopts::Ref{QuantityWidgetOption} = QuantityWidgetOption()
    showslnums::Bool = false
    dragmode::String = ""
    dragmodes::Vector{String} = ["swap", "before", "after"]
    selectedqtw::Cint = 0
    acd::AnimateChild = AnimateChild(rate=(8, 12))
    fakewidget::QuantityWidget = QuantityWidget()
    maxwindowsize::CImGui.ImVec2 = (400, 600)
    windowpos::Bool = true # false left true right
    global function view(insw::InstrWidget)
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
        CImGui.SameLine()
        CImGui.PushItemWidth(4CImGui.GetFontSize())
        @c CImGui.DragInt(mlstr("display columns"), &insw.showcols, 1, 1, 36, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Widgets"))
        for (i, qtw) in enumerate(insw.qtws)
            CImGui.PushID(i)
            i % insw.showcols == 1 || CImGui.SameLine()
            @c view(qtw, i, showslnums, &selectedqtw; showhold=insw.draggable)
            if CImGui.BeginPopupContextItem()
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, stcstr("QT", " ", i))
                insw.draggable && @c CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.HoldPin, " ", mlstr(qtw.hold ? "Drag" : "Hold")), C_NULL, &qtw.hold
                )
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
                addwidgetmenu(insw)
                addwidgetmenu(insw, i; mode=:before)
                addwidgetmenu(insw, i; mode=:after)
                convertmenu(insw, i)
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (deleteat!(insw.qtws, i); break)
                optionsmenu(qtw, insw.instrnm)
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
                        if dragmode == mlstr("before")
                            insert!(insw.qtws, i, insw.qtws[payload_i])
                            deleteat!(insw.qtws, payload_i < i ? payload_i : payload_i + 1)
                        elseif dragmode == mlstr("after")
                            insert!(insw.qtws, i + 1, insw.qtws[payload_i])
                            deleteat!(insw.qtws, payload_i < i ? payload_i : payload_i + 1)
                        else
                            insw.qtws[i] = insw.qtws[payload_i]
                            insw.qtws[payload_i] = qtw
                        end
                        break
                    end
                end
                CImGui.EndDragDropTarget()
            end
            CImGui.Unindent()
            CImGui.PopID()
        end
        if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
            CImGui.IsMouseClicked(1) && (openmodw = true)
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
            selectedqtw == 0 || (acd.targetsize = maxwindowsize)
        else
            mainwindowsz = CImGui.GetItemRectSize()
            acd.targetsize = (2mainwindowsz.x / 5, 4mainwindowsz.y / 5)
            acd.rate = acd.targetsize ./ 20 * 60 / unsafe_load(CImGui.GetIO().Framerate)
            selectedqtw == 0 && (acd.targetsize = (4, 6))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg))
            changesize = false
            acd("optionsmenu", true, 0) do
                if windowpos
                    CImGui.Button(ICONS.ICON_LEFT_LONG) && (windowpos = false; changesize = true)
                    CImGui.SameLine()
                end
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, stcstr("QT ", selectedqtw))
                if !windowpos
                    CImGui.SameLine(0, CImGui.GetFontSize())
                    CImGui.Button(ICONS.ICON_RIGHT_LONG) && (windowpos = true; changesize = true)
                end
                CImGui.BeginChild("optionsmenu inside", (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
                if selectedqtw == 0
                    optionsmenu(fakewidget, "")
                elseif 0 < selectedqtw <= length(insw.qtws)
                    optionsmenu(insw.qtws[selectedqtw], insw.instrnm)
                    fakewidget = insw.qtws[selectedqtw]
                end
                CImGui.EndChild()
            end
            changesize && (acd.presentsize = (4, 6))
            CImGui.PopStyleColor()
        end

        openmodw && CImGui.OpenPopup(stcstr("view widget", insw.instrnm, insw.name))
        if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
            CImGui.OpenPopupOnItemClick(stcstr("view widget", insw.instrnm, insw.name))
        end
        if CImGui.BeginPopup(stcstr("view widget", insw.instrnm, insw.name))
            addwidgetmenu(insw)
            CImGui.EndPopup()
        end
    end
end

function view(qtw::QuantityWidget, id, showslnums, selectedqtw::Ref{Cint}; showhold=false)
    label = if qtw.name == "_Panel_"
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
    if showhold && qtw.hold
        posmin = CImGui.GetItemRectMin()
        posmax = CImGui.GetItemRectMax()
        ftsz = CImGui.GetFontSize()
        CImGui.AddText(
            CImGui.GetWindowDrawList(), GLOBALFONT, ftsz, (posmax.x - ftsz / 2, posmin.y - ftsz / 2),
            CImGui.ColorConvertFloat4ToU32(CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)),
            MORESTYLE.Icons.HoldPin
        )
    end
end

function addwidgetmenu(insw::InstrWidget, i=0; mode=:addlast)
    if CImGui.BeginMenu(
        stcstr(
            MORESTYLE.Icons.NewFile, " ",
            mlstr(
                if mode == :addlast
                    "Add"
                elseif mode == :before
                    "Add Before"
                elseif mode == :after
                    "Add After"
                end
            )
        )
    )
        newqtw = nothing
        if CImGui.MenuItem(mlstr("Panel"))
            newqtw = QuantityWidget(name="_Panel_", alias="")
        end
        if CImGui.MenuItem(mlstr("Shape"))
            newqtw = QuantityWidget(name="_Shape_", alias="")
            newqtw.options.globaloptions = false
            newqtw.options.uitype = "rect"
            newqtw.options.bdcolor = [0, 0, 0, 1]
        end
        if CImGui.MenuItem(mlstr("Image"))
            newqtw = QuantityWidget(name="_Image_", alias="")
        end
        if CImGui.MenuItem(mlstr("Selector"))
            newqtw = QuantityWidget(name="_QuantitySelector_", alias="")
            newqtw.options.uitype = "combo"
        end
        if CImGui.BeginMenu(mlstr("Sweep Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "sweep" || continue
                    if CImGui.MenuItem(qt.alias)
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias, qtype="sweep")
                        newqtw.options.uitype = "read"
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
                    end
                end
            end
            CImGui.EndMenu()
        end
        CImGui.EndMenu()
        if !isnothing(newqtw)
            if mode == :addlast
                push!(insw.qtws, newqtw)
            elseif mode == :before
                insert!(insw.qtws, i, newqtw)
            elseif mode == :after
                insert!(insw.qtws, i + 1, newqtw)
            end
        end
    end
end

function convertmenu(insw::InstrWidget, i)
    if CImGui.BeginMenu(
        stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Convert to")),
        insw.qtws[i].name ∉ ["_Panel_", "_QuantitySelector_", "_Image_", "_Shape_"]
    )
        if CImGui.BeginMenu(mlstr("Sweep Quantity"))
            if haskey(INSCONF, insw.instrnm)
                for (qtnm, qt) in INSCONF[insw.instrnm].quantities
                    qt.type == "sweep" || continue
                    if CImGui.MenuItem(qt.alias)
                        insw.qtws[i] = QuantityWidget(
                            name=qtnm,
                            alias=qt.alias,
                            qtype="sweep",
                            options=insw.qtws[i].options
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
                        insw.qtws[i] = QuantityWidget(
                            name=qtnm,
                            alias=qt.alias,
                            qtype="set",
                            numoptvs=length(qt.optvalues),
                            options=insw.qtws[i].options
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
                        insw.qtws[i] = QuantityWidget(
                            name=qtnm,
                            alias=qt.alias,
                            qtype="read",
                            options=insw.qtws[i].options
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
        if CImGui.CollapsingHeader(mlstr("Variable Options"))
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
        if CImGui.CollapsingHeader(mlstr("Color Options"))
            widgetcolormenu(qtw)
        end
    end
end

function widgetcolormenu(qtw::QuantityWidget)
    CImGui.ColorEdit4(
        mlstr("Text"),
        qtw.options.textcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Background"),
        qtw.options.bgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Border"),
        qtw.options.bdcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Hovered"),
        qtw.options.hoveredcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Actived"),
        qtw.options.activecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    if qtw.options.uitype in ["inputstep", "inputstop", "inputset"]
        CImGui.ColorEdit4(
            mlstr("Hint Text"),
            qtw.options.hintcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype == "combo"
        CImGui.ColorEdit4(
            mlstr("Combo Button"),
            qtw.options.combobtcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Popup Background"),
            qtw.options.popupcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.name == "_Image_"
        CImGui.ColorEdit4(
            mlstr("Image Background"),
            qtw.options.imgbgcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Image Tint"),
            qtw.options.imgtintcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype == "toggle"
        CImGui.ColorEdit4(
            mlstr("Toggle-on"),
            qtw.options.oncolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Toggle-off"),
            qtw.options.offcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype in ["slider", "vslider"]
        CImGui.ColorEdit4(
            mlstr("SliderGrab"),
            qtw.options.grabcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Active SliderGrab"),
            qtw.options.grabactivecolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
end

function widgetcolormenu(opts::QuantityWidgetOption)
    CImGui.ColorEdit4(
        mlstr("Text"),
        opts.textcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Background"),
        opts.bgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Border"),
        opts.bdcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Hovered"),
        opts.hoveredcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Actived"),
        opts.activecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Hint Text"),
        opts.hintcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Combo Button"),
        opts.combobtcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Popup Background"),
        opts.popupcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Image Background"),
        opts.imgbgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Image Tint"),
        opts.imgtintcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Toggle-on"),
        opts.oncolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Toggle-off"),
        opts.offcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("SliderGrab"),
        opts.grabcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Active SliderGrab"),
        opts.grabactivecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
end

function initialize!(insw::InstrWidget, addr)
    insw.draggable = false
    empty!(insw.qtlist)
    qtlist = []
    for qtw in insw.qtws
        qtw.options.globaloptions && copycolors!(qtw.options, insw.options)
        qtw.options.globaloptions = false
        qtw.qtype in ["sweep", "set", "read"] && push!(qtlist, qtw.name)
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
                    for i in idxes
                        if 0 < i <= length(insw.qtws)
                            if insw.qtws[i].name == "_Panel_"
                                insw.qtws[i].alias = alias
                            else
                                optv = [(qtnm, qt.type) for (qtnm, qt) in INSCONF[insw.instrnm].quantities if qt.alias == alias]
                                if !isempty(optv)
                                    qtnm, type = only(optv)
                                    if type == insw.qtws[i].qtype
                                        insw.qtws[i].name = qtnm
                                        insw.qtws[i].alias = alias
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for qtw in filter(x -> x.name == "_QuantitySelector_", insw.qtws)
        if !isempty(qtw.options.bindingqtwidxes) && !isempty(qtw.options.bindingqtwidxes[1])
            if 0 < qtw.options.bindingqtwidxes[1][1] <= length(insw.qtws)
                alias = insw.qtws[qtw.options.bindingqtwidxes[1][1]].alias
                selectedidx = findfirst(==(alias), qtw.options.selectorlist[1])
                if !isnothing(selectedidx)
                    qtw.options.selectedidx = selectedidx
                    qtw.alias = qtw.options.selectorlabels[qtw.options.selectedidx]
                end
            end
        end
    end
end