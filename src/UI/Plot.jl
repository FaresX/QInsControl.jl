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
    pos::Cdouble = 0
end

@kwdef mutable struct Xaxis
    axis::ImPlot.ImAxis = ImPlot.ImAxis_X1
    label::String = "x1"
    tickvalues::Vector{Cdouble} = []
    ticklabels::Vector{String} = []
    hovered::Bool = false
end

@kwdef mutable struct Yaxis
    axis::ImPlot.ImAxis = ImPlot.ImAxis_Y1
    label::String = "y1"
    tickvalues::Vector{Cdouble} = []
    ticklabels::Vector{String} = []
    hovered::Bool = false
end

@kwdef mutable struct Zaxis
    axis::UInt32 = 1
    label::String = "z1"
    colormap::ImPlot.ImPlotColormap = ImPlot.ImPlotColormap_Viridis
    zlims::Tuple{Cdouble,Cdouble} = (0, 1)
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
    xlims::Tuple{Cdouble,Cdouble} = (0.0, 1.0)
    ylims::Tuple{Cdouble,Cdouble} = (0.0, 1.0)
    zlims::Tuple{Cdouble,Cdouble} = (0.0, 1.0)
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
            CImGui.BeginGroup()
            for za in plt.zaxes
                CImGui.Text(stcstr("Colormap ", za.axis))
            end
            CImGui.EndGroup()
            CImGui.SameLine()
            CImGui.BeginGroup()
            for za in plt.zaxes
                if ImPlot.ColormapButton(
                    stcstr(unsafe_string(ImPlot.GetColormapName(za.colormap)), "##", za.axis),
                    ImVec2(Cfloat(-0.1), Cfloat(0)),
                    za.colormap
                )
                    za.colormap = (za.colormap + 1) % Cint(ImPlot.GetColormapCount())
                    for pss in plt.series
                        pss.axis.zaxis.axis == za.axis && (pss.axis.zaxis.colormap = za.colormap)
                    end
                end
            end
            CImGui.EndGroup()
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
    for z in [pss.axis.zaxis for pss in plt.series if pss.ptype == "heatmap"]
        z.axis in [za.axis for za in plt.zaxes] || push!(plt.zaxes, deepcopy(z))
    end
    for pltza in plt.zaxes
        for axis in [pss.axis for pss in plt.series]
            axis.zaxis.axis == pltza.axis && (axis.zaxis = deepcopy(pltza))
        end
    end
end

function Plot(plt::Plot; psize=CImGui.ImVec2(0, 0), flags=0)
    if ImPlot.BeginPlot(
        stcstr(plt.title, "###", plt.id),
        CImGui.ImVec2(CImGui.GetContentRegionAvailWidth() - sum(za.colormapscalesize.x for za in plt.zaxes; init=0), psize.y),
        flags
    )
        isempty(plt.xaxes) && mergexaxes!(plt)
        isempty(plt.yaxes) && mergeyaxes!(plt)
        map(xa -> ImPlot.SetupAxis(xa.axis, xa.label), plt.xaxes)
        map(ya -> ImPlot.SetupAxis(ya.axis, ya.label), plt.yaxes)
        map(xa -> xa.hovered = ImPlot.IsAxisHovered(xa.axis), plt.xaxes)
        map(ya -> ya.hovered = ImPlot.IsAxisHovered(ya.axis), plt.yaxes)
        for (i, pss) in enumerate(plt.series)
            if pss.ptype == "heatmap"
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
        plt.hovered = ImPlot.IsPlotHovered()
        ImPlot.EndPlot()
    end
    plt.plotpos = CImGui.GetItemRectMin()
    plt.plotsize = CImGui.GetItemRectSize()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
    for za in plt.zaxes
        CImGui.SameLine()
        ImPlot.PushColormap(za.colormap)
        ImPlot.ColormapScale(stcstr(za.label, "###", plt.id, "-", za.axis), za.zlims..., CImGui.ImVec2(Cfloat(0), psize.y))
        ImPlot.PopColormap()
        za.colormapscalesize = CImGui.GetItemRectSize()
        za.hovered = CImGui.IsItemHovered()
    end
    CImGui.PopStyleVar()
    for pss in plt.series
        pss.ptype == "heatmap" && !isempty(pss.z) && renderlinecuts(plt.linecuts, pss, plt)
    end
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
        idx = argmin(abs.(pss.x .- plt.mspos.x))
        yrg = ImPlot.GetPlotLimits().Y
        yl, yr = yrg.Min, yrg.Max
        if abs(pss.y[idx] - plt.mspos.y) < 0.04(yr - yl)
            CImGui.BeginTooltip()
            SeparatorTextColored(MORESTYLE.Colors.HighlightText, pss.legend)
            CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
            if isempty(pss.axis.xaxis.tickvalues)
                CImGui.Text(string("x : ", pss.x[idx]))
            else
                CImGui.Text(string("x : ", pss.axis.xaxis.ticklabels[idx]))
            end
            CImGui.Text(string("y : ", pss.y[idx]))
            CImGui.PopTextWrapPos()
            CImGui.EndTooltip()
        end
    end
end
Plot(pss::PlotSeries, plt::Plot, ::Val{:line}) = Plot2D(ImPlot.PlotLine, pss, plt)
Plot(pss::PlotSeries, plt::Plot, ::Val{:scatter}) = Plot2D(ImPlot.PlotScatter, pss, plt)

function Plot(pss::PlotSeries, plt::Plot, ::Val{:heatmap})
    ImPlot.PushColormap(pss.axis.zaxis.colormap)
    ImPlot.PlotHeatmap(
        pss.legend, pss.z, reverse(size(pss.z))..., pss.axis.zaxis.zlims..., "",
        ImPlot.ImPlotPoint(pss.xlims[1], pss.ylims[1]), ImPlot.ImPlotPoint(pss.xlims[2], pss.ylims[2])
    )
    ImPlot.PopColormap()
    pss.legendhovered = ImPlot.IsLegendEntryHovered(pss.legend)
    plt.mspos = ImPlot.GetPlotMousePos()
    if plt.showtooltip && plt.hovered && inregion(plt.mspos, (pss.xlims[1], pss.ylims[1]), (pss.xlims[2], pss.ylims[2]))
        zsz = size(pss.z)
        xr = range(pss.xlims[1], pss.xlims[2], length=zsz[1])
        yr = range(pss.ylims[2], pss.ylims[1], length=zsz[2])
        xidx = argmin(abs.(xr .- plt.mspos.x))
        yidx = argmin(abs.(yr .- plt.mspos.y))
        CImGui.BeginTooltip()
        SeparatorTextColored(MORESTYLE.Colors.HighlightText, pss.legend)
        CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
        CImGui.Text(string("x : ", xr[xidx]))
        CImGui.Text(string("y : ", yr[yidx]))
        CImGui.Text(string("z : ", pss.z[xidx, yidx]))
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
    PlotLinecuts(plt.linecuts)
end

function setupplotseries!(pss::PlotSeries, x::AbstractVector{Tx}, y) where {Tx<:AbstractString}
    pss.x = 1:length(y)
    pss.y = y
    pss.xaxis.axis.ticklabels = x
end
function setupplotseries!(pss::PlotSeries, x::AbstractVector{Tx}, y) where {Tx<:Real}
    pss.x, pss.y = trunc(x, y)
end
function setupplotseries!(pss::PlotSeries, x::AbstractVector{Tx}, y, z) where {Tx<:Real}
    pss.x = x
    pss.y = y
    pss.z = z
    if isempty(x)
        pss.xlims = (0, 1)
    else
        xlims = extrema(x)
        xlims[1] == xlims[2] && (xlims = (0, 1))
        pss.xlims = xlims
    end
    if isempty(y)
        pss.ylims = (0, 1)
    else
        ylims = extrema(y)
        ylims[1] == ylims[2] && (ylims = (0, 1))
        pss.ylims = ylims
    end
    if isempty(z)
        pss.zlims = (0, 1)
    else
        zlims = extrema(z)
        zlims[1] == zlims[2] && (zlims = (0, 1))
        pss.zlims = zlims
    end
    pss.axis.zaxis.zlims = pss.zlims
end

function PlotAnns(anns::Vector{Annotation})
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

function isdraglinexhovered(x)
    !ImPlot.IsPlotHovered() && abs(ImPlot.PlotToPixels(x, ImPlot.GetPlotMousePos().y).x - CImGui.GetMousePos().x) < 4
end
function isdraglineyhovered(y)
    !ImPlot.IsPlotHovered() && abs(ImPlot.PlotToPixels(ImPlot.GetPlotMousePos().x, y).y - CImGui.GetMousePos().y) < 4
end

function renderlinecuts(linecuts::Vector{Linecut}, pss::PlotSeries, plt::Plot)
    if !isempty(linecuts)
        p_open = Ref(true)
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin(
            stcstr(plt.title, " ", mlstr("Linecuts"), " ", pss.legend, "###", plt.id, pss.legend),
            p_open,
            CImGui.ImGuiWindowFlags_NoDocking
        )
            zsz = size(pss.z)
            hlines = collect(filter(x -> !x.vline, linecuts))
            vlines = collect(filter(x -> x.vline, linecuts))
            if !isempty(hlines) && ImPlot.BeginPlot(
                stcstr(plt.title, " ", mlstr("Horizontal Linecuts")),
                CImGui.ImVec2(CImGui.GetContentRegionAvailWidth() / (1 + !isempty(vlines)), -1)
            )
                ImPlot.SetupAxis(pss.axis.xaxis.axis, pss.axis.xaxis.label)
                ImPlot.SetupAxis(pss.axis.yaxis.axis, pss.axis.zaxis.label)
                for lc in hlines
                    xr = collect(range(pss.xlims[1], pss.xlims[2], length=zsz[1]))
                    yr = collect(range(pss.ylims[2], pss.ylims[1], length=zsz[2]))
                    yidx = argmin(abs.(yr .- lc.pos))
                    if lc.ptype == "line"
                        ImPlot.PlotLine("", xr, pss.z[:, yidx], zsz[1])
                    elseif lc.ptype == "scatter"
                        ImPlot.PlotScatter("", xr, pss.z[:, yidx], zsz[1])
                    end
                end
                ImPlot.EndPlot()
            end
            CImGui.SameLine()
            if !isempty(vlines) && ImPlot.BeginPlot(
                stcstr(plt.title, " ", mlstr("Vertical Linecuts")), pss.axis.yaxis.label, pss.axis.zaxis.label,
                CImGui.ImVec2(-1, -1)
            )
                for lc in vlines
                    xr = collect(range(pss.xlims[1], pss.xlims[2], length=zsz[1]))
                    yr = collect(range(pss.ylims[1], pss.ylims[2], length=zsz[2]))
                    xidx = argmin(abs.(xr .- lc.pos))
                    if lc.ptype == "line"
                        ImPlot.PlotLine("", yr, reverse(pss.z[xidx, :]), zsz[2])
                    elseif lc.ptype == "scatter"
                        ImPlot.PlotScatter("", yr, reverse(pss.z[xidx, :]), zsz[2])
                    end
                end
                ImPlot.EndPlot()
            end
        end
        CImGui.End()
        p_open[] || empty!(linecuts)
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