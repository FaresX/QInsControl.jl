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
    rightclickmenu,
    lo::Layout,
    size=(Cfloat(0), CImGui.GetTextLineHeight() * ceil(Int, length(lo.labels) / lo.showcol));
    showlayout=false,
    selectableflags=0,
    selectablesize=(0, 0)
)
    states_old = copy(lo.states)
    marks_old = copy(lo.marks)
    editlabels = @. lo.labels * " " * lo.marks * "###for rename" * lo.labels
    @c MultiSelectable(
        rightclickmenu, lo.id, editlabels, lo.states, lo.showcol, &lo.idxing, size;
        border=true, selectableflags=selectableflags, selectablesize=selectablesize
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
        DragMultiSelectable(
            () -> false,
            lo.id,
            lo.selectedlabels,
            trues(length(lo.selectedlabels)),
            lo.showcol
        )
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
    linkidx::Vector{Cint} = [0]
    plots::Vector{Plot} = [Plot()]
    layout::Layout = Layout()
    isdelplot::Bool = false
    delplot_i::Int = 0
end

function editmenu(dtp::DataPlot)
    ldtpks = length(dtp.dtpks)
    length(dtp.showdtpks) == ldtpks || resize!(dtp.showdtpks, ldtpks)
    llink = length(dtp.linkidx)
    llink == ldtpks || (resize!(dtp.linkidx, ldtpks); llink < ldtpks && (dtp.linkidx[llink+1:end] .= 0))
    dtp.layout.labels = [stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot"), " ", i) for i in eachindex(dtp.layout.labels)]
    edit(
        dtp.layout, (0, 0);
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
            CImGui.Text(mlstr("Link to"))
            CImGui.SameLine()
            linkedidx = dtp.linkidx[dtp.layout.idxing]
            CImGui.PushItemWidth(4CImGui.GetFontSize())
            @c CImGui.DragInt(
                "##Link to", &linkedidx, 1, 0, length(dtp.dtpks), "%d",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            CImGui.PopItemWidth()
            dtp.linkidx[dtp.layout.idxing] = linkedidx
            CImGui.EndPopup()
        end
        # dealwithlinkidx(dtp)
        return openright
    end
end

function newplot!(dtp::DataPlot)
    push!(dtp.layout.labels, string(length(dtp.layout.labels) + 1))
    push!(dtp.layout.marks, "")
    push!(dtp.layout.states, false)
    push!(dtp.plots, Plot())
    push!(dtp.dtpks, DataPicker())
    push!(dtp.linkidx, 0)
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
            if dtp.linkidx[i] == 0
                dtpk = dtp.dtpks[i]
                datakeys = [sort(collect(keys(isempty(datastr) ? datafloat : datastr))); ""]
                datakeys == dtpk.datalist || (dtpk.datalist = datakeys)
                @c edit(dtpk, stcstr(id, "-", i), &isshowdtpk)
                dtp.showdtpks[i] = isshowdtpk
                syncplotdata(dtp.plots[i], dtpk, datastr, datafloat)
            else
                dtpk = dtp.dtpks[i]
                pltlink = dtp.plots[dtp.linkidx[i]]
                dtpklink = dtp.dtpks[dtp.linkidx[i]]
                xkeys = "x" .* string.(1:length(pltlink.series))
                ykeys = "y" .* string.(1:length(pltlink.series))
                zkeys = "z" .* string.(1:length(pltlink.series))
                datakeys = [xkeys; ykeys; zkeys; ""]
                datakeys == dtpk.datalist || (dtpk.datalist = datakeys)
                @c edit(dtpk, stcstr(id, "-", i), &isshowdtpk)
                dtp.showdtpks[i] = isshowdtpk
                if true in [
                    dtss.update ||
                    (dtss.isrealtime && waittime(stcstr("DataPicker-link", dtp.plots[i].id, "-", j), dtss.refreshrate))
                    for (j, dtss) in enumerate(dtpk.series)
                ]
                    linkeddata = Dict{String,VecOrMat{Cdouble}}()
                    for (j, pss) in enumerate(pltlink.series)
                        push!(linkeddata, "x$j" => copy(pss.x))
                        push!(linkeddata, "y$j" => copy(pss.y))
                        push!(linkeddata, "z$j" => copy(pss.z))
                        dtpklink.series[j].hflipz && reverse!(linkeddata["z$j"], dims=1)
                        dtpklink.series[j].vflipz && reverse!(linkeddata["z$j"], dims=2)
                        linkeddata["z$j"] = transpose(linkeddata["z$j"]) |> collect
                    end
                    syncplotdata(dtp.plots[i], dtpk, Dict{String,Vector{String}}(), linkeddata)
                end
            end
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
            deleteat!(dtp.layout, dtp.delplot_i)
            deleteat!(dtp.plots, dtp.delplot_i)
            deleteat!(dtp.dtpks, dtp.delplot_i)
            deleteat!(dtp.showdtpks, dtp.delplot_i)
            deleteat!(dtp.linkidx, dtp.delplot_i)
        end
    end
end

function renderplots(dtp::DataPlot, id)
    for (i, idx) in enumerate(dtp.layout.selectedidx)
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        isopenplot = dtp.layout.states[idx]
        @c CImGui.Begin(
            stcstr(
                MORESTYLE.Icons.Plot, " ",
                mlstr("Plot"), " ",
                idx, " ", dtp.layout.marks[idx],
                "###", id, "-", idx, "dtv"
            ),
            &isopenplot
        )
        Plot(dtp.plots[idx], stcstr(id, "-", idx))
        CImGui.End()
        dtp.layout.states[idx] = isopenplot
        isopenplot || (deleteat!(dtp.layout.selectedidx, i); deleteat!(dtp.layout.selectedlabels, i))
    end
end

function Base.empty!(dtp::DataPlot)
    for plt in dtp.plots
        empty!(plt.xaxes)
        empty!(plt.yaxes)
        empty!(plt.zaxes)
        for pss in plt.series
            empty!(pss.x)
            empty!(pss.y)
            pss.z = Matrix{eltype(pss.z)}(undef, 0, 0)
        end
    end
    return dtp
end

function update!(dtp::DataPlot, datastr, datafloat::Dict{String,VecOrMat{Cdouble}}=Dict{String,VecOrMat{Cdouble}}())
    for (i, dtpk) in enumerate(dtp.dtpks)
        dtpk.update = true
        syncplotdata(dtp.plots[i], dtpk, datastr, datafloat; quiet=true, force=true)
    end
end