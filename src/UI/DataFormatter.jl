abstract type AbstractFormatData end
@kwdef mutable struct FormatData <: AbstractFormatData
    path::AbstractString = ""
    dtviewer::DataViewer = DataViewer(p_open=false)
    dtpki::Cint = 1
    mode::String = "default"
end

@kwdef mutable struct FormatDataGroup <: AbstractFormatData
    data::Vector{FormatData} = []
    mode::String = "default"
    merge::Bool = false
    dtviewer::DataViewer = DataViewer(p_open=false)
end

@kwdef mutable struct FormatCodes <: AbstractFormatData
    codes::AbstractString = ""
    mode::AbstractString = "default"
end

@kwdef mutable struct DataFormatter
    data::Vector{AbstractFormatData} = []
    noclose::Bool = true
    p_open::Bool = true
end

const FORMATTERSINGLEMODES = ["default"]
const FORMATTERGROUPMODES = ["default"]
const FORMATTERCODEMODES = ["default"]

function edit(fc::FormatCodes, _)
    lines = split(fc.codes, '\n')
    x = CImGui.CalcTextSize(lines[argmax(lengthpr.(lines))]).x + 2CImGui.GetFontSize()
    width = CImGui.GetContentRegionAvail().x
    x = x > width ? x : width
    y = (1 + length(findall("\n", fc.codes))) * CImGui.GetTextLineHeight() + 2unsafe_load(IMGUISTYLE.FramePadding.y)
    CImGui.BeginChild("##FormatCodes", (Cfloat(0), y), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
    @c InputTextMultilineRSZ("##FormatCodes", &fc.codes, (x, y), ImGuiInputTextFlags_AllowTabInput)
    CImGui.EndChild()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    CImGui.SetCursorScreenPos(rmin.x, rmax.y)
    CImGui.PushItemWidth(3CImGui.GetFontSize())
    @c ComboS("##mode", &fc.mode, FORMATTERCODEMODES, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()
    CImGui.Button(mlstr("Codes"), (-1, 0))
end

function edit(fd::FormatData, id)
    ftsz = CImGui.GetFontSize()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.FormatDataBorder)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
    CImGui.BeginChild("text", (Cfloat(-1), 3CImGui.GetTextLineHeightWithSpacing()), true)
    CImGui.PushTextWrapPos()
    CImGui.Text(fd.path)
    CImGui.PopTextWrapPos()
    CImGui.EndChild()
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    CImGui.SetCursorScreenPos(rmin.x, rmax.y)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Button,
        fd.dtviewer.p_open ? MORESTYLE.Colors.HighlightText : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
    )
    if CImGui.Button(ICONS.ICON_EYE, (2ftsz, Cfloat(0)))
        fd.dtviewer.p_open ⊻= true
        if fd.dtviewer.p_open
            loaddtviewer!(fd.dtviewer, fd.path, stcstr("formatdata", id))
        else
            atclosedtviewer!(fd.dtviewer)
            fd.dtviewer = DataViewer(p_open=false)
        end
    end
    CImGui.PopStyleColor()
    CImGui.SameLine()
    if CImGui.Button(MORESTYLE.Icons.DataFormatter, (2ftsz, Cfloat(0)))
        if haskey(fd.dtviewer.data, "data")
            exportdata(fd.dtviewer.data["data"])
        else
            data = @trypasse load(fd.path, "data") Dict()
            isempty(data) || exportdata(data)
        end
    end
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
    CImGui.PushItemWidth(2ftsz)
    @c CImGui.DragInt("##which dtpk", &fd.dtpki, 1, 1, 60)
    CImGui.PopItemWidth()
    CImGui.SameLine()
    CImGui.PushItemWidth(3ftsz)
    @c ComboS("##mode", &fd.mode, FORMATTERSINGLEMODES, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.PopStyleVar()
    CImGui.SameLine()
    CImGui.Button(mlstr("Data"), (-1, 0)) && Threads.@spawn @trycatch mlstr("task failed!!!") fd.path = pick_file(filterlist="qdt")
end

function edit(fdg::FormatDataGroup, id)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.FormatDataGroupBorder)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
    lfdg = length(fdg.data)
    height = max(lfdg, 1) * (3CImGui.GetTextLineHeightWithSpacing() + CImGui.GetFrameHeight()) + (lfdg - 1) * unsafe_load(IMGUISTYLE.ItemSpacing.y) +
             2unsafe_load(IMGUISTYLE.WindowPadding.y)
    CImGui.BeginChild("FormatDataGroup", (Cfloat(0), height), true)
    for (i, fd) in enumerate(fdg.data)
        CImGui.PushID(i)
        edit(fd, stcstr(id, '-', i))
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && deleteat!(fdg.data, i)
            CImGui.EndPopup()
        end
        CImGui.PopID()
        if CImGui.BeginDragDropSource(0)
            @c CImGui.SetDragDropPayload("Swap FormatData in Group", &i, sizeof(Cint))
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Swap FormatData in Group")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                if i != payload_i
                    insert!(fdg.data, i, fdg.data[payload_i])
                    deleteat!(fdg.data, payload_i < i ? payload_i : payload_i + 1)
                end
            end
            CImGui.EndDragDropTarget()
        end
    end
    CImGui.EndChild()
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
    CImGui.SetCursorScreenPos(rmin.x, rmax.y)
    ftsz = CImGui.GetFontSize()
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Button,
        fdg.dtviewer.p_open ? MORESTYLE.Colors.HighlightText : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
    )
    if CImGui.Button(ICONS.ICON_EYE, (2ftsz, Cfloat(0)))
        fdg.dtviewer.p_open ⊻= true
        fdg.dtviewer.p_open && loaddtviewer!(fdg, id)
    end
    CImGui.PopStyleColor()
    CImGui.SameLine()
    if CImGui.Button(ICONS.ICON_ROTATE, (2ftsz, Cfloat(0)))
        fdg.dtviewer.p_open || (fdg.dtviewer = DataViewer(p_open=false))
    end
    CImGui.SameLine()
    if @c CImGui.Checkbox(ICONS.ICON_CODE_MERGE, &fdg.merge)
        fdg.dtviewer.p_open || (fdg.dtviewer = DataViewer(p_open=false))
    end
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
    CImGui.Button(ICONS.ICON_PLUS, (2ftsz, Cfloat(0))) && push!(fdg.data, FormatData())
    CImGui.SameLine()
    CImGui.Button(ICONS.ICON_MINUS, (2ftsz, Cfloat(0))) && (isempty(fdg.data) || pop!(fdg.data))
    CImGui.PopStyleVar()
    CImGui.SameLine()
    CImGui.PushItemWidth(3ftsz)
    @c ComboS("##mode", &fdg.mode, FORMATTERGROUPMODES, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()
    if CImGui.Button(mlstr("Data Group"), (-1, 0))
        Threads.@spawn @trycatch mlstr("task failed!!!") begin
            pathes = pick_multi_file(filterlist="qdt")
            isempty(pathes) || append!(fdg.data, [FormatData(path=path) for path in pathes])
        end
    end
end

function edit(dft::DataFormatter, id)
    CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Once)
    if @c CImGui.Begin(stcstr(MORESTYLE.Icons.DataFormatter, " ", mlstr("Data Formatter"), "##", id), &dft.p_open)
        SetWindowBgImage(CONF.BGImage.formatter.path; rate=CONF.BGImage.formatter.rate, use=CONF.BGImage.formatter.use)
        CImGui.PushFont(C_NULL, MORESTYLE.Variables.BigIconSize)
        CImGui.AddRectFilled(
            CImGui.GetWindowDrawList(),
            CImGui.GetCursorScreenPos(),
            CImGui.GetCursorScreenPos() .+ (CImGui.GetWindowWidth(), CImGui.GetFrameHeight() + unsafe_load(IMGUISTYLE.ItemSpacing.y)),
            MORESTYLE.Colors.ToolBarBg
        )
        CImGui.Button(MORESTYLE.Icons.NewFile)
        rmin = CImGui.GetItemRectMin()
        CImGui.SameLine()
        ftsz = CImGui.GetFontSize()
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.IconButton)
        CImGui.Button(MORESTYLE.Icons.File, (3ftsz / 2, Cfloat(0))) && push!(dft.data, FormatData())
        CImGui.SameLine()
        CImGui.Button(MORESTYLE.Icons.OpenFolder, (3ftsz / 2, Cfloat(0))) && push!(dft.data, FormatDataGroup())
        CImGui.SameLine()
        CImGui.Button(MORESTYLE.Icons.CodeBlock, (3ftsz / 2, Cfloat(0))) && push!(dft.data, FormatCodes())
        rmax = CImGui.GetItemRectMax()
        CImGui.AddRect(
            CImGui.GetWindowDrawList(), rmin, rmax,
            MORESTYLE.Colors.ShowTextRect,
            MORESTYLE.Variables.TextRectRounding, ImDrawFlags_RoundCornersAll, MORESTYLE.Variables.TextRectThickness
        )
        CImGui.SameLine()
        CImGui.Button(MORESTYLE.Icons.Delete, (3ftsz / 2, Cfloat(0))) && (isempty(dft.data) || pop!(dft.data))
        # CImGui.SameLine()
        # if CImGui.Button(MORESTYLE.Icons.DataFormatter, (3ftsz / 2, Cfloat(0)))
        #     @trycatch mlstr("formatting data failed!") formatdata(dft.data)
        # end
        CImGui.PopStyleColor(2)
        CImGui.PopFont()
        # igSeparatorText("")
        for (i, fd) in enumerate(dft.data)
            CImGui.PushID(i)
            edit(fd, stcstr(id, '-', i))
            if CImGui.BeginPopupContextItem()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && deleteat!(dft.data, i)
                CImGui.EndPopup()
            end
            CImGui.Spacing()
            if CImGui.BeginDragDropSource(0)
                @c CImGui.SetDragDropPayload("Swap FormatData", &i, sizeof(Cint))
                CImGui.EndDragDropSource()
            end
            if CImGui.BeginDragDropTarget()
                payload = CImGui.AcceptDragDropPayload("Swap FormatData")
                if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                    payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                    if i != payload_i
                        insert!(dft.data, i, dft.data[payload_i])
                        deleteat!(dft.data, payload_i < i ? payload_i : payload_i + 1)
                    end
                end
                CImGui.EndDragDropTarget()
            end
            CImGui.PopID()
        end
    end
    CImGui.End()
    if dft.p_open
        for (i, fd) in enumerate(dft.data)
            showdtviewer(fd, stcstr(id, "-", i))
        end
    end
end

atclosedataformatter!(dft::DataFormatter) = atcloseformatdata!.(dft.data)
atcloseformatdata!(d::FormatData) = d.dtviewer.p_open && atclosedtviewer!(d.dtviewer)
atcloseformatdata!(d::FormatDataGroup) = (atcloseformatdata!.(d.data); d.dtviewer.p_open && atclosedtviewer!(d.dtviewer))
atcloseformatdata!(::FormatCodes) = nothing

function loaddtviewer!(fdg::FormatDataGroup, id)
    haskey(fdg.dtviewer.data, "data") ? (return) : fdg.dtviewer.data["data"] = Dict{String,Vector{String}}()
    if length(fdg.data) == 2
        bnm1 = basename(fdg.data[1].path)
        bnm2 = basename(fdg.data[2].path)
        bnm1s = split(bnm1, ".")
        bnm2s = split(bnm2, ".")
        if length(bnm1s) >= 3 && length(bnm2s) >= 3 && bnm1s[end] == bnm2s[end] == "cache" &&
           bnm1s[end-1] in ["cfg", "qdt"] && bnm2s[end-1] in ["cfg", "qdt"] &&
           join(bnm1s[1:end-2], ".") == join(bnm2s[1:end-2], ".")
            if bnm1s[end-1] == "cfg"
                mergecache!(fdg.dtviewer, fdg.data[1].path, fdg.data[2].path, id)
            else
                mergecache!(fdg.dtviewer, fdg.data[2].path, fdg.data[1].path, id)
            end
            return nothing
        end
    end
    for (i, fd) in enumerate(fdg.data)
        if isfile(fd.path)
            data = @trypasse load(fd.path, "data") Dict{String,Vector{String}}()
            if !isempty(data)
                if fdg.merge
                    for (k, val) in data
                        if haskey(fdg.dtviewer.data["data"], k)
                            append!(fdg.dtviewer.data["data"][k], val)
                        else
                            fdg.dtviewer.data["data"][k] = val
                        end
                    end
                else
                    datai = Dict{String,Vector{String}}()
                    for (k, val) in data
                        datai[string(i, " - ", k)] = val
                    end
                    merge!(fdg.dtviewer.data["data"], datai)
                end
            end
        end
    end
    fdg.dtviewer.data["dataplot"] = deepcopy(fdg.dtviewer.dtp)
    fdg.dtviewer.data["daqtask"] = DAQTask(
        explog=join([string("Data ", i, '\n', fd.path) for (i, fd) in enumerate(fdg.data)], '\n'),
        blocks=[]
    )
    fdg.dtviewer.data["valid"] = true
    return nothing
end

function showdtviewer(fd::FormatData, id)
    if fd.dtviewer.p_open
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        @c(CImGui.Begin(stcstr("FormatData", id), &fd.dtviewer.p_open)) && edit(fd.dtviewer, fd.path, stcstr("FormatData", id))
        CImGui.End()
        fd.dtviewer.p_open && haskey(fd.dtviewer.data, "data") && renderplots(fd.dtviewer.dtp, stcstr("formatdata", id))
        if !fd.dtviewer.p_open
            atclosedtviewer!(fd.dtviewer)
            fd.dtviewer = DataViewer(p_open=false)
        end
    end
end
function showdtviewer(fdg::FormatDataGroup, id)
    for (i, fd) in enumerate(fdg.data)
        showdtviewer(fd, stcstr(id, "-", i))
    end
    if fdg.dtviewer.p_open
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        @c(CImGui.Begin(stcstr("FormatDataGroup", id), &fdg.dtviewer.p_open)) && edit(fdg.dtviewer, "", stcstr("FormatDataGroup", id))
        CImGui.End()
        fdg.dtviewer.p_open && haskey(fdg.dtviewer.data, "data") && renderplots(fdg.dtviewer.dtp, stcstr("formatdatagroup", id))
    end
end
showdtviewer(::FormatCodes, _) = nothing

function formatdata(fds::Vector{AbstractFormatData})
    savepath = save_file(filterlist=".jmd;.jl")
    if savepath != ""
        open(savepath, "a+") do file
            for fd in fds
                fd isa FormatData && isfile(fd.path) && write(file, formatdata(fd))
                fd isa FormatDataGroup && all(x -> isfile(x.path), fd) && write(file, formatdata(fd))
                write(file, formatdata(fd))
            end
        end
    end
end
formatdata(fc::FormatCodes) = formatdata(fc, Val(Symbol(fc.mode)))
formatdata(fc::FormatCodes, ::Val{:default}) = string(fc.codes, '\n')
formatdata(fd::FormatData) = formatdata(fd, Val(Symbol(fd.mode)))
formatdata(fdg::FormatDataGroup) = formatdata(fdg, Val(Symbol(fdg.mode)))
function formatdata(fd::FormatData, ::Val{:default})
    ""
end
function formatdata(fdg::FormatDataGroup, ::Val{:default})
    ""
end

function registermodes!(modes, type=:single)
    if type == :single
        append!(FORMATTERSINGLEMODES, setdiff(Set(modes), Set(FORMATTERSINGLEMODES)))
    elseif type == :group
        append!(FORMATTERGROUPMODES, setdiff(Set(modes), Set(FORMATTERGROUPMODES)))
    elseif type == :code
        append!(FORMATTERCODEMODES, setdiff(Set(modes), Set(FORMATTERCODEMODES)))
    end
end

function readqdtcache(path)
    data = Dict()
    for dpair in split(read(path, String), '\n')
        key, val = string.(split(dpair, ","))
        haskey(data, key) || push!(data, key => [])
        push!(data[key], val)
    end
    return data
end
function mergecache!(dtviewer::DataViewer, cfgcachepath, qdtcachepath, id)
    qdata = readqdtcache(qdtcachepath)
    cfg = load(cfgcachepath)
    if haskey(cfg, "EXTRADATA")
        for (key, val) in cfg["EXTRADATA"]
            qdata[key] = val
        end
    end
    data = Dict()
    savetype = eval(Symbol(CONF.DAQ.savetype))
    if savetype == String
        data["data"] = qdata
    else
        datafloat = Dict()
        for (key, val) in qdata
            dataparsed = tryparse.(savetype, val)
            datafloat[key] = true in isnothing.(dataparsed) ? val : dataparsed
        end
        data["data"] = datafloat
    end
    for (key, val) in cfg
        key == "EXTRADATA" && continue
        data[key] = val
    end
    loaddtviewer!(dtviewer, data, stcstr("formatdatagroup", id))
end