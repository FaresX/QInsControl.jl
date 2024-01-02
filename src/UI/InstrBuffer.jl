abstract type AbstractQuantity end
@kwdef mutable struct SweepQuantity <: AbstractQuantity
    # back end
    enable::Bool = true
    name::String = ""
    alias::String = ""
    step::String = ""
    stop::String = ""
    delay::Cfloat = 0.1
    read::String = ""
    utype::String = ""
    uindex::Int = 1
    help::String = ""
    isautorefresh::Bool = false
    issweeping::Bool = false
    # front end
    showval::String = ""
    showU::String = ""
    show_edit::String = ""
    show_view::String = ""
    passfilter::Bool = true
end

@kwdef mutable struct SetQuantity <: AbstractQuantity
    # back end
    enable::Bool = true
    name::String = ""
    alias::String = ""
    set::String = ""
    optkeys::Vector{String} = []
    optvalues::Vector{String} = []
    optedidx::Cint = 1
    read::String = ""
    utype::String = ""
    uindex::Int = 1
    help::String = ""
    isautorefresh::Bool = false
    # front end
    showval::String = ""
    showU::String = ""
    show_edit::String = ""
    show_view::String = ""
    passfilter::Bool = true
end

@kwdef mutable struct ReadQuantity <: AbstractQuantity
    # back end
    enable::Bool = true
    name::String = ""
    alias::String = ""
    read::String = ""
    utype::String = ""
    uindex::Int = 1
    help::String = ""
    isautorefresh::Bool = false
    # front end
    showval::String = ""
    showU::String = ""
    show_edit::String = ""
    show_view::String = ""
    passfilter::Bool = true
end

function quantity(name, qtcf::QuantityConf)
    return if qtcf.type == "sweep"
        SweepQuantity(name=name, alias=qtcf.alias, utype=qtcf.U, help=qtcf.help)
    elseif qtcf.type == "set"
        SetQuantity(
            name=name, alias=qtcf.alias, optkeys=qtcf.optkeys, optvalues=qtcf.optvalues, utype=qtcf.U, help=qtcf.help
        )
    elseif qtcf.type == "read"
        ReadQuantity(name=name, alias=qtcf.alias, utype=qtcf.U, help=qtcf.help)
    end
end

function getvalU!(qt::AbstractQuantity)
    U, Us = @c getU(qt.utype, &qt.uindex)
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    qt.showval = U == "" ? qt.read : @trypass @sprintf("%g", parse(Float64, qt.read) / Uchange) qt.read
    qt.showU = string(U)
end

function updatefront!(qt::SweepQuantity)
    getvalU!(qt)
    content = string("\n", qt.alias, "\n \n", qt.showval, " ", qt.showU, "\n ") |> centermultiline
    qt.show_edit = string(content, "###for refresh")
end

function updateoptvalue!(qt::SetQuantity)
    if qt.showU == ""
        if qt.read in qt.optvalues
            qt.optedidx = findfirst(==(qt.read), qt.optvalues)
            qt.showval = string(qt.optkeys[qt.optedidx], " => ", qt.read)
        end
    else
        floatread = tryparse(Float64, qt.read)
        if !isnothing(floatread)
            floatoptvalues = replace(tryparse.(Float64, qt.optvalues), nothing => NaN)
            if true in Bool.(floatread .≈ floatoptvalues)
                qt.optedidx = findfirst(floatread .≈ floatoptvalues)
                qt.showval = string(qt.optkeys[qt.optedidx], " => ", qt.showval)
            end
        end
    end
end

function updatefront!(qt::SetQuantity)
    getvalU!(qt)
    updateoptvalue!(qt)
    content = string("\n", qt.alias, "\n \n", qt.showval, " ", qt.showU, "\n ") |> centermultiline
    qt.show_edit = string(content, "###for refresh")
end

function updatefront!(qt::ReadQuantity)
    getvalU!(qt)
    content = string("\n", qt.alias, "\n \n", qt.showval, " ", qt.showU, "\n ") |> centermultiline
    qt.show_edit = string(content, "###for refresh")
end

function updatefront!(qt::AbstractQuantity; show_edit=true)
    if show_edit
        updatefront!(qt)
    else
        getvalU!(qt)
        qt isa SetQuantity && updateoptvalue!(qt)
        qt.show_view = string(qt.alias, "\n", qt.showval, " ", qt.showU) |> centermultiline
    end
end

@kwdef mutable struct InstrBuffer
    instrnm::String = ""
    quantities::OrderedDict{String,AbstractQuantity} = OrderedDict()
    isautorefresh::Bool = true
    filter::String = ""
    filtervarname::Bool = false
    showdisable::Bool = false
end

function InstrBuffer(instrnm)
    haskey(INSCONF, instrnm) || @error "[$(now())]\n$(mlstr("unsupported instrument!!!"))" instrument = instrnm
    sweepqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "sweep"]
    setqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "set"]
    readqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "read"]
    quantities = [readqts; sweepqts; setqts]
    instrqts = OrderedDict()
    for qt in quantities
        alias = INSCONF[instrnm].quantities[qt].alias
        optkeys = INSCONF[instrnm].quantities[qt].optkeys
        optvalues = INSCONF[instrnm].quantities[qt].optvalues
        utype = INSCONF[instrnm].quantities[qt].U
        type = INSCONF[instrnm].quantities[qt].type
        help = replace(INSCONF[instrnm].quantities[qt].help, "\\\n" => "")
        newqt = quantity(qt, QuantityConf(alias, utype, "", optkeys, optvalues, type, help))
        push!(instrqts, qt => newqt)
    end
    InstrBuffer(instrnm=instrnm, quantities=instrqts)
end

function update_passfilter!(insbuf::InstrBuffer)
    for (qtnm, qt) in insbuf.quantities
        if insbuf.filter != "" && isvalid(insbuf.filter)
            qt.passfilter = if insbuf.filtervarname
                occursin(lowercase(insbuf.filter), lowercase(qtnm))
            else
                occursin(lowercase(insbuf.filter), lowercase(qt.alias))
            end
        else
            qt.passfilter = true
        end
    end
end

@kwdef mutable struct InstrBufferViewer
    instrnm::String = ""
    addr::String = ""
    inputcmd::String = "*IDN?"
    readstr::String = ""
    p_open::Bool = false
    insbuf::InstrBuffer = InstrBuffer()
end
function InstrBufferViewer(instrnm, addr)
    insbuf = InstrBuffer(instrnm)
    for (qtnm, qt) in insbuf.quantities
        if haskey(CONF.InsBuf.disablelist, instrnm) && haskey(CONF.InsBuf.disablelist[instrnm], addr)
            qt.enable = qtnm ∉ CONF.InsBuf.disablelist[instrnm][addr]
        end
        if haskey(CONF.InsBuf.unitlist, instrnm) && haskey(CONF.InsBuf.unitlist[instrnm], addr) &&
           haskey(CONF.InsBuf.unitlist[instrnm][addr], qtnm)
            qt.uindex = CONF.InsBuf.unitlist[instrnm][addr][qtnm]
        end
    end
    InstrBufferViewer(instrnm, addr, "*IDN?", "", false, insbuf)
end

const INSTRBUFFERVIEWERS::Dict{String,Dict{String,InstrBufferViewer}} = Dict()

function updatefrontall!()
    for (ins, inses) in filter(x -> !isempty(x.second), INSTRBUFFERVIEWERS)
        for (_, ibv) in inses
            for (_, qt) in ibv.insbuf.quantities
                updatefront!(qt)
            end
        end
    end
end

function edit(ibv::InstrBufferViewer)
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
    ins, addr = ibv.instrnm, ibv.addr
    if @c CImGui.Begin(stcstr(INSCONF[ins].conf.icon, "  ", ins, "  ", addr), &ibv.p_open)
        SetWindowBgImage()
        @c testcmd(ins, addr, &ibv.inputcmd, &ibv.readstr)
        edit(ibv.insbuf, addr)
        CImGui.IsKeyPressed(ImGuiKey_F5, false) && (refresh1(true); updatefrontall!())
    end
    CImGui.End()
end

let
    firsttime::Bool = true
    selectedins::String = ""
    selectedaddr::String = ""
    inputcmd::String = "*IDN?"
    readstr::String = ""
    default_insbufs = Dict{String,InstrBuffer}()
    global function ShowInstrBuffer(p_open::Ref)
        CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin(
            stcstr(MORESTYLE.Icons.InstrumentsOverview, "  ", mlstr("Instrument Settings and Status"), "###insbuf"),
            p_open
        )
            SetWindowBgImage()
            CImGui.Columns(2)
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            CImGui.BeginChild("instrument list")
            CImGui.Selectable(
                stcstr(MORESTYLE.Icons.InstrumentsOverview, " ", mlstr("Overview")),
                selectedins == "", 0, (Cfloat(0), 2CImGui.GetFrameHeight())
            ) && (selectedins = "")
            for (ins, inses) in INSTRBUFFERVIEWERS
                CImGui.Selectable(
                    stcstr(INSCONF[ins].conf.icon, " ", ins), selectedins == ins,
                    0, (Cfloat(0), 3CImGui.GetFrameHeight() / 2)
                ) && (selectedins = ins)
                CImGui.SameLine()
                # CImGui.TextDisabled(stcstr("(", length(inses), ")"))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled))
                CImGui.Selectable(
                    stcstr("(", length(inses), ")"), false, 0, (Cfloat(0), 3CImGui.GetFrameHeight() / 2)
                )
                CImGui.PopStyleColor()
            end
            CImGui.EndChild()
            CImGui.NextColumn()
            CImGui.BeginChild("setings")
            haskey(INSTRBUFFERVIEWERS, selectedins) || (selectedins = "")
            if selectedins == ""
                for (ins, inses) in filter(x -> !isempty(x.second), INSTRBUFFERVIEWERS)
                    CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(ins, ": "))
                    for (addr, ibv) in inses
                        CImGui.Text(stcstr("\t\t", addr, "\t\t"))
                        CImGui.SameLine()
                        @c CImGui.Checkbox(stcstr("##if auto refresh", addr), &ibv.insbuf.isautorefresh)
                        if ins != "VirtualInstr"
                            CImGui.SameLine()
                            CImGui.Button(
                                stcstr(MORESTYLE.Icons.CloseFile, "##delete ", addr)
                            ) && delete!(inses, addr)
                        end
                    end
                    CImGui.Separator()
                end
            else
                showinslist::Set = @trypass keys(INSTRBUFFERVIEWERS[selectedins]) Set{String}()
                CImGui.PushItemWidth(-CImGui.GetFontSize() * 2.5)
                @c ComBoS(mlstr("address"), &selectedaddr, showinslist)
                CImGui.PopItemWidth()
                CImGui.Separator()
                @c testcmd(selectedins, selectedaddr, &inputcmd, &readstr)

                selectedaddr = haskey(INSTRBUFFERVIEWERS[selectedins], selectedaddr) ? selectedaddr : ""
                haskey(default_insbufs, selectedins) || push!(default_insbufs, selectedins => InstrBuffer(selectedins))
                insbuf = selectedaddr == "" ? default_insbufs[selectedins] : INSTRBUFFERVIEWERS[selectedins][selectedaddr].insbuf
                edit(insbuf, selectedaddr)
            end
            CImGui.EndChild()
        end
        CImGui.End()
    end
end #let    

function testcmd(ins, addr, inputcmd::Ref{String}, readstr::Ref{String})
    if CImGui.CollapsingHeader(stcstr("\t", mlstr("Command Test")))
        y = (1 + length(findall("\n", inputcmd[]))) * CImGui.GetTextLineHeight() +
            2unsafe_load(IMGUISTYLE.FramePadding.y)
        InputTextMultilineRSZ("##input cmd", inputcmd, (Float32(-1), y))
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(mlstr("clear")) && (inputcmd[] = "")
            CImGui.EndPopup()
        end
        TextRect(stcstr(readstr[], "\n "); size=(Cfloat(0), 4CImGui.GetFontSize()))
        CImGui.BeginChild("align buttons", (Float32(0), CImGui.GetFrameHeightWithSpacing()))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, 12)
        CImGui.Columns(3, C_NULL, false)
        if CImGui.Button(stcstr(MORESTYLE.Icons.WriteBlock, "  ", mlstr("Write")), (-1, 0))
            if addr != ""
                remote_do(workers()[1], ins, addr, inputcmd[]) do ins, addr, inputcmd
                    ct = Controller(ins, addr)
                    try
                        login!(CPU, ct)
                        ct(write, CPU, inputcmd, Val(:write))
                        logout!(CPU, ct)
                    catch e
                        @error(
                            "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                            instrument = string(ins, ": ", addr),
                            exception = e
                        )
                        logout!(CPU, ct)
                    end
                end
            end
        end
        CImGui.NextColumn()
        if CImGui.Button(stcstr(MORESTYLE.Icons.QueryBlock, "  ", mlstr("Query")), (-1, 0))
            if addr != ""
                fetchdata = wait_remotecall_fetch(workers()[1], ins, addr, inputcmd[]) do ins, addr, inputcmd
                    ct = Controller(ins, addr)
                    try
                        login!(CPU, ct)
                        readstr = ct(query, CPU, inputcmd, Val(:query))
                        logout!(CPU, ct)
                        return readstr
                    catch e
                        @error(
                            "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                            instrument = string(ins, ": ", addr),
                            exception = e
                        )
                        logout!(CPU, ct)
                    end
                end
                isnothing(fetchdata) || (readstr[] = fetchdata)
            end
        end
        CImGui.NextColumn()
        if CImGui.Button(stcstr(MORESTYLE.Icons.ReadBlock, "  ", mlstr("Read")), (-1, 0))
            if addr != ""
                fetchdata = wait_remotecall_fetch(workers()[1], ins, addr) do ins, addr
                    ct = Controller(ins, addr)
                    try
                        login!(CPU, ct)
                        readstr = ct(read, CPU, Val(:read))
                        logout!(CPU, ct)
                        return readstr
                    catch e
                        @error(
                            "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                            instrument = string(ins, ": ", addr),
                            exception = e
                        )
                        logout!(CPU, ct)
                    end
                end
                isnothing(fetchdata) || (readstr[] = fetchdata)
            end
        end
        CImGui.NextColumn()
        CImGui.PopStyleVar()
        CImGui.EndChild()
        CImGui.Separator()
    end
end


function edit(insbuf::InstrBuffer, addr)
    CImGui.PushID(insbuf.instrnm)
    CImGui.PushID(addr)
    @c(InputTextRSZ("##filterqt", &insbuf.filter)) && update_passfilter!(insbuf)
    CImGui.SameLine()
    @c(CImGui.Checkbox(
        insbuf.filtervarname ? mlstr("Filter variables") : mlstr("Filter aliases"),
        &insbuf.filtervarname
    )) && update_passfilter!(insbuf)
    CImGui.BeginChild("InstrBuffer")
    # CImGui.Columns(CONF.InsBuf.showcol, C_NULL, false)
    btsize = (CImGui.GetContentRegionAvailWidth() - unsafe_load(IMGUISTYLE.ItemSpacing.x) * (CONF.InsBuf.showcol - 1)) / CONF.InsBuf.showcol
    for (i, qt) in enumerate(values(insbuf.quantities))
        qt.enable || insbuf.showdisable || continue
        qt.passfilter || continue
        CImGui.PushID(qt.name)
        i % CONF.InsBuf.showcol == 1 || i == 1 || CImGui.SameLine()
        edit(qt, insbuf.instrnm, addr; btsize=(btsize, Cfloat(0)))
        # i % CONF.InsBuf.showcol == 0 && i != 1 && CImGui.SameLine()
        CImGui.PopID()
        # CImGui.NextColumn()
        CImGui.Indent()
        if CImGui.BeginDragDropSource(0)
            @c CImGui.SetDragDropPayload("Swap DAQTask", &i, sizeof(Cint))
            CImGui.Text(qt.alias)
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Swap DAQTask")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                if i != payload_i
                    key_i = idxkey(insbuf.quantities, i)
                    key_payload_i = idxkey(insbuf.quantities, payload_i)
                    swapvalue!(insbuf.quantities, key_i, key_payload_i)
                end
            end
            CImGui.EndDragDropTarget()
        end
        CImGui.Unindent()
    end
    CImGui.EndChild()
    CImGui.PopID()
    CImGui.PopID()
    if !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows)
        CImGui.OpenPopupOnItemClick(stcstr("rightclick", insbuf.instrnm, addr))
    end
    if CImGui.BeginPopup(stcstr("rightclick", insbuf.instrnm, addr))
        if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InstrumentsManualRef, " ", mlstr("Manual Refresh")), "F5")
            insbuf.isautorefresh = true
            refresh1(true)
            updatefrontall!()
        end
        CImGui.Text(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Auto Refresh")))
        CImGui.SameLine()
        isautoref = SYNCSTATES[Int(IsAutoRefreshing)]
        @c CImGui.Checkbox("##auto refresh", &isautoref)
        SYNCSTATES[Int(IsAutoRefreshing)] = isautoref
        insbuf.isautorefresh = SYNCSTATES[Int(IsAutoRefreshing)]
        if isautoref
            CImGui.SameLine()
            CImGui.Text(" ")
            CImGui.SameLine()
            CImGui.PushItemWidth(CImGui.GetFontSize() * 2)
            @c CImGui.DragFloat(
                "##auto refresh",
                &CONF.InsBuf.refreshrate,
                0.1, 0.1, 60, "%.1f",
                CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            CImGui.PopItemWidth()
        end
        CImGui.Text(stcstr(MORESTYLE.Icons.ShowCol, " ", mlstr("display columns")))
        CImGui.SameLine()
        CImGui.PushItemWidth(3CImGui.GetFontSize() / 2)
        @c CImGui.DragInt(
            "##display columns",
            &CONF.InsBuf.showcol, 1, 1, 12, "%d",
            CImGui.ImGuiSliderFlags_AlwaysClamp
        )
        CImGui.PopItemWidth()
        CImGui.Text(stcstr(MORESTYLE.Icons.ShowDisable, " ", mlstr("Show Disabled")))
        CImGui.SameLine()
        @c CImGui.Checkbox("##show disabled", &insbuf.showdisable)
        CImGui.EndPopup()
    end
    CImGui.IsKeyPressed(ImGuiKey_F5, false) && (refresh1(true); updatefrontall!())
end

let
    stbtsz::Float32 = 0
    closepopup::Bool = false
    global function edit(qt::SweepQuantity, instrnm, addr; btsize=(-1, 0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.SweepQuantityTxt)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            if qt.isautorefresh || qt.issweeping
                MORESTYLE.Colors.DAQTaskRunning
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
            end
        )
        qt.show_edit == "" && updatefront!(qt)
        # CImGui.PushFont(PLOTFONT)
        if ColoredButton(
            qt.show_edit;
            size=btsize,
            colbt=if qt.enable
                if qt.isautorefresh || qt.issweeping
                    MORESTYLE.Colors.DAQTaskRunning
                else
                    MORESTYLE.Colors.SweepQuantityBt
                end
            else
                MORESTYLE.Colors.LogError
            end
        )
            if qt.enable && addr != ""
                fetchdata = refresh_qt(instrnm, addr, qt.name)
                isnothing(fetchdata) || (qt.read = fetchdata)
                updatefront!(qt)
            end
        end
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        if CImGui.BeginPopupContextItem()
            if qt.enable
                @c InputTextWithHintRSZ("##step", mlstr("step"), &qt.step)
                @c InputTextWithHintRSZ("##stop", mlstr("stop"), &qt.stop)
                @c CImGui.DragFloat("##delay", &qt.delay, 1.0, 0.01, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                if qt.issweeping
                    if CImGui.Button(
                        mlstr(" Stop "), (-0.1, 0.0)
                    ) || CImGui.IsKeyPressed(ImGuiKey_Enter, false)
                        qt.issweeping = false
                    end
                else
                    if CImGui.Button(
                        mlstr(" Start "), (-0.1, 0.0)
                    ) || CImGui.IsKeyPressed(ImGuiKey_Enter, false)
                        apply!(qt, instrnm, addr)
                        closepopup = true
                    end
                end
                if closepopup && !CImGui.IsKeyDown(ImGuiKey_Enter)
                    CImGui.CloseCurrentPopup()
                    closepopup = false
                end
            end
            CImGui.Text(stcstr(mlstr("unit"), " "))
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
            CImGui.PopItemWidth()
            CImGui.SameLine()
            @c CImGui.Checkbox(mlstr("refresh"), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
        end
    end
end #let

let
    triggerset::Bool = false
    popup_before_list::Dict{String,Dict{String,Dict{String,Bool}}} = Dict()
    popup_now::Bool = false
    closepopup::Bool = false
    global function edit(qt::SetQuantity, instrnm, addr; btsize=(-1, 0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.SetQuantityTxt)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
        )
        qt.show_edit == "" && updatefront!(qt)
        # CImGui.PushFont(PLOTFONT)
        if ColoredButton(
            qt.show_edit;
            size=btsize,
            colbt=if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.SetQuantityBt
            else
                MORESTYLE.Colors.LogError
            end
        )
            if qt.enable && addr != ""
                fetchdata = refresh_qt(instrnm, addr, qt.name)
                isnothing(fetchdata) || (qt.read = fetchdata)
                updatefront!(qt)
            end
        end
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        haskey(popup_before_list, instrnm) || push!(popup_before_list, instrnm => Dict())
        haskey(popup_before_list[instrnm], addr) || push!(popup_before_list[instrnm], addr => Dict())
        haskey(popup_before_list[instrnm][addr], qt.name) || push!(popup_before_list[instrnm][addr], qt.name => false)
        popup_now = CImGui.BeginPopupContextItem()
        popup_before = popup_before_list[instrnm][addr][qt.name]
        !popup_now && popup_before && (popup_before_list[instrnm][addr][qt.name] = false)
        if popup_now
            if qt.enable
                @c InputTextWithHintRSZ("##set", mlstr("set value"), &qt.set)
                if CImGui.Button(
                       mlstr(" Confirm "),
                       (-Cfloat(0.1), Cfloat(0))
                   ) || triggerset || CImGui.IsKeyPressed(ImGuiKey_Enter, false)
                    triggerset && (qt.set = qt.optvalues[qt.optedidx])
                    apply!(qt, instrnm, addr, triggerset)
                    triggerset = false
                    closepopup = true
                end
                if closepopup && !CImGui.IsKeyDown(ImGuiKey_Enter)
                    CImGui.CloseCurrentPopup()
                    closepopup = false
                end
                if !isempty(qt.optkeys) && !popup_before && addr != ""
                    fetchdata = refresh_qt(instrnm, addr, qt.name)
                    if !isnothing(fetchdata)
                        fetchdata in qt.optvalues && (qt.optedidx = findfirst(==(fetchdata), qt.optvalues))
                    end
                end
                CImGui.BeginGroup()
                for (i, optv) in enumerate(qt.optvalues)
                    (iseven(i) || optv == "") && continue
                    @c(CImGui.RadioButton(qt.optkeys[i], &qt.optedidx, i)) && (triggerset = true)
                end
                CImGui.EndGroup()
                CImGui.SameLine(0, 2CImGui.GetFontSize())
                CImGui.BeginGroup()
                for (i, optv) in enumerate(qt.optvalues)
                    (isodd(i) || optv == "") && continue
                    @c(CImGui.RadioButton(qt.optkeys[i], &qt.optedidx, i)) && (triggerset = true)
                end
                CImGui.EndGroup()
            end
            CImGui.Text(stcstr(mlstr("unit"), " "))
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
            CImGui.PopItemWidth()
            CImGui.SameLine()
            @c CImGui.Checkbox(mlstr("refresh"), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
            popup_before_list[instrnm][addr][qt.name] = true
        end
    end
end

let
    refbtsz::Float32 = 0
    global function edit(qt::ReadQuantity, instrnm, addr; btsize=(-1, 0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.ReadQuantityTxt)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
        )
        qt.show_edit == "" && updatefront!(qt)
        # CImGui.PushFont(PLOTFONT)
        if ColoredButton(
            qt.show_edit;
            size=btsize,
            colbt=if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.ReadQuantityBt
            else
                MORESTYLE.Colors.LogError
            end
        )
            if qt.enable && addr != ""
                fetchdata = refresh_qt(instrnm, addr, qt.name)
                isnothing(fetchdata) || (qt.read = fetchdata)
                updatefront!(qt)
            end
        end
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        if CImGui.BeginPopupContextItem()
            CImGui.Text(stcstr(mlstr("unit"), " "))
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
            CImGui.PopItemWidth()
            CImGui.SameLine()
            @c CImGui.Checkbox(mlstr("refresh"), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
        end
    end
end

function view(instrbufferviewers_local)
    for (ins, inses) in filter(x -> !isempty(x.second), instrbufferviewers_local)
        ins == "Others" && continue
        for (addr, ibv) in inses
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(ins, "：", addr))
            CImGui.PushID(addr)
            view(ibv.insbuf)
            CImGui.PopID()
        end
    end
end

function view(insbuf::InstrBuffer)
    y = ceil(Int, length(insbuf.quantities) / CONF.InsBuf.showcol) * 2CImGui.GetFrameHeight()
    CImGui.BeginChild("view insbuf", (Float32(0), y))
    CImGui.Columns(CONF.InsBuf.showcol, C_NULL, false)
    CImGui.PushID(insbuf.instrnm)
    for (name, qt) in insbuf.quantities
        CImGui.PushID(name)
        view(qt)
        CImGui.NextColumn()
        CImGui.PopID()
    end
    CImGui.PopID()
    CImGui.EndChild()
end

function view(qt::AbstractQuantity)
    qt.show_view == "" && updatefront!(qt; show_edit=false)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Button,
        qt.enable ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button) : MORESTYLE.Colors.LogError
    )
    CImGui.Button(qt.show_view, (-1, 0)) && (qt.uindex += 1; updatefront!(qt; show_edit=false))
    CImGui.PopStyleColor()
end

function apply!(qt::SweepQuantity, instrnm, addr)
    addr == "" && return nothing
    U, Us = @c getU(qt.utype, &qt.uindex)
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    start = wait_remotecall_fetch(workers()[1], instrnm, addr) do instrnm, addr
        ct = Controller(instrnm, addr)
        try
            getfunc = Symbol(instrnm, :_, qt.name, :_get) |> eval
            login!(CPU, ct)
            readstr = ct(getfunc, CPU, Val(:read))
            logout!(CPU, ct)
            return parse(Float64, readstr)
        catch e
            @error(
                "[$(now())]\n$(mlstr("error getting start value!!!"))",
                instrument = string(instrnm, "-", addr),
                exception = e
            )
            logout!(CPU, ct)
        end
    end
    step = @trypasse eval(Meta.parse(qt.step)) * Uchange begin
        @error "[$(now())]\n$(mlstr("error parsing step value!!!"))" step = qt.step
    end
    stop = @trypasse eval(Meta.parse(qt.stop)) * Uchange begin
        @error "[$(now())]\n$(mlstr("error parsing stop value!!!"))" stop = qt.stop
    end
    if !(isnothing(start) | isnothing(step) | isnothing(stop))
        sweeplist = gensweeplist(start, step, stop)
        errormonitor(
            Threads.@spawn begin
                qt.issweeping = true
                ct = Controller(instrnm, addr)
                sweep_c = Channel{Vector{String}}(CONF.DAQ.channel_size)
                sweep_rc = RemoteChannel(() -> sweep_c)
                sweepcalltask = @async remotecall_wait(
                    workers()[1], ct, sweeplist, sweep_rc, qt.name, qt.delay
                ) do ct, sweeplist, sweep_rc, qtnm, delay
                    push!(SWEEPCTS, ct.id => (Ref(true), ct))
                    sweep_lc = Channel{String}(CONF.DAQ.channel_size)
                    login!(CPU, ct)
                    try
                        setfunc = Symbol(ct.instrnm, :_, qtnm, :_set) |> eval
                        getfunc = Symbol(ct.instrnm, :_, qtnm, :_get) |> eval
                        @sync begin
                            sweeptask = errormonitor(
                                @async begin
                                    for sv in sweeplist
                                        SWEEPCTS[ct.id][1][] || break
                                        sleep(delay)
                                        SWEEPCTS[ct.id][2](setfunc, CPU, string(sv), Val(:write))
                                        put!(sweep_lc, SWEEPCTS[ct.id][2](getfunc, CPU, Val(:read)))
                                    end
                                end
                            )
                            errormonitor(
                                @async while !istaskdone(sweeptask) || isready(sweep_lc)
                                    isready(sweep_lc) && put!(sweep_rc, packtake!(sweep_lc, CONF.DAQ.packsize))
                                    sleep(delay / 10)
                                    yield()
                                end
                            )
                        end
                    catch e
                        @error(
                            "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                            instrument = string(ct.instrnm, ": ", ct.addr),
                            quantity = qtnm,
                            exception = e
                        )
                    finally
                        logout!(CPU, SWEEPCTS[ct.id][2])
                        SWEEPCTS[ct.id][1][] = false
                    end
                end
                while !istaskdone(sweepcalltask) || isready(sweep_rc)
                    qt.issweeping || remotecall_wait(ctid -> SWEEPCTS[ctid][1][] = false, workers()[1], ct.id)
                    isready(sweep_rc) && for val in take!(sweep_rc)
                        qt.read = val
                        updatefront!(qt)
                    end
                    sleep(qt.delay / 10)
                    yield()
                end
                qt.issweeping = false
                remotecall_wait(ctid -> delete!(SWEEPCTS, ctid), workers()[1], ct.id)
            end
        )
    else
        qt.issweeping = false
    end
    return nothing
end

function apply!(qt::SetQuantity, instrnm, addr, byoptvalues=false)
    addr == "" && return nothing
    U, Us = @c getU(qt.utype, &qt.uindex)
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    sv = (U == "" || byoptvalues) ? qt.set : @trypasse string(float(eval(Meta.parse(qt.set)) * Uchange)) qt.set
    sv = string(lstrip(rstrip(sv)))
    if (U == "" && sv != "") || !isnothing(tryparse(Float64, sv))
        fetchdata = wait_remotecall_fetch(workers()[1], instrnm, addr, sv) do instrnm, addr, sv
            ct = Controller(instrnm, addr)
            try
                setfunc = Symbol(instrnm, :_, qt.name, :_set) |> eval
                getfunc = Symbol(instrnm, :_, qt.name, :_get) |> eval
                login!(CPU, ct)
                ct(setfunc, CPU, sv, Val(:write))
                readstr = ct(getfunc, CPU, Val(:read))
                logout!(CPU, ct)
                return readstr
            catch e
                @error(
                    "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                    instrument = string(instrnm, ": ", addr),
                    quantity = qt.name,
                    exception = e
                )
                logout!(CPU, ct)
            end
        end
        isnothing(fetchdata) || (qt.read = fetchdata; updatefront!(qt))
    else
        @warn "[$(now())]\n$(mlstr("invalid input!"))"
    end
    return nothing
end

function resolvedisablelist(qt::AbstractQuantity, instrnm, addr)
    haskey(CONF.InsBuf.disablelist, instrnm) || push!(CONF.InsBuf.disablelist, instrnm => Dict())
    haskey(CONF.InsBuf.disablelist[instrnm], addr) || push!(CONF.InsBuf.disablelist[instrnm], addr => [])
    disablelist = CONF.InsBuf.disablelist[instrnm][addr]
    if qt.enable
        qt.name in disablelist && deleteat!(disablelist, findfirst(==(qt.name), disablelist))
    else
        qt.name in disablelist || push!(disablelist, qt.name)
    end
    svconf = deepcopy(CONF)
    svconf.U = Dict(up.first => string.(up.second) for up in CONF.U)
    to_toml(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"), svconf)
end

function resolveunitlist(qt::AbstractQuantity, instrnm, addr)
    haskey(CONF.InsBuf.unitlist, instrnm) || push!(CONF.InsBuf.unitlist, instrnm => Dict())
    haskey(CONF.InsBuf.unitlist[instrnm], addr) || push!(CONF.InsBuf.unitlist[instrnm], addr => Dict())
    unitlist = CONF.InsBuf.unitlist[instrnm][addr]
    haskey(unitlist, qt.name) || push!(unitlist, qt.name => qt.uindex)
    if unitlist[qt.name] != qt.uindex
        push!(unitlist, qt.name => qt.uindex)
        svconf = deepcopy(CONF)
        svconf.U = Dict(up.first => string.(up.second) for up in CONF.U)
        to_toml(joinpath(ENV["QInsControlAssets"], "Necessity/conf.toml"), svconf)
    end
end

function refresh_qt(instrnm, addr, qtnm)
    wait_remotecall_fetch(workers()[1], instrnm, addr) do instrnm, addr
        ct = Controller(instrnm, addr)
        try
            getfunc = Symbol(instrnm, :_, qtnm, :_get) |> eval
            login!(CPU, ct)
            readstr = ct(getfunc, CPU, Val(:read))
            logout!(CPU, ct)
            return readstr
        catch e
            @error(
                "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                instrument = string(instrnm, ": ", addr),
                quantity = qtnm,
                exception = e
            )
            logout!(CPU, ct)
        end
    end
end

function log_instrbufferviewers()
    refresh1(true)
    push!(CFGBUF, "instrbufferviewers/[$(now())]" => deepcopy(INSTRBUFFERVIEWERS))
end

function refresh1(log=false; instrlist=keys(INSTRBUFFERVIEWERS))
    fetchibvs = wait_remotecall_fetch(workers()[1], INSTRBUFFERVIEWERS; timeout=120) do ibvs
        empty!(INSTRBUFFERVIEWERS)
        merge!(INSTRBUFFERVIEWERS, ibvs)
        @sync for (ins, inses) in filter(x -> x.first in instrlist && !isempty(x.second), INSTRBUFFERVIEWERS)
            ins == "Others" && continue
            haskey(REFRESHCTS, ins) || push!(REFRESHCTS, ins => Dict())
            for (addr, ibv) in inses
                @async if ibv.insbuf.isautorefresh || log
                    haskey(REFRESHCTS[ins], addr) || push!(REFRESHCTS[ins], addr => Controller(ins, addr))
                    ct = REFRESHCTS[ins][addr]
                    try
                        login!(CPU, ct)
                        for (qtnm, qt) in ibv.insbuf.quantities
                            if (qt.isautorefresh && qt.enable) || (log && (CONF.DAQ.logall || qt.enable))
                                getfunc = Symbol(ins, :_, qtnm, :_get) |> eval
                                qt.read = ct(getfunc, CPU, Val(:read))
                            elseif !qt.enable
                                qt.read = ""
                            end
                        end
                    catch e
                        @error(
                            "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                            instrument = string(ins, ": ", addr),
                            exception = e
                        )
                    finally
                        logout!(CPU, ct)
                    end
                end
            end
        end
        return INSTRBUFFERVIEWERS
    end
    Threads.@spawn if !isnothing(fetchibvs)
        for (ins, inses) in filter(x -> !isempty(x.second), INSTRBUFFERVIEWERS)
            for (addr, ibv) in filter(x -> x.second.insbuf.isautorefresh || log, inses)
                for (qtnm, qt) in filter(x -> x.second.isautorefresh || log, ibv.insbuf.quantities)
                    qt.read = fetchibvs[ins][addr].insbuf.quantities[qtnm].read
                    updatefront!(qt)
                end
            end
        end
    end
end

function autorefresh()
    errormonitor(
        Threads.@spawn while true
            t1 = time()
            timedwait(() -> time() - t1 > CONF.InsBuf.refreshrate, 60; pollint=0.05)
            SYNCSTATES[Int(IsAutoRefreshing)] && refresh1()
            yield()
        end
    )
end