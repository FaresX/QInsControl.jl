Base.@kwdef mutable struct MoreStyleColor
    HighlightText::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    LogInfo::Vector{Cfloat} = [0.000, 0.855, 1.000, 1.000]
    LogError::Vector{Cfloat} = [1.000, 0.000, 0.000, 1.000]
    LogWarn::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    StrideCodeBlockBorder::Vector{Cfloat} = [1.000, 0.000, 0.680, 1.000]
    SweepBlockBorder::Vector{Cfloat} = [1.000, 0.750, 0.000, 1.000]
    BlockAsyncBorder::Vector{Cfloat} = [0.000, 1.000, 0.000, 0.600]
    BlockObserveBG::Vector{Cfloat} = [0.000, 0.960, 1.000, 0.700]
    BlockObserveReadingBG::Vector{Cfloat} = [1.000, 0.600, 0.000, 0.700]
    BlockIcons::Vector{Cfloat} = [1.000, 0.600, 0.000, 1.000]
    ShowTextRect::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    DAQTaskRunning::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
end

Base.@kwdef mutable struct MoreStyleIcon
    File::String = ICONS.ICON_FILE
    OpenFile::String = ICONS.ICON_FILE
    OpenFolder::String = ICONS.ICON_FOLDER
    NewFile::String = ICONS.ICON_CIRCLE_PLUS
    CloseFile::String = ICONS.ICON_TRASH_CAN

    Preferences::String = ICONS.ICON_GEAR
    CommonSetting::String = ICONS.ICON_ADDRESS_BOOK
    StyleSetting::String = ICONS.ICON_PALETTE
    SaveButton::String = ICONS.ICON_FLOPPY_DISK
    SelectPath::String = ICONS.ICON_MAP

    CPUMonitor::String = ICONS.ICON_MICROCHIP

    Instrumets::String = ICONS.ICON_BIOHAZARD
    InstrumentsSetting::String = ICONS.ICON_BOOK_JOURNAL_WHILLS
    InstrumentsManualRef::String = ICONS.ICON_ROTATE
    InstrumentsAutoRef::String = ICONS.ICON_REPEAT
    ShowCol::String = ICONS.ICON_EYE

    InstrumentsOverview::String = ICONS.ICON_BOOK_BIBLE
    InstrumentsDAQ::String = ICONS.ICON_CIRCLE_RADIATION
    TaskButton::String = ICONS.ICON_FLAG
    RunTask::String = ICONS.ICON_CIRCLE_PLAY
    BlockTask::String = ICONS.ICON_CIRCLE_PAUSE
    InterruptTask::String = ICONS.ICON_CIRCLE_STOP
    Edit::String = ICONS.ICON_PEN
    Copy::String = ICONS.ICON_WINDOW_RESTORE
    Load::String = ICONS.ICON_SCREWDRIVER_WRENCH
    Rename::String = ICONS.ICON_PEN_TO_SQUARE
    Disable::String = ICONS.ICON_RECTANGLE_XMARK
    Restore::String = ICONS.ICON_RECYCLE
    ShowDisable::String = ICONS.ICON_EYE
    NotShowDisable::String = ICONS.ICON_EYE_SLASH
    SelectData::String = ICONS.ICON_CHART_AREA
    # PlotNumber::String = ICONS.ICON_CODE_BRANCH
    Datai::String = ICONS.ICON_CHART_COLUMN
    Update::String = ICONS.ICON_CLOUD_ARROW_UP
    InsertUp::String = ICONS.ICON_CIRCLE_ARROW_UP
    InsertDown::String = ICONS.ICON_CIRCLE_ARROW_DOWN
    InsertInside::String = ICONS.ICON_CIRCLE_ARROW_RIGHT
    Convert::String = ICONS.ICON_RIGHT_LEFT

    CodeBlock::String = ICONS.ICON_SITEMAP
    StrideCodeBlock::String = ICONS.ICON_RAINBOW
    SweepBlock::String = ICONS.ICON_VOLCANO
    SettingBlock::String = ICONS.ICON_GEARS
    ReadingBlock::String = ICONS.ICON_BOOK_OPEN
    LogBlock::String = ICONS.ICON_CLOUD_ARROW_DOWN
    WriteBlock::String = ICONS.ICON_UPLOAD
    QueryBlock::String = ICONS.ICON_ARROW_DOWN_UP_ACROSS_LINE
    ReadBlock::String = ICONS.ICON_DOWNLOAD
    SaveBlock::String = ICONS.ICON_FLOPPY_DISK
    Circuit::String = ICONS.ICON_MICROCHIP
    CommonNode::String = ICONS.ICON_LEFT_RIGHT
    GroundNode::String = ICONS.ICON_PLUG_CIRCLE_BOLT
    ResistanceNode::String = ICONS.ICON_ROAD_BARRIER
    TrilinkNode::String = ICONS.ICON_CODE_FORK
    SampleBaseNode::String = ICONS.ICON_MICROCHIP

    InstrumentsRegister::String = ICONS.ICON_MICROSCOPE
    InstrumentsSeach::String = ICONS.ICON_GLOBE
    InstrumentsAutoDetect::String = ICONS.ICON_CLOCK

    Help::String = ICONS.ICON_BOOK_TANAKH
    Metrics::String = ICONS.ICON_EYE
    Logger::String = ICONS.ICON_BOX_ARCHIVE
    HelpPad::String = ICONS.ICON_ENVELOPE_CIRCLE_CHECK
    About::String = ICONS.ICON_SPLOTCH
end

mutable struct ImNodesStyle
    grid_spacing::Cfloat
    node_corner_rounding::Cfloat
    node_padding_horizontal::Cfloat
    node_padding_vertical::Cfloat
    node_border_thickness::Cfloat
    link_thickness::Cfloat
    link_line_segments_per_length::Cfloat
    link_hover_distance::Cfloat
    pin_circle_radius::Cfloat
    pin_quad_side_length::Cfloat
    pin_triangle_side_length::Cfloat
    pin_line_thickness::Cfloat
    pin_hover_radius::Cfloat
    pin_offset::Cfloat
    flags::UInt32
    colors::NTuple{16,Cuint}
    function ImNodesStyle()
        vars = Any[]
        s = Ref{LibCImGui.Style}()
        for var in fieldnames(LibCImGui.Style)
            push!(vars, getproperty(s[], var))
        end
        new(vars...)
    end
end

Base.@kwdef mutable struct MoreStylePinShape
    input::LibCImGui.PinShape = LibCImGui.PinShape_Circle
    output::LibCImGui.PinShape = LibCImGui.PinShape_Triangle
end

mutable struct MoreStyle
    Colors::MoreStyleColor
    Icons::MoreStyleIcon
    PinShapes::MoreStylePinShape
    MoreStyle() = new(MoreStyleColor(), MoreStyleIcon(), MoreStylePinShape())
end

mutable struct UnionStyle
    imguistyle::LibCImGui.ImGuiStyle
    implotstyle::ImPlot.ImPlotStyle
    imnodesstyle::ImNodesStyle
    morestyle::MoreStyle
    UnionStyle() = new(Ref{LibCImGui.ImGuiStyle}()[], Ref{ImPlot.ImPlotStyle}()[], ImNodesStyle(), MoreStyle())
end

global imguistyle::Ptr{CImGui.LibCImGui.ImGuiStyle}
global implotstyle::Ptr{ImPlot.ImPlotStyle}
global imnodesstyle::Ptr{CImGui.LibCImGui.Style}
global morestyle::MoreStyle
const styles = Dict{String,UnionStyle}()

let
    nodeoutline::Bool = false
    gridlines::Bool = false
    colors::String = ""
    output_dest::Cint = 0
    output_only_modified::Bool = true
    # filter::Ptr{ImGuiTextFilter} = ImGuiTextFilter_ImGuiTextFilter(C_NULL)
    filter::String = ""
    alpha_flags::CImGui.ImGuiColorEditFlags = 0
    global function ShowStyleEditor(style_ref::ImNodesStyle)
        if @c ComBoS("Colors", &colors, ["Dark", "Light", "Classic"])
            if colors == "Dark"
                imnodes_StyleColorsDark()
            elseif colors == "Light"
                imnodes_StyleColorsLight()
            elseif colors == "Classic"
                imnodes_StyleColorsClassic()
            end
        end
        imnodesstyle = imnodes_GetStyle()
        if CImGui.Button("Save Ref")
            for var in fieldnames(LibCImGui.Style)
                var == :colors && continue
                setproperty!(style_ref, var, unsafe_load(getproperty(imnodesstyle, var)))
            end
            storecolors = Cuint[]
            for i in eachindex(instances(LibCImGui.ColorStyle)[1:end-1])
                push!(storecolors, CImGui.c_get(imnodesstyle.colors, i - 1))
            end
            style_ref.colors = (storecolors...,)
        end
        CImGui.SameLine()
        if CImGui.Button("Revert Ref")
            for var in fieldnames(LibCImGui.Style)
                var == :colors && continue
                setproperty!(imnodesstyle, var, getproperty(style_ref, var))
            end
            for i in eachindex(instances(LibCImGui.ColorStyle)[1:end-1])
                CImGui.c_set!(imnodesstyle.colors, i - 1, style_ref.colors[i])
            end
        end
        CImGui.SameLine()
        ShowHelpMarker(
            """
            Save/Revert in local non-persistent storage. 
            Default Colors definition are not affected.
            Use "Export" below to save them somewhere.
            """
        )
        if CImGui.BeginTabBar("ImNodesStyle")
            if CImGui.BeginTabItem("Variables")
                for var in fieldnames(LibCImGui.Style)
                    fieldtype(LibCImGui.Style, var) == Cfloat || continue
                    CImGui.DragFloat(string(var), getproperty(imnodesstyle, var), 1.0, 0, 120, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                end
                CImGui.CheckboxFlags("NodeOutLine", imnodesstyle.flags, LibCImGui.StyleFlags_NodeOutline)
                CImGui.SameLine()
                CImGui.CheckboxFlags("GridLines", imnodesstyle.flags, LibCImGui.StyleFlags_GridLines)
                CImGui.EndTabItem()
            end
            if CImGui.BeginTabItem("Colors")
                if CImGui.Button("Export")
                    if output_dest == 0
                        CImGui.LogToClipboard()
                    else
                        CImGui.LogToTTY()
                    end
                    CImGui.LogText("ImVec4* colors = imnodes_GetStyle().colors;\n")
                    for col in instances(LibCImGui.ColorStyle)[1:end-1]
                        if !output_only_modified || style_ref.colors[Int(col)+1] != CImGui.c_get(imnodesstyle.colors, col)
                            CImGui.LogText(string("colors[$col] = ", CImGui.c_get(imnodesstyle.colors, col), "\n"))
                        end
                    end
                    CImGui.LogFinish()
                end
                CImGui.SameLine()
                CImGui.SetNextItemWidth(120)
                @c CImGui.Combo("##output_type", &output_dest, "To Clipboard\0To TTY\0")
                CImGui.SameLine()
                @c CImGui.Checkbox("Only Modified Colors", &output_only_modified)
                # ImGuiTextFilter_Draw(filter, "Filter colors", 16CImGui.GetFontSize())
                CImGui.PushItemWidth(16CImGui.GetFontSize())
                @c InputTextRSZ("Filter colors", &filter)
                CImGui.PopItemWidth()
                if CImGui.RadioButton("Opaque", alpha_flags == ImGuiColorEditFlags_None)
                    alpha_flags = ImGuiColorEditFlags_None
                end
                CImGui.SameLine()
                if CImGui.RadioButton("Alpha", alpha_flags == ImGuiColorEditFlags_AlphaPreview)
                    alpha_flags = ImGuiColorEditFlags_AlphaPreview
                end
                CImGui.SameLine()
                if CImGui.RadioButton("Both", alpha_flags == ImGuiColorEditFlags_AlphaPreviewHalf)
                    alpha_flags = ImGuiColorEditFlags_AlphaPreviewHalf
                end
                CImGui.SameLine()
                ShowHelpMarker(
                    """
                    In the color list:
                    Left-click on color square to open color picker,
                    Right-click to open edit options menu.
                    """
                )
                CImGui.BeginChild("imnodes Colors", (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
                for col in instances(LibCImGui.ColorStyle)[1:end-1]
                    # ImGuiTextFilter_PassFilter(filter, pointer(string(col)), C_NULL) || continue
                    occursin(lowercase(filter), lowercase(string(col))) || continue
                    col_imvec4 = CImGui.ColorConvertU32ToFloat4(CImGui.c_get(imnodesstyle.colors, col))
                    col_arr = [col_imvec4.x, col_imvec4.y, col_imvec4.z, col_imvec4.w]
                    CImGui.ColorEdit4(string(col), col_arr, CImGui.ImGuiColorEditFlags_AlphaBar | alpha_flags)
                    CImGui.c_set!(imnodesstyle.colors, col, CImGui.ColorConvertFloat4ToU32(col_arr))
                    if style_ref.colors[Int(col)+1] != CImGui.c_get(imnodesstyle.colors, col)
                        CImGui.SameLine()
                        if CImGui.Button("Save")
                            style_ref.colors = newtuple(style_ref.colors, Int(col) + 1, CImGui.c_get(imnodesstyle.colors, col))
                        end
                        CImGui.SameLine()
                        if CImGui.Button("Revert")
                            CImGui.c_set!(imnodesstyle.colors, col, style_ref.colors[Int(col)+1])
                        end
                    end
                end
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            CImGui.EndTabBar()
        end
    end
end

let
    output_dest::Cint = 0
    output_only_modified::Bool = true
    # filter::Ptr{ImGuiTextFilter} = ImGuiTextFilter_ImGuiTextFilter(C_NULL)
    filter::String = ""
    alpha_flags::CImGui.ImGuiColorEditFlags = 0
    # icons_filter::Ptr{ImGuiTextFilter} = ImGuiTextFilter_ImGuiTextFilter(C_NULL)
    icons_filter::String = ""
    icon_to_clipboard::String = ""
    global function ShowStyleEditor(style_ref::MoreStyle)
        global morestyle
        if CImGui.Button("Save Ref")
            for var in fieldnames(MoreStyle)
                setproperty!(style_ref, var, deepcopy(getproperty(morestyle, var)))
            end
        end
        CImGui.SameLine()
        if CImGui.Button("Revert Ref")
            for var in fieldnames(MoreStyle)
                setproperty!(morestyle, var, deepcopy(getproperty(style_ref, var)))
            end
        end
        CImGui.SameLine()
        ShowHelpMarker(
            """
            Save/Revert in local non-persistent storage. 
            Default Colors definition are not affected.
            Use "Export" below to save them somewhere.
            """
        )
        if CImGui.BeginTabBar("MoreStyle")
            if CImGui.BeginTabItem("Colors")
                if CImGui.Button("Export")
                    if output_dest == 0
                        CImGui.LogToClipboard()
                    else
                        CImGui.LogToTTY()
                    end
                    CImGui.LogText("ImVec4* colors = imnodes_GetStyle().colors;\n")
                    for col in fieldnames(MoreStyleColor)
                        if !output_only_modified || getproperty(style_ref.Colors, col) != getproperty(morestyle.Colors, col)
                            CImGui.LogText(string("colors[$col] = ", getproperty(morestyle.Colors, col), "\n"))
                        end
                    end
                    CImGui.LogFinish()
                end
                CImGui.SameLine()
                CImGui.SetNextItemWidth(120)
                @c CImGui.Combo("##output_type", &output_dest, "To Clipboard\0To TTY\0")
                CImGui.SameLine()
                @c CImGui.Checkbox("Only Modified Colors", &output_only_modified)
                # ImGuiTextFilter_Draw(filter, "Filter colors", 16CImGui.GetFontSize())
                CImGui.PushItemWidth(16CImGui.GetFontSize())
                @c InputTextRSZ("Filter colors", &filter)
                CImGui.PopItemWidth()
                if CImGui.RadioButton("Opaque", alpha_flags == ImGuiColorEditFlags_None)
                    alpha_flags = ImGuiColorEditFlags_None
                end
                CImGui.SameLine()
                if CImGui.RadioButton("Alpha", alpha_flags == ImGuiColorEditFlags_AlphaPreview)
                    alpha_flags = ImGuiColorEditFlags_AlphaPreview
                end
                CImGui.SameLine()
                if CImGui.RadioButton("Both", alpha_flags == ImGuiColorEditFlags_AlphaPreviewHalf)
                    alpha_flags = ImGuiColorEditFlags_AlphaPreviewHalf
                end
                CImGui.SameLine()
                ShowHelpMarker(
                    """
                    In the color list:
                    Left-click on color square to open color picker,
                    Right-click to open edit options menu.
                    """
                )
                CImGui.BeginChild("Colors", (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
                for color in fieldnames(MoreStyleColor)
                    # ImGuiTextFilter_PassFilter(filter, pointer(string(color)), C_NULL) || continue
                    occursin(lowercase(filter), lowercase(string(color))) || continue
                    CImGui.ColorEdit4(string(color), getproperty(morestyle.Colors, color), CImGui.ImGuiColorEditFlags_AlphaBar | alpha_flags)
                    if getproperty(style_ref.Colors, color) != getproperty(morestyle.Colors, color)
                        CImGui.SameLine()
                        if CImGui.Button("Save")
                            setproperty!(style_ref.Colors, color, copy(getproperty(morestyle.Colors, color)))
                        end
                        CImGui.SameLine()
                        if CImGui.Button("Revert")
                            setproperty!(morestyle.Colors, color, copy(getproperty(style_ref.Colors, color)))
                        end
                    end
                end
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            if CImGui.BeginTabItem("Icons")
                icons = fieldnames(MoreStyleIcon)
                # ImGuiTextFilter_Draw(icons_filter, "Filter icons", 24CImGui.GetFontSize())
                CImGui.PushItemWidth(24CImGui.GetFontSize())
                @c InputTextRSZ("Filter icons", &icons_filter)
                CImGui.PopItemWidth()
                # CImGui.SameLine()
                # if @c IconSelector("To Clipboard", &icon_to_clipboard)
                #     CImGui.LogToClipboard()
                #     CImGui.LogText(icon_to_clipboard)
                #     CImGui.LogFinish()
                # end
                CImGui.BeginChild("Icons")
                CImGui.Columns(3, C_NULL, false)
                for icon in icons
                    # ImGuiTextFilter_PassFilter(icons_filter, pointer(string(icon)), C_NULL) || continue
                    occursin(lowercase(icons_filter), lowercase(string(icon))) || continue
                    editicon = getproperty(morestyle.Icons, icon)
                    @c IconSelector(string(icon), &editicon)
                    setproperty!(morestyle.Icons, icon, editicon)
                    CImGui.NextColumn()
                end
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            if CImGui.BeginTabItem("PinShapes")
                inpin = string(morestyle.PinShapes.input)
                if @c ComBoS("Input PinShape", &inpin, string.(instances(LibCImGui.PinShape)))
                    morestyle.PinShapes.input = getproperty(LibCImGui, Symbol(inpin))
                end
                outpin = string(morestyle.PinShapes.output)
                if @c ComBoS("Output PinShape", &outpin, string.(instances(LibCImGui.PinShape)))
                    morestyle.PinShapes.output = getproperty(LibCImGui, Symbol(outpin))
                end
                CImGui.EndTabItem()
            end
            CImGui.EndTabBar()
        end
    end
end

function loadstyle(style_ref::LibCImGui.ImGuiStyle)
    for var in fieldnames(LibCImGui.ImGuiStyle)
        var == :Colors && continue
        setproperty!(imguistyle, var, getproperty(style_ref, var))
    end
    for i in 1:CImGui.ImGuiCol_COUNT
        CImGui.c_set!(imguistyle.Colors, i - 1, style_ref.Colors[i])
    end
end
function loadstyle(style_ref::ImPlot.ImPlotStyle)
    for var in fieldnames(ImPlot.ImPlotStyle)
        var == :Colors && continue
        setproperty!(implotstyle, var, getproperty(style_ref, var))
    end
    for i in 1:ImPlot.ImPlotCol_COUNT
        CImGui.c_set!(implotstyle.Colors, i - 1, style_ref.Colors[i])
    end
end
function loadstyle(style_ref::ImNodesStyle)
    for var in fieldnames(LibCImGui.Style)
        var == :colors && continue
        setproperty!(imnodesstyle, var, getproperty(style_ref, var))
    end
    for i in eachindex(instances(LibCImGui.ColorStyle)[1:end-1])
        CImGui.c_set!(imnodesstyle.colors, i - 1, style_ref.colors[i])
    end
end
loadstyle(style_ref::MoreStyle) = (global morestyle = deepcopy(style_ref))
function loadstyle(ustyle::UnionStyle)
    for s in fieldnames(UnionStyle)
        loadstyle(getproperty(ustyle, s))
    end
end


let
    ustyle::UnionStyle = UnionStyle()
    style_name::String = ""
    nmerr::Bool = false
    selected_style::String = ""
    showmorestyle::Bool = false
    global function StyleEditor()
        # global imguistyle
        ws = CImGui.GetWindowWidth()
        styledir = conf.Style.dir
        CImGui.PushItemWidth(ws / 2)
        inputstyledir = @c InputTextRSZ("##Style-dir", &styledir)
        CImGui.SameLine()
        CImGui.PopItemWidth()
        selectstyledir = CImGui.Button(morestyle.Icons.SelectPath * "##Style-path")
        selectstyledir && (styledir = pick_folder(abspath(styledir)))
        if inputstyledir || selectstyledir
            if isfile(styledir)
                conf.Style.dir = styledir
            else
                CImGui.SameLine()
                CImGui.TextColored((1.000, 0.000, 0.000, 1.000), "路径不存在！！！")
            end
        end
        if CImGui.Button(morestyle.Icons.SaveButton * " Save to File  ")
            if rstrip(style_name, ' ') != ""
                push!(styles, style_name => ustyle)
                # jldsave(conf.Style.path, styles=styles)
                jldopen(joinpath(conf.Style.dir, "$style_name.sty"), "w") do file
                    file[style_name] = styles[style_name]
                end
                nmerr = false
            else
                nmerr = true
            end
        end
        bw = CImGui.GetItemRectSize().x
        CImGui.SameLine()
        hinttext = nmerr ? "Illegal Name" : "Style Name"
        tc = nmerr ? ImVec4(morestyle.Colors.LogError...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_TextDisabled)
        CImGui.PushStyleColor(CImGui.ImGuiCol_TextDisabled, tc)
        CImGui.PushItemWidth(ws / 2 - bw - unsafe_load(imguistyle.ItemSpacing.x))
        @c InputTextWithHintRSZ("##Input Style Name", hinttext, &style_name)
        CImGui.PopItemWidth()
        CImGui.PopStyleColor()
        CImGui.SameLine()
        CImGui.Button(morestyle.Icons.CloseFile) && CImGui.OpenPopup("##是否删除style")
        CImGui.SameLine()
        ShowHelpMarker("This operation will delete the selected imguistyle. Please be careful!")
        if YesNoDialog("##是否删除style", "确认删除？", CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            delete!(styles, selected_style)
            Base.Filesystem.rm(joinpath(conf.Style.dir, "$selected_style.sty"), force=true)
            selected_style = ""
        end
        CImGui.PushItemWidth(ws * 0.5)
        if @c ComBoS("Style", &selected_style, keys(styles))
            if selected_style != ""
                ustyle = styles[selected_style]
                style_name = selected_style
                loadstyle(ustyle)
            end
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.Button("Set as default") && (selected_style == "" || (conf.Style.default = selected_style))
        if CImGui.BeginTabBar("Style Editor")
            if CImGui.BeginTabItem("ImGui Style")
                CImGui.BeginChild("ImGui Style")
                @c CImGui.ShowStyleEditor(&ustyle.imguistyle)
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            if CImGui.BeginTabItem("ImPlot Style")
                CImGui.BeginChild("ImPlot Style")
                @c ImPlot.ShowStyleEditor(&ustyle.implotstyle)
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            if CImGui.BeginTabItem("ImNodes Style")
                CImGui.BeginChild("ImNodes Style")
                ShowStyleEditor(ustyle.imnodesstyle)
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            if CImGui.BeginTabItem("More Style")
                CImGui.BeginChild("More Style")
                ShowStyleEditor(ustyle.morestyle)
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            CImGui.EndTabBar()
        end
    end
end