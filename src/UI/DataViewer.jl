mutable struct DataViewer
    p_open::Ref{Bool}
    show_data_picker::Bool
    firsttime::Bool
    dtpicker::DataPicker
    uiplot::UIPlot
    data::Dict
end
DataViewer() = DataViewer(Ref(true), false, true, DataPicker(), UIPlot(), Dict())

let
    window_ids::Dict{Int,String} = Dict()
    global function edit(dtviewer::DataViewer, filetree::FileTree, isrename::Dict{String,Bool}, id)
        # CImGui.SetNextWindowPos((300, 200), CImGui.ImGuiCond_Once)
        # CImGui.SetNextWindowSize((1200, 800), CImGui.ImGuiCond_Once)
        if !haskey(window_ids, id)
            if filetree.rootpath_bnm == ""
                push!(window_ids, id => morestyle.Icons.OpenFile * "  数据浏览##$id")
            else
                push!(window_ids, id => morestyle.Icons.OpenFolder * "  数据浏览##$id")
            end
        end
        if CImGui.Begin(window_ids[id], dtviewer.p_open)
            CImGui.Columns(2)
            dtviewer.firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.3); dtviewer.firsttime = false)

            CImGui.BeginChild("DataViewer-FileTree")
            oldfile = filetree.selectedpath[]
            edit(filetree, isrename)
            if filetree.selectedpath[] != oldfile
                dtviewer.data = @trypasse load(filetree.selectedpath[]) Dict()
                datakeys = keys(dtviewer.data)
                "uiplot" in datakeys && (dtviewer.uiplot = @trypasse dtviewer.data["uiplot"] dtviewer.uiplot)
                "datapicker" in datakeys && (dtviewer.dtpicker = @trypasse dtviewer.data["datapicker"] dtviewer.dtpicker)
            end
            CImGui.EndChild()
            CImGui.NextColumn() #文件列表

            CImGui.BeginChild("DataViewer")
            if CImGui.BeginTabBar("Data_Viewer")
                if CImGui.BeginTabItem("仪器状态")
                    CImGui.BeginChild("仪器状态")
                    if !isempty(dtviewer.data) && true in occursin.(r"instrbuffer/.*", keys(dtviewer.data))
                        insbufkeys::Vector{String} = sort([key for key in keys(dtviewer.data) if occursin(r"instrbuffer/.*", key)])
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
                    if !isempty(dtviewer.data) && haskey(dtviewer.data, "daqtask")
                        CImGui.PushID(id)
                        view(dtviewer.data["daqtask"].nodeeditor)
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
                    if CImGui.BeginPopupContextItem("选择数据查看")
                        CImGui.MenuItem(morestyle.Icons.SelectData * " 选择数据") && (dtviewer.show_data_picker = true)
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
                    Plot(dtviewer.uiplot, "DataViewer绘图$id")
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
            if dtviewer.show_data_picker
                if haskey(dtviewer.data, "data")
                    datakeys::Set{String} = keys(dtviewer.data["data"])
                    datakeys == Set(dtviewer.dtpicker.datalist) || (dtviewer.dtpicker.datalist = collect(datakeys); dtviewer.dtpicker.y = falses(length(datakeys)))
                    isupdate = @c edit(dtviewer.dtpicker, id, &dtviewer.show_data_picker)
                    if !dtviewer.show_data_picker || isupdate || (dtviewer.dtpicker.isrealtime && waittime("DataViewer$id", dtviewer.dtpicker.refreshrate))
                        syncplotdata(dtviewer.uiplot, dtviewer.dtpicker, dtviewer.data["data"])
                    end
                else
                    CImGui.OpenPopup("文件中没有数据")
                    dtviewer.show_data_picker = false
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
            # CImGui.TableSetupColumn("Row")
            for key in keys(data)
                CImGui.TableSetupColumn(key)
            end
            # CImGui.TableSetupColumn("none")
            CImGui.TableHeadersRow()
            ls = max(length.(values(data))...)
            for i in 1:ls
                CImGui.TableNextRow()
                # CImGui.TableNextColumn()
                # CImGui.Text(string(i))
                for (_, val) in data
                    CImGui.TableNextColumn()
                    i > length(val) ? CImGui.Text("") : CImGui.Text(val[i])
                end
            end
            CImGui.EndTable()
        end
    end
end

# function showdata(data)
#     if CImGui.BeginTabBar("##showdatacol")
#         for (key, val) in data
#             if CImGui.BeginTabItem(key)
#                 CImGui.BeginChild("ShowData", (-1, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
#                 CImGui.TextColored(morestyle.Colors.HighlightText, key)
#                 CImGui.Separator()
#                 row, col = val isa Vector ? (length(val), 1) : size(val)
#                 w = Float32(max(length.(val)...) * (CImGui.GetFontSize() * 2 / 3))
#                 h = CImGui.GetTextLineHeight()
#                 for i in 1:row
#                     for j in 1:col
#                         CImGui.Selectable(val[i, j], false, 0, (w, h))
#                     end
#                 end
#                 CImGui.EndChild()
#                 CImGui.EndTabItem()
#             end
#         end
#         CImGui.EndTabBar()
#     end
# end

