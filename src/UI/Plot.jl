@kwdef mutable struct PlotStates
    id::String = ""
    xhv::Bool = false
    yhv::Bool = false
    chv::Bool = false
    phv::Bool = false
    showtooltip::Bool = true
    mspos::ImPlot.ImPlotPoint = ImPlot.ImPlotPoint(0, 0)
    plotpos::CImGui.ImVec2 = (0, 0)
    plotsize::CImGui.ImVec2 = (0, 0)
end

@kwdef mutable struct Annotation
    label::String = "Ann"
    posx::Cdouble = 0
    posy::Cdouble = 0
    offsetx::Cdouble = 0
    offsety::Cdouble = 0
    color::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    possz::Cfloat = 4
end
Annotation(label, posx, posy) = Annotation(label, posx, posy, posx, posy, [1.000, 1.000, 1.000, 1.000], 4)

@kwdef mutable struct Linecut
    ptype::String = "line"
    vline::Bool = true
    pos::Cdouble = 0
end

@kwdef mutable struct UIPlot
    x::Vector{Tx} where {Tx<:Union{Real,String}} = Union{Real,String}[]
    y::Vector{Vector{Ty}} where {Ty<:Real} = [Real[]]
    z::Matrix{Tz} where {Tz<:Float64} = Matrix{Float64}(undef, 0, 0)
    ptype::String = "line"
    title::String = "title"
    xlabel::String = "x"
    ylabel::String = "y"
    zlabel::String = "z"
    legends::Vector{String} = [string("y", i) for i in eachindex(y)]
    cmap::Cint = 4
    anns::Vector{Annotation} = Annotation[]
    linecuts::Vector{Linecut} = Linecut[]
    ps::PlotStates = PlotStates()
end
UIPlot(x, y, z) = UIPlot(x=x, y=y, z=z)

let
    annbuf::Annotation = Annotation()
    openpopup_mspos_list::Dict{String,Vector{Cfloat}} = Dict()
    global function Plot(uip::UIPlot, id, size=(0, 0))
        uip.ps.id = id
        CImGui.PushID(id)
        CImGui.BeginChild("Plot", size)
        CImGui.PushFont(PLOTFONT)
        if uip.ptype == "heatmap"
            if isempty(uip.z)
                PlotHolder(uip.ps, CImGui.ImVec2(-1, -1))
            else
                xlims, ylims, zlims, xlabel, ylabel = xyzsetting(uip)
                @c Plot(
                    uip.z, &uip.cmap, uip.ps;
                    psize=CImGui.ImVec2(-1, -1),
                    title=uip.title,
                    xlabel=xlabel,
                    ylabel=ylabel,
                    zlabel=uip.zlabel,
                    xlims=xlims,
                    ylims=ylims,
                    zlims=zlims,
                    anns=uip.anns,
                    linecuts=uip.linecuts
                )
            end
        else
            if isempty(uip.y) || isempty(uip.y[1])
                PlotHolder(uip.ps, CImGui.ImVec2(-1, -1))
            else
                x, xlabel = xysetting(uip)
                Plot(
                    x, uip.y, uip.ps;
                    psize=CImGui.ImVec2(-1, -1),
                    ptype=uip.ptype,
                    title=uip.title,
                    xlabel=xlabel,
                    ylabel=uip.ylabel,
                    legends=uip.legends,
                    xticks=uip.x,
                    anns=uip.anns
                )
            end
        end
        CImGui.PopFont()
        uip.ps.phv && CImGui.IsMouseClicked(2) && CImGui.OpenPopup(stcstr("title", id))
        haskey(openpopup_mspos_list, id) || push!(openpopup_mspos_list, id => Cfloat[0, 0])
        openpopup_mspos = openpopup_mspos_list[id]
        if CImGui.BeginPopup(stcstr("title", id))
            if openpopup_mspos == Cfloat[0, 0]
                openpopup_mspos .= uip.ps.mspos.x, uip.ps.mspos.y
                annbuf.posx, annbuf.posy = openpopup_mspos
                annbuf.offsetx, annbuf.offsety = openpopup_mspos
            end
            # annbuf.posx, annbuf.posy = CImGui.GetMousePosOnOpeningCurrentPopup()
            # annbuf.offsetx, annbuf.offsety = CImGui.GetMousePosOnOpeningCurrentPopup()
            @c InputTextRSZ(mlstr("title"), &uip.title)
            # @c ComBoS(mlstr("plot type"), &uip.ptype, ["line", "scatter", "heatmap"])
            if uip.ptype == "heatmap" && ImPlot.ColormapButton(
                unsafe_string(ImPlot.GetColormapName(uip.cmap)),
                ImVec2(Cfloat(-0.1), Cfloat(0)),
                uip.cmap
            )
                uip.cmap = (uip.cmap + 1) % Cint(ImPlot.GetColormapCount())
            end
            @c CImGui.Checkbox(mlstr("data tip"), &uip.ps.showtooltip)
            if CImGui.BeginMenu(mlstr("Add Linecut"))
                CImGui.MenuItem(mlstr("Horizontal Linecut")) && push!(uip.linecuts, Linecut(vline=false, pos=openpopup_mspos[2]))
                CImGui.MenuItem(mlstr("Vertical Linecut")) && push!(uip.linecuts, Linecut(pos=openpopup_mspos[1]))
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
                    push!(uip.anns, deepcopy(annbuf))
                end
            end
            # if CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save Image")))
            #     CImGui.CloseCurrentPopup()
            #     saveimg_seting(save_file(; filterlist="png;jpg;jpeg;bmp;eps;tif"), [uip])
            #     SYNCSTATES[Int(SavingImg)] = true
            # end
            CImGui.EndPopup()
        end
        igIsPopupOpenStr(stcstr("title", id), 0) || openpopup_mspos == Cfloat[0, 0] || fill!(openpopup_mspos, 0)
        if CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_RootAndChildWindows)
            uip.ps.xhv && CImGui.IsMouseDoubleClicked(0) && CImGui.OpenPopup(stcstr("xlabel", id))
        end
        if CImGui.BeginPopup(stcstr("xlabel", id))
            @c InputTextRSZ(stcstr("X ", mlstr("label")), &uip.xlabel)
            CImGui.EndPopup()
        end
        if CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_RootAndChildWindows)
            uip.ps.yhv && CImGui.IsMouseDoubleClicked(0) && CImGui.OpenPopup(stcstr("ylabel", id))
        end
        if CImGui.BeginPopup(stcstr("ylabel", id))
            @c InputTextRSZ(stcstr("Y ", mlstr("label")), &uip.ylabel)
            CImGui.EndPopup()
        end
        if CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_RootAndChildWindows)
            uip.ps.chv && CImGui.IsMouseDoubleClicked(0) && CImGui.OpenPopup(stcstr("zlabel", id))
        end
        if CImGui.BeginPopup(stcstr("zlabel", id))
            @c InputTextRSZ(stcstr("Z ", mlstr("label")), &uip.zlabel)
            CImGui.EndPopup()
        end
        CImGui.EndChild()
        CImGui.PopID()
    end
end

function Plot(x::Vector{T1}, ys::Vector{Vector{T2}}, ps::PlotStates;
    psize=CImGui.ImVec2(0, 0),
    ptype="line",
    title="title",
    xlabel="x",
    ylabel="y",
    legends=[],
    xticks=[],
    anns=[]
) where {T1<:Real} where {T2<:Real}
    llg = length(legends)
    lys = length(ys)
    if llg < lys
        for i in llg+1:lys
            push!(legends, string("y", i))
        end
    end
    xflags = SYNCSTATES[Int(SavingImg)] ? ImPlot.ImPlotAxisFlags_AutoFit : 0
    yflags = SYNCSTATES[Int(SavingImg)] ? ImPlot.ImPlotAxisFlags_AutoFit : 0
    if ImPlot.BeginPlot(title, xlabel, ylabel, psize, 0, xflags, yflags)
        ps.xhv = ImPlot.IsPlotXAxisHovered()
        ps.yhv = ImPlot.IsPlotYAxisHovered()
        ps.phv = ImPlot.IsPlotHovered()
        for (lg, y) in zip(legends, ys)
            px, py = Vector{T2}.(trunc(x, y))
            if ptype == "line"
                ImPlot.PlotLine(lg, px, py, length(py))
            elseif ptype == "scatter"
                ImPlot.PlotScatter(lg, px, py, length(py))
            end
            xl, xr = extrema(px)
            ps.mspos = ImPlot.GetPlotMousePos()
            if ps.showtooltip && ps.phv && xl <= ps.mspos.x <= xr && !SYNCSTATES[Int(SavingImg)]
                idx = argmin(abs.(px .- ps.mspos.x))
                yrg = ImPlot.GetPlotLimits().Y
                yl, yr = yrg.Min, yrg.Max
                if abs(py[idx] - ps.mspos.y) < 0.04(yr - yl)
                    CImGui.BeginTooltip()
                    CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
                    if isempty(xticks)
                        CImGui.Text(string("x : ", x[idx]))
                    else
                        CImGui.Text(string("x : ", xticks[idx]))
                    end
                    CImGui.Text(string("y : ", py[idx]))
                    CImGui.PopTextWrapPos()
                    CImGui.EndTooltip()
                end
            end
        end
        PlotAnns(anns)
        ImPlot.EndPlot()
    end
    ps.plotpos = CImGui.GetItemRectMin()
    ps.plotsize = CImGui.GetItemRectSize()
end

let
    width_list::Dict{String,Cfloat} = Dict()
    global function Plot(z::Matrix{Float64}, cmap::Ref{Cint}, ps::PlotStates;
        psize=CImGui.ImVec2(0, 0),
        ptype="heatmap",
        title="title",
        xlabel="x",
        ylabel="y",
        zlabel="z",
        xlims=(0, 1),
        ylims=(0, 1),
        zlims=(0, 1),
        anns=[],
        linecuts=[]
    )
        CImGui.BeginChild("Heatmap", psize)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 2))
        ImPlot.PushColormap(cmap[])
        lb = ImPlot.ImPlotPoint(CImGui.ImVec2(xlims[1], ylims[1]))
        rt = ImPlot.ImPlotPoint(CImGui.ImVec2(xlims[2], ylims[2]))
        xflags = SYNCSTATES[Int(SavingImg)] ? ImPlot.ImPlotAxisFlags_AutoFit : 0
        yflags = SYNCSTATES[Int(SavingImg)] ? ImPlot.ImPlotAxisFlags_AutoFit : 0
        if ImPlot.BeginPlot(
            title,
            xlabel,
            ylabel,
            CImGui.ImVec2(CImGui.GetContentRegionAvailWidth() - get!(width_list, ps.id, Cfloat(0)), -1),
            0,
            xflags,
            yflags
        )
            ImPlot.PlotHeatmap("", z, reverse(size(z))..., zlims..., "", lb, rt)
            ps.xhv = ImPlot.IsPlotXAxisHovered()
            ps.yhv = ImPlot.IsPlotYAxisHovered()
            ps.phv = ImPlot.IsPlotHovered()
            ps.mspos = ImPlot.GetPlotMousePos()
            if ps.showtooltip && ps.phv &&
               inregion(ps.mspos, (xlims[1], ylims[1]), (xlims[2], ylims[2])) && !SYNCSTATES[Int(SavingImg)]
                zsz = size(z)
                xr = range(xlims[1], xlims[2], length=zsz[1])
                yr = range(ylims[2], ylims[1], length=zsz[2])
                xidx = argmin(abs.(xr .- ps.mspos.x))
                yidx = argmin(abs.(yr .- ps.mspos.y))
                CImGui.BeginTooltip()
                CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
                CImGui.Text(string("x : ", xr[xidx]))
                CImGui.Text(string("y : ", yr[yidx]))
                CImGui.Text(string("z : ", z[xidx, yidx]))
                CImGui.PopTextWrapPos()
                CImGui.EndTooltip()
            end
            PlotAnns(anns)
            PlotLinecuts(linecuts)
            ImPlot.EndPlot()
        end
        ps.plotpos = CImGui.GetItemRectMin()
        ps.plotsize = CImGui.GetItemRectSize()
        CImGui.SameLine()
        ImPlot.ColormapScale(stcstr(zlabel, "###$(ps.id)"), zlims..., CImGui.ImVec2(0, -1))
        cmssize = CImGui.GetItemRectSize()
        ps.plotsize = (ps.plotsize.x + cmssize.x, ps.plotsize.y)
        width_list[ps.id] = cmssize.x
        ps.chv = CImGui.IsItemHovered()
        ImPlot.PopColormap()
        CImGui.PopStyleVar()
        CImGui.EndChild()
        if !isempty(linecuts)
            p_open = Ref(true)
            CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
            if CImGui.Begin(stcstr(title, " ", mlstr("Linecuts"), "###", ps.id), p_open, CImGui.ImGuiWindowFlags_NoDocking)
                zsz = size(z)
                hlines = collect(filter(x -> !x.vline, linecuts))
                vlines = collect(filter(x -> x.vline, linecuts))
                if !isempty(hlines) && ImPlot.BeginPlot(
                    stcstr(title, " ", mlstr("Horizontal Linecuts")), xlabel, zlabel,
                    CImGui.ImVec2(CImGui.GetContentRegionAvailWidth() / (1 + !isempty(vlines)), -1)
                )
                    for lc in hlines
                        xr = collect(range(xlims[1], xlims[2], length=zsz[1]))
                        yr = collect(range(ylims[2], ylims[1], length=zsz[2]))
                        yidx = argmin(abs.(yr .- lc.pos))
                        if lc.ptype == "line"
                            ImPlot.PlotLine("", xr, z[:, yidx], zsz[1])
                        elseif lc.ptype == "scatter"
                            ImPlot.PlotScatter("", xr, z[:, yidx], zsz[1])
                        end
                    end
                    ImPlot.EndPlot()
                end
                CImGui.SameLine()
                if !isempty(vlines) && ImPlot.BeginPlot(
                    stcstr(title, " ", mlstr("Vertical Linecuts")), ylabel, zlabel,
                    CImGui.ImVec2(-1, -1)
                )
                    for lc in vlines
                        xr = collect(range(xlims[1], xlims[2], length=zsz[1]))
                        yr = collect(range(ylims[1], ylims[2], length=zsz[2]))
                        xidx = argmin(abs.(xr .- lc.pos))
                        if lc.ptype == "line"
                            ImPlot.PlotLine("", yr, z[xidx, :], zsz[2])
                        elseif lc.ptype == "scatter"
                            ImPlot.PlotScatter("", yr, z[xidx, :], zsz[2])
                        end
                    end
                    ImPlot.EndPlot()
                end
            end
            CImGui.End()
            p_open[] || empty!(linecuts)
        end
    end
end

function PlotHolder(ps::PlotStates, psize=CImGui.ImVec2(0, 0))
    if ImPlot.BeginPlot(mlstr("No data input or incorrect input data!!!"), "X", "Y", psize)
        ps.xhv = ImPlot.IsPlotXAxisHovered()
        ps.yhv = ImPlot.IsPlotYAxisHovered()
        ps.phv = ImPlot.IsPlotHovered()
        ps.mspos = ImPlot.GetPlotMousePos()
        ImPlot.EndPlot()
    end
end

function PlotAnns(anns::Vector{Annotation})
    openpopup_i = 0
    delete_i = 0
    ishv = false
    CImGui.PushFont(GLOBALFONT)
    for (i, ann) in enumerate(anns)
        offset = ImPlot.PlotToPixels(ann.offsetx, ann.offsety) .- ImPlot.PlotToPixels(ann.posx, ann.posy)
        halflabelsz = CImGui.CalcTextSize(ann.label) ./ 2
        ImPlot.AnnotateClamped(
            ann.posx,
            ann.posy,
            correct_offset(offset, halflabelsz),
            CImGui.ImVec4(ann.color...),
            ann.label
        )
        CImGui.PushID(i)
        @c ImPlot.DragPoint(ann.label, &ann.posx, &ann.posy, true, CImGui.ImVec4(ann.color...), ann.possz)
        ishv = CImGui.IsItemHovered()
        @c ImPlot.DragPoint(
            "Offset",
            &ann.offsetx,
            &ann.offsety,
            true,
            CImGui.ImVec4(ann.color[1:3]..., 0.000),
            halflabelsz[2] / 2
        )
        ishv |= CImGui.IsItemHovered()
        ishv && (openpopup_i = i)
        CImGui.PopID()
        if CImGui.BeginPopup(stcstr("annotation", i))
            ann = anns[i]
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
            CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile, "##annotation")) && (delete_i = i)
            CImGui.EndPopup()
        end
    end
    CImGui.PopFont()
    ishv && CImGui.IsMouseClicked(1) && CImGui.OpenPopup(stcstr("annotation", openpopup_i))
    delete_i == 0 || deleteat!(anns, delete_i)
end

function PlotLinecuts(linecuts::Vector{Linecut})
    delete_i = 0
    CImGui.PushFont(GLOBALFONT)
    for (i, lc) in enumerate(linecuts)
        if lc.vline
            @c ImPlot.DragLineX(stcstr("Linecuts", " ", i), &lc.pos)
        else
            @c ImPlot.DragLineY(stcstr("Linecuts", " ", i), &lc.pos)
        end
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (delete_i = i)
            CImGui.EndPopup()
        end
    end
    CImGui.PopFont()
    delete_i == 0 || deleteat!(linecuts, delete_i)
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

function xysetting(uip::UIPlot)
    ylm = max_with_empty(length.(uip.y))
    xlims = (1, ylm)
    x = uip.x
    if isempty(uip.x)
        x = collect(eltype(uip.y[1]), 1:ylm)
    else
        if eltype(uip.x) <: Real
            if all(isnan, uip.x)
                x = collect(eltype(uip.y[1]), 1:ylm)
            else
                xlims = extrema(uip.x[findall(!isnan, uip.x)])
                xlims = xlims[1] == xlims[2] ? (xlims[1] - 1, xlims[1] + 1) : xlims
            end
        elseif eltype(uip.x) <: AbstractString
            xl = length(uip.x)
            xticksnum = round(
                Int,
                2CImGui.GetContentRegionAvailWidth() / max_with_empty(lengthpr.(uip.x)) / 3CImGui.GetFontSize()
            )
            xticks = if xticksnum == 0
                uip.x[[1]]
            else
                uip.x[round.(Int, range(1, xl, length=2xticksnum + 1))[2:2:end-1]]
            end
            ImPlot.SetNextPlotTicksX(1 + xl / 2xticksnum, xl - xl / 2xticksnum, xticksnum, xticks)
            x = collect(eltype(uip.y[1]), 1:ylm)
        end
    end
    ImPlot.SetNextPlotLimitsX(xlims..., CImGui.ImGuiCond_Once)
    xlabel = xlims != (1, ylm) || eltype(uip.x) <: AbstractString ? uip.xlabel : mlstr("No correct X input")
    ylims = (0, 1)
    yall = vcat(uip.y...)
    if !all(isnan, yall)
        ylims = extrema(yall[findall(!isnan, yall)])
        ylims = ylims[1] == ylims[2] ? (ylims[1] - 1, ylims[1] + 1) : ylims
    end
    ImPlot.SetNextPlotLimitsY(ylims..., CImGui.ImGuiCond_Once, ImPlot.ImPlotYAxis_1)
    x, xlabel
end

function xyzsetting(uip::UIPlot)
    sz1, sz2 = size(uip.z)
    xlims = (1, sz2)
    if !isempty(uip.x)
        if eltype(uip.x) <: Real
            if !all(isnan, uip.x)
                xlims = extrema(uip.x[findall(!isnan, uip.x)])
                xlims[1] == xlims[2] && (xlims = (0, 1))
            end
        elseif eltype(uip.x) <: AbstractString
            xlims = (1, sz2)
            xticksnum = round(
                Int,
                2CImGui.GetContentRegionAvailWidth() / max_with_empty(lengthpr.(uip.x)) / 3CImGui.GetFontSize()
            )
            xticks = if length(uip.x) < xticksnum
                uip.x
            else
                uip.x[round.(Int, range(1, sz2, length=2xticksnum + 1))[2:2:end-1]]
            end
            ImPlot.SetNextPlotTicksX(1 + sz2 / 2xticksnum, sz2 - sz2 / 2xticksnum, xticksnum, xticks)
        end
    end
    ImPlot.SetNextPlotLimitsX(xlims..., CImGui.ImGuiCond_Once)
    xlabel = xlims != (1, sz2) || eltype(uip.x) <: AbstractString ? uip.xlabel : mlstr("No correct X input")
    ylims = (1, sz1)
    if !isempty(uip.y) && !all(isnan, uip.y[1])
        ylims = extrema(uip.y[1][findall(!isnan, uip.y[1])])
        ylims[1] == ylims[2] && (ylims = (0, 1))
    end
    ImPlot.SetNextPlotLimitsY(ylims..., CImGui.ImGuiCond_Once, ImPlot.ImPlotYAxis_1)
    ylabel = ylims == (1, sz1) ? mlstr("No correct Y input") : uip.ylabel
    zlims = extrema(uip.z)
    zlims[1] == zlims[2] && (zlims = (0, 1))
    xlims, ylims, zlims, xlabel, ylabel
end

# let
#     count_fps::Int = 0
#     path::String = ""
#     uips::Vector{UIPlot} = []
#     global function saveimg()
#         if SYNCSTATES[Int(SavingImg)]
#             count_fps == 0 && path == "" && (SYNCSTATES[Int(SavingImg)] = false; return 0)
#             count_fps += 1
#             viewport = igGetMainViewport()
#             if CONF.Basic.hidewindow
#                 CImGui.SetNextWindowPos((0, 0))
#                 CImGui.SetNextWindowSize((CONF.Basic.windowsize...,))
#             else
#                 CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
#                 CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
#             end
#             CImGui.SetNextWindowFocus()
#             CImGui.SetNextWindowBgAlpha(1)
#             CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, 0)
#             CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, (0, 0))
#             CImGui.Begin("Save Plot", C_NULL, CImGui.ImGuiWindowFlags_NoTitleBar)
#             l = length(uips)
#             n = CONF.DAQ.plotshowcol
#             m = ceil(Int, l / n)
#             n = m == 1 ? l : n
#             height = (CImGui.GetWindowHeight() - (m - 1) * unsafe_load(IMGUISTYLE.ItemSpacing.y)) / m
#             CImGui.Columns(n, C_NULL, false)
#             for i in 1:m
#                 for j in 1:n
#                     idx = (i - 1) * n + j
#                     if idx <= l
#                         Plot(uips[idx], stcstr("Save Plot", idx), (Cfloat(0), height))
#                         CImGui.NextColumn()
#                     end
#                 end
#             end
#             CImGui.End()
#             CImGui.PopStyleVar(2)
#             if count_fps == CONF.DAQ.pick_fps[1]
#                 img = ImageMagick.load("screenshot:")
#                 vpos, vsize = unsafe_load(viewport.WorkPos), unsafe_load(viewport.WorkSize)
#                 CONF.Basic.viewportenable || (vpos = CImGui.ImVec2(vpos[1] + glfwwindowx, vpos[2] + glfwwindowy))
#                 CONF.Basic.hidewindow && (vpos = (0, 0); vsize = (CONF.Basic.windowsize...,))
#                 u, d = round(Int, vpos[2] + 1), round(Int, vpos[2] + vsize[2] - 4)
#                 l, r = round(Int, vpos[1] + 1), round(Int, vpos[1] + vsize[1] - 1)
#                 if length(size(img)) == 3
#                     imgr, imgc, imgh = size(img)
#                     img = reshape(img, imgr, imgh * imgc)
#                 end
#                 @trypass FileIO.save(path, img[u:d, l:r]) @error "[$(now())]\n$(mlstr("error saving image!!!"))"
#                 SYNCSTATES[Int(SavingImg)] = false
#                 count_fps = 0
#                 return 0
#             end
#         end
#         return count_fps
#     end

#     global function saveimg_seting(setpath, setuips)
#         empty!(uips)
#         path = setpath
#         for p in setuips
#             push!(uips, deepcopy(p))
#         end
#     end
# end