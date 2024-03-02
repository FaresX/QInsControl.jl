@kwdef mutable struct Annotation
    label::String = "Ann"
    posx::Cdouble = 0
    posy::Cdouble = 0
    offsetx::Cdouble = 0
    offsety::Cdouble = 0
    color::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    possz::Cfloat = 4
end

@kwdef mutable struct Linecut
    ptype::String = "line"
    vline::Bool = true
    thickness::Cfloat = 0
    color::CImGui.ImVec4 = (1.000, 1.000, 1.000, 1.000)
    pos::Cdouble = 0
end

@kwdef mutable struct Xaxis
    axis::ImPlot.ImAxis = ImPlot.ImAxis_X1
    label::String = "x1"
    tickvalues::Vector{Cdouble} = []
    ticklabels::Vector{String} = []
    lims::Tuple{Cdouble,Cdouble} = (0, 1)
    scale::ImPlot.ImPlotScale = 0
    hovered::Bool = false
end

@kwdef mutable struct Yaxis
    axis::ImPlot.ImAxis = ImPlot.ImAxis_Y1
    label::String = "y1"
    tickvalues::Vector{Cdouble} = []
    ticklabels::Vector{String} = []
    lims::Tuple{Cdouble,Cdouble} = (0, 1)
    scale::ImPlot.ImPlotScale = 0
    hovered::Bool = false
end

@kwdef mutable struct Zaxis
    axis::UInt32 = 1
    label::String = "z1"
    colormap::ImPlot.ImPlotColormap = ImPlot.ImPlotColormap_Viridis
    tickvalues::Vector{Cdouble} = []
    ticklabels::Vector{String} = []
    lims::Tuple{Cdouble,Cdouble} = (0, 1)
    scale::UInt32 = 0
    hovered::Bool = false
    colormapscalesize::CImGui.ImVec2 = (0, 0)
end

@kwdef mutable struct Axis
    xaxis::Xaxis = Xaxis()
    yaxis::Yaxis = Yaxis()
    zaxis::Zaxis = Zaxis()
end

@kwdef mutable struct PlotSeries{Tx<:Real,Ty<:Real,Tz<:Real}
    ptype::String = "line"
    legend::String = "s1"
    x::Vector{Tx} = Cdouble[]
    y::Vector{Ty} = Cdouble[]
    z::Matrix{Tz} = Matrix{Cdouble}(undef, 0, 0)
    axis::Axis = Axis()
    legendhovered::Bool = false
end

@kwdef mutable struct Plot
    id::String = ""
    title::String = ""
    series::Vector{PlotSeries} = PlotSeries[]
    anns::Vector{Annotation} = Annotation[]
    linecuts::Vector{Linecut} = Linecut[]
    xaxes::Vector{Xaxis} = []
    yaxes::Vector{Yaxis} = []
    zaxes::Vector{Zaxis} = []
    hovered::Bool = false
    showtooltip::Bool = true
    mspos::ImPlot.ImPlotPoint = ImPlot.ImPlotPoint(0, 0)
    plotpos::CImGui.ImVec2 = (0, 0)
    plotsize::CImGui.ImVec2 = (0, 0)
end

let
    annbuf::Annotation = Annotation()
    openpopup_mspos_list::Dict{String,Vector{Cfloat}} = Dict()
    global function Plot(plt::Plot, id; psize=CImGui.ImVec2(0, -1), flags=0)
        plt.id = id
        CImGui.PushID(id)
        CImGui.BeginChild("Plot", psize)
        mousedoubleclicked0 = CImGui.IsMouseDoubleClicked(0)
        CImGui.PushFont(PLOTFONT)
        Plot(plt; psize=CImGui.ImVec2(-1, -1), flags=flags)
        CImGui.PopFont()
        plt.hovered && CImGui.IsMouseClicked(2) && CImGui.OpenPopup(stcstr("title", id))
        haskey(openpopup_mspos_list, id) || push!(openpopup_mspos_list, id => Cfloat[0, 0])
        openpopup_mspos = openpopup_mspos_list[id]
        if CImGui.BeginPopup(stcstr("title", id))
            if openpopup_mspos == Cfloat[0, 0]
                openpopup_mspos .= plt.mspos.x, plt.mspos.y
                annbuf.posx, annbuf.posy = openpopup_mspos
                annbuf.offsetx, annbuf.offsety = openpopup_mspos
            end
            @c InputTextRSZ(mlstr("title"), &plt.title)
            @c CImGui.Checkbox(mlstr("data tip"), &plt.showtooltip)
            if CImGui.BeginMenu(mlstr("Add Linecut"))
                CImGui.MenuItem(mlstr("Horizontal Linecut")) && push!(plt.linecuts, Linecut(vline=false, pos=openpopup_mspos[2]))
                CImGui.MenuItem(mlstr("Vertical Linecut")) && push!(plt.linecuts, Linecut(pos=openpopup_mspos[1]))
                CImGui.EndMenu()
            end
            if CImGui.CollapsingHeader(mlstr("Annotation"))
                @c InputTextRSZ(mlstr("content"), &annbuf.label)
                pos = Cfloat[annbuf.posx, annbuf.posy]
                CImGui.InputFloat2(mlstr("position"), pos)
                annbuf.posx, annbuf.posy = pos
                offset = Cfloat[annbuf.offsetx, annbuf.offsety]
                CImGui.InputFloat2(mlstr("offset"), offset)
                annbuf.offsetx, annbuf.offsety = offset
                @c CImGui.DragFloat(mlstr("size"), &annbuf.possz, 1.0, 1, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.ColorEdit4(mlstr("color"), annbuf.color, CImGui.ImGuiColorEditFlags_AlphaBar)
                CImGui.SameLine()
                if CImGui.Button(MORESTYLE.Icons.NewFile * "##annotation")
                    push!(plt.anns, deepcopy(annbuf))
                end
            end
            CImGui.EndPopup()
        end
        igIsPopupOpen_Str(stcstr("title", id), 0) || openpopup_mspos == Cfloat[0, 0] || fill!(openpopup_mspos, 0)
        for (i, pltxa) in enumerate(plt.xaxes)
            pltxa.hovered && mousedoubleclicked0 && CImGui.OpenPopup(stcstr("xlabel", i, "-", id))
            if CImGui.BeginPopup(stcstr("xlabel", i, "-", id))
                if @c InputTextRSZ(stcstr("X ", mlstr("label")), &pltxa.label)
                    for pss in plt.series
                        pss.axis.xaxis.axis == pltxa.axis && (pss.axis.xaxis.label = pltxa.label)
                    end
                end
                scale = string(ImPlot.ImPlotScale_(pltxa.scale))
                if @c ComBoS(mlstr("Axis Scale"), &scale, string.(instances(ImPlot.ImPlotScale_)))
                    pltxa.scale = getproperty(ImPlot, Symbol(scale))
                    for pss in plt.series
                        pss.axis.xaxis.axis == pltxa.axis && (pss.axis.xaxis.scale = pltxa.scale)
                    end
                end
                CImGui.EndPopup()
            end
        end
        for (i, pltya) in enumerate(plt.yaxes)
            pltya.hovered && mousedoubleclicked0 && CImGui.OpenPopup(stcstr("ylabel", i, "-", id))
            if CImGui.BeginPopup(stcstr("ylabel", i, "-", id))
                if @c InputTextRSZ(stcstr("Y ", mlstr("label")), &pltya.label)
                    for pss in plt.series
                        pss.axis.yaxis.axis == pltya.axis && (pss.axis.yaxis.label = pltya.label)
                    end
                end
                scale = string(ImPlot.ImPlotScale_(pltya.scale))
                if @c ComBoS(mlstr("Axis Scale"), &scale, string.(instances(ImPlot.ImPlotScale_)))
                    pltya.scale = getproperty(ImPlot, Symbol(scale))
                    for pss in plt.series
                        pss.axis.yaxis.axis == pltya.axis && (pss.axis.yaxis.scale = pltya.scale)
                    end
                end
                CImGui.EndPopup()
            end
        end
        for (i, pltza) in enumerate(plt.zaxes)
            pltza.hovered && mousedoubleclicked0 && CImGui.OpenPopup(stcstr("zlabel", i, "-", id))
            if CImGui.BeginPopup(stcstr("zlabel", i, "-", id))
                if @c InputTextRSZ(stcstr("Z ", mlstr("label")), &pltza.label)
                    for pss in plt.series
                        pss.axis.zaxis.axis == pltza.axis && (pss.axis.zaxis.label = pltza.label)
                    end
                end
                cmap = unsafe_string(ImPlot.GetColormapName(pltza.colormap))
                if @c ComBoS(mlstr("Colormap"), &cmap, unsafe_string.(ImPlot.GetColormapName.(0:ImPlot.GetColormapCount()-1)))
                    pltza.colormap = ImPlot.GetColormapIndex(cmap)
                    for pss in plt.series
                        pss.axis.zaxis.axis == pltza.axis && (pss.axis.zaxis.colormap = pltza.colormap)
                    end
                end
                if ImPlot.ColormapButton(
                    stcstr(unsafe_string(ImPlot.GetColormapName(pltza.colormap)), "##", pltza.axis),
                    ImVec2(Cfloat(-0.1), Cfloat(0)),
                    pltza.colormap
                )
                    pltza.colormap = (pltza.colormap + 1) % ImPlot.GetColormapCount()
                    for pss in plt.series
                        pss.axis.zaxis.axis == pltza.axis && (pss.axis.zaxis.colormap = pltza.colormap)
                    end
                end
                CImGui.EndPopup()
            end
        end
        CImGui.EndChild()
        CImGui.PopID()
    end
end

function mergexaxes!(plt::Plot)
    empty!(plt.xaxes)
    for x in [pss.axis.xaxis for pss in plt.series]
        x.axis in [xa.axis for xa in plt.xaxes] || push!(plt.xaxes, deepcopy(x))
    end
    for pltxa in plt.xaxes
        for axis in [pss.axis for pss in plt.series]
            axis.xaxis.axis == pltxa.axis && (axis.xaxis = deepcopy(pltxa))
        end
    end
end

function mergeyaxes!(plt::Plot)
    empty!(plt.yaxes)
    for y in [pss.axis.yaxis for pss in plt.series]
        y.axis in [ya.axis for ya in plt.yaxes] || push!(plt.yaxes, deepcopy(y))
    end
    for pltya in plt.yaxes
        for axis in [pss.axis for pss in plt.series]
            axis.yaxis.axis == pltya.axis && (axis.yaxis = deepcopy(pltya))
        end
    end
end

function mergezaxes!(plt::Plot)
    empty!(plt.zaxes)
    for pss in plt.series
        zlims = isempty(pss.z) ? (0, 1) : extrema(pss.z)
        zlims[1] == zlims[2] && (zlims = (0, 1))
        pss.axis.zaxis.lims = zlims
    end
    for z in [pss.axis.zaxis for pss in plt.series if pss.ptype == "heatmap"]
        z.axis in [za.axis for za in plt.zaxes] || push!(plt.zaxes, deepcopy(z))
    end
    for pltza in plt.zaxes
        sameaxis = [pss.axis for pss in plt.series if pss.axis.zaxis.axis == pltza.axis]
        pltza.lims = extrema(vcat([collect(axis.zaxis.lims) for axis in sameaxis]...))
        for axis in sameaxis
            axis.zaxis = deepcopy(pltza)
        end
    end
end

function Plot(plt::Plot; psize=CImGui.ImVec2(0, 0), flags=0)
    if ImPlot.BeginPlot(
        stcstr(plt.title, "###", plt.id),
        CImGui.ImVec2((psize.x > 0 ? psize.x : CImGui.GetContentRegionAvailWidth()) - sum(za.colormapscalesize.x for za in plt.zaxes; init=0), psize.y),
        flags
    )
        isempty(plt.xaxes) && mergexaxes!(plt)
        isempty(plt.yaxes) && mergeyaxes!(plt)
        map(xa -> ImPlot.SetupAxis(xa.axis, xa.label), plt.xaxes)
        map(ya -> ImPlot.SetupAxis(ya.axis, ya.label), plt.yaxes)
        map(xa -> ImPlot.SetupAxisScale(xa.axis, xa.scale), plt.xaxes)
        map(ya -> ImPlot.SetupAxisScale(ya.axis, ya.scale), plt.yaxes)
        map(xa -> xa.hovered = ImPlot.IsAxisHovered(xa.axis), plt.xaxes)
        map(ya -> ya.hovered = ImPlot.IsAxisHovered(ya.axis), plt.yaxes)
        hasheatmap = false
        for (i, pss) in enumerate(plt.series)
            if pss.ptype == "heatmap"
                hasheatmap = true
                (isempty(pss.x) | isempty(pss.y) | isempty(pss.z)) && continue
            else
                (isempty(pss.x) | isempty(pss.y)) && continue
            end
            Plot(pss, plt)
            if ImPlot.BeginLegendPopup(stcstr("legend", i))
                @c InputTextRSZ(mlstr("legend"), &pss.legend)
                ImPlot.EndLegendPopup()
            end
        end
        PlotAnns(plt.anns)
        hasheatmap && PlotLinecuts(plt.linecuts)
        plt.hovered = ImPlot.IsPlotHovered()
        ImPlot.EndPlot()
    end
    plt.plotpos = CImGui.GetItemRectMin()
    plt.plotsize = CImGui.GetItemRectSize()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
    for za in plt.zaxes
        CImGui.SameLine()
        za.colormap + 1 > ImPlot.GetColormapCount() && (za.colormap %= ImPlot.GetColormapCount())
        ImPlot.PushColormap(za.colormap)
        ImPlot.ColormapScale(stcstr(za.label, "###", plt.id, "-", za.axis), za.lims..., CImGui.ImVec2(Cfloat(0), psize.y))
        ImPlot.PopColormap()
        za.colormapscalesize = CImGui.GetItemRectSize()
        za.hovered = CImGui.IsItemHovered()
    end
    CImGui.PopStyleVar()
    renderlinecuts(plt)
end

Plot(pss::PlotSeries, plt::Plot) = Plot(pss, plt, Val(Symbol(pss.ptype)))

function Plot2D(plotfunc, pss::PlotSeries, plt::Plot)
    ImPlot.SetAxes(pss.axis.xaxis.axis, pss.axis.yaxis.axis)
    ImPlot.SetupAxisTicks(pss.axis.xaxis.axis, pss.axis.xaxis.tickvalues, length(pss.axis.xaxis.tickvalues), pss.axis.xaxis.ticklabels)
    plotfunc(pss.legend, pss.x, pss.y, length(pss.x))
    pss.legendhovered = ImPlot.IsLegendEntryHovered(pss.legend)
    xl, xr = extrema(pss.x)
    plt.mspos = ImPlot.GetPlotMousePos()
    if plt.showtooltip && plt.hovered && xl <= plt.mspos.x <= xr
        minx = pss.x[argmin(abs.(pss.x .- plt.mspos.x))]
        idxes = findall(≈(minx), pss.x)
        mspospixel = CImGui.GetMousePos()
        d2s = [sum(abs2.(mspospixel .- ImPlot.PlotToPixels(pss.x[idx], pss.y[idx]))) for idx in idxes]
        if !isempty(d2s)
            mind2 = findmin(d2s)
            idx = idxes[mind2[2]]
            if mind2[1] < abs2(unsafe_load(IMPLOTSTYLE.MarkerSize))
                CImGui.BeginTooltip()
                SeparatorTextColored(MORESTYLE.Colors.HighlightText, pss.legend)
                CImGui.PushTextWrapPos(36CImGui.GetFontSize())
                CImGui.Text(string("x : ", isempty(pss.axis.xaxis.ticklabels) ? pss.x[idx] : pss.axis.xaxis.ticklabels[idx]))
                CImGui.Text(string("y : ", pss.y[idx]))
                CImGui.PopTextWrapPos()
                CImGui.EndTooltip()
            end
        end
    end
end
Plot(pss::PlotSeries, plt::Plot, ::Val{:line}) = Plot2D(ImPlot.PlotLine, pss, plt)
Plot(pss::PlotSeries, plt::Plot, ::Val{:scatter}) = Plot2D(ImPlot.PlotScatter, pss, plt)
Plot(pss::PlotSeries, plt::Plot, ::Val{:stairs}) = Plot2D(ImPlot.PlotStairs, pss, plt)
Plot(pss::PlotSeries, plt::Plot, ::Val{:stems}) = Plot2D(ImPlot.PlotStems, pss, plt)

function Plot(pss::PlotSeries, plt::Plot, ::Val{:heatmap})
    pss.axis.zaxis.colormap + 1 > ImPlot.GetColormapCount() && (pss.axis.zaxis.colormap %= ImPlot.GetColormapCount())
    ImPlot.PushColormap(pss.axis.zaxis.colormap)
    ImPlot.PlotHeatmap(
        pss.legend, pss.z, reverse(size(pss.z))..., pss.axis.zaxis.lims..., "",
        ImPlot.ImPlotPoint(pss.axis.xaxis.lims[1], pss.axis.yaxis.lims[1]),
        ImPlot.ImPlotPoint(pss.axis.xaxis.lims[2], pss.axis.yaxis.lims[2])
    )
    ImPlot.PopColormap()
    pss.legendhovered = ImPlot.IsLegendEntryHovered(pss.legend)
    plt.mspos = ImPlot.GetPlotMousePos()
    if plt.showtooltip && plt.hovered && inregion(
           plt.mspos,
           (pss.axis.xaxis.lims[1], pss.axis.yaxis.lims[1]), (pss.axis.xaxis.lims[2], pss.axis.yaxis.lims[2])
       )
        zsz = size(pss.z)
        xr = range(pss.axis.xaxis.lims[1], pss.axis.xaxis.lims[2], length=zsz[1])
        yr = range(pss.axis.yaxis.lims[2], pss.axis.yaxis.lims[1], length=zsz[2])
        xidx = argmin(abs.(xr .- plt.mspos.x))
        yidx = argmin(abs.(yr .- plt.mspos.y))
        CImGui.BeginTooltip()
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, pss.legend)
        CImGui.PushTextWrapPos(36CImGui.GetFontSize())
        CImGui.Text(string("x : ", xr[xidx]))
        CImGui.Text(string("y : ", yr[yidx]))
        CImGui.Text(string("z : ", pss.z[xidx, yidx]))
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
end

function setupplotseries!(pss::PlotSeries, x::AbstractVector{Tx}, y) where {Tx<:AbstractString}
    pss.x = 1:length(y)
    pss.y = y
    lx, ly = length(x), length(y)
    pss.axis.xaxis.ticklabels = lx < ly ? append!(copy(x), fill("", ly - lx)) : x[1:ly]
end
function setupplotseries!(pss::PlotSeries, x::AbstractVector{Tx}, y) where {Tx<:Real}
    pss.x, pss.y = isempty(x) ? (1:length(y), y) : trunc(x, y)
end
function setupplotseries!(pss::PlotSeries, x::AbstractVector{Tx}, y, z) where {Tx<:Real}
    pss.z = z
    if isempty(pss.z)
        empty!(pss.x)
        empty!(pss.y)
        pss.axis.xaxis.lims = (0, 1)
        pss.axis.yaxis.lims = (0, 1)
        pss.axis.zaxis.lims = (0, 1)
    else
        zsz = size(pss.z)
        if isempty(x)
            pss.axis.xaxis.lims = (0, 1)
            pss.x = 1:zsz[1]
        else
            xlims = extrema(x)
            xlims[1] == xlims[2] && (xlims = (0, 1))
            pss.axis.xaxis.lims = xlims
            pss.x = length(x) == zsz[1] ? x : range(extrema(x)..., length=zsz[1])
        end
        if isempty(y)
            pss.axis.yaxis.lims = (0, 1)
            pss.y = 1:zsz[2]
        else
            ylims = extrema(y)
            ylims[1] == ylims[2] && (ylims = (0, 1))
            pss.axis.yaxis.lims = ylims
            pss.y = length(y) == zsz[2] ? y : range(extrema(y)..., length=zsz[2])
        end
    end
end

function PlotAnns(anns::Vector{Annotation})
    if !isempty(anns)
        openpopup_i = 0
        ishv = false
        ImPlot.SetAxes(ImPlot.ImAxis_X1, ImPlot.ImAxis_Y1)
        CImGui.PushFont(GLOBALFONT)
        for (i, ann) in enumerate(anns)
            offset = ImPlot.PlotToPixels(ann.offsetx, ann.offsety) .- ImPlot.PlotToPixels(ann.posx, ann.posy)
            halflabelsz = CImGui.CalcTextSize(ann.label) ./ 2
            ImPlot.AnnotationClamped(
                ann.posx,
                ann.posy,
                CImGui.ImVec4(ann.color...),
                correct_offset(offset, halflabelsz),
                ann.label
            )
            CImGui.PushID(i)
            @c ImPlot.DragPoint(i, &ann.posx, &ann.posy, CImGui.ImVec4(ann.color...), ann.possz)
            ishv = isdragpointhovered(ann.posx, ann.posy, ann.possz)
            @c ImPlot.DragPoint(
                -i,
                &ann.offsetx,
                &ann.offsety,
                CImGui.ImVec4(ann.color[1:3]..., 0.000),
                halflabelsz[2] / 2
            )
            ishv |= isdragpointhovered(ann.offsetx, ann.offsety, halflabelsz[2])
            ishv && (ItemTooltipNoHovered(ann.label); openpopup_i = i)
            CImGui.PopID()
            if CImGui.BeginPopup(stcstr("annotation", i))
                @c InputTextRSZ(mlstr("content"), &ann.label)
                pos = Cfloat[ann.posx, ann.posy]
                CImGui.InputFloat2(mlstr("position"), pos)
                ann.posx, ann.posy = pos
                offset = Cfloat[ann.offsetx, ann.offsety]
                CImGui.InputFloat2(mlstr("offset"), offset)
                ann.offsetx, ann.offsety = offset
                @c CImGui.DragFloat(mlstr("size"), &ann.possz, 1.0, 1, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.ColorEdit4(mlstr("color"), ann.color, CImGui.ImGuiColorEditFlags_AlphaBar)
                CImGui.SameLine()
                CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##annotation")) && (deleteat!(anns, i); break)
                CImGui.EndPopup()
            end
        end
        CImGui.PopFont()
        openpopup_i != 0 && CImGui.IsMouseClicked(1) && CImGui.OpenPopup(stcstr("annotation", openpopup_i))
    end
end

function isdragpointhovered(x, y, sz)
    ppos = ImPlot.PlotToPixels(x, y)
    inregion(CImGui.GetMousePos(), ppos .- sz / 2, ppos .+ sz / 2)
end

function correct_offset(offset, halflabelsz)
    if offset[1] > halflabelsz[1]
        if offset[2] > halflabelsz[2]
            offset_correct = offset - halflabelsz
        elseif -halflabelsz[2] <= offset[2] <= halflabelsz[2]
            offset_correct = CImGui.ImVec2(offset[1] - halflabelsz[1], Cfloat(0))
        else
            offset_correct = CImGui.ImVec2(offset[1] - halflabelsz[1], offset[2] + halflabelsz[2])
        end
    elseif -halflabelsz[1] <= offset[1] <= halflabelsz[1]
        if offset[2] > halflabelsz[2]
            offset_correct = CImGui.ImVec2(Cfloat(0), offset[2] - halflabelsz[2])
        elseif -halflabelsz[2] <= offset[2] <= halflabelsz[2]
            offset_correct = CImGui.ImVec2(Cfloat(0), Cfloat(0))
        else
            offset_correct = CImGui.ImVec2(Cfloat(0), offset[2] + halflabelsz[2])
        end
    else
        if offset[2] > halflabelsz[2]
            offset_correct = CImGui.ImVec2(offset[1] + halflabelsz[1], offset[2] - halflabelsz[2])
        elseif -halflabelsz[2] <= offset[2] <= halflabelsz[2]
            offset_correct = CImGui.ImVec2(offset[1] + halflabelsz[1], Cfloat(0))
        else
            offset_correct = offset + halflabelsz
        end
    end
    return ImVec2(offset_correct...)
end

function PlotLinecuts(linecuts::Vector{Linecut})
    if !isempty(linecuts)
        openpopup_i = 0
        ishv = false
        ImPlot.SetAxes(ImPlot.ImAxis_X1, ImPlot.ImAxis_Y1)
        CImGui.PushFont(GLOBALFONT)
        for (i, lc) in enumerate(linecuts)
            if lc.vline
                @c ImPlot.DragLineX(i, &lc.pos, CImGui.ImVec4(MORESTYLE.Colors.HighlightText...))
                ishv |= isdraglinexhovered(lc.pos)
            else
                @c ImPlot.DragLineY(i, &lc.pos, CImGui.ImVec4(MORESTYLE.Colors.HighlightText...))
                ishv |= isdraglineyhovered(lc.pos)
            end
            ishv && (openpopup_i = i)
            if CImGui.BeginPopup(stcstr("linecut", i))
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"), "##", i)) && (deleteat!(linecuts, i); break)
                CImGui.EndPopup()
            end
        end
        CImGui.PopFont()
        openpopup_i != 0 && CImGui.IsMouseClicked(1) && CImGui.OpenPopup(stcstr("linecut", openpopup_i))
    end
end

function isdraglinexhovered(x)
    !ImPlot.IsPlotHovered() && abs(ImPlot.PlotToPixels(x, ImPlot.GetPlotMousePos().y).x - CImGui.GetMousePos().x) < 4
end
function isdraglineyhovered(y)
    !ImPlot.IsPlotHovered() && abs(ImPlot.PlotToPixels(ImPlot.GetPlotMousePos().x, y).y - CImGui.GetMousePos().y) < 4
end

function renderlinecuts(plt::Plot)
    if !isempty(plt.linecuts)
        p_open = Ref(true)
        CImGui.SetNextWindowSize((600, 400), CImGui.ImGuiCond_Once)
        CImGui.PushFont(GLOBALFONT)
        openlinecuts = CImGui.Begin(
            stcstr(mlstr("Linecuts"), " ", plt.title, "###", plt.id),
            p_open,
            CImGui.ImGuiWindowFlags_NoDocking
        )
        CImGui.PopFont()
        if openlinecuts
            hms = length(Set([s.legend for s in plt.series if s.ptype == "heatmap"]))

            num_h = count(lc -> !lc.vline, plt.linecuts)
            num_v = length(plt.linecuts) - num_h
            w = CImGui.GetContentRegionAvailWidth() / (2 - (num_h == 0 || num_v == 0))
            h = (CImGui.GetContentRegionAvail().y - (hms - 1) * unsafe_load(IMGUISTYLE.ItemSpacing.y)) / hms
            if num_h != 0
                CImGui.BeginChild("hlinecuts", (w, Cfloat(0)))
                renderhlinecuts(plt, h)
                CImGui.EndChild()
                CImGui.SameLine()
            end
            if num_v != 0
                CImGui.BeginChild("vlinecuts", (w, Cfloat(0)))
                rendervlinecuts(plt, h)
                CImGui.EndChild()
            end
        end
        CImGui.End()
        p_open[] || empty!(plt.linecuts)
    end
end

let
    hlinecuts::Dict{String,Dict{String,Plot}} = Dict()
    global function renderhlinecuts(plt::Plot, h)
        if count(lc -> !lc.vline, plt.linecuts) == 0
            delete!(hlinecuts, plt.id)
        else
            haskey(hlinecuts, plt.id) || push!(hlinecuts, plt.id => Dict())
            for pss in filter(s -> s.ptype == "heatmap", plt.series)
                if haskey(hlinecuts[plt.id], pss.legend)
                    empty!(hlinecuts[plt.id][pss.legend].series)
                else
                    push!(
                        hlinecuts[plt.id],
                        pss.legend => Plot(title=stcstr(mlstr("Horizontal Linecuts"), " ", pss.legend))
                    )
                end
            end
            lgs = [s.legend for s in plt.series]
            for lg in filter(lg -> lg ∉ lgs, keys(hlinecuts[plt.id]))
                delete!(hlinecuts[plt.id], lg)
            end
            for pss in filter(s -> s.ptype == "heatmap", plt.series)
                zsz = size(pss.z)
                xr = collect(range(pss.axis.xaxis.lims[1], pss.axis.xaxis.lims[2], length=zsz[1]))
                yr = collect(range(pss.axis.yaxis.lims[2], pss.axis.yaxis.lims[1], length=zsz[2]))
                if !isempty(xr) && !isempty(yr) && !isempty(pss.z)
                    empty!(hlinecuts[plt.id][pss.legend].xaxes)
                    empty!(hlinecuts[plt.id][pss.legend].yaxes)
                    for (i, lc) in enumerate(filter(lc -> !lc.vline, plt.linecuts))
                        newseries = PlotSeries(
                            ptype=lc.ptype,
                            legend=stcstr("HL ", i),
                            axis=Axis(
                                xaxis=Xaxis(axis=pss.axis.xaxis.axis, label=pss.axis.xaxis.label),
                                yaxis=Yaxis(axis=pss.axis.yaxis.axis, label=pss.axis.zaxis.label)
                            )
                        )
                        push!(hlinecuts[plt.id][pss.legend].series, newseries)
                        setupplotseries!(newseries, xr, pss.z[:, argmin(abs.(yr .- lc.pos))])
                    end
                end
            end
            for (i, hplt) in enumerate(values(hlinecuts[plt.id]))
                CImGui.BeginChild(i, (Cfloat(0), h))
                Plot(hplt; psize=CImGui.ImVec2(-1, -1))
                CImGui.EndChild()
            end
        end
    end
end

let
    vlinecuts::Dict{String,Dict{String,Plot}} = Dict()
    global function rendervlinecuts(plt::Plot, h)
        if count(lc -> lc.vline, plt.linecuts) == 0
            delete!(vlinecuts, plt.id)
        else
            haskey(vlinecuts, plt.id) || push!(vlinecuts, plt.id => Dict())
            for pss in filter(s -> s.ptype == "heatmap", plt.series)
                if haskey(vlinecuts[plt.id], pss.legend)
                    empty!(vlinecuts[plt.id][pss.legend].series)
                else
                    push!(
                        vlinecuts[plt.id],
                        pss.legend => Plot(title=stcstr(mlstr("Vertical Linecuts"), " ", pss.legend))
                    )
                end
            end
            lgs = [s.legend for s in plt.series]
            for lg in filter(lg -> lg ∉ lgs, keys(vlinecuts[plt.id]))
                delete!(vlinecuts[plt.id], lg)
            end
            for pss in filter(s -> s.ptype == "heatmap", plt.series)
                zsz = size(pss.z)
                xr = collect(range(pss.axis.xaxis.lims[1], pss.axis.xaxis.lims[2], length=zsz[1]))
                yr = collect(range(pss.axis.yaxis.lims[1], pss.axis.yaxis.lims[2], length=zsz[2]))
                if !isempty(xr) && !isempty(yr) && !isempty(pss.z)
                    empty!(vlinecuts[plt.id][pss.legend].xaxes)
                    empty!(vlinecuts[plt.id][pss.legend].yaxes)
                    for (i, lc) in enumerate(filter(lc -> lc.vline, plt.linecuts))
                        newseries = PlotSeries(
                            ptype=lc.ptype,
                            legend=stcstr("VL ", i),
                            axis=Axis(
                                xaxis=Xaxis(axis=pss.axis.xaxis.axis, label=pss.axis.yaxis.label),
                                yaxis=Yaxis(axis=pss.axis.yaxis.axis, label=pss.axis.zaxis.label)
                            )
                        )
                        push!(vlinecuts[plt.id][pss.legend].series, newseries)
                        setupplotseries!(newseries, yr, reverse(pss.z[argmin(abs.(xr .- lc.pos)), :]))
                    end
                end
            end
            for (i, vplt) in enumerate(values(vlinecuts[plt.id]))
                CImGui.BeginChild(i, (Cfloat(0), h))
                Plot(vplt; psize=CImGui.ImVec2(-1, -1))
                CImGui.EndChild()
            end
        end
    end
end

function trunc(x::T1, y::T2)::Tuple{T1,T2} where {T1} where {T2}
    nx, ny = length(x), length(y)
    if nx == ny
        return x, y
    elseif nx > ny
        return @view(x[1:ny]), y
    else
        return x, @view(y[1:nx])
    end
end

function dropexeption!(z)
    true in ismissing.(z) && (replace!(z, missing => 0); z = float.(z))
    true in isnan.(z) && replace!(z, NaN => 0)
    Inf in z && (replace!(z, Inf => 0))
    -Inf in z && (replace!(z, -Inf => 0))
end
