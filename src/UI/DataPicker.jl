mutable struct DataPicker
    datalist::Vector{String}
    ptype::String
    x::String
    y::Vector{Bool}
    z::String
    w::Vector{Bool}
    xtype::Bool # true = > Number false = > String
    zsize::Vector{Cint}
    vflipz::Bool
    hflipz::Bool
    nonuniform::Bool
    codes::CodeBlock
    hold::Bool
    isrealtime::Bool
    isrunning::Bool
    runtime::Float64
    refreshrate::Cfloat
    alsz::Float32
end
DataPicker() = DataPicker(
    [""],
    "line",
    "", [false], "", [false],
    true,
    [0, 0], false, false, false,
    CodeBlock(),
    false, false, false,
    0, Cint(1), 0
)

let
    holdsz::Cfloat = 0
    ptypelist::Vector{String} = ["line", "scatter", "heatmap"]
    global function edit(dtpk::DataPicker, id, p_open::Ref)
        CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Once)
        # dtpk.hold && CImGui.SetNextWindowFocus()
        CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, unsafe_load(IMGUISTYLE.PopupRounding))
        isupdate = false
        isfocus = true
        if CImGui.Begin(
            stcstr("Data Selecting##", id),
            p_open,
            CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking
        )
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, MORESTYLE.Icons.Plot)
            CImGui.SameLine()
            CImGui.Text(stcstr(" ", mlstr("Data Selecting")))
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
            @c CImGui.Checkbox(mlstr("HOLD"), &dtpk.hold)
            holdsz = CImGui.GetItemRectSize().x
            @c ComBoS(mlstr("plot type"), &dtpk.ptype, ptypelist)
            CImGui.Separator()

            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
            selectx = CImGui.CollapsingHeader(stcstr(mlstr("Select"), " X"))
            CImGui.PopStyleColor()
            if selectx
                CImGui.PushItemWidth(-1)
                @c ComBoS("##select X", &dtpk.x, [dtpk.datalist; ""])
                CImGui.PopItemWidth()
                @c CImGui.Checkbox(dtpk.xtype ? mlstr("number") : mlstr("text"), &dtpk.xtype)
            end

            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
            selecty = CImGui.CollapsingHeader(stcstr(mlstr("Select"), " Y"))
            CImGui.PopStyleColor()
            if selecty
                if isempty(dtpk.datalist)
                    CImGui.Selectable("")
                else
                    MultiSelectable(() -> false, "select Y", dtpk.datalist, dtpk.y, 1)
                end
            end

            if dtpk.ptype == "heatmap"
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
                selectz = CImGui.CollapsingHeader(stcstr(mlstr("Select"), " Z"))
                CImGui.PopStyleColor()
                if selectz
                    CImGui.PushItemWidth(-1)
                    @c ComBoS("##select Z", &dtpk.z, [dtpk.datalist; ""])
                    CImGui.PopItemWidth()
                    CImGui.DragInt2(mlstr("matrix dimension"), dtpk.zsize, 1, 0, 1000000, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
                    @c CImGui.Checkbox(mlstr("flip vertically"), &dtpk.vflipz)
                    CImGui.SameLine(CImGui.GetContentRegionAvailWidth() / 2)
                    @c CImGui.Checkbox(mlstr("flip horizontally"), &dtpk.hflipz)
                    @c CImGui.Checkbox(mlstr("nonuniform axes"), &dtpk.nonuniform)
                end
            end

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
                CImGui.Button(
                    stcstr(
                        MORESTYLE.Icons.Update, " ",
                        dtpk.isrunning ? stcstr(mlstr("Updating..."), " ", dtpk.runtime, "s") : mlstr("Update"), " "
                    )
                ) && (isupdate = true)
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
end

let
    synctasks::Dict{String,Task} = Dict()
    global function syncplotdata(uiplot::UIPlot, dtpk::DataPicker, datastr::Dict, datafloat::Dict=Dict())
        if haskey(synctasks, uiplot.ps.id)
            istaskdone(synctasks[uiplot.ps.id]) ? delete!(synctasks, uiplot.ps.id) : return nothing
        end
        pdtask = @async processdata(uiplot, dtpk, datastr, datafloat)
        push!(synctasks, uiplot.ps.id => pdtask)
        return nothing
    end

    function processdata(uiplot::UIPlot, dtpk::DataPicker, datastr::Dict, datafloat::Dict)
        dtpk.isrunning = true
        dtpk.runtime = 0
        errormonitor(
            @async begin
                t1 = time()
                while dtpk.isrunning
                    dtpk.runtime = round(time() - t1; digits=1)
                    sleep(0.001)
                    yield()
                end
            end
        )
        uiplot.ptype = dtpk.ptype
        if isempty(datafloat)
            if dtpk.xtype
                xbuf = haskey(datastr, dtpk.x) ? replace(tryparse.(Float64, datastr[dtpk.x]), nothing => NaN) : Float64[]
            else
                xbuf = haskey(datastr, dtpk.x) ? copy(datastr[dtpk.x]) : String[]
            end
            ybuf = @trypass(
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
                xbuf = haskey(datafloat, dtpk.x) ? copy(datafloat[dtpk.x]) : Float64[]
            else
                xbuf = haskey(datastr, dtpk.x) ? copy(datastr[dtpk.x]) : String[]
            end
            ybuf = @trypass [copy(datafloat[key]) for key in dtpk.datalist[dtpk.y]] [Float64[]]
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
                x = $xbuf
                ys = $ybuf
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
        end
        try
            uiplot.x, uiplot.y, nz = if nprocs() > 2
                f = @eval Main QInsControl.remotecall(() -> eval($ex), QInsControl.workers()[2])
                waittask = errormonitor(@async fetch(f))
                wait(waittask)
                fetch(waittask)
            else
                eval(ex)
            end
            if uiplot.ptype == "heatmap"
                true in ismissing.(nz) && (replace!(nz, missing => 0); nz = float.(nz))
                true in isnan.(nz) && replace!(nz, NaN => 0)
                Inf in nz && (replace!(nz, Inf => 0))
                -Inf in nz && (replace!(nz, -Inf => 0))
                if nz isa Matrix
                    uiplot.z = collect(transpose(nz))
                else
                    lmin = min(length(uiplot.z), length(nz))
                    rows = ceil(Int, lmin / dtpk.zsize[1])
                    fill!(uiplot.z, zero(eltype(uiplot.z)))
                    @views uiplot.z[1:rows, :] = transpose(resize(nz, dtpk.zsize[1], rows))
                end
                dtpk.nonuniform && uniformz!(uiplot.y[1], uiplot.x, uiplot.z)
                dtpk.vflipz && reverse!(uiplot.z, dims=2)
                dtpk.hflipz && reverse!(uiplot.z, dims=1)
            end
            dtpk.isrealtime || @info "[$(now())]" data_processing = prettify(innercodes)
        catch e
            dtpk.isrealtime || @error "[$(now())]\n$(mlstr("processing data failed!!!"))" exception = e codes = prettify(ex)
        finally
            dtpk.isrunning = false
        end
    end
end