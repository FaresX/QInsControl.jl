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
    width = CImGui.GetContentRegionAvailWidth()
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
        fd.dtviewer.p_open ? loaddtviewer!(fd.dtviewer, fd.path) : (fd.dtviewer = DataViewer(p_open=false))
    end
    CImGui.PopStyleColor()
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
    if fd.dtviewer.p_open
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        if @c CImGui.Begin(stcstr("FormatData", id), &fd.dtviewer.p_open)
            edit(fd.dtviewer, fd.path, stcstr("FormatData", id))
        end
        CImGui.End()
        fd.dtviewer.p_open && haskey(fd.dtviewer.data, "data") && renderplots(fd.dtviewer.dtp, stcstr("formatdata", id))
        fd.dtviewer.p_open || (fd.dtviewer = DataViewer(p_open=false))
    end
    CImGui.Button(mlstr("Data"), (-1, 0)) && @monitorspawn fd.path = pick_file(filterlist="qdt")
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
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (deleteat!(fdg.data, i); break)
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
        fdg.dtviewer.p_open ? loaddtviewer!(fdg) : (fdg.dtviewer = DataViewer(p_open=false))
    end
    CImGui.PopStyleColor()
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
    if fdg.dtviewer.p_open
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        if @c CImGui.Begin(stcstr("FormatDataGroup", id), &fdg.dtviewer.p_open)
            edit(fdg.dtviewer, "", stcstr("FormatDataGroup", id))
        end
        CImGui.End()
        fdg.dtviewer.p_open && haskey(fdg.dtviewer.data, "data") && renderplots(fdg.dtviewer.dtp, stcstr("formatdatagroup", id))
        fdg.dtviewer.p_open || (fdg.dtviewer = DataViewer(p_open=false))
    end
    if CImGui.Button(mlstr("Data Group"), (-1, 0))
        @monitorspawn begin
            pathes = pick_multi_file(filterlist="qdt")
            isempty(pathes) || append!(fdg.data, [FormatData(path=path) for path in pathes])
        end
    end
end

function edit(dft::DataFormatter, id)
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
    if @c CImGui.Begin(stcstr(MORESTYLE.Icons.DataFormatter, " ", mlstr("Data Formatter"), "##", id), &dft.p_open)
        SetWindowBgImage()
        CImGui.PushFont(PLOTFONT)
        CImGui.AddRectFilled(
            CImGui.GetWindowDrawList(),
            CImGui.GetCursorScreenPos(),
            CImGui.GetCursorScreenPos() .+ (CImGui.GetWindowContentRegionMax().x, CImGui.GetFrameHeight() + unsafe_load(IMGUISTYLE.ItemSpacing.y)),
            CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.ToolBarBg)
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
            CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.ShowTextRect),
            MORESTYLE.Variables.TextRectRounding, ImDrawFlags_RoundCornersAll, MORESTYLE.Variables.TextRectThickness
        )
        CImGui.SameLine()
        CImGui.Button(MORESTYLE.Icons.CloseFile, (3ftsz / 2, Cfloat(0))) && (isempty(dft.data) || pop!(dft.data))
        CImGui.SameLine()
        if CImGui.Button(MORESTYLE.Icons.DataFormatter, (3ftsz / 2, Cfloat(0)))
            try
                formatdata(dft.data)
            catch e
                @error mlstr("formatting data failed!") exception = e
            end
        end
        CImGui.PopStyleColor(2)
        CImGui.PopFont()
        # igSeparatorText("")
        for (i, fd) in enumerate(dft.data)
            CImGui.PushID(i)
            edit(fd, stcstr(id, '-', i))
            if CImGui.BeginPopupContextItem()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (deleteat!(dft.data, i); break)
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
end

function loaddtviewer!(fdg::FormatDataGroup)
    haskey(fdg.dtviewer.data, "data") || (fdg.dtviewer.data["data"] = Dict{String,Vector{String}}())
    for (i, fd) in enumerate(fdg.data)
        if isfile(fd.path)
            data = @trypasse load(fd.path, "data") Dict{String,Vector{String}}()
            if !isempty(data)
                datai = Dict{String,Vector{String}}()
                for (k, val) in data
                    datai[string(i, " - ", k)] = val
                end
                merge!(fdg.dtviewer.data["data"], datai)
            end
        end
    end
    fdg.dtviewer.data["dataplot"] = empty!(deepcopy(fdg.dtviewer.dtp))
    fdg.dtviewer.data["daqtask"] = DAQTask(
        explog=join([string("Data ", i, '\n', fd.path) for (i, fd) in enumerate(fdg.data)], '\n'),
        blocks=[]
    )
end

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