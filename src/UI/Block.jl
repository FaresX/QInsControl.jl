abstract type AbstractBlock end

struct NullBlock <: AbstractBlock end
skipnull(bkch::Vector{AbstractBlock}) = findall(bk -> !isa(bk, NullBlock), bkch)

mutable struct CodeBlock <: AbstractBlock
    codes::String
    region::Vector{Float32}
end
CodeBlock() = CodeBlock("", zeros(4))

mutable struct StrideCodeBlock <: AbstractBlock
    head::String
    level::Int
    blocks::Vector{AbstractBlock}
    region::Vector{Float32}
end
StrideCodeBlock(level) = StrideCodeBlock("", level, Vector{AbstractBlock}(), zeros(4))
StrideCodeBlock() = StrideCodeBlock(1)

mutable struct SweepBlock <: AbstractBlock
    instrnm::String
    addr::String
    quantity::String
    step::String
    stop::String
    level::Int
    blocks::Vector{AbstractBlock}
    ui::Int
    delay::Cfloat
    region::Vector{Float32}
end
SweepBlock(level) = SweepBlock("仪器", "地址", "扫描量", "", "", level, Vector{AbstractBlock}(), 1, 0.1, zeros(4))
SweepBlock() = SweepBlock(1)

mutable struct SettingBlock <: AbstractBlock
    instrnm::String
    addr::String
    quantity::String
    setvalue::String
    ui::Int
    region::Vector{Float32}
end
SettingBlock() = SettingBlock("仪器", "地址", "设置", "", 1, zeros(4))

mutable struct ReadingBlock <: AbstractBlock
    instrnm::String
    mark::String
    addr::String
    quantity::String
    index::String
    isasync::Bool
    isobserve::Bool
    isreading::Bool
    region::Vector{Float32}
end
ReadingBlock() = ReadingBlock("仪器", "", "地址", "读取量", "", false, false, false, zeros(4))

mutable struct LogBlock <: AbstractBlock
    region::Vector{Float32}
end
LogBlock() = LogBlock(zeros(4))

mutable struct WriteBlock <: AbstractBlock
    instrnm::String
    addr::String
    cmd::String
    isasync::Bool
    region::Vector{Float32}
end
WriteBlock() = WriteBlock("仪器", "地址", "", false, zeros(4))

mutable struct QueryBlock <: AbstractBlock
    instrnm::String
    mark::String
    addr::String
    cmd::String
    index::String
    isasync::Bool
    isobserve::Bool
    isreading::Bool
    region::Vector{Float32}
end
QueryBlock() = QueryBlock("仪器", "", "地址", "", "", false, false, false, zeros(4))

mutable struct ReadBlock <: AbstractBlock
    instrnm::String
    mark::String
    addr::String
    index::String
    isasync::Bool
    isobserve::Bool
    isreading::Bool
    region::Vector{Float32}
end
ReadBlock() = ReadBlock("仪器", "", "地址", "", false, false, false, zeros(4))

############tocodes-------------------------------------------------------------------------------------------------------

tocodes(::NullBlock) = nothing

function tocodes(bk::CodeBlock)
    ex = @trypass Meta.parseall(bk.codes) (@error "[$(now())]\ncodes are wrong in parsing time (CodeBlock)!!!" bk = bk; return)
    ex isa Expr && ex.head == :toplevel && (ex.head = :block)
    ex
end

function tocodes(bk::StrideCodeBlock)
    innercodes = tocodes.(bk.blocks)
    headcodes = bk.head
    isasync = false
    for bk in bk.blocks
        typeof(bk) in [ReadingBlock, WriteBlock, QueryBlock, ReadBlock] && bk.isasync && (isasync = true; break)
    end
    interpcodes = isasync ? quote
        @sync begin
            $(innercodes...)
        end
    end : quote
        $(innercodes...)
    end
    interpall = quote
        if syncstates[Int(isblock)]
            @warn "[$(now())]\n暂停！" StrideCodeBlock = $headcodes
            lock(() -> wait(block), block)
            @info "[$(now())]\n继续！" StrideCodeBlock = $headcodes
        end
        if syncstates[Int(isinterrupt)]
            @warn "[$(now())]\n中断！" StrideCodeBlock = $headcodes
            return
        end
        $interpcodes
    end
    codestr = string(headcodes, " ", interpall, " end")
    @trypasse Meta.parse(codestr) (@error "[$(now())]\ncodes are wrong in parsing time (StrideCodeBlock)!!!" bk = bk)
end

function tocodes(bk::SweepBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    quantity = bk.quantity
    setfunc = Symbol(bk.instrnm, :_, bk.quantity, :_set)
    getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get)
    Ut = insconf[bk.instrnm].quantities[quantity].U
    Us = conf.U[Ut]
    U = Us[bk.ui]
    U == "" && (@error "[$(now())]\n输入数据有误！！！" bk = bk;
    return)
    stepc = @trypass Meta.parse(bk.step) (@error "[$(now())]\ncodes are wrong in parsing time (SweepBlock)!!!" bk = bk; return)
    stopc = @trypass Meta.parse(bk.stop) (@error "[$(now())]\ncodes are wrong in parsing time (SweepBlock)!!!" bk = bk; return)
    start = :(parse(Float64, $getfunc(instrs[$instr])))
    Uchange = U isa Unitful.MixedUnits ? 1 : ustrip(Us[1], 1U)
    step = Expr(:call, :*, stepc, Uchange)
    stop = Expr(:call, :*, stopc, Uchange)
    innercodes = tocodes.(bk.blocks)
    isasync = false
    for bk in bk.blocks
        typeof(bk) in [ReadingBlock, WriteBlock, QueryBlock, ReadBlock] && bk.isasync && (isasync = true; break)
    end
    interpcodes = isasync ? quote
        @sync begin
            $(innercodes...)
        end
    end : quote
        $(innercodes...)
    end
    @gensym ijk
    @gensym sweepsteps
    return quote
        $sweepsteps = ceil(Int, abs(($start - $stop) / $step))
        $sweepsteps = $sweepsteps == 1 ? 2 : $sweepsteps
        @progress for $ijk in range($start, $stop, length=$sweepsteps)
            if syncstates[Int(isblock)]
                @warn "[$(now())]\n暂停！" SweepBlock = $instr
                lock(() -> wait(block), block)
                @info "[$(now())]\n继续！" SweepBlock = $instr
            end
            if syncstates[Int(isinterrupt)]
                @warn "[$(now())]\n中断！" SweepBlock = $instr
                return
            end
            sleep($(bk.delay))
            controllers[$instr]($setfunc, CPU, string($ijk), Val(:write))
            $interpcodes
        end
    end
end

function tocodes(bk::SettingBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    quantity = bk.quantity
    Ut = insconf[bk.instrnm].quantities[quantity].U
    Us = conf.U[Ut]
    U = Us[bk.ui]
    if U == ""
        setvalue = parsedollar(bk.setvalue)
    else
        setvaluec = @trypass Meta.parse(bk.setvalue) (@error "[$(now())]\ncodes are wrong in parsing time (SettingBlock)!!!" bk = bk; return)
        Uchange = U isa Unitful.MixedUnits ? 1 : ustrip(Us[1], 1U)
        setvalue = Expr(:call, float, Expr(:call, :*, setvaluec, Uchange))
    end
    setfunc = Symbol(bk.instrnm, :_, bk.quantity, :_set)
    return :(controllers[$instr]($setfunc, CPU, string($setvalue), Val(:write)))
end

function tocodes(bk::ReadingBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get)
    index = @trypasse eval(Meta.parse(bk.index)) (@error "[$(now())]\ncodes are wrong in parsing time (ReadingBlock)!!!" bk = bk; return)
    if isnothing(index)
        key = string(bk.mark, "_", bk.instrnm, "_", bk.quantity, "_", bk.addr)
        getdata = :(controllers[$instr]($getfunc, CPU, Val(:read)))
        ex = if bk.isobserve
            observable = Symbol(bk.mark)
            bk.isreading ? quote
                $observable = $getdata
                put!(databuf_lc, ($key, $observable))
            end : :($observable = $getdata)
        else
            :(put!(databuf_lc, ($key, $getdata)))
        end
        return bk.isasync ? quote
            @async begin
                $ex
            end
        end : ex
    else
        marks = fill("", length(index))
        for (i, v) in enumerate(split(bk.mark, ","))
            marks[i] = v
        end
        for i in index
            marks[i] == "" && (marks[i] = "mark$i")
        end
        keyall = [string(mark, "_", bk.instrnm, "_", bk.quantity, "[", ind, "]", "_", bk.addr) for (mark, ind) in zip(marks, index)]
        getdata = :(string.(split(controllers[$instr]($getfunc, CPU, Val(:read)), ",")[collect($index)]))
        ex = if bk.isobserve
            observable = Symbol(bk.mark)
            bk.isreading ? quote
                $observable = $getdata
                for data in zip($keyall, $observable)
                    put!(databuf_lc, data)
                end
            end : :($observable = $getdata)
        else
            quote
                for data in zip($keyall, $getdata)
                    put!(databuf_lc, data)
                end
            end
        end
        return bk.isasync ? quote
            @async begin
                $ex
            end
        end : ex
    end
end

tocodes(::LogBlock) = :(remotecall_wait(eval, 1, :(log_instrbufferviewers())))

function tocodes(bk::WriteBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    cmd = parsedollar(bk.cmd)
    ex = :(controllers[$instr](write, CPU, string($cmd), Val(:write)))
    return bk.isasync ? quote
        @async begin
            $ex
        end
    end : ex
end

function tocodes(bk::QueryBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    index = @trypasse eval(Meta.parse(bk.index)) (@error "[$(now())]\ncodes are wrong in parsing time (QueryBlock)!!!" bk = bk; return)
    cmd = parsedollar(bk.cmd)
    if isnothing(index)
        key = string(bk.mark, "_", bk.instrnm, "_", bk.addr)
        getdata = :(controllers[$instr](query, CPU, string($cmd), Val(:query)))
        ex = if bk.isobserve
            observable = Symbol(bk.mark)
            bk.isreading ? quote
                $observable = $getdata
                put!(databuf_lc, ($key, $observable))
            end : :($observable = $getdata)
        else
            :(put!(databuf_lc, ($key, $getdata)))
        end
        return bk.isasync ? quote
            @async begin
                $ex
            end
        end : ex
    else
        marks = fill("", length(index))
        for (i, v) in enumerate(split(bk.mark, ","))
            marks[i] = v
        end
        for i in index
            marks[i] == "" && (marks[i] = "mark$i")
        end
        keyall = [string(mark, "_", bk.instrnm, "[", ind, "]", "_", bk.addr) for (mark, ind) in zip(marks, index)]
        getdata = :(string.(split(controllers[$instr](query, CPU, $cmd, Val(:query)), ",")[collect($index)]))
        ex = if bk.isobserve
            observable = Symbol(bk.mark)
            bk.isreading ? quote
                $observable = $getdata
                for data in zip($keyall, $observable)
                    put!(databuf_lc, data)
                end
            end : :($observable = $getdata)
        else
            quote
                for data in zip($keyall, $getdata)
                    put!(databuf_lc, data)
                end
            end
        end
        return bk.isasync ? quote
            @async begin
                $ex
            end
        end : ex
    end
end

function tocodes(bk::ReadBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    index = @trypasse eval(Meta.parse(bk.index)) (@error "[$(now())]\ncodes are wrong in parsing time (ReadBlock)!!!" bk = bk; return)
    if isnothing(index)
        key = string(bk.mark, "_", bk.instrnm, "_", bk.addr)
        getdata = :(controllers[$instr](read, CPU, Val(:read)))
        ex = if bk.isobserve
            observable = Symbol(bk.mark)
            bk.isreading ? quote
                $observable = $getdata
                put!(databuf_lc, ($key, $observable))
            end : :($observable = $getdata)
        else
            :(put!(databuf_lc, ($key, $getdata)))
        end
        return bk.isasync ? quote
            @async begin
                $ex
            end
        end : ex
    else
        marks = fill("", length(index))
        for (i, v) in enumerate(split(bk.mark, ","))
            marks[i] = v
        end
        for i in index
            marks[i] == "" && (marks[i] = "mark$i")
        end
        keyall = [string(mark, "_", bk.instrnm, "[", ind, "]", "_", bk.addr) for (mark, ind) in zip(marks, index)]
        getdata = :(string.(split(controllers[$instr](read, CPU, Val(:read)), ",")[collect($index)]))
        ex = if bk.isobserve
            observable = Symbol(bk.mark)
            bk.isreading ? quote
                $observable = $getdata
                for data in zip($keyall, $observable)
                    put!(databuf_lc, data)
                end
            end : :($observable = $getdata)
        else
            quote
                for data in zip($keyall, $getdata)
                    put!(databuf_lc, data)
                end
            end
        end
        return bk.isasync ? quote
            @async begin
                $ex
            end
        end : ex
    end
end

############bkheight-------------------------------------------------------------------------------------------------------

bkheight(::NullBlock) = zero(Float32)
bkheight(bk::CodeBlock) = (1 + length(findall("\n", bk.codes))) * CImGui.GetTextLineHeight() + 2unsafe_load(imguistyle.FramePadding.y) + 2unsafe_load(imguistyle.WindowPadding.y) + 1
bkheight(bk::StrideCodeBlock) = 2unsafe_load(imguistyle.WindowPadding.y) + CImGui.GetFrameHeight() + length(skipnull(bk.blocks)) * unsafe_load(imguistyle.ItemSpacing.y) + sum(bkheight.(bk.blocks))
bkheight(bk::SweepBlock) = 2unsafe_load(imguistyle.WindowPadding.y) + CImGui.GetFrameHeight() + length(skipnull(bk.blocks)) * unsafe_load(imguistyle.ItemSpacing.y) + sum(bkheight.(bk.blocks))
bkheight(bk) = 2unsafe_load(imguistyle.WindowPadding.y) + CImGui.GetFrameHeight()

############edit-------------------------------------------------------------------------------------------------------

function edit(bk::CodeBlock)
    CImGui.BeginChild("##CodeBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.CodeBlock)
    CImGui.SameLine()
    @c InputTextMultilineRSZ("##CodeBlock", &bk.codes, (-1, -1))
    CImGui.EndChild()
end

function edit(bk::StrideCodeBlock)
    bdc = isempty(skipnull(bk.blocks)) ? CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border) : ImVec4(morestyle.Colors.StrideCodeBlockBorder...)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##StrideBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.StrideCodeBlock)
    CImGui.SameLine()
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##代码块头", "代码块头", &bk.head)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor()
    isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
    CImGui.EndChild()
end

function edit(bk::SweepBlock)
    bdc = isempty(skipnull(bk.blocks)) ? CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border) : ImVec4(morestyle.Colors.SweepBlockBorder...)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(imguistyle.ItemSpacing.y)))
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##SweepBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.SweepBlock)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##SweepBlock仪器", &bk.instrnm, keys(insconf), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    inlist = haskey(instrbufferviewers, bk.instrnm) && haskey(instrbufferviewers[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : "地址"
    addrlist = haskey(instrbufferviewers, bk.instrnm) ? keys(instrbufferviewers[bk.instrnm]) : String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##SweepBlock地址", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    showqt = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].alias
    else
        "扫描"
    end
    CImGui.PushItemWidth(width)
    if CImGui.BeginCombo("##SweepBlock设置", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
        qtlist = haskey(insconf, bk.instrnm) ? keys(insconf[bk.instrnm].quantities) : Set{String}()
        qts = if haskey(insconf, bk.instrnm)
            [qt for qt in qtlist if insconf[bk.instrnm].quantities[qt].type == "sweep" && insconf[bk.instrnm].quantities[qt].enable]
        else
            String[]
        end
        for qt in qts
            selected = bk.quantity == qt
            showqt = insconf[bk.instrnm].quantities[qt].alias
            CImGui.Selectable(showqt, selected, 0) && (bk.quantity = qt)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    CImGui.PopItemWidth()
    CImGui.SameLine()

    CImGui.PushItemWidth(width * 3 / 4)
    @c InputTextWithHintRSZ("##SweepBlock步长", "步长", &bk.step)
    CImGui.PopItemWidth()
    CImGui.SameLine()
    CImGui.PushItemWidth(width * 3 / 4)
    @c InputTextWithHintRSZ("##SweepBlock终点", "终点", &bk.stop)
    CImGui.PopItemWidth()
    CImGui.SameLine()
    CImGui.PushItemWidth(width / 2)
    @c CImGui.DragFloat("##SweepBlock停顿", &bk.delay, 0.01, 0, 9.99, "%.2f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    Ut = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    CImGui.PushItemWidth(-1)
    @c ShowUnit("##SweepBlock", Ut, &bk.ui)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor()
    isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function edit(bk::SettingBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(imguistyle.ItemSpacing.y)))
    CImGui.BeginChild("##SettingBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.SettingBlock)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##SettingBlock仪器", &bk.instrnm, keys(insconf), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    inlist = haskey(instrbufferviewers, bk.instrnm) && haskey(instrbufferviewers[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : "地址"
    addrlist = haskey(instrbufferviewers, bk.instrnm) ? keys(instrbufferviewers[bk.instrnm]) : String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##SettingBlock地址", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    showqt = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].alias
    else
        "设置"
    end
    CImGui.PushItemWidth(width)
    if CImGui.BeginCombo("##SettingBlock设置", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
        qtlist = haskey(insconf, bk.instrnm) ? keys(insconf[bk.instrnm].quantities) : Set{String}()
        sts = if haskey(insconf, bk.instrnm)
            [qt for qt in qtlist if insconf[bk.instrnm].quantities[qt].type in ["set", "sweep"] && insconf[bk.instrnm].quantities[qt].enable]
        else
            String[]
        end
        for st in sts
            selected = bk.quantity == st
            showst = insconf[bk.instrnm].quantities[st].alias
            CImGui.Selectable(showst, selected, 0) && (bk.quantity = st)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    CImGui.PopItemWidth()

    CImGui.SameLine()
    CImGui.PushItemWidth(2width)
    @c InputTextWithHintRSZ("##SettingBlock设置值", "设置值", &bk.setvalue)
    CImGui.PopItemWidth()
    if CImGui.BeginPopup("选择设置值")
        optvlist = @trypass insconf[bk.instrnm].quantities[bk.quantity].optvalues [""]
        for optv in optvlist
            optv == "" && (CImGui.TextColored(morestyle.Colors.HighlightText, "不可用的选项！");
            continue)
            CImGui.MenuItem(optv) && (bk.setvalue = optv)
        end
        CImGui.EndPopup()
    end
    CImGui.OpenPopupOnItemClick("选择设置值", 2)

    CImGui.SameLine()
    Ut = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    CImGui.PushItemWidth(-1)
    @c ShowUnit("SettingBlock", Ut, &bk.ui)
    CImGui.PopItemWidth()
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function edit(bk::ReadingBlock)
    bdc = bk.isasync ? ImVec4(morestyle.Colors.BlockAsyncBorder...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(imguistyle.ItemSpacing.y)))
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##ReadingBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.ReadingBlock)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##ReadingBlock仪器", &bk.instrnm, keys(insconf), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    inlist = haskey(instrbufferviewers, bk.instrnm) && haskey(instrbufferviewers[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : "地址"
    addrlist = @trypass keys(instrbufferviewers[bk.instrnm]) String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##ReadingBlock地址", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    showqt = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].alias
    else
        "读取"
    end
    CImGui.PushItemWidth(width)
    if CImGui.BeginCombo("##ReadingBlock设置", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
        qtlist = haskey(insconf, bk.instrnm) ? keys(insconf[bk.instrnm].quantities) : Set{String}()
        qts = @trypass [qt for qt in qtlist if insconf[bk.instrnm].quantities[qt].enable] String[]
        for qt in qts
            selected = bk.quantity == qt
            showqt = insconf[bk.instrnm].quantities[qt].alias
            CImGui.Selectable(showqt, selected, 0) && (bk.quantity = qt)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    CImGui.PopItemWidth()
    CImGui.SameLine()

    CImGui.PushItemWidth(width * 2 / 3)
    @c InputTextWithHintRSZ("##ReadingBlock索引", "索引", &bk.index)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    markc = bk.isobserve ? ImVec4(morestyle.Colors.BlockObserveBG...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_FrameBg)
    bk.isobserve && bk.isreading && (markc = ImVec4(morestyle.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##ReadingBlock", "标注", &bk.mark)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor()
    CImGui.SameLine()

    CImGui.EndChild()
    CImGui.IsItemClicked(0) && (bk.isasync ⊻= true)
    if CImGui.IsItemClicked(2)
        if bk.isobserve
            bk.isreading ? (bk.isobserve = false; bk.isreading = false) : (bk.isreading = true)
        else
            bk.isobserve = true
        end
    end
    CImGui.PopStyleColor()
    CImGui.PopStyleVar()
end

function edit(logbk::LogBlock)
    CImGui.BeginChild("##LogBlock", (Float32(0), bkheight(logbk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.LogBlock)
    CImGui.SameLine()
    CImGui.Button("LogBlock##", (-1, 0))
    CImGui.EndChild()
end

function edit(bk::WriteBlock)
    bdc = bk.isasync ? ImVec4(morestyle.Colors.BlockAsyncBorder...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(imguistyle.ItemSpacing.y)))
    CImGui.BeginChild("##WriteBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.WriteBlock)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##WriteBlock仪器", &bk.instrnm, keys(insconf), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(instrbufferviewers, bk.instrnm) && haskey(instrbufferviewers[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : "地址"
    addrlist = @trypass keys(instrbufferviewers[bk.instrnm]) String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##WriteBlock地址", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选地址

    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##WriteBlock CMD", "命令", &bk.cmd)
    CImGui.PopItemWidth() #命令

    CImGui.EndChild()
    CImGui.IsItemClicked(0) && (bk.isasync ⊻= true)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end

function edit(bk::QueryBlock)
    bdc = bk.isasync ? ImVec4(morestyle.Colors.BlockAsyncBorder...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(imguistyle.ItemSpacing.y)))
    CImGui.BeginChild("##QueryBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.QueryBlock)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##QueryBlock仪器", &bk.instrnm, keys(insconf), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(instrbufferviewers, bk.instrnm) && haskey(instrbufferviewers[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : "地址"
    addrlist = @trypass keys(instrbufferviewers[bk.instrnm]) String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##QueryBlock地址", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选地址WriteBlock

    CImGui.PushItemWidth(width * 4 / 3)
    @c InputTextWithHintRSZ("##QueryBlock CMD", "命令", &bk.cmd)
    CImGui.PopItemWidth()
    CImGui.SameLine() #命令

    CImGui.PushItemWidth(width * 2 / 3)
    @c InputTextWithHintRSZ("##QueryBlock索引", "索引", &bk.index)
    CImGui.PopItemWidth()
    CImGui.SameLine() #索引

    markc = bk.isobserve ? ImVec4(morestyle.Colors.BlockObserveBG...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_FrameBg)
    bk.isobserve && bk.isreading && (markc = ImVec4(morestyle.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##QueryBlock Mark", "标注", &bk.mark)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor() #标注

    CImGui.EndChild()
    CImGui.IsItemClicked(0) && (bk.isasync ⊻= true)
    if CImGui.IsItemClicked(2)
        if bk.isobserve
            bk.isreading ? (bk.isobserve = false; bk.isreading = false) : (bk.isreading = true)
        else
            bk.isobserve = true
        end
    end
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end

function edit(bk::ReadBlock)
    bdc = bk.isasync ? ImVec4(morestyle.Colors.BlockAsyncBorder...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(imguistyle.ItemSpacing.y)))
    CImGui.BeginChild("##ReadBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(morestyle.Colors.BlockIcons, morestyle.Icons.ReadBlock)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##ReadBlock仪器", &bk.instrnm, keys(insconf), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(instrbufferviewers, bk.instrnm) && haskey(instrbufferviewers[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : "地址"
    addrlist = haskey(instrbufferviewers, bk.instrnm) ? keys(instrbufferviewers[bk.instrnm]) : String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##ReadBlock地址", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选地址

    CImGui.PushItemWidth(width * 2 / 3)
    @c InputTextWithHintRSZ("##ReadBlock索引", "索引", &bk.index)
    CImGui.PopItemWidth()
    CImGui.SameLine() #索引

    markc = bk.isobserve ? ImVec4(morestyle.Colors.BlockObserveBG...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_FrameBg)
    bk.isobserve && bk.isreading && (markc = ImVec4(morestyle.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##ReadBlock Mark", "标注", &bk.mark)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor() #标注

    CImGui.EndChild()
    CImGui.IsItemClicked(0) && (bk.isasync ⊻= true)
    if CImGui.IsItemClicked(2)
        if bk.isobserve
            bk.isreading ? (bk.isobserve = false; bk.isreading = false) : (bk.isreading = true)
        else
            bk.isobserve = true
        end
    end
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end

mousein(bk::AbstractBlock, total=false)::Bool = total ? mousein(bk.region) || (typeof(bk) in [SweepBlock, StrideCodeBlock] && true in mousein.(bk.blocks, true)) : mousein(bk.region)
mousein(::NullBlock, total=false) = false

let
    isdragging::Bool = false
    dragblock = AbstractBlock[]
    dropblock = AbstractBlock[]
    global function edit(blocks::Vector{AbstractBlock}, n::Int)
        for (i, bk) in enumerate(blocks)
            bk isa NullBlock && continue
            if isdragging && mousein(bk)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Separator, morestyle.Colors.HighlightText)
                draw_list = CImGui.GetWindowDrawList()
                rectcolor = CImGui.ColorConvertFloat4ToU32([morestyle.Colors.HighlightText[1:3]; 0.4])
                CImGui.AddRectFilled(draw_list, CImGui.ImVec2(bk.region[1:2]...), CImGui.ImVec2(bk.region[3:4]...), rectcolor, 0.0, 0)
                CImGui.PopStyleColor()
            end
            CImGui.PushID(i)
            edit(bk)
            id = string(CImGui.igGetItemID())
            if typeof(bk) in [SweepBlock, StrideCodeBlock]
                rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
                wp = unsafe_load(imguistyle.WindowPadding.y)
                extraheight = isempty(bk.blocks) ? wp : unsafe_load(imguistyle.ItemSpacing.y) ÷ 2
                bk.region = [rmin.x, rmin.y, rmax.x, rmin.y + wp + CImGui.GetFrameHeight() + extraheight]
            else
                rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
                bk.region = [rmin.x, rmin.y, rmax.x, rmax.y]
            end
            CImGui.PopID()
            if CImGui.IsMouseDown(0)
                io = CImGui.GetIO()
                if CImGui.c_get(io.MouseDownDuration, 0) > 0.1 && !isdragging && mousein(bk)
                    bk in dragblock || length(dragblock) == 1 || push!(dragblock, bk)
                    isdragging = true
                end
            else
                if isdragging && mousein(bk)
                    bk in dropblock || length(dropblock) == 1 || push!(dropblock, bk)
                    isdragging = false
                end
            end
            mousein(bk) && CImGui.OpenPopupOnItemClick(id, 1)
            if CImGui.BeginPopup(id)
                if CImGui.BeginMenu(morestyle.Icons.InsertUp * " 在上方插入")
                    CImGui.MenuItem(morestyle.Icons.CodeBlock * " CodeBlock") && insert!(blocks, i, CodeBlock())
                    CImGui.MenuItem(morestyle.Icons.StrideCodeBlock * " StrideCodeBlock") && insert!(blocks, i, StrideCodeBlock(n))
                    CImGui.MenuItem(morestyle.Icons.SettingBlock * " SettingBlock") && insert!(blocks, i, SettingBlock())
                    CImGui.MenuItem(morestyle.Icons.SweepBlock * " SweepBlock") && insert!(blocks, i, SweepBlock(n))
                    CImGui.MenuItem(morestyle.Icons.ReadingBlock * " ReadingBlock") && insert!(blocks, i, ReadingBlock())
                    CImGui.MenuItem(morestyle.Icons.LogBlock * " LogBlock") && insert!(blocks, i, LogBlock())
                    CImGui.MenuItem(morestyle.Icons.WriteBlock * " WriteBlock") && insert!(blocks, i, WriteBlock())
                    CImGui.MenuItem(morestyle.Icons.QueryBlock * " QueryBlock") && insert!(blocks, i, QueryBlock())
                    CImGui.MenuItem(morestyle.Icons.ReadBlock * " ReadBlock") && insert!(blocks, i, ReadBlock())
                    CImGui.EndMenu()
                end
                if (bk isa StrideCodeBlock || bk isa SweepBlock) && isempty(skipnull(bk.blocks))
                    if CImGui.BeginMenu(morestyle.Icons.InsertInside * " 在内部插入", bk.level < 6)
                        CImGui.MenuItem(morestyle.Icons.CodeBlock * " CodeBlock") && push!(bk.blocks, CodeBlock())
                        CImGui.MenuItem(morestyle.Icons.StrideCodeBlock * " StrideCodeBlock") && push!(bk.blocks, StrideCodeBlock(n + 1))
                        CImGui.MenuItem(morestyle.Icons.SettingBlock * " SettingBlock") && push!(bk.blocks, SettingBlock())
                        CImGui.MenuItem(morestyle.Icons.SweepBlock * " SweepBlock") && push!(bk.blocks, SweepBlock(n + 1))
                        CImGui.MenuItem(morestyle.Icons.ReadingBlock * " ReadingBlock") && push!(bk.blocks, ReadingBlock())
                        CImGui.MenuItem(morestyle.Icons.LogBlock * " LogBlock") && push!(bk.blocks, LogBlock())
                        CImGui.MenuItem(morestyle.Icons.WriteBlock * " WriteBlock") && push!(bk.blocks, WriteBlock())
                        CImGui.MenuItem(morestyle.Icons.QueryBlock * " QueryBlock") && push!(bk.blocks, QueryBlock())
                        CImGui.MenuItem(morestyle.Icons.ReadBlock * " ReadBlock") && push!(bk.blocks, ReadBlock())
                        CImGui.EndMenu()
                    end
                end
                if CImGui.BeginMenu(morestyle.Icons.InsertDown * " 在下方插入")
                    CImGui.MenuItem(morestyle.Icons.CodeBlock * " CodeBlock") && insert!(blocks, i + 1, CodeBlock())
                    CImGui.MenuItem(morestyle.Icons.StrideCodeBlock * " StrideCodeBlock") && insert!(blocks, i + 1, StrideCodeBlock(n))
                    CImGui.MenuItem(morestyle.Icons.SettingBlock * " SettingBlock") && insert!(blocks, i + 1, SettingBlock())
                    CImGui.MenuItem(morestyle.Icons.SweepBlock * " SweepBlock") && insert!(blocks, i + 1, SweepBlock(n))
                    CImGui.MenuItem(morestyle.Icons.ReadingBlock * " ReadingBlock") && insert!(blocks, i + 1, ReadingBlock())
                    CImGui.MenuItem(morestyle.Icons.LogBlock * " LogBlock") && insert!(blocks, i + 1, LogBlock())
                    CImGui.MenuItem(morestyle.Icons.WriteBlock * " WriteBlock") && insert!(blocks, i + 1, WriteBlock())
                    CImGui.MenuItem(morestyle.Icons.QueryBlock * " QueryBlock") && insert!(blocks, i + 1, QueryBlock())
                    CImGui.MenuItem(morestyle.Icons.ReadBlock * " ReadBlock") && insert!(blocks, i + 1, ReadBlock())
                    CImGui.EndMenu()
                end
                if CImGui.BeginMenu(morestyle.Icons.Convert * " 转换为")
                    CImGui.MenuItem(morestyle.Icons.CodeBlock * " CodeBlock") && (bk isa CodeBlock || (blocks[i] = CodeBlock()))
                    if CImGui.MenuItem(morestyle.Icons.StrideCodeBlock * " StrideCodeBlock")
                        if !(bk isa StrideCodeBlock)
                            if bk isa SweepBlock
                                blocks[i] = StrideCodeBlock(n)
                                blocks[i].blocks = bk.blocks
                            else
                                blocks[i] = StrideCodeBlock(n)
                            end
                        end
                    end
                    CImGui.MenuItem(morestyle.Icons.SettingBlock * " SettingBlock") && (bk isa SettingBlock || (blocks[i] = SettingBlock()))
                    if CImGui.MenuItem(morestyle.Icons.SweepBlock * " SweepBlock")
                        if !(bk isa SweepBlock)
                            if bk isa StrideCodeBlock
                                blocks[i] = SweepBlock(n)
                                blocks[i].blocks = bk.blocks
                            else
                                blocks[i] = SweepBlock(n)
                            end
                        end
                    end
                    CImGui.MenuItem(morestyle.Icons.ReadingBlock * " ReadingBlock") && (bk isa ReadingBlock || (blocks[i] = ReadingBlock()))
                    CImGui.MenuItem(morestyle.Icons.LogBlock * " LogBlock") && (bk isa LogBlock || (blocks[i] = LogBlock()))
                    CImGui.MenuItem(morestyle.Icons.WriteBlock * " WriteBlock") && (bk isa WriteBlock || (blocks[i] = WriteBlock()))
                    CImGui.MenuItem(morestyle.Icons.QueryBlock * " QueryBlock") && (bk isa QueryBlock || (blocks[i] = QueryBlock()))
                    CImGui.MenuItem(morestyle.Icons.ReadBlock * " ReadBlock") && (bk isa ReadBlock || (blocks[i] = ReadBlock()))
                    CImGui.EndMenu()
                end
                CImGui.MenuItem(morestyle.Icons.CloseFile * " 删除") && (blocks[i] = NullBlock())
                bk isa CodeBlock && CImGui.MenuItem(morestyle.Icons.CloseFile * " 清空") && (bk.codes = "")
                bk isa StrideCodeBlock && CImGui.MenuItem(morestyle.Icons.CloseFile * " 清空") && (bk.head = "")
                CImGui.EndPopup()
            end
        end
        for (i, bk) in enumerate(blocks)
            bk isa NullBlock && deleteat!(blocks, i)
        end
        if n == 1
            if isdragging && !CImGui.IsMouseDown(0)
                isdragging = false
            elseif !isdragging
                !isempty(dragblock) && !isempty(dropblock) && swapblock(blocks, only(dragblock), only(dropblock))
                empty!(dragblock)
                empty!(dropblock)
            end
        end
    end
end #let

function swapblock(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock, dropbk::AbstractBlock)
    (dragbk == dropbk || isininnerblocks(dropbk, dragbk)) && return
    disable_drag(blocks, dragbk)
    insert_drop(blocks, dragbk, dropbk)
end

function isininnerblocks(dropbk::AbstractBlock, dragbk::AbstractBlock)
    if typeof(dragbk) in [SweepBlock, StrideCodeBlock]
        return dropbk in dragbk.blocks || true in [isininnerblocks(dropbk, bk) for bk in dragbk.blocks]
    else
        return false
    end
end

function disable_drag(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock)
    for (i, bk) in enumerate(blocks)
        bk == dragbk && (blocks[i] = NullBlock(); return true)
        typeof(bk) in [SweepBlock, StrideCodeBlock] && disable_drag(bk.blocks, dragbk) && return true
    end
    return false
end

function insert_drop(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock, dropbk::AbstractBlock)
    for (i, bk) in enumerate(blocks)
        bk == dropbk && (insert!(blocks, i, dragbk); return true)
        typeof(bk) in [SweepBlock, StrideCodeBlock] && insert_drop(bk.blocks, dragbk, dropbk) && return true
    end
    return false
end

############view-------------------------------------------------------------------------------------------------------

function view(bk::CodeBlock)
    CImGui.BeginChild("##CodeBlockViewer", (Float32(0), bkheight(bk)), true)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(bk.codes, (-1, 0))
    CImGui.PopStyleVar()
    CImGui.EndChild()
end

function view(bk::StrideCodeBlock)
    bdc = isempty(skipnull(bk.blocks)) ? CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border) : ImVec4(morestyle.Colors.StrideCodeBlockBorder...)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##StrideCodeBlockViewer", (Float32(0), bkheight(bk)), true)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(bk.head, (-1, 0))
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.EndChild()
end

function view(bk::SweepBlock)
    bdc = isempty(skipnull(bk.blocks)) ? CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border) : ImVec4(morestyle.Colors.SweepBlockBorder...)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##SweepBlockViewer", (Float32(0), bkheight(bk)), true)
    instrnm = bk.instrnm
    addr = bk.addr
    quantity = @trypass insconf[bk.instrnm].quantities[bk.quantity].alias ""
    Ut = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    units::Vector{String} = string.(conf.U[Ut])
    showu = @trypass units[bk.ui] ""
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(string("仪器：", instrnm, " 地址：", addr, " 扫描量：", quantity, " 步长：", bk.step, showu, " 终点：", bk.stop, showu, " 延迟：", bk.delay), (-1, 0))
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.EndChild()
end

function view(bk::SettingBlock)
    CImGui.BeginChild("##SettingBlockViewer", (Float32(0), bkheight(bk)), true)
    instrnm = bk.instrnm
    addr = bk.addr
    quantity = @trypass insconf[bk.instrnm].quantities[bk.quantity].alias ""
    Ut = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    units::Vector{String} = string.(conf.U[Ut])
    showu = @trypass units[bk.ui] ""
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(string("仪器：", instrnm, " 地址：", addr, " 设置：", quantity, " 设置值：", bk.setvalue, showu), (-1, 0))
    CImGui.PopStyleVar()
    CImGui.EndChild()
end

function view(bk::ReadingBlock)
    bdc = bk.isasync ? ImVec4(morestyle.Colors.BlockAsyncBorder...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##ReadingBlockViewer", (Float32(0), bkheight(bk)), true)
    quantity = @trypass insconf[bk.instrnm].quantities[bk.quantity].alias ""
    markc = bk.isobserve ? ImVec4(morestyle.Colors.BlockObserveBG...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
    bk.isobserve && bk.isreading && (markc = ImVec4(morestyle.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(string("仪器：", bk.instrnm, " 地址：", bk.addr, " 读取量：", quantity, " 索引：", bk.index, " 标注：", bk.mark), (-1, 0))
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.EndChild()
    CImGui.PopStyleColor()
end

function view(logbk::LogBlock)
    CImGui.BeginChild("##LogBlock", (Float32(0), bkheight(logbk)), true)
    CImGui.Button("LogBlock##", (-1, 0))
    CImGui.EndChild()
end

function view(bk::WriteBlock)
    bdc = bk.isasync ? ImVec4(morestyle.Colors.BlockAsyncBorder...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##WriteBlockViewer", (Float32(0), bkheight(bk)), true)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(string("仪器：", bk.instrnm, " 地址：", bk.addr, " 命令：", bk.cmd), (-1, 0))
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleColor()
end

function view(bk::QueryBlock)
    bdc = bk.isasync ? ImVec4(morestyle.Colors.BlockAsyncBorder...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##WriteBlockViewer", (Float32(0), bkheight(bk)), true)
    markc = bk.isobserve ? ImVec4(morestyle.Colors.BlockObserveBG...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
    bk.isobserve && bk.isreading && (markc = ImVec4(morestyle.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(string("仪器：", bk.instrnm, " 地址：", bk.addr, " 命令：", bk.cmd, " 索引：", bk.index, " 标注：", bk.mark), (-1, 0))
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.EndChild()
    CImGui.PopStyleColor()
end

function view(bk::ReadBlock)
    bdc = bk.isasync ? ImVec4(morestyle.Colors.BlockAsyncBorder...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Border)
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, bdc)
    CImGui.BeginChild("##WriteBlockViewer", (Float32(0), bkheight(bk)), true)
    markc = bk.isobserve ? ImVec4(morestyle.Colors.BlockObserveBG...) : CImGui.c_get(imguistyle.Colors, CImGui.ImGuiCol_Text)
    bk.isobserve && bk.isreading && (markc = ImVec4(morestyle.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(string("仪器：", bk.instrnm, " 地址：", bk.addr, " 命令：", bk.cmd, " 索引：", bk.index, " 标注：", bk.mark), (-1, 0))
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.EndChild()
    CImGui.PopStyleColor()
end

function view(blocks::Vector{AbstractBlock})
    for (i, bk) in enumerate(blocks)
        bk isa NullBlock && continue
        CImGui.PushID(i)
        view(bk)
        CImGui.PopID()
    end
end

############show-------------------------------------------------------------------------------------------------------

Base.show(io::IO, ::NullBlock) = print(io, "NullBlock")
function Base.show(io::IO, bk::CodeBlock)
    str = """
    CodeBlock :
            region :
             codes : 
    """
    print(io, str)
    bk.codes == "" || print(io, string(bk.codes, "\n"))
end
function Base.show(io::IO, bk::StrideCodeBlock)
    str = """
    StrideCodeBlock :
            region : $(bk.region)
             level : $(bk.level)
              head : $(bk.head)
              body : 
    """
    print(io, str)
    for b in bk.blocks
        print(io, string("+"^64, "\n", "\t"^4))
        show(io, b)
    end
end
function Base.show(io::IO, bk::SweepBlock)
    ut = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    u = conf.U[ut][bk.ui]
    str = """
    SweepBlock :
            region : $(bk.region)
             level : $(bk.level)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
              step : $(bk.step)
              stop : $(bk.stop)
              unit : $u
             delay : $(bk.delay)
              body :
    """
    print(io, str)
    for b in bk.blocks
        print(io, string("-"^64, "\n", "\t"^4))
        show(io, b)
    end
end
function Base.show(io::IO, bk::SettingBlock)
    ut = if haskey(insconf, bk.instrnm) && haskey(insconf[bk.instrnm].quantities, bk.quantity)
        insconf[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    u = conf.U[ut][bk.ui]
    str = """
    SettingBlock :
            region : $(bk.region)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
         set value : $(bk.setvalue)
              unit : $u
    """
    print(io, str)
end
function Base.show(io::IO, bk::ReadingBlock)
    str = """
    ReadingBlock :
            region : $(bk.region)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
    """
    print(io, str)
end
function Base.show(io::IO, bk::LogBlock)
    str = """
    LogBlock :
            region : $(bk.region)
    """
    print(io, str)
end
function Base.show(io::IO, bk::WriteBlock)
    str = """
    WriteBlock :
            region : $(bk.region)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
           command : $(bk.cmd)
             async : $(bk.isasync)
    """
    print(io, str)
end
function Base.show(io::IO, bk::QueryBlock)
    str = """
    QueryBlock :
            region : $(bk.region)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
           command : $(bk.cmd)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
    """
    print(io, str)
end
function Base.show(io::IO, bk::ReadBlock)
    str = """
    ReadBlock :
            region : $(bk.region)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
    """
    print(io, str)
end