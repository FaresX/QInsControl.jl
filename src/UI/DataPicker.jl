mutable struct DataPicker
    datalist::Vector{String}
    x::String
    y::Vector{Bool}
    z::String
    w::Vector{Bool}
    xtype::Bool # true = > Number false = > String
    codes::CodeBlock
    hold::Bool
    isrealtime::Bool
    refreshrate::Cfloat
    alsz::Float32
end
DataPicker() = DataPicker([""], "", [false], "", [false], true, CodeBlock(), false, false, Cint(1), 0)

let
    window_ids::Dict = Dict()
    global function edit(dtpk::DataPicker, id, p_open::Ref)
        CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Appearing)
        # dtpk.hold && CImGui.SetNextWindowFocus()
        CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_PopupBg))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, unsafe_load(imguistyle.PopupRounding))
        isupdate = false
        isfocus = true
        haskey(window_ids, id) || push!(window_ids, id => "数据选择$id")
        if CImGui.Begin(window_ids[id], p_open, CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking)
            @cstatic holdsz::Float32 = 0 begin
                CImGui.TextColored(morestyle.Colors.HighlightText, morestyle.Icons.SelectData)
                CImGui.SameLine()
                CImGui.Text(" 数据选择")
                CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
                @c CImGui.Checkbox("HOLD", &dtpk.hold)
                holdsz = CImGui.GetItemRectSize().x
            end
            CImGui.Separator()

            @cstatic xtypesz::Float32 = 0 begin
                CImGui.TextColored(morestyle.Colors.HighlightText, "选择X")
                CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - xtypesz)
                if dtpk.xtype
                    @c CImGui.Checkbox("数字", &dtpk.xtype)
                else
                    @c CImGui.Checkbox("文本", &dtpk.xtype)
                end
                xtypesz = CImGui.GetItemRectSize().x
            end
            CImGui.PushItemWidth(-1)
            @c ComBoS("##选择X", &dtpk.x, [dtpk.datalist; ""])
            CImGui.PopItemWidth()

            CImGui.TextColored(morestyle.Colors.HighlightText, "选择Y")
            isempty(dtpk.datalist) ? CImGui.Selectable("") : MultiSelectable(()->false, "数据选择Y", dtpk.datalist, dtpk.y, 1)

            CImGui.PushItemWidth(-1)
            CImGui.TextColored(morestyle.Colors.HighlightText, "选择Z")
            @c ComBoS("##选择Z", &dtpk.z, [dtpk.datalist; ""])
            CImGui.PopItemWidth()

            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, morestyle.Colors.HighlightText)
            selectw = CImGui.CollapsingHeader("选择W")
            CImGui.PopStyleColor()
            if selectw
                # CImGui.TextColored(morestyle.Colors.HighlightText, "选择W")
                isempty(dtpk.datalist) ? CImGui.Selectable("") : MultiSelectable(()->false, "数据选择W", dtpk.datalist, dtpk.w, 1)
            end

            CImGui.TextColored(morestyle.Colors.LogInfo, "数据微处理")
            CImGui.SameLine(CImGui.GetWindowContentRegionWidth() - dtpk.alsz)
            if dtpk.isrealtime
                CImGui.Text("采样率")
                CImGui.SameLine()
                dtpk.alsz = CImGui.GetItemRectSize().x
                CImGui.PushItemWidth(2CImGui.GetFontSize())
                @c CImGui.DragFloat("s", &dtpk.refreshrate, 0.01, 0.01, 6, "%.2f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                CImGui.SameLine()
                CImGui.PopItemWidth()
                dtpk.alsz += CImGui.GetItemRectSize().x + unsafe_load(imguistyle.ItemSpacing.x)
            else
                CImGui.Button(morestyle.Icons.Update * " 更新  ") && (isupdate = true)
                dtpk.alsz = CImGui.GetItemRectSize().x
            end
            CImGui.SameLine()
            @c CImGui.Checkbox("RT", &dtpk.isrealtime)
            dtpk.alsz += CImGui.GetItemRectSize().x + unsafe_load(imguistyle.ItemSpacing.x)
            CImGui.IsItemHovered() && CImGui.SetTooltip("实时更新数据/手动更新数据")

            CImGui.PushID("数据选择XYZ")
            edit(dtpk.codes)
            if CImGui.BeginPopupContextItem()
                CImGui.MenuItem("清空") && (dtpk.codes = CodeBlock())
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
end

function syncplotdata(uiplot::UIPlot, dtpk::DataPicker, data)
    # dtpk.isrealtime || (uiplot.xlabel = dtpk.x)
    if dtpk.xtype
        uiplot.x = @trypass replace(tryparse.(Float64, data[dtpk.x]), nothing => NaN) Float64[]
    else
        uiplot.x = @trypass copy(data[dtpk.x]) String[]
    end
    uiplot.y = @trypass [replace(tryparse.(Float64, data[key]), nothing => NaN) for key in dtpk.datalist[dtpk.y]] [Float64[]]
    uiplot.legends = @trypass dtpk.datalist[dtpk.y] uiplot.legends
    zbuf::Array = uiplot.z
    if uiplot.ptype == "heatmap"
        zbuf = @trypass replace(tryparse.(Float64, data[dtpk.z]), nothing => 0) Matrix{Float64}(undef, 0, 0)
    end
    wbuf = @trypass [replace(tryparse.(Float64, data[key]), nothing => NaN) for key in dtpk.datalist[dtpk.w]] [Float64[]]
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
        uiplot.x, uiplot.y, uiplot.z = eval(ex)
        uiplot.z = transposeimg(uiplot.z)
        dtpk.isrealtime || @info "[$(now())]" data_processing = innercodes
    catch e
        dtpk.isrealtime || @error "[$(now())]\ncodes are wrong in evaluating time (sync UIPlot)!!!" exception = e codes = ex
    end
    nothing
end