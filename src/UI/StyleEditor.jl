@option mutable struct QImGuiColors
    Text::Vector{Cfloat} = [1.00, 1.00, 1.00, 1.00]
    TextDisabled::Vector{Cfloat} = [0.50, 0.50, 0.50, 1.00]
    WindowBg::Vector{Cfloat} = [0.06, 0.06, 0.06, 0.94]
    ChildBg::Vector{Cfloat} = [0.00, 0.00, 0.00, 0.00]
    PopupBg::Vector{Cfloat} = [0.08, 0.08, 0.08, 0.94]
    Border::Vector{Cfloat} = [0.43, 0.43, 0.50, 0.50]
    BorderShadow::Vector{Cfloat} = [0.00, 0.00, 0.00, 0.00]
    FrameBg::Vector{Cfloat} = [0.16, 0.29, 0.48, 0.54]
    FrameBgHovered::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.40]
    FrameBgActive::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.67]
    TitleBg::Vector{Cfloat} = [0.04, 0.04, 0.04, 1.00]
    TitleBgActive::Vector{Cfloat} = [0.16, 0.29, 0.48, 1.00]
    TitleBgCollapsed::Vector{Cfloat} = [0.00, 0.00, 0.00, 0.51]
    MenuBarBg::Vector{Cfloat} = [0.14, 0.14, 0.14, 1.00]
    ScrollbarBg::Vector{Cfloat} = [0.02, 0.02, 0.02, 0.53]
    ScrollbarGrab::Vector{Cfloat} = [0.31, 0.31, 0.31, 1.00]
    ScrollbarGrabHovered::Vector{Cfloat} = [0.41, 0.41, 0.41, 1.00]
    ScrollbarGrabActive::Vector{Cfloat} = [0.51, 0.51, 0.51, 1.00]
    CheckMark::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.00]
    SliderGrab::Vector{Cfloat} = [0.24, 0.52, 0.88, 1.00]
    SliderGrabActive::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.00]
    Button::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.40]
    ButtonHovered::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.00]
    ButtonActive::Vector{Cfloat} = [0.06, 0.53, 0.98, 1.00]
    Header::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.31]
    HeaderHovered::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.80]
    HeaderActive::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.00]
    Separator::Vector{Cfloat} = [0.43, 0.43, 0.50, 0.50]
    SeparatorHovered::Vector{Cfloat} = [0.10, 0.40, 0.75, 0.78]
    SeparatorActive::Vector{Cfloat} = [0.10, 0.40, 0.75, 1.00]
    ResizeGrip::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.20]
    ResizeGripHovered::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.67]
    ResizeGripActive::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.95]
    TabHovered::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.80]
    Tab::Vector{Cfloat} = [0.18, 0.35, 0.58, 0.86]
    TabSelected::Vector{Cfloat} = [0.20, 0.41, 0.68, 1.00]
    TabSelectedOverline::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.00]
    TabDimmed::Vector{Cfloat} = [0.07, 0.10, 0.15, 0.97]
    TabDimmedSelected::Vector{Cfloat} = [0.14, 0.26, 0.42, 1.00]
    TabDimmedSelectedOverline::Vector{Cfloat} = [0.50, 0.50, 0.50, 1.00]
    DockingPreview::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.70]
    DockingEmptyBg::Vector{Cfloat} = [0.20, 0.20, 0.20, 1.00]
    PlotLines::Vector{Cfloat} = [0.61, 0.61, 0.61, 1.00]
    PlotLinesHovered::Vector{Cfloat} = [1.00, 0.43, 0.35, 1.00]
    PlotHistogram::Vector{Cfloat} = [0.90, 0.70, 0.00, 1.00]
    PlotHistogramHovered::Vector{Cfloat} = [1.00, 0.60, 0.00, 1.00]
    TableHeaderBg::Vector{Cfloat} = [0.19, 0.19, 0.20, 1.00]
    TableBorderStrong::Vector{Cfloat} = [0.31, 0.31, 0.35, 1.00]
    TableBorderLight::Vector{Cfloat} = [0.23, 0.23, 0.25, 1.00]
    TableRowBg::Vector{Cfloat} = [0.00, 0.00, 0.00, 0.00]
    TableRowBgAlt::Vector{Cfloat} = [1.00, 1.00, 1.00, 0.06]
    TextLink::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.00]
    TextSelectedBg::Vector{Cfloat} = [0.26, 0.59, 0.98, 0.35]
    DragDropTarget::Vector{Cfloat} = [1.00, 1.00, 0.00, 0.90]
    NavHighlight::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.00]
    NavWindowingHighlight::Vector{Cfloat} = [1.00, 1.00, 1.00, 0.70]
    NavWindowingDimBg::Vector{Cfloat} = [0.80, 0.80, 0.80, 0.20]
    ModalWindowDimBg::Vector{Cfloat} = [0.80, 0.80, 0.80, 0.35]
end
Base.getindex(x::QImGuiColors, i::Int) = getproperty(x, fieldnames(QImGuiColors)[i])
Base.setindex!(x::QImGuiColors, v, i::Int) = setproperty!(x, fieldnames(QImGuiColors)[i], v)
@option mutable struct QImGuiStyle
    Alpha::Cfloat = 0.3
    DisabledAlpha::Cfloat = 0.6
    WindowPadding::Vector{Cfloat} = [8, 8]
    WindowRounding::Cfloat = 0
    WindowBorderSize::Cfloat = 1
    WindowMinSize::Vector{Cfloat} = [6, 6]
    WindowTitleAlign::Vector{Cfloat} = [0.0, 0.5]
    WindowMenuButtonPosition::Int32 = ImGuiDir_Left
    ChildRounding::Cfloat = 0
    ChildBorderSize::Cfloat = 1
    PopupRounding::Cfloat = 0
    PopupBorderSize::Cfloat = 1
    FramePadding::Vector{Cfloat} = [4, 3]
    FrameRounding::Cfloat = 0
    FrameBorderSize::Cfloat = 0
    ItemSpacing::Vector{Cfloat} = [8, 4]
    ItemInnerSpacing::Vector{Cfloat} = [4, 4]
    CellPadding::Vector{Cfloat} = [4, 2]
    TouchExtraPadding::Vector{Cfloat} = [0, 0]
    IndentSpacing::Cfloat = 21
    ColumnsMinSpacing::Cfloat = 6
    ScrollbarSize::Cfloat = 14
    ScrollbarRounding::Cfloat = 9
    GrabMinSize::Cfloat = 6
    GrabRounding::Cfloat = 0
    LogSliderDeadzone::Cfloat = 4
    TabRounding::Cfloat = 4
    TabBorderSize::Cfloat = 0
    TabMinWidthForCloseButton::Cfloat = 12
    TabBarBorderSize::Cfloat = 1
    TabBarOverlineSize::Cfloat = 2
    TableAngledHeadersAngle::Cfloat = 35
    TableAngledHeadersTextAlign::Vector{Cfloat} = [0.5, 0.0]
    ColorButtonPosition::Int32 = ImGuiDir_Right
    ButtonTextAlign::Vector{Cfloat} = [0.5, 0.5]
    SelectableTextAlign::Vector{Cfloat} = [0, 0]
    SeparatorTextBorderSize::Cfloat = 3
    SeparatorTextAlign::Vector{Cfloat} = [0.0, 0.5]
    SeparatorTextPadding::Vector{Cfloat} = [20, 3]
    DisplayWindowPadding::Vector{Cfloat} = [19, 19]
    DisplaySafeAreaPadding::Vector{Cfloat} = [3, 3]
    DockingSeparatorSize::Cfloat = 2
    MouseCursorScale::Cfloat = 1
    AntiAliasedLines::Bool = true
    AntiAliasedLinesUseTex::Bool = true
    AntiAliasedFill::Bool = true
    CurveTessellationTol::Cfloat = 1.25
    CircleTessellationMaxError::Cfloat = 0.3
    Colors::QImGuiColors = QImGuiColors()
    HoverStationaryDelay::Cfloat = 0
    HoverDelayShort::Cfloat = 0
    HoverDelayNormal::Cfloat = 0
    HoverFlagsForTooltipMouse::ImGuiHoveredFlags = ImGuiHoveredFlags_None
    HoverFlagsForTooltipNav::ImGuiHoveredFlags = ImGuiHoveredFlags_None
end
Base.convert(::Type{ImGuiDir}, x::Int32) = ImGuiDir(x)
function Base.convert(::Type{QImGuiStyle}, x::Ptr{ImGuiStyle})
    nx = QImGuiStyle()
    for var in fieldnames(ImGuiStyle)
        var == :Colors && continue
        setproperty!(nx, var, unsafe_load(getproperty(x, var)))
    end
    for i in 1:CImGui.ImGuiCol_COUNT
        nx.Colors[i] = CImGui.c_get(x.Colors, i - 1)
    end
    nx
end
function Base.convert(::Type{Ptr{ImGuiStyle}}, x::QImGuiStyle)
    nx = ImGuiStyle_ImGuiStyle()
    for var in fieldnames(ImGuiStyle)
        var == :Colors && continue
        setproperty!(nx, var, getproperty(x, var))
    end
    for i in 1:CImGui.ImGuiCol_COUNT
        CImGui.c_set!(nx.Colors, i - 1, x.Colors[i])
    end
    nx
end

@option mutable struct QImNodesColors
    NodeBackground::Vector{Cfloat} = [0.2, 0.2, 0.2, 1.0]
    NodeBackgroundHovered::Vector{Cfloat} = [0.29, 0.29, 0.29, 1.0]
    NodeBackgroundSelected::Vector{Cfloat} = [0.29, 0.29, 0.29, 1.0]
    NodeOutline::Vector{Cfloat} = [0.39, 0.39, 0.39, 1.0]
    TitleBar::Vector{Cfloat} = [0.16, 0.29, 0.48, 1.0]
    TitleBarHovered::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.0]
    TitleBarSelected::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.0]
    Link::Vector{Cfloat} = [0.24, 0.52, 0.88, 0.78]
    LinkHovered::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.0]
    LinkSelected::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.0]
    Pin::Vector{Cfloat} = [0.21, 0.59, 0.98, 0.71]
    PinHovered::Vector{Cfloat} = [0.21, 0.59, 0.98, 1.0]
    BoxSelector::Vector{Cfloat} = [0.24, 0.52, 0.88, 0.12]
    BoxSelectorOutline::Vector{Cfloat} = [0.24, 0.52, 0.88, 0.59]
    GridBackground::Vector{Cfloat} = [0.16, 0.16, 0.2, 0.78]
    GridLine::Vector{Cfloat} = [0.78, 0.78, 0.78, 0.16]
    GridLinePrimary::Vector{Cfloat} = [0.94, 0.94, 0.94, 0.24]
    MiniMapBackground::Vector{Cfloat} = [0.1, 0.1, 0.1, 0.59]
    MiniMapBackgroundHovered::Vector{Cfloat} = [0.1, 0.1, 0.1, 0.78]
    MiniMapOutline::Vector{Cfloat} = [0.59, 0.59, 0.59, 0.39]
    MiniMapOutlineHovered::Vector{Cfloat} = [0.59, 0.59, 0.59, 0.78]
    MiniMapNodeBackground::Vector{Cfloat} = [0.78, 0.78, 0.78, 0.39]
    MiniMapNodeBackgroundHovered::Vector{Cfloat} = [0.78, 0.78, 0.78, 1.0]
    MiniMapNodeBackgroundSelected::Vector{Cfloat} = [0.78, 0.78, 0.78, 1.0]
    MiniMapNodeOutline::Vector{Cfloat} = [0.78, 0.78, 0.78, 0.39]
    MiniMapLink::Vector{Cfloat} = [0.24, 0.52, 0.88, 0.78]
    MiniMapLinkSelected::Vector{Cfloat} = [0.26, 0.59, 0.98, 1.0]
    MiniMapCanvas::Vector{Cfloat} = [0.78, 0.78, 0.78, 0.1]
    MiniMapCanvasOutline::Vector{Cfloat} = [0.78, 0.78, 0.78, 0.78]
end
Base.getindex(x::QImNodesColors, i::Int) = getproperty(x, fieldnames(QImNodesColors)[i])
Base.setindex!(x::QImNodesColors, v, i::Int) = setproperty!(x, fieldnames(QImNodesColors)[i], v)
@option mutable struct QImNodesStyle
    GridSpacing::Cfloat = 24
    NodeCornerRounding::Cfloat = 4
    NodePadding::Vector{Cfloat} = [8, 8]
    NodeBorderThickness::Cfloat = 1
    LinkThickness::Cfloat = 3
    LinkLineSegmentsPerLength::Cfloat = 0.1
    LinkHoverDistance::Cfloat = 10
    PinCircleRadius::Cfloat = 4
    PinQuadSideLength::Cfloat = 7
    PinTriangleSideLength::Cfloat = 9.5
    PinLineThickness::Cfloat = 1
    PinHoverRadius::Cfloat = 10
    PinOffset::Cfloat = 0
    MiniMapPadding::Vector{Cfloat} = [8, 8]
    MiniMapOffset::Vector{Cfloat} = [4, 4]
    Flags::ImNodesStyleFlags = ImNodesStyleFlags_NodeOutline | ImNodesStyleFlags_GridLines
    Colors::QImNodesColors = QImNodesColors()
end

@option mutable struct MoreStyleColor
    ClearColor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
    BgImageTint::Vector{Cfloat} = [1.000, 1.000, 1.000, 0.600]
    HighlightText::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    InfoText::Vector{Cfloat} = [0.000, 0.855, 1.000, 1.000]
    ErrorText::Vector{Cfloat} = [1.000, 0.000, 0.000, 1.000]
    WarnText::Vector{Cfloat} = [1.000, 1.000, 0.000, 1.000]
    InfoBg::Vector{Cfloat} = [0.000, 0.855, 1.000, 0.6]
    ErrorBg::Vector{Cfloat} = [1.000, 0.000, 0.000, 0.6]
    WarnBg::Vector{Cfloat} = [1.000, 1.000, 0.000, 0.6]
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

@option mutable struct MoreStyleIcon
    File::String = ICONS.ICON_FILE
    OpenFile::String = ICONS.ICON_FILE
    OpenFolder::String = ICONS.ICON_FOLDER
    NewFile::String = ICONS.ICON_CIRCLE_PLUS
    Delete::String = ICONS.ICON_TRASH_CAN
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
    FreeSweepBlock::String = ICONS.ICON_YIN_YANG
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

@option mutable struct MoreStyleVariable
    TextRectRounding::Cfloat = 0
    TextRectThickness::Cfloat = 2
    TextRectPadding::Vector{Cfloat} = [6, 6]
    PinShapeInput::UInt32 = lib.ImNodesPinShape_Circle
    PinShapeOutput::UInt32 = lib.ImNodesPinShape_Triangle
    MiniMapFraction::Cfloat = 0.2
    MiniMapLocation::UInt32 = lib.ImNodesMiniMapLocation_TopRight
    WidgetBorderThickness::Cfloat = 1
    ContainerBlockWindowPadding::Vector{Cfloat} = [18, 18]
    MakieTheme::String = "default"
end

@option mutable struct MoreStyle
    Variables::MoreStyleVariable = MoreStyleVariable()
    Colors::MoreStyleColor = MoreStyleColor()
    Icons::MoreStyleIcon = MoreStyleIcon()
end

@option mutable struct UnionStyle
    imguistyle::QImGuiStyle = QImGuiStyle()
    imnodesstyle::QImNodesStyle = QImNodesStyle()
    morestyle::MoreStyle = MoreStyle()
end

global IMGUISTYLE::Ptr{CImGui.lib.ImGuiStyle}
global IMGUISTYLE_REF::Ref{Ptr{ImGuiStyle}} = Ref(ImGuiStyle_ImGuiStyle())
global IMNODESSTYLE::Ptr{CImGui.lib.ImNodesStyle}
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
    global function ShowStyleEditor(style_ref::QImNodesStyle)
        if @c ComboS("Colors", &colors, ["Dark", "Light", "Classic"])
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
            for var in fieldnames(lib.ImNodesStyle)
                var == :Colors && continue
                setproperty!(style_ref, var, unsafe_load(getproperty(IMNODESSTYLE, var)))
            end
            storecolors = Cuint[]
            for i in eachindex(instances(lib.ImNodesCol_)[1:end-1])
                push!(storecolors, CImGui.c_get(IMNODESSTYLE.Colors, i - 1))
            end
            style_ref.Colors = QImNodesColors(CImGui.ColorConvertU32ToFloat4.(storecolors)...)
        end
        CImGui.SameLine()
        if CImGui.Button("Revert Ref")
            for var in fieldnames(lib.ImNodesStyle)
                var == :Colors && continue
                setproperty!(IMNODESSTYLE, var, getproperty(style_ref, var))
            end
            for i in eachindex(instances(lib.ImNodesCol_)[1:end-1])
                CImGui.c_set!(IMNODESSTYLE.Colors, i - 1, CImGui.ColorConvertFloat4ToU32(style_ref.Colors[i]))
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
                for var in fieldnames(lib.ImNodesStyle)
                    if fieldtype(lib.ImNodesStyle, var) == Cfloat
                        CImGui.DragFloat(
                            stcstr(var),
                            getproperty(IMNODESSTYLE, var),
                            1.0, 0, 120, "%.3f",
                            CImGui.ImGuiSliderFlags_AlwaysClamp
                        )
                    elseif fieldtype(lib.ImNodesStyle, var) == ImVec2
                        CImGui.DragFloat2(
                            stcstr(var),
                            getproperty(IMNODESSTYLE, var),
                            1.0, 0, 120, "%.3f",
                            CImGui.ImGuiSliderFlags_AlwaysClamp
                        )
                    end
                end
                for flag in instances(lib.ImNodesStyleFlags_)
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
                    for col in instances(lib.ImNodesCol_)[1:end-1]
                        if !output_only_modified || style_ref.Colors[Int(col)+1] != CImGui.c_get(IMNODESSTYLE.Colors, col)
                            CImGui.LogText(
                                string(
                                    "colors[$col] = ",
                                    round.(CImGui.ColorConvertU32ToFloat4(CImGui.c_get(IMNODESSTYLE.Colors, col)); digits=2),
                                    "\n"
                                )
                            )
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
                for col in instances(lib.ImNodesCol_)[1:end-1]
                    CImGui.PushID(string(col))
                    # ImGuiTextFilter_PassFilter(filter, pointer(string(col)), C_NULL) || continue
                    (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(string(col)))) || continue
                    col_imvec4 = CImGui.ColorConvertU32ToFloat4(CImGui.c_get(IMNODESSTYLE.Colors, col))
                    col_arr = [col_imvec4.x, col_imvec4.y, col_imvec4.z, col_imvec4.w]
                    CImGui.ColorEdit4(stcstr(col), col_arr, CImGui.ImGuiColorEditFlags_AlphaBar | alpha_flags)
                    CImGui.c_set!(IMNODESSTYLE.Colors, col, CImGui.ColorConvertFloat4ToU32(col_arr))
                    if CImGui.ColorConvertFloat4ToU32(style_ref.Colors[Int(col)+1]) != CImGui.c_get(IMNODESSTYLE.Colors, col)
                        CImGui.PushID(stcstr(col))
                        CImGui.SameLine()
                        CImGui.Button("Save") && (style_ref.Colors[Int(col)+1] = CImGui.ColorConvertU32ToFloat4(CImGui.c_get(IMNODESSTYLE.Colors, col)))
                        CImGui.SameLine()
                        CImGui.Button("Revert") && CImGui.c_set!(
                            IMNODESSTYLE.Colors, col, CImGui.ColorConvertFloat4ToU32(style_ref.Colors[Int(col)+1])
                        )
                        CImGui.PopID()
                    end
                    CImGui.PopID()
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
                @c CImGui.DragFloat(
                    "WidgetBorderThickness", &MORESTYLE.Variables.WidgetBorderThickness,
                    1, 0, 60, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.DragFloat2(
                    "TextRectPadding", MORESTYLE.Variables.TextRectPadding,
                    1, 0, 60, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                inpin = string(lib.ImNodesPinShape_(MORESTYLE.Variables.PinShapeInput))
                if @c ComboS("Input PinShape", &inpin, string.(instances(lib.ImNodesPinShape_)))
                    MORESTYLE.Variables.PinShapeInput = getproperty(lib, Symbol(inpin))
                end
                outpin = string(lib.ImNodesPinShape_(MORESTYLE.Variables.PinShapeOutput))
                if @c ComboS("Output PinShape", &outpin, string.(instances(lib.ImNodesPinShape_)))
                    MORESTYLE.Variables.PinShapeOutput = getproperty(lib, Symbol(outpin))
                end
                @c CImGui.DragFloat(
                    "Minimap Fraction",
                    &MORESTYLE.Variables.MiniMapFraction,
                    0.1, 0.1, 1, "%.1f",
                    CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                minimaplocation = string(lib.ImNodesMiniMapLocation_(MORESTYLE.Variables.MiniMapLocation))
                if @c ComboS("Minimap Location", &minimaplocation, string.(instances(lib.ImNodesMiniMapLocation_)))
                    MORESTYLE.Variables.MiniMapLocation = getproperty(lib, Symbol(minimaplocation))
                end
                CImGui.DragFloat2(
                    "ContainerBlockWindowPadding", MORESTYLE.Variables.ContainerBlockWindowPadding,
                    1, 0, 60, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                if @c ComboS("Makie Theme", &MORESTYLE.Variables.MakieTheme, keys(MAKIETHEMES))
                    toimguitheme!(MAKIETHEMES[MORESTYLE.Variables.MakieTheme])
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
                        CImGui.PushID(stcstr(color))
                        CImGui.SameLine()
                        if CImGui.Button("Save")
                            getproperty(style_ref.Colors, color) .= getproperty(MORESTYLE.Colors, color)
                        end
                        CImGui.SameLine()
                        if CImGui.Button("Revert")
                            getproperty(MORESTYLE.Colors, color) .= getproperty(style_ref.Colors, color)
                        end
                        CImGui.PopID()
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

function loadstyle(style_ref::QImGuiStyle)
    IMGUISTYLE_REF[] = style_ref
    for var in fieldnames(ImGuiStyle)
        var == :Colors && continue
        setproperty!(IMGUISTYLE, var, unsafe_load(getproperty(IMGUISTYLE_REF[], var)))
    end
    for i in 0:CImGui.ImGuiCol_COUNT-1
        CImGui.c_set!(IMGUISTYLE.Colors, i, CImGui.c_get(IMGUISTYLE_REF[].Colors, i))
    end
end
function loadstyle(style_ref::QImNodesStyle)
    for var in fieldnames(lib.ImNodesStyle)
        var == :Colors && continue
        setproperty!(IMNODESSTYLE, var, getproperty(style_ref, var))
    end
    for i in eachindex(instances(lib.ImNodesCol_)[1:end-1])
        CImGui.c_set!(IMNODESSTYLE.Colors, i - 1, CImGui.ColorConvertFloat4ToU32(style_ref.Colors[i]))
    end
end
function loadstyle(style_ref::MoreStyle)
    for var in fieldnames(MoreStyleVariable)
        setproperty!(MORESTYLE.Variables, var, getproperty(style_ref.Variables, var))
        var == :MakieTheme && toimguitheme!(MAKIETHEMES[style_ref.Variables.MakieTheme])
    end
    for var in fieldnames(MoreStyleColor)
        getproperty(MORESTYLE.Colors, var) .= getproperty(style_ref.Colors, var)
    end
    for var in fieldnames(MoreStyleIcon)
        setproperty!(MORESTYLE.Icons, var, getproperty(style_ref.Icons, var))
    end
end
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
    windows::Vector{String} = [
        "Main", "Circuit", "Instruments", "Registration",
        "FileTree", "FileViewer", "Formatter", "Console", "Logger", "Preferences"
    ]
    global function StyleEditor()
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
                ustyle.imguistyle = IMGUISTYLE
                STYLES[style_name] = ustyle
                @trycatch mlstr("saving styles failed!!!") begin
                    to_toml(joinpath(CONF.Style.dir, "$style_name.toml"), ustyle)
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
            nmerr ? MORESTYLE.Colors.ErrorText : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled)
        )
        CImGui.PushItemWidth(ws / 2 - bw - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c InputTextWithHintRSZ("##Input Style Name", hinttext, &style_name)
        CImGui.PopItemWidth()
        CImGui.PopStyleColor()
        CImGui.SameLine()
        CImGui.Button(MORESTYLE.Icons.Delete) && CImGui.OpenPopup("##if delete style")
        CImGui.SameLine()
        ShowHelpMarker("This operation will delete the selected IMGUISTYLE. Please be careful!")
        if YesNoDialog("##if delete style", mlstr("confirm delete?"), CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            delete!(STYLES, selected_style)
            Base.Filesystem.rm(joinpath(CONF.Style.dir, "$selected_style.toml"), force=true)
            selected_style = ""
        end

        CImGui.PushItemWidth(ws / 2)
        if selected_style == "" && haskey(STYLES, CONF.Style.default)
            selected_style = CONF.Style.default
            ustyle = STYLES[selected_style]
            IMGUISTYLE_REF[] = ustyle.imguistyle
        end
        if @c ComboS("##Style Selecting", &selected_style, keys(STYLES))
            if selected_style != ""
                ustyle = STYLES[selected_style]
                style_name = selected_style
                loadstyle(ustyle)
                IMGUISTYLE_REF[] = ustyle.imguistyle
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
                CImGui.ShowStyleEditor(IMGUISTYLE_REF[])
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
            if CImGui.BeginTabItem("Wallpapers")
                CImGui.BeginChild("Wallpapers")
                for (i, fnm) in enumerate(fieldnames(OptBGImage))
                    CImGui.PushID(i)
                    bg = getproperty(CONF.BGImage, fnm)
                    bgpath = bg.path
                    CImGui.PushItemWidth(ws / 2)
                    inputbgpath = @c InputTextRSZ("##BGImage-path", &bgpath)
                    CImGui.PopItemWidth()
                    CImGui.SameLine()
                    selectbgpath = CImGui.Button(stcstr(MORESTYLE.Icons.SelectPath, "##BGImage-path"))
                    selectbgpath && (bgpath = pick_file(abspath(bgpath); filterlist="png,jpg,jpeg,tif,bmp;gif"))
                    CImGui.SameLine()
                    @c CImGui.Checkbox("##useall", &bg.use)
                    ItemTooltip("apply to all the windows ?")
                    CImGui.SameLine()
                    CImGui.Text(windows[i])
                    if inputbgpath || selectbgpath
                        if isfile(bgpath)
                            destroyimage!(bg.path)
                            bg.path = bgpath
                            createimage(bgpath; showsize=CONF.Basic.windowsize)
                        else
                            CImGui.SameLine()
                            CImGui.TextColored(MORESTYLE.Colors.ErrorText, mlstr("path does not exist!!!"))
                        end
                    end
                    if bg.use
                        @c CImGui.DragInt("Rate", &bg.rate, 1, 1, 120, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                    end
                    CImGui.PopID()
                end
                CImGui.EndChild()
                CImGui.EndTabItem()
            end
            CImGui.EndTabBar()
        end
    end
end