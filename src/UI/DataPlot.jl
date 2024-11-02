@kwdef mutable struct Layout
    id::String = "Layout"
    showcol::Cint = 1
    idxing::Cint = 1
    labels::Vector{String} = ["default"]
    marks::Vector{String} = [""]
    states::Vector{Bool} = [false]
    selectedlabels::Vector{String} = []
    labeltoidx::Dict{String,Int} = Dict()
    selectedidx::Vector{Int} = []
end

labeltoidx!(lo::Layout) = lo.selectedidx = [lo.labeltoidx[lb] for lb in lo.selectedlabels]

function edit(
    rightclickmenu, lo::Layout, args...;
    action=(si, ti, args...) -> (),
    size=(Cfloat(0), CImGui.GetTextLineHeight() * ceil(Int, length(lo.labels) / lo.showcol)),
    showlayout=false,
    selectableflags=0,
    selectablesize=(0, 0)
)
    states_old = copy(lo.states)
    marks_old = copy(lo.marks)
    editlabels = @. lo.labels * " " * lo.marks * "###for rename" * lo.labels
    @c DragMultiSelectable(
        rightclickmenu, lo.id, editlabels, lo.states, lo.showcol, &lo.idxing, args...;
        action=action, size=size, border=true, selectableflags=selectableflags, selectablesize=selectablesize
    )
    if lo.states != states_old || lo.marks != marks_old
        editlabels = @. lo.labels * " " * lo.marks
        lo.selectedlabels = editlabels[lo.states]
        lo.labeltoidx = Dict(zip(editlabels, collect(eachindex(editlabels))))
        labeltoidx!(lo)
    end
    if showlayout
        CImGui.Separator()
        CImGui.Text(mlstr("layout"))
        selectedlabels_old = copy(lo.selectedlabels)
        DragMultiSelectable(() -> false, lo.id, lo.selectedlabels, trues(length(lo.selectedlabels)), lo.showcol, Ref(1))
        lo.selectedlabels == selectedlabels_old || labeltoidx!(lo)
    end
end

function update!(lo::Layout)
    editlabels = @. lo.labels * " " * lo.marks
    lo.selectedlabels = editlabels[lo.states]
    lo.labeltoidx = Dict(zip(editlabels, collect(eachindex(editlabels))))
    labeltoidx!(lo)
    lo.idxing = 1
end

function Base.deleteat!(lo::Layout, i)
    deleteat!(lo.labels, i)
    deleteat!(lo.marks, i)
    deleteat!(lo.states, i)
    update!(lo)
end

@kwdef mutable struct DataPlot
    dtpks::Vector{DataPicker} = [DataPicker()]
    showdtpks::Vector{Bool} = [false]
    plots::Vector{QPlot} = [QPlot()]
    layout::Layout = Layout()
    isdelplot::Bool = false
    delplot_i::Int = 0
end

function editmenu(dtp::DataPlot)
    ldtpks = length(dtp.dtpks)
    length(dtp.showdtpks) == ldtpks || resizebool!(dtp.showdtpks, ldtpks)
    dtp.layout.labels = [stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i) for i in eachindex(dtp.layout.labels)]
    edit(
        dtp.layout, dtp;
        action=insertplotbefore!, size=(0, 0),
        selectablesize=(Cfloat(0), CImGui.GetFrameHeight() - unsafe_load(IMGUISTYLE.ItemSpacing.y))
    ) do
        openright = CImGui.BeginPopupContextItem()
        if openright
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Select Data")))
                # if !dtp.layout.states[dtp.layout.idxing]
                #     for dtss in dtp.dtpks[dtp.layout.idxing].series
                #         dtss.isrealtime = false
                #     end
                # end
                dtp.showdtpks[dtp.layout.idxing] = true
            end
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")))
                dtp.isdelplot = true
                dtp.delplot_i = dtp.layout.idxing
            end
            markbuf = dtp.layout.marks[dtp.layout.idxing]
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c InputTextRSZ(dtp.layout.labels[dtp.layout.idxing], &markbuf)
            CImGui.PopItemWidth()
            dtp.layout.marks[dtp.layout.idxing] = markbuf
            CImGui.EndPopup()
        end
        return openright
    end
end

function newplot!(dtp::DataPlot)
    push!(dtp.layout.labels, string(length(dtp.layout.labels) + 1))
    push!(dtp.layout.marks, "")
    push!(dtp.layout.states, false)
    push!(dtp.plots, QPlot())
    push!(dtp.dtpks, DataPicker())
end

function insertplotbefore!(si, ti, dtp::DataPlot)
    insert!(dtp.layout.labels, ti, dtp.layout.labels[si])
    insert!(dtp.layout.marks, ti, dtp.layout.marks[si])
    insert!(dtp.layout.states, ti, dtp.layout.states[si])
    insert!(dtp.plots, ti, dtp.plots[si])
    insert!(dtp.dtpks, ti, dtp.dtpks[si])
    insert!(dtp.showdtpks, ti, dtp.showdtpks[si])
    deleteat!(dtp.layout.labels, si < ti ? si : si + 1)
    deleteat!(dtp.layout.marks, si < ti ? si : si + 1)
    deleteat!(dtp.layout.states, si < ti ? si : si + 1)
    deleteat!(dtp.plots, si < ti ? si : si + 1)
    deleteat!(dtp.dtpks, si < ti ? si : si + 1)
    deleteat!(dtp.showdtpks, si < ti ? si : si + 1)
end

function showdtpks(
    dtp::DataPlot,
    id,
    datastr::Dict{String,Vector{String}},
    datafloat::Dict{String,VecOrMat{Cdouble}}=Dict{String,VecOrMat{Cdouble}}()
)
    if CImGui.BeginPopupModal(stcstr("##no data", id), C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        CImGui.TextColored(MORESTYLE.Colors.LogError, stcstr("\n", mlstr("No data!"), "\n "))
        CImGui.Button(stcstr(mlstr("Confirm"), "##no data"), (180, 0)) && CImGui.CloseCurrentPopup()
        CImGui.EndPopup()
    end
    for (i, isshowdtpk) in enumerate(dtp.showdtpks)
        if isshowdtpk
            if isempty(datastr) && isempty(datafloat)
                CImGui.OpenPopup(stcstr("##no data", id))
                dtp.showdtpks[i] = false
                continue
            end
            dtpk = dtp.dtpks[i]
            datakeys = [sort(collect(keys(isempty(datastr) ? datafloat : datastr))); ""]
            datakeys == dtpk.datalist || (dtpk.datalist = datakeys)
            @c edit(dtpk, stcstr(id, "-", i), &isshowdtpk)
            dtp.showdtpks[i] = isshowdtpk
            syncplotdata(dtp.plots[i], dtpk, datastr, datafloat)
        end
    end

    dtp.isdelplot && ((CImGui.OpenPopup(stcstr("##delete plot", dtp.layout.idxing)));
    dtp.isdelplot = false)
    if YesNoDialog(
        stcstr("##delete plot", dtp.layout.idxing),
        mlstr("Confirm delete?"),
        CImGui.ImGuiWindowFlags_AlwaysAutoResize
    )
        if length(dtp.plots) > 1
            # delete!(FIGURES, dtp.plots[dtp.delplot_i].id)
            deleteat!(dtp.layout, dtp.delplot_i)
            deleteat!(dtp.plots, dtp.delplot_i)
            deleteat!(dtp.dtpks, dtp.delplot_i)
            deleteat!(dtp.showdtpks, dtp.delplot_i)
        end
    end
end

function renderplots(dtp::DataPlot, id)
    for (i, idx) in enumerate(dtp.layout.selectedidx)
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        isopenplot = dtp.layout.states[idx]
        if @c CImGui.Begin(
            stcstr(
                MORESTYLE.Icons.Plot, " ",
                mlstr("Plot"), " ",
                idx, " ", dtp.layout.marks[idx],
                "###", id, "-", idx, "dtv"
            ),
            &isopenplot
        )
            QPlot(dtp.plots[idx], stcstr(id, "-", idx))
        end
        CImGui.End()
        dtp.layout.states[idx] = isopenplot
        isopenplot || (deleteat!(dtp.layout.selectedidx, i); deleteat!(dtp.layout.selectedlabels, i))
    end
end

function update!(dtp::DataPlot, datastr, datafloat::Dict{String,VecOrMat{Cdouble}}=Dict{String,VecOrMat{Cdouble}}())
    for (i, dtpk) in enumerate(dtp.dtpks)
        dtpk.update = true
        syncplotdata(dtp.plots[i], dtpk, datastr, datafloat)
    end
end

function norealtime!(dtp::DataPlot)
    for dtpk in dtp.dtpks
        for dtss in dtpk.series
            dtss.isrealtime = false
        end
    end
    return dtp
end

function rmplots!(dtp::DataPlot)
    for plt in dtp.plots
        rmplot!(plt)
    end
end