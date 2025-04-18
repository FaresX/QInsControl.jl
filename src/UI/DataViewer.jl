@kwdef mutable struct DataViewer
    dtp::DataPlot = DataPlot()
    data::Dict = Dict()
    p_open::Bool = true
end

let
    filteron::Bool = false
    filterins::String = ""
    filteraddr::String = ""
    filterqt::String = ""
    global function edit(dtviewer::DataViewer, path, id)
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
                    CImGui.Text(mlstr("Filter"))
                    CImGui.SameLine()
                    @c CImGui.Checkbox("##Filter", &filteron)
                    if filteron
                        w = (CImGui.GetContentRegionAvail().x - 3unsafe_load(IMGUISTYLE.ItemInnerSpacing.x))/4
                        CImGui.SameLine()
                        ibvs1 = dtviewer.data[insbufkeys[1]]
                        inses = Dict{String,Vector{String}}()
                        for (ins, instrs) in ibvs1
                            isempty(instrs) || (inses[ins] = collect(keys(instrs)))
                        end
                        CImGui.PushItemWidth(w)
                        @c ComboS("##Instruments", &filterins, keys(inses))
                        CImGui.SameLine()
                        @c ComboS("##Addresses", &filteraddr, haskey(inses, filterins) ? [inses[filterins]; ""] : [""])
                        CImGui.SameLine()
                        aliases = haskey(INSCONF, filterins) ? [[qt.alias for qt in values(INSCONF[filterins].quantities)]; ""] : [""]
                        @c ComboS("##Quantities", &filterqt, aliases)
                        CImGui.PopItemWidth()
                    end
                    CImGui.BeginChild("instrument status")
                    for insbuf in insbufkeys
                        logtime::String = split(insbuf, "/")[2]
                        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.WarnText)
                        CImGui.Button(logtime, (-0.1, 0.0))
                        CImGui.PopStyleColor()
                        CImGui.PushID(logtime)
                        view(
                            dtviewer.data[insbuf];
                            filterins=filterins, filteraddr=filteraddr, filterqt=filterqt, filteron=filteron
                        )
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
                    view(dtviewer.data["circuit"], stcstr("DataViewerCircuit", id))
                    CImGui.PopID()
                else
                    CImGui.Text(mlstr("data not loaded or data format not supported!"))
                end
                CImGui.EndTabItem()
            end
            if CImGui.BeginTabItem(mlstr("Data"))
                if haskey(dtviewer.data, "data")
                    if CImGui.BeginPopupContextItem()
                        if CImGui.MenuItem(stcstr(MORESTYLE.Icons.DataFormatter, " ", mlstr("Export")))
                            exportdata(dtviewer.data["data"])
                        end
                        CImGui.EndPopup()
                    end
                    showdata(dtviewer.data["data"], id)
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
                    editmenu(dtviewer.dtp, dtviewer.data["data"])
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
                        edit(dtviewer.data["revision"]["circuit"], stcstr("DataViewerRevision", id))
                    else
                        if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, "##new revision"), (-1, -1))
                            dtviewer.data["revision"] = Dict(
                                "description" => "",
                                "circuit" => deepcopy(dtviewer.data["circuit"])
                            )
                            loadsamplebasenode!(dtviewer.data["revision"]["circuit"])
                        end
                    end
                else
                    CImGui.Text(mlstr("data not loaded or data format not supported!"))
                end
                CImGui.EndTabItem()
            end
            CImGui.PopStyleColor()
            if CImGui.BeginTabItem(mlstr("Information"))
                if haskey(dtviewer.data, "info")
                    for (key, info) in dtviewer.data["info"]
                        SeparatorTextColored(MORESTYLE.Colors.HighlightText, key)
                        CImGui.Text(string(info))
                    end
                else
                    CImGui.Text(mlstr("no available information!"))
                end
                CImGui.EndTabItem()
            end
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
end

function loaddtviewer!(dtviewer::DataViewer, path, id)
    data = if split(basename(path), '.')[end] in ["qdt", "daq", "cfg"]
        dataload = @trypasse load(path) nothing
        if isnothing(dataload)
            datadict = Dict()
            for key in ["actions", "daqtask", "circuit", "data", "revision", "info", "valid"]
                loadval = @trypass load(path, key) nothing
                isnothing(loadval) || push!(datadict, key => loadval)
            end
            datadict
        else
            dataload
        end
    else
        Dict()
    end
    loaddtviewer!(dtviewer, data, id)
end
function loaddtviewer!(dtviewer::DataViewer, data::Dict, id)
    dtviewer.data = data
    if haskey(dtviewer.data, "data") && !(dtviewer.data["data"] isa Dict{String,Vector{String}})
        dtviewer.data["data"] = Dict(key => string.(val) for (key, val) in dtviewer.data["data"])
    end
    if haskey(dtviewer.data, "dataplot")
        dtviewer.dtp = dtviewer.data["dataplot"]
        for (i, plt) in enumerate(dtviewer.dtp.plots)
            plt.id = stcstr(id, "-", i)
        end
        haskey(dtviewer.data, "data") && update!(dtviewer.dtp, dtviewer.data["data"])
    end
    if !isempty(dtviewer.data)
        haskey(dtviewer.data, "circuit") && loadsamplebasenode!(dtviewer.data["circuit"])
        if haskey(dtviewer.data, "revision")
            for (_, node) in dtviewer.data["revision"]["circuit"].nodes
                if node isa SampleHolderNode
                    @trycatch mlstr("loading image failed!!!") begin
                        img = RGBA.(jpeg_decode(node.imgr.image))
                        imgsize = size(img)
                        node.imgr.id = CImGui.create_image_texture(imgsize...)
                        CImGui.update_image_texture(node.imgr.id, img, imgsize...)
                    end
                end
            end
        end
    end
end
function loadsamplebasenode!(circuit::NodeEditor)
    for (_, node) in circuit.nodes
        if node isa SampleHolderNode
            @trycatch mlstr("loading image failed!!!") begin
                img = RGBA.(jpeg_decode(node.imgr.image))
                imgsize = size(img)
                node.imgr.id = CImGui.create_image_texture(imgsize...)
                CImGui.update_image_texture(node.imgr.id, img, imgsize...)
            end
        end
    end
end

atclosedtviewer!(dtviewer::DataViewer) = (rmtextures!(dtviewer); rmplots!(dtviewer))
function rmtextures!(dtv::DataViewer)
    if haskey(dtv.data, "circuit")
        for (_, node) in dtv.data["circuit"].nodes
            node isa SampleHolderNode && destroytexture!(node.imgr.id)
        end
    end
    if haskey(dtv.data, "revision")
        for (_, node) in dtv.data["revision"]["circuit"].nodes
            node isa SampleHolderNode && destroytexture!(node.imgr.id)
        end
    end
end
rmplots!(dtv::DataViewer) = rmplots!(dtv.dtp)

function saveqdt(dtviewer::DataViewer, path)
    if !isempty(dtviewer.data)
        jldopen(path, "w") do file
            for key in keys(dtviewer.data)
                key == "info" && continue
                key == "dataplot" && (file[key] = deepcopy(dtviewer.dtp); continue)
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
            file["info"] = fileinfo()
        end
    end
end

let
    flags::Cint = 0
    flags |= CImGui.ImGuiTableFlags_ScrollY
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
        contentwidth = CImGui.GetContentRegionAvail().x
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
        if CImGui.BeginTable("showdata", length(data) + 1, flags)
            CImGui.TableSetupScrollFreeze(0, 1)
            CImGui.TableSetupColumn(mlstr("Rows"), CImGui.ImGuiTableColumnFlags_WidthFixed, 4CImGui.GetFontSize())
            for key in keys(data)
                CImGui.TableSetupColumn(key)
            end
            CImGui.TableHeadersRow()

            startpage = (pagei[id] - 1) * CONF.DtViewer.showdatarow + 1
            stoppage = pagei[id] * CONF.DtViewer.showdatarow
            for i in startpage:(pagei[id] == pages ? lmax : stoppage)
                CImGui.TableNextRow()
                CImGui.TableSetColumnIndex(0)
                CImGui.Text(stcstr(i))
                for (j, val) in enumerate(values(data))
                    CImGui.TableSetColumnIndex(j)
                    CImGui.Text(i > length(val) ? "" : val[i])
                end
            end
            CImGui.EndTable()
        end
        CImGui.EndChild()
        CImGui.PopID()
    end
end

function exportdata(data::Dict{String,Vector{String}})
    exportpath = save_file(; filterlist="csv")
    if exportpath != ""
        @trycatch mlstr("exporting data failed!!!") begin
            exportdata(exportpath, data, Val(Symbol(split(basename(exportpath), '.')[end])))
        end
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