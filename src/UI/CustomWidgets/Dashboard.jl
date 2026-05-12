@kwdef mutable struct DashBoard
    limit::Vector{Cfloat} = [0.0, 400.0]
    value::Vector{Cfloat} = [0, 0]
    colorsub::Vector{Cfloat} = [0.78, 0.78]
    selfinspstatusflag::Bool = true
    valuesmoothflag::Bool = true
    start::Bool = false
end

function SetDashboardValueLimit!(db::DashBoard, limit)
    db.limit .= limit
    db.value[2] = db.limit[1]
    return db.limit
end

LIMIT_CLAMP(value, min, max) = value < min ? min : value > max ? max : value

const SemicircleDeg = ImVec2(45.0, 315.0)
const RulerScaleLen = ImVec2(3.0, 1.2)
IMFXC_DEGTORAD(deg) = deg * π / 180.0
ICB_ZEROLIMIT(high, value) = high - value < 0.0 ? 0.0 : high - value > 1.0 ? 1.0 : high - value
function ExtColorBrightnesScale(color, value)
    ImVec4(ICB_ZEROLIMIT(color[1], value), ICB_ZEROLIMIT(color[2], value), ICB_ZEROLIMIT(color[3], value), ICB_ZEROLIMIT(color[4], value))
end
function ExtDrawLine(point0, point1, color, linewidth)
    CImGui.AddLine(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + point0[1], CImGui.GetCursorScreenPos()[2] + point0[2]),
        ImVec2(CImGui.GetCursorScreenPos()[1] + point1[1], CImGui.GetCursorScreenPos()[2] + point1[2]),
        color,
        linewidth
    )
end
function ExtDrawText(position, color, text)
    CImGui.AddText(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1], CImGui.GetCursorScreenPos()[2] + position[2]),
        color,
        text
    )
end
function ExtDrawRectangleFill(position, size, color; rounding=0)
    CImGui.AddRectFilled(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1], CImGui.GetCursorScreenPos()[2] + position[2]),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1] + size[1], CImGui.GetCursorScreenPos()[2] + position[2] + size[2]),
        color, rounding
    )
end
function ExtDrawRectangle(position, size, color; thickness=0, rounding=0)
    CImGui.AddRect(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1], CImGui.GetCursorScreenPos()[2] + position[2]),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1] + size[1], CImGui.GetCursorScreenPos()[2] + position[2] + size[2]),
        color, rounding, 0, thickness
    )
end
function ExtDrawCircleFill(position, size, color; num_segments=24)
    CImGui.AddCircleFilled(
        CImGui.GetWindowDrawList(),
        ImVec2(CImGui.GetCursorScreenPos()[1] + position[1], CImGui.GetCursorScreenPos()[2] + position[2]),
        size,
        color,
        num_segments
    )
end

LEDSTATE(STAT, POS, HCOLOR, LCOLOR; size=(40, 20)) = ExtDrawRectangleFill(POS, size, STAT ? HCOLOR : LCOLOR)

function DrawSemicircleBox(window_width, y_offset, ruler, color; num_segments=24)
    DrawOffsetHigh = window_width * 0.5
    CircleRadius = ImVec2(DrawOffsetHigh - unsafe_load(IMGUISTYLE.ItemSpacing.x), window_width * 0.28)

    LineBeginInnerTemp = ImVec2(
        sin(IMFXC_DEGTORAD(SemicircleDeg[1])) * CircleRadius[1] + DrawOffsetHigh,
        cos(IMFXC_DEGTORAD(SemicircleDeg[1])) * CircleRadius[1] + y_offset
    )

    RulerDrawSpc = ImVec2(
        (SemicircleDeg[2] - SemicircleDeg[1]) / ruler,
        (SemicircleDeg[2] - SemicircleDeg[1]) / (ruler * 5)
    )
    RulerDrawCount = [0.0, 1.0]

    CImGui.PathArcTo(CImGui.GetWindowDrawList(), CImGui.GetCursorScreenPos() .+ (DrawOffsetHigh, y_offset), CircleRadius[1], -5π / 4, π / 4, 2num_segments)
    CImGui.PathStroke(CImGui.GetWindowDrawList(), CImGui.ColorConvertFloat4ToU32(color), false, 0.01window_width)
    for i in SemicircleDeg[1]:0.15:SemicircleDeg[2]

        LineEndInnerTemp = ImVec2(
            sin(IMFXC_DEGTORAD(i)) * CircleRadius[1] + DrawOffsetHigh,
            cos(IMFXC_DEGTORAD(i)) * CircleRadius[1] + y_offset
        )

        if i - SemicircleDeg[1] >= RulerDrawSpc[1] * RulerDrawCount[1]
            LineRulerTemp = ImVec2(
                sin(IMFXC_DEGTORAD(i)) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1]) + DrawOffsetHigh,
                cos(IMFXC_DEGTORAD(i)) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1]) + y_offset
            )
            ExtDrawLine(LineEndInnerTemp, LineRulerTemp, color, 4.0)
            RulerDrawCount[1] += 1.0
        end

        if i - SemicircleDeg[1] > RulerDrawSpc[2] * RulerDrawCount[2]
            LineRulerTemp = ImVec2(
                sin(IMFXC_DEGTORAD(i)) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[2]) + DrawOffsetHigh,
                cos(IMFXC_DEGTORAD(i)) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[2]) + y_offset
            )
            ExtDrawLine(LineEndInnerTemp, LineRulerTemp, color, 2.2)
            RulerDrawCount[2] += 1.0
        end

        LineBeginInnerTemp = LineEndInnerTemp
    end

    CImGui.PathArcTo(CImGui.GetWindowDrawList(), CImGui.GetCursorScreenPos() .+ (DrawOffsetHigh, y_offset), CircleRadius[2], -5π / 4, π / 4, round(Int, 3num_segments / 2))
    CImGui.PathStroke(CImGui.GetWindowDrawList(), CImGui.ColorConvertFloat4ToU32(color), false, 0.03window_width)

    ExtDrawLine(
        ImVec2(
            sin(IMFXC_DEGTORAD(SemicircleDeg[2])) * CircleRadius[1] + DrawOffsetHigh,
            cos(IMFXC_DEGTORAD(SemicircleDeg[2])) * CircleRadius[1] + y_offset
        ),
        ImVec2(
            sin(IMFXC_DEGTORAD(SemicircleDeg[2])) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1]) + DrawOffsetHigh,
            cos(IMFXC_DEGTORAD(SemicircleDeg[2])) * (CircleRadius[1] - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1]) + y_offset
        ),
        color, 2.2
    )
end

function DrawTextFunc(DrawText, DrawPos, color)
    TextSizeOffset = CImGui.CalcTextSize(DrawText)
    ExtDrawText(ImVec2(DrawPos[1] - TextSizeOffset[1] * 0.5, DrawPos[2] - TextSizeOffset[2] * 0.5), color, DrawText)
end

function DrawRulerscaleValue(window_width, y_offset, ruler, limit, color)
    DrawOffsetHigh = window_width * 0.5
    CircleRadius = DrawOffsetHigh - unsafe_load(IMGUISTYLE.ItemSpacing.x)
    RulerDrawSpc = (SemicircleDeg[2] - SemicircleDeg[1]) / ruler
    RulerDrawCount = 0.0
    ValueDrawTemp = limit[2]
    ValueOffset = (limit[2] - limit[1]) / ruler

    for i in SemicircleDeg[1]:0.32:SemicircleDeg[2]
        if i - SemicircleDeg[1] >= RulerDrawSpc * RulerDrawCount
            DrawTextPos = ImVec2(
                sin(IMFXC_DEGTORAD(i)) * (CircleRadius - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1] * 2.4) + DrawOffsetHigh,
                cos(IMFXC_DEGTORAD(i)) * (CircleRadius - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1] * 2.4) + y_offset
            )
            DrawTextTemp = @sprintf "%g" round(ValueDrawTemp, sigdigits=3)
            ValueDrawTemp -= ValueOffset

            DrawTextFunc(DrawTextTemp, DrawTextPos, color)
            RulerDrawCount += 1.0
        end
    end

    HeadTextPos = ImVec2(
        sin(IMFXC_DEGTORAD(SemicircleDeg[2])) * (CircleRadius - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1] * 2.4) + DrawOffsetHigh,
        cos(IMFXC_DEGTORAD(SemicircleDeg[2])) * (CircleRadius - unsafe_load(IMGUISTYLE.ItemSpacing.x) * RulerScaleLen[1] * 2.4) + y_offset
    )
    DrawTextFunc(string(limit[1]), HeadTextPos, color)
end

function DrawIndicator(
    window_width, y_offset, value, limit;
    linewidth=7.2, num_segments=24,
    colbase=[0.16, 0.16, 0.16, 1.0], colind=[1.0, 0.0, 0.0, 0.98]
)
    DrawOffsetHigh = window_width * 0.5
    IWL = linewidth / (DrawOffsetHigh * 0.85)

    SemicircleDegLen = SemicircleDeg[2] - SemicircleDeg[1] + IWL * 180.0
    ValueLength = limit[2] - limit[1]
    ValueProportion = (value - limit[1]) / ValueLength
    ValueProportion = LIMIT_CLAMP(ValueProportion, 0.0, 1.0)

    CenterPoint = ImVec2(window_width * 0.5, y_offset)
    LineBeginTemp = ImVec2(
        sin(IMFXC_DEGTORAD(SemicircleDeg[2] - SemicircleDegLen * ValueProportion) + IWL) * DrawOffsetHigh * 0.85 - unsafe_load(IMGUISTYLE.ItemSpacing.x) + DrawOffsetHigh,
        cos(IMFXC_DEGTORAD(SemicircleDeg[2] - SemicircleDegLen * ValueProportion) + IWL) * DrawOffsetHigh * 0.85 - unsafe_load(IMGUISTYLE.ItemSpacing.x) + y_offset
    )

    ExtDrawCircleFill(CenterPoint, 8linewidth, [colbase[1:3]...; colbase[4] * 0.6]; num_segments=num_segments)
    ExtDrawLine(LineBeginTemp, CenterPoint, colind, linewidth)
    ExtDrawCircleFill(CenterPoint, 6linewidth, colbase; num_segments=num_segments)
end

function DrawDashboardWindow(
    db::DashBoard, value;
    size=(400, 400), ruler=6, speed=2, num_segments=24, rounding=0, bdrounding=0, thickness=0,
    colbg=[0, 0, 0, 0], colbd=[0, 0, 0, 0],
    colpanel=[1, 1, 1, 1], coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
    colbase=[0.16, 0.16, 0.16, 1.0], colind=(1.0, 0.0, 0.0, 0.98)
)
    !db.selfinspstatusflag && db.start && (db.value[1] = value)
    db.value[1] = LIMIT_CLAMP(db.value[1], db.limit[1], db.limit[2])

    db.limit[1] >= db.limit[2] && (db.limit[1] = db.limit[2] - 1.0)

    # CImGui.BeginChild(name, size)
    # ColoredButton(""; size=size, colbt=(0, 0, 0, 0), colbth=(0, 0, 0, 0), colbta=(0, 0, 0, 0))
    # CImGui.SetWindowFontScale(1.42)

    if db.start
        if db.selfinspstatusflag && db.value[1] < db.limit[1] + 1.0
            db.valuesmoothflag = true
            db.value[1] = db.limit[2]
        end
        if db.selfinspstatusflag && (db.value[1] - db.value[2]) < db.value[1] * 0.08
            db.selfinspstatusflag = false
            db.value[1] = db.limit[1]
        end
        if abs(db.value[1] - db.value[2]) < (db.limit[2] - db.limit[1]) / 270
            db.valuesmoothflag = false
        else
            db.valuesmoothflag = true
        end
        db.colorsub[1] = 0.0
    else
        db.colorsub[1] = 0.78
        db.value[1] = db.limit[1]
        db.valuesmoothflag = true
        db.selfinspstatusflag = true
    end

    ledsz = (40, 20) .* (size[1] / 600)
    posl = ImVec2(unsafe_load(IMGUISTYLE.ItemSpacing.x), unsafe_load(IMGUISTYLE.ItemSpacing.x))
    posr = ImVec2(ledsz[1] + unsafe_load(IMGUISTYLE.ItemSpacing.x) * 2.0, unsafe_load(IMGUISTYLE.ItemSpacing.x))
    ExtDrawRectangleFill((0, 0), size, colbg; rounding=rounding)
    ExtDrawRectangle((0, 0), size, colbd; thickness=thickness, rounding=bdrounding)
    LEDSTATE(
        db.start && db.selfinspstatusflag,
        posl,
        (1.0, 0.0, 0.0, 1.0),
        ExtColorBrightnesScale(colpanel, 0.78);
        size=ledsz
    )
    LEDSTATE(
        db.start && !db.selfinspstatusflag,
        posr,
        (0.0, 1.0, 0.0, 1.0),
        ExtColorBrightnesScale(colpanel, 0.78);
        size=ledsz
    )
    # if CImGui.IsMouseClicked(0)
    #     mousein(CImGui.GetCursorScreenPos() .+ posl, CImGui.GetCursorScreenPos() .+ posl .+ (40, 20)) && (db.start = false)
    #     mousein(CImGui.GetCursorScreenPos() .+ posr, CImGui.GetCursorScreenPos() .+ posr .+ (40, 20)) && (db.start = true)
    # end
    DrawSemicircleBox(size[1], size[2] * 0.6, ruler, ExtColorBrightnesScale(colpanel, db.colorsub[2]); num_segments=num_segments)
    DrawRulerscaleValue(size[1], size[2] * 0.6, ruler, db.limit, ExtColorBrightnesScale(coltxt, db.colorsub[2]))
    DrawIndicator(
        size[1], size[2] * 0.6, db.value[2], db.limit;
        linewidth=0.01size[1], num_segments=num_segments, colbase=colbase, colind=colind
    )

    db.colorsub[2] += (db.colorsub[1] - db.colorsub[2]) * 0.024 * speed
    if db.valuesmoothflag
        db.value[2] += (db.value[1] - db.value[2]) * 0.016 * speed
    else
        db.value[2] = db.value[1]
    end
    # CImGui.EndChild()
    # return CImGui.IsWindowHovered()
end

let
    dashboardlist::Dict{String,DashBoard} = Dict()
    global function DashBoardPanel(
        label, value, range, start;
        size=(400, 400),
        ruler=6,
        rounding=unsafe_load(IMGUISTYLE.FrameRounding),
        bdrounding=unsafe_load(IMGUISTYLE.FrameRounding),
        thickness=0,
        num_segments=24,
        col=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ChildBg),
        colon=MORESTYLE.Colors.ToggleButtonOn,
        colbase=MORESTYLE.Colors.ToggleButtonOff,
        colind=MORESTYLE.Colors.HighlightText,
        coltxt=CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text),
        colrect=(0, 0, 0, 0)
    )
        haskey(dashboardlist, label) || (dashboardlist[label] = DashBoard())
        db = dashboardlist[label]
        db.start = start
        all(range .≈ db.limit) || SetDashboardValueLimit!(db, range)
        DrawDashboardWindow(
            db, value;
            size=size, ruler=ruler, speed=2, num_segments=num_segments,
            rounding=rounding, bdrounding=bdrounding, thickness=thickness,
            colbg=col, colbd=colrect, colpanel=colon, colbase=colbase, colind=colind, coltxt=coltxt
        )
        # rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
        # draw_list = CImGui.GetWindowDrawList()
        # CImGui.AddRect(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(colrect), bdrounding, 0, thickness)
    end
end