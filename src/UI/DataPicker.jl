mutable struct DataPicker
    datalist::Vector{String}
    x::String
    y::Vector{Bool}
    z::String
    w::Vector{Bool}
    xtype::Bool # true = > Number false = > String
    zsize::Vector{Cint}
    vflipz::Bool
    hflipz::Bool
    codes::CodeBlock
    hold::Bool
    isrealtime::Bool
    refreshrate::Cfloat
    alsz::Float32
end
DataPicker() = DataPicker(
    [""],
    "", [false], "", [false],
    true,
    [0, 0], false, false,
    CodeBlock(),
    false, false, Cint(1), 0
)

function edit(dtpk::DataPicker, id, p_open::Ref)
    CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Appearing)
    # dtpk.hold && CImGui.SetNextWindowFocus()
    CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg))
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, unsafe_load(IMGUISTYLE.PopupRounding))
    isupdate = false
    isfocus = true
    if CImGui.Begin(
        stcstr(mlstr("Data Selecting"), "##", id),
        p_open,
        CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking
    )
        @cstatic holdsz::Float32 = 0 begin
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, MORESTYLE.Icons.Plot)
            CImGui.SameLine()
            CImGui.Text(stcstr(" ", mlstr("Data Selecting")))
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
            @c CImGui.Checkbox(mlstr("HOLD"), &dtpk.hold)
            holdsz = CImGui.GetItemRectSize().x
        end
        CImGui.Separator()

        @cstatic xtypesz::Float32 = 0 begin
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(mlstr("Select"), " X"))
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - xtypesz)
            @c CImGui.Checkbox(dtpk.xtype ? mlstr("number") : mlstr("text"), &dtpk.xtype)
            xtypesz = CImGui.GetItemRectSize().x
        end
        CImGui.PushItemWidth(-1)
        @c ComBoS("##select X", &dtpk.x, [dtpk.datalist; ""])
        CImGui.PopItemWidth()

        CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(mlstr("Select"), " Y"))
        if isempty(dtpk.datalist)
            CImGui.Selectable("")
        else
            MultiSelectable(() -> false, "select Y", dtpk.datalist, dtpk.y, 1)
        end

        CImGui.PushItemWidth(-1)
        CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(mlstr("Select"), " Z"))
        @c ComBoS("##select Z", &dtpk.z, [dtpk.datalist; ""])
        CImGui.PopItemWidth()
        CImGui.DragInt2(mlstr("matrix dimension"), dtpk.zsize, 1, 0, 1000000, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
        @c CImGui.Checkbox(mlstr("flip vertically"), &dtpk.vflipz)
        CImGui.SameLine(CImGui.GetContentRegionAvailWidth() / 2)
        @c CImGui.Checkbox(mlstr("flip horizontally"), &dtpk.hflipz)

        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
        selectw = CImGui.CollapsingHeader(stcstr(mlstr("Select"), " W"))
        CImGui.PopStyleColor()
        if selectw
            if isempty(dtpk.datalist)
                CImGui.Selectable("")
            else
                MultiSelectable(() -> false, "select W", dtpk.datalist, dtpk.w, 1)
            end
        end

        CImGui.TextColored(MORESTYLE.Colors.LogInfo, mlstr("data processing"))
        CImGui.SameLine(CImGui.GetWindowContentRegionWidth() - dtpk.alsz)
        if dtpk.isrealtime
            CImGui.Text(mlstr("sampling rate"))
            CImGui.SameLine()
            dtpk.alsz = CImGui.GetItemRectSize().x
            CImGui.PushItemWidth(2CImGui.GetFontSize())
            @c CImGui.DragFloat("s", &dtpk.refreshrate, 0.01, 0.01, 6, "%.2f", CImGui.ImGuiSliderFlags_AlwaysClamp)
            CImGui.SameLine()
            CImGui.PopItemWidth()
            dtpk.alsz += CImGui.GetItemRectSize().x + unsafe_load(IMGUISTYLE.ItemSpacing.x)
        else
            CImGui.Button(stcstr(MORESTYLE.Icons.Update, stcstr(" ", mlstr("Update"), " "))) && (isupdate = true)
            dtpk.alsz = CImGui.GetItemRectSize().x
        end
        CImGui.SameLine()
        @c CImGui.Checkbox("RT", &dtpk.isrealtime)
        dtpk.alsz += CImGui.GetItemRectSize().x + unsafe_load(IMGUISTYLE.ItemSpacing.x)
        CImGui.IsItemHovered() && CImGui.SetTooltip(mlstr("real-time data update/manual data update"))

        CImGui.PushID("select XYZ")
        edit(dtpk.codes)
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(mlstr("Clear")) && (dtpk.codes = CodeBlock())
            CImGui.EndPopup()
        end
        CImGui.PopID()
        isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
    end
    CImGui.End()
    p_open.x &= (isfocus | dtpk.hold)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    isupdate
end

function syncplotdata(uiplot::UIPlot, dtpk::DataPicker, datastr, datafloat)
    # dtpk.isrealtime || (uiplot.xlabel = dtpk.x)
    if isempty(datafloat)
        if dtpk.xtype
            uiplot.x = haskey(datastr, dtpk.x) ? replace(tryparse.(Float64, datastr[dtpk.x]), nothing => NaN) : Float64[]
        else
            uiplot.x = haskey(datastr, dtpk.x) ? copy(datastr[dtpk.x]) : String[]
        end
        uiplot.y = @trypass(
            [replace(tryparse.(Float64, datastr[key]), nothing => NaN) for key in dtpk.datalist[dtpk.y]],
            [Float64[]]
        )
        uiplot.legends = @trypass dtpk.datalist[dtpk.y] uiplot.legends
        zbuf = uiplot.z
        if uiplot.ptype == "heatmap"
            zbuf = if haskey(datastr, dtpk.z)
                replace(tryparse.(Float64, datastr[dtpk.z]), nothing => 0)
            else
                Matrix{Float64}(undef, 0, 0)
            end
            all(size(uiplot.z) .== reverse(dtpk.zsize)) || (uiplot.z = zeros(Float64, reverse(dtpk.zsize)...))
        end
        wbuf = @trypass(
            [replace(tryparse.(Float64, datastr[key]), nothing => NaN) for key in dtpk.datalist[dtpk.w]],
            [Float64[]]
        )
    else
        if dtpk.xtype
            uiplot.x = haskey(datafloat, dtpk.x) ? copy(datafloat[dtpk.x]) : Float64[]
        else
            uiplot.x = haskey(datastr, dtpk.x) ? copy(datastr[dtpk.x]) : String[]
        end
        uiplot.y = @trypass [copy(datafloat[key]) for key in dtpk.datalist[dtpk.y]] [Float64[]]
        uiplot.legends = @trypass dtpk.datalist[dtpk.y] uiplot.legends
        zbuf = uiplot.z
        if uiplot.ptype == "heatmap"
            zbuf = if haskey(datafloat, dtpk.z)
                all(!isnan, datafloat[dtpk.z]) ? copy(datafloat[dtpk.z]) : replace(datafloat[dtpk.z], NaN => 0)
            else
                Matrix{Float64}(undef, 0, 0)
            end
            all(size(uiplot.z) .== reverse(dtpk.zsize)) || (uiplot.z = zeros(Float64, reverse(dtpk.zsize)...))
        end
        wbuf = @trypass [copy(datafloat[key]) for key in dtpk.datalist[dtpk.w]] [Float64[]]
    end
    innercodes = tocodes(dtpk.codes)
    ex::Expr = quote
        let
            x = $uiplot.x
            ys = $uiplot.y
            isempty(ys) && (ys = [Float64[]])
            y = ys[1]
            z = $zbuf
            ws = $wbuf
            isempty(ws) && (ws = [Float64[]])
            w = ws[1]
            $innercodes
            ys[1] = y
            x, ys, z
        end
    end |> prettify
    try
        uiplot.x, uiplot.y, nz = eval(ex)
        if uiplot.ptype == "heatmap"
            lmin = min(length(uiplot.z), length(nz))
            rows = ceil(Int, lmin / dtpk.zsize[1])
            fill!(uiplot.z, zero(eltype(uiplot.z)))
            @views uiplot.z[1:rows, :] = transpose(resize(nz, dtpk.zsize[1], rows))
            dtpk.vflipz && reverse!(uiplot.z, dims=2)
            dtpk.hflipz && reverse!(uiplot.z, dims=1)
        end
        dtpk.isrealtime || @info "[$(now())]" data_processing = innercodes
    catch e
        dtpk.isrealtime || @error "[$(now())]\n$(mlstr("processing data failed!!!"))" exception = e codes = ex
    end
    nothing
end