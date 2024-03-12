@kwdef mutable struct MoreStyleColor
    BgImageTint::Vector{Cfloat} = [1.000, 1.000, 1.000, 0.600]
    HighlightText::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    LogInfo::Vector{Cfloat} = [0.000, 0.855, 1.000, 1.000]
    LogError::Vector{Cfloat} = [1.000, 0.000, 0.000, 1.000]
    LogWarn::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    SweepQuantityBt::Vector{Cfloat} = [0.000, 1.000, 1.000, 0.400]
    SetQuantityBt::Vector{Cfloat} = [1.000, 1.000, 0.000, 0.400]
    ReadQuantityBt::Vector{Cfloat} = [1.000, 0.000, 1.000, 0.400]
    SweepQuantityTxt::Vector{Cfloat} = [1.000, 0.000, 0.000, 1.000]
    SetQuantityTxt::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
    ReadQuantityTxt::Vector{Cfloat} = [0.000, 0.000, 1.000, 1.000]
    ControlButtonPause::Vector{Cfloat} = [0.000, 0.000, 1.000, 1.000]
    StrideCodeBlockBorder::Vector{Cfloat} = [1.000, 0.000, 0.680, 1.000]
    SweepBlockBorder::Vector{Cfloat} = [1.000, 0.750, 0.000, 1.000]
    NormalBlockBorder::Vector{Cfloat} = [1.000, 1.000, 1.000, 0.600]
    BlockAsyncBorder::Vector{Cfloat} = [0.000, 1.000, 0.000, 0.600]
    BlockObserveBG::Vector{Cfloat} = [0.000, 0.960, 1.000, 0.700]
    BlockObserveReadingBG::Vector{Cfloat} = [1.000, 0.600, 0.000, 0.700]
    BlockIcons::Vector{Cfloat} = [1.000, 0.600, 0.000, 1.000]
    BlockTrycatch::Vector{Cfloat} = [1.000, 0.000, 0.000, 1.000]
    BlockDragdrop::Vector{Cfloat} = [0.000, 0.000, 1.000, 0.400]
    ShowTextRect::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    DAQTaskRunning::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
    DAQTaskToRun::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.400]
    NodeConnected::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
    ImagePin::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    ImagePinHoveredout::Vector{Cfloat} = [0.000, 0.000, 1.000, 1.000]
    ImagePinDragging::Vector{Cfloat} = [1.000, 0.000, 0.000, 1.000]
    ImagePinLinkId::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    ToggleButtonOn::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
    ToggleButtonOff::Vector{Cfloat} = [0.600, 0.600, 0.600, 1.000]
    SelectedWidgetBt::Vector{Cfloat} = [0.600, 0.600, 0.000, 0.600]
    ItemBorder::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    FormatDataBorder::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    FormatDataGroupBorder::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    WidgetRect::Vector{Cfloat} = [1.000, 1.000, 1.000, 0.200]
    WidgetRectHovered::Vector{Cfloat} = [1.000, 1.000, 1.000, 0.400]
    WidgetRectDragging::Vector{Cfloat} = [1.000, 1.000, 1.000, 0.600]
    WidgetRectSelected::Vector{Cfloat} = [0.000, 0.000, 1.000, 0.600]
    WidgetBorder::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.200]
    WidgetBorderHovered::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.400]
    WidgetBorderDragging::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.600]
    WidgetBorderSelected::Vector{Cfloat} = [0.000, 1.000, 0.000, 1.000]
    ToolBarBg::Vector{Cfloat} = [0.000, 0.000, 0.000, 0.400]
    IconButton::Vector{Cfloat} = [0.000, 0.320, 0.574, 1.000]
end

@kwdef mutable struct MoreStyleIcon
    File::String = ICONS.ICON_FILE
    OpenFile::String = ICONS.ICON_FILE
    OpenFolder::String = ICONS.ICON_FOLDER
    NewFile::String = ICONS.ICON_CIRCLE_PLUS
    CloseFile::String = ICONS.ICON_TRASH_CAN
    DataFormatter::String = ICONS.ICON_FILE_EXPORT

    Preferences::String = ICONS.ICON_GEAR
    CommonSetting::String = ICONS.ICON_ADDRESS_BOOK
    StyleSetting::String = ICONS.ICON_PALETTE
    SaveButton::String = ICONS.ICON_FLOPPY_DISK
    SelectPath::String = ICONS.ICON_MAP

    CPUMonitor::String = ICONS.ICON_COMPUTER

    Instruments::String = ICONS.ICON_BIOHAZARD
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
    View::String = ICONS.ICON_EYE
    Edit::String = ICONS.ICON_PEN
    Copy::String = ICONS.ICON_WINDOW_RESTORE
    Paste::String = ICONS.ICON_PASTE
    Load::String = ICONS.ICON_SCREWDRIVER_WRENCH
    Rename::String = ICONS.ICON_PEN_TO_SQUARE
    Undo::String = ICONS.ICON_ROTATE_LEFT
    Redo::String = ICONS.ICON_ROTATE_RIGHT
    Plot::String = ICONS.ICON_CHART_AREA
    Datai::String = ICONS.ICON_CHART_COLUMN
    Update::String = ICONS.ICON_CLOUD_ARROW_UP
    InsertUp::String = ICONS.ICON_CIRCLE_ARROW_UP
    InsertDown::String = ICONS.ICON_CIRCLE_ARROW_DOWN
    InsertInside::String = ICONS.ICON_CIRCLE_ARROW_RIGHT
    Convert::String = ICONS.ICON_RIGHT_LEFT

    CodeBlock::String = ICONS.ICON_SITEMAP
    StrideCodeBlock::String = ICONS.ICON_RAINBOW
    BranchBlock::String = ICONS.ICON_CODE_BRANCH
    SweepBlock::String = ICONS.ICON_VOLCANO
    SettingBlock::String = ICONS.ICON_GEARS
    ReadingBlock::String = ICONS.ICON_BOOK_OPEN
    LogBlock::String = ICONS.ICON_CLOUD_ARROW_DOWN
    WriteBlock::String = ICONS.ICON_UPLOAD
    QueryBlock::String = ICONS.ICON_ARROW_DOWN_UP_ACROSS_LINE
    ReadBlock::String = ICONS.ICON_DOWNLOAD
    FeedbackBlock::String = ICONS.ICON_RECYCLE

    Circuit::String = ICONS.ICON_MICROCHIP
    ResetCoord::String = ICONS.ICON_UP_DOWN_LEFT_RIGHT
    UniversalNode::String = ICONS.ICON_LEFT_RIGHT
    GroundNode::String = ICONS.ICON_PLUG_CIRCLE_BOLT
    ResistanceNode::String = ICONS.ICON_ROAD_BARRIER
    Trilink21Node::String = ICONS.ICON_CODE_FORK
    Trilink12Node::String = ICONS.ICON_CODE_FORK
    SampleHolderNode::String = ICONS.ICON_MICROCHIP

    InstrumentsRegister::String = ICONS.ICON_MICROSCOPE
    InstrumentsSeach::String = ICONS.ICON_GLOBE
    InstrumentsAutoDetect::String = ICONS.ICON_MAGNIFYING_GLASS

    HoldPin::String = ICONS.ICON_TROWEL

    Help::String = ICONS.ICON_BOOK_TANAKH
    Console::String = ICONS.ICON_COMPUTER
    SendMsg::String = ICONS.ICON_PAPER_PLANE
    Metrics::String = ICONS.ICON_EYE
    Logger::String = ICONS.ICON_BOX_ARCHIVE
    CopyIcon::String = ICONS.ICON_SQUARE_VIRUS
    HelpPad::String = ICONS.ICON_ENVELOPE_CIRCLE_CHECK
    About::String = ICONS.ICON_SPLOTCH
end

mutable struct ImNodesStyle
    GridSpacing::Cfloat
    NodeCornerRounding::Cfloat
    NodePadding::ImVec2
    NodeBorderThickness::Cfloat
    LinkThickness::Cfloat
    LinkLineSegmentsPerLength::Cfloat
    LinkHoverDistance::Cfloat
    PinCircleRadius::Cfloat
    PinQuadSideLength::Cfloat
    PinTriangleSideLength::Cfloat
    PinLineThickness::Cfloat
    PinHoverRadius::Cfloat
    PinOffset::Cfloat
    MiniMapPadding::ImVec2
    MiniMapOffset::ImVec2
    Flags::ImNodesStyleFlags
    Colors::NTuple{29,Cuint}
    function ImNodesStyle()
        vars = Any[]
        s = Ref{LibCImGui.ImNodesStyle}()
        for var in fieldnames(LibCImGui.ImNodesStyle)
            push!(vars, getproperty(s[], var))
        end
        new(vars...)
    end
end

@kwdef mutable struct MoreStyleVariable
    TextRectRounding::Cfloat = 0
    TextRectThickness::Cfloat = 2
    TextRectPadding::Vector{Cfloat} = [6, 6]
    PinShapeInput::LibCImGui.ImNodesPinShape = LibCImGui.ImNodesPinShape_Circle
    PinShapeOutput::LibCImGui.ImNodesPinShape = LibCImGui.ImNodesPinShape_Triangle
    MiniMapFraction::Cfloat = 0.2
    MiniMapLocation::LibCImGui.ImNodesMiniMapLocation = LibCImGui.ImNodesMiniMapLocation_TopRight
    ImPlotMarker::Cint = 0
end

@kwdef mutable struct MoreStyle
    Variables::MoreStyleVariable = MoreStyleVariable()
    Colors::MoreStyleColor = MoreStyleColor()
    Icons::MoreStyleIcon = MoreStyleIcon()
end

@kwdef mutable struct UnionStyle
    imguistyle::LibCImGui.ImGuiStyle = Ref{LibCImGui.ImGuiStyle}()[]
    implotstyle::ImPlot.ImPlotStyle = Ref{ImPlot.ImPlotStyle}()[]
    imnodesstyle::ImNodesStyle = ImNodesStyle()
    morestyle::MoreStyle = MoreStyle()
end

global IMGUISTYLE::Ptr{CImGui.LibCImGui.ImGuiStyle}
global IMPLOTSTYLE::Ptr{ImPlot.ImPlotStyle}
global IMNODESSTYLE::Ptr{CImGui.LibCImGui.ImNodesStyle}
global MORESTYLE::MoreStyle
const STYLES = Dict{String,UnionStyle}()

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
                imnodes_StyleColorsDark(IMNODESSTYLE)
            elseif colors == "Light"
                imnodes_StyleColorsLight(IMNODESSTYLE)
            elseif colors == "Classic"
                imnodes_StyleColorsClassic(IMNODESSTYLE)
            end
        end
        # imnodesstyle = imnodes_GetStyle()
        if CImGui.Button("Save Ref")
            for var in fieldnames(LibCImGui.ImNodesStyle)
                var == :Colors && continue
                setproperty!(style_ref, var, unsafe_load(getproperty(IMNODESSTYLE, var)))
            end
            storecolors = Cuint[]
            for i in eachindex(instances(LibCImGui.ImNodesCol_)[1:end-1])
                push!(storecolors, CImGui.c_get(IMNODESSTYLE.Colors, i - 1))
            end
            style_ref.Colors = (storecolors...,)
        end
        CImGui.SameLine()
        if CImGui.Button("Revert Ref")
            for var in fieldnames(LibCImGui.ImNodesStyle)
                var == :Colors && continue
                setproperty!(IMNODESSTYLE, var, getproperty(style_ref, var))
            end
            for i in eachindex(instances(LibCImGui.ImNodesCol_)[1:end-1])
                CImGui.c_set!(IMNODESSTYLE.Colors, i - 1, style_ref.Colors[i])
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
                for var in fieldnames(LibCImGui.ImNodesStyle)
                    if fieldtype(LibCImGui.ImNodesStyle, var) == Cfloat
                        CImGui.DragFloat(
                            stcstr(var),
                            getproperty(IMNODESSTYLE, var),
                            1.0, 0, 120, "%.3f",
                            CImGui.ImGuiSliderFlags_AlwaysClamp
                        )
                    elseif fieldtype(LibCImGui.ImNodesStyle, var) == ImVec2
                        CImGui.DragFloat2(
                            stcstr(var),
                            getproperty(IMNODESSTYLE, var),
                            1.0, 0, 120, "%.3f",
                            CImGui.ImGuiSliderFlags_AlwaysClamp
                        )
                    end
                end
                for flag in instances(LibCImGui.ImNodesStyleFlags_)
                    CImGui.CheckboxFlags(stcstr(flag), IMNODESSTYLE.Flags, flag)
                end
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
                    for col in instances(LibCImGui.ImNodesCol_)[1:end-1]
                        if !output_only_modified || style_ref.Colors[Int(col)+1] != CImGui.c_get(IMNODESSTYLE.Colors, col)
                            CImGui.LogText(string("colors[$col] = ", CImGui.c_get(IMNODESSTYLE.Colors, col), "\n"))
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
                for col in instances(LibCImGui.ImNodesCol_)[1:end-1]
                    # ImGuiTextFilter_PassFilter(filter, pointer(string(col)), C_NULL) || continue
                    (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(string(col)))) || continue
                    col_imvec4 = CImGui.ColorConvertU32ToFloat4(CImGui.c_get(IMNODESSTYLE.Colors, col))
                    col_arr = [col_imvec4.x, col_imvec4.y, col_imvec4.z, col_imvec4.w]
                    CImGui.ColorEdit4(stcstr(col), col_arr, CImGui.ImGuiColorEditFlags_AlphaBar | alpha_flags)
                    CImGui.c_set!(IMNODESSTYLE.Colors, col, CImGui.ColorConvertFloat4ToU32(col_arr))
                    if style_ref.Colors[Int(col)+1] != CImGui.c_get(IMNODESSTYLE.Colors, col)
                        CImGui.SameLine()
                        if CImGui.Button("Save")
                            style_ref.Colors = newtuple(
                                style_ref.Colors,
                                Int(col) + 1,
                                CImGui.c_get(IMNODESSTYLE.Colors, col)
                            )
                        end
                        CImGui.SameLine()
                        if CImGui.Button("Revert")
                            CImGui.c_set!(IMNODESSTYLE.Colors, col, style_ref.Colors[Int(col)+1])
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
        global MORESTYLE
        if CImGui.Button("Save Ref")
            for var in fieldnames(MoreStyle)
                setproperty!(style_ref, var, deepcopy(getproperty(MORESTYLE, var)))
            end
        end
        CImGui.SameLine()
        if CImGui.Button("Revert Ref")
            for var in fieldnames(MoreStyle)
                setproperty!(MORESTYLE, var, deepcopy(getproperty(style_ref, var)))
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
            if CImGui.BeginTabItem("Variables")
                @c CImGui.DragFloat(
                    "TextRectRounding", &MORESTYLE.Variables.TextRectRounding,
                    1, 0, 60, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                @c CImGui.DragFloat(
                    "TextRectThickness", &MORESTYLE.Variables.TextRectThickness,
                    1, 0, 60, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.DragFloat2(
                    "TextRectPadding", MORESTYLE.Variables.TextRectPadding,
                    1, 0, 60, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                inpin = string(LibCImGui.ImNodesPinShape_(MORESTYLE.Variables.PinShapeInput))
                if @c ComBoS("Input PinShape", &inpin, string.(instances(LibCImGui.ImNodesPinShape_)))
                    MORESTYLE.Variables.PinShapeInput = getproperty(LibCImGui, Symbol(inpin))
                end
                outpin = string(LibCImGui.ImNodesPinShape_(MORESTYLE.Variables.PinShapeOutput))
                if @c ComBoS("Output PinShape", &outpin, string.(instances(LibCImGui.ImNodesPinShape_)))
                    MORESTYLE.Variables.PinShapeOutput = getproperty(LibCImGui, Symbol(outpin))
                end
                selectedmarker = unsafe_string(ImPlot.GetMarkerName(MORESTYLE.Variables.ImPlotMarker))
                implotmarkerlist = [unsafe_string(ImPlot.GetMarkerName(i - 1)) for i in 1:ImPlot.ImPlotMarker_COUNT]
                @c CImGui.DragFloat(
                    "Minimap Fraction",
                    &MORESTYLE.Variables.MiniMapFraction,
                    0.1, 0.1, 1, "%.1f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                minimaplocation = string(LibCImGui.ImNodesMiniMapLocation_(MORESTYLE.Variables.MiniMapLocation))
                if @c ComBoS("Minimap Location", &minimaplocation, string.(instances(LibCImGui.ImNodesMiniMapLocation_)))
                    MORESTYLE.Variables.MiniMapLocation = getproperty(LibCImGui, Symbol(minimaplocation))
                end
                if @c ComBoS("ImPlotMarker", &selectedmarker, implotmarkerlist)
                    MORESTYLE.Variables.ImPlotMarker = findfirst(==(selectedmarker), implotmarkerlist) - 1
                    IMPLOTSTYLE.Marker = MORESTYLE.Variables.ImPlotMarker
                end
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
                    for col in fieldnames(MoreStyleColor)
                        if !output_only_modified || getproperty(style_ref.Colors, col) != getproperty(MORESTYLE.Colors, col)
                            CImGui.LogText(string("colors[$col] = ", getproperty(MORESTYLE.Colors, col), "\n"))
                        end
                    end
                    CImGui.LogFinish()
                end
                CImGui.SameLine()
                CImGui.SetNextItemWidth(120)
                @c CImGui.Combo("##output_type", &output_dest, "To Clipboard\0To TTY\0")
                CImGui.SameLine()
                @c CImGui.Checkbox("Only Modified Colors", &output_only_modified)
                # ImGuiTextFilter_Draw(filter, pointer("Filter colors"), 16CImGui.GetFontSize())
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
                    (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(string(color)))) || continue
                    CImGui.ColorEdit4(
                        stcstr(color),
                        getproperty(MORESTYLE.Colors, color),
                        CImGui.ImGuiColorEditFlags_AlphaBar | alpha_flags
                    )
                    if getproperty(style_ref.Colors, color) != getproperty(MORESTYLE.Colors, color)
                        CImGui.SameLine()
                        if CImGui.Button("Save")
                            setproperty!(style_ref.Colors, color, copy(getproperty(MORESTYLE.Colors, color)))
                        end
                        CImGui.SameLine()
                        if CImGui.Button("Revert")
                            setproperty!(MORESTYLE.Colors, color, copy(getproperty(style_ref.Colors, color)))
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
                    editicon = getproperty(MORESTYLE.Icons, icon)
                    @c IconSelector(stcstr(icon), &editicon)
                    setproperty!(MORESTYLE.Icons, icon, editicon)
                    CImGui.NextColumn()
                end
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            CImGui.EndTabBar()
        end
    end
end

function loadstyle(style_ref::LibCImGui.ImGuiStyle)
    for var in fieldnames(LibCImGui.ImGuiStyle)
        var == :Colors && continue
        setproperty!(IMGUISTYLE, var, getproperty(style_ref, var))
    end
    for i in 1:CImGui.ImGuiCol_COUNT
        CImGui.c_set!(IMGUISTYLE.Colors, i - 1, style_ref.Colors[i])
    end
end
function loadstyle(style_ref::ImPlot.ImPlotStyle)
    for var in fieldnames(ImPlot.ImPlotStyle)
        var == :Colors && continue
        setproperty!(IMPLOTSTYLE, var, getproperty(style_ref, var))
    end
    for i in 1:ImPlot.ImPlotCol_COUNT
        CImGui.c_set!(IMPLOTSTYLE.Colors, i - 1, style_ref.Colors[i])
    end
end
function loadstyle(style_ref::ImNodesStyle)
    for var in fieldnames(LibCImGui.ImNodesStyle)
        var == :Colors && continue
        setproperty!(IMNODESSTYLE, var, getproperty(style_ref, var))
    end
    for i in eachindex(instances(LibCImGui.ImNodesCol_)[1:end-1])
        CImGui.c_set!(IMNODESSTYLE.Colors, i - 1, style_ref.Colors[i])
    end
end
loadstyle(style_ref::MoreStyle) = (global MORESTYLE = deepcopy(style_ref); IMPLOTSTYLE.Marker = MORESTYLE.Variables.ImPlotMarker)
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
        styledir = CONF.Style.dir
        CImGui.PushItemWidth(ws / 2)
        inputstyledir = @c InputTextRSZ("##Style-dir", &styledir)
        CImGui.SameLine()
        CImGui.PopItemWidth()
        selectstyledir = CImGui.Button(MORESTYLE.Icons.SelectPath * "##Style-path")
        selectstyledir && (styledir = pick_folder(abspath(styledir)))
        if inputstyledir || selectstyledir
            if isfile(styledir)
                CONF.Style.dir = styledir
            else
                CImGui.SameLine()
                CImGui.TextColored((1.000, 0.000, 0.000, 1.000), "path does not exist!!!")
            end
        end
        if CImGui.Button(MORESTYLE.Icons.SaveButton * " Save to File  ")
            if rstrip(style_name, ' ') != ""
                push!(STYLES, style_name => ustyle)
                # jldsave(conf.Style.path, styles=styles)
                jldopen(joinpath(CONF.Style.dir, "$style_name.sty"), "w") do file
                    file[style_name] = STYLES[style_name]
                end
                nmerr = false
            else
                nmerr = true
            end
        end
        bw = CImGui.GetItemRectSize().x
        CImGui.SameLine()
        hinttext = nmerr ? "Illegal Name" : "Style Name"
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_TextDisabled,
            nmerr ? MORESTYLE.Colors.LogError : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled)
        )
        CImGui.PushItemWidth(ws / 2 - bw - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c InputTextWithHintRSZ("##Input Style Name", hinttext, &style_name)
        CImGui.PopItemWidth()
        CImGui.PopStyleColor()
        CImGui.SameLine()
        CImGui.Button(MORESTYLE.Icons.CloseFile) && CImGui.OpenPopup("##if delete style")
        CImGui.SameLine()
        ShowHelpMarker("This operation will delete the selected IMGUISTYLE. Please be careful!")
        if YesNoDialog("##if delete style", mlstr("confirm delete?"), CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            delete!(STYLES, selected_style)
            Base.Filesystem.rm(joinpath(CONF.Style.dir, "$selected_style.sty"), force=true)
            selected_style = ""
        end

        ###wallpaper###
        bgpath = CONF.BGImage.path
        CImGui.PushItemWidth(ws / 2)
        inputbgpath = @c InputTextRSZ("##BGImage-path", &bgpath)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        selectbgpath = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##BGImage-path"))
        selectbgpath && (bgpath = pick_file(abspath(bgpath); filterlist="png,jpg,jpeg,tif,bmp,gif"))
        CImGui.SameLine()
        @c CImGui.Checkbox("##useall", &CONF.BGImage.useall)
        ItemTooltip("apply to all the windows ?")
        CImGui.SameLine()
        CImGui.Text("Wallpaper")
        if inputbgpath || selectbgpath
            if isfile(bgpath)
                CONF.BGImage.path = bgpath
            else
                CImGui.SameLine()
                CImGui.TextColored(MORESTYLE.Colors.LogError, mlstr("path does not exist!!!"))
            end
        end
        if CONF.BGImage.useall
            @c CImGui.DragInt("Rate", &CONF.BGImage.rate, 1, 1, 120, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
        end

        CImGui.PushItemWidth(ws / 2)
        selected_style == "" && haskey(STYLES, CONF.Style.default) && (selected_style = CONF.Style.default; ustyle = STYLES[selected_style])
        if @c ComBoS("##Style Selecting", &selected_style, keys(STYLES))
            if selected_style != ""
                ustyle = STYLES[selected_style]
                style_name = selected_style
                loadstyle(ustyle)
            end
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.Button("Set as default") && (selected_style == "" || (CONF.Style.default = selected_style))
        CImGui.SameLine()
        CImGui.Text("Style")
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