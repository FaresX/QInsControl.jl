abstract type AbstractBlock end

struct NullBlock <: AbstractBlock end
skipnull(bkch::Vector{AbstractBlock}) = findall(bk -> !isa(bk, NullBlock), bkch)

@kwdef mutable struct CodeBlock <: AbstractBlock
    codes::String = ""
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct StrideCodeBlock <: AbstractBlock
    codes::String = ""
    level::Int = 1
    blocks::Vector{AbstractBlock} = AbstractBlock[]
    nohandler::Bool = false
    hideblocks::Bool = false
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct BranchBlock <: AbstractBlock
    codes::String = ""
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct SweepBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("sweep")
    step::String = ""
    stop::String = ""
    delay::Cfloat = 0.1
    ui::Int = 1
    level::Int = 1
    blocks::Vector{AbstractBlock} = AbstractBlock[]
    istrycatch::Bool = false
    hideblocks::Bool = false
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct SettingBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("set")
    setvalue::String = ""
    ui::Int = 1
    istrycatch::Bool = false
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct ReadingBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("read")
    index::String = ""
    mark::String = ""
    isasync::Bool = false
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = false
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct WriteBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    cmd::String = ""
    isasync::Bool = false
    istrycatch::Bool = false
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct QueryBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    cmd::String = ""
    index::String = ""
    mark::String = ""
    isasync::Bool = false
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = false
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

@kwdef mutable struct ReadBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    index::String = ""
    mark::String = ""
    isasync::Bool = false
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = false
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end

############ isapprox --------------------------------------------------------------------------------------------------

Base.isapprox(::T1, ::T2) where {T1<:AbstractBlock} where {T2<:AbstractBlock} = T1 == T2
Base.isapprox(x::CodeBlock, y::CodeBlock) = x.codes == y.codes
Base.isapprox(x::StrideCodeBlock, y::StrideCodeBlock) = x.codes == y.codes && x.blocks ≈ y.blocks
Base.isapprox(x::SweepBlock, y::SweepBlock) = x.blocks ≈ y.blocks
Base.isapprox(x::Vector{AbstractBlock}, y::Vector{AbstractBlock}) = length(x) == length(y) ? all(x .≈ y) : false

############ tocodes ---------------------------------------------------------------------------------------------------

tocodes(::NullBlock) = nothing

function tocodes(bk::CodeBlock)
    ex = @trypass Meta.parseall(bk.codes) begin
        @error "[$(now())]\ncodes are wrong in parsing time (CodeBlock)!!!" bk = bk
        return
    end
    ex isa Expr && ex.head == :toplevel && (ex.head = :block)
    ex
end

function tocodes(bk::StrideCodeBlock)
    branch_idx = [i for (i, bk) in enumerate(bk.blocks) if bk isa BranchBlock]
    branch_codes = [bk.codes for bk in bk.blocks[branch_idx]]
    pushfirst!(branch_idx, 0)
    push!(branch_idx, length(bk.blocks) + 1)
    push!(branch_codes, "end")
    innercodes = []
    for i in eachindex(branch_idx)[1:end-1]
        isasync = false
        for bk in bk.blocks[branch_idx[i]+1:branch_idx[i+1]-1]
            typeof(bk) in [ReadingBlock, WriteBlock, QueryBlock, ReadBlock] && bk.isasync && (isasync = true; break)
        end
        push!(
            innercodes,
            isasync ? quote
                @sync begin
                    $(tocodes.(bk.blocks[branch_idx[i]+1:branch_idx[i+1]-1])...)
                end
            end : quote
                $(tocodes.(bk.blocks[branch_idx[i]+1:branch_idx[i+1]-1])...)
            end
        )
    end
    ex1 = bk.nohandler ? quote end : quote
        @gencontroller StrideCodeBlock $(bk.codes)
    end
    codestr = string(bk.codes, "\n ", ex1)
    for i in eachindex(innercodes)
        codestr *= string("\n ", innercodes[i], "\n ", branch_codes[i])
    end
    @trypasse Meta.parse(codestr) (@error "[$(now())]\ncodes are wrong in parsing time (StrideCodeBlock)!!!" bk = bk)
end

tocodes(bk::BranchBlock) = error("[$(now())]\n$(mlstr("BranchBlock has to be in a StrideCodeBlock!!!"))\nbk=$bk")

function tocodes(bk::SweepBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    quantity = bk.quantity
    setfunc = Symbol(bk.instrnm, :_, bk.quantity, :_set)
    getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get)
    Ut = INSCONF[bk.instrnm].quantities[quantity].U
    Us = CONF.U[Ut]
    U = Us[bk.ui]
    U == "" && (@error "[$(now())]\n$(mlstr("input data error!!!"))" bk = bk;
    return)
    stepc = @trypass Meta.parse(bk.step) begin
        @error "[$(now())]\n$(mlstr("codes are wrong in parsing time (SweepBlock)!!!"))" bk = bk
        return nothing
    end
    stopc = @trypass Meta.parse(bk.stop) begin
        @error "[$(now())]\n$(mlstr("codes are wrong in parsing time (SweepBlock)!!!"))" bk = bk
        return nothing
    end
    start = :(parse(Float64, controllers[$instr]($getfunc, CPU, Val(:read))))
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
    @gensym sweeplist
    setcmd = :(controllers[$instr]($setfunc, CPU, string($ijk), Val(:write)))
    ex2 = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $setcmd) : setcmd
    return quote
        $sweeplist = gensweeplist($start, $step, $stop)
        @progress for $ijk in $sweeplist
            @gencontroller SweepBlock $instr
            $ex2
            sleep($(bk.delay))
            $interpcodes
        end
    end
end

function tocodes(bk::SettingBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    quantity = bk.quantity
    Ut = INSCONF[bk.instrnm].quantities[quantity].U
    Us = CONF.U[Ut]
    U = Us[bk.ui]
    if U == ""
        setvalue = parsedollar(bk.setvalue)
    else
        setvaluec = @trypass Meta.parse(bk.setvalue) begin
            @error "[$(now())]\n$(mlstr("codes are wrong in parsing time (SettingBlock)!!!"))" bk = bk
            return
        end
        Uchange = U isa Unitful.MixedUnits ? 1 : ustrip(Us[1], 1U)
        setvalue = Expr(:call, float, Expr(:call, :*, setvaluec, Uchange))
    end
    setfunc = Symbol(bk.instrnm, :_, bk.quantity, :_set)
    setcmd = :(controllers[$instr]($setfunc, CPU, string($setvalue), Val(:write)))
    return bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $setcmd) : setcmd
end


tocodes(bk::ReadingBlock) = gencodes_read(bk)

function tocodes(bk::WriteBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    cmd = parsedollar(bk.cmd)
    setcmd = :(controllers[$instr](write, CPU, string($cmd), Val(:write)))
    ex = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $setcmd) : setcmd
    return bk.isasync ? quote
        @async begin
            $ex
        end
    end : ex
end

tocodes(bk::QueryBlock) = gencodes_read(bk)

tocodes(bk::ReadBlock) = gencodes_read(bk)

function gencodes_read(bk::Union{ReadingBlock,QueryBlock,ReadBlock})
    instr = string(bk.instrnm, "_", bk.addr)
    index = @trypasse eval(Meta.parse(bk.index)) begin
        @error "[$(now())]\n$(mlstr("codes are wrong in parsing time (ReadingBlock)!!!"))" bk = bk
        return
    end
    index isa Integer && (index = [index])
    bk isa ReadingBlock && (getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get))
    bk isa QueryBlock && (cmd = parsedollar(bk.cmd))
    if isnothing(index)
        key = if bk isa ReadingBlock
            string(bk.mark, "_", bk.instrnm, "_", bk.quantity, "_", bk.addr)
        else
            string(bk.mark, "_", bk.instrnm, "_", bk.addr)
        end
        getcmd = if bk isa ReadingBlock
            :(controllers[$instr]($getfunc, CPU, Val(:read)))
        elseif bk isa QueryBlock
            :(controllers[$instr](query, CPU, string($cmd), Val(:query)))
        elseif bk isa ReadBlock
            :(controllers[$instr](read, CPU, Val(:read)))
        end
        getdata = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $getcmd) : getcmd
        if bk.isobserve
            observable = Symbol(bk.mark)
            return bk.isreading ? quote
                $observable = $getdata
                put!(databuf_lc, ($key, $observable))
            end : :($observable = $getdata)
        else
            ex = :(put!(databuf_lc, ($key, $getdata)))
            return bk.isasync ? quote
                @async begin
                    $ex
                end
            end : ex
        end
    else
        marks = fill("", length(index))
        for (i, v) in enumerate(split(bk.mark, ","))
            marks[i] = v
        end
        for i in index
            marks[i] == "" && (marks[i] = "mark$i")
        end
        keyall = if bk isa ReadingBlock
            [
                string(mark, "_", bk.instrnm, "_", bk.quantity, "[", ind, "]", "_", bk.addr)
                for (mark, ind) in zip(marks, index)
            ]
        else
            [string(mark, "_", bk.instrnm, "[", ind, "]", "_", bk.addr) for (mark, ind) in zip(marks, index)]
        end
        getcmd = if bk isa ReadingBlock
            :(string.(split(controllers[$instr]($getfunc, CPU, Val(:read)), ",")[collect($index)]))
        elseif bk isa QueryBlock
            :(string.(split(controllers[$instr](query, CPU, $cmd, Val(:query)), ",")[collect($index)]))
        elseif bk isa ReadBlock
            :(string.(split(controllers[$instr](read, CPU, Val(:read)), ",")[collect($index)]))
        end
        getdata = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $getcmd $(length(index))) : getcmd
        if bk.isobserve
            observable = length(index) == 1 ? Symbol(bk.mark) : Expr(:tuple, Symbol.(lstrip.(split(bk.mark, ',')))...)
            return bk.isreading ? quote
                $observable = $getdata
                for data in zip($keyall, $observable)
                    put!(databuf_lc, data)
                end
            end : :($observable = $getdata)
        else
            if bk.isasync
                return quote
                    @async for data in zip($keyall, $getdata)
                        put!(databuf_lc, data)
                        yield()
                    end
                end
            else
                return quote
                    for data in zip($keyall, $getdata)
                        put!(databuf_lc, data)
                    end
                end
            end
        end
    end
end

macro gentrycatch(instrnm, addr, cmd, len=0)
    esc(
        quote
            let
                state, getval = counter(CONF.DAQ.retryconnecttimes) do tout
                    state, getval = counter(CONF.DAQ.retrysendtimes) do tin
                        try
                            getval = $cmd
                            return true, getval
                        catch e
                            @error(
                                "[$(now)]\n$(mlstr("instrument communication failed!!!"))",
                                instrument = $(string(instrnm, ": ", addr)),
                                exception = e
                            )
                            @info stcstr(mlstr("retry sending command"), " ", tin)
                            return false, $(len == 0 ? "" : fill("", len))
                        end
                    end
                    if state
                        return true, getval
                    else
                        try
                            disconnect!(CPU.instrs[$addr])
                            connect!(CPU.resourcemanager, CPU.instrs[$addr])
                        catch
                        end
                        @info stcstr(mlstr("retry reconnecting instrument"), " ", tout)
                        return false, $(len == 0 ? "" : fill("", len))
                    end
                end
                getval
            end
        end
    )
end

macro gencontroller(key, val)
    esc(
        quote
            if SYNCSTATES[Int(IsBlocked)]
                @warn "[$(now())]\n$(mlstr("pause!"))" $key = $val
                lock(() -> wait(BLOCK), BLOCK)
                @info "[$(now())]\n$(mlstr("continue!"))" $key = $val
            elseif SYNCSTATES[Int(IsInterrupted)]
                @warn "[$(now())]\n$(mlstr("interrupt!"))" $key = $val
                return nothing
            end
        end
    )
end

############functionality-----------------------------------------------------------------------------------------------
macro logblock()
    esc(
        :(remotecall_wait(eval, 1, :(log_instrbufferviewers())))
    )
end

macro saveblock(key, var)
    esc(
        :(put!(databuf_lc, (string($(Meta.quot(key))), string($var))))
    )
end

macro saveblock(var)
    esc(
        :(put!(databuf_lc, (string($(Meta.quot(var))), string($var))))
    )
end

macro psleep(seconds)
    s1 = floor(seconds)
    s2 = floor(seconds - s1; digits=3) * 1000
    esc(
        quote
            @progress for _ in 1:$s1
                @gencontroller psleep $seconds
                sleep(1)
            end
            for _ in 1:$s2
                sleep(0.001)
            end
        end
    )
end

############bkheight----------------------------------------------------------------------------------------------------

bkheight(::NullBlock) = zero(Float32)
function bkheight(bk::CodeBlock)
    (1 + length(findall("\n", bk.codes))) * CImGui.GetTextLineHeight() +
    2unsafe_load(IMGUISTYLE.FramePadding.y) +
    2unsafe_load(IMGUISTYLE.WindowPadding.y) + 1
end
function bkheight(bk::StrideCodeBlock)
    return bk.hideblocks ? 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight() :
           2unsafe_load(IMGUISTYLE.WindowPadding.y) +
           CImGui.GetFrameHeight() +
           length(skipnull(bk.blocks)) * unsafe_load(IMGUISTYLE.ItemSpacing.y) +
           sum(bkheight.(bk.blocks))
end
function bkheight(bk::SweepBlock)
    return bk.hideblocks ? 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight() :
           2unsafe_load(IMGUISTYLE.WindowPadding.y) +
           CImGui.GetFrameHeight() +
           length(skipnull(bk.blocks)) * unsafe_load(IMGUISTYLE.ItemSpacing.y) +
           sum(bkheight.(bk.blocks))
end
bkheight(_) = 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight()

############ edit-------------------------------------------------------------------------------------------------------

function edit(bk::CodeBlock)
    CImGui.BeginChild("##CodeBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.CodeBlock)
    CImGui.SameLine()
    @c InputTextMultilineRSZ("##CodeBlock", &bk.codes, (-1, -1))
    CImGui.EndChild()
end

function edit(bk::StrideCodeBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if isempty(skipnull(bk.blocks))
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        else
            MORESTYLE.Colors.StrideCodeBlockBorder
        end
    )
    CImGui.BeginChild("##StrideBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.nohandler ? MORESTYLE.Colors.StrideCodeBlockBorder : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.StrideCodeBlock
    )
    CImGui.IsItemClicked(2) && (bk.nohandler ⊻= true)
    CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
    CImGui.SameLine()
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##code header", mlstr("code header"), &bk.codes)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor()
    bk.hideblocks || isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
    CImGui.EndChild()
end

function edit(bk::BranchBlock)
    CImGui.BeginChild("##BranchBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.BranchBlock)
    CImGui.SameLine()
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##BranchBlock", mlstr("code branch"), &bk.codes)
    CImGui.PopItemWidth()
    CImGui.EndChild()
end

function edit(bk::SweepBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if isempty(skipnull(bk.blocks))
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        else
            ImVec4(MORESTYLE.Colors.SweepBlockBorder...)
        end
    )
    CImGui.BeginChild("##SweepBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.SweepBlock
    )
    CImGui.IsItemClicked(2) && (bk.istrycatch ⊻= true)
    CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 3CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##SweepBlock instrument", &bk.instrnm, keys(INSCONF), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##SweepBlock address", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    showqt = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].alias
    else
        mlstr("sweep")
    end
    CImGui.PushItemWidth(width)
    if CImGui.BeginCombo("##SweepBlock sweep", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
        qtlist = haskey(INSCONF, bk.instrnm) ? keys(INSCONF[bk.instrnm].quantities) : Set{String}()
        qts = if haskey(INSCONF, bk.instrnm)
            [
                qt
                for qt in qtlist
                if INSCONF[bk.instrnm].quantities[qt].type == "sweep"
            ]
        else
            String[]
        end
        for qt in qts
            selected = bk.quantity == qt
            showqt = INSCONF[bk.instrnm].quantities[qt].alias
            CImGui.Selectable(showqt, selected, 0) && (bk.quantity = qt)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    CImGui.PopItemWidth()
    CImGui.SameLine()

    CImGui.PushItemWidth(width * 3 / 4)
    @c InputTextWithHintRSZ("##SweepBlock step", mlstr("step"), &bk.step)
    CImGui.PopItemWidth()
    CImGui.SameLine()
    CImGui.PushItemWidth(width * 3 / 4)
    @c InputTextWithHintRSZ("##SweepBlock stop", mlstr("stop"), &bk.stop)
    CImGui.PopItemWidth()
    CImGui.SameLine()
    CImGui.PushItemWidth(width / 2)
    @c CImGui.DragFloat("##SweepBlock delay", &bk.delay, 0.01, 0, 9.99, "%.2f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    CImGui.PushItemWidth(-1)
    @c ShowUnit("##SweepBlock", Ut, &bk.ui)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor()
    bk.hideblocks || isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function edit(bk::SettingBlock)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.BeginChild("##SettingBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.SettingBlock
    )
    CImGui.IsItemClicked(2) && (bk.istrycatch ⊻= true)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 3CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##SettingBlock instrument", &bk.instrnm, keys(INSCONF), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##SettingBlock address", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    showqt = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].alias
    else
        mlstr("set")
    end
    CImGui.PushItemWidth(width)
    if CImGui.BeginCombo("##SettingBlock set", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
        qtlist = haskey(INSCONF, bk.instrnm) ? keys(INSCONF[bk.instrnm].quantities) : Set{String}()
        sts = if haskey(INSCONF, bk.instrnm)
            [
                qt for qt in qtlist
                if INSCONF[bk.instrnm].quantities[qt].type in ["set", "sweep"]
            ]
        else
            String[]
        end
        for st in sts
            selected = bk.quantity == st
            showst = INSCONF[bk.instrnm].quantities[st].alias
            CImGui.Selectable(showst, selected, 0) && (bk.quantity = st)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    CImGui.PopItemWidth()

    CImGui.SameLine()
    CImGui.PushItemWidth(2width)
    @c InputTextWithHintRSZ("##SettingBlock set value", mlstr("set value"), &bk.setvalue)
    CImGui.PopItemWidth()
    if CImGui.BeginPopup("select set value")
        optklist = @trypass INSCONF[bk.instrnm].quantities[bk.quantity].optkeys []
        optvlist = @trypass INSCONF[bk.instrnm].quantities[bk.quantity].optvalues []
        isempty(optklist) && CImGui.TextColored(MORESTYLE.Colors.HighlightText, mlstr("unavailable options!"))
        for (i, optv) in enumerate(optvlist)
            optv == "" && continue
            CImGui.MenuItem(optklist[i]) && (bk.setvalue = optv)
        end
        CImGui.EndPopup()
    end
    CImGui.OpenPopupOnItemClick("select set value", 2)

    CImGui.SameLine()
    Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
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
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.BeginChild("##ReadingBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.ReadingBlock
    )
    CImGui.IsItemClicked(2) && (bk.istrycatch ⊻= true)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##ReadingBlock instrument", &bk.instrnm, keys(INSCONF), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##ReadingBlock address", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    showqt = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].alias
    else
        mlstr("read")
    end
    CImGui.PushItemWidth(width)
    if CImGui.BeginCombo("##ReadingBlock read", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
        qtlist = haskey(INSCONF, bk.instrnm) ? keys(INSCONF[bk.instrnm].quantities) : Set{String}()
        qts = collect(qtlist)
        for qt in qts
            selected = bk.quantity == qt
            showqt = INSCONF[bk.instrnm].quantities[qt].alias
            CImGui.Selectable(showqt, selected, 0) && (bk.quantity = qt)
            selected && CImGui.SetItemDefaultFocus()
        end
        CImGui.EndCombo()
    end
    CImGui.PopItemWidth()
    CImGui.SameLine()

    CImGui.PushItemWidth(width * 2 / 3)
    @c InputTextWithHintRSZ("##ReadingBlock index", mlstr("index"), &bk.index)
    CImGui.PopItemWidth()
    CImGui.SameLine()

    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##ReadingBlock mark", mlstr("mark"), &bk.mark)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor()
    if CImGui.IsItemClicked(2)
        if bk.isobserve
            bk.isreading ? (bk.isobserve = false; bk.isreading = false) : (bk.isreading = true)
        else
            bk.isobserve = true
        end
    end

    CImGui.EndChild()
    CImGui.IsItemClicked(0) && (bk.isasync ⊻= true)
    CImGui.PopStyleColor()
    CImGui.PopStyleVar()
end

function edit(bk::WriteBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.BeginChild("##WriteBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.WriteBlock
    )
    CImGui.IsItemClicked(2) && (bk.istrycatch ⊻= true)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##WriteBlock instrument", &bk.instrnm, keys(INSCONF), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##WriteBlock address", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选地址

    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##WriteBlock CMD", mlstr("command"), &bk.cmd)
    CImGui.PopItemWidth() #命令

    CImGui.EndChild()
    CImGui.IsItemClicked(0) && (bk.isasync ⊻= true)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end

function edit(bk::QueryBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.BeginChild("##QueryBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.QueryBlock
    )
    CImGui.IsItemClicked(2) && (bk.istrycatch ⊻= true)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##QueryBlock instrument", &bk.instrnm, keys(INSCONF), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##QueryBlock address", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选地址WriteBlock

    CImGui.PushItemWidth(width * 4 / 3)
    @c InputTextWithHintRSZ("##QueryBlock CMD", mlstr("command"), &bk.cmd)
    CImGui.PopItemWidth()
    CImGui.SameLine() #命令

    CImGui.PushItemWidth(width * 2 / 3)
    @c InputTextWithHintRSZ("##QueryBlock索引", mlstr("index"), &bk.index)
    CImGui.PopItemWidth()
    CImGui.SameLine() #索引

    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##QueryBlock mark", mlstr("mark"), &bk.mark)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor() #标注
    if CImGui.IsItemClicked(2)
        if bk.isobserve
            bk.isreading ? (bk.isobserve = false; bk.isreading = false) : (bk.isreading = true)
        else
            bk.isobserve = true
        end
    end

    CImGui.EndChild()
    CImGui.IsItemClicked(0) && (bk.isasync ⊻= true)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end

function edit(bk::ReadBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
    CImGui.BeginChild("##ReadBlock", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.ReadBlock
    )
    CImGui.IsItemClicked(2) && (bk.istrycatch ⊻= true)
    CImGui.SameLine()
    width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    @c ComBoS("##ReadBlock instrument", &bk.instrnm, keys(INSCONF), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : String[]
    CImGui.PushItemWidth(width)
    @c ComBoS("##ReadBlock address", &bk.addr, addrlist, CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选地址

    CImGui.PushItemWidth(width * 2 / 3)
    @c InputTextWithHintRSZ("##ReadBlock index", mlstr("index"), &bk.index)
    CImGui.PopItemWidth()
    CImGui.SameLine() #索引

    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_FrameBg)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    CImGui.PushStyleColor(CImGui.ImGuiCol_FrameBg, markc)
    CImGui.PushItemWidth(-1)
    @c InputTextWithHintRSZ("##ReadBlock mark", mlstr("mark"), &bk.mark)
    CImGui.PopItemWidth()
    CImGui.PopStyleColor() #标注
    if CImGui.IsItemClicked(2)
        if bk.isobserve
            bk.isreading ? (bk.isobserve = false; bk.isreading = false) : (bk.isreading = true)
        else
            bk.isobserve = true
        end
    end

    CImGui.EndChild()
    CImGui.IsItemClicked() && (bk.isasync ⊻= true)
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
end

function mousein(bk::AbstractBlock, total=false)::Bool
    if total
        mousein(bk.regmin, bk.regmax) || (typeof(bk) in [SweepBlock, StrideCodeBlock] && true in mousein.(bk.blocks, true))
    else
        mousein(bk.regmin, bk.regmax)
    end
end
mousein(::NullBlock, total=false) = false

let
    isdragging::Bool = false
    dragblock = AbstractBlock[]
    dropblock = AbstractBlock[]
    copyblock::AbstractBlock = NullBlock()
    global function edit(blocks::Vector{AbstractBlock}, n::Int)
        for (i, bk) in enumerate(blocks)
            bk isa NullBlock && continue
            if isdragging && mousein(bk)
                CImGui.PushStyleColor(CImGui.ImGuiCol_Separator, MORESTYLE.Colors.HighlightText)
                draw_list = CImGui.GetWindowDrawList()
                rectcolor = CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.BlockDragdrop)
                CImGui.AddRectFilled(draw_list, bk.regmin, bk.regmax, rectcolor, 0.0, 0)
                CImGui.PopStyleColor()
            end
            CImGui.PushID(i)
            edit(bk)
            id = stcstr(CImGui.igGetItemID())
            if typeof(bk) in [SweepBlock, StrideCodeBlock]
                rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
                wp = unsafe_load(IMGUISTYLE.WindowPadding.y)
                extraheight = isempty(bk.blocks) ? wp : unsafe_load(IMGUISTYLE.ItemSpacing.y) ÷ 2
                # bk.region .= rmin.x, rmin.y, rmax.x, rmin.y + wp + CImGui.GetFrameHeight() + extraheight
                bk.regmin = rmin
                bk.regmax = (rmax.x, rmin.y + wp + CImGui.GetFrameHeight() + extraheight)
            else
                rmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
                # bk.region .= rmin.x, rmin.y, rmax.x, rmax.y
                bk.regmin = rmin
                bk.regmax = rmax
            end
            CImGui.PopID()
            if CImGui.IsMouseDown(0)
                if CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) > 0.2 && !isdragging && mousein(bk)
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
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertUp, " ", mlstr("Insert Above")))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CodeBlock, " ", mlstr("CodeBlock"))) && insert!(blocks, i, CodeBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.StrideCodeBlock, " ", mlstr("StrideCodeBlock"))) && insert!(blocks, i, StrideCodeBlock(level=n))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.BranchBlock, " ", mlstr("BranchBlock"))) && insert!(blocks, i, BranchBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SweepBlock, " ", mlstr("SweepBlock"))) && insert!(blocks, i, SweepBlock(level=n))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SettingBlock, " ", mlstr("SettingBlock"))) && insert!(blocks, i, SettingBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadingBlock, " ", mlstr("ReadingBlock"))) && insert!(blocks, i, ReadingBlock())
                    # CImGui.MenuItem(stcstr(MORESTYLE.Icons.LogBlock, " ", mlstr("LogBlock"))) && insert!(blocks, i, LogBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.WriteBlock, " ", mlstr("WriteBlock"))) && insert!(blocks, i, WriteBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.QueryBlock, " ", mlstr("QueryBlock"))) && insert!(blocks, i, QueryBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadBlock, " ", mlstr("ReadBlock"))) && insert!(blocks, i, ReadBlock())
                    # CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveBlock, " ", mlstr("SaveBlock"))) && insert!(blocks, i, SaveBlock())
                    CImGui.EndMenu()
                end
                if (bk isa StrideCodeBlock || bk isa SweepBlock) && isempty(skipnull(bk.blocks))
                    if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertInside, " ", mlstr("Insert Inside")), bk.level < 6)
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.CodeBlock, " ", mlstr("CodeBlock"))) && push!(bk.blocks, CodeBlock())
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.StrideCodeBlock, " ", mlstr("StrideCodeBlock"))) && push!(bk.blocks, StrideCodeBlock(level=n + 1))
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.BranchBlock, " ", mlstr("BranchBlock"))) && push!(bk.blocks, BranchBlock())
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.SweepBlock, " ", mlstr("SweepBlock"))) && push!(bk.blocks, SweepBlock(level=n + 1))
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.SettingBlock, " ", mlstr("SettingBlock"))) && push!(bk.blocks, SettingBlock())
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadingBlock, " ", mlstr("ReadingBlock"))) && push!(bk.blocks, ReadingBlock())
                        # CImGui.MenuItem(stcstr(MORESTYLE.Icons.LogBlock, " ", mlstr("LogBlock"))) && push!(bk.blocks, LogBlock())
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.WriteBlock, " ", mlstr("WriteBlock"))) && push!(bk.blocks, WriteBlock())
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.QueryBlock, " ", mlstr("QueryBlock"))) && push!(bk.blocks, QueryBlock())
                        CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadBlock, " ", mlstr("ReadBlock"))) && push!(bk.blocks, ReadBlock())
                        # CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveBlock, " ", mlstr("SaveBlock"))) && push!(bk.blocks, SaveBlock())
                        CImGui.EndMenu()
                    end
                end
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertDown, " ", mlstr("Insert Below")))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CodeBlock, " ", mlstr("CodeBlock"))) && insert!(blocks, i + 1, CodeBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.StrideCodeBlock, " ", mlstr("StrideCodeBlock"))) && insert!(blocks, i + 1, StrideCodeBlock(level=n))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.BranchBlock, " ", mlstr("BranchBlock"))) && insert!(blocks, i + 1, BranchBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SweepBlock, " ", mlstr("SweepBlock"))) && insert!(blocks, i + 1, SweepBlock(level=n))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SettingBlock, " ", mlstr("SettingBlock"))) && insert!(blocks, i + 1, SettingBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadingBlock, " ", mlstr("ReadingBlock"))) && insert!(blocks, i + 1, ReadingBlock())
                    # CImGui.MenuItem(stcstr(MORESTYLE.Icons.LogBlock, " ", mlstr("LogBlock"))) && insert!(blocks, i + 1, LogBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.WriteBlock, " ", mlstr("WriteBlock"))) && insert!(blocks, i + 1, WriteBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.QueryBlock, " ", mlstr("QueryBlock"))) && insert!(blocks, i + 1, QueryBlock())
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadBlock, " ", mlstr("ReadBlock"))) && insert!(blocks, i + 1, ReadBlock())
                    # CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveBlock, " ", mlstr("SaveBlock"))) && insert!(blocks, i + 1, SaveBlock())
                    CImGui.EndMenu()
                end
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Convert to")))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CodeBlock, " ", mlstr("CodeBlock"))) && (bk isa CodeBlock || (blocks[i] = CodeBlock()))
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.StrideCodeBlock, " ", mlstr("StrideCodeBlock")))
                        if !(bk isa StrideCodeBlock)
                            if bk isa SweepBlock
                                blocks[i] = StrideCodeBlock(level=n)
                                blocks[i].blocks = bk.blocks
                            else
                                blocks[i] = StrideCodeBlock(level=n)
                            end
                        end
                    end
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.BranchBlock, " ", mlstr("BranchBlock"))) && (bk isa BranchBlock || (blocks[i] = BranchBlock()))
                    if CImGui.MenuItem(stcstr(MORESTYLE.Icons.SweepBlock, " ", mlstr("SweepBlock")))
                        if !(bk isa SweepBlock)
                            if bk isa StrideCodeBlock
                                blocks[i] = SweepBlock(level=n)
                                blocks[i].blocks = bk.blocks
                            else
                                blocks[i] = SweepBlock(level=n)
                            end
                        end
                    end
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SettingBlock, " ", mlstr("SettingBlock"))) && (bk isa SettingBlock || (blocks[i] = SettingBlock()))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadingBlock, " ", mlstr("ReadingBlock"))) && (bk isa ReadingBlock || (blocks[i] = ReadingBlock()))
                    # CImGui.MenuItem(stcstr(MORESTYLE.Icons.LogBlock, " ", mlstr("LogBlock"))) && (bk isa LogBlock || (blocks[i] = LogBlock()))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.WriteBlock, " ", mlstr("WriteBlock"))) && (bk isa WriteBlock || (blocks[i] = WriteBlock()))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.QueryBlock, " ", mlstr("QueryBlock"))) && (bk isa QueryBlock || (blocks[i] = QueryBlock()))
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadBlock, " ", mlstr("ReadBlock"))) && (bk isa ReadBlock || (blocks[i] = ReadBlock()))
                    # CImGui.MenuItem(stcstr(MORESTYLE.Icons.SaveBlock, " ", mlstr("SaveBlock"))) && (bk isa SaveBlock || (blocks[i] = SaveBlock()))
                    CImGui.EndMenu()
                end
                CImGui.Separator()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy"))) && (copyblock = deepcopy(blocks[i]))
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste"))) && insert!(blocks, i + 1, deepcopy(copyblock))
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (blocks[i] = NullBlock())
                if typeof(bk) in [CodeBlock, StrideCodeBlock]
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Clear"))) && (bk.codes = "")
                end
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
    if typeof(dropbk) in [SweepBlock, StrideCodeBlock] && unsafe_load(CImGui.GetIO().KeyCtrl)
        push!(dropbk.blocks, dragbk)
        return
    end
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
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.CodeBlock)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(bk.codes, (-1, 0))
    CImGui.PopStyleVar()
    CImGui.EndChild()
end

function view(bk::StrideCodeBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if isempty(skipnull(bk.blocks))
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        else
            MORESTYLE.Colors.StrideCodeBlockBorder
        end
    )
    CImGui.BeginChild("##StrideCodeBlockViewer", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.nohandler ? MORESTYLE.Colors.StrideCodeBlockBorder : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.StrideCodeBlock
    )
    CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(bk.codes, (-1, 0))
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    bk.hideblocks || isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.EndChild()
end

function view(bk::BranchBlock)
    CImGui.BeginChild("##BranchBlockViewer", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.BranchBlock)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(bk.codes, (-1, 0))
    CImGui.PopStyleVar()
    CImGui.EndChild()
end

function view(bk::SweepBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if isempty(skipnull(bk.blocks))
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        else
            MORESTYLE.Colors.SweepBlockBorder
        end
    )
    CImGui.BeginChild("##SweepBlockViewer", (Float32(0), bkheight(bk)), true)
    instrnm = bk.instrnm
    addr = bk.addr
    quantity = @trypass INSCONF[bk.instrnm].quantities[bk.quantity].alias ""
    Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    units::Vector{String} = string.(CONF.U[Ut])
    showu = @trypass units[bk.ui] ""
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.SweepBlock
    )
    CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", instrnm,
            "\t", mlstr("address"), ": ", addr,
            "\t", mlstr("sweep"), ": ", quantity,
            "\t", mlstr("step"), ": ", bk.step, showu,
            "\t", mlstr("stop"), ": ", bk.stop, showu,
            "\t", mlstr("delay"), ": ", bk.delay
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    bk.hideblocks || isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.EndChild()
end

function view(bk::SettingBlock)
    CImGui.BeginChild("##SettingBlockViewer", (Float32(0), bkheight(bk)), true)
    instrnm = bk.instrnm
    addr = bk.addr
    quantity = @trypass INSCONF[bk.instrnm].quantities[bk.quantity].alias ""
    Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    units::Vector{String} = string.(CONF.U[Ut])
    showu = @trypass units[bk.ui] ""
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.SettingBlock
    )
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", instrnm,
            "\t", mlstr("address"), ": ", addr,
            "\t", mlstr("set"), ": ", quantity,
            "\t", mlstr("set value"), ": ", bk.setvalue, showu
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.EndChild()
end

function view(bk::ReadingBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.BeginChild("##ReadingBlockViewer", (Float32(0), bkheight(bk)), true)
    quantity = @trypass INSCONF[bk.instrnm].quantities[bk.quantity].alias ""
    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.ReadingBlock
    )
    CImGui.SameLine()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("read"), ": ", quantity,
            "\t", mlstr("index"), ": ", bk.index,
            "\t", mlstr("mark"), ": ", bk.mark
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.EndChild()
    CImGui.PopStyleColor()
end

function view(bk::WriteBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.BeginChild("##WriteBlockViewer", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.WriteBlock
    )
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("command"), ": ", bk.cmd
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleColor()
end

function view(bk::QueryBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.BeginChild("##WriteBlockViewer", (Float32(0), bkheight(bk)), true)
    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.QueryBlock
    )
    CImGui.SameLine()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("command"), ": ", bk.cmd,
            "\t", mlstr("index"), ": ", bk.index,
            "\t", mlstr("mark"), ": ", bk.mark
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.EndChild()
    CImGui.PopStyleColor()
end

function view(bk::ReadBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if bk.isasync && !bk.isobserve
            MORESTYLE.Colors.BlockAsyncBorder
        else
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        end
    )
    CImGui.BeginChild("##WriteBlockViewer", (Float32(0), bkheight(bk)), true)
    markc = if bk.isobserve
        ImVec4(MORESTYLE.Colors.BlockObserveBG...)
    else
        CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text)
    end
    bk.isobserve && bk.isreading && (markc = ImVec4(MORESTYLE.Colors.BlockObserveReadingBG...))
    CImGui.TextColored(
        bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
        MORESTYLE.Icons.ReadBlock
    )
    CImGui.SameLine()
    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, markc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("index"), ": ", bk.index,
            "\t", mlstr("mark"), ": ", bk.mark
        ),
        (-1, 0)
    )
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
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             codes : 
    """
    print(io, str)
    bk.codes == "" || print(io, string(bk.codes, "\n"))
end
function Base.show(io::IO, bk::StrideCodeBlock)
    str = """
    StrideCodeBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             level : $(bk.level)
        hideblocks : $(bk.hideblocks)
              head : $(bk.codes)
              body : 
    """
    print(io, str)
    for b in bk.blocks
        print(io, string("+"^64, "\n", "\t"^4))
        show(io, b)
    end
end
function Base.show(io::IO, bk::BranchBlock)
    str = """
    BranchBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             codes : 
    """
    print(io, str)
    bk.codes == "" || print(io, string(bk.codes, "\n"))
end
function Base.show(io::IO, bk::SweepBlock)
    ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    u = CONF.U[ut][bk.ui]
    str = """
    SweepBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             level : $(bk.level)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
              step : $(bk.step)
              stop : $(bk.stop)
              unit : $u
             delay : $(bk.delay)
          trycatch : $(bk.istrycatch)
        hideblocks : $(bk.hideblocks)
              body :
    """
    print(io, str)
    for b in bk.blocks
        print(io, string("-"^64, "\n", "\t"^4))
        show(io, b)
    end
end
function Base.show(io::IO, bk::SettingBlock)
    ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    u = CONF.U[ut][bk.ui]
    str = """
    SettingBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
         set value : $(bk.setvalue)
              unit : $u
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::ReadingBlock)
    str = """
    ReadingBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::WriteBlock)
    str = """
    WriteBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
           command : $(bk.cmd)
             async : $(bk.isasync)
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::QueryBlock)
    str = """
    QueryBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
           command : $(bk.cmd)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end
function Base.show(io::IO, bk::ReadBlock)
    str = """
    ReadBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
             index : $(bk.index)
              mark : $(bk.mark)
             async : $(bk.isasync)
           observe : $(bk.isobserve)
           reading : $(bk.isreading)
          trycatch : $(bk.istrycatch)
    """
    print(io, str)
end