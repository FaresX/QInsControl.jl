@kwdef mutable struct DataSeries
    x::String = ""
    y::String = ""
    z::String = ""
    w::String = ""
    aux::Vector{String} = String[]
    xtype::Bool = true # true = > Number false = > String
    processcodes::CodeBlock = CodeBlock()
    processfigurecodes::CodeBlock = CodeBlock(codes="autolimits!(content(figure[1,1]))")
    plotcodes::CodeBlock = CodeBlock(codes="lines!(content(figure[1,1]), x, y)")
    update::Bool = false
    updateprocessfunc::Bool = false
    updateprocessfigurefunc::Bool = false
    updateplot::Bool = false
    isrealtime::Bool = false
    isrunning::Bool = false
    runtime::Float64 = 0
    refreshrate::Cfloat = 0.1
    alsz::Cfloat = 0
end

@kwdef mutable struct DataPicker
    datalist::Vector{String} = String[]
    series::Vector{DataSeries} = [DataSeries()]
    codes::CodeBlock = CodeBlock(codes="Axis(figure[1,1])\nDataInspector(figure)")
    hold::Bool = false
    update::Bool = false
    updatelayout::Bool = false
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
            CImGui.SameLine(CImGui.GetContentRegionAvail().x - holdsz)
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
            if CImGui.CollapsingHeader(mlstr("Figure Layout"))
                CImGui.Button(stcstr(MORESTYLE.Icons.Update, " ", mlstr("Update Layout"))) && (dtpk.updatelayout = true)
                CImGui.Text("function layout!(figure)")
                CImGui.PushID("Layout")
                edit(dtpk.codes)
                CImGui.PopID()
            end
            CImGui.BeginChild("Series Child")
            for (i, dtss) in enumerate(dtpk.series)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.HighlightText)
                openseries = CImGui.CollapsingHeader(stcstr(mlstr("Series"), " ", i))
                CImGui.PopStyleColor()
                if CImGui.BeginPopupContextItem()
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy"))) && (copyseries = deepcopy(dtss))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste"))) && insert!(dtpk.series, i + 1, deepcopy(copyseries))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (deleteat!(dtpk.series, i); break)
                    CImGui.EndPopup()
                end
                if CImGui.BeginDragDropSource(0)
                    @c CImGui.SetDragDropPayload("Swap Series", &i, sizeof(Cint))
                    CImGui.Text(stcstr(mlstr("Series"), " ", i))
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
                    CImGui.BeginChild("Series")
                    edit(dtss, dtpk.datalist)
                    CImGui.EndChild()
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
        CImGui.PopItemWidth()
        CImGui.RadioButton(mlstr("number"), dtss.xtype) && (dtss.xtype = true)
        CImGui.SameLine(0, 2CImGui.GetFontSize())
        CImGui.RadioButton(mlstr("text"), !dtss.xtype) && (dtss.xtype = false)
        CImGui.EndGroup()

        BoxTextColored("Y"; size=(4CImGui.GetFontSize(), Cfloat(0)), col=MORESTYLE.Colors.HighlightText)
        CImGui.SameLine()
        CImGui.BeginGroup()
        CImGui.PushItemWidth(-1)
        @c ComboS("##select Y", &dtss.y, datalist)
        CImGui.PopItemWidth()
        CImGui.EndGroup()

        BoxTextColored("Z"; size=(4CImGui.GetFontSize(), Cfloat(0)), col=MORESTYLE.Colors.HighlightText)
        CImGui.SameLine()
        CImGui.BeginGroup()
        CImGui.PushItemWidth(-1)
        @c ComboS("##select Z", &dtss.z, datalist)
        CImGui.PopItemWidth()
        CImGui.EndGroup()

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

        SeparatorTextColored(MORESTYLE.Colors.LogInfo, mlstr("Data Processing"))
        if dtss.isrealtime
            CImGui.Button(stcstr(MORESTYLE.Icons.Update, " ", mlstr("Update Function"))) && (dtss.updateprocessfunc = true)
            CImGui.SameLine(CImGui.GetContentRegionAvail().x - dtss.alsz)
            CImGui.Text(mlstr("sampling rate"))
            CImGui.SameLine()
            dtss.alsz = CImGui.GetItemRectSize().x
            CImGui.PushItemWidth(2CImGui.GetFontSize())
            @c CImGui.DragFloat("s", &dtss.refreshrate, 0.01, 0.01, 60, "%.2f", CImGui.ImGuiSliderFlags_AlwaysClamp)
            CImGui.PopItemWidth()
            dtss.alsz += CImGui.GetItemRectSize().x + unsafe_load(IMGUISTYLE.ItemSpacing.x)
            CImGui.SameLine()
        else
            CImGui.Button(
                stcstr(
                    MORESTYLE.Icons.Update, " ",
                    dtss.isrunning ? stcstr(mlstr("Updating..."), " ", dtss.runtime, "s") : mlstr("Update"), " "
                )
            ) && (dtss.update = true; dtss.updateprocessfunc = true)
            CImGui.SameLine(CImGui.GetContentRegionAvail().x - dtss.alsz)
            dtss.alsz = -unsafe_load(IMGUISTYLE.ItemSpacing.x)
        end
        @c CImGui.Checkbox("RT", &dtss.isrealtime)
        dtss.alsz += CImGui.GetItemRectSize().x + unsafe_load(IMGUISTYLE.ItemSpacing.x)
        CImGui.IsItemHovered() && CImGui.SetTooltip(mlstr("real-time data update/manual data update"))

        CImGui.PushID("process data")
        CImGui.Text("function process(x, y, z, w, [auxi]...)")
        edit(dtss.processcodes)
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(mlstr("Clear")) && (dtss.processcodes = "")
            CImGui.EndPopup()
        end
        CImGui.PopID()
        CImGui.PushID("process figure")
        CImGui.Text("function process!(figure, x, y, z)")
        edit(dtss.processfigurecodes)
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(mlstr("Clear")) && (dtss.processfigurecodes = "")
            CImGui.EndPopup()
        end
        CImGui.PopID()
        CImGui.PushID("define plot")
        CImGui.Button(stcstr(MORESTYLE.Icons.Update, " ", mlstr("Update Plot"))) && (dtss.updateplot = true)
        CImGui.Text("function plot!(figure, x, y, z)")
        edit(dtss.plotcodes)
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(mlstr("Clear")) && (dtss.plotcodes = "")
            CImGui.EndPopup()
        end
        CImGui.PopID()
    end
end

let
    synctasks::Dict{String,Dict{Int,Task}} = Dict()
    global function syncplotdata(
        plt::QPlot,
        dtpk::DataPicker,
        datastr::Dict{String,Vector{String}},
        datafloat::Dict{String,VecOrMat{Cdouble}}=Dict{String,VecOrMat{Cdouble}}()
    )
        haskey(FIGURES, plt.id) || (FIGURES[plt.id] = Figure())
        haskey(synctasks, plt.id) || (synctasks[plt.id] = Dict())
        if dtpk.update
            dtpk.updatelayout = true
            for dtss in dtpk.series
                dtss.update = true
                dtss.updateprocessfunc = true
                dtss.updateprocessfigurefunc = true
                dtss.updateplot = true
            end
        end
        if dtpk.updatelayout
            dtpk.updatelayout = false
            plotfigurelayout(plt, dtpk)
        end
        for (i, dtss) in enumerate(dtpk.series)
            if dtss.update || (dtss.isrealtime && waittime(stcstr("DataPicker", plt.id, "-", i), dtss.refreshrate))
                if haskey(synctasks[plt.id], i) && istaskdone(synctasks[plt.id][i])
                    if !istaskfailed(synctasks[plt.id][i])
                        x, y, z = fetch(synctasks[plt.id][i])
                        setobservables!(dtss, x, y, z)
                        postprocess(plt, dtss, x, y, z)
                    end
                    delete!(synctasks[plt.id], i)
                end
                if !haskey(synctasks[plt.id], i)
                    pdtask = Threads.@spawn preprocess(dtss, datastr, datafloat)
                    synctasks[plt.id][i] = pdtask
                    if dtss.update
                        timedwaitfetch(pdtask, 6; msg=mlstr("force to stop processing data due to timeout"))
                        if !istaskfailed(pdtask)
                            x, y, z = fetch(pdtask)
                            setobservables!(dtss, x, y, z)
                            postprocess(plt, dtss, x, y, z)
                        end
                        delete!(synctasks[plt.id], i)
                    end
                end
                dtss.update = false
            end
            if dtss.updateplot
                plottofigure(plt, dtss)
                dtss.updateplot = false
            end
        end
        dtpk.update = false
    end

    observables::Dict{DataSeries,NTuple{3,Observable}} = Dict()
    global getobservables(dtss::DataSeries) = observables[dtss]
    global function setobservables!(dtss::DataSeries, x, y, z)
        try
            cx, cy, cz = collect(x), collect(y), collect(z)
            if haskey(observables, dtss) && typeof(cx) == typeof(observables[dtss][1][]) &&
               typeof(cy) == typeof(observables[dtss][2][]) && typeof(cz) == typeof(observables[dtss][3][])
                isempty(cx) || (observables[dtss][1].val = cx)
                isempty(cy) || (observables[dtss][2].val = cy)
                if !isempty(cz)
                    if size(cz) == size(observables[dtss][3][])
                        observables[dtss][3].val = cz
                    else
                        observables[dtss] = (observables[dtss][1], observables[dtss][2], Observable(cz))
                    end
                end
                notify.(observables[dtss])
            else
                observables[dtss] = (Observable(collect(cx)), Observable(collect(cy)), Observable(collect(cz)))
            end
        catch e
            if !dtss.isrealtime
                @error string("[", now(), "]\n", mlstr("setting observables failed!!!")) exception = e
                showbacktrace()
            end
        end
    end
    global rmobvs(dtss) = delete!(observables, dtss)

    function plotfigurelayout(plt::QPlot, dtpk::DataPicker)
        try
            rmplot!(plt)
            FIGURES[plt.id] = Figure()
            ex = quote
                (figure::Figure -> begin
                    $(tocodes(dtpk.codes))
                end)(FIGURES[$(plt.id)])
            end
            eval(ex)
        catch
            @error string("[", now(), "]\n", mlstr("plotting layout failed!!!"))
            showbacktrace()
        end
    end

    processfuncs::Dict{DataSeries,Function} = Dict()
    function preprocess(dtss::DataSeries, datastr::Dict{String,Vector{String}}, datafloat::Dict{String,VecOrMat{Cdouble}})
        timingtask = errormonitor(
                @async begin
                    t1 = time()
                    while dtss.isrunning
                        dtss.runtime = round(time() - t1; digits=1)
                        sleep(0.05)
                    end
                end
            )
        try
            dtss.isrunning = true
            dtss.runtime = 0
            xbuf = dtss.xtype ? loaddata(datastr, datafloat, dtss.x) : haskey(datastr, dtss.x) ? copy(datastr[dtss.x]) : String[]
            ybuf = loaddata(datastr, datafloat, dtss.y)
            zbuf = loaddata(datastr, datafloat, dtss.z)
            wbuf = loaddata(datastr, datafloat, dtss.w)
            auxbufs = [loaddata(datastr, datafloat, aux) for aux in dtss.aux]
            if dtss.updateprocessfunc || !haskey(processfuncs, dtss)
                innercodes = tocodes(dtss.processcodes)
                exfunc::Expr = quote
                    (x, y, z, w, $([Symbol.(:aux, i) for i in eachindex(auxbufs)]...)) -> begin
                        $innercodes
                        x, y, z
                    end
                end
                processfuncs[dtss] = CONF.DAQ.externaleval ? @eval(Main, $exfunc) : eval(exfunc)
                dtss.updateprocessfigurefunc = true
            end
            exprocess = :($(processfuncs[dtss])($xbuf, $ybuf, $zbuf, $wbuf, $auxbufs...))
            return CONF.DAQ.externaleval ? @eval(Main, $exprocess) : eval(exprocess)
        catch e
            if !dtss.isrealtime
                @error string("[", now(), "]\n", mlstr("pre-processing data failed!!!")) exception = e
                showbacktrace()
            end
            rethrow()
        finally
            dtss.updateprocessfunc = false
            dtss.isrunning = false
            timedwaitfetch(timingtask, 0.1; msg=mlstr("force to stop timing task"))
        end
    end
    processfigurefuncs::Dict{DataSeries,Function} = Dict()
    function postprocess(plt::QPlot, dtss::DataSeries, x, y, z)
        try
            if dtss.updateprocessfigurefunc || !haskey(processfigurefuncs, dtss)
                innercodes = tocodes(dtss.processfigurecodes)
                exfunc::Expr = quote
                    (figure::Figure, x, y, z) -> begin
                        $innercodes
                    end
                end
                processfigurefuncs[dtss] = CONF.DAQ.externaleval ? @eval(Main, $exfunc) : eval(exfunc)
            end
            :($(processfigurefuncs[dtss])(FIGURES[$(plt.id)], $x, $y, $z)) |> eval
        catch e
            if !dtss.isrealtime
                @error string("[", now(), "]\n", mlstr("post-processing figure failed!!!")) exception = e
                showbacktrace()
            end
        finally
            dtss.updateprocessfigurefunc = false
        end
    end

    function plottofigure(plt::QPlot, dtss::DataSeries)
        try
            ex = quote
                (figure::Figure -> begin
                    x, y, z = getobservables($dtss)
                    $(tocodes(dtss.plotcodes))
                end)(FIGURES[$(plt.id)])
            end
            eval(ex)
        catch e
            @error string("[", now(), "]\n", mlstr("plotting data failed!!!")) exception = e
            showbacktrace()
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