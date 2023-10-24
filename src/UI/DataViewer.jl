mutable struct DataViewer
    noclose::Bool
    p_open::Bool
    show_dtpickers::Vector{Bool}
    firsttime::Bool
    dtpickers::Vector{DataPicker}
    uiplots::Vector{UIPlot}
    layout::Layout
    data::Dict
end
DataViewer() = DataViewer(true, true, [false], true, [DataPicker()], [UIPlot()], Layout(), Dict())

let
    isdelplot::Bool = false
    delplot_i::Int = 0
    global function edit(dtviewer::DataViewer, filetree::FileTree, isrename::Dict{String,Bool}, id)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
        if @c CImGui.Begin(
            if filetree.rootpath_bnm == ""
                stcstr(MORESTYLE.Icons.OpenFile, "  ", mlstr("Data Browse"), "###dtv", id)
            else
                stcstr(MORESTYLE.Icons.OpenFolder, "  ", mlstr("Data Browse"), "###dtv", id)
            end,
            &dtviewer.p_open
        )
            CImGui.Columns(2)
            dtviewer.firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.3); dtviewer.firsttime = false)

            CImGui.BeginChild("DataViewer-FileTree")
            oldfile = filetree.selectedpath[]
            InputTextRSZ(stcstr(mlstr("Filter"), "##", id), filetree.filter)
            edit(filetree, isrename)
            if filetree.selectedpath[] != oldfile
                if split(basename(filetree.selectedpath[]), '.')[end] in ["qdt", "cfg"]
                    dtviewer.data = @trypasse load(filetree.selectedpath[]) Dict()
                    datakeys = keys(dtviewer.data)
                    "uiplots" in datakeys && (dtviewer.uiplots = @trypasse dtviewer.data["uiplots"] dtviewer.uiplot)
                    "datapickers" in datakeys && (dtviewer.dtpickers = @trypasse dtviewer.data["datapickers"] dtviewer.dtpicker)
                    "plotlayout" in datakeys && (dtviewer.layout = @trypasse dtviewer.data["plotlayout"] dtviewer.layout)
                    if !isempty(dtviewer.data) && haskey(dtviewer.data, "circuit")
                        for (_, node) in dtviewer.data["circuit"].nodes
                            if node isa SampleBaseNode
                                try
                                    imgsize = size(node.imgr.image)
                                    node.imgr.id = ImGui_ImplOpenGL3_CreateImageTexture(imgsize...)
                                    ImGui_ImplOpenGL3_UpdateImageTexture(node.imgr.id, node.imgr.image, imgsize...)
                                catch e
                                    @error "[$(now())]\n$(mlstr("loading image failed!!!"))" exception = e
                                end
                            end
                        end
                    end
                else
                    dtviewer.data = Dict()
                end
            end
            CImGui.EndChild()
            filetree.rootpath_bnm != "" && !CImGui.IsAnyItemHovered() && CImGui.OpenPopupOnItemClick("File Menu")
            if CImGui.BeginPopup("File Menu")
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Refresh")))
                    filetree.filetrees = FolderFileTree(
                        filetree.rootpath,
                        filetree.selectedpath,
                        filetree.filter
                    ).filetrees
                end
                CImGui.EndPopup()
            end
            CImGui.NextColumn() #文件列表

            CImGui.BeginChild("DataViewer")
            if CImGui.BeginTabBar("Data Viewer")
                if CImGui.BeginTabItem(mlstr("Instrument Status"))
                    if true in occursin.(r"instrbufferviewers/.*", keys(dtviewer.data))
                        if CImGui.BeginPopupContextItem()
                            CImGui.Text(mlstr("display columns"))
                            CImGui.SameLine()
                            CImGui.PushItemWidth(2CImGui.GetFontSize())
                            @c CImGui.DragInt(
                                "##InsBuf col num",
                                &CONF.InsBuf.showcol,
                                1, 1, 6, "%d",
                                CImGui.ImGuiSliderFlags_AlwaysClamp
                            )
                            CImGui.PopItemWidth()
                            CImGui.EndPopup()
                        end
                        insbufkeys::Vector{String} = sort(
                            [key for key in keys(dtviewer.data) if occursin(r"instrbufferviewers/.*", key)]
                        )
                        CImGui.BeginChild("instrument status")
                        for insbuf in insbufkeys
                            logtime::String = split(insbuf, "/")[2]
                            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, MORESTYLE.Colors.LogInfo)
                            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.LogWarn)
                            CImGui.Button(logtime, (-0.1, 0.0))
                            CImGui.PopStyleColor(2)
                            CImGui.PushID(logtime)
                            view(dtviewer.data[insbuf])
                            CImGui.PopID()
                        end
                        CImGui.EndChild()
                    else
                        CImGui.Text(mlstr("data not loaded or data format not supported!"))
                    end
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem(mlstr("Script"))
                    if haskey(dtviewer.data, "daqtask")
                        CImGui.PushID(id)
                        view(dtviewer.data["daqtask"])
                        CImGui.PopID()
                    else
                        CImGui.Text(mlstr("data not loaded or data format not supported!"))
                    end
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem(mlstr("Circuit"))
                    if haskey(dtviewer.data, "circuit")
                        CImGui.PushID(id)
                        view(dtviewer.data["circuit"], stcstr("Nodes Editor", id))
                        CImGui.PopID()
                    else
                        CImGui.Text(mlstr("data not loaded or data format not supported!"))
                    end
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem(mlstr("Data"))
                    if haskey(dtviewer.data, "data")
                        if CImGui.BeginPopupContextItem()
                            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Export")))
                                exportpath = save_file(; filterlist="csv")
                                if exportpath != ""
                                    try
                                        exportdata(
                                            exportpath,
                                            dtviewer.data["data"],
                                            Val(Symbol(split(basename(exportpath), '.')[end]))
                                        )
                                    catch e
                                        @error "[$(now())]\n$(mlstr("exporting data failed!!!"))" exception = e
                                    end
                                end
                            end
                            CImGui.EndPopup()
                        end
                        CImGui.BeginChild("ShowData")
                        showdata(dtviewer.data["data"], id)
                        CImGui.EndChild()
                    else
                        CImGui.Text(mlstr("data not loaded or data format not supported!"))
                    end
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem(mlstr("Plots"))
                    if length(dtviewer.show_dtpickers) != length(dtviewer.dtpickers)
                        resize!(dtviewer.show_dtpickers, length(dtviewer.dtpickers))
                    end
                    if haskey(dtviewer.data, "data")
                        if CONF.DAQ.freelayout
                            if CImGui.Button(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")))
                                saveqdt(dtviewer, filetree)
                            end
                            CImGui.SameLine()
                            editplotlayout(dtviewer)
                        else
                            if CImGui.BeginPopupContextItem("select data to plot")
                                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Plot")))
                                    editplotlayout(dtviewer)
                                    CImGui.EndMenu()
                                end
                                CImGui.Separator()
                                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")))
                                    saveqdt(dtviewer, filetree)
                                end
                                CImGui.EndPopup()
                            end
                        end
                        renderplots(dtviewer, id)
                    else
                        CImGui.Text(mlstr("data not loaded or data format not supported!"))
                    end
                    CImGui.EndTabItem()
                end
                CImGui.PushStyleColor(
                    CImGui.ImGuiCol_Tab,
                    if haskey(dtviewer.data, "revision")
                        MORESTYLE.Colors.HighlightText
                    else
                        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Tab)
                    end
                )
                if CImGui.BeginTabItem(mlstr("Revision"))
                    if haskey(dtviewer.data, "daqtask") | haskey(dtviewer.data, "circuit")
                        if haskey(dtviewer.data, "revision")
                            if CImGui.BeginPopupContextItem()
                                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")))
                                    saveqdt(dtviewer, filetree) 
                                end
                                CImGui.EndPopup()
                            end
                            CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("Description"))
                            desp = dtviewer.data["revision"]["description"]
                            y = (1 + length(findall("\n", desp))) * CImGui.GetTextLineHeight() +
                                2unsafe_load(IMGUISTYLE.FramePadding.y)
                            @c InputTextMultilineRSZ("##Description", &desp, (Cfloat(-1), y))
                            dtviewer.data["revision"]["description"] = desp
                            edit(dtviewer.data["revision"]["circuit"])
                        else
                            if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, "##new revision"), (-1, -1))
                                push!(
                                    dtviewer.data,
                                    "revision" => Dict(
                                        "description" => "",
                                        "circuit" => deepcopy(dtviewer.data["circuit"])
                                    )
                                )
                            end
                        end
                    else
                        CImGui.Text(mlstr("data not loaded or data format not supported!"))
                    end
                    CImGui.EndTabItem()
                end
                CImGui.PopStyleColor()
                CImGui.EndTabBar()
            end
            CImGui.EndChild()
            CImGui.NextColumn() #查看菜单

            if CImGui.BeginPopupModal("no data in file", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                CImGui.TextColored(MORESTYLE.logerrorcol, mlstr("no data in the file!"))
                CImGui.Button(stcstr(mlstr("Confirm"), "##no data"), (180, 0)) && CImGui.CloseCurrentPopup()
                CImGui.EndPopup()
            end
            for (i, isshow_dtpk) in enumerate(dtviewer.show_dtpickers)
                if isshow_dtpk
                    if haskey(dtviewer.data, "data")
                        dtpk = dtviewer.dtpickers[i]
                        datakeys::Set{String} = keys(dtviewer.data["data"])
                        if datakeys != Set(dtpk.datalist)
                            dtpk.datalist = collect(datakeys)
                            dtpk.y = falses(length(datakeys))
                            dtpk.w = falses(length(datakeys))
                        end
                        isupdate = @c edit(dtpk, stcstr(id, "-", i), &isshow_dtpk)
                        dtviewer.show_dtpickers[i] = isshow_dtpk
                        if isupdate || (dtpk.isrealtime && waittime(
                            stcstr("DataViewer", stcstr(id, "-", i), "-DataPicker", i),
                            dtpk.refreshrate
                        )
                        )
                            syncplotdata(dtviewer.uiplots[i], dtpk, dtviewer.data["data"])
                        end
                    else
                        CImGui.OpenPopup("no data in file")
                        dtviewer.show_dtpickers .= false
                    end
                end
            end

            isdelplot && ((CImGui.OpenPopup(stcstr("##delete plot", dtviewer.layout.idxing)));
            isdelplot = false)
            if YesNoDialog(
                stcstr("##delete plot", dtviewer.layout.idxing),
                mlstr("Confirm delete?"),
                CImGui.ImGuiWindowFlags_AlwaysAutoResize
            )
                if length(dtviewer.uiplots) > 1
                    deleteat!(dtviewer.layout, delplot_i)
                    deleteat!(dtviewer.uiplots, delplot_i)
                    deleteat!(dtviewer.dtpickers, delplot_i)
                    deleteat!(dtviewer.show_dtpickers, delplot_i)
                end
            end
        end
        CImGui.End()
    end

    function saveqdt(dtviewer::DataViewer, filetree::FileTree)
        if !isempty(dtviewer.data)
            jldopen(filetree.selectedpath[], "w") do file
                for key in keys(dtviewer.data)
                    file[key] = dtviewer.data[key]
                end
            end
        end
    end

    function renderplots(dtviewer::DataViewer, id)
        if CONF.DAQ.freelayout
            for (i, idx) in enumerate(dtviewer.layout.selectedidx)
                CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
                isopenplot = dtviewer.layout.states[idx]
                @c CImGui.Begin(
                    stcstr(
                        MORESTYLE.Icons.Plot, " ",
                        mlstr("Plot"), " ",
                        idx, " ", dtviewer.layout.marks[idx],
                        "###", id, "-", idx, "dtv"
                    ),
                    &isopenplot
                )
                Plot(dtviewer.uiplots[idx], stcstr("plot file", id, "-", idx))
                CImGui.End()
                dtviewer.layout.states[idx] = isopenplot
                isopenplot || (deleteat!(dtviewer.layout.selectedidx, i); deleteat!(dtviewer.layout.selectedlabels, i))
            end
        else
            CImGui.BeginChild("plot")
            if isempty(dtviewer.layout.selectedidx)
                Plot(dtviewer.uiplots[1], stcstr("plot file", id, "-", 1))
            else
                totalsz = CImGui.GetContentRegionAvail()
                l = length(dtviewer.layout.selectedidx)
                n = CONF.DAQ.plotshowcol
                m = ceil(Int, l / n)
                n = m == 1 ? l : n
                height = (CImGui.GetContentRegionAvail().y - (m - 1) * unsafe_load(IMGUISTYLE.ItemSpacing.y)) / m
                for i in 1:m
                    CImGui.BeginChild(stcstr("plotrow", i), (Cfloat(0), height))
                    CImGui.Columns(n)
                    for j in 1:n
                        idx = (i - 1) * n + j
                        if idx <= l
                            index = dtviewer.layout.selectedidx[idx]
                            Plot(dtviewer.uiplots[index], stcstr("plot file", id, "-", index), (Cfloat(0), height))
                            CImGui.NextColumn()
                        end
                    end
                    CImGui.EndChild()
                end
            end
            CImGui.EndChild()
        end
    end

    function editplotlayout(dtviewer::DataViewer)
        if !CONF.DAQ.freelayout
            CImGui.Text(mlstr("plot columns"))
            CImGui.SameLine()
            CImGui.PushItemWidth(2CImGui.GetFontSize())
            @c CImGui.DragInt(
                "##plot columns",
                &CONF.DAQ.plotshowcol,
                1, 1, 6, "%d",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            CImGui.PopItemWidth()
            CImGui.SameLine()
        end
        CImGui.PushID("add new plot")
        if CImGui.Button(
            if CONF.DAQ.freelayout
                stcstr(mlstr("new plot"), " ", MORESTYLE.Icons.NewFile)
            else
                MORESTYLE.Icons.NewFile
            end
        )
            push!(dtviewer.layout.labels, string(length(dtviewer.layout.labels) + 1))
            push!(dtviewer.layout.marks, "")
            push!(dtviewer.layout.states, false)
            push!(dtviewer.uiplots, UIPlot())
            push!(dtviewer.dtpickers, DataPicker())
        end
        CImGui.PopID()

        dtviewer.layout.showcol = CONF.DAQ.freelayout ? 1 : CONF.DAQ.plotshowcol
        dtviewer.layout.labels = MORESTYLE.Icons.Plot * " " .*
                                 string.(collect(eachindex(dtviewer.layout.labels)))
        maxplotmarkidx = argmax(lengthpr.(dtviewer.layout.marks))
        maxploticonwidth = CONF.DAQ.freelayout ? Cfloat(0) : dtviewer.layout.showcol * CImGui.CalcTextSize(
            stcstr(
                MORESTYLE.Icons.Plot,
                " ",
                dtviewer.layout.labels[maxplotmarkidx],
                dtviewer.layout.marks[maxplotmarkidx]
            )
        ).x
        edit(
            dtviewer.layout,
            (
                maxploticonwidth,
                CImGui.GetFrameHeight() * ceil(Int, length(dtviewer.layout.labels) /
                                                    dtviewer.layout.showcol)
            );
            showlayout=!CONF.DAQ.freelayout
        ) do
            openright = CImGui.BeginPopupContextItem()
            if openright
                if CImGui.MenuItem(
                    stcstr(MORESTYLE.Icons.Plot, " ", mlstr("Select Data"))
                ) && dtviewer.layout.states[dtviewer.layout.idxing]
                    dtviewer.show_dtpickers[dtviewer.layout.idxing] = true
                end
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete")))
                    isdelplot = true
                    delplot_i = dtviewer.layout.idxing
                end
                markbuf = dtviewer.layout.marks[dtviewer.layout.idxing]
                CImGui.PushItemWidth(6CImGui.GetFontSize())
                @c InputTextRSZ(dtviewer.layout.labels[dtviewer.layout.idxing], &markbuf)
                CImGui.PopItemWidth()
                dtviewer.layout.marks[dtviewer.layout.idxing] = markbuf
                CImGui.EndPopup()
            end
            return openright
        end
    end
end

let
    flags::Cint = 0
    flags |= CImGui.ImGuiTableFlags_Resizable
    flags |= CImGui.ImGuiTableFlags_Reorderable
    # flags |= CImGui.ImGuiTableFlags_Sortable
    flags |= CImGui.ImGuiTableFlags_Hideable
    # flags |= CImGui.ImGuiTableFlags_BordersOuter
    flags |= CImGui.ImGuiTableFlags_BordersInnerV
    flags |= CImGui.ImGuiTableFlags_RowBg
    pagei::Dict = Dict()
    global function showdata(data, id)
        lmax = max_with_empty(length.(values(data)))
        haskey(pagei, id) || push!(pagei, id => 1)
        pages = ceil(Int, lmax / CONF.DtViewer.showdatarow)
        pagei[id] > pages && (pagei[id] = 1)
        showpagewidth = CImGui.CalcTextSize(stcstr(" ", pagei[id], " / ", pages, " ")).x
        contentwidth = CImGui.GetContentRegionAvailWidth()
        CImGui.PushID(id)
        if CImGui.Button(ICONS.ICON_CARET_LEFT, ((contentwidth - showpagewidth) / 2, Cfloat(0)))
            pagei[id] > 1 && (pagei[id] -= 1)
        end
        CImGui.SameLine()
        CImGui.Text(stcstr(" ", pagei[id], " / ", pages, " "))
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && CImGui.OpenPopup(stcstr("selectpage", id))
        if CImGui.BeginPopup(stcstr("selectpage", id))
            pagei_buf::Cint = pagei[id]
            @c CImGui.DragInt(
                stcstr("##selectpage", id),
                &pagei_buf,
                1, 1, lmax, "%d",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            pagei[id] = pagei_buf
            CImGui.EndPopup()
        end
        CImGui.SameLine()
        if CImGui.Button(ICONS.ICON_CARET_RIGHT, ((contentwidth - showpagewidth) / 2, Cfloat(0)))
            pagei[id] < pages && (pagei[id] += 1)
        end
        CImGui.BeginChild("showdatatable")
        if CImGui.BeginTable("showdata", length(data), flags)
            for key in keys(data)
                CImGui.TableSetupColumn(key)
            end
            CImGui.TableHeadersRow()

            startpage = (pagei[id] - 1) * CONF.DtViewer.showdatarow + 1
            stoppage = pagei[id] * CONF.DtViewer.showdatarow
            for i in startpage:(pagei[id] == pages ? lmax : stoppage)
                CImGui.TableNextRow()
                for (_, val) in data
                    CImGui.TableNextColumn()
                    CImGui.Text(i > length(val) ? "" : val[i])
                end
            end
            CImGui.EndTable()
        end
        CImGui.EndChild()
        CImGui.PopID()
    end
end

function exportdata(path::AbstractString, data::Dict{String,Vector{String}}, ::Val{:csv})
    maxl = max_with_empty(length.(values(data)))
    data_cols = length(data)
    buf = fill("", maxl + 1, data_cols)
    @views for (i, kv) in enumerate(data)
        buf[1, i] = kv.first
        buf[2:length(kv.second)+1, i] = kv.second
    end
    open(path, "w") do file
        for row in eachrow(buf)
            println(file, join(row, ','))
        end
    end
end

exportdata(path::AbstractString, data::Dict{String,Vector{String}}, _) = exportdata(path, data, Val(:csv))