Base.@kwdef mutable struct PlotState
    xhv::Bool = false
    yhv::Bool = false
    phv::Bool = false
    annhv::Bool = false
    annhv_i::Cint = 1
    showtooltip::Bool = true
    mspos::ImPlot.ImPlotPoint = ImPlot.ImPlotPoint(0, 0)
    plotpos::CImGui.ImVec2 = (0, 0)
    plotsize::CImGui.ImVec2 = (0, 0)
end

mutable struct Annotation
    label::String
    posx::Cdouble
    posy::Cdouble
    offsetx::Cdouble
    offsety::Cdouble
    color::Vector{Cfloat}
    possz::Cfloat
end
Annotation(label, posx, posy) = Annotation(label, posx, posy, posx, posy, [1.000, 1.000, 1.000, 1.000], 4)
Annotation() = Annotation("Ann", 0, 0)

mutable struct UIPlot
    x::Vector{Tx} where {Tx<:Union{Real,String}}
    y::Vector{Vector{Ty}} where {Ty<:Real}
    z::Matrix{Tz} where {Tz<:Float64}
    ptype::String
    title::String
    xlabel::String
    ylabel::String
    zlabel::String
    legends::Vector{String}
    anns::Vector{Annotation}
end
UIPlot(x, y, z) = UIPlot(x, y, z, "line", "title", "x", "y", "z", [string("y", i) for i in eachindex(y)], Annotation[])
UIPlot() = UIPlot(Union{Real,String}[], [Real[]], Matrix{Float64}(undef, 0, 0))

let
    annbuf::Annotation = Annotation()
    openpopup_mspos::Vector{Cfloat} = [0, 0]
    global function Plot(uip::UIPlot, id, size=(0, 0))
        CImGui.PushID(id)
        CImGui.BeginChild("Plot", size)
        if uip.ptype == "heatmap"
            if isempty(uip.z)
                ps = PlotHolder(CImGui.ImVec2(-1, -1))
            else
                xlims, ylims, zlims, xlabel, ylabel = xyzsetting(uip)
                ps = @c Plot(
                    uip.z, &uip.zlabel, id;
                    psize=CImGui.ImVec2(-1, -1),
                    title=uip.title,
                    xlabel=xlabel,
                    ylabel=ylabel,
                    xlims=xlims,
                    ylims=ylims,
                    zlims=zlims,
                    anns=uip.anns
                )
            end
        else
            if isempty(uip.y) || isempty(uip.y[1])
                ps = PlotHolder(CImGui.ImVec2(-1, -1))
            else
                x, xlabel = xysetting(uip)
                ps = Plot(
                    x, uip.y;
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
        ps.phv && CImGui.IsMouseClicked(2) && CImGui.OpenPopup("title$id")
        if CImGui.BeginPopup("title$id")
            if openpopup_mspos == Cfloat[0, 0]
                openpopup_mspos = [ps.mspos.x, ps.mspos.y]
                annbuf.posx, annbuf.posy = openpopup_mspos
                annbuf.offsetx, annbuf.offsety = openpopup_mspos
            end
            @c InputTextRSZ("标题", &uip.title)
            @c ComBoS("绘图类型", &uip.ptype, ["line", "scatter", "heatmap"])
            @c CImGui.Checkbox("数据提示", &ps.showtooltip)
            if CImGui.CollapsingHeader("标签")
                @c InputTextRSZ("内容", &annbuf.label)
                pos = Cfloat[annbuf.posx, annbuf.posy]
                CImGui.InputFloat2("坐标", pos)
                annbuf.posx, annbuf.posy = pos
                offset = Cfloat[annbuf.offsetx, annbuf.offsety]
                CImGui.InputFloat2("偏移", offset)
                annbuf.offsetx, annbuf.offsety = offset
                @c CImGui.DragFloat("尺寸", &annbuf.possz, 1.0, 1, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.ColorEdit4("颜色", annbuf.color, CImGui.ImGuiColorEditFlags_AlphaBar)
                CImGui.SameLine()
                if CImGui.Button(morestyle.Icons.NewFile * "##标签")
                    newann = Annotation(
                        annbuf.label,
                        annbuf.posx,
                        annbuf.posy,
                        annbuf.offsetx,
                        annbuf.offsety,
                        copy(annbuf.color),
                        annbuf.possz
                    )
                    push!(uip.anns, newann)
                end
            end
            if CImGui.Button(morestyle.Icons.SaveButton * " 保存##图像")
                CImGui.CloseCurrentPopup()
                saveimg_seting(save_file(; filterlist="png;jpg;jpeg;bmp;eps;tif"), [uip])
                global savingimg = true
            end
            CImGui.EndPopup()
        end
        igIsPopupOpenStr("title$id", 0) || openpopup_mspos == Cfloat[0, 0] || (openpopup_mspos = Cfloat[0, 0])
        ps.annhv && CImGui.IsMouseClicked(1) && CImGui.OpenPopup("注释")
        if CImGui.BeginPopup("注释")
            ann_i = uip.anns[ps.annhv_i]
            @c InputTextRSZ("内容", &ann_i.label)
            pos = Cfloat[ann_i.posx, ann_i.posy]
            CImGui.InputFloat2("坐标", pos)
            ann_i.posx, ann_i.posy = pos
            offset = Cfloat[ann_i.offsetx, ann_i.offsety]
            CImGui.InputFloat2("偏移", offset)
            ann_i.offsetx, ann_i.offsety = offset
            @c CImGui.DragFloat("尺寸", &ann_i.possz, 1.0, 1, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
            CImGui.ColorEdit4("颜色", ann_i.color, CImGui.ImGuiColorEditFlags_AlphaBar)
            CImGui.SameLine()
            if CImGui.Button(morestyle.Icons.CloseFile * "##标签")
                deleteat!(uip.anns, ps.annhv_i)
                CImGui.CloseCurrentPopup()
            end
            CImGui.EndPopup()
        end
        ps.xhv && CImGui.IsMouseDoubleClicked(0) && CImGui.OpenPopup("x标签$id")
        if CImGui.BeginPopup("x标签$id")
            @c InputTextRSZ("x标签", &uip.xlabel)
            CImGui.EndPopup()
        end
        ps.yhv && CImGui.IsMouseDoubleClicked(0) && CImGui.OpenPopup("y标签$id")
        if CImGui.BeginPopup("y标签$id")
            @c InputTextRSZ("y标签", &uip.ylabel)
            CImGui.EndPopup()
        end
        CImGui.EndChild()
        CImGui.PopID()
    end
end

let
    px = []
    py = []
    ps::PlotState = PlotState()
    global function Plot(x::Vector{T1}, ys::Vector{Vector{T2}};
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
        global savingimg
        xflags = savingimg ? ImPlot.ImPlotAxisFlags_AutoFit : 0
        yflags = savingimg ? ImPlot.ImPlotAxisFlags_AutoFit : 0
        if ImPlot.BeginPlot(title, xlabel, ylabel, psize, 0, xflags, yflags)
            ps.xhv = ImPlot.IsPlotXAxisHovered()
            ps.yhv = ImPlot.IsPlotYAxisHovered()
            ps.phv = ImPlot.IsPlotHovered()
            for (lg, y) in zip(legends, ys)
                px, py = Vector{T2}.(trunc(x, y))
                ptype == "line" && ImPlot.PlotLine(lg, px, py, length(py))
                ptype == "scatter" && ImPlot.PlotScatter(lg, px, py, length(py))
                xl, xr = extrema(px)
                ps.mspos = ImPlot.GetPlotMousePos()
                if ps.showtooltip && ps.phv && xl <= ps.mspos.x <= xr && !savingimg
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
            PlotAnns(anns, ps)
            ImPlot.EndPlot()
        end
        ps.plotpos = CImGui.GetItemRectMin()
        ps.plotsize = CImGui.GetItemRectSize()
        ps
    end
end

let
    cmap::Cint = Cint(ImPlot.ImPlotColormap_Viridis)
    width::Cfloat = 0
    ps::PlotState = PlotState()
    global function Plot(z::Matrix{Float64}, zlabel::Ref, id;
        psize=CImGui.ImVec2(0, 0),
        ptype="heatmap",
        title="title",
        xlabel="x",
        ylabel="y",
        xlims=(0, 1),
        ylims=(0, 1),
        zlims=(0, 1),
        anns=[]
    )
        CImGui.BeginChild("Heatmap", psize)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 2))
        if ImPlot.ColormapButton(unsafe_string(ImPlot.GetColormapName(cmap)), ImVec2(-1, 0), cmap)
            cmap = (cmap + 1) % Cint(ImPlot.GetColormapCount())
        end
        ImPlot.PushColormap(cmap)
        lb = ImPlot.ImPlotPoint(CImGui.ImVec2(xlims[1], ylims[1]))
        rt = ImPlot.ImPlotPoint(CImGui.ImVec2(xlims[2], ylims[2]))
        global savingimg
        xflags = savingimg ? ImPlot.ImPlotAxisFlags_AutoFit : 0
        yflags = savingimg ? ImPlot.ImPlotAxisFlags_AutoFit : 0
        if ImPlot.BeginPlot(title, xlabel, ylabel, CImGui.ImVec2(CImGui.GetContentRegionAvailWidth() - width, -1), 0, xflags, yflags)
            pz = Matrix(transpose(z))
            ImPlot.PlotHeatmap("", pz, size(z)..., zlims..., "", lb, rt)
            ps.xhv = ImPlot.IsPlotXAxisHovered()
            ps.yhv = ImPlot.IsPlotYAxisHovered()
            ps.phv = ImPlot.IsPlotHovered()
            ps.mspos = ImPlot.GetPlotMousePos()
            if ps.showtooltip && ps.phv && inregion(ps.mspos, [xlims[1], ylims[1], xlims[2], ylims[2]]) && !savingimg
                zsz = size(z)
                xr = range(xlims[1], xlims[2], length=zsz[2])
                yr = range(ylims[2], ylims[1], length=zsz[1])
                xidx = argmin(abs.(xr .- ps.mspos.x))
                yidx = argmin(abs.(yr .- ps.mspos.y))
                CImGui.BeginTooltip()
                CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
                CImGui.Text(string("x : ", xr[xidx]))
                CImGui.Text(string("y : ", yr[yidx]))
                CImGui.Text(string("z : ", z[yidx, xidx]))
                CImGui.PopTextWrapPos()
                CImGui.EndTooltip()
            end
            PlotAnns(anns, ps)
            ImPlot.EndPlot()
        end
        ps.plotpos = CImGui.GetItemRectMin()
        ps.plotsize = CImGui.GetItemRectSize()
        CImGui.SameLine()
        ImPlot.ColormapScale(string(zlabel[], "###$id"), zlims..., CImGui.ImVec2(0, -1))
        cmssize = CImGui.GetItemRectSize()
        ps.plotsize = (ps.plotsize.x + cmssize.x, ps.plotsize.y)
        width = cmssize.x
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && CImGui.OpenPopup("z标签$id")
        if CImGui.BeginPopup("z标签$id")
            InputTextRSZ("z标签##$id", zlabel)
            CImGui.EndPopup()
        end
        ImPlot.PopColormap()
        CImGui.PopStyleVar()
        CImGui.EndChild()
        ps
    end
end

let
    ps::PlotState = PlotState()
    global function PlotHolder(psize=CImGui.ImVec2(0, 0))
        if ImPlot.BeginPlot("没有数据输入或输入数据有误！！！", "X", "Y", psize)
            ps.xhv = ImPlot.IsPlotXAxisHovered()
            ps.yhv = ImPlot.IsPlotYAxisHovered()
            ps.phv = ImPlot.IsPlotHovered()
            ps.mspos = ImPlot.GetPlotMousePos()
            ImPlot.EndPlot()
        end
        ps
    end
end

function PlotAnns(anns::Vector{Annotation}, ps::PlotState)
    for (i, ann) in enumerate(anns)
        offset = ImPlot.PlotToPixels(ann.offsetx, ann.offsety) - ImPlot.PlotToPixels(ann.posx, ann.posy)
        halflabelsz = CImGui.CalcTextSize(ann.label) / 2
        ImPlot.AnnotateClamped(
            ann.posx,
            ann.posy,
            correct_offset(offset, halflabelsz),
            CImGui.ImVec4(ann.color...),
            ann.label
        )
        CImGui.PushID(i)
        @c ImPlot.DragPoint(ann.label, &ann.posx, &ann.posy, true, CImGui.ImVec4(ann.color...), ann.possz)
        ps.annhv = CImGui.IsItemHovered()
        @c ImPlot.DragPoint(
            "Offset",
            &ann.offsetx,
            &ann.offsety,
            true,
            CImGui.ImVec4(ann.color[1:3]..., 0.000),
            halflabelsz.y / 2
        )
        ps.annhv |= CImGui.IsItemHovered()
        ps.annhv && (ps.annhv_i = i)
        CImGui.PopID()
    end
end

function correct_offset(offset, halflabelsz)
    if offset.x > halflabelsz.x
        if offset.y > halflabelsz.y
            offset_correct = offset - halflabelsz
        elseif -halflabelsz.y <= offset.y <= halflabelsz.y
            offset_correct = CImGui.ImVec2(offset.x - halflabelsz.x, Cfloat(0))
        else
            offset_correct = CImGui.ImVec2(offset.x - halflabelsz.x, offset.y + halflabelsz.y)
        end
    elseif -halflabelsz.x <= offset.x <= halflabelsz.x
        if offset.y > halflabelsz.y
            offset_correct = CImGui.ImVec2(Cfloat(0), offset.y - halflabelsz.y)
        elseif -halflabelsz.y <= offset.y <= halflabelsz.y
            offset_correct = CImGui.ImVec2(Cfloat(0), Cfloat(0))
        else
            offset_correct = CImGui.ImVec2(Cfloat(0), offset.y + halflabelsz.y)
        end
    else
        if offset.y > halflabelsz.y
            offset_correct = CImGui.ImVec2(offset.x + halflabelsz.x, offset.y - halflabelsz.y)
        elseif -halflabelsz.y <= offset.y <= halflabelsz.y
            offset_correct = CImGui.ImVec2(offset.x + halflabelsz.x, Cfloat(0))
        else
            offset_correct = offset + halflabelsz
        end
    end
    return offset_correct
end

function trunc(x::T1, y::T2)::Tuple{T1,T2} where {T1} where {T2}
    nx, ny = length(x), length(y)
    if nx == ny
        return x, y
    elseif nx > ny
        return x[1:ny], y
    else
        return x, y[1:nx]
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
            xticksnum = round(Int, 3CImGui.GetContentRegionAvailWidth() / max_with_empty(lengthpr.(uip.x)) / 2CImGui.GetFontSize())
            xticks = uip.x[round.(Int, range(1, xl, length=2xticksnum + 1))[2:2:end-1]]
            ImPlot.SetNextPlotTicksX(1 + xl / 2xticksnum, xl - xl / 2xticksnum, xticksnum, xticks)
            x = collect(eltype(uip.y[1]), 1:ylm)
        end
    end
    ImPlot.SetNextPlotLimitsX(xlims..., CImGui.ImGuiCond_Once)
    xlabel = xlims != (1, ylm) || eltype(uip.x) <: AbstractString ? uip.xlabel : "No correct X input"
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
            xticksnum = round(Int, 3CImGui.GetContentRegionAvailWidth() / max_with_empty(lengthpr.(uip.x)) / 2CImGui.GetFontSize())
            xticks = uip.x[round.(Int, range(1, sz2, length=2xticksnum + 1))[2:2:end-1]]
            ImPlot.SetNextPlotTicksX(1 + sz2 / 2xticksnum, sz2 - sz2 / 2xticksnum, xticksnum, xticks)
        end
    end
    ImPlot.SetNextPlotLimitsX(xlims..., CImGui.ImGuiCond_Once)
    xlabel = xlims != (1, sz2) || eltype(uip.x) <: AbstractString ? uip.xlabel : "No correct X input"
    ylims = (1, sz1)
    if !isempty(uip.y) && !all(isnan, uip.y[1])
        ylims = extrema(uip.y[1][findall(!isnan, uip.y[1])])
        ylims[1] == ylims[2] && (ylims = (0, 1))
    end
    ImPlot.SetNextPlotLimitsY(ylims..., CImGui.ImGuiCond_Once, ImPlot.ImPlotYAxis_1)
    ylabel = ylims == (1, sz1) ? "No correct Y input" : uip.ylabel
    zlims = extrema(uip.z)
    zlims[1] == zlims[2] && (zlims = (0, 1))
    xlims, ylims, zlims, xlabel, ylabel
end

let
    count_fps::Int = 0
    path::String = ""
    uips::Vector{UIPlot} = []
    global function saveimg()
        global savingimg
        if savingimg
            count_fps == 0 && path == "" && (savingimg = false; return 0)
            count_fps += 1
            viewport = igGetMainViewport()
            CImGui.SetNextWindowPos(unsafe_load(viewport.WorkPos))
            CImGui.SetNextWindowSize(unsafe_load(viewport.WorkSize))
            CImGui.SetNextWindowFocus()
            CImGui.SetNextWindowBgAlpha(1)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, 0)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, (0, 0))
            CImGui.Begin("Save Plot", C_NULL, CImGui.ImGuiWindowFlags_NoTitleBar)
            l = length(uips)
            n = conf.DAQ.plotshowcol
            m = ceil(Int, l / n)
            n = m == 1 ? l : n
            height = (CImGui.GetWindowHeight() - (m - 1) * unsafe_load(imguistyle.ItemSpacing.y)) / m
            CImGui.Columns(n, C_NULL, false)
            for i in 1:m
                for j in 1:n
                    idx = (i - 1) * n + j
                    if idx <= l
                        Plot(uips[idx], "Save Plot$idx", (Cfloat(0), height))
                        CImGui.NextColumn()
                    end
                end
            end
            CImGui.End()
            CImGui.PopStyleVar(2)
            if count_fps == conf.DAQ.pick_fps[1]
                img = ImageMagick.load("screenshot:")
                vpos, vsize = unsafe_load(viewport.WorkPos), unsafe_load(viewport.WorkSize)
                conf.Basic.viewportenable || (vpos = CImGui.ImVec2(vpos.x + glfwwindowx, vpos.y + glfwwindowy))
                u, d = round(Int, vpos.y+1), round(Int, vpos.y + vsize.y-4)
                l, r = round(Int, vpos.x+1), round(Int, vpos.x + vsize.x-1)
                if length(size(img)) == 3
                    imgr, imgc, imgh = size(img)
                    img = reshape(img, imgr, imgh*imgc)
                end
                @trypass FileIO.save(path, img[u:d,l:r]) @error "[$(now())]\n图像保存错误！！！"
                savingimg = false
                count_fps = 0
                return 0
            end
        end
        return count_fps
    end

    global function saveimg_seting(setpath, setuips)
        empty!(uips)
        path = setpath
        for p in setuips push!(uips, deepcopy(p)) end
    end
end