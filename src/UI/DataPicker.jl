@kwdef mutable struct DataSeries
    ptype::String = "line"
    x::String = ""
    y::String = ""
    z::String = ""
    w::String = ""
    aux::Vector{String} = String[]
    xaxis::Cint = 1
    yaxis::Cint = 1
    zaxis::Cint = 1
    legend::String = "s1"
    sampling::Bool = false
    samplingnum::Cint = 0
    xtype::Bool = true # true = > Number false = > String
    zsize::Vector{Cint} = [0, 0]
    vflipz::Bool = false
    hflipz::Bool = false
    nonuniformx::Bool = false
    nonuniformy::Bool = false
    codes::CodeBlock = CodeBlock()
    update::Bool = false
    updatefunc::Bool = false
    isrealtime::Bool = false
    isrunning::Bool = false
    runtime::Float64 = 0
    refreshrate::Cfloat = 1
    alsz::Cfloat = 0
end

@kwdef mutable struct DataPicker
    datalist::Vector{String} = String[]
    series::Vector{DataSeries} = [DataSeries()]
    hold::Bool = false
    update::Bool = false
end

let
    holdsz::Cfloat = 0
    copyseries::DataSeries = DataSeries()
    global function edit(dtpk::DataPicker, id, p_open::Ref{Bool})
        CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Once)
        CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PopupBg))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding, unsafe_load(IMGUISTYLE.PopupRounding))
        isfocus = true
        if CImGui.Begin(
            stcstr("Data Selecting##", id),
            p_open,
            CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoDocking
        )
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0, 0, 0, 0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
            # CImGui.TextColored(MORESTYLE.Colors.HighlightText, MORESTYLE.Icons.Plot)
            CImGui.Button(MORESTYLE.Icons.Plot)
            CImGui.PopStyleColor()
            CImGui.SameLine()
            CImGui.Button(stcstr(" ", mlstr("Data Selecting")))
            CImGui.PopStyleColor(3)
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() - holdsz)
            CImGui.Button(MORESTYLE.Icons.Update) && (dtpk.update = true)
            holdsz = CImGui.GetItemRectSize().x
            CImGui.SameLine()
            CImGui.Button(MORESTYLE.Icons.NewFile) && push!(dtpk.series, DataSeries())
            holdsz += CImGui.GetItemRectSize().x
            CImGui.SameLine()
            CImGui.Button(MORESTYLE.Icons.CloseFile) && (isempty(dtpk.series) || pop!(dtpk.series))
            holdsz += CImGui.GetItemRectSize().x + 2unsafe_load(IMGUISTYLE.ItemSpacing.x)
            CImGui.SameLine()
            @c ToggleButton(MORESTYLE.Icons.HoldPin, &dtpk.hold)
            holdsz += CImGui.GetItemRectSize().x
            CImGui.BeginChild("Series")
            for (i, dtss) in enumerate(dtpk.series)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
                openseries = CImGui.CollapsingHeader(stcstr(mlstr("Series"), " ", i, " ", dtss.legend, "###", i))
                CImGui.PopStyleColor()
                if CImGui.BeginPopupContextItem()
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy"))) && (copyseries = deepcopy(dtss))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste"))) && insert!(dtpk.series, i + 1, deepcopy(copyseries))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (deleteat!(dtpk.series, i); break)
                    CImGui.EndPopup()
                end
                if CImGui.BeginDragDropSource(0)
                    @c CImGui.SetDragDropPayload("Swap Series", &i, sizeof(Cint))
                    CImGui.Text(stcstr(mlstr("Series"), " ", i, " ", dtss.legend))
                    CImGui.EndDragDropSource()
                end
                if CImGui.BeginDragDropTarget()
                    payload = CImGui.AcceptDragDropPayload("Swap Series")
                    if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                        payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                        if i != payload_i
                            insert!(dtpk.series, i, dtpk.series[payload_i])
                            deleteat!(dtpk.series, payload_i < i ? payload_i : payload_i + 1)
                            dtpk.update = true
                        end
                    end
                    CImGui.EndDragDropTarget()
                end
                if openseries
                    CImGui.PushID(i)
                    edit(dtss, dtpk.datalist)
                    CImGui.PopID()
                end
            end
            CImGui.EndChild()
            if CImGui.BeginPopup("copymenu")
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste"))) && push!(dtpk.series, deepcopy(copyseries))
                CImGui.EndPopup()
            end
            CImGui.IsAnyItemHovered() || CImGui.OpenPopupOnItemClick("copymenu")
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        CImGui.End()
        p_open[] &= (isfocus | dtpk.hold)
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
    end
end

let
    ptypelist::Vector{String} = ["line", "scatter", "stairs", "stems", "heatmap"]
    global function edit(dtss::DataSeries, datalist)
        availwidth = CImGui.GetContentRegionAvailWidth()
        CImGui.PushItemWidth(availwidth / 3)
        @c InputTextRSZ(mlstr("legend"), &dtss.legend)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        @c CImGui.Checkbox(mlstr("##sampling"), &dtss.sampling)
        CImGui.SameLine()
        CImGui.PushItemWidth(availwidth / 3)
        @c CImGui.DragInt(mlstr("sampling"), &dtss.samplingnum, 100, 0, 1000000, "%d", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()
        CImGui.PushItemWidth(availwidth / 3)
        @c ComboS(mlstr("plot type"), &dtss.ptype, ptypelist)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.NewFile)) && push!(dtss.aux, "")
        CImGui.SameLine()
        CImGui.Button(stcstr(MORESTYLE.Icons.CloseFile)) && (isempty(dtss.aux) || pop!(dtss.aux))
        CImGui.SameLine()
        CImGui.Text(mlstr("Aux Dims"))
        CImGui.Separator()

        BoxTextColored("X"; size=(4CImGui.GetFontSize(), Cfloat(0)), col=MORESTYLE.Colors.HighlightText)
        CImGui.SameLine()
        CImGui.BeginGroup()
        CImGui.PushItemWidth(-1)
        @c ComboS("##select X", &dtss.x, datalist)
        CImGui.PushItemWidth(CImGui.GetContentRegionAvailWidth() / 2)
        @c CImGui.SliderInt(stcstr("X", mlstr("axis")), &dtss.xaxis, 1, 3)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PopItemWidth()
        @c CImGui.Checkbox(dtss.xtype ? mlstr("number") : mlstr("text"), &dtss.xtype)
        CImGui.EndGroup()

        BoxTextColored("Y"; size=(4CImGui.GetFontSize(), Cfloat(0)), col=MORESTYLE.Colors.HighlightText)
        CImGui.SameLine()
        CImGui.BeginGroup()
        CImGui.PushItemWidth(-1)
        @c ComboS("##select Y", &dtss.y, datalist)
        CImGui.PopItemWidth()
        CImGui.PushItemWidth(CImGui.GetContentRegionAvailWidth() / 2)
        @c CImGui.SliderInt(stcstr("Y", mlstr("axis")), &dtss.yaxis, 1, 3)
        CImGui.PopItemWidth()
        CImGui.EndGroup()

        if dtss.ptype == "heatmap"
            BoxTextColored("Z"; size=(4CImGui.GetFontSize(), Cfloat(0)), col=MORESTYLE.Colors.HighlightText)
            CImGui.SameLine()
            CImGui.BeginGroup()
            CImGui.PushItemWidth(-1)
            @c ComboS("##select Z", &dtss.z, datalist)
            CImGui.PopItemWidth()
            CImGui.PushItemWidth(CImGui.GetContentRegionAvailWidth() / 2)
            @c CImGui.SliderInt(stcstr("Z", mlstr("axis")), &dtss.zaxis, 1, 6)
            CImGui.PopItemWidth()
            CImGui.PushItemWidth(-CImGui.CalcTextSize(mlstr("matrix size")).x - 2CImGui.GetFontSize())
            CImGui.DragInt2(
                mlstr("matrix size"), dtss.zsize, 1, 0, 1000000, "%d",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            CImGui.PopItemWidth()
            if SYNCSTATES[Int(IsDAQTaskRunning)]
                CImGui.SameLine()
                if CImGui.Button(MORESTYLE.Icons.InstrumentsAutoRef) && length(PROGRESSLIST) == 2
                    dtss.zsize .= reverse([pgb[3] for pgb in values(PROGRESSLIST)])
                end
            end
            @c CImGui.Checkbox(mlstr("flip vertically"), &dtss.vflipz)
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() / 2)
            @c CImGui.Checkbox(mlstr("flip horizontally"), &dtss.hflipz)
            @c CImGui.Checkbox(stcstr(mlstr("nonuniform"), " ", "X"), &dtss.nonuniformx)
            CImGui.SameLine(CImGui.GetContentRegionAvailWidth() / 2)
            @c CImGui.Checkbox(stcstr(mlstr("nonuniform"), " ", "Y"), &dtss.nonuniformy)
            CImGui.EndGroup()
        end

        BoxTextColored("W"; size=(4CImGui.GetFontSize(), Cfloat(0)), col=MORESTYLE.Colors.HighlightText)
        CImGui.SameLine()
        CImGui.PushItemWidth(-1)
        @c ComboS("##select W", &dtss.w, datalist)
        CImGui.PopItemWidth()

        for (i, aux) in enumerate(dtss.aux)
            BoxTextColored(stcstr("AUX", " ", i); size=(4CImGui.GetFontSize(), Cfloat(0)), col=MORESTYLE.Colors.HighlightText)
            CImGui.SameLine()
            CImGui.PushItemWidth(-1)
            @c(ComboS(stcstr("##select AUX", i), &aux, datalist)) && (dtss.aux[i] = aux)
            CImGui.PopItemWidth()
        end

        SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Data Processing"))
        if dtss.isrealtime
            CImGui.Button(stcstr(MORESTYLE.Icons.Update, " ", mlstr("Update Function"))) && (dtss.updatefunc = true)
            CImGui.SameLine(CImGui.GetWindowContentRegionWidth() - dtss.alsz)
            CImGui.Text(mlstr("sampling rate"))
            CImGui.SameLine()
            dtss.alsz = CImGui.GetItemRectSize().x
            CImGui.PushItemWidth(2CImGui.GetFontSize())
            @c CImGui.DragFloat("s", &dtss.refreshrate, 0.01, 0.01, 60, "%.2f", CImGui.ImGuiSliderFlags_AlwaysClamp)
            CImGui.SameLine()
            CImGui.PopItemWidth()
            dtss.alsz += CImGui.GetItemRectSize().x + unsafe_load(IMGUISTYLE.ItemSpacing.x)
        else
            CImGui.Button(
                stcstr(
                    MORESTYLE.Icons.Update, " ",
                    dtss.isrunning ? stcstr(mlstr("Updating..."), " ", dtss.runtime, "s") : mlstr("Update"), " "
                )
            ) && (dtss.update = true; dtss.updatefunc = true)
            CImGui.SameLine(CImGui.GetWindowContentRegionWidth() - dtss.alsz)
            dtss.alsz = 0
        end
        @c CImGui.Checkbox("RT", &dtss.isrealtime)
        dtss.alsz += CImGui.GetItemRectSize().x + unsafe_load(IMGUISTYLE.ItemSpacing.x)
        CImGui.IsItemHovered() && CImGui.SetTooltip(mlstr("real-time data update/manual data update"))

        CImGui.PushID("select XYZ")
        CImGui.Text("function process(x, y, z, w, [auxi]...)")
        edit(dtss.codes)
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(mlstr("Clear")) && (dtss.codes.codes = "")
            CImGui.EndPopup()
        end
        CImGui.PopID()
    end
end

let
    synctasks::Dict{String,Dict{Int,Task}} = Dict()
    global function syncplotdata(
        plt::Plot,
        dtpk::DataPicker,
        datastr::Dict{String,Vector{String}},
        datafloat::Dict{String,VecOrMat{Cdouble}}=Dict{String,VecOrMat{Cdouble}}();
        force=false
    )
        haskey(synctasks, plt.id) || (synctasks[plt.id] = Dict())
        lpltss = length(plt.series)
        ldtpkss = length(dtpk.series)
        if lpltss < ldtpkss
            append!(plt.series, fill(PlotSeries(), ldtpkss - lpltss))
            mergexaxes!(plt)
            mergeyaxes!(plt)
            mergezaxes!(plt)
        elseif lpltss > ldtpkss
            deleteat!(plt.series, ldtpkss+1:lpltss)
            mergexaxes!(plt)
            mergeyaxes!(plt)
            mergezaxes!(plt)
        end
        for (i, dtss) in enumerate(dtpk.series)
            if dtpk.update || dtss.update || (dtss.isrealtime && waittime(stcstr("DataPicker", plt.id, "-", i), dtss.refreshrate))
                if haskey(synctasks[plt.id], i)
                    if istaskdone(synctasks[plt.id][i])
                        istaskfailed(synctasks[plt.id][i]) || postprocess(
                            plt, plt.series[i], dtss, fetch(synctasks[plt.id][i])...; force=force
                        )
                        delete!(synctasks[plt.id], i)
                    else
                        force || continue
                    end
                end
                pdtask = Threads.@spawn preprocess(dtss, datastr, datafloat)
                synctasks[plt.id][i] = pdtask
                if dtpk.update || dtss.update
                    try
                        wait(pdtask)
                    catch
                    end
                    istaskfailed(pdtask) || postprocess(plt, plt.series[i], dtss, fetch(pdtask)...; force=force)
                    delete!(synctasks[plt.id], i)
                end
                dtss.update = false
            end
        end
        dtpk.update = false
    end

    processfuncs::Dict{DataSeries,Function} = Dict()
    function preprocess(dtss::DataSeries, datastr::Dict{String,Vector{String}}, datafloat::Dict{String,VecOrMat{Cdouble}})
        try
            dtss.isrunning = true
            dtss.runtime = 0
            errormonitor(
                @async begin
                    t1 = time()
                    while dtss.isrunning
                        dtss.runtime = round(time() - t1; digits=1)
                        sleep(0.05)
                    end
                end
            )
            xbuf = dtss.xtype ? loaddata(datastr, datafloat, dtss.x) : haskey(datastr, dtss.x) ? copy(datastr[dtss.x]) : String[]
            ybuf = loaddata(datastr, datafloat, dtss.y)
            zbuf = dtss.ptype == "heatmap" ? loaddata(datastr, datafloat, dtss.z) : Cdouble[]
            wbuf = loaddata(datastr, datafloat, dtss.w)
            auxbufs = [loaddata(datastr, datafloat, aux) for aux in dtss.aux]
            if dtss.updatefunc || !haskey(processfuncs, dtss)
                innercodes = tocodes(dtss.codes)
                exfunc::Expr = quote
                    (x, y, z, w, $([Symbol.(:aux, i) for i in eachindex(auxbufs)]...)) -> begin
                        $innercodes
                        x, y, z
                    end
                end
                processfuncs[dtss] = CONF.DAQ.externaleval ? @eval(Main, $exfunc) : eval(exfunc)
                dtss.updatefunc = false
            end
            exprocess=:($(processfuncs[dtss])($xbuf, $ybuf, $zbuf, $wbuf, $auxbufs...))
            return CONF.DAQ.externaleval ? @eval(Main, $exprocess) : eval(exprocess)
        catch e
            if !dtss.isrealtime
                @error string("[", now(), "]\n", mlstr("pre-processing data failed!!!")) exception = e
                showbacktrace()
            end
            rethrow()
        finally
            dtss.isrunning = false
        end
    end

    function postprocess(plt::Plot, pss::PlotSeries, dtss::DataSeries, nx, ny, nz; force=false)
        forcesync = force || pss.ptype != dtss.ptype
        forcesync && (pss.ptype = dtss.ptype)
        forcesync |= !dtss.xtype || (dtss.xtype && !isempty(pss.axis.xaxis.ticklabels))
        try
            if pss.ptype == "heatmap"
                dropexeption!(nz)
                if nz isa Matrix
                    pss.z = transpose(nz)
                else
                    all(size(pss.z) .== reverse(dtss.zsize)) || (pss.z = zeros(Float64, reverse(dtss.zsize)...))
                    lmin = min(length(pss.z), length(nz))
                    rows = ceil(Int, lmin / dtss.zsize[1])
                    fill!(pss.z, zero(eltype(pss.z)))
                    @views pss.z[1:rows, :] = transpose(resize(nz, dtss.zsize[1], rows))
                end
                dtss.nonuniformx && uniformx!(pss.x, pss.z)
                dtss.nonuniformx && uniformy!(pss.y, pss.z)
                dtss.vflipz && reverse!(pss.z, dims=2)
                dtss.hflipz && reverse!(pss.z, dims=1)
                setupplotseries!(pss, nx, ny, pss.z)
                if dtss.sampling
                    pss.x, pss.y, pss.z = imgsampling(
                        pss.x, pss.y, pss.z; num=min(dtss.samplingnum, CONF.Basic.samplingthreshold)
                    )
                else
                    if length(pss.z) > CONF.Basic.samplingthreshold
                        pss.x, pss.y, pss.z = imgsampling(pss.x, pss.y, pss.z; num=CONF.Basic.samplingthreshold)
                    end
                end
            else
                setupplotseries!(pss, nx, ny)
                if dtss.sampling
                    pss.x, pss.y = imgsampling(pss.x, pss.y; num=min(dtss.samplingnum, CONF.Basic.samplingthreshold))
                else
                    if length(pss.x) > CONF.Basic.samplingthreshold && length(pss.y) > CONF.Basic.samplingthreshold
                        pss.x, pss.y = imgsampling(pss.x, pss.y; num=CONF.Basic.samplingthreshold)
                    end
                end
            end
            syncaxes(plt, pss, dtss; force=forcesync)
        catch e
            if !dtss.isrealtime
                @error "[$(now())]\n$(mlstr("post-processing data failed!!!"))" exception = e
                showbacktrace()
            end
        end
    end

    function loaddata(datastr::Dict{String,Vector{String}}, datafloat::Dict{String,VecOrMat{Cdouble}}, key)
        if isempty(datafloat)
            haskey(datastr, key) ? replace(tryparse.(Cdouble, datastr[key]), nothing => NaN) : Float64[]
        else
            haskey(datafloat, key) ? copy(datafloat[key]) : Float64[]
        end
    end
end

function syncaxes(plt::Plot, pss::PlotSeries, dtss::DataSeries; force=false)
    pss.legend = dtss.legend
    if pss.axis.xaxis.axis + 1 != dtss.xaxis || force
        pss.axis.xaxis.axis = ImPlot.ImAxis_(dtss.xaxis - 1)
        mergexaxes!(plt)
    end
    if pss.axis.yaxis.axis - 2 != dtss.yaxis || force
        pss.axis.yaxis.axis = ImPlot.ImAxis_(dtss.yaxis + 2)
        mergeyaxes!(plt)
    end
    changez = pss.axis.zaxis.axis != dtss.zaxis || isempty(plt.zaxes)
    if !(isempty(plt.zaxes) || isempty(pss.z))
        zlims = extrema(pss.z)
        zlims[1] == zlims[2] && (zlims = (0, 1))
        pss.axis.zaxis.lims = zlims
        changez |= pss.axis.zaxis.lims != plt.zaxes[findfirst(za -> za.axis == pss.axis.zaxis.axis, plt.zaxes)].lims
    end
    if (pss.ptype == "heatmap" && changez) || force
        pss.axis.zaxis.axis = dtss.zaxis
        mergezaxes!(plt)
    end
end
