function getvalU!(qt::AbstractQuantity)
    U, Us = @c getU(qt.utype, &qt.uindex)
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    if qt.separator == ""
        length(qt.showval) == qt.numread || resizefill!(qt.showval, qt.numread)
        qt.showval[1] = U == "" ? qt.read : @trypass @sprintf("%g", parse(Float64, qt.read) / Uchange) qt.read
    else
        # splitread = split(qt.read, qt.separator)
        # qt.showval = U == "" ? splitread : [@trypass @sprintf("%g", parse(Float64, r) / Uchange) r for r in splitread]
        qt.showval = split(qt.read, qt.separator)
        length(qt.showval) == qt.numread || resizefill!(qt.showval, qt.numread)
    end
    qt.showU = string(U)
end

function updatefront!(qt::SweepQuantity)
    getvalU!(qt)
    qt.show_edit = string("\n", qt.alias, "\n \n", join(qt.showval, qt.separator), " ", qt.showU, "\n ")
    dorender()
end

function updateoptvalue!(qt::SetQuantity)
    if qt.showU == ""
        if qt.read in qt.optvalues
            qt.optedidx = findfirst(==(qt.read), qt.optvalues)
            length(qt.showval) == qt.numread || resizefill!(qt.showval, qt.numread)
            qt.showval[1] = string(qt.optkeys[qt.optedidx], " => ", qt.read)
        end
    else
        floatread = tryparse(Float64, qt.read)
        if !isnothing(floatread)
            floatoptvalues = replace(tryparse.(Float64, qt.optvalues), nothing => NaN)
            if true in Bool.(floatread .≈ floatoptvalues)
                qt.optedidx = findfirst(floatread .≈ floatoptvalues)
                length(qt.showval) == qt.numread || resizefill!(qt.showval, qt.numread)
                qt.showval[1] = string(qt.optkeys[qt.optedidx], " => ", qt.showval[1])
            end
        end
    end
end

function updatefront!(qt::SetQuantity)
    getvalU!(qt)
    updateoptvalue!(qt)
    qt.show_edit = string("\n", qt.alias, "\n \n", join(qt.showval, qt.separator), " ", qt.showU, "\n ")
    dorender()
end

function updatefront!(qt::ReadQuantity)
    getvalU!(qt)
    qt.show_edit = string("\n", qt.alias, "\n \n", join(qt.showval, qt.separator), " ", qt.showU, "\n ")
    dorender()
end

function updatefrontview!(qt::AbstractQuantity)
    getvalU!(qt)
    qt isa SetQuantity && updateoptvalue!(qt)
    qt.show_view = string(qt.alias, "\n", join(qt.showval, qt.separator), " ", qt.showU)
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

function edit(ibv::InstrBufferViewer)
    CImGui.SetNextWindowSize((800, 600) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Once)
    ins, addr = ibv.instrnm, ibv.addr
    if @c CImGui.Begin(stcstr(INSTRCONF[ins].conf.icon, "  ", ins, "  ", addr), &ibv.p_open)
        SetWindowBgImage(
            CONF.BGImage.instrbufferviewer.path;
            rate=CONF.BGImage.instrbufferviewer.rate,
            use=CONF.BGImage.instrbufferviewer.use
        )
        @c testcmd(ins, addr, &ibv.inputcmd, &ibv.reading)
        edit(ibv.insbuf, addr)
        CImGui.IsKeyPressed(ImGuiKey_F5, false) && putonce(true)
    end
    CImGui.End()
end

let
    newcmd::Ref{Tuple{String,Bool}} = ("", false)
    visitedsetting::Dict{String,Bool} = Dict()
    global function testcmd(ins, addr, inputcmd::Ref{String}, reading::Ref{String})
        if CImGui.CollapsingHeader(stcstr("\t", mlstr("Communication Test")))
            if CImGui.BeginTabBar("communication")
                if CImGui.BeginTabItem(mlstr("Command Test"))
                    y = (1 + length(findall("\n", inputcmd[]))) * CImGui.GetTextLineHeight() +
                        2unsafe_load(IMGUISTYLE.FramePadding.y)
                    InputTextMultilineRSZ("##input cmd", inputcmd, (Cfloat(0), y))
                    if CImGui.BeginPopupContextItem()
                        CImGui.MenuItem(mlstr("Clear")) && (inputcmd[] = "")
                        CImGui.EndPopup()
                    end
                    CImGui.SameLine()
                    CImGui.Button(mlstr("Clear History")) && (reading[] = "")
                    updatecontent = newcmd[][1] == addr ? newcmd[][2] : false
                    updatecontent && (newcmd[] = ("", false))
                    TextRect(
                        stcstr(reading[], "\n "), updatecontent;
                        size=(CImGui.GetContentRegionAvail().x, 12CImGui.GetFontSize())
                    )
                    CImGui.Spacing()
                    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, 24)
                    btw = (CImGui.GetContentRegionAvail().x - 2unsafe_load(IMGUISTYLE.ItemSpacing.x)) / 3
                    bth = 2CImGui.GetFrameHeight()
                    if CImGui.Button(stcstr(MORESTYLE.Icons.WriteBlock, "  ", mlstr("Write")), (btw, bth))
                        if addr != ""
                            reading[] *= string("Write: ", inputcmd[], "\n\n")
                            remote_write(ins, addr, inputcmd[], CONF.DAQ.ctbuflen)
                            newcmd[] = (addr, true)
                        end
                    end
                    CImGui.SameLine()
                    if CImGui.Button(stcstr(MORESTYLE.Icons.QueryBlock, "  ", mlstr("Query")), (btw, bth))
                        if addr != ""
                            reading[] *= string("Write: ", inputcmd[], "\n")
                            fetchdata = remote_query(ins, addr, inputcmd[], CONF.DAQ.ctbuflen)
                            isnothing(fetchdata) || (reading[] *= string("Read: \n\t\t", fetchdata, "\n\n"))
                            newcmd[] = (addr, true)
                        end
                    end
                    CImGui.SameLine()
                    if CImGui.Button(stcstr(MORESTYLE.Icons.ReadBlock, "  ", mlstr("Read")), (btw, bth))
                        if addr != ""
                            fetchdata = remote_read(ins, addr, CONF.DAQ.ctbuflen)
                            isnothing(fetchdata) || (reading[] *= string("Read: \n\t\t", fetchdata, "\n\n"))
                            newcmd[] = (addr, true)
                        end
                    end
                    CImGui.PopStyleVar()
                    CImGui.EndTabItem()
                end
                opentab = CImGui.BeginTabItem(mlstr("Settings"))
                if opentab
                    haskey(visitedsetting, addr) || (visitedsetting[addr] = false)
                    if !visitedsetting[addr]
                        deepcopy!(selectbuf(addr), getattr(addr, CONF.Communication.attrlist))
                        visitedsetting[addr] = true
                    end
                    setup(addr)
                    CImGui.EndTabItem()
                    igTabItemButton(mlstr("Save"), 0) && saveattr(addr)
                else
                    visitedsetting[addr] = false
                end
                CImGui.EndTabBar()
            end
            CImGui.Separator()
        end
    end
end

let
    serialattrbuf::SerialInstrAttr = SerialInstrAttr()
    tcpsocketattrbuf::TCPSocketInstrAttr = TCPSocketInstrAttr()
    virtualattrbuf::VirtualInstrAttr = VirtualInstrAttr()
    visaattrbuf::VISAInstrAttr = VISAInstrAttr()
    isobusattrbuf::ISOBUSInstrAttr = ISOBUSInstrAttr(virtualattrbuf)
    qicattrbuf::QICInstrAttr = QICInstrAttr(virtualattrbuf)
    bufdict = Dict()
    global function selectbuf(addr)
        haskey(bufdict, addr) || (bufdict[addr] = selectbuf(getattr(addr)))
        return bufdict[addr]
    end
    selectbuf(::SerialInstrAttr) = serialattrbuf
    selectbuf(::TCPSocketInstrAttr) = tcpsocketattrbuf
    selectbuf(::VirtualInstrAttr) = virtualattrbuf
    selectbuf(::VISAInstrAttr) = visaattrbuf
    selectbuf(attr::ISOBUSInstrAttr) = isobusattrbuf = attr
    selectbuf(attr::QICInstrAttr) = qicattrbuf = attr
end

function saveattr(addr)
    buf = selectbuf(addr)
    CONF.Communication.attrlist[addr] = attrtodict(buf)
    syncattr(buf, addr)
    saveconf()
end

setup(addr) = setup(selectbuf(addr))
function setup(attr::SerialInstrAttr)
    baudrate = Cint(attr.baudrate)
    @c(CImGui.InputInt(mlstr("Baud Rate"), &baudrate)) && baudrate > 0 && (attr.baudrate = baudrate)
    mode = string(attr.mode)
    @c(ComboS(mlstr("Mode"), &mode, string.(instances(SPMode)))) && (attr.mode = getproperty(LibSerialPort, Symbol(mode)))
    ndatabits = Cint(attr.ndatabits)
    @c(igSliderInt(mlstr("Data Bits"), &ndatabits, 5, 8, "%d", 0)) && (attr.ndatabits = ndatabits)
    parity = string(attr.parity)
    @c(ComboS(mlstr("Parity"), &parity, string.(instances(SPParity)))) && (attr.parity = getproperty(LibSerialPort, Symbol(parity)))
    nstopbits = Cint(attr.nstopbits)
    @c(igSliderInt(mlstr("Stop Bits"), &nstopbits, 1, 2, "%d", 0)) && (attr.nstopbits = nstopbits)
    rts = string(attr.rts)
    @c(ComboS(mlstr("Ready to Send"), &rts, string.(instances(SPrts)))) && (attr.rts = getproperty(LibSerialPort, Symbol(rts)))
    cts = string(attr.cts)
    @c(ComboS(mlstr("Clear to Send"), &cts, string.(instances(SPcts)))) && (attr.cts = getproperty(LibSerialPort, Symbol(cts)))
    dtr = string(attr.dtr)
    @c(ComboS(mlstr("Data Terminal Ready"), &dtr, string.(instances(SPdtr)))) && (attr.dtr = getproperty(LibSerialPort, Symbol(dtr)))
    dsr = string(attr.dsr)
    @c(ComboS(mlstr("Data Set Ready"), &dsr, string.(instances(SPdsr)))) && (attr.dsr = getproperty(LibSerialPort, Symbol(dsr)))
    xonxoff = string(attr.xonxoff)
    @c(ComboS(mlstr("XON/XOFF"), &xonxoff, string.(instances(SPXonXoff)))) && (attr.xonxoff = getproperty(LibSerialPort, Symbol(xonxoff)))
    @c InputTextRSZ(mlstr("IDN function"), &attr.idnfunc)
    timeoutw = Cfloat(attr.timeoutw)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Write Timeout"), " (s)"), &timeoutw,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutw = timeoutw)
    timeoutr = Cfloat(attr.timeoutr)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Read Timeout"), " (s)"), &timeoutr,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutr = timeoutr)
    querydelay = Cfloat(attr.querydelay)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Query Delay"), " (s)"), &querydelay,
        1, 0, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.querydelay = querydelay)
    termchar = TERMCHARDICTINV[attr.termchar]
    @c(ComboS(mlstr("Termination Character"), &termchar, keys(TERMCHARDICT))) && (attr.termchar = TERMCHARDICT[termchar])
    @c CImGui.Checkbox(mlstr("Clear buffer when error occurs"), &attr.clearbuffer)
end
function setup(attr::TCPSocketInstrAttr)
    @c InputTextRSZ(mlstr("IDN function"), &attr.idnfunc)
    timeoutw = Cfloat(attr.timeoutw)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Write Timeout"), " (s)"), &timeoutw,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutw = timeoutw)
    timeoutr = Cfloat(attr.timeoutr)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Read Timeout"), " (s)"), &timeoutr,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutr = timeoutr)
    querydelay = Cfloat(attr.querydelay)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Query Delay"), " (s)"), &querydelay,
        1, 0, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.querydelay = querydelay)
    termchar = TERMCHARDICTINV[attr.termchar]
    @c(ComboS(mlstr("Termination Character"), &termchar, keys(TERMCHARDICT))) && (attr.termchar = TERMCHARDICT[termchar])
    @c CImGui.Checkbox(mlstr("Clear buffer when error occurs"), &attr.clearbuffer)
end
function setup(attr::VirtualInstrAttr)
    @c InputTextRSZ(mlstr("IDN function"), &attr.idnfunc)
    querydelay = Cfloat(attr.querydelay)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Query Delay"), " (s)"), &querydelay,
        1, 0, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.querydelay = querydelay)
    termchar = TERMCHARDICTINV[attr.termchar]
    @c(ComboS(mlstr("Termination Character"), &termchar, keys(TERMCHARDICT))) && (attr.termchar = TERMCHARDICT[termchar])
    @c CImGui.Checkbox(mlstr("Clear buffer when error occurs"), &attr.clearbuffer)
end
function setup(attr::VISAInstrAttr)
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, "ASRL")
    baudrate = Cint(attr.baudrate)
    @c(CImGui.InputInt(mlstr("Baud Rate"), &baudrate)) && baudrate > 0 && (attr.baudrate = baudrate)
    ndatabits = Cint(attr.ndatabits)
    @c(igSliderInt(mlstr("Data Bits"), &ndatabits, 5, 8, "%d", 0)) && (attr.ndatabits = ndatabits)
    parity = string(attr.parity)
    @c(ComboS(
        mlstr("Parity"), &parity, string.(instances(VI_ASRL_PAR))
    )) && (attr.parity = eval(Symbol(parity)))
    nstopbits = string(attr.nstopbits)
    @c(ComboS(
        mlstr("Stop Bits"), &nstopbits, string.(instances(VI_ASRL_STOP))
    )) && (attr.nstopbits = eval(Symbol(nstopbits)))
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Common"))
    @c CImGui.Checkbox(mlstr(attr.async ? "Asynchronous" : "Synchronous"), &attr.async)
    @c InputTextRSZ(mlstr("IDN function"), &attr.idnfunc)
    timeoutw = Cfloat(attr.timeoutw)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Write Timeout"), " (s)"), &timeoutw,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutw = timeoutw)
    timeoutr = Cfloat(attr.timeoutr)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Read Timeout"), " (s)"), &timeoutr,
        1, 0.1, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.timeoutr = timeoutr)
    querydelay = Cfloat(attr.querydelay)
    @c(CImGui.DragFloat(
        stcstr(mlstr("Query Delay"), " (s)"), &querydelay,
        1, 0, 360, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    ) && (attr.querydelay = querydelay)
    termchar = TERMCHARDICTINV[attr.termchar]
    @c(ComboS(mlstr("Termination Character"), &termchar, keys(TERMCHARDICT))) && (attr.termchar = TERMCHARDICT[termchar])
    @c CImGui.Checkbox(mlstr("Clear buffer when error occurs"), &attr.clearbuffer)
end
setup(attr::ISOBUSInstrAttr) = setup(attr.attr)
setup(attr::QICInstrAttr) = setup(attr.attr)

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
    btsize = (CImGui.GetContentRegionAvail().x - unsafe_load(IMGUISTYLE.ItemSpacing.x) * (CONF.InsBuf.showcol - 1)) / CONF.InsBuf.showcol
    showi = 0
    for (i, qt) in enumerate(values(insbuf.quantities))
        qt.enable || insbuf.showdisable || continue
        qt.passfilter || continue
        showi += 1
        CImGui.PushID(qt.name)
        CONF.InsBuf.showcol == 1 || showi % CONF.InsBuf.showcol == 1 || showi == 1 || CImGui.SameLine()
        edit(qt, insbuf.instrnm, addr; btsize=(btsize, Cfloat(0)))
        CImGui.PopID()
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
            putonce(true)
        end
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, (0, 0))
        CImGui.Text(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Auto Refresh")))
        CImGui.SameLine()
        isautoref = STATES[AutoRefreshing]
        @c CImGui.Checkbox("##auto refresh", &isautoref)
        STATES[AutoRefreshing] = isautoref
        insbuf.isautorefresh = STATES[AutoRefreshing]
        CImGui.Text(stcstr(MORESTYLE.Icons.ShowCol, " ", mlstr("Display Columns")))
        CImGui.SameLine()
        CImGui.PushItemWidth(3CImGui.GetFontSize() / 2)
        @c CImGui.DragInt(
            "##display columns",
            &CONF.InsBuf.showcol, 1, 1, 12, "%d",
            CImGui.ImGuiSliderFlags_AlwaysClamp
        )
        CImGui.PopItemWidth()
        CImGui.Text(stcstr(MORESTYLE.Icons.View, " ", mlstr("Show Disabled")))
        CImGui.SameLine()
        @c CImGui.Checkbox("##show disabled", &insbuf.showdisable)
        CImGui.PopStyleVar()
        CImGui.EndPopup()
    end
    CImGui.IsKeyPressed(ImGuiKey_F5, false) && putonce(true)
end

let
    stbtsz::Float32 = 0
    closepopup::Bool = false
    global function edit(qt::SweepQuantity, instrnm, addr; btsize=(-1, 0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.SweepQuantityTxt)
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_ButtonHovered,
            qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : CImGui.c_get(
                IMGUISTYLE.Colors, CImGui.ImGuiCol_ButtonHovered
            )
        )
        qt.show_edit == "" && updatefront!(qt)
        # CImGui.PushFont(BIGFONT)
        ColoredButton(
            stcstr(centermultiline(qt.show_edit), "###for refresh");
            size=btsize,
            colbt=if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.SweepQuantityBt
            else
                MORESTYLE.Colors.ErrorBg
            end
        ) && Threads.@spawn @trycatch mlstr("reading task failed!!!") getread!(qt, instrnm, addr)
        if qt.issweeping
            rmin = CImGui.GetItemRectMin()
            rsz = CImGui.GetItemRectSize()
            frac = Cfloat(calcfraction(qt.presenti, qt.nstep))
            phcol = CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_PlotHistogram)
            pgcol = [phcol.x, phcol.y, phcol.z, min(0.6, phcol.w)]
            CImGui.AddRectFilled(
                CImGui.GetWindowDrawList(), rmin, (rmin.x + frac * rsz.x, rmin.y + rsz.y),
                pgcol, unsafe_load(IMGUISTYLE.FrameRounding)
            )
            if CImGui.IsItemHovered() && CImGui.BeginTooltip()
                CImGui.ProgressBar(
                    calcfraction(qt.presenti, qt.nstep), (0, 0),
                    progressmark(qt.presenti, qt.nstep, qt.elapsedtime)
                )
                CImGui.EndTooltip()
            end
        end
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        if CImGui.BeginPopupContextItem()
            if qt.enable
                ftsz = CImGui.GetFontSize()
                itemw = CImGui.CalcItemWidth()
                CImGui.BeginGroup()
                CImGui.PushItemWidth(2itemw / 3)
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Cfloat(0), Cfloat(0)))
                @c InputTextWithHintRSZ("##step", mlstr("step"), &qt.step)
                CImGui.PopStyleVar()
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Cfloat(0), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
                @c InputTextWithHintRSZ("##stop", mlstr("stop"), &qt.stop)
                CImGui.PopItemWidth()
                CImGui.EndGroup()
                CImGui.SameLine()
                CImGui.PushStyleVar(
                    CImGui.ImGuiStyleVar_FramePadding,
                    (unsafe_load(IMGUISTYLE.FramePadding.x), CImGui.GetFrameHeight() - ftsz / 2)
                )
                CImGui.PushItemWidth(itemw / 3)
                @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
                CImGui.PopItemWidth()
                CImGui.PopStyleVar(2)
                @c CImGui.DragFloat("##delay", &qt.delay, 1.0, 0.01, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                if qt.issweeping
                    if CImGui.Button(
                        mlstr(" Stop "), (itemw, Cfloat(0))
                    ) || CImGui.IsKeyPressed(ImGuiKey_Enter, false)
                        qt.issweeping = false
                    end
                else
                    if CImGui.Button(
                        mlstr("Start"), (itemw, Cfloat(0))
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
            if qt.isautorefresh
                CImGui.PushItemWidth(4CImGui.GetFontSize())
                @c CImGui.DragFloat(
                    "##refreshrate", &qt.refreshrate, 0.1, 0.1, 360, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.PopItemWidth()
                CImGui.SameLine()
            end
            @c CImGui.Checkbox(stcstr(mlstr("refresh"), qt.isautorefresh ? " (s)" : ""), &qt.isautorefresh)
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
        # CImGui.PushFont(BIGFONT)
        ColoredButton(
            stcstr(centermultiline(qt.show_edit), "###for refresh");
            size=btsize,
            colbt=if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.SetQuantityBt
            else
                MORESTYLE.Colors.ErrorBg
            end
        ) && Threads.@spawn @trycatch mlstr("reading task failed!!!") getread!(qt, instrnm, addr)
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        haskey(popup_before_list, instrnm) || (popup_before_list[instrnm] = Dict())
        haskey(popup_before_list[instrnm], addr) || (popup_before_list[instrnm][addr] = Dict())
        haskey(popup_before_list[instrnm][addr], qt.name) || (popup_before_list[instrnm][addr][qt.name] = false)
        popup_now = CImGui.BeginPopupContextItem()
        popup_before = popup_before_list[instrnm][addr][qt.name]
        !popup_now && popup_before && (popup_before_list[instrnm][addr][qt.name] = false)
        if popup_now
            if qt.enable
                ftsz = CImGui.GetFontSize()
                itemw = CImGui.CalcItemWidth()
                CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Cfloat(0), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
                CImGui.PushItemWidth(2itemw / 3)
                @c InputTextWithHintRSZ("##set", mlstr("set value"), &qt.set)
                CImGui.PopItemWidth()
                CImGui.SameLine()
                CImGui.PushItemWidth(itemw / 3)
                @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
                CImGui.PopItemWidth()
                CImGui.PopStyleVar()
                if CImGui.Button(
                       mlstr("Confirm"), (itemw, Cfloat(0))
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
                    fetchdata = remote_qtread(instrnm, addr, qt.name, CONF.DAQ.ctbuflen, qt.timeoutr)
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
            if qt.isautorefresh
                CImGui.PushItemWidth(4CImGui.GetFontSize())
                @c CImGui.DragFloat(
                    "##refreshrate", &qt.refreshrate, 0.1, 0.1, 360, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
                )
                CImGui.PopItemWidth()
                CImGui.SameLine()
            end
            @c CImGui.Checkbox(stcstr(mlstr("refresh"), qt.isautorefresh ? " (s)" : ""), &qt.isautorefresh)
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
        # CImGui.PushFont(BIGFONT)
        ColoredButton(
            stcstr(centermultiline(qt.show_edit), "###for refresh");
            size=btsize,
            colbt=if qt.enable
                qt.isautorefresh ? MORESTYLE.Colors.DAQTaskRunning : MORESTYLE.Colors.ReadQuantityBt
            else
                MORESTYLE.Colors.ErrorBg
            end
        ) && Threads.@spawn @trycatch mlstr("reading task failed!!!") getread!(qt, instrnm, addr)
        # CImGui.PopFont()
        CImGui.PopStyleColor(2)
        if CONF.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            ItemTooltip(qt.help)
        end
        if CImGui.BeginPopupContextItem()
            CImGui.Text(stcstr(mlstr("unit"), " "))
            CImGui.SameLine()
            CImGui.PushItemWidth(4CImGui.GetFontSize())
            @c(ShowUnit("##insbuf", qt.utype, &qt.uindex)) && (updatefront!(qt); resolveunitlist(qt, instrnm, addr))
            CImGui.PopItemWidth()
            CImGui.SameLine()
            CImGui.PushItemWidth(2CImGui.GetFontSize())
            qt.isautorefresh && @c CImGui.DragFloat(
                "##refreshrate", &qt.refreshrate, 0.1, 0.1, 360, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp
            )
            CImGui.PopItemWidth()
            CImGui.SameLine()
            @c CImGui.Checkbox(stcstr(mlstr("refresh"), qt.isautorefresh ? " (s)" : ""), &qt.isautorefresh)
            CImGui.SameLine()
            if @c CImGui.Checkbox(qt.enable ? mlstr("Enable") : mlstr("Disable"), &qt.enable)
                resolvedisablelist(qt, instrnm, addr)
            end
            CImGui.EndPopup()
        end
    end
end

function view(instrbufferviewers_local; filterins="", filteraddr="", filterqt="", filteron=false)
    for (ins, inses) in filter(x -> !isempty(x.second), instrbufferviewers_local)
        ins == "Others" && continue
        filteron && ins != filterins && continue
        for (addr, ibv) in inses
            filteron && filteraddr != "" && addr != filteraddr && continue
            CImGui.TextColored(MORESTYLE.Colors.HighlightText, stcstr(ins, "：", addr))
            CImGui.PushID(addr)
            view(ibv.insbuf; filterqt=filterqt, filteron=filteron)
            CImGui.PopID()
        end
    end
end

function view(insbuf::InstrBuffer; filterqt="", filteron=false)
    y = ceil(Int, length(insbuf.quantities) / CONF.InsBuf.showcol) * 2CImGui.GetFrameHeight()
    CImGui.BeginChild("view insbuf", (Float32(0), y))
    CImGui.Columns(CONF.InsBuf.showcol, C_NULL, false)
    CImGui.PushID(insbuf.instrnm)
    for (name, qt) in insbuf.quantities
        filteron && filterqt != "" && qt.alias != filterqt && continue
        CImGui.PushID(name)
        view(qt)
        CImGui.NextColumn()
        CImGui.PopID()
    end
    CImGui.PopID()
    CImGui.EndChild()
end

function view(qt::AbstractQuantity, size=(-1, 0))
    qt.show_view == "" && updatefrontview!(qt)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Button,
        qt.enable ? CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Button) : MORESTYLE.Colors.ErrorBg
    )
    if CImGui.Button(centermultiline(qt.show_view), size)
        _, Us = @c getU(qt.utype, &qt.uindex)
        uindex = findfirst(==(qt.showU), string.(Us))
        if !isnothing(uindex)
            uindexo = qt.uindex
            qt.uindex = uindex + 1
            updatefrontview!(qt)
            qt.uindex = uindexo
        end
    end
    CImGui.PopStyleColor()
    if CImGui.IsItemHovered()
        CImGui.BeginTooltip()
        CImGui.PushTextWrapPos(CImGui.GetFontSize() * 36.0)
        CImGui.Text(qt.name)
        if !(qt isa ReadQuantity)
            U, _ = @c getU(qt.utype, &qt.uindex)
            if qt isa SweepQuantity
                CImGui.Text(stcstr(mlstr("step"), mlstr(": "), qt.step, U))
                CImGui.Text(stcstr(mlstr("stop"), mlstr(": "), qt.stop, U))
                CImGui.Text(stcstr(mlstr("delay"), mlstr(": "), qt.delay, "s"))
            elseif qt isa SetQuantity
                CImGui.Text(stcstr(mlstr("set"), mlstr(": "), qt.set, U))
            end
        end
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
end

function apply!(qt::SweepQuantity, instrnm, addr)
    addr == "" && return nothing
    U, Us = @c getU(qt.utype, &qt.uindex)
    U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
    start = @trypasse parse(Float64, remote_qtread(instrnm, addr, qt.name, CONF.DAQ.ctbuflen, qt.timeoutr)) begin
        @error "[$(now())]\n$(mlstr("error parsing start value!!!"))"
    end
    step = @trypasse eval(Meta.parse(qt.step)) * Uchange begin
        @error "[$(now())]\n$(mlstr("error parsing step value!!!"))" step = qt.step
    end
    stop = @trypasse eval(Meta.parse(qt.stop)) * Uchange begin
        @error "[$(now())]\n$(mlstr("error parsing stop value!!!"))" stop = qt.stop
    end
    if !(isnothing(start) | isnothing(step) | isnothing(stop))
        sweeplist = gensweeplist(start, step, stop; equalstep=CONF.DAQ.equalstep)
        qt.nstep = length(sweeplist)
        Threads.@spawn @trycatch mlstr("sweeping task failed!!!") begin
            @info "[$(now())]\nBefore sweeping" instrument = instrnm address = addr quantity = qt
            actionidx = 1
            SYNCSTATES[IsDAQTaskRunning] && (actionidx = logaction(qt, instrnm, addr))
            @sync begin
                @async_record "sweep remote: $instrnm $addr $(qt.name)" remote_qtsweep(
                    instrnm, addr, qt.name, sweeplist, CONF.DAQ.ctbuflen, qt.timeoutw, qt.timeoutr, qt.delay, qt;
                    channelsize=CONF.DAQ.channelsize, packsize=CONF.DAQ.packsize, retreading=CONF.InsBuf.retreading
                )
                @async_record "sweep local: $instrnm $addr $(qt.name)" while qt.issweeping
                    updatefront!(qt)
                    CONF.DAQ.highspeeddatatransfer ? yield() : sleep(qt.delay / 2)
                end
            end
            @info "[$(now())]\nAfter sweeping" instrument = instrnm address = addr quantity = qt
            SYNCSTATES[IsDAQTaskRunning] && logaction(qt, instrnm, addr, actionidx)
        end
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
    if byoptvalues || (U == "" && sv != "") || !isnothing(tryparse(Float64, sv))
        @info "[$(now())]\nBefore setting" instrument = instrnm address = addr quantity = qt
        actionidx = 1
        SYNCSTATES[IsDAQTaskRunning] && (actionidx = logaction(qt, instrnm, addr))
        fetchdata = remote_qtset(
            instrnm, addr, qt.name, sv, CONF.DAQ.ctbuflen, qt.timeoutw, qt.timeoutr;
            attrlist=CONF.Communication.attrlist
        )
        isnothing(fetchdata) || (qt.read = fetchdata; updatefront!(qt))
        @info "[$(now())]\nAfter setting" instrument = instrnm address = addr quantity = qt
        SYNCSTATES[IsDAQTaskRunning] && logaction(qt, instrnm, addr, actionidx)
    else
        @warn "[$(now())]\n$(mlstr("invalid inputs!"))"
    end
    return nothing
end

function logaction(qt::AbstractQuantity, instrnm, addr)
    haskey(CFGBUF, "actions") || (CFGBUF["actions"] = Vector{Tuple{DateTime,String,String,AbstractQuantity}}[])
    push!(CFGBUF["actions"], Tuple{DateTime,String,String,AbstractQuantity}[])
    push!(CFGBUF["actions"][end], (now(), instrnm, addr, deepcopy(qt)))
    return length(CFGBUF["actions"])
end
function logaction(qt::AbstractQuantity, instrnm, addr, idx)
    haskey(CFGBUF, "actions") || (CFGBUF["actions"] = Vector{Tuple{DateTime,String,String,AbstractQuantity}}[])
    if idx > length(CFGBUF["actions"])
        push!(CFGBUF["actions"], Tuple{DateTime,String,String,AbstractQuantity}[])
        push!(CFGBUF["actions"][end], (DateTime(0), instrnm, addr, deepcopy(qt)))
        push!(CFGBUF["actions"][end], (now(), instrnm, addr, deepcopy(qt)))
    else
        push!(CFGBUF["actions"][idx], (now(), instrnm, addr, deepcopy(qt)))
    end
end

function viewactions(actions::Vector{Vector{Tuple{DateTime,String,String,AbstractQuantity}}})
    CImGui.BeginChild("viewactions")
    CImGui.Columns(CONF.InsBuf.showcol, C_NULL, false)
    for (i, action) in enumerate(actions)
        CImGui.PushID(i)
        viewactions(action)
        CImGui.NextColumn()
        CImGui.PopID()
    end
    CImGui.EndChild()
end
function viewactions(actions::Vector{Tuple{DateTime,String,String,AbstractQuantity}})
    sz1 = CImGui.CalcTextSize(mlstr("B\ne\nf\no\nr\ne")).y
    sz2 = CImGui.CalcTextSize(mlstr("A\nf\nt\ne\nr")).y
    y = sz1 + sz2 + 4unsafe_load(IMGUISTYLE.FramePadding.y) + 2unsafe_load(IMGUISTYLE.WindowPadding.y) +
        unsafe_load(IMGUISTYLE.ItemSpacing.y) + CImGui.GetFrameHeightWithSpacing()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
    CImGui.BeginChild("action", (Cfloat(-1), y), true)
    ColoredButton(
        stcstr(actions[1][2], ": ", actions[1][3]);
        size=(-1, 0), colbt=(0, 0, 0, 0), colbth=(0, 0, 0, 0), colbta=(0, 0, 0, 0)
    )
    if length(actions) == 1
        CImGui.Button(mlstr("B\ne\nf\no\nr\ne"), (2CImGui.GetFontSize(), Cfloat(0)))
        CImGui.SameLine()
        viewaction(actions[1], sz1 + 2unsafe_load(IMGUISTYLE.FramePadding.y))
        CImGui.Button(mlstr("A\nf\nt\ne\nr"), (2CImGui.GetFontSize(), Cfloat(0)))
        CImGui.SameLine()
        CImGui.Button(mlstr("Unrecorded"), (-1, -1))
    elseif length(actions) == 2
        CImGui.PushID("before")
        CImGui.Button(mlstr("B\ne\nf\no\nr\ne"), (2CImGui.GetFontSize(), Cfloat(0)))
        CImGui.SameLine()
        viewaction(actions[1], sz1 + 2unsafe_load(IMGUISTYLE.FramePadding.y))
        CImGui.PopID()
        CImGui.PushID("after")
        CImGui.Button(mlstr("A\nf\nt\ne\nr"), (2CImGui.GetFontSize(), Cfloat(0)))
        CImGui.SameLine()
        viewaction(actions[2], sz2 + 2unsafe_load(IMGUISTYLE.FramePadding.y))
        CImGui.PopID()
    end
    CImGui.EndChild()
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end
function viewaction(action::Tuple{DateTime,String,String,AbstractQuantity}, totalheight)
    if action[1] == DateTime(0)
        CImGui.Button(mlstr("Unrecorded"), (Cfloat(-1), totalheight))
    else
        CImGui.BeginGroup()
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 0))
        CImGui.Button(string(action[1]), (Cfloat(-1), 2CImGui.GetFontSize()))
        view(action[4], (Cfloat(-1), totalheight - CImGui.GetItemRectSize().y))
        CImGui.PopStyleVar()
        CImGui.EndGroup()
    end
end

function resolvedisablelist(qt::AbstractQuantity, instrnm, addr)
    haskey(CONF.InsBuf.disablelist, instrnm) || (CONF.InsBuf.disablelist[instrnm] = Dict())
    haskey(CONF.InsBuf.disablelist[instrnm], addr) || (CONF.InsBuf.disablelist[instrnm][addr] = [])
    disablelist = CONF.InsBuf.disablelist[instrnm][addr]
    if qt.enable
        qt.name in disablelist && deleteat!(disablelist, findfirst(==(qt.name), disablelist))
    else
        qt.name in disablelist || push!(disablelist, qt.name)
    end
    saveconf()
end

function resolveunitlist(qt::AbstractQuantity, instrnm, addr)
    haskey(CONF.InsBuf.unitlist, instrnm) || (CONF.InsBuf.unitlist[instrnm] = Dict())
    haskey(CONF.InsBuf.unitlist[instrnm], addr) || (CONF.InsBuf.unitlist[instrnm][addr] = Dict())
    unitlist = CONF.InsBuf.unitlist[instrnm][addr]
    haskey(unitlist, qt.name) || (unitlist[qt.name] = qt.uindex)
    unitlist[qt.name] != qt.uindex && (unitlist[qt.name] = qt.uindex; saveconf())
end

function getread!(qt::AbstractQuantity, instrnm, addr)
    if qt.enable && addr != ""
        fetchdata = remote_qtread(instrnm, addr, qt.name, CONF.DAQ.ctbuflen, qt.timeoutr)
        isnothing(fetchdata) || (qt.read = fetchdata)
        updatefront!(qt)
    end
end

function log_instrbufferviewers()
    putonce(true)
    CFGBUF["instrbufferviewers/[$(now())]"] = deepcopy(INSTRBUFFERVIEWERS)
end

let
    puttask::Ref{Task} = Ref{Task}()
    taketask::Ref{Task} = Ref{Task}()
    monitortask::Ref{Task} = Ref{Task}()
    stoptask::Bool = false
    global function stoprefresh()
        stoptask = true
        sleep(0.1)
        if isassigned(puttask)
            istaskdone(puttask[]) || schedule(puttask[], mlstr("Stop autorefresh putting task"); error=true)
            if istaskdone(puttask[])
                @info mlstr("instrument autorefresh putting task stopped")
            else
                @warn mlstr("instrument autorefresh putting task not stopped")
            end
        end
        if isassigned(taketask)
            istaskdone(taketask[]) || schedule(taketask[], mlstr("Stop autorefresh taking task"); error=true)
            if istaskdone(taketask[])
                @info mlstr("instrument autorefresh taking task stopped")
            else
                @warn mlstr("instrument autorefresh taking task not stopped")
            end
        end
    end
    global function startrefresh()
        stoptask = false
        puttask[] = @spawn_record "instrument autorefresh putting task" while !stoptask
            putonce()
            sleep(0.001)
        end
        taketask[] = @spawn_record "instrument autorefresh taking task" while !stoptask
            if isoutputready()
                try
                    instrnm, addr, qtnm, read = takeoutput!()
                    qt = INSTRBUFFERVIEWERS[instrnm][addr].insbuf.quantities[qtnm]
                    qt.read = read
                    qt.lastrefresh = time()
                    qt.refreshed = false
                    updatefront!(qt)
                catch e
                    @error(
                        "[$(now())]\n$(mlstr("instrument autorefresh taking task failed!!!"))",
                        exception = e
                    )
                    showbacktrace()
                end
                yield()
            else
                sleep(0.001)
            end
        end
        sleep(0.1)
        if istaskstarted(puttask[])
            @info mlstr("instrument autorefresh putting task started")
        else
            @warn mlstr("instrument autorefresh putting task not started")
        end
        if istaskstarted(taketask[])
            @info mlstr("instrument autorefresh taking task started")
        else
            @warn mlstr("instrument autorefresh taking task not started")
        end
    end
    global function putonce(log=false)
        try
            for (ins, inses) in INSTRBUFFERVIEWERS
                ins == "Others" && continue
                for ibv in values(inses)
                    for qt in values(ibv.insbuf.quantities)
                        if log && (CONF.DAQ.logall || qt.enable)
                            putinput!(ins, ibv.addr, qt.name, qt.timeoutr)
                        elseif STATES[AutoRefreshing] && qt.enable && qt.isautorefresh
                            if !qt.refreshed && time() - qt.lastrefresh > qt.refreshrate
                                putinput!(ins, ibv.addr, qt.name, qt.timeoutr)
                                qt.refreshed = true
                            end
                        end
                    end
                end
            end
        catch e
            @error(
                "[$(now())]\n$(mlstr("instrument autorefresh putting task failed!!!"))",
                exception = e
            )
            showbacktrace()
        end
    end
end