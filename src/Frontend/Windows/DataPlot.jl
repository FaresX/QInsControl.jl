@kwdef mutable struct DataPlot
    name::String = ""
    showplot::Bool = false
    plot::QPlot = QPlot()
    dtpk::DataPicker = DataPicker()
    showdtpk::Bool = false
end

let
    copydataplot::DataPlot = DataPlot()
    global function edit(dtps::Vector{DataPlot}, datastr, datafloat::Dict{String,VecOrMat{Cdouble}}=Dict{String,VecOrMat{Cdouble}}())
        isdelplot = false
        delplot_i = 0
        isrename = false
        CImGui.BeginChild("DataPlots", (0, 0), true)
        for (i, dtp) in enumerate(dtps)
            if i == 1
                ccpos = CImGui.GetCursorScreenPos()
                CImGui.SetCursorScreenPos(ccpos.x, ccpos.y + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2)
            end
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            @c CImGui.Selectable(
                stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i, " ", dtp.name, "###plot", i), &dtp.showplot, 0,
                (Cfloat(0), CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y))
            )
            CImGui.PopStyleVar()
            i == length(dtps) || CImGui.Spacing()
            CImGui.Indent()
            if CImGui.BeginDragDropSource(0)
                @c CImGui.SetDragDropPayload("Swap DataPlot", &i, sizeof(Cint))
                CImGui.Text(stcstr(mlstr("Plot"), " ", i, " ", dtp.name))
                CImGui.EndDragDropSource()
            end
            if CImGui.BeginDragDropTarget()
                payload = CImGui.AcceptDragDropPayload("Swap DataPlot")
                if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                    payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                    if i != payload_i
                        insert!(dtps, i, dtps[payload_i])
                        deleteat!(dtps, payload_i < i ? payload_i : payload_i + 1)
                    end
                end
                CImGui.EndDragDropTarget()
            end
            CImGui.Unindent()
            if CImGui.BeginPopupContextItem()
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Select Data")))
                    dtp.showdtpk = true
                end
                CImGui.Separator()
                if dtp.showplot && CImGui.MenuItem(stcstr(MORESTYLE.Icons.Update, " ", mlstr("Update")))
                    dtp.dtpk.update = true
                    syncplotdata(dtp.plot, dtp.dtpk, datastr, datafloat)
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy")))
                    copydataplot = dtp
                end
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste"))) && insert!(dtps, i, copydataplot)
                CImGui.Separator()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Rename, " ", mlstr("Rename"))) && (isrename = true)
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete")))
                    isdelplot = true
                    delplot_i = i
                end
                CImGui.EndPopup()
            end
            isdelplot && delplot_i == i && CImGui.OpenPopup(stcstr("##delete plot", i))
            if YesNoDialog(
                stcstr("##delete plot", i),
                mlstr("Confirm delete?"),
                CImGui.ImGuiWindowFlags_AlwaysAutoResize
            )
                length(dtps) > 1 && (rmplot!(dtp.plot); deleteat!(dtps, i))
            end
            isrename && (CImGui.OpenPopup(stcstr("rename plot", i));
            isrename = false)
            if CImGui.BeginPopup(stcstr("rename plot", i))
                @c InputTextRSZ(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i, "###plot", i), &dtp.name)
                CImGui.EndPopup()
            end
        end
        CImGui.EndChild()
    end

    global pasteplot!(dtps::Vector{DataPlot}) = push!(dtps, copydataplot)
end

function showdtpks(
    dtps::Vector{DataPlot}, id,
    datastr::Dict{String,Vector{String}}, datafloat::Dict{String,VecOrMat{Cdouble}}=Dict{String,VecOrMat{Cdouble}}()
)
    for (i, dtp) in enumerate(dtps)
        if dtp.showdtpk
            datakeys = [sort(collect(keys(isempty(datastr) ? datafloat : datastr))); ""]
            datakeys == dtp.dtpk.datalist || (dtp.dtpk.datalist = datakeys)
            @c edit(dtp.dtpk, stcstr(id, "-", i), &dtp.showdtpk)
            syncplotdata(dtp.plot, dtp.dtpk, datastr, datafloat)
        end
    end
end

function renderplots(dtps::Vector{DataPlot}, id)
    for (i, dtp) in enumerate(dtps)
        dtp.showplot || continue
        ws = (
            dtp.plot.size[1] + 2unsafe_load(IMGUISTYLE.WindowPadding.x),
            dtp.plot.size[2] + 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight()
        )
        CImGui.SetNextWindowSize(ws, CImGui.ImGuiCond_Once)
        if @c CImGui.Begin(
            stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i, " ", dtp.name, "###", id, "-", i, "dtv"),
            &dtp.showplot
        )
            QPlot(dtp.plot, stcstr(id, "-", i))
        end
        CImGui.End()
    end
end

function update!(dtps::Vector{DataPlot}, datastr, datafloat::Dict{String,VecOrMat{Cdouble}}=Dict{String,VecOrMat{Cdouble}}(); all=false)
    for dtp in dtps
        (all || dtp.showplot) || continue
        dtp.dtpk.update = true
        syncplotdata(dtp.plot, dtp.dtpk, datastr, datafloat)
    end
end

function norealtime!(dtps::Vector{DataPlot})
    for dtp in dtps
        for dtss in dtp.dtpk.series
            dtss.isrealtime = false
        end
    end
    return dtps
end

function rmplots!(dtps::Vector{DataPlot})
    for dtp in dtps
        rmplot!(dtp.plot)
    end
end