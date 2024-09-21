@kwdef mutable struct DataViewer
    dtp::DataPlot = DataPlot()
    data::Dict = Dict()
    p_open::Bool = true
end

@kwdef mutable struct FileViewer
    filetree::FileTree = FileTree()
    isrename::Dict{String,Bool} = Dict()
    dtviewers::Dict{String,DataViewer} = Dict()
    p_open::Bool = true
    noclose::Bool = true
end

function edit(fv::FileViewer, id)
    CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Once)
    if @c CImGui.Begin(
        if fv.filetree.rootpath_bnm == ""
            stcstr(MORESTYLE.Icons.OpenFile, "  ", mlstr("Data Browse"), "###dtv", id)
        else
            stcstr(MORESTYLE.Icons.OpenFolder, "  ", mlstr("Data Browse"), "###dtv", id)
        end,
        &fv.p_open
    )
        SetWindowBgImage()

        oldfiles = copy(fv.filetree.selectedpathes)
        InputTextRSZ(stcstr(mlstr("Filter"), "##", id), fv.filetree.filter)
        CImGui.SameLine()
        CImGui.Checkbox(mlstr("Valid"), fv.filetree.valid)
        CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, MORESTYLE.Colors.ToolBarBg)
        edit(fv.filetree, fv.isrename, false)
        if fv.filetree.selectedpathes != oldfiles
            for path in fv.filetree.selectedpathes
                haskey(fv.dtviewers, path) || push!(fv.dtviewers, path => DataViewer())
                path in oldfiles || loaddtviewer!(fv.dtviewers[path], path)
            end
            for path in keys(fv.dtviewers)
                path in fv.filetree.selectedpathes || delete!(fv.dtviewers, path)
            end
        end
        CImGui.PopStyleColor()
        fv.filetree.rootpath_bnm != "" && CImGui.IsMouseClicked(1) && !CImGui.IsAnyItemHovered() &&
            CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_RootAndChildWindows) && CImGui.OpenPopup("File Menu")
        if CImGui.BeginPopup("File Menu")
            if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Refresh")))
                fv.filetree.filetrees = FolderFileTree(
                    fv.filetree.rootpath,
                    fv.filetree.selectedpathes,
                    fv.filetree.filter,
                    fv.filetree.valid
                ).filetrees
            end
            CImGui.EndPopup()
        end
    end
    CImGui.End()
    for path in fv.filetree.selectedpathes
        haskey(fv.dtviewers, path) || push!(fv.dtviewers, path => DataViewer())
        dtviewer = fv.dtviewers[path]
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        @c(CImGui.Begin(stcstr(basename(path), "##", id, path), &dtviewer.p_open)) && edit(dtviewer, path, string(id, path))
        CImGui.End()
        if dtviewer.p_open
            haskey(dtviewer.data, "data") && renderplots(dtviewer.dtp, stcstr("DataViewer", id, path))
        else
            delete!(fv.dtviewers, path)
            deleteat!(fv.filetree.selectedpathes, findall(==(path), fv.filetree.selectedpathes))
        end
    end
end

function edit(dtviewer::DataViewer, path, id)
    CImGui.BeginChild("DataViewer")
    if CImGui.BeginTabBar("Data Viewer")
        if CImGui.BeginTabItem(mlstr("Instrument Status"))
            if true in occursin.(r"instrbufferviewers/.*", keys(dtviewer.data))
                if CImGui.BeginPopupContextItem()
                    CImGui.Text(mlstr("Display Columns"))
                    @c CImGui.SliderInt("##InsBuf col num", &CONF.InsBuf.showcol, 1, 6)
                    CImGui.EndPopup()
                end
                insbufkeys::Vector{String} = sort(
                    [key for key in keys(dtviewer.data) if occursin(r"instrbufferviewers/.*", key)]
                )
                CImGui.BeginChild("instrument status")
                for insbuf in insbufkeys
                    logtime::String = split(insbuf, "/")[2]
                    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.LogWarn)
                    CImGui.Button(logtime, (-0.1, 0.0))
                    CImGui.PopStyleColor()
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
        if CImGui.BeginTabItem(mlstr("Actions"))
            if CImGui.BeginPopupContextItem()
                CImGui.Text(mlstr("Display Columns"))
                @c CImGui.SliderInt("##InsBuf col num", &CONF.InsBuf.showcol, 1, 6)
                CImGui.EndPopup()
            end
            haskey(dtviewer.data, "actions") ? viewactions(dtviewer.data["actions"]) : CImGui.Text(mlstr("No actions!"))
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
                            @trycatch mlstr("exporting data failed!!!") begin
                                exportdata(
                                    exportpath,
                                    dtviewer.data["data"],
                                    Val(Symbol(split(basename(exportpath), '.')[end]))
                                )
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
            if haskey(dtviewer.data, "data")
                if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("New Plot")), (Cfloat(-1), 2CImGui.GetFontSize()))
                    newplot!(dtviewer.dtp)
                end
                editmenu(dtviewer.dtp)
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
            if haskey(dtviewer.data, "daqtask") || haskey(dtviewer.data, "circuit")
                if haskey(dtviewer.data, "revision")
                    CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("Description"))
                    desp = dtviewer.data["revision"]["description"]
                    y = (1 + length(findall("\n", desp))) * CImGui.GetTextLineHeight() +
                        2unsafe_load(IMGUISTYLE.FramePadding.y)
                    @c InputTextMultilineRSZ("##Description", &desp, (Cfloat(-1), y))
                    dtviewer.data["revision"]["description"] = desp
                    edit(dtviewer.data["revision"]["circuit"])
                else
                    if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, "##new revision"), (-1, -1))
                        dtviewer.data["revision"] = Dict(
                            "description" => "",
                            "circuit" => deepcopy(dtviewer.data["circuit"])
                        )
                    end
                end
            else
                CImGui.Text(mlstr("data not loaded or data format not supported!"))
            end
            CImGui.EndTabItem()
        end
        CImGui.PopStyleColor()
        if igTabItemButton(stcstr(MORESTYLE.Icons.SaveButton, " ", mlstr("Save")), 0)
            if isfile(path)
                saveqdt(dtviewer, path)
            else
                savepath = save_file(; filterlist="qdt")
                savepath == "" || saveqdt(dtviewer, savepath)
            end
        end
        CImGui.SameLine()
        haskey(dtviewer.data, "valid") || push!(dtviewer.data, "valid" => false)
        valid = dtviewer.data["valid"]
        @c(CImGui.Checkbox(mlstr("Valid"), &valid)) && (dtviewer.data["valid"] = valid)
        CImGui.EndTabBar()
    end
    CImGui.EndChild()
    haskey(dtviewer.data, "data") && showdtpks(dtviewer.dtp, stcstr("DataViewer", id), dtviewer.data["data"])
end

function loaddtviewer!(dtviewer::DataViewer, path)
    loaddtviewer!(dtviewer, split(basename(path), '.')[end] in ["qdt", "cfg"] ? @trypasse(compatload(path), Dict()) : Dict())
end
function loaddtviewer!(dtviewer::DataViewer, data::Dict)
    dtviewer.data = data
    if haskey(dtviewer.data, "data") && !(dtviewer.data["data"] isa Dict{String,Vector{String}})
        dtviewer.data["data"] = Dict(key => string.(val) for (key, val) in dtviewer.data["data"])
    end
    if haskey(dtviewer.data, "dataplot")
        dtviewer.dtp = dtviewer.data["dataplot"]
        haskey(dtviewer.data, "data") && update!(dtviewer.dtp, dtviewer.data["data"])
    end
    if !isempty(dtviewer.data)
        if haskey(dtviewer.data, "circuit")
            for (_, node) in dtviewer.data["circuit"].nodes
                if node isa SampleHolderNode
                    @trycatch mlstr("loading image failed!!!") begin
                        img = RGBA.(jpeg_decode(node.imgr.image))
                        imgsize = size(img)
                        node.imgr.id = ImGui_ImplOpenGL3_CreateImageTexture(imgsize...)
                        ImGui_ImplOpenGL3_UpdateImageTexture(node.imgr.id, img, imgsize...)
                    end
                end
            end
        end
        if haskey(dtviewer.data, "revision")
            for (_, node) in dtviewer.data["revision"]["circuit"].nodes
                if node isa SampleHolderNode
                    @trycatch mlstr("loading image failed!!!") begin
                        img = RGBA.(jpeg_decode(node.imgr.image))
                        imgsize = size(img)
                        node.imgr.id = ImGui_ImplOpenGL3_CreateImageTexture(imgsize...)
                        ImGui_ImplOpenGL3_UpdateImageTexture(node.imgr.id, img, imgsize...)
                    end
                end
            end
        end
    end
end

function saveqdt(dtviewer::DataViewer, path)
    if !isempty(dtviewer.data)
        jldopen(path, "w") do file
            for key in keys(dtviewer.data)
                key == "dataplot" && (file[key] = empty!(deepcopy(dtviewer.dtp)); continue)
                if key == "data"
                    savetype = eval(Symbol(CONF.DAQ.savetype))
                    if savetype == String
                        file["data"] = dtviewer.data["data"]
                    else
                        datafloat = Dict()
                        for (key, val) in dtviewer.data["data"]
                            dataparsed = tryparse.(savetype, val)
                            datafloat[key] = true in isnothing.(dataparsed) ? val : dataparsed
                        end
                        file["data"] = datafloat
                    end
                    continue
                end
                file[key] = dtviewer.data[key]
            end
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
        haskey(pagei, id) || (pagei[id] = 1)
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