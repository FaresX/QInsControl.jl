mutable struct DataViewer
    noclose::Bool
    p_open::Bool
    show_dtpicker::Bool
    show_dtpicker_i::Int
    firsttime::Bool
    dtpickers::Vector{DataPicker}
    uiplots::Vector{UIPlot}
    layout::Layout
    data::Dict
end
DataViewer() = DataViewer(true, true, false, 1, true, [DataPicker()], [UIPlot()], Layout(), Dict())

let
    window_ids::Dict{Int,String} = Dict()
    isdelplot::Bool = false
    delplot_i::Int = 0
    global function edit(dtviewer::DataViewer, filetree::FileTree, isrename::Dict{String,Bool}, id)
        # CImGui.SetNextWindowPos((100, 100), CImGui.ImGuiCond_Once)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
        if !haskey(window_ids, id)
            if filetree.rootpath_bnm == ""
                push!(window_ids, id => morestyle.Icons.OpenFile * "  数据浏览##$id")
            else
                push!(window_ids, id => morestyle.Icons.OpenFolder * "  数据浏览##$id")
            end
        end
        if @c CImGui.Begin(window_ids[id], &dtviewer.p_open)
            CImGui.Columns(2)
            dtviewer.firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.3); dtviewer.firsttime = false)

            CImGui.BeginChild("DataViewer-FileTree")
            oldfile = filetree.selectedpath[]
            edit(filetree, isrename)
            if filetree.selectedpath[] != oldfile && split(basename(filetree.selectedpath[]), '.')[end] in ["qdt", "cfg"]
                dtviewer.data = @trypasse load(filetree.selectedpath[]) Dict()
                datakeys = keys(dtviewer.data)
                "uiplots" in datakeys && (dtviewer.uiplots = @trypasse dtviewer.data["uiplots"] dtviewer.uiplot)
                "datapickers" in datakeys && (dtviewer.dtpickers = @trypasse dtviewer.data["datapickers"] dtviewer.dtpicker)
                "plotlayout" in datakeys && (dtviewer.layout = @trypasse dtviewer.data["plotlayout"] dtviewer.layout)
            end
            CImGui.EndChild()
            CImGui.NextColumn() #文件列表

            CImGui.BeginChild("DataViewer")
            if CImGui.BeginTabBar("Data_Viewer")
                if CImGui.BeginTabItem("仪器状态")
                    if CImGui.BeginPopupContextItem()
                        CImGui.Text("显示列数")
                        CImGui.SameLine()
                        CImGui.PushItemWidth(2CImGui.GetFontSize())
                        @c CImGui.DragInt(
                            "##InsBuf列数",
                            &conf.InsBuf.showcol,
                            1, 1, 6, "%d",
                            CImGui.ImGuiSliderFlags_AlwaysClamp
                        )
                        CImGui.PopItemWidth()
                        CImGui.EndPopup()
                    end
                    CImGui.BeginChild("仪器状态")
                    if !isempty(dtviewer.data) && true in occursin.(r"instrbufferviewers/.*", keys(dtviewer.data))
                        insbufkeys::Vector{String} = sort(
                            [key for key in keys(dtviewer.data) if occursin(r"instrbufferviewers/.*", key)]
                        )
                        for insbuf in insbufkeys
                            logtime::String = split(insbuf, "/")[2]
                            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, morestyle.Colors.LogInfo)
                            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, morestyle.Colors.LogWarn)
                            CImGui.Button(logtime, (-0.1, 0.0))
                            CImGui.PopStyleColor(2)
                            CImGui.PushID(logtime)
                            view(dtviewer.data[insbuf])
                            CImGui.PopID()
                        end
                    else
                        CImGui.Text("未加载数据或数据格式不支持！")
                    end
                    CImGui.EndChild()
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem("配置")
                    if !isempty(dtviewer.data) && haskey(dtviewer.data, "daqtask")
                        CImGui.PushID(id)
                        view(dtviewer.data["daqtask"])
                        CImGui.PopID()
                    else
                        CImGui.Text("未加载数据或数据格式不支持！")
                    end
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem("电路")
                    if !isempty(dtviewer.data) && haskey(dtviewer.data, "circuit")
                        CImGui.PushID(id)
                        view(dtviewer.data["circuit"])
                        CImGui.PopID()
                    else
                        CImGui.Text("未加载数据或数据格式不支持！")
                    end
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem("数据")
                    if !isempty(dtviewer.data) && haskey(dtviewer.data, "data")
                        CImGui.BeginChild("ShowData")
                        showdata(dtviewer.data["data"])
                        CImGui.EndChild()
                    else
                        CImGui.Text("未加载数据或数据格式不支持！")
                    end
                    CImGui.EndTabItem()
                end
                if CImGui.BeginTabItem("绘图")
                    if haskey(dtviewer.data, "data")
                        if CImGui.BeginPopupContextItem("选择数据查看")
                            if CImGui.BeginMenu(morestyle.Icons.SelectData * " 绘图")
                                CImGui.Text("绘图列数")
                                CImGui.SameLine()
                                CImGui.PushItemWidth(2CImGui.GetFontSize())
                                @c CImGui.DragInt(
                                    "##绘图列数",
                                    &conf.DAQ.plotshowcol,
                                    1, 1, 6, "%d",
                                    CImGui.ImGuiSliderFlags_AlwaysClamp
                                )
                                CImGui.PopItemWidth()
                                CImGui.SameLine()
                                CImGui.PushID("add new plot")
                                if CImGui.Button(morestyle.Icons.NewFile)
                                    push!(dtviewer.layout.labels, string(length(dtviewer.layout.labels) + 1))
                                    push!(dtviewer.layout.marks, "")
                                    push!(dtviewer.layout.states, false)
                                    push!(dtviewer.uiplots, UIPlot())
                                    push!(dtviewer.dtpickers, DataPicker())
                                end
                                CImGui.PopID()

                                dtviewer.layout.showcol = conf.DAQ.plotshowcol
                                dtviewer.layout.labels = morestyle.Icons.SelectData * " " .*
                                                         string.(collect(eachindex(dtviewer.layout.labels)))
                                maxplotmarkidx = argmax(lengthpr.(dtviewer.layout.marks))
                                maxploticonwidth = dtviewer.layout.showcol * CImGui.CalcTextSize(
                                    string(
                                        morestyle.Icons.SelectData,
                                        " ",
                                        dtviewer.layout.labels[maxplotmarkidx],
                                        dtviewer.layout.marks[maxplotmarkidx]
                                    )
                                ).x
                                edit(
                                    dtviewer.layout,
                                    (
                                        maxploticonwidth,
                                        CImGui.GetFrameHeight() * ceil(Int, length(dtviewer.layout.labels) / dtviewer.layout.showcol)
                                    )
                                ) do
                                    openright = CImGui.BeginPopupContextItem()
                                    if openright
                                        if CImGui.MenuItem("选择数据") && dtviewer.layout.states[dtviewer.layout.idxing]
                                            dtviewer.show_dtpicker = true
                                            dtviewer.show_dtpicker_i = dtviewer.layout.idxing
                                        end
                                        if CImGui.MenuItem(morestyle.Icons.CloseFile * " 删除")
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
                                CImGui.EndMenu()
                            end
                            # CImGui.MenuItem(morestyle.Icons.SelectData * " 选择数据") && (dtviewer.show_dtpicker = true)
                            CImGui.Separator()
                            if CImGui.MenuItem(morestyle.Icons.SaveButton * " 保存")
                                if !isempty(dtviewer.data)
                                    jldopen(filetree.selectedpath[], "w") do file
                                        for key in keys(dtviewer.data)
                                            file[key] = dtviewer.data[key]
                                        end
                                    end
                                end
                            end
                            CImGui.EndPopup()
                        end
                    end
                    isdelplot && ((CImGui.OpenPopup("##删除绘图$(dtviewer.layout.idxing)"));
                    isdelplot = false)
                    if YesNoDialog("##删除绘图$(dtviewer.layout.idxing)", "确认删除？", CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                        if length(dtviewer.uiplots) > 1
                            deleteat!(dtviewer.layout.labels, delplot_i)
                            deleteat!(dtviewer.layout.marks, delplot_i)
                            deleteat!(dtviewer.layout.states, delplot_i)
                            deleteat!(dtviewer.uiplots, delplot_i)
                            deleteat!(dtviewer.dtpickers, delplot_i)
                            update!(dtviewer.layout)
                        end
                    end
                    CImGui.BeginChild("绘图")
                    if isempty(dtviewer.layout.selectedidx)
                        Plot(dtviewer.uiplots[1], "文件绘图1")
                    else
                        totalsz = CImGui.GetContentRegionAvail()
                        l = length(dtviewer.layout.selectedidx)
                        n = conf.DAQ.plotshowcol
                        m = ceil(Int, l / n)
                        n = m == 1 ? l : n
                        height = (CImGui.GetContentRegionAvail().y - (m - 1) * unsafe_load(imguistyle.ItemSpacing.y)) / m
                        CImGui.Columns(n)
                        for i in 1:m
                            for j in 1:n
                                idx = (i - 1) * n + j
                                if idx <= l
                                    index = dtviewer.layout.selectedidx[idx]
                                    Plot(
                                        dtviewer.uiplots[index],
                                        "文件绘图$(filetree.selectedpath[])-$index",
                                        (Cfloat(0), height)
                                    )
                                    CImGui.NextColumn()
                                end
                            end
                        end
                    end
                    CImGui.EndChild()
                    # Plot(dtviewer.uiplot, "DataViewer绘图$id")
                    CImGui.EndTabItem()
                end
                CImGui.EndTabBar()
            end
            CImGui.EndChild()
            CImGui.NextColumn() #查看菜单

            if CImGui.BeginPopupModal("文件中没有数据", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                CImGui.TextColored(morestyle.logerrorcol, "文件中没有数据！")
                CImGui.Button("确认##文件中没有数据", (180, 0)) && CImGui.CloseCurrentPopup()
                CImGui.EndPopup()
            end
            if dtviewer.show_dtpicker
                if haskey(dtviewer.data, "data")
                    show_i = dtviewer.show_dtpicker_i
                    dtpk = dtviewer.dtpickers[show_i]
                    datakeys::Set{String} = keys(dtviewer.data["data"])
                    if datakeys != Set(dtpk.datalist)
                        dtpk.datalist = collect(datakeys)
                        dtpk.y = falses(length(datakeys))
                    end
                    isupdate = @c edit(dtpk, id, &dtviewer.show_dtpicker)
                    if !dtviewer.show_dtpicker || isupdate ||
                       (dtpk.isrealtime && waittime("DataViewer$id-DataPicker$show_i", dtpk.refreshrate))
                        syncplotdata(dtviewer.uiplots[show_i], dtpk, dtviewer.data["data"])
                    end
                else
                    CImGui.OpenPopup("文件中没有数据")
                    dtviewer.show_dtpicker = false
                end
            end
        end
        CImGui.End()
    end
end

let
    flags = 0
    flags |= CImGui.ImGuiTableFlags_Resizable
    flags |= CImGui.ImGuiTableFlags_Reorderable
    # flags |= CImGui.ImGuiTableFlags_Sortable
    flags |= CImGui.ImGuiTableFlags_Hideable
    # flags |= CImGui.ImGuiTableFlags_BordersOuter
    flags |= CImGui.ImGuiTableFlags_BordersInnerV
    flags |= CImGui.ImGuiTableFlags_RowBg
    global function showdata(data)
        if CImGui.BeginTable("showdata", length(data), flags)
            for key in keys(data)
                CImGui.TableSetupColumn(key)
            end
            CImGui.TableHeadersRow()
            ls = max_with_empty(length.(values(data)))
            for i in 1:ls
                CImGui.TableNextRow()
                for (_, val) in data
                    CImGui.TableNextColumn()
                    i > length(val) ? CImGui.Text("") : CImGui.Text(val[i])
                end
            end
            CImGui.EndTable()
        end
    end
end

