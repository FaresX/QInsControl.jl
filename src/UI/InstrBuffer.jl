mutable struct InstrQuantity
    enable::Bool
    name::String
    alias::String
    step::String
    stop::String
    delay::Cfloat
    set::String
    optvalues::Vector{String}
    optedvalueidx::Cint
    read::String
    utype::String
    uindex::Int
    type::Symbol
    help::String
    isautorefresh::Bool
end
InstrQuantity() = InstrQuantity(true, "", "", "", "", Cfloat(0.1), "", [""], 1, "", "", 1, :set, "", false)
InstrQuantity(name, qtcf::QuantityConf) = InstrQuantity(qtcf.enable, name, qtcf.alias, "", "", Cfloat(0.1), "", qtcf.optvalues, 1, "", "", 1, Symbol(qtcf.type), qtcf.help, false)

mutable struct InstrBuffer
    instrnm::String
    quantities::OrderedDict{String,InstrQuantity}
    isautorefresh::Bool
end
InstrBuffer() = InstrBuffer("", OrderedDict(), false)

const instrbuffer::OrderedDict{String,OrderedDict{String,InstrBuffer}} = OrderedDict()
refreshrate::Cfloat = 6 #仪器状态刷新率

function InstrBuffer(instrnm)
    haskey(insconf, instrnm) || @error "[$(now())]\n不支持的仪器!!!" instrument = instrnm
    sweepqts = [qt for qt in keys(insconf[instrnm].quantities) if insconf[instrnm].quantities[qt].type == "sweep"]
    setqts = [qt for qt in keys(insconf[instrnm].quantities) if insconf[instrnm].quantities[qt].type == "set"]
    readqts = [qt for qt in keys(insconf[instrnm].quantities) if insconf[instrnm].quantities[qt].type == "read"]
    quantities = [sweepqts; setqts; readqts]
    instrqts = OrderedDict()
    for qt in quantities
        enable = insconf[instrnm].quantities[qt].enable
        alias = insconf[instrnm].quantities[qt].alias
        optvalues = insconf[instrnm].quantities[qt].optvalues
        utype = insconf[instrnm].quantities[qt].U
        type = Symbol(insconf[instrnm].quantities[qt].type)
        help = replace(insconf[instrnm].quantities[qt].help, "\\\n" => "")
        push!(instrqts, qt => InstrQuantity(enable, qt, alias, "", "", Cfloat(0.1), "", optvalues, 1, "", utype, 1, type, help, false))
    end
    InstrBuffer(instrnm, instrqts, false)
end

mutable struct InstrBufferViewer
    instrnm::String
    addr::String
    inputcmd::String
    readstr::String
    p_open::Ref{Bool}
end
InstrBufferViewer(instrnm, addr) = InstrBufferViewer(instrnm, addr, "*IDN?", "", Ref(false))

const instrbufferviewers::Dict{String,Dict{String,InstrBufferViewer}} = Dict()

let
    # window_ids::Dict{Tuple{String,String},String} = Dict()
    global function edit(ibv::InstrBufferViewer)
        # CImGui.SetNextWindowPos((600, 100), CImGui.ImGuiCond_Once)
        # CImGui.SetNextWindowSize((600, 400), CImGui.ImGuiCond_Once)
        ins, addr = ibv.instrnm, ibv.addr
        # (ins, addr) in keys(window_ids) || push!(window_ids, (ins, addr) => string(insconf[ins]["conf"]["icon"], "  ", ins, " --- ", addr))
        # if CImGui.Begin(window_ids[(ins, addr)], ibv.p_open)
        if CImGui.Begin(string(insconf[ins].conf.icon, "  ", ins, " --- ", addr), ibv.p_open)
            @c testcmd(ins, addr, &ibv.inputcmd, &ibv.readstr)
            insbuf = instrbuffer[ins][addr]
            # CImGui.BeginChild("outsiderightclick")
            edit(insbuf, addr)
            # CImGui.EndChild()
            !CImGui.IsAnyItemHovered() && CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_ChildWindows) && CImGui.OpenPopupOnItemClick("rightclick")
            if CImGui.BeginPopup("rightclick")
                global refreshrate
                if CImGui.MenuItem(morestyle.Icons.InstrumentsManualRef * " 手动刷新", "F5", false, !syncstates[Int(isdaqtask_running)])
                    insbuf.isautorefresh = true
                    lockstates(refresh_remote, instrbuffer_rc, instrbuffer, log=true)
                end
                CImGui.Text(morestyle.Icons.InstrumentsAutoRef * " 自动刷新")
                CImGui.SameLine()
                isautoref = syncstates[Int(isautorefresh)]
                @c CImGui.Checkbox("##自动刷新", &isautoref)
                syncstates[Int(isautorefresh)] = isautoref
                insbuf.isautorefresh = syncstates[Int(isautorefresh)]
                if isautoref
                    CImGui.SameLine()
                    CImGui.Text(" ")
                    CImGui.SameLine()
                    CImGui.PushItemWidth(CImGui.GetFontSize() * 2)
                    @c CImGui.DragFloat("##自动刷新", &refreshrate, 0.1, 0.1, 60, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                    remotecall_wait((x) -> (global refreshrate = x), workers()[1], refreshrate)
                    CImGui.PopItemWidth()
                end
                CImGui.EndPopup()
            end
            CImGui.IsKeyReleased(294) && lockstates(refresh_remote, instrbuffer_rc, instrbuffer, log=true)
        end
        CImGui.End()
    end
end

let
    firsttime::Bool = true
    selectedins::String = ""
    selectedaddr::String = ""
    inputcmd::String = "*IDN?"
    readstr::String = ""
    default_insbufs = Dict{String,InstrBuffer}()
    global function ShowInstrBuffer(p_open::Ref)
        # CImGui.SetNextWindowPos((600, 100), CImGui.ImGuiCond_Once)
        # CImGui.SetNextWindowSize((1000, 800), CImGui.ImGuiCond_Once)
        if CImGui.Begin(morestyle.Icons.InstrumentsOverview * "  仪器设置和状态", p_open)
            CImGui.Columns(2)
            firsttime && (CImGui.SetColumnOffset(1, CImGui.GetWindowWidth() * 0.25); firsttime = false)
            CImGui.BeginChild("仪器列表")
            CImGui.Selectable(morestyle.Icons.InstrumentsOverview * " 总览", selectedins == "") && (selectedins = "")
            for ins in keys(instrbuffer)
                CImGui.Selectable(insconf[ins].conf.icon * " " * ins, selectedins == ins) && (selectedins = ins)
                CImGui.SameLine()
                CImGui.TextDisabled("($(length(instrbuffer[ins])))")
            end
            CImGui.EndChild()
            if CImGui.BeginPopupContextItem()
                global refreshrate
                if CImGui.MenuItem(morestyle.Icons.InstrumentsManualRef * " 手动刷新", "F5", false, !syncstates[Int(isdaqtask_running)])
                    lockstates(refresh_remote, instrbuffer_rc, instrbuffer, log=true)
                end
                CImGui.Text(morestyle.Icons.InstrumentsAutoRef * " 自动刷新")
                CImGui.SameLine()
                isautoref = syncstates[Int(isautorefresh)]
                @c CImGui.Checkbox("##自动刷新", &isautoref)
                syncstates[Int(isautorefresh)] = isautoref
                if isautoref
                    CImGui.SameLine()
                    CImGui.Text(" ")
                    CImGui.SameLine()
                    CImGui.PushItemWidth(CImGui.GetFontSize() * 2)
                    @c CImGui.DragFloat("##自动刷新", &refreshrate, 0.1, 0.1, 60, "%.1f", CImGui.ImGuiSliderFlags_AlwaysClamp)
                    remotecall_wait((x) -> (global refreshrate = x), workers()[1], refreshrate)
                    CImGui.PopItemWidth()
                end
                CImGui.EndPopup()
            end
            CImGui.IsKeyReleased(294) && lockstates(refresh_remote, instrbuffer_rc, instrbuffer, log=true)
            CImGui.NextColumn()
            CImGui.BeginChild("设置选项")
            haskey(instrbuffer, selectedins) || (selectedins = "")
            if selectedins == ""
                for ins in keys(instrbuffer)
                    CImGui.TextColored(morestyle.Colors.HighlightText, string(ins, "："))
                    for addr in keys(instrbuffer[ins])
                        CImGui.Text(string("\t\t", addr, "\t\t"))
                        CImGui.SameLine()
                        insbuf = instrbuffer[ins][addr]
                        @c CImGui.Checkbox("##是否自动刷新$addr", &insbuf.isautorefresh)
                    end
                    CImGui.Separator()
                end
            else
                showinslist::Set = @trypass keys(instrbuffer[selectedins]) Set{String}()
                CImGui.PushItemWidth(-CImGui.GetFontSize() * 2.5)
                @c ComBoS("地址", &selectedaddr, showinslist)
                CImGui.PopItemWidth()
                CImGui.Separator()
                @c testcmd(selectedins, selectedaddr, &inputcmd, &readstr)

                selectedaddr = haskey(instrbuffer[selectedins], selectedaddr) ? selectedaddr : ""
                haskey(default_insbufs, selectedins) || push!(default_insbufs, selectedins => InstrBuffer(selectedins))
                insbuf = selectedaddr == "" ? default_insbufs[selectedins] : instrbuffer[selectedins][selectedaddr]
                edit(insbuf, selectedaddr)
            end
            CImGui.EndChild()
        end
        CImGui.End()
    end
end #let    

function testcmd(ins, addr, inputcmd::Ref{String}, readstr::Ref{String})
    if CImGui.CollapsingHeader("\t指令测试")
        y = (1 + length(findall("\n", inputcmd[]))) * CImGui.GetTextLineHeight() + 2unsafe_load(imguistyle.FramePadding.y)
        InputTextMultilineRSZ("##输入命令", inputcmd, (Float32(-1), y))
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem("清空") && (inputcmd[] = "")
            CImGui.EndPopup()
        end
        TextRect(string(readstr[], "\n "))
        CImGui.BeginChild("对齐按钮", (Float32(0), CImGui.GetFrameHeightWithSpacing()))
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, 12)
        CImGui.Columns(3, C_NULL, false)
        if CImGui.Button(morestyle.Icons.WriteBlock * "  Write", (-1, 0))
            if addr != ""
                instr = instrument(ins, addr)
                lockstates() do
                    @trylink_do instr write(instr, inputcmd[]) nothing
                end
            end
        end
        CImGui.NextColumn()
        if CImGui.Button(morestyle.Icons.QueryBlock * "  Query", (-1, 0))
            if addr != ""
                instr = instrument(ins, addr)
                lockstates() do
                    @trylink_do instr (readstr[] = query(instr, inputcmd[])) nothing
                end
            end
        end
        CImGui.NextColumn()
        if CImGui.Button(morestyle.Icons.ReadBlock * "  Read", (-1, 0))
            if addr != ""
                instr = instrument(ins, addr)
                lockstates() do
                    @trylink_do instr (readstr[] = read(instr)) nothing
                end
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
    CImGui.BeginChild("InstrBuffer")
    CImGui.Columns(conf.InsBuf.showcol, C_NULL, false)
    for (i, qt) in enumerate(values(insbuf.quantities))
        CImGui.PushID(qt.name)
        qt.enable && (edit(qt, insbuf.instrnm, addr); CImGui.NextColumn())
        CImGui.PopID()
        CImGui.Indent()
        if CImGui.BeginDragDropSource(0)
            @c CImGui.SetDragDropPayload("Swap DAQTask", &i, sizeof(Cint))
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Swap DAQTask")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                if i != payload_i
                    key_i = idxkey(insbuf.quantities, i)
                    key_payload_i = idxkey(insbuf.quantities, payload_i)
                    insbuf_i = insbuf.quantities[key_i]
                    insbuf.quantities[key_i] = insbuf.quantities[key_payload_i]
                    insbuf.quantities[key_payload_i] = insbuf_i
                end
            end
            CImGui.EndDragDropTarget()
        end
        CImGui.Unindent()
    end
    CImGui.EndChild()
    CImGui.PopID()
    CImGui.PopID()
end

edit(qt::InstrQuantity, instrnm::String, addr::String) = edit(qt, instrnm, addr, Val(qt.type))

let
    issweeping::Bool = false
    stbtsz::Float32 = 0
    testcb = "abcd"
    Us = []
    U = ""
    val::String = ""
    content::String = ""
    global sweeptask::Task
    global function edit(qt::InstrQuantity, instrnm::String, addr::String, ::Val{:sweep})
        # ftsz = CImGui.GetFontSize()
        # CImGui.Text(qt.alias)
        # if CImGui.IsItemHovered()
        #     CImGui.BeginTooltip()
        #     CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
        #     CImGui.TextUnformatted(qt.help)
        #     CImGui.PopTextWrapPos()
        #     CImGui.EndTooltip()
        # end
        # CImGui.SameLine(ftsz * (maxaliaslist[instrnm] / 3 + 0.5))
        # CImGui.Text("：")
        # CImGui.SameLine() ###alias
        Us = conf.U[qt.utype]
        U = isempty(Us) ? "" : Us[qt.uindex]
        U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
        # CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 2))
        # width::Float32 = Float32((CImGui.GetContentRegionAvailWidth() - 3ftsz - stbtsz) / 4)
        # CImGui.PushItemWidth(width)
        # @c InputTextWithHintRSZ("##步长", "步长", &qt.step)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()
        # CImGui.PushItemWidth(width)
        # @c InputTextWithHintRSZ("##终点", "终点", &qt.stop)
        # CImGui.PopItemWidth()
        # CImGui.SameLine()
        # CImGui.PushItemWidth(width)
        # @c CImGui.DragFloat("##delay", &qt.delay, 1.0, 0.05, 60)
        # CImGui.PopItemWidth()
        # CImGui.SameLine() ###步长、终点和延迟
        # valstr = qt.read
        val = U == "" ? qt.read : @trypass string(parse(Float64, qt.read) / Uchange) qt.read
        content = string(qt.alias, "\n步长：", qt.step, " ", U, "\n终点：", qt.stop, " ", U, "\n延迟：", qt.delay, " s\n", val, " ", U) |> centermultiline
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, qt.isautorefresh || issweeping ? morestyle.Colors.DAQTaskRunning : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Button))
        if CImGui.Button(content, (-1, 0))
            if issweeping
                issweeping = false
                wait(sweeptask)
            else
                addr == "" || lockstates(refresh_local, instrnm, addr, qt.name)
            end
        end
        CImGui.PopStyleColor()
        if conf.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            # CImGui.BeginTooltip()
            # CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
            # CImGui.TextUnformatted(qt.help)
            # CImGui.PopTextWrapPos()
            # CImGui.EndTooltip()
            # CImGui.SetTooltip(qt.help)
            ItemTooltip(qt.help)
        end
        # CImGui.IsItemHovered() && CImGui.OpenPopupOnItemClick("选项设置", 2)
        if CImGui.BeginPopupContextItem()
            @c InputTextWithHintRSZ("##步长", "步长", &qt.step)
            @c InputTextWithHintRSZ("##终点", "终点", &qt.stop)
            @c CImGui.DragFloat("##延迟", &qt.delay, 1.0, 0.05, 60, "%.3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
            if issweeping
                if CImGui.Button(" 结束 ", (-1, 0))
                    issweeping = false
                    # syncstates[Int(isdaqtask_running)] = false
                    # syncstates[Int(busy_acquiring)] = false
                    wait(sweeptask)
                end
            else
                if CImGui.Button(" 开始 ", (-1, 0))
                    if addr != ""
                        instr = instrument(instrnm, addr)
                        getfunc = Symbol(instrnm, :_, qt.name, :_get)
                        setfunc = Symbol(instrnm, :_, qt.name, :_set)
                        # syncstates[Int(isdaqtask_running)] = true
                        # syncstates[Int(busy_acquiring)] = true
                        global sweeptask = @async begin
                            lockstates() do
                                @trylink_do instr begin
                                    start = @trypasse parse(Float64, eval(:($getfunc($instr)))) @error "[$(now())]\nstart获取错误！！！" instrument = string(instrnm, "-", addr)
                                    step = @trypasse eval(Meta.parse(qt.step)) * Uchange @error "[$(now())]\nstep解析错误！！！" step = qt.step
                                    stop = @trypasse eval(Meta.parse(qt.stop)) * Uchange @error "[$(now())]\nstop解析错误！！！" stop = qt.stop
                                    issweeping = true
                                    sweepsteps = ceil(Int, abs((start - stop) / step))
                                    sweepsteps = sweepsteps == 1 ? 2 : sweepsteps
                                    for i in range(start, stop, length=sweepsteps)
                                        issweeping || break
                                        sleep(qt.delay)
                                        :($setfunc($instr, $i)) |> eval
                                        qt.read = :($getfunc($instr)) |> eval
                                    end
                                    issweeping = false
                                end (issweeping = false;
                                @error "[$(now())]\n仪器通信故障或参数设置错误！！！" instrument = string(instrnm, "-", addr))
                                @trylink_do instr (qt.read = :($getfunc($instr)) |> eval) nothing
                                # syncstates[Int(isdaqtask_running)] = false
                                # syncstates[Int(busy_acquiring)] = false
                            end
                        end
                        errormonitor(sweeptask)
                    end
                end
            end
            CImGui.Text("单位 ")
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c ShowUnit("##insbuf", qt.utype, &qt.uindex)
            CImGui.PopItemWidth()
            CImGui.SameLine(0, 2CImGui.GetFontSize())
            @c CImGui.Checkbox("刷新", &qt.isautorefresh)
            CImGui.EndPopup()
        end
        # CImGui.SameLine() ###实际值
        # CImGui.PushItemWidth(3ftsz)
        # @c ShowUnit("##insbuf", qt.utype, &qt.uindex)
        # CImGui.PopItemWidth()
        # CImGui.PopStyleVar()
        # CImGui.SameLine() ###单位
        # CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, 6)

        # stbtsz = CImGui.GetItemRectSize().x
        # CImGui.SameLine()
        # @c CImGui.Checkbox("##是否自动刷新", &qt.isautorefresh)
        # stbtsz += CImGui.GetItemRectSize().x + 2unsafe_load(imguistyle.ItemSpacing.x)
        # CImGui.PopStyleVar()
    end
end #let

let
    triggerset::Bool = false
    Us = []
    U = ""
    val::String = ""
    content::String = ""
    global function edit(qt::InstrQuantity, instrnm::String, addr::String, ::Val{:set})
        # ftsz = CImGui.GetFontSize()
        # CImGui.Text(qt.alias)

        # CImGui.SameLine(ftsz * (maxaliaslist[instrnm] / 3 + 0.5))
        # CImGui.Text("：")
        # CImGui.SameLine() ###alias
        Us = conf.U[qt.utype]
        U = isempty(Us) ? "" : Us[qt.uindex]
        U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
        # CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 2))
        # width::Float32 = Float32((CImGui.GetContentRegionAvailWidth() - 3ftsz - okbtsz) / 2)
        # CImGui.PushItemWidth(width)
        # @c InputTextWithHintRSZ("##设置", "设置值", &qt.set)
        # CImGui.PopItemWidth()
        # triggerset = false
        # if CImGui.BeginPopup("选择设置值")
        #     for (i, optv) in enumerate(qt.optvalues)
        #         optv == "" && (CImGui.TextColored(morestyle.Colors.HighlightText, "不可用的选项！"); continue)
        #         @c(CImGui.RadioButton(optv, &qt.optedvalueidx, i)) && (qt.set = optv; triggerset = true)
        #     end
        #     CImGui.EndPopup()
        # end
        # CImGui.OpenPopupOnItemClick("选择设置值", 2)
        # CImGui.SameLine() ###设置值
        # valstr = qt.read
        val = U == "" ? qt.read : @trypass string(parse(Float64, qt.read) / Uchange) qt.read
        content = string(qt.alias, "\n \n设置值：", qt.set, " ", U, "\n \n", val, " ", U) |> centermultiline
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, qt.isautorefresh ? morestyle.Colors.DAQTaskRunning : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Button))
        if CImGui.Button(content, (-1, 0))
            addr == "" || lockstates(refresh_local, instrnm, addr, qt.name)
        end
        CImGui.PopStyleColor()
        if conf.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            # CImGui.BeginTooltip()
            # CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
            # CImGui.TextUnformatted(qt.help)
            # CImGui.PopTextWrapPos()
            # CImGui.EndTooltip()
            # CImGui.SetTooltip(qt.help)
            ItemTooltip(qt.help)
        end
        # CImGui.IsItemHovered() && CImGui.OpenPopupOnItemClick("选项设置", 2)
        if CImGui.BeginPopupContextItem()
            @c InputTextWithHintRSZ("##设置", "设置值", &qt.set)
            if CImGui.Button(" 确认 ", (-1, 0)) || triggerset
                triggerset = false
                if addr != ""
                    sv::String = U == "" ? qt.set : @trypasse string(float(eval(Meta.parse(qt.set)) * Uchange)) svstr
                    triggerset && (sv = qt.optvalues[qt.optedvalueidx])
                    instr = instrument(instrnm, addr)
                    setfunc = Symbol(instrnm, :_, qt.name, :_set)
                    getfunc = Symbol(instrnm, :_, qt.name, :_get)
                    lockstates() do
                        @trylink_do instr (eval(:($setfunc($instr, $sv))); qt.read = eval(:($getfunc($instr)))) nothing
                    end
                end
            end
            # CImGui.BeginChild("alignoptvalues")
            # CImGui.Columns(2, C_NULL, false)
            for (i, optv) in enumerate(qt.optvalues)
                optv == "" && continue
                @c(CImGui.RadioButton(optv, &qt.optedvalueidx, i)) && (qt.set = optv; triggerset = true)
                # CImGui.NextColumn()
                i % 2 == 1 && CImGui.SameLine(0, 2CImGui.GetFontSize())
            end
            # CImGui.EndChild()
            CImGui.Text("单位 ")
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c ShowUnit("##insbuf", qt.utype, &qt.uindex)
            CImGui.PopItemWidth()
            CImGui.SameLine(0, 2CImGui.GetFontSize())
            @c CImGui.Checkbox("刷新", &qt.isautorefresh)
            CImGui.EndPopup()
        end
        # CImGui.SameLine() ###实际值
        # CImGui.PushItemWidth(3ftsz)
        # @c ShowUnit("##insbuf", qt.utype, &qt.uindex)
        # CImGui.PopItemWidth()
        # CImGui.PopStyleVar()
        # CImGui.SameLine() ###单位
        # CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, 6)

        # okbtsz = CImGui.GetItemRectSize().x
        # CImGui.SameLine()
        # @c CImGui.Checkbox("##是否自动刷新", &qt.isautorefresh)
        # okbtsz += CImGui.GetItemRectSize().x + 2unsafe_load(imguistyle.ItemSpacing.x)
        # CImGui.PopStyleVar()
    end
end

let
    refbtsz::Float32 = 0
    Us = []
    U = ""
    val::String = ""
    content::String = ""
    global function edit(qt::InstrQuantity, instrnm, addr, ::Val{:read})
        Us = conf.U[qt.utype]
        U = isempty(Us) ? "" : Us[qt.uindex]
        U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
        val = U == "" ? qt.read : @trypass string(parse(Float64, qt.read) / Uchange) qt.read
        content = string(qt.alias, "\n \n \n", val, " ", U, "\n ") |> centermultiline
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, qt.isautorefresh ? morestyle.Colors.DAQTaskRunning : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Button))
        if CImGui.Button(content, (-1, 0))
            addr == "" || lockstates(refresh_local, instrnm, addr, qt.name)
        end
        CImGui.PopStyleColor()
        if conf.InsBuf.showhelp && CImGui.IsItemHovered() && qt.help != ""
            # CImGui.BeginTooltip()
            # CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
            # CImGui.TextUnformatted(qt.help)
            # CImGui.PopTextWrapPos()
            # CImGui.EndTooltip()
            # CImGui.SetTooltip(qt.help)
            ItemTooltip(qt.help)
        end
        # CImGui.IsItemHovered() && CImGui.OpenPopupOnItemClick("选项设置", 2)
        if CImGui.BeginPopupContextItem()
            CImGui.Text("单位 ")
            CImGui.SameLine()
            CImGui.PushItemWidth(6CImGui.GetFontSize())
            @c ShowUnit("##insbuf", qt.utype, &qt.uindex)
            CImGui.PopItemWidth()
            CImGui.SameLine(0, 2CImGui.GetFontSize())
            @c CImGui.Checkbox("刷新", &qt.isautorefresh)
            CImGui.EndPopup()
        end
        # CImGui.SameLine() ###实际值
        # CImGui.PushItemWidth(3ftsz)
        # @c ShowUnit("##insbuf", qt.utype, &qt.uindex)
        # CImGui.PopItemWidth()
        # CImGui.PopStyleVar()
        # CImGui.SameLine() ###单位
        # CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding, 6)
        # if CImGui.Button(" 刷新 ")
        #     addr == "" || lockstates(refresh_local, instrnm, addr, qt.name)
        # end
        # refbtsz = CImGui.GetItemRectSize().x
        # CImGui.SameLine()
        # @c CImGui.Checkbox("##是否自动刷新", &qt.isautorefresh)
        # refbtsz += CImGui.GetItemRectSize().x + 2unsafe_load(imguistyle.ItemSpacing.x)
        # CImGui.PopStyleVar()
    end
end

function view(instrbuffer_local)
    for ins in keys(instrbuffer_local)
        ins == "Others" && continue
        for addr in keys(instrbuffer_local[ins])
            CImGui.TextColored(morestyle.Colors.HighlightText, string(ins, "：", addr))
            insbuf = instrbuffer_local[ins][addr]
            CImGui.PushID(addr)
            view(insbuf)
            CImGui.PopID()
        end
    end
end

function view(insbuf::InstrBuffer)
    y = ceil(Int, length(insbuf.quantities) / conf.InsBuf.showcol) * 2CImGui.GetFrameHeight()
    CImGui.BeginChild("view insbuf", (Float32(0), y))
    CImGui.Columns(conf.InsBuf.showcol, C_NULL, false)
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

let
    Us = []
    U = ""
    val::String = ""
    content::String = ""
    global function view(qt::InstrQuantity)
        # ftsz = CImGui.GetFontSize()
        # CImGui.Text(qt.alias)
        # CImGui.SameLine(ftsz * (max(values(maxaliaslist)...) / 3 + 0.5))
        # CImGui.Text("：")
        # CImGui.SameLine() ###alias
        Us = conf.U[qt.utype]
        U = isempty(Us) ? "" : Us[qt.uindex]
        U == "" || (Uchange::Float64 = Us[1] isa Unitful.FreeUnits ? ustrip(Us[1], 1U) : 1.0)
        # CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (0, 2))
        val = U == "" ? qt.read : @trypass string(parse(Float64, qt.read) / Uchange) qt.read
        content = string(qt.alias, "\n", val, " ", U) |> centermultiline
        if CImGui.Button(content, (-1, 0))
            qt.uindex = (qt.uindex + 1) % length(Us)
            qt.uindex == 0 && (qt.uindex = length(Us))
        end
        # CImGui.SameLine() ###实际值
        # CImGui.PushItemWidth(3ftsz)
        # @c ShowUnit("##insbuf", qt.utype, &qt.uindex)
        # CImGui.PopItemWidth()
        # CImGui.PopStyleVar()
    end
end

function refresh_remote(instrbuffer_rc, instrbuffer; log=false)
    @sync for ins in keys(instrbuffer)
        ins == "Others" && continue
        for addr in keys(instrbuffer[ins])
            @async begin
                insbuf = instrbuffer[ins][addr]
                if insbuf.isautorefresh || log
                    instr = instrument(ins, addr)
                    @trylink_do instr begin
                        query(instr, "*IDN?")
                        dtbuf = []
                        for qt in keys(insbuf.quantities)
                            if insbuf.quantities[qt].isautorefresh || log
                                getfunc = Symbol(ins, :_, qt, :_get)
                                val = :($getfunc($instr)) |> eval
                                push!(dtbuf, (ins, addr, qt, val))
                            end
                        end
                        put!(instrbuffer_rc, deepcopy(dtbuf))
                    end nothing
                    yield()
                end
            end
        end
    end
end

function refresh_local(instrbuffer_rc)
    if isready(instrbuffer_rc)
        packdata = take!(instrbuffer_rc)
        for data in packdata
            ins, addr, qt, val = data
            insbuf = instrbuffer[ins][addr]
            insbuf.quantities[qt].read = val
        end
    end
end

function refresh_local(instrnm, addr, quantity)
    instr = instrument(instrnm, addr)
    insbuf = @trypass instrbuffer[instrnm][addr] (@error "[$(now())]\n仪器不存在!!!" instrument = instrnm;
    return)
    getfunc = Symbol(instrnm, :_, quantity, :_get)
    @trylink_do instr (insbuf.quantities[quantity].read = eval(:($getfunc($instr)))) nothing
end

function lockstates(f, args...; syncstates=syncstates, kwargs...)
    if !syncstates[Int(busy_acquiring)]
        syncstates[Int(busy_acquiring)] = true
        if syncstates[Int(isdaqtask_running)]
            if syncstates[Int(isblock)]
                starttime = time()
                while time() - starttime < 60
                    syncstates[Int(isblocking)] && (f(args...; kwargs...); break)
                    yield()
                end
            else
                syncstates[Int(isblock)] = true
                starttime = time()
                while time() - starttime < 60
                    syncstates[Int(isblocking)] && (f(args...; kwargs...); break)
                    yield()
                end
                syncstates[Int(isblock)] = false
                remote_do(workers()[1]) do
                    lock(() -> notify(block), block)
                end
            end
        else
            f(args...; kwargs...)
        end
        syncstates[Int(busy_acquiring)] = false
    end
    nothing
end

function autorefresh()
    errormonitor(@async while true
        i_sleep = 0
        while i_sleep < refreshrate
            sleep(0.1)
            i_sleep += 0.1
        end
        if syncstates[Int(isautorefresh)]
            remotecall_wait(workers()[1], instrbuffer_rc, instrbuffer, syncstates) do instrbuffer_rc, instrbuffer, syncstates
                lockstates(refresh_remote, instrbuffer_rc, instrbuffer; syncstates=syncstates)
            end
        end
    end)
    errormonitor(@async while true
        refresh_local(instrbuffer_rc)
        yield()
    end)
end

###仅在运行时使用
function log_instrbuffer(instrbuffer_rc)
    refresh_remote(instrbuffer_rc, instrbuffer, log=true)
    wait(@async while isready(instrbuffer_rc)
        yield()
    end)
    push!(cfgbuf, "instrbuffer/[$(now())]" => instrbuffer)
end

