@option mutable struct QuantityWidgetOption
    uitype::String = "none"
    globaloptions::Bool = false
    allowoverlap::Bool = false
    useimage::Bool = false
    autorefresh::Bool = false
    textsize::String = "normal"
    textscale::Cfloat = 1
    textinside::Bool = true
    itemsize::Vector{Cfloat} = [0, 0]
    rounding::Cfloat = 4
    grabrounding::Cfloat = 6
    bdrounding::Cfloat = 0
    bdthickness::Cfloat = 0
    comboflags::Cint = 0
    uv0::Vector{Cfloat} = [0, 0]
    uv1::Vector{Cfloat} = [1, 1]
    framepadding::Cfloat = -1
    vertices::Vector{Vector{Cfloat}} = [[0, 0], [0, 0], [0, 0]]
    circlesegments::Cint = 24
    ticknum::Cint = 6
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
end

const INSWCONF = OrderedDict{String,Vector{InstrWidget}}() #仪器注册表

function copyvars!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[1:29]
        fnm in [:uitype, :vertices] && continue
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function copycolors!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[30:end]
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function copyglobal!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[1:29]
        fnm in [:rounding, :grabrounding, :bdrounding, :bdthickness] && continue
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function edit(qtw::QuantityWidget, insbuf::InstrBuffer, instrnm, addr, gopts::QuantityWidgetOption)
    opts = qtw.options.globaloptions ? gopts : qtw.options
    qtw.options.globaloptions && copyglobal!(opts, qtw.options)
    scale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    scaling = scale != 1
    if scaling
        itemsizeo = copy(opts.itemsize)
        csposo = copy(opts.vertices[1])
        opts.itemsize *= scale
        opts.vertices[1] *= scale
    end
    CImGui.SetCursorScreenPos(CImGui.GetWindowPos() .+ opts.vertices[1])
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
    if scaling
        opts.itemsize = itemsizeo
        opts.vertices[1] = csposo
    end
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
    cspos = CImGui.GetWindowPos()
    a = cspos .+ opts.vertices[1]
    b = a .+ opts.vertices[2]
    c = a .+ opts.vertices[3]
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
    cspos = CImGui.GetWindowPos()
    a = cspos .+ opts.vertices[1]
    b = a .+ opts.vertices[2]
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
        unsafe_load(CImGui.GetIO().KeyCtrl) && (qt.uindex += 1; getvalU!(qt); resolveunitlist(qt, instrnm, addr))
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:readdashboard})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    val, mrange1, mrange2, start = parseforreaddashboard(qt)
    DashBoardPanel(
        stcstr(instrnm, addr, qt.name), val, [mrange1, mrange2], start;
        size=opts.itemsize,
        ruler=opts.ticknum,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        num_segments=opts.circlesegments,
        col=opts.bgcolor,
        colon=opts.oncolor,
        colbase=opts.grabcolor,
        colind=opts.checkedcolor,
        coltxt=opts.textcolor,
        colrect=opts.bdcolor,
    )
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return false
end
function parseforreaddashboard(qt::AbstractQuantity)
    readings = split(qt.showval, ',')
    U, Us = @c getU(qt.utype, &qt.uindex)
    if U == ""
        return [0, 0, 400, true]
    else
        # @info readings qt.showval
        if length(readings) == 4
            val = tryparse(Float64, readings[1])
            mrange1 = tryparse(Float64, readings[2])
            mrange2 = tryparse(Float64, readings[3])
            start = tryparse(Bool, readings[4])
            if isnothing(val) || isnothing(mrange1) || isnothing(mrange2) || isnothing(start)
                return [0, 0, 400, true]
            else
                Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0
                return [val / Uchange, mrange1 / Uchange, mrange2 / Uchange, start]
            end
        else
            return [0, 0, 400, true]
        end
    end
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

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:inputctrlset})
    opts.textsize == "big" && CImGui.PushFont(PLOTFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    @c ColoredInputTextWithHintRSZ("##set", mlstr("set"), &qt.set;
        size=opts.itemsize,
        rounding=opts.rounding,
        bdrounding=opts.bdrounding,
        thickness=opts.bdthickness,
        colfrm=opts.bgcolor,
        coltxt=opts.textcolor,
        colhint=opts.hintcolor,
        colrect=opts.bdcolor
    )
    trig = CImGui.IsItemDeactivated()
    trig && (apply!(qt, instrnm, addr); updatefront!(qt))
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
    draggable::Bool = false
    draglayers::Dict{Int,Union{DragRect,Vector{DragPoint}}} = Dict()
    qtwgroup::Vector{Cint} = []
    qtwgrouppos::Vector{Vector{Cfloat}} = []
    qtwgroupposoffset::Vector{Cfloat} = [0, 0]
    qtwgroupsize::Vector{Vector{Cfloat}} = []
    qtwgroupsizeoffset::Vector{Cfloat} = [0, 0]
    copiedopts::Ref{QuantityWidgetOption} = QuantityWidgetOption()
    showslnums::Bool = false
    showpos::Bool = false
    dragmode::String = ""
    dragmodes::Vector{String} = ["swap", "before", "after"]
    showcols::Cint = 6
    selectedqtw::Cint = 0
    acd::AnimateChild = AnimateChild(rate=(8, 12))
    fakewidget::QuantityWidget = QuantityWidget()
    maxwindowsize::CImGui.ImVec2 = (400, 600)
    windowpos::Bool = true # false left true right
    global function edit(insw::InstrWidget, insbuf::InstrBuffer, addr, p_open, id; usingit=false)
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
            CImGui.BeginChild("drawing area")
            for (i, qtw) in enumerate(insw.qtws)
                CImGui.PushID(i)
                !usingit && draggable && igBeginDisabled(true)
                if edit(qtw, insbuf, insw.instrnm, addr, insw.options)
                    qtw.qtype in qtypes && qtw.options.uitype ∉ continuousuitypes && Threads.@spawn refresh1(insw, addr)
                    qtw.name == "_QuantitySelector_" && (trigselector!(qtw, insw); Threads.@spawn refresh1(insw, addr))
                end
                !usingit && draggable && igEndDisabled()
                if !usingit
                    if haskey(draglayers, i)
                        isselected = selectedqtw == i
                        ingroup = i in qtwgroup
                        isselectedoringroup = isselected || ingroup
                        if draggable
                            if isselectedoringroup
                                if draglayers[i] isa Vector
                                    for dp in draglayers[i]
                                        dp.col = MORESTYLE.Colors.WidgetRectSelected
                                    end
                                    isselected && (draglayers[i][1].col = MORESTYLE.Colors.SelectedWidgetBt)
                                else
                                    draglayers[i].col = MORESTYLE.Colors.WidgetRectSelected
                                    draglayers[i].colbd = MORESTYLE.Colors.WidgetBorderSelected
                                    isselected && (draglayers[i].col = MORESTYLE.Colors.SelectedWidgetBt)
                                end
                            end
                            @c showlayer(insw, qtw, i, &isanyitemdragging)
                            if isselectedoringroup && haskey(draglayers, i)
                                if draglayers[i] isa Vector
                                    for dp in draglayers[i]
                                        dp.col = MORESTYLE.Colors.WidgetRect
                                    end
                                else
                                    draglayers[i].col = MORESTYLE.Colors.WidgetRect
                                    draglayers[i].colbd = MORESTYLE.Colors.WidgetBorder
                                end
                            end
                        else
                            if ingroup
                                drawlist = CImGui.GetWindowDrawList()
                                wpos = CImGui.GetWindowPos()
                                if qtw.name == "_Shape_" && qtw.options.uitype in ["triangle", "line"]
                                    a = wpos .+ qtw.options.vertices[1]
                                    b = a .+ qtw.options.vertices[2]
                                    if qtw.options.uitype == "triangle"
                                        c = a .+ qtw.options.vertices[3]
                                        CImGui.AddTriangleFilled(
                                            drawlist, a, b, c,
                                            CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.WidgetRectSelected)
                                        )
                                        CImGui.AddTriangle(
                                            drawlist, a, b, c,
                                            CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.WidgetBorderSelected),
                                            max(4, 2qtw.options.bdthickness)
                                        )
                                    elseif qtw.options.uitype == "line"
                                        CImGui.AddLine(
                                            drawlist, a, b,
                                            CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.WidgetBorderSelected),
                                            max(4, 2qtw.options.bdthickness)
                                        )
                                    end
                                else
                                    a = wpos .+ qtw.options.vertices[1]
                                    b = a .+ qtw.options.itemsize
                                    CImGui.AddRectFilled(
                                        drawlist, a, b,
                                        CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.WidgetRectSelected)
                                    )
                                    CImGui.AddRect(
                                        drawlist, a, b,
                                        CImGui.ColorConvertFloat4ToU32(
                                            isselected ? MORESTYLE.Colors.SelectedWidgetBt : MORESTYLE.Colors.WidgetBorderSelected
                                        ),
                                        0, 0, max(4, 2qtw.options.bdthickness)
                                    )
                                end
                            end
                        end
                    else
                        addnewlayer(qtw, i)
                    end
                end
                CImGui.PopID()
            end
            if !usingit && draggable
                CImGui.SetCursorPos(0, 0)
                ColoredButton("##max"; size=(-1, -1), colbt=(0, 0, 0, 0), colbth=(0, 0, 0, 0), colbta=(0, 0, 0, 0))
            end
            CImGui.EndChild()
        end
        usingit || CImGui.IsWindowCollapsed() || (insw.windowsize .= CImGui.GetWindowSize() ./ scale)
        CImGui.End()
        CImGui.PopStyleColor()
    end

    global function showlayer(insw::InstrWidget, qtw::QuantityWidget, i::Int, isanyitemdragging::Ref{Bool})
        ishovered = false
        dl = draglayers[i]
        if (qtw.name == "_Shape_" && (
            (qtw.options.uitype == "triangle" && dl isa Vector && length(dl) == 3) ||
            (qtw.options.uitype == "line" && dl isa Vector && length(dl) == 2) ||
            (qtw.options.uitype in ["rect", "circle"] && dl isa DragRect)
        )) || (qtw.name != "_Shape_" && dl isa DragRect)
            @c showlayer(insw, qtw, dl, i, isanyitemdragging, &ishovered)
        else
            delete!(draglayers, i)
        end
        if ishovered && CImGui.IsMouseClicked(0)
            unsafe_load(CImGui.GetIO().KeyCtrl) ? addtogroup(qtw, i) : selectedqtw = i
        end
    end

    global function showlayer(insw::InstrWidget, qtw::QuantityWidget, dr::DragRect, i, isanyitemdragging::Ref{Bool}, ishovered::Ref{Bool})
        cspos = CImGui.GetWindowPos()
        dr.posmin = cspos .+ qtw.options.vertices[1]
        dr.posmax = dr.posmin .+ (qtw.name == "_Shape_" || qtw.options.uitype == "readdashboard" ? qtw.options.itemsize : CImGui.GetItemRectSize())
        (isanyitemdragging[] || qtw.hold) && (dr.dragging = false; dr.gripdragging = false)
        edit(dr)
        isanyitemdragging[] |= dr.dragging | dr.gripdragging
        if dr.dragging && i in qtwgroup
            qtwgroupposoffset .= dr.posmin .- cspos .- qtwgrouppos[findfirst(==(i), qtwgroup)]
            updategrouppos(insw)
        end
        if dr.dragging || dr.gripdragging
            qtw.options.itemsize = dr.posmax .- dr.posmin
            qtw.options.vertices[1] = dr.posmin .- cspos
        end
        ishovered[] = dr.hovered || dr.griphovered
    end

    global function showlayer(insw::InstrWidget, qtw::QuantityWidget, dps::Vector{DragPoint}, i, isanyitemdragging::Ref{Bool}, ishovered::Ref{Bool})
        ### 同步位置
        cspos = CImGui.GetWindowPos()
        dps[1].pos = cspos .+ qtw.options.vertices[1]
        for j in eachindex(dps)[2:end]
            dps[j].pos = dps[1].pos .+ qtw.options.vertices[j]
        end
        ### 绘制图层
        for dp in dps
            (isanyitemdragging[] || qtw.hold) && (dp.dragging = false)
            edit(dp)
            isanyitemdragging[] |= dp.dragging
        end
        ## 反同步位置
        if dps[1].dragging
            if i in qtwgroup
                qtwgroupposoffset .= dps[1].pos .- cspos .- qtwgrouppos[findfirst(==(i), qtwgroup)]
                updategrouppos(insw)
            else
                qtw.options.vertices[1] .= dps[1].pos .- cspos
            end
        end
        for j in eachindex(dps)[2:end]
            dps[j].dragging && (qtw.options.vertices[j] .= dps[j].pos .- dps[1].pos)
        end
        ishovered[] = |([dp.hovered for dp in dps]...)
    end

    global function addnewlayer(qtw::QuantityWidget, i)
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
            newlayer[1].radius = 12
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

    global function view(insw::InstrWidget)
        openmodw = false
        dragmode == "" && (dragmode = mlstr("swap"))
        # CImGui.BeginChild(stcstr(insw.instrnm, insw.name), (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
        CImGui.BeginChild("view widgets all")
        CImGui.Columns(2)
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Widgets"))
        CImGui.BeginChild("view widgets", (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
        btw = (CImGui.GetContentRegionAvailWidth() - unsafe_load(IMGUISTYLE.ItemSpacing.x) * (showcols - 1)) / showcols
        for (i, qtw) in enumerate(insw.qtws)
            CImGui.PushID(i)
            showcols == 1 || i % showcols == 1 || CImGui.SameLine()
            view(insw, qtw, i; size=(btw, Cfloat(0)))
            if CImGui.BeginPopupContextItem()
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, stcstr("QT", " ", i))
                draggable && @c CImGui.MenuItem(
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
                # optionsmenu(qtw, insw.instrnm)
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

        CImGui.NextColumn()
        coloffsetminus = CImGui.GetWindowContentRegionWidth() - CImGui.GetColumnOffset(1)
        CImGui.BeginChild("options")
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Options"))
        @c CImGui.Checkbox(mlstr("Show Serial Numbers"), &showslnums)
        @c CImGui.Checkbox(mlstr("Show Positions"), &showpos)
        @c CImGui.Checkbox(mlstr("Draggable"), &draggable)
        @c ComBoS(mlstr("Dragging Mode"), &dragmode, mlstr.(dragmodes))
        @c CImGui.SliderInt(mlstr("Display Columns"), &showcols, 1, 12, "%d")
        if isempty(qtwgroup)
            qtwgroupposoffset == [0, 0] || (qtwgroupposoffset .= [0, 0])
            qtwgroupsizeoffset == [0, 0] || (qtwgroupsizeoffset .= [0, 0])
        else
            CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##emptygroup"), (-1, 0)) && emptygroup()
            CImGui.DragFloat2(
                mlstr("Position Offset"), qtwgroupposoffset, 1, -6000, 6000, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
            ) && updategrouppos(insw)
            CImGui.DragFloat2(
                mlstr("Size Offset"), qtwgroupsizeoffset, 1, -6000, 6000, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
            ) && updategroupsize(insw)
        end
        optioncursor = CImGui.GetCursorScreenPos()
        globalwidgetoptionsmenu(insw)
        CImGui.EndChild()
        CImGui.EndChild()
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
            optionchildh = CImGui.GetWindowPos().y + CImGui.GetWindowSize().y - optioncursor.y
            acd.targetsize = (coloffsetminus - unsafe_load(IMGUISTYLE.WindowPadding.x), optionchildh)
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

    global function view(insw::InstrWidget, qtw::QuantityWidget, id; size=(0, 0))
        pos = if showpos
            stcstr(
                mlstr("Position"), " ", "X : ",
                qtw.options.vertices[1][1], "    ", qtw.options.vertices[1][1] + qtw.options.itemsize[1], '\n',
                mlstr("Position"), " ", "Y : ",
                qtw.options.vertices[1][2], "    ", qtw.options.vertices[1][2] + qtw.options.itemsize[2]
            )
        else
            ""
        end
        label = if qtw.name == "_Panel_"
            if qtw.options.useimage
                stcstr(showslnums ? stcstr(id, " ", "Image\nButton") : "Image\nButton", '\n', pos)
            else
                stcstr(showslnums ? id : "", " Text", " \n ", mlstr(qtw.alias), '\n', pos, "###", id)
            end
        elseif qtw.name == "_Shape_"
            stcstr(showslnums ? stcstr(id, " ") : "", "Shape\n", qtw.options.uitype, '\n', pos)
        elseif qtw.name == "_Image_"
            stcstr(showslnums ? stcstr(id, " Image\n ") : " Image\n ", '\n', pos)
        elseif qtw.name == "_QuantitySelector_"
            label = join([string('[', join(idxes, ' '), ']') for idxes in qtw.options.bindingqtwidxes], '\n')
            stcstr(showslnums ? stcstr(id, " ") : "", "Selector\n", label, '\n', pos, "###", id)
        else
            stcstr(showslnums ? stcstr(id, " ") : "", qtw.alias, "\n", qtw.options.uitype, '\n', pos)
        end
        ispushstylecol = selectedqtw == id || id in qtwgroup
        ispushstylecol && CImGui.PushStyleColor(
            CImGui.ImGuiCol_Button,
            selectedqtw == id ? MORESTYLE.Colors.SelectedWidgetBt : MORESTYLE.Colors.WidgetRectSelected
        )
        if CImGui.Button(label, size)
            if unsafe_load(CImGui.GetIO().KeyCtrl)
                addtogroup(qtw, id)
            elseif unsafe_load(CImGui.GetIO().KeyShift)
                if selectedqtw == 0
                    selectedqtw = id
                elseif selectedqtw == id
                    addtogroup(qtw, id)
                elseif selectedqtw < id
                    for i in selectedqtw:id
                        addtogroup(insw.qtws[i], i)
                    end
                else
                    for i in id:selectedqtw
                        addtogroup(insw.qtws[i], i)
                    end
                end
            else
                selectedqtw = selectedqtw == id ? 0 : id
            end
        end
        ispushstylecol && CImGui.PopStyleColor()
        if draggable && qtw.hold
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

    global function addtogroup(qtw, i)
        if i in qtwgroup
            idxes = findall(==(i), qtwgroup)
            deleteat!(qtwgroup, idxes)
            deleteat!(qtwgrouppos, idxes)
            deleteat!(qtwgroupsize, idxes)
        else
            push!(qtwgroup, i)
            push!(qtwgrouppos, copy(qtw.options.vertices[1]))
            push!(qtwgroupsize, copy(qtw.options.itemsize))
        end
    end

    global function emptygroup()
        empty!(qtwgroup)
        empty!(qtwgrouppos)
        empty!(qtwgroupsize)
    end

    global function updategrouppos(insw::InstrWidget)
        for (i, pos) in zip(qtwgroup, qtwgrouppos)
            insw.qtws[i].options.vertices[1] .= pos .+ qtwgroupposoffset
        end
    end

    global function updategroupsize(insw::InstrWidget)
        for (i, sz) in zip(qtwgroup, qtwgroupsize)
            insw.qtws[i].options.itemsize .= sz .+ qtwgroupsizeoffset
        end
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
    setuitypesall = ["read", "unit", "readunit", "inputset", "inputctrlset", "ctrlset", "combo", "radio", "slider", "vslider", "toggle"]
    setuitypesnoopts = ["read", "unit", "readunit", "inputset", "inputctrlset", "ctrlset"]
    setuitypesno2opts = ["read", "unit", "readunit", "inputset", "inputctrlset", "ctrlset", "combo", "radio", "slider", "vslider"]
    # readnumuitypes = ["read", "unit", "readunit", "readdashboard"]
    readuitypes = ["read", "unit", "readunit", "readdashboard"]
    otheruitypes = ["none"]
    shapetypes = ["rect", "triangle", "circle", "line"]
    qtselectoruitypes = ["combo", "slider", "vslider"]
    textsizes = ["normal", "big"]
    manualinputalias::String = ""
    global function optionsmenu(qtw::QuantityWidget, instrnm)
        CImGui.Text(stcstr(mlstr("Position"), " ", "X : "))
        CImGui.SameLine()
        CImGui.Text(stcstr(qtw.options.vertices[1][1], "    ", qtw.options.vertices[1][1] + qtw.options.itemsize[1]))
        CImGui.Text(stcstr(mlstr("Position"), " ", "Y : "))
        CImGui.SameLine()
        CImGui.Text(stcstr(qtw.options.vertices[1][2], "    ", qtw.options.vertices[1][2] + qtw.options.itemsize[2]))
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
                        setuitypesno2opts
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
            qtw.name == "_QuantitySelector_" || @c CImGui.Checkbox(mlstr("Global Options"), &qtw.options.globaloptions)
            @c CImGui.Checkbox(mlstr("Allow Overlap"), &qtw.options.allowoverlap)
            @c CImGui.Checkbox(mlstr("Auto Refresh"), &qtw.options.autorefresh)
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
            qtw.options.uitype in ["slider", "vslider"] && @c CImGui.Checkbox(mlstr("Text Inside"), &qtw.options.textinside)
            qtw.options.uitype == "combo" && @c CImGui.CheckboxFlags(
                mlstr("No ArrowButton"), &qtw.options.comboflags, CImGui.ImGuiComboFlags_NoArrowButton
            )
            CImGui.DragFloat2(mlstr("Item Size"), qtw.options.itemsize)
            if qtw.options.uitype == "triangle"
                CImGui.DragFloat2(stcstr(mlstr("Vertex"), " a"), qtw.options.vertices[1])
                CImGui.DragFloat2(stcstr(mlstr("Vertex"), " b ", mlstr("from"), " a"), qtw.options.vertices[2])
                CImGui.DragFloat2(stcstr(mlstr("Vertex"), " c ", mlstr("from"), " a"), qtw.options.vertices[3])
            elseif qtw.options.uitype == "circle"
                CImGui.DragFloat2(mlstr("Cursor Position"), qtw.options.vertices[1])
                @c CImGui.DragInt(
                    mlstr("Segments"), &qtw.options.circlesegments, 1, 6, 60, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
            elseif qtw.options.uitype == "line"
                CImGui.DragFloat2(stcstr(mlstr("Vertex"), " a"), qtw.options.vertices[1])
                CImGui.DragFloat2(stcstr(mlstr("Vertex"), " b ", mlstr("from"), " a"), qtw.options.vertices[2])
            else
                CImGui.DragFloat2(mlstr("Cursor Position"), qtw.options.vertices[1])
            end
            if qtw.options.uitype == "readdashboard"
                @c CImGui.DragInt(
                    mlstr("Segments"), &qtw.options.circlesegments, 1, 6, 60, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragInt(
                    mlstr("Ticks"), &qtw.options.ticknum, 1, 2, 36, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
            end
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
            @c CImGui.SliderInt(mlstr("Binding Index to RadioButton"), &qtw.options.bindingidx, 1, qtw.numoptvs)
            CImGui.SliderInt2(mlstr("Binding Index to ON/OFF"), qtw.options.bindingonoff, 1, qtw.numoptvs)
        end
        if qtw.name == "_QuantitySelector_" && CImGui.CollapsingHeader(mlstr("Selector Options"))
            # @c ComBoS(mlstr("Selector Type"), &qtw.options.selectortype, selectortypes)
            @c CImGui.DragInt(
                mlstr("Binding Numbers"), &qtw.options.selectornum, 1, 1, 12, "%d",
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
                if @c InputTextRSZ(mlstr("Binding to Widgets"), &bindingqtwidxesstr)
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
    if qtw.options.uitype != "readdashboard"
        CImGui.ColorEdit4(
            mlstr("Hovered"),
            qtw.options.hoveredcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        CImGui.ColorEdit4(
            mlstr("Activated"),
            qtw.options.activecolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
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
    if qtw.options.uitype in ["readdashboard", "toggle", "ctrlsweep"]
        CImGui.ColorEdit4(
            mlstr("Toggle-on"),
            qtw.options.oncolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        qtw.options.uitype != "readdashboard" && CImGui.ColorEdit4(
            mlstr("Toggle-off"),
            qtw.options.offcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype in ["readdashboard", "slider", "vslider"]
        CImGui.ColorEdit4(
            mlstr("SliderGrab"),
            qtw.options.grabcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
        qtw.options.uitype != "readdashboard" && CImGui.ColorEdit4(
            mlstr("Active SliderGrab"),
            qtw.options.grabactivecolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
end

function globalwidgetoptionsmenu(insw::InstrWidget)
    # if CImGui.CollapsingHeader(mlstr("Global Options"))
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Global Options"))
    CImGui.BeginChild("global widget options")
    @c InputTextRSZ(mlstr("Widget Name"), &insw.name)
    @c CImGui.Checkbox(mlstr("Use Wallpaper"), &insw.usewallpaper)
    if insw.usewallpaper
        bgpath = insw.wallpaperpath
        inputbgpath = @c InputTextRSZ("##wallpaper", &bgpath)
        CImGui.SameLine()
        selectbgpath = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##wallpaper"))
        selectbgpath && (bgpath = pick_file(abspath(bgpath); filterlist="png,jpg,jpeg,tif,bmp"))
        CImGui.SameLine()
        CImGui.Text(mlstr("Wallpaper"))
        if inputbgpath || selectbgpath
            if isfile(bgpath)
                insw.wallpaperpath = bgpath
            else
                CImGui.SameLine()
                CImGui.TextColored(MORESTYLE.Colors.LogError, mlstr("path does not exist!!!"))
            end
        end
        CImGui.ColorEdit4(
            stcstr(mlstr("Background Tint")),
            insw.bgtintcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    CImGui.DragFloat2(
        mlstr("Window Size"),
        insw.windowsize, 1, 6, 6000, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
    )
    @c CImGui.DragFloat(
        mlstr("Frame Rounding"),
        &insw.options.rounding,
        1, 0, 60, "%.3f",
        CImGui.ImGuiSliderFlags_AlwaysClamp
    )
    @c CImGui.DragFloat(
        mlstr("Grab Rounding"),
        &insw.options.grabrounding,
        1, 0, 60, "%.3f",
        CImGui.ImGuiSliderFlags_AlwaysClamp
    )
    @c CImGui.DragFloat(
        mlstr("Border Rounding"),
        &insw.options.bdrounding,
        1, 0, 60, "%.3f",
        CImGui.ImGuiSliderFlags_AlwaysClamp
    )
    @c CImGui.DragFloat(
        mlstr("Border Thickness"),
        &insw.options.bdthickness,
        1, 0, 60, "%.3f",
        CImGui.ImGuiSliderFlags_AlwaysClamp
    )
    CImGui.ColorEdit4(
        mlstr("Window"),
        insw.windowbgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Text"),
        insw.options.textcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Background"),
        insw.options.bgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Border"),
        insw.options.bdcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Hovered"),
        insw.options.hoveredcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Activated"),
        insw.options.activecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Hint Text"),
        insw.options.hintcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Combo Button"),
        insw.options.combobtcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Popup Background"),
        insw.options.popupcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Image Background"),
        insw.options.imgbgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Image Tint"),
        insw.options.imgtintcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Toggle-on"),
        insw.options.oncolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Toggle-off"),
        insw.options.offcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("SliderGrab"),
        insw.options.grabcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Active SliderGrab"),
        insw.options.grabactivecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.EndChild()
    # end
end

function initialize!(insw::InstrWidget, addr)
    empty!(insw.qtlist)
    qtlist = []
    autoreflist = []
    for qtw in insw.qtws
        qtw.options.globaloptions && copycolors!(qtw.options, insw.options)
        qtw.options.globaloptions = false
        if qtw.qtype in ["sweep", "set", "read"]
            push!(qtlist, qtw.name)
            qtw.options.autorefresh && push!(autoreflist, qtw.name)
        end
    end
    append!(insw.qtlist, Set(qtlist))
    refresh1(insw, addr)
    if haskey(INSTRBUFFERVIEWERS, insw.instrnm) && haskey(INSTRBUFFERVIEWERS[insw.instrnm], addr)
        if !isempty(autoreflist)
            SYNCSTATES[Int(IsAutoRefreshing)] = true
            INSTRBUFFERVIEWERS[insw.instrnm][addr].insbuf.isautorefresh = true
            for (_, qt) in filter(x -> x.first in autoreflist, INSTRBUFFERVIEWERS[insw.instrnm][addr].insbuf.quantities)
                qt.isautorefresh = true
            end
        end
    end
end

function exit!(insw::InstrWidget, addr)
    autoreflist = []
    for qtw in insw.qtws
        qtw.qtype in ["sweep", "set", "read"] && qtw.options.autorefresh && push!(autoreflist, qtw.name)
    end
    if haskey(INSTRBUFFERVIEWERS, insw.instrnm) && haskey(INSTRBUFFERVIEWERS[insw.instrnm], addr)
        if !isempty(autoreflist)
            for (_, qt) in filter(x -> x.first in autoreflist, INSTRBUFFERVIEWERS[insw.instrnm][addr].insbuf.quantities)
                qt.isautorefresh = false
            end
        end
    end
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
    isempty(qtw.options.bindingqtwidxes) && return
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
                            optv = [(qtnm, qt) for (qtnm, qt) in INSCONF[insw.instrnm].quantities if qt.alias == alias]
                            if !isempty(optv)
                                qtnm, qt = only(optv)
                                if qt.type == insw.qtws[i].qtype
                                    if qt.type == "set"
                                        uitype = insw.qtws[i].options.uitype
                                        noopts = ["read", "unit", "readunit", "inputset", "inputctrlset", "ctrlset"]
                                        lopts = length(qt.optkeys)
                                        ((uitype == "toggle" && lopts != 2) || (uitype ∉ noopts && lopts == 0)) && break
                                    end
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
    for qtw in filter(x -> x.name == "_QuantitySelector_", insw.qtws)
        if !isempty(qtw.options.bindingqtwidxes[1])
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