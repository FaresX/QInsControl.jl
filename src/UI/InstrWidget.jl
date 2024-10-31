@option mutable struct QuantityWidgetOption
    uitype::String = "none"
    globaloptions::Bool = true
    allowoverlap::Bool = false
    useimage::Bool = false
    autorefresh::Bool = false
    refreshrate::Cfloat = 1
    pathes::Vector{String} = []
    rate::Cint = 1
    textsize::String = "normal"
    textscale::Cfloat = 1
    textinside::Bool = true
    notimes::Bool = false
    notime::Bool = false
    itemsize::Vector{Cfloat} = [60, 60]
    rounding::Cfloat = 4
    grabrounding::Cfloat = 6
    bdrounding::Cfloat = 0
    bdthickness::Cfloat = 0
    comboflags::Cint = 0
    uv0::Vector{Cfloat} = [0, 0]
    uv1::Vector{Cfloat} = [1, 1]
    framepadding::Vector{Cfloat} = [6, 6]
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
    readorinput::Bool = true
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
    numread::Cint = 1
    hold::Bool = false
    options::QuantityWidgetOption = QuantityWidgetOption()
    selected::Bool = false
    posbuf::Vector{Cfloat} = [0, 0]
    sizebuf::Vector{Cfloat} = [0, 0]
end

@option mutable struct InstrWidget
    instrnm::String = "VirtualInstr"
    name::String = "widget 1"
    qtws::Vector{QuantityWidget} = []
    windowflags::CImGui.ImGuiWindowFlags = 0
    windowsize::Vector{Cfloat} = [600, 600]
    usewallpaper::Bool = false
    wallpaperpath::String = ""
    rate::Cint = 1
    windowbgcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    bgtintcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    titlebgcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    titlebgactivecolor::Vector{Cfloat} = [0.8, 0.8, 0.8, 1.000]
    titlebgcollapsedcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 0.5]
    globaloptions::Bool = true
    qtlist::Vector{String} = []
    posoffset::Vector{Cfloat} = [0, 0]
    sizeoffset::Vector{Cfloat} = [0, 0]
end

function Base.isapprox(insw1::InstrWidget, insw2::InstrWidget)
    return all(
        fdnm == :qtws ? insw1.qtws ≈ insw2.qtws : getproperty(insw1, fdnm) == getproperty(insw2, fdnm)
        for fdnm in fieldnames(InstrWidget)
    )
end
function Base.isapprox(qtws1::Vector{QuantityWidget}, qtws2::Vector{QuantityWidget})
    return length(qtws1) == length(qtws2) && all(qtws1 .≈ qtws2)
end
function Base.isapprox(qtw1::QuantityWidget, qtw2::QuantityWidget)
    return all(getproperty(qtw1, fdnm) == getproperty(qtw2, fdnm) for fdnm in fieldnames(QuantityWidget)[1:end-2])
end
function Base.isequal(opts1::QuantityWidgetOption, opts2::QuantityWidgetOption)
    return all(getproperty(opts1, fdnm) == getproperty(opts2, fdnm) for fdnm in fieldnames(QuantityWidgetOption))
end

function copyinsw!(insw1::InstrWidget, insw2::InstrWidget)
    for fdnm in fieldnames(InstrWidget)
        setproperty!(insw1, fdnm, getproperty(insw2, fdnm))
    end
end

const INSWCONF = OrderedDict{String,Vector{InstrWidget}}() #仪器注册表

function copyvars!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[1:35]
        fnm in [:uitype, :vertices] && continue
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function copycolors!(opts1, opts2)
    fnms = fieldnames(QuantityWidgetOption)
    for fnm in fnms[36:end]
        setproperty!(opts1, fnm, getproperty(opts2, fnm))
    end
end

function edit(qtw::QuantityWidget, insbuf::InstrBuffer, instrnm, addr)
    opts = qtw.options
    scale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    scaling = scale != 1
    if scaling
        itemsizeo = copy(opts.itemsize)
        csposo = copy(opts.vertices[1])
        opts.itemsize *= scale
        opts.vertices[1] *= scale
    end
    CImGui.SetCursorScreenPos(CImGui.GetWindowPos() .+ opts.vertices[1])
    opts.allowoverlap && igSetNextItemAllowOverlap()
    trig = if haskey(insbuf.quantities, qtw.name)
        edit(opts, insbuf.quantities[qtw.name], instrnm, addr, Val(Symbol(qtw.options.uitype)))
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
    if scaling
        opts.itemsize = itemsizeo
        opts.vertices[1] = csposo
    end
    return trig
end

function editPanel(qtw::QuantityWidget, opts::QuantityWidgetOption)
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    isempty(opts.pathes) && push!(opts.pathes, "")
    trig = if opts.globaloptions
        ImageColoredButtonRect(mlstr(qtw.alias), opts.pathes[1], opts.useimage; size=opts.itemsize, rate=opts.rate)
    else
        ImageColoredButtonRect(
            mlstr(qtw.alias), opts.pathes[1], opts.useimage;
            size=opts.itemsize,
            rate=opts.rate,
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
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function editShape(opts::QuantityWidgetOption, ::Val{:rect})
    drawlist = CImGui.GetWindowDrawList()
    cspos = CImGui.GetCursorScreenPos()
    b = cspos .+ opts.itemsize
    CImGui.AddRectFilled(
        drawlist, cspos, b, opts.bgcolor,
        opts.rounding, ImDrawFlags_RoundCornersAll
    )
    CImGui.AddRect(
        drawlist, cspos, b, opts.bdcolor,
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
    CImGui.AddTriangleFilled(drawlist, a, b, c, opts.bgcolor)
    CImGui.AddTriangle(drawlist, a, b, c, opts.bdcolor, opts.bdthickness)
    return false
end

function editShape(opts::QuantityWidgetOption, ::Val{:circle})
    drawlist = CImGui.GetWindowDrawList()
    cspos = CImGui.GetCursorScreenPos()
    O = cspos .+ opts.itemsize ./ 2
    r = min(opts.itemsize...) / 2
    CImGui.AddCircleFilled(drawlist, O, r, opts.bgcolor, opts.circlesegments)
    CImGui.AddCircle(drawlist, O, r, opts.bdcolor, opts.circlesegments, opts.bdthickness)
    return false
end

function editShape(opts::QuantityWidgetOption, ::Val{:line})
    drawlist = CImGui.GetWindowDrawList()
    cspos = CImGui.GetWindowPos()
    a = cspos .+ opts.vertices[1]
    b = a .+ opts.vertices[2]
    CImGui.AddLine(drawlist, a, b, opts.bdcolor, opts.bdthickness)
    return false
end

function editImage(::QuantityWidget, opts::QuantityWidgetOption)
    isempty(opts.pathes) && push!(opts.pathes, "")
    if opts.globaloptions
        Image(opts.pathes[1]; size=opts.itemsize, rate=opts.rate)
    else
        Image(
            opts.pathes[1];
            size=opts.itemsize,
            rate=opts.rate,
            uv0=opts.uv0,
            uv1=opts.uv1,
            tint_col=opts.imgtintcolor,
            border_col=opts.bdcolor
        )
    end
    return false
end

function editQuantitySelector(qtw::QuantityWidget, opts::QuantityWidgetOption, ::Val{:combo})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredCombo(
            stcstr("##selector", qtw.alias), &qtw.alias, opts.selectorlabels, opts.comboflags; size=opts.itemsize
        )
    else
        @c ColoredCombo(
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
    end
    trig && (opts.selectedidx = findfirst(==(qtw.alias), opts.selectorlabels))
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function editQuantitySelector(qtw::QuantityWidget, opts::QuantityWidgetOption, ::Val{:slider})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredSlider(
            CImGui.SliderInt,
            stcstr(opts.textinside ? "##" : "", qtw.alias),
            &opts.selectedidx, 1, opts.selectornum, opts.textinside ? qtw.alias : "";
            size=opts.itemsize
        )
    else
        @c ColoredSlider(
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
    end
    trig && (qtw.alias = opts.selectorlabels[opts.selectedidx])
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function editQuantitySelector(qtw::QuantityWidget, opts::QuantityWidgetOption, ::Val{:vslider})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredVSlider(
            CImGui.VSliderInt,
            stcstr(opts.textinside ? "##" : "", qtw.alias),
            &opts.selectedidx, 1, opts.selectornum, opts.textinside ? qtw.alias : "";
            size=opts.itemsize
        )
    else
        @c ColoredVSlider(
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
    end
    trig && (qtw.alias = opts.selectorlabels[opts.selectedidx])
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

edit(::QuantityWidgetOption, ::AbstractQuantity, _, _, ::Val) = CImGui.Button(mlstr("Invalid UI Type"))

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:read})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        ColoredButtonRect(qt.showval[opts.bindingidx]; size=opts.itemsize)
    else
        ColoredButtonRect(
            qt.showval[opts.bindingidx];
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
    end
    trig && getread!(qt, instrnm, addr)
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:unit})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        ColoredButtonRect(qt.showU; size=opts.itemsize)
    else
        ColoredButtonRect(
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
    end
    trig && (qt.uindex += 1; getvalU!(qt); resolveunitlist(qt, instrnm, addr))
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:readunit})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        ColoredButtonRect(stcstr(qt.showval[opts.bindingidx], " ", qt.showU); size=opts.itemsize)
    else
        ColoredButtonRect(
            stcstr(qt.showval[opts.bindingidx], " ", qt.showU);
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
    end
    if trig
        getread!(qt, instrnm, addr)
        unsafe_load(CImGui.GetIO().KeyCtrl) && (qt.uindex += 1; getvalU!(qt); resolveunitlist(qt, instrnm, addr))
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:readdashboard})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    val, mrange1, mrange2, start = parseforreaddashboard(qt)
    if opts.globaloptions
        DashBoardPanel(stcstr(instrnm, addr, qt.name), val, [mrange1, mrange2], start; size=opts.itemsize)
    else
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
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return false
end
function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:readdashboarddigits})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        ColoredButtonRect(@sprintf("%g", parseforreaddashboard(qt)[1]); size=opts.itemsize)
    else
        ColoredButtonRect(
            @sprintf("%g", parseforreaddashboard(qt)[1]);
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
    end
    trig && getread!(qt, instrnm, addr)
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end
function edit(opts::QuantityWidgetOption, qt::AbstractQuantity, instrnm, addr, ::Val{:readdashboarddigitsunit})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        ColoredButtonRect(stcstr(@sprintf("%g", parseforreaddashboard(qt)[1]), " ", qt.showU); size=opts.itemsize)
    else
        ColoredButtonRect(
            stcstr(@sprintf("%g", parseforreaddashboard(qt)[1]), " ", qt.showU);
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
    end
    if trig
        getread!(qt, instrnm, addr)
        unsafe_load(CImGui.GetIO().KeyCtrl) && (qt.uindex += 1; getvalU!(qt); resolveunitlist(qt, instrnm, addr))
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end
function parseforreaddashboard(qt::AbstractQuantity)
    U, Us = @c getU(qt.utype, &qt.uindex)
    if U == ""
        return [0, 0, 400, true]
    else
        if length(qt.showval) == 4
            val = tryparse(Float64, qt.showval[1])
            mrange1 = tryparse(Float64, qt.showval[2])
            mrange2 = tryparse(Float64, qt.showval[3])
            start = tryparse(Bool, qt.showval[4])
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
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredInputTextWithHintRSZ("##step", mlstr("step"), &qt.step; size=opts.itemsize)
    else
        @c ColoredInputTextWithHintRSZ(
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
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:inputstop})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredInputTextWithHintRSZ("##stop", mlstr("stop"), &qt.stop; size=opts.itemsize)
    else
        @c ColoredInputTextWithHintRSZ(
            "##stop", mlstr("stop"), &qt.stop;
            size=opts.itemsize,
            rounding=opts.rounding,
            bdrounding=opts.bdrounding,
            thickness=opts.bdthickness,
            colfrm=opts.bgcolor,
            coltxt=opts.textcolor,
            colhint=opts.hintcolor,
            colrect=opts.bdcolor
        )
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:dragdelay})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredDragWidget(
            CImGui.DragFloat,
            "##delay", &qt.delay, 0.01, 0.01, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp;
            size=opts.itemsize
        )
    else
        @c ColoredDragWidget(
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
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, _, _, ::Val{:progressbar})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        ColoredProgressBarRect(
            calcfraction(qt.presenti, qt.nstep),
            progressmark(qt.presenti, qt.nstep, qt.elapsedtime; opts.notimes, opts.notime);
            size=opts.itemsize
        )
    else
        ColoredProgressBarRect(
            calcfraction(qt.presenti, qt.nstep),
            progressmark(qt.presenti, qt.nstep, qt.elapsedtime; opts.notimes, opts.notime);
            size=opts.itemsize,
            rounding=opts.rounding,
            bdrounding=opts.bdrounding,
            thickness=opts.bdthickness,
            colbar=opts.bgcolor,
            colbara=opts.activecolor,
            coltxt=opts.textcolor,
            colrect=opts.bdcolor
        )
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SweepQuantity, instrnm, addr, ::Val{:ctrlsweep})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ToggleButtonRect(mlstr(qt.issweeping ? opts.stoptext : opts.starttext), &qt.issweeping; size=opts.itemsize)
    else
        @c ToggleButtonRect(
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
    end
    trig && qt.issweeping && apply!(qt, instrnm, addr)
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    # qt.issweeping && updatefront!(qt)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, _, _, ::Val{:inputset})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredInputTextWithHintRSZ("##set", mlstr(opts.starttext), &qt.set; size=opts.itemsize)
    else
        @c ColoredInputTextWithHintRSZ("##set", mlstr(opts.starttext), &qt.set;
            size=opts.itemsize,
            rounding=opts.rounding,
            bdrounding=opts.bdrounding,
            thickness=opts.bdthickness,
            colfrm=opts.bgcolor,
            coltxt=opts.textcolor,
            colhint=opts.hintcolor,
            colrect=opts.bdcolor
        )
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:ctrlset})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        ColoredButtonRect(mlstr(opts.starttext); size=opts.itemsize)
    else
        ColoredButtonRect(
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
    end
    trig && apply!(qt, instrnm, addr)
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:inputctrlset})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    if opts.globaloptions
        @c ColoredInputTextWithHintRSZ("##set", mlstr(opts.starttext), &qt.set; size=opts.itemsize)
    else
        @c ColoredInputTextWithHintRSZ(
            "##set", mlstr(opts.starttext), &qt.set;
            size=opts.itemsize,
            rounding=opts.rounding,
            bdrounding=opts.bdrounding,
            thickness=opts.bdthickness,
            colfrm=opts.bgcolor,
            coltxt=opts.textcolor,
            colhint=opts.hintcolor,
            colrect=opts.bdcolor
        )
    end
    trig = CImGui.IsItemDeactivated()
    trig && apply!(qt, instrnm, addr)
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:readinputctrlset})
    if opts.readorinput
        trig = edit(opts, qt, instrnm, addr, Val(:read))
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (opts.readorinput = false)
    else
        trig = edit(opts, qt, instrnm, addr, Val(:inputctrlset))
        CImGui.IsItemDeactivated() && (opts.readorinput = true)
    end
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:combo})
    presentv = qt.optkeys[qt.optedidx]
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredCombo(stcstr("##", qt.alias), &presentv, qt.optkeys, opts.comboflags; size=opts.itemsize)
    else
        @c ColoredCombo(
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
    end
    if trig
        qt.optedidx = findfirst(==(presentv), qt.optkeys)
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:radio})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredRadioButton(qt.optkeys[opts.bindingidx], &qt.optedidx, opts.bindingidx)
    else
        @c ColoredRadioButton(
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
    end
    if trig
        qt.optedidx = opts.bindingidx
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:slider})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredSlider(
            CImGui.SliderInt,
            stcstr(opts.textinside ? "##" : "", qt.optkeys[qt.optedidx]),
            &qt.optedidx, 1, length(qt.optvalues), opts.textinside ? qt.optkeys[qt.optedidx] : "";
            size=opts.itemsize
        )
    else
        @c ColoredSlider(
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
    end
    if trig
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:vslider})
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ColoredVSlider(
            CImGui.VSliderInt,
            stcstr(opts.textinside ? "##" : "", qt.optkeys[qt.optedidx]),
            &qt.optedidx, 1, length(qt.optvalues), opts.textinside ? qt.optkeys[qt.optedidx] : "";
            size=opts.itemsize
        )
    else
        @c ColoredVSlider(
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
    end
    if trig
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

function edit(opts::QuantityWidgetOption, qt::SetQuantity, instrnm, addr, ::Val{:toggle})
    ison = qt.optedidx == opts.bindingonoff[1]
    opts.textsize == "big" && CImGui.PushFont(BIGFONT)
    originscale = unsafe_load(CImGui.GetIO().FontGlobalScale)
    CImGui.SetWindowFontScale(opts.textscale)
    trig = if opts.globaloptions
        @c ToggleButtonRect(qt.optkeys[opts.bindingonoff[ison ? 1 : 2]], &ison; size=opts.itemsize)
    else
        @c ToggleButtonRect(
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
    end
    if trig
        qt.optedidx = opts.bindingonoff[ison ? 1 : 2]
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr, true)
    end
    opts.textsize == "big" && CImGui.PopFont()
    CImGui.SetWindowFontScale(originscale)
    return trig
end

let
    qtypes::Vector{String} = ["sweep", "set", "read"]
    continuousuitypes::Vector{String} = ["inputstep", "inputstop", "dragdelay", "inputset"]
    draggable::Bool = false
    disabled::Bool = true
    draglayers::Dict{Int,Union{DragRect,Vector{DragPoint}}} = Dict()
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
    redolist::Dict{InstrWidget,LoopVector{InstrWidget}} = Dict()
    spacing::Vector{Cfloat} = [0, 0]
    global function edit(insw::InstrWidget, insbuf::InstrBuffer, addr, p_open, id; usingit=false)
        scale = unsafe_load(CImGui.GetIO().FontGlobalScale)
        CImGui.SetNextWindowSize(insw.windowsize * scale)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_WindowBg,
            insw.globaloptions ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_WindowBg) : insw.windowbgcolor
        )
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_TitleBg,
            insw.globaloptions ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TitleBg) : insw.titlebgcolor
        )
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_TitleBgActive,
            insw.globaloptions ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TitleBgActive) : insw.titlebgactivecolor
        )
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_TitleBgCollapsed,
            insw.globaloptions ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TitleBgCollapsed) : insw.titlebgcollapsedcolor
        )
        if CImGui.Begin(
            stcstr(
                INSCONF[insw.instrnm].conf.icon, " ", insw.instrnm, " ", addr, " ", insw.name,
                "###", insw.instrnm, addr, id
            ),
            p_open,
            insw.windowflags | (addr == "" ? CImGui.ImGuiWindowFlags_NoDocking : 0)
        )
            isanyitemdragging = false
            if insw.globaloptions
                SetWindowBgImage()
            else
                SetWindowBgImage(insw.wallpaperpath; rate=insw.rate, use=insw.usewallpaper, tint_col=insw.bgtintcolor)
            end
            CImGui.BeginChild("drawing area")
            for (i, qtw) in enumerate(insw.qtws)
                CImGui.PushID(i)
                igBeginDisabled(!usingit && draggable && disabled)
                if edit(qtw, insbuf, insw.instrnm, addr)
                    if qtw.qtype in qtypes && qtw.options.uitype ∉ continuousuitypes
                        Threads.@spawn @trycatch mlstr("task failed!!!") refresh1(insw, addr; blacklist=[qtw.name])
                    end
                    if qtw.name == "_QuantitySelector_"
                        trigselector!(qtw, insw)
                        refreshqtlist!(insw)
                        Threads.@spawn @trycatch mlstr("task failed!!!") refresh1(insw, addr)
                    end
                end
                igEndDisabled()
                if !usingit
                    if haskey(draglayers, i)
                        isselected = selectedqtw == i
                        isselectedoringroup = isselected || qtw.selected
                        if draggable
                            if isselectedoringroup
                                if draglayers[i] isa Vector
                                    for dp in draglayers[i]
                                        dp.col = MORESTYLE.Colors.WidgetRectSelected
                                    end
                                    draglayers[i][1].col = if isselected && !qtw.selected
                                        MORESTYLE.Colors.SelectedWidgetBt
                                    elseif !isselected && qtw.selected
                                        MORESTYLE.Colors.WidgetRectSelected
                                    else
                                        (MORESTYLE.Colors.SelectedWidgetBt .+ MORESTYLE.Colors.WidgetRectSelected) ./ 2
                                    end
                                else
                                    draglayers[i].colbd = MORESTYLE.Colors.WidgetBorderSelected
                                    draglayers[i].col = if isselected && !qtw.selected
                                        MORESTYLE.Colors.SelectedWidgetBt
                                    elseif !isselected && qtw.selected
                                        MORESTYLE.Colors.WidgetRectSelected
                                    else
                                        (MORESTYLE.Colors.SelectedWidgetBt .+ MORESTYLE.Colors.WidgetRectSelected) ./ 2
                                    end
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
                            if qtw.selected
                                drawlist = CImGui.GetWindowDrawList()
                                wpos = CImGui.GetWindowPos()
                                if qtw.name == "_Shape_" && qtw.options.uitype in ["triangle", "line"]
                                    a = wpos .+ qtw.options.vertices[1]
                                    b = a .+ qtw.options.vertices[2]
                                    if qtw.options.uitype == "triangle"
                                        c = a .+ qtw.options.vertices[3]
                                        CImGui.AddTriangleFilled(
                                            drawlist, a, b, c,
                                            MORESTYLE.Colors.WidgetRectSelected
                                        )
                                        CImGui.AddTriangle(
                                            drawlist, a, b, c,
                                            MORESTYLE.Colors.WidgetBorderSelected,
                                            max(4, 2qtw.options.bdthickness)
                                        )
                                    elseif qtw.options.uitype == "line"
                                        CImGui.AddLine(
                                            drawlist, a, b,
                                            MORESTYLE.Colors.WidgetBorderSelected,
                                            max(4, 2qtw.options.bdthickness)
                                        )
                                    end
                                else
                                    a = wpos .+ qtw.options.vertices[1]
                                    b = a .+ qtw.options.itemsize
                                    CImGui.AddRectFilled(
                                        drawlist, a, b,
                                        MORESTYLE.Colors.WidgetRectSelected
                                    )
                                    CImGui.AddRect(
                                        drawlist, a, b,
                                        isselected ? MORESTYLE.Colors.SelectedWidgetBt : MORESTYLE.Colors.WidgetBorderSelected,
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
        CImGui.IsWindowCollapsed() || (insw.windowsize .= CImGui.GetWindowSize() ./ scale)
        CImGui.End()
        CImGui.PopStyleColor(4)
    end

    global function showlayer(insw::InstrWidget, qtw::QuantityWidget, i::Int, isanyitemdragging::Ref{Bool})
        ishovered = false
        dl = draglayers[i]
        if (qtw.name == "_Shape_" && (
            (qtw.options.uitype == "triangle" && dl isa Vector && length(dl) == 3) ||
            (qtw.options.uitype == "line" && dl isa Vector && length(dl) == 2) ||
            (qtw.options.uitype in ["rect", "circle"] && dl isa DragRect)
        )) || (qtw.name != "_Shape_" && dl isa DragRect)
            @c showlayer(insw, qtw, dl, isanyitemdragging, &ishovered)
        else
            delete!(draglayers, i)
        end
        if ishovered && CImGui.IsMouseClicked(0)
            if unsafe_load(CImGui.GetIO().KeyCtrl)
                if !qtw.hold
                    qtw.selected ⊻= true
                    qtw.selected && addtogroup!(qtw)
                end
            else
                selectedqtw = i
            end
        end
    end

    global function showlayer(insw::InstrWidget, qtw::QuantityWidget, dr::DragRect, isanyitemdragging::Ref{Bool}, ishovered::Ref{Bool})
        cspos = CImGui.GetWindowPos()
        dr.posmin = cspos .+ qtw.options.vertices[1]
        dr.posmax = dr.posmin .+ (qtw.name == "_Shape_" || qtw.options.uitype == "readdashboard" ? qtw.options.itemsize : CImGui.GetItemRectSize())
        (isanyitemdragging[] || qtw.hold) && (dr.dragging = false; dr.gripdragging = false)
        qtw.selected && (dr.gripdragging = false)
        edit(dr)
        isanyitemdragging[] |= dr.dragging | dr.gripdragging
        if dr.dragging && qtw.selected
            insw.posoffset .= dr.posmin .- cspos .- qtw.posbuf
            updategrouppos!(insw)
        end
        if dr.dragging || dr.gripdragging
            qtw.options.itemsize = dr.posmax .- dr.posmin
            qtw.options.vertices[1] = dr.posmin .- cspos
        end
        ishovered[] = dr.hovered || dr.griphovered
    end

    global function showlayer(insw::InstrWidget, qtw::QuantityWidget, dps::Vector{DragPoint}, isanyitemdragging::Ref{Bool}, ishovered::Ref{Bool})
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
            if qtw.selected
                insw.posoffset .= dps[1].pos .- cspos .- qtw.posbuf
                updategrouppos!(insw)
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
            newlayer.thickness = MORESTYLE.Variables.WidgetBorderThickness
        end
        draglayers[i] = newlayer
    end

    global function view(insw::InstrWidget)
        openmodw = false
        dragmode == "" && (dragmode = mlstr("swap"))
        if !haskey(redolist, insw)
            redolist[insw] = LoopVector(fill(InstrWidget(), CONF.Register.historylen))
            redolist[insw][] = deepcopy(insw)
        end
        if !CImGui.IsMouseDown(0)
            redolist[insw][] ≈ insw || (move!(redolist[insw]); redolist[insw][] = deepcopy(insw))
        end
        if unsafe_load(CImGui.GetIO().KeyCtrl)
            if CImGui.IsKeyPressed(ImGuiKey_Z, false) && !isempty(redolist[insw][-1].qtws)
                move!(redolist[insw], -1)
                copyinsw!(insw, deepcopy(redolist[insw][]))
            elseif CImGui.IsKeyPressed(ImGuiKey_Y, false) && !isempty(redolist[insw][1].qtws)
                move!(redolist[insw])
                copyinsw!(insw, deepcopy(redolist[insw][]))
            end
        end
        CImGui.BeginChild("view widgets all")
        CImGui.Columns(2)
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Widgets"))
        CImGui.BeginChild("view widgets", (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
        btw = (CImGui.GetContentRegionAvail().x - unsafe_load(IMGUISTYLE.ItemSpacing.x) * (showcols - 1)) / showcols
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
        coloffsetminus = CImGui.GetWindowWidth() - CImGui.GetColumnOffset(1)
        CImGui.BeginChild("options")
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Options"))
        stbw = CImGui.GetContentRegionAvail().x / 2
        if CImGui.Button(stcstr(MORESTYLE.Icons.Undo, " ", mlstr("Undo"))) && !isempty(redolist[insw][-1].qtws)
            move!(redolist[insw], -1)
            copyinsw!(insw, deepcopy(redolist[insw][]))
        end
        CImGui.SameLine()
        if CImGui.Button(stcstr(MORESTYLE.Icons.Redo, " ", mlstr("Redo"))) && !isempty(redolist[insw][1].qtws)
            move!(redolist[insw])
            copyinsw!(insw, deepcopy(redolist[insw][]))
        end
        @c CImGui.Checkbox(mlstr("Show Serial Numbers"), &showslnums)
        @c CImGui.Checkbox(mlstr("Show Positions"), &showpos)
        @c CImGui.Checkbox(mlstr("Draggable"), &draggable)
        draggable && (CImGui.SameLine(); @c CImGui.Checkbox(mlstr("Disable"), &disabled))
        @c ComboS(mlstr("Dragging Mode"), &dragmode, mlstr.(dragmodes))
        @c CImGui.SliderInt(mlstr("Display Columns"), &showcols, 1, 12, "%d")
        if all(!qtw.selected for qtw in insw.qtws)
            insw.posoffset == [0, 0] || (insw.posoffset .= [0, 0])
            insw.sizeoffset == [0, 0] || (insw.sizeoffset .= [0, 0])
        else
            CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##emptygroup"), (-1, 0)) && emptygroup!(insw)
            CImGui.DragFloat2(
                mlstr("Position Offset"), insw.posoffset, 1, -6000, 6000, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
            ) && updategrouppos!(insw)
            CImGui.DragFloat2(
                mlstr("Size Offset"), insw.sizeoffset, 1, -6000, 6000, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
            ) && updategroupsize!(insw)
            itemw = CImGui.CalcItemWidth()
            itemh = 2CImGui.GetFrameHeight()
            CImGui.DragFloat2(mlstr("Spacing"), spacing, 1, 0, 600, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
            CImGui.Button(mlstr("Horizontal"), (itemw / 2, Cfloat(0))) && autospacing!(insw, selectedqtw, spacing[1], Val(:horizontal))
            CImGui.SameLine()
            CImGui.Button(mlstr("Vertical"), (itemw / 2, Cfloat(0))) && autospacing!(insw, selectedqtw, spacing[2], Val(:vertical))
            CImGui.PopStyleVar()
            CImGui.SameLine()
            CImGui.Text(mlstr("Auto Spacing"))
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
            CImGui.Button(mlstr("Left"), (itemw / 4, itemh)) && alignwidgets!(insw, selectedqtw, Val(:left))
            CImGui.SameLine()
            CImGui.BeginGroup()
            CImGui.Button(mlstr("Top"), (itemw / 2, Cfloat(0))) && alignwidgets!(insw, selectedqtw, Val(:up))
            CImGui.Button(mlstr("Bottom"), (itemw / 2, Cfloat(0))) && alignwidgets!(insw, selectedqtw, Val(:down))
            CImGui.EndGroup()
            CImGui.SameLine()
            CImGui.Button(mlstr("Right"), (itemw / 4, itemh)) && alignwidgets!(insw, selectedqtw, Val(:right))
            CImGui.PopStyleVar()
            CImGui.SameLine()
            CImGui.Text(mlstr("Auto Align"))
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
        ispushstylecol = selectedqtw == id || qtw.selected
        ispushstylecol && CImGui.PushStyleColor(
            CImGui.ImGuiCol_Button,
            if selectedqtw == id && !qtw.selected
                MORESTYLE.Colors.SelectedWidgetBt
            elseif selectedqtw != id && qtw.selected
                MORESTYLE.Colors.WidgetRectSelected
            else
                (MORESTYLE.Colors.SelectedWidgetBt .+ MORESTYLE.Colors.WidgetRectSelected) ./ 2
            end
        )
        if CImGui.Button(label, size)
            if unsafe_load(CImGui.GetIO().KeyCtrl)
                qtw.selected ⊻= true
                qtw.selected && addtogroup!(qtw)
            elseif unsafe_load(CImGui.GetIO().KeyShift)
                if selectedqtw == 0
                    selectedqtw = id
                elseif selectedqtw == id
                    addtogroup!(qtw)
                elseif selectedqtw < id
                    for i in selectedqtw:id
                        addtogroup!(insw.qtws[i])
                    end
                else
                    for i in id:selectedqtw
                        addtogroup!(insw.qtws[i])
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
                CImGui.GetWindowDrawList(), GLOBALFONT, ftsz, (posmax.x - ftsz, posmin.y),
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
                MORESTYLE.Icons.HoldPin
            )
        end
        if qtw.options.autorefresh
            posmin = CImGui.GetItemRectMin()
            ftsz = CImGui.GetFontSize()
            CImGui.AddText(
                CImGui.GetWindowDrawList(), GLOBALFONT, ftsz, posmin,
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
                MORESTYLE.Icons.InstrumentsAutoRef
            )
        end
    end
end

function addtogroup!(qtw::QuantityWidget)
    qtw.selected = true
    qtw.posbuf = copy(qtw.options.vertices[1])
    qtw.sizebuf = copy(qtw.options.itemsize)
end

function emptygroup!(insw::InstrWidget)
    for qtw in insw.qtws
        qtw.selected = false
    end
end

function updategrouppos!(insw::InstrWidget)
    for qtw in filter(x -> x.selected, insw.qtws)
        qtw.options.vertices[1] .= qtw.posbuf .+ insw.posoffset
    end
end

function updategroupsize!(insw::InstrWidget)
    for qtw in filter(x -> x.selected, insw.qtws)
        qtw.options.itemsize .= qtw.sizebuf .+ insw.sizeoffset
    end
end

function alignwidgets!(insw::InstrWidget, selectedqtw, ::Val{:left})
    qtws = filter(x -> x.selected, insw.qtws)
    poses = [qtw.posbuf for qtw in qtws]
    hasbase = selectedqtw != 0 && insw.qtws[selectedqtw].selected
    minx = hasbase ? insw.qtws[selectedqtw].posbuf[1] : min([pos[1] for pos in poses]...)
    for pos in poses
        pos[1] = minx
    end
    updategrouppos!(insw)
end

function alignwidgets!(insw::InstrWidget, selectedqtw, ::Val{:right})
    qtws = filter(x -> x.selected, insw.qtws)
    poses = [qtw.posbuf for qtw in qtws]
    sizes = [qtw.sizebuf for qtw in qtws]
    hasbase = selectedqtw != 0 && insw.qtws[selectedqtw].selected
    maxx = if hasbase
        qtw = insw.qtws[selectedqtw]
        qtw.posbuf[1] + qtw.sizebuf[1]
    else
        max([pos[1] + sizes[i][1] for (i, pos) in enumerate(poses)]...)
    end
    for (i, pos) in enumerate(poses)
        pos[1] = maxx - sizes[i][1]
    end
    updategrouppos!(insw)
end

function alignwidgets!(insw::InstrWidget, selectedqtw, ::Val{:up})
    qtws = filter(x -> x.selected, insw.qtws)
    poses = [qtw.posbuf for qtw in qtws]
    hasbase = selectedqtw != 0 && insw.qtws[selectedqtw].selected
    miny = hasbase ? insw.qtws[selectedqtw].posbuf[2] : min([pos[2] for pos in poses]...)
    for pos in poses
        pos[2] = miny
    end
    updategrouppos!(insw)
end

function alignwidgets!(insw::InstrWidget, selectedqtw, ::Val{:down})
    qtws = filter(x -> x.selected, insw.qtws)
    poses = [qtw.posbuf for qtw in qtws]
    sizes = [qtw.sizebuf for qtw in qtws]
    hasbase = selectedqtw != 0 && insw.qtws[selectedqtw].selected
    maxy = if hasbase
        qtw = insw.qtws[selectedqtw]
        qtw.posbuf[2] + qtw.sizebuf[2]
    else
        max([pos[2] + sizes[i][2] for (i, pos) in enumerate(poses)]...)
    end
    for (i, pos) in enumerate(poses)
        pos[2] = maxy - sizes[i][2]
    end
    updategrouppos!(insw)
end

function autospacing!(insw::InstrWidget, selectedqtw, spacing, ::Val{:horizontal})
    hasbase = selectedqtw != 0 && insw.qtws[selectedqtw].selected
    hasbase && (basepos = copy(insw.qtws[selectedqtw].posbuf))
    qtws = filter(x -> x.selected, insw.qtws)
    poses = [qtw.posbuf for qtw in qtws]
    sizes = [qtw.sizebuf for qtw in qtws]
    sp = sortperm([pos[1] for pos in poses])
    sortedposes = poses[sp]
    sortedsizes = sizes[sp]
    for i in eachindex(sortedposes)[2:end]
        sortedposes[i][1] = sortedposes[i-1][1] + sortedsizes[i-1][1] + spacing
    end
    if hasbase
        δpos = insw.qtws[selectedqtw].posbuf .- basepos
        for pos in poses
            pos .-= δpos
        end
    end
    updategrouppos!(insw)
end

function autospacing!(insw::InstrWidget, selectedqtw, spacing, ::Val{:vertical})
    hasbase = selectedqtw != 0 && insw.qtws[selectedqtw].selected
    hasbase && (basepos = copy(insw.qtws[selectedqtw].posbuf))
    qtws = filter(x -> x.selected, insw.qtws)
    poses = [qtw.posbuf for qtw in qtws]
    sizes = [qtw.sizebuf for qtw in qtws]
    sp = sortperm([pos[2] for pos in poses])
    sortedposes = poses[sp]
    sortedsizes = sizes[sp]
    for i in eachindex(sortedposes)[2:end]
        sortedposes[i][2] = sortedposes[i-1][2] + sortedsizes[i-1][2] + spacing
    end
    if hasbase
        δpos = insw.qtws[selectedqtw].posbuf .- basepos
        for pos in poses
            pos .-= δpos
        end
    end
    updategrouppos!(insw)
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
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias, qtype="sweep", numread=qt.numread)
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
                        newqtw = QuantityWidget(
                            name=qtnm, alias=qt.alias, qtype="set", numoptvs=length(qt.optvalues), numread=qt.numread
                        )
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
                        newqtw = QuantityWidget(name=qtnm, alias=qt.alias, qtype="read", numread=qt.numread)
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
                            numoptvs=length(qt.optvalues),
                            numread=qt.numread,
                            options=insw.qtws[i].options
                        )
                        insw.qtws[i].options.selectedidx = 1
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
                            numread=qt.numread,
                            options=insw.qtws[i].options
                        )
                        insw.qtws[i].options.selectedidx = 1
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
                            numoptvs=length(qt.optvalues),
                            numread=qt.numread,
                            options=insw.qtws[i].options
                        )
                        insw.qtws[i].options.selectedidx = 1
                    end
                end
            end
            CImGui.EndMenu()
        end
        CImGui.EndMenu()
    end
end

let
    sweepuitypes = ["read", "unit", "readunit", "inputstep", "inputstop", "dragdelay", "progressbar", "ctrlsweep"]
    setuitypesall = ["read", "unit", "readunit", "inputset", "inputctrlset", "ctrlset", "combo", "radio", "slider", "vslider", "toggle"]
    setuitypesnoopts = ["read", "unit", "readunit", "inputset", "ctrlset", "inputctrlset", "readinputctrlset"]
    setuitypesno2opts = ["read", "unit", "readunit", "inputset", "inputctrlset", "ctrlset", "combo", "radio", "slider", "vslider"]
    # readnumuitypes = ["read", "unit", "readunit", "readdashboard"]
    readuitypes = ["read", "unit", "readunit", "readdashboard", "readdashboarddigits", "readdashboarddigitsunit"]
    otheruitypes = ["none"]
    shapetypes = ["rect", "triangle", "circle", "line"]
    qtselectoruitypes = ["combo", "slider", "vslider"]
    qtypes = ["sweep", "set", "read"]
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
            @c ComboS(
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
            @c CImGui.Checkbox(mlstr("Global Options"), &qtw.options.globaloptions)
            @c CImGui.Checkbox(mlstr("Allow Overlap"), &qtw.options.allowoverlap)
            if qtw.qtype in qtypes
                if qtw.options.autorefresh
                    CImGui.PushItemWidth(6CImGui.GetFontSize())
                    @c CImGui.DragFloat(
                        "##refreshrate", &qtw.options.refreshrate, 0.1, 0.1, 360, "%.1f",
                        CImGui.ImGuiSliderFlags_AlwaysClamp
                    )
                    CImGui.PopItemWidth()
                    CImGui.SameLine()
                end
                @c CImGui.Checkbox(stcstr(mlstr("Auto Refresh"), qtw.options.autorefresh ? " (s)" : ""), &qtw.options.autorefresh)
            end
            if qtw.name == "_Panel_"
                @c CImGui.Checkbox(mlstr("Use Image"), &qtw.options.useimage)
                @c InputTextRSZ("##Text", &qtw.alias)
                CImGui.SameLine()
                iconstr = MORESTYLE.Icons.CopyIcon
                @c(IconSelector(mlstr("Text"), &iconstr)) && (qtw.alias *= iconstr)
            end
            if qtw.options.uitype in ["ctrlsweep", "ctrlset", "inputctrlset", "readinputctrlset"]
                @c InputTextRSZ("##Start", &qtw.options.starttext)
                CImGui.SameLine()
                iconstr = MORESTYLE.Icons.CopyIcon
                if @c IconSelector(mlstr(qtw.options.uitype == "ctrlsweep" ? "Start" : "Set"), &iconstr)
                    qtw.options.starttext *= iconstr
                end
            end
            if qtw.options.uitype == "ctrlsweep"
                @c InputTextRSZ("##Stop", &qtw.options.stoptext)
                CImGui.SameLine()
                iconstr = MORESTYLE.Icons.CopyIcon
                @c(IconSelector(mlstr("Stop"), &iconstr)) && (qtw.options.stoptext *= iconstr)
            end
            @c ComboS(mlstr("Text Size"), &qtw.options.textsize, textsizes)
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
            if qtw.options.uitype == "progressbar"
                @c CImGui.Checkbox(mlstr("No Times"), &qtw.options.notimes)
                @c CImGui.Checkbox(mlstr("No Time"), &qtw.options.notime)
            end
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
            imgpath = qtw.options.pathes[1]
            inputimgpath = @c InputTextRSZ("##ImagePath", &imgpath)
            CImGui.SameLine()
            selectimgpath = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##ImagePath"))
            selectimgpath && (imgpath = pick_file(abspath(imgpath); filterlist="png,jpg,jpeg,tif,bmp;gif"))
            CImGui.SameLine()
            CImGui.Text(mlstr("Path"))
            if inputimgpath || selectimgpath
                if isfile(imgpath)
                    qtw.options.pathes[1] = imgpath
                else
                    CImGui.SameLine()
                    CImGui.TextColored(MORESTYLE.Colors.LogError, mlstr("path does not exist!!!"))
                end
            end
            @c CImGui.DragInt(mlstr("Rate"), &qtw.options.rate, 1, 1, 120, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
            @c CImGui.DragFloat2(
                mlstr("Frame Padding"),
                qtw.options.framepadding, 1, 0, min(qtw.options.itemsize...) / 2, "%.1f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            CImGui.DragFloat2(mlstr("uv0"), qtw.options.uv0)
            CImGui.DragFloat2(mlstr("uv1"), qtw.options.uv1)
        end
        if qtw.qtype == "set" && qtw.options.uitype != "read" && CImGui.CollapsingHeader(mlstr("Binding Options"))
            @c CImGui.SliderInt(mlstr("Binding Index to RadioButton"), &qtw.options.bindingidx, 1, qtw.numoptvs)
            CImGui.SliderInt2(mlstr("Binding Index to ON/OFF"), qtw.options.bindingonoff, 1, qtw.numoptvs)
        end
        if qtw.options.uitype == "read" && CImGui.CollapsingHeader(mlstr("Binding Options"))
            @c CImGui.SliderInt(mlstr("Reading Index"), &qtw.options.bindingidx, 1, qtw.numread)
        end
        if qtw.name == "_QuantitySelector_" && CImGui.CollapsingHeader(mlstr("Selector Options"))
            # @c ComboS(mlstr("Selector Type"), &qtw.options.selectortype, selectortypes)
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
            width = CImGui.GetContentRegionAvail().x / 3
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
    if qtw.options.uitype == "readdashboard"
        CImGui.ColorEdit4(
            mlstr("Base"),
            qtw.options.grabcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype in ["slider", "vslider"]
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
    if qtw.options.uitype == "readdashboard"
        CImGui.ColorEdit4(
            mlstr("Indicator"),
            qtw.options.checkedcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    if qtw.options.uitype == "radio"
        CImGui.ColorEdit4(
            mlstr("Checked"),
            qtw.options.checkedcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
end

function globalwidgetoptionsmenu(insw::InstrWidget)
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Global Options"))
    CImGui.BeginChild("global widget options")
    @c InputTextRSZ(mlstr("Widget Name"), &insw.name)
    @c CImGui.CheckboxFlags(mlstr("No Titlebar"), &insw.windowflags, CImGui.ImGuiWindowFlags_NoTitleBar)
    @c CImGui.CheckboxFlags(mlstr("No Resizing"), &insw.windowflags, CImGui.ImGuiWindowFlags_NoResize)
    @c CImGui.CheckboxFlags(mlstr("No Collapsing"), &insw.windowflags, CImGui.ImGuiWindowFlags_NoCollapse)
    @c CImGui.CheckboxFlags(mlstr("No Docking"), &insw.windowflags, CImGui.ImGuiWindowFlags_NoDocking)
    @c CImGui.Checkbox(mlstr("Global Options"), &insw.globaloptions)
    CImGui.DragFloat2(
        mlstr("Window Size"),
        insw.windowsize, 1, 6, 6000, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
    )
    @c CImGui.Checkbox(mlstr("Use Wallpaper"), &insw.usewallpaper)
    if insw.usewallpaper
        bgpath = insw.wallpaperpath
        inputbgpath = @c InputTextRSZ("##wallpaper", &bgpath)
        CImGui.SameLine()
        selectbgpath = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##wallpaper"))
        selectbgpath && (bgpath = pick_file(abspath(bgpath); filterlist="png,jpg,jpeg,tif,bmp;gif"))
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
        @c CImGui.DragInt(mlstr("Rate"), &insw.rate, 1, 1, 120, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.ColorEdit4(
            stcstr(mlstr("Background Tint")),
            insw.bgtintcolor,
            CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
        )
    end
    CImGui.ColorEdit4(
        mlstr("Window"),
        insw.windowbgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Title"),
        insw.titlebgcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Active Title"),
        insw.titlebgactivecolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.ColorEdit4(
        mlstr("Collapsed Title"),
        insw.titlebgcollapsedcolor,
        CImGui.ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_AlphaPreviewHalf
    )
    CImGui.EndChild()
    # end
end

function initialize!(insw::InstrWidget, addr)
    _, autoreflist = refreshqtlist!(insw)
    if haskey(INSTRBUFFERVIEWERS, insw.instrnm) && haskey(INSTRBUFFERVIEWERS[insw.instrnm], addr) && !isempty(autoreflist)
        SYNCSTATES[Int(IsAutoRefreshing)] = true
        INSTRBUFFERVIEWERS[insw.instrnm][addr].insbuf.isautorefresh = true
        qts = INSTRBUFFERVIEWERS[insw.instrnm][addr].insbuf.quantities
        for (qtnm, qt) in filter(x -> x.first in keys(autoreflist), qts)
            qt.isautorefresh = true
            qt.refreshrate = autoreflist[qtnm]
        end
    end
    Threads.@spawn @trycatch mlstr("task failed!!!") refresh1(insw, addr)
end

function exit!(insw::InstrWidget, addr)
    autoreflist = []
    for qtw in insw.qtws
        qtw.qtype in ["sweep", "set", "read"] && qtw.options.autorefresh && push!(autoreflist, qtw.name)
    end
    if haskey(INSTRBUFFERVIEWERS, insw.instrnm) && haskey(INSTRBUFFERVIEWERS[insw.instrnm], addr) && !isempty(autoreflist)
        for (_, qt) in filter(x -> x.first in autoreflist, INSTRBUFFERVIEWERS[insw.instrnm][addr].insbuf.quantities)
            qt.isautorefresh = false
        end
    end
end

function refreshqtlist!(insw::InstrWidget)
    empty!(insw.qtlist)
    qtlist = []
    autoreflist = Dict()
    for qtw in insw.qtws
        if qtw.qtype in ["sweep", "set", "read"]
            push!(qtlist, qtw.name)
            qtw.options.autorefresh && (autoreflist[qtw.name] = qtw.options.refreshrate)
        end
    end
    append!(insw.qtlist, Set(qtlist))
    return qtlist, autoreflist
end

function refresh1(insw::InstrWidget, addr; blacklist=[])
    lock(REFRESHLOCK) do
        if haskey(INSTRBUFFERVIEWERS, insw.instrnm) && haskey(INSTRBUFFERVIEWERS[insw.instrnm], addr)
            fetchibvs = wait_remotecall_fetch(
                workers()[1], INSTRBUFFERVIEWERS, insw.instrnm, addr, insw.qtlist, blacklist; timeout=120
            ) do ibvs, ins, addr, qtlist, blacklist
                merge!(INSTRBUFFERVIEWERS, ibvs)
                ct = Controller(ins, addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
                try
                    login!(CPU, ct; attr=getattr(addr))
                    for (qtnm, qt) in filter(
                        x -> x.first in qtlist && x.first ∉ blacklist,
                        INSTRBUFFERVIEWERS[ins][addr].insbuf.quantities
                    )
                        getfunc = Symbol(ins, :_, qtnm, :_get) |> eval
                        qt.read = ct(getfunc, CPU, Val(:read))
                    end
                catch e
                    @error(
                        "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                        instrument = string(ins, ": ", addr),
                        exception = e
                    )
                    showbacktrace()
                finally
                    logout!(CPU, ct)
                end
                return INSTRBUFFERVIEWERS
            end
            if !isnothing(fetchibvs)
                for (qtnm, qt) in filter(
                    x -> x.first in insw.qtlist,
                    INSTRBUFFERVIEWERS[insw.instrnm][addr].insbuf.quantities
                )
                    qt.read = fetchibvs[insw.instrnm][addr].insbuf.quantities[qtnm].read
                    updatefront!(qt)
                end
            end
        end
    end
end

let
    noopts = ["read", "unit", "readunit", "inputset", "ctrlset", "inputctrlset", "readinputctrlset"]
    global function trigselector!(qtw::QuantityWidget, insw::InstrWidget)
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
end