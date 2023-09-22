abstract type AbstractQuantity end
mutable struct SweepQuantity <: AbstractQuantity
    # back end
    enable::Bool
    name::String
    alias::String
    step::String
    stop::String
    delay::Cfloat
    read::String
    utype::String
    uindex::Int
    help::String
    isautorefresh::Bool
    issweeping::Bool
    # front end
    show_edit::String
    show_view::String
    passfilter::Bool
end
SweepQuantity() = SweepQuantity(
    true, "", "", "", "", Cfloat(0.1), "", "", 1, "", false, false,
    "", "", true
)

mutable struct SetQuantity <: AbstractQuantity
    # back end
    enable::Bool
    name::String
    alias::String
    set::String
    optkeys::Vector{String}
    optvalues::Vector{String}
    optedidx::Cint
    read::String
    utype::String
    uindex::Int
    help::String
    isautorefresh::Bool
    # front end
    show_edit::String
    show_view::String
    passfilter::Bool
end
SetQuantity() = SetQuantity(
    true, "", "", "", [], [], 1, "", "", 1, "", false,
    "", "", true
)
mutable struct ReadQuantity <: AbstractQuantity
    # back end
    enable::Bool
    name::String
    alias::String
    read::String
    utype::String
    uindex::Int
    help::String
    isautorefresh::Bool
    # front end
    show_edit::String
    show_view::String
    passfilter::Bool
end
ReadQuantity() = ReadQuantity(
    true, "", "", "", "", 1, "", false,
    "", "", true
)

function quantity(name, qtcf::QuantityConf)
    return if qtcf.type == "sweep"
        SweepQuantity(
            true, name, qtcf.alias,
            "", "", Cfloat(0.1),
            "",
            qtcf.U, 1,
            qtcf.help,
            false,
            false,
            "", "", true
        )
    elseif qtcf.type == "set"
        SetQuantity(
            true, name, qtcf.alias,
            "", qtcf.optkeys, qtcf.optvalues, 1,
            "",
            qtcf.U, 1,
            qtcf.help,
            false,
            "", "", true
        )
    elseif qtcf.type == "read"
        ReadQuantity(
            true, name, qtcf.alias,
            "",
            qtcf.U, 1,
            qtcf.help,
            false,
            "", "", true
        )
    end
end

function getvalU(qt::AbstractQuantity)
    Us = CONF.U[qt.utype]
    U = isempty(Us) ? "" : Us[qt.uindex]
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    val = U == "" ? qt.read : @trypass string(parse(Float64, qt.read) / Uchange) qt.read
    return val, U
end

function updatefront!(qt::SweepQuantity)
    val, U = getvalU(qt)
    content = string(
        qt.alias,
        "\n", mlstr("step"), ": ", qt.step, " ", U,
        "\n", mlstr("stop"), ": ", qt.stop, " ", U,
        "\n", mlstr("delay"), ": ", qt.delay, " s\n",
        val, " ", U
    ) |> centermultiline
    qt.show_edit = string(content, "###for refresh")
end

function updatefront!(qt::SetQuantity)
    val, U = getvalU(qt)
    if val in qt.optvalues
        validx = findfirst(==(val), qt.optvalues)
        val = string(qt.optkeys[validx], " => ", qt.optvalues[validx])
    end
    content = string(
        qt.alias,
        "\n \n",
        mlstr("set value"), ": ", qt.set, " ", U,
        "\n \n",
        val, " ", U
    ) |> centermultiline
    qt.show_edit = string(content, "###for refresh")
end

function updatefront!(qt::ReadQuantity)
    val, U = getvalU(qt)
    content = string(qt.alias, "\n \n \n", val, " ", U, "\n ") |> centermultiline
    qt.show_edit = string(content, "###for refresh")
end

function updatefront!(qt::AbstractQuantity; show_edit=true)
    if show_edit
        updatefront!(qt)
    else
        val, U = getvalU(qt)
        if qt isa SetQuantity && val in qt.optvalues
            validx = findfirst(==(val), qt.optvalues)
            val = string(qt.optkeys[validx], " => ", qt.optvalues[validx])
        end
        qt.show_view = string(qt.alias, "\n", val, " ", U) |> centermultiline
    end
end

mutable struct InstrBuffer
    instrnm::String
    quantities::OrderedDict{String,AbstractQuantity}
    isautorefresh::Bool
    filter::String
    filtervarname::Bool
    showdisable::Bool
end
InstrBuffer() = InstrBuffer("", OrderedDict(), false, "", false, false)

function InstrBuffer(instrnm)
    haskey(INSCONF, instrnm) || @error "[$(now())]\n$(mlstr("unsupported instrument!!!"))" instrument = instrnm
    sweepqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "sweep"]
    setqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "set"]
    readqts = [qt for qt in keys(INSCONF[instrnm].quantities) if INSCONF[instrnm].quantities[qt].type == "read"]
    quantities = [sweepqts; setqts; readqts]
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
    InstrBuffer(instrnm, instrqts, false, "", false, false)
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

mutable struct InstrBufferViewer
    instrnm::String
    addr::String
    inputcmd::String
    readstr::String
    p_open::Bool
    insbuf::InstrBuffer
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
InstrBufferViewer() = InstrBufferViewer("", "", "*IDN?", "", false, InstrBuffer())

const INSTRBUFFERVIEWERS::Dict{String,Dict{String,InstrBufferViewer}} = Dict()

function updatefrontall!()
    for ins in keys(INSTRBUFFERVIEWERS)
        for (_, ibv) in INSTRBUFFERVIEWERS[ins]
            for (_, qt) in ibv.insbuf.quantities
                updatefront!(qt)
            end
        end
    end
end

function edit(ibv::InstrBufferViewer)
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
    ins, addr = ibv.instrnm, ibv.addr
    if @c CImGui.Begin(stcstr(INSCONF[ins].conf.icon, "  ", ins, " --- ", addr), &ibv.p_open)
        @c testcmd(ins, addr, &ibv.inputcmd, &ibv.readstr)
        edit(ibv.insbuf, addr)
        CImGui.IsKeyPressed(294, false) && (manualrefresh(); updatefrontall!())
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
            CImGui.Columns(2)
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            CImGui.BeginChild("instrument list")
            CImGui.Selectable(
                stcstr(MORESTYLE.Icons.InstrumentsOverview, " ", mlstr("Overview")),
                selectedins == ""
            ) && (selectedins = "")
            for ins in keys(INSTRBUFFERVIEWERS)
                CImGui.Selectable(stcstr(INSCONF[ins].conf.icon, " ", ins), selectedins == ins) && (selectedins = ins)
                CImGui.SameLine()
                CImGui.TextDisabled(stcstr("(", length(INSTRBUFFERVIEWERS[ins]), ")"))
            end
            CImGui.EndChild()
            CImGui.NextColumn()
            CImGui.BeginChild("setings")
            haskey(INSTRBUFFERVIEWERS, selectedins) || (selectedins = "")
            if selectedins == ""
                for ins in keys(INSTRBUFFERVIEWERS)
                    CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(ins, ": "))
                    for (addr, ibv) in INSTRBUFFERVIEWERS[ins]
                        CImGui.Text(stcstr("\t\t", addr, "\t\t"))
                        CImGui.SameLine()
                        @c CImGui.Checkbox(stcstr("##if auto refresh", addr), &ibv.insbuf.isautorefresh)
                        if ins != "VirtualInstr"
                            CImGui.SameLine()
                            CImGui.Button(
                                stcstr(MORESTYLE.Icons.CloseFile, "##delete ", addr)
                            ) && delete!(INSTRBUFFERVIEWERS[ins], addr)
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
        TextRect(stcstr(readstr[], "\n "))
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
                errormonitor(
                    @async begin
                        fetchdata_call = remotecall(workers()[1], ins, addr, inputcmd[]) do ins, addr, inputcmd
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
                        fetchdata = waittofetch(fetchdata_call)
                        isnothing(fetchdata) || (readstr[] = fetchdata)
                    end
                ) |> wait
            end
        end
        CImGui.NextColumn()
        if CImGui.Button(stcstr(MORESTYLE.Icons.ReadBlock, "  ", mlstr("Read")), (-1, 0))
            if addr != ""
                errormonitor(
                    @async begin
                        fetchdata_call = remotecall(workers()[1], ins, addr) do ins, addr
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
                        fetchdata = waittofetch(fetchdata_call)
                        isnothing(fetchdata) || (readstr[] = fetchdata)
                    end
                ) |> wait
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
    CImGui.Columns(CONF.InsBuf.showcol, C_NULL, false)
    for (i, qt) in enumerate(values(insbuf.quantities))
        qt.enable || insbuf.showdisable || continue
        qt.passfilter || continue
        CImGui.PushID(qt.name)
        edit(qt, insbuf.instrnm, addr)
        CImGui.PopID()
        CImGui.NextColumn()
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
            manualrefresh()
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
    CImGui.IsKeyPressed(294, false) && (manualrefresh(); updatefrontall!())
end

let
    stbtsz::Float32 = 0
    closepopup::Bool = false
    global function edit(qt::SweepQuantity, instrnm, addr)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Button,
            if qt.enable
                if qt.isautorefresh || qt.issweeping
                    MORESTYLE.Colors.DAQTaskRunning
                else
                    CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
                end
            else
                MORESTYLE.Colors.LogError
            end
        )
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            if qt.isautorefresh || qt.issweeping
                MORESTYLE.Colors.DAQTaskRunning
            else
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
            end
        )
        qt.show_edit == "" && updatefront!(qt)
        if CImGui.Button(qt.show_edit, (-1, 0))
            if qt.enable && addr != ""
                fetchdata = refresh_qt(instrnm, addr, qt.name)
                isnothing(fetchdata) || (qt.read = fetchdata)
                updatefront!(qt)
            end
        end
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        if CImGui.BeginPopupContextItem()
            if qt.enable
                @c InputTextWithHintRSZ("##step", mlstr("step"), &qt.step)
                @c InputTextWithHintRSZ("##stop", mlstr("stop"), &qt.stop)
                @c CImGui.DragFloat("##delay", &qt.delay, 1.0, 0.05, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                if qt.issweeping
                    if CImGui.Button(
                        mlstr(" Stop "), (-0.1, 0.0)
                    ) || CImGui.IsKeyPressed(igGetKeyIndex(ImGuiKey_Enter), false)
                        qt.issweeping = false
                    end
                else
                    if CImGui.Button(
                        mlstr(" Start "), (-0.1, 0.0)
                    ) || CImGui.IsKeyPressed(igGetKeyIndex(ImGuiKey_Enter), false)
                        apply!(qt, instrnm, addr)
                        closepopup = true
                    end
                end
                if closepopup && !CImGui.IsKeyDown(igGetKeyIndex(ImGuiKey_Enter))
                    CImGui.CloseCurrentPopup()
                    closepopup = false
                end
            end
            CImGui.Text(stcstr(mlstr("unit"), " "))
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && resolveunitlist(qt, instrnm, addr)
            CImGui.PopItemWidth()
            CImGui.SameLine()
            @c CImGui.Checkbox(mlstr("refresh"), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
            updatefront!(qt)
        end
        (qt.issweeping || qt.isautorefresh) && updatefront!(qt)
    end
end #let

let
    triggerset::Bool = false
    popup_before_list::Dict{String,Dict{String,Dict{String,Bool}}} = Dict()
    popup_now_list::Dict{String,Dict{String,Dict{String,Bool}}} = Dict()
    closepopup::Bool = false
    global function edit(qt::SetQuantity, instrnm, addr)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Button,
            if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
            else
                MORESTYLE.Colors.LogError
            end
        )
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
        )
        qt.show_edit == "" && updatefront!(qt)
        if CImGui.Button(qt.show_edit, (-1, 0))
            if qt.enable && addr != ""
                fetchdata = refresh_qt(instrnm, addr, qt.name)
                isnothing(fetchdata) || (qt.read = fetchdata)
                updatefront!(qt)
            end
        end
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        haskey(popup_before_list, instrnm) || push!(popup_before_list, instrnm => Dict())
        haskey(popup_before_list[instrnm], addr) || push!(popup_before_list[instrnm], addr => Dict())
        haskey(popup_before_list[instrnm][addr], qt.name) || push!(popup_before_list[instrnm][addr], qt.name => false)
        haskey(popup_now_list, instrnm) || push!(popup_now_list, instrnm => Dict())
        haskey(popup_now_list[instrnm], addr) || push!(popup_now_list[instrnm], addr => Dict())
        haskey(popup_now_list[instrnm][addr], qt.name) || push!(popup_now_list[instrnm][addr], qt.name => false)
        popup_now_list[instrnm][addr][qt.name] = CImGui.BeginPopupContextItem()
        popup_now = popup_now_list[instrnm][addr][qt.name]
        popup_before = popup_before_list[instrnm][addr][qt.name]
        !popup_now && popup_before && (popup_before_list[instrnm][addr][qt.name] = false)
        if popup_now
            if qt.enable
                @c InputTextWithHintRSZ("##set", mlstr("set value"), &qt.set)
                if CImGui.Button(
                       stcstr(" ", mlstr("Confirm"), " "),
                       (-Cfloat(0.1), Cfloat(0))
                   ) || triggerset || CImGui.IsKeyPressed(igGetKeyIndex(ImGuiKey_Enter), false)
                    triggerset && (qt.set = qt.optvalues[qt.optedidx])
                    apply!(qt, instrnm, addr)
                    triggerset = false
                    closepopup = true
                end
                if closepopup && !CImGui.IsKeyDown(igGetKeyIndex(ImGuiKey_Enter))
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
                    @c(CImGui.RadioButton(qt.optkeys[i], &qt.optedidx, i)) && (qt.set = optv; triggerset = true)
                end
                CImGui.EndGroup()
                CImGui.SameLine(0, 2CImGui.GetFontSize())
                CImGui.BeginGroup()
                for (i, optv) in enumerate(qt.optvalues)
                    (isodd(i) || optv == "") && continue
                    @c(CImGui.RadioButton(qt.optkeys[i], &qt.optedidx, i)) && (qt.set = optv; triggerset = true)
                end
                CImGui.EndGroup()
            end
            CImGui.Text(stcstr(mlstr("unit"), " "))
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && resolveunitlist(qt, instrnm, addr)
            CImGui.PopItemWidth()
            CImGui.SameLine()
            @c CImGui.Checkbox(mlstr("refresh"), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
            updatefront!(qt)
            popup_before_list[instrnm][addr][qt.name] = true
        end
        qt.isautorefresh && updatefront!(qt)
    end
end

let
    refbtsz::Float32 = 0
    global function edit(qt::ReadQuantity, instrnm, addr)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Button,
            if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button)
            else
                MORESTYLE.Colors.LogError
            end
        )
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered)
        )
        qt.show_edit == "" && updatefront!(qt)
        if CImGui.Button(qt.show_edit, (-1, 0))
            if qt.enable && addr != ""
                fetchdata = refresh_qt(instrnm, addr, qt.name)
                isnothing(fetchdata) || (qt.read = fetchdata)
                updatefront!(qt)
            end
        end
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        if CImGui.BeginPopupContextItem()
            CImGui.Text(stcstr(mlstr("unit"), " "))
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && resolveunitlist(qt, instrnm, addr)
            CImGui.PopItemWidth()
            CImGui.SameLine()
            @c CImGui.Checkbox(mlstr("refresh"), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
            updatefront!(qt)
        end
        qt.isautorefresh && updatefront!(qt)
    end
end

function view(instrbufferviewers_local)
    for ins in keys(instrbufferviewers_local)
        ins == "Others" && continue
        for (addr, ibv) in instrbufferviewers_local[ins]
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
    if CImGui.Button(qt.show_view, (-1, 0))
        Us = CONF.U[qt.utype]
        qt.uindex = (qt.uindex + 1) % length(Us)
        qt.uindex == 0 && (qt.uindex = length(Us))
        updatefront!(qt; show_edit=false)
    end
    CImGui.PopStyleColor()
end

function apply!(qt::SweepQuantity, instrnm, addr)
    addr == "" && return nothing
    Us = CONF.U[qt.utype]
    U = isempty(Us) ? "" : Us[qt.uindex]
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    start_call = remotecall(workers()[1], instrnm, addr) do instrnm, addr
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
    start = waittofetch(start_call)
    step = @trypasse eval(Meta.parse(qt.step)) * Uchange begin
        @error "[$(now())]\n$(mlstr("error parsing step value!!!"))" step = qt.step
    end
    stop = @trypasse eval(Meta.parse(qt.stop)) * Uchange begin
        @error "[$(now())]\n$(mlstr("error parsing stop value!!!"))" stop = qt.stop
    end
    if !(isnothing(start) || isnothing(step) || isnothing(stop))
        if CONF.DAQ.equalstep
            sweepsteps = ceil(Int, abs((start - stop) / step))
            sweepsteps = sweepsteps == 1 ? 2 : sweepsteps
            sweeplist = range(start, stop, length=sweepsteps)
        else
            step = start < stop ? abs(step) : -abs(step)
            sweeplist = collect(start:step:stop)
            sweeplist[end] == stop || push!(sweeplist, stop)
        end
        errormonitor(
            @async begin
                qt.issweeping = true
                ct = Controller(instrnm, addr)
                remotecall_wait(workers()[1], ct) do ct
                    @isdefined(sweepcts) || (global sweepcts = Dict{UUID,Controller}())
                    push!(sweepcts, ct.id => ct)
                    login!(CPU, ct)
                end
                for sv in sweeplist
                    qt.issweeping || break
                    sleep(qt.delay)
                    fetchdata_call = remotecall(workers()[1], sv, ct.id) do sv, ctid
                        try
                            setfunc = Symbol(instrnm, :_, qt.name, :_set) |> eval
                            getfunc = Symbol(instrnm, :_, qt.name, :_get) |> eval
                            sweepcts[ctid](setfunc, CPU, string(sv), Val(:write))
                            returnval = sweepcts[ctid](getfunc, CPU, Val(:read))
                        catch e
                            @error(
                                "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                                instrument = string(instrnm, ": ", addr),
                                quantity = qt.name,
                                exception = e
                            )
                        end
                    end
                    fetchdata = waittofetch(fetchdata_call)
                    isnothing(fetchdata) ? break : qt.read = fetchdata
                end
                remotecall_wait(workers()[1], ct.id) do ctid
                    logout!(CPU, sweepcts[ctid])
                    pop!(sweepcts, ctid)
                end
                qt.issweeping = false
            end
        )
    end
    return nothing
end

function apply!(qt::SetQuantity, instrnm, addr)
    addr == "" && return nothing
    Us = CONF.U[qt.utype]
    U = isempty(Us) ? "" : Us[qt.uindex]
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    sv = U == "" ? qt.set : @trypasse string(float(eval(Meta.parse(qt.set)) * Uchange)) qt.set
    errormonitor(
        @async begin
            fetchdata_call = remotecall(workers()[1], instrnm, addr, sv) do instrnm, addr, sv
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
            fetchdata = waittofetch(fetchdata_call)
            isnothing(fetchdata) || (qt.read = fetchdata)
        end
    ) |> wait
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
    fetchdata_call = remotecall(workers()[1], instrnm, addr) do instrnm, addr
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
    waittofetch(fetchdata_call)
end

function log_instrbufferviewers()
    manualrefresh()
    push!(CFGBUF, "instrbufferviewers/[$(now())]" => deepcopy(INSTRBUFFERVIEWERS))
end

function refresh_fetch_ibvs(ibvs_local; log=false)
    refreshcall_list = []
    remotecall_wait(workers()[1], ibvs_local) do ibvs_local
        @isdefined(refreshcts) || (global refreshcts = Dict())
        empty!(INSTRBUFFERVIEWERS)
        merge!(INSTRBUFFERVIEWERS, ibvs_local)
    end
    for ins in keys(ibvs_local)
        ins == "Others" && continue
        remotecall_wait(workers()[1], ins) do ins
            haskey(refreshcts, ins) || push!(refreshcts, ins => Dict())
        end
        for (addr, ibv) in ibvs_local[ins]
            if ibv.insbuf.isautorefresh || log
                refresh_call = remotecall(workers()[1], ins, addr, log, CONF.DAQ.logall) do ins, addr, log, logall
                    haskey(refreshcts[ins], addr) || push!(refreshcts[ins], addr => Controller(ins, addr))
                    try
                        login!(CPU, refreshcts[ins][addr])
                        for (qtnm, qt) in INSTRBUFFERVIEWERS[ins][addr].insbuf.quantities
                            if (qt.isautorefresh && qt.enable) || (log && (logall || qt.enable))
                                getfunc = Symbol(ins, :_, qtnm, :_get) |> eval
                                qt.read = refreshcts[ins][addr](getfunc, CPU, Val(:read))
                            elseif !qt.enable
                                qt.read = ""
                            end
                        end
                        logout!(CPU, refreshcts[ins][addr])
                    catch e
                        @error(
                            "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                            instrument = string(ins, ": ", addr),
                            exception = e
                        )
                        logout!(CPU, refreshcts[ins][addr])
                        for (_, qt) in INSTRBUFFERVIEWERS[ins][addr].insbuf.quantities
                            qt.read = ""
                        end
                    end
                end
                push!(refreshcall_list, refresh_call)
            end
        end
    end
    @sync for rcall in refreshcall_list
        errormonitor(@async waittofetch(rcall, 36))
    end
    remotecall_fetch(() -> INSTRBUFFERVIEWERS, workers()[1])
end

function manualrefresh()
    ibvs_remote = refresh_fetch_ibvs(INSTRBUFFERVIEWERS; log=true)
    for ins in keys(INSTRBUFFERVIEWERS)
        ins == "Others" && continue
        for (addr, ibv) in INSTRBUFFERVIEWERS[ins]
            for (qtnm, qt) in ibv.insbuf.quantities
                qt.read = ibvs_remote[ins][addr].insbuf.quantities[qtnm].read
            end
        end
    end
end

function autorefresh()
    errormonitor(
        @async while true
            i_sleep = 0
            while i_sleep < CONF.InsBuf.refreshrate
                sleep(0.1)
                i_sleep += 0.1
            end
            if SYNCSTATES[Int(IsAutoRefreshing)]
                ibvs_remote = refresh_fetch_ibvs(INSTRBUFFERVIEWERS)
                for ins in keys(INSTRBUFFERVIEWERS)
                    ins == "Others" && continue
                    for (addr, ibv) in INSTRBUFFERVIEWERS[ins]
                        if ibv.insbuf.isautorefresh
                            for (qtnm, qt) in ibv.insbuf.quantities
                                if qt.isautorefresh
                                    qt.read = ibvs_remote[ins][addr].insbuf.quantities[qtnm].read
                                end
                            end
                        end
                    end
                end
            end
        end
    )
end