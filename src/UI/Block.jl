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

@kwdef mutable struct FeedbackBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    action::String = mlstr("Pause")
    regmin::ImVec2 = (0, 0)
    regmax::ImVec2 = (0, 0)
end
############ isapprox --------------------------------------------------------------------------------------------------

function Base.isapprox(bk1::T1, bk2::T2) where {T1<:AbstractBlock} where {T2<:AbstractBlock}
    if T1 == T2
        return all(
            fnm == :blocks ? bk1.blocks ≈ bk2.blocks : getproperty(bk1, fnm) == getproperty(bk2, fnm)
            for fnm in fieldnames(T1)[1:end-2]
        )
    end
    return false
end
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
    U, Us = @c getU(INSCONF[bk.instrnm].quantities[quantity].U, &bk.ui)
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
    U, Us = @c getU(INSCONF[bk.instrnm].quantities[quantity].U, &bk.ui)
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

function tocodes(bk::FeedbackBlock)
    instr = string(bk.instrnm, "_", bk.addr)
    quote
        if haskey(SWEEPCTS, $(bk.instrnm)) && haskey(SWEEPCTS[$(bk.instrnm)], $(bk.addr))
            SWEEPCTS[$(bk.instrnm)][$(bk.addr)][1][] = false
        end
        if $(bk.action) == mlstr("Interrupt")
            SYNCSTATES[Int(IsInterrupted)] = true
            @warn "[$(now())]\n$(mlstr("interrupt!"))" FeedbackBlock = $instr
            return nothing
        elseif $(bk.action) == mlstr("Pause")
            SYNCSTATES[Int(IsBlocked)] = true
            @warn "[$(now())]\n$(mlstr("pause!"))" FeedbackBlock = $instr
            lock(() -> wait(BLOCK), BLOCK)
            @info "[$(now())]\n$(mlstr("continue!"))" FeedbackBlock = $instr
        end
    end
end

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
        for (i, idx) in enumerate(index)
            marks[i] == "" && (marks[i] = "mark$idx")
        end
        keyall = if bk isa ReadingBlock
            [
                string(mark, "_", bk.instrnm, "_", bk.quantity, "[", ind, "]", "_", bk.addr)
                for (mark, ind) in zip(marks, index)
            ]
        else
            [string(mark, "_", bk.instrnm, "[", ind, "]", "_", bk.addr) for (mark, ind) in zip(marks, index)]
        end
        separator = bk isa ReadingBlock ? INSCONF[bk.instrnm].quantities[bk.quantity].separator : ","
        separator == "" && (separator = ",")
        getcmd = if bk isa ReadingBlock
            :(string.(split(controllers[$instr]($getfunc, CPU, Val(:read)), $separator)[collect($index)]))
        elseif bk isa QueryBlock
            :(string.(split(controllers[$instr](query, CPU, $cmd, Val(:query)), $separator)[collect($index)]))
        elseif bk isa ReadBlock
            :(string.(split(controllers[$instr](read, CPU, Val(:read)), $separator)[collect($index)]))
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
                            @warn stcstr("[", now(), "]\n", mlstr("retry sending command"), " ", tin)
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
                        @warn stcstr("[", now(), "]\n", mlstr("retry reconnecting instrument"), " ", tout)
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
            if SYNCSTATES[Int(IsInterrupted)]
                @warn "[$(now())]\n$(mlstr("interrupt!"))" $key = $val
                return nothing
            elseif SYNCSTATES[Int(IsBlocked)]
                @warn "[$(now())]\n$(mlstr("pause!"))" $key = $val
                lock(() -> wait(BLOCK), BLOCK)
                @info "[$(now())]\n$(mlstr("continue!"))" $key = $val
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
    @c InputTextMultilineRSZ("##CodeBlock", &bk.codes, (-1, -1), ImGuiInputTextFlags_AllowTabInput)
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

let
    filter::String = ""
    global function edit(bk::SweepBlock)
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
        @c ComboSFiltered("##SweepBlock instrument", &bk.instrnm, sort(collect(keys(INSCONF))), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine()

        inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        bk.addr = inlist ? bk.addr : mlstr("address")
        addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
        CImGui.PushItemWidth(width)
        @c ComboS("##SweepBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
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
                [qt for qt in qtlist if INSCONF[bk.instrnm].quantities[qt].type == "sweep"]
            else
                String[]
            end
            @c InputTextWithHintRSZ("##SweepBlock sweep", mlstr("Filter"), &filter)
            sp = sortperm([INSCONF[bk.instrnm].quantities[qt].alias for qt in qts])
            for qt in qts[sp]
                showqt = INSCONF[bk.instrnm].quantities[qt].alias
                (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(showqt))) || continue
                selected = bk.quantity == qt
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
end

let
    filter::String = ""
    global function edit(bk::SettingBlock)
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
        @c ComboSFiltered("##SettingBlock instrument", &bk.instrnm, sort(collect(keys(INSCONF))), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine()

        inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        bk.addr = inlist ? bk.addr : mlstr("address")
        addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
        CImGui.PushItemWidth(width)
        @c ComboS("##SettingBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
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
                [qt for qt in qtlist if INSCONF[bk.instrnm].quantities[qt].type in ["set", "sweep"]]
            else
                String[]
            end
            @c InputTextWithHintRSZ("##SettingBlock set", mlstr("Filter"), &filter)
            sp = sortperm([INSCONF[bk.instrnm].quantities[qt].alias for qt in sts])
            for st in sts[sp]
                showqt = INSCONF[bk.instrnm].quantities[st].alias
                (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(showqt))) || continue
                selected = bk.quantity == st
                CImGui.Selectable(showqt, selected, 0) && (bk.quantity = st)
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
end

let
    filter::String = ""
    global function edit(bk::ReadingBlock)
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
        @c ComboSFiltered("##ReadingBlock instrument", &bk.instrnm, sort(collect(keys(INSCONF))), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine()

        inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        bk.addr = inlist ? bk.addr : mlstr("address")
        addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) String[]
        CImGui.PushItemWidth(width)
        @c ComboS("##ReadingBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        hasqt = haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        showqt = hasqt ? INSCONF[bk.instrnm].quantities[bk.quantity].alias : mlstr("read")
        CImGui.PushItemWidth(width)
        if CImGui.BeginCombo("##ReadingBlock read", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
            qtlist = haskey(INSCONF, bk.instrnm) ? keys(INSCONF[bk.instrnm].quantities) : Set{String}()
            qts = collect(qtlist)
            @c InputTextWithHintRSZ("##ReadingBlock read", mlstr("Filter"), &filter)
            sp = sortperm([INSCONF[bk.instrnm].quantities[qt].alias for qt in qts])
            for qt in qts[sp]
                showqt = INSCONF[bk.instrnm].quantities[qt].alias
                (filter == "" || !isvalid(filter) || occursin(lowercase(filter), lowercase(showqt))) || continue
                selected = bk.quantity == qt
                CImGui.Selectable(showqt, selected, 0) && (bk.quantity = qt)
                selected && CImGui.SetItemDefaultFocus()
            end
            CImGui.EndCombo()
        end
        CImGui.PopItemWidth()
        CImGui.SameLine()

        igBeginDisabled((!hasqt || (hasqt && INSCONF[bk.instrnm].quantities[bk.quantity].numread == 1)))
        CImGui.PushItemWidth(width * 2 / 3)
        @c InputTextWithHintRSZ("##ReadingBlock index", mlstr("index"), &bk.index)
        CImGui.PopItemWidth()
        igEndDisabled()
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
    @c ComboSFiltered("##WriteBlock instrument", &bk.instrnm, sort(collect(keys(INSCONF))), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) Set{String}()
    CImGui.PushItemWidth(width)
    @c ComboS("##WriteBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
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
    @c ComboSFiltered("##QueryBlock instrument", &bk.instrnm, sort(collect(keys(INSCONF))), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = @trypass keys(INSTRBUFFERVIEWERS[bk.instrnm]) Set{String}()
    CImGui.PushItemWidth(width)
    @c ComboS("##QueryBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
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
    @c ComboSFiltered("##ReadBlock instrument", &bk.instrnm, sort(collect(keys(INSCONF))), CImGui.ImGuiComboFlags_NoArrowButton)
    CImGui.PopItemWidth()
    CImGui.SameLine() #选仪器

    inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
    bk.addr = inlist ? bk.addr : mlstr("address")
    addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
    CImGui.PushItemWidth(width)
    @c ComboS("##ReadBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
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

let
    actions::Vector{String} = ["Pause", "Interrupt", "Continue"]
    global function edit(bk::FeedbackBlock)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
        CImGui.BeginChild("##FeedbackBlock", (Float32(0), bkheight(bk)), true)
        CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.FeedbackBlock)
        CImGui.SameLine()
        width = (CImGui.GetContentRegionAvailWidth() - 2CImGui.GetFontSize()) / 3
        CImGui.PushItemWidth(width)
        @c ComboSFiltered("##FeedbackBlock instrument", &bk.instrnm, sort(collect(keys(INSCONF))), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine() #选仪器

        inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        bk.addr = inlist ? bk.addr : mlstr("address")
        addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
        CImGui.PushItemWidth(width)
        @c ComboS("##FeedbackBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine() #选地址

        CImGui.PushItemWidth(-1)
        @c ComboS("##FeedbackBlock action", &bk.action, mlstr.(actions), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth() #action

        CImGui.EndChild()
        CImGui.PopStyleVar()
    end
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
    addmode::Bool = false
    draggingid = 0
    presentid = 0
    dragblock = AbstractBlock[]
    dropblock = AbstractBlock[]
    copyblock::AbstractBlock = NullBlock()
    selectedblock::Cint = 0
    instrblocks::Vector{Type} = [SweepBlock, SettingBlock, ReadingBlock, WriteBlock, QueryBlock, ReadBlock, FeedbackBlock]
    allblocks::Vector{Symbol} = [:CodeBlock, :StrideCodeBlock, :BranchBlock, :SweepBlock, :SettingBlock, :ReadingBlock,
        :WriteBlock, :QueryBlock, :ReadBlock, :FeedbackBlock]

    global function dragblockmenu(id)
        presentid = id
        CImGui.PushFont(PLOTFONT)
        ftsz = CImGui.GetFontSize()
        lbk = length(allblocks)
        availw = CImGui.GetContentRegionAvailWidth() / lbk - unsafe_load(IMGUISTYLE.ItemSpacing.x)
        for (i, bk) in enumerate(allblocks)
            CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.BlockIcons)
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_SelectableTextAlign, (0.5, 0.5))
            CImGui.Selectable(getproperty(MORESTYLE.Icons, bk), false, 0, (availw, 2ftsz))
            CImGui.PopStyleVar()
            CImGui.PopStyleColor()
            CImGui.PushFont(GLOBALFONT)
            ItemTooltip(mlstr(stcstr(bk)))
            CImGui.PopFont()
            if CImGui.IsItemActive() && !isdragging && isempty(dragblock)
                push!(dragblock, eval(bk)())
                isdragging = true
                addmode = true
                draggingid = presentid
            end
            i == lbk || CImGui.SameLine()
        end
        CImGui.PopFont()
        if isdragging && draggingid == presentid && length(dragblock) == 1
            draw_list = CImGui.GetWindowDrawList()
            tiptxt = mlstr(split(string(typeof(only(dragblock))), '.')[end])
            rmin = CImGui.GetMousePos() .+ CImGui.ImVec2(ftsz, ftsz)
            rmax = rmin .+ CImGui.CalcTextSize(tiptxt) .+ CImGui.ImVec2(ftsz, ftsz)
            CImGui.AddRectFilled(draw_list, rmin, rmax, CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.BlockDragdrop))
            CImGui.AddText(
                draw_list,
                rmin .+ CImGui.ImVec2(ftsz / 2, ftsz / 2),
                CImGui.ColorConvertFloat4ToU32(MORESTYLE.Colors.HighlightText),
                tiptxt
            )
        end
    end

    global function edit(blocks::Vector{AbstractBlock}, n::Int, id=0)
        n == 1 && (presentid = id)
        for (i, bk) in enumerate(blocks)
            bk isa NullBlock && continue
            if isdragging && draggingid == presentid && mousein(bk)
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
                bk.regmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
                wp = unsafe_load(IMGUISTYLE.WindowPadding.y)
                extraheight = isempty(bk.blocks) ? wp : unsafe_load(IMGUISTYLE.ItemSpacing.y) ÷ 2
                bk.regmax = (rmax.x, bk.regmin.y + wp + CImGui.GetFrameHeight() + extraheight)
            else
                bk.regmin, bk.regmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
            end
            CImGui.PopID()
            if CImGui.IsMouseDown(0)
                if CImGui.c_get(CImGui.GetIO().MouseDownDuration, 0) > 0.2 && !isdragging && mousein(bk) && isempty(dragblock)
                    push!(dragblock, bk)
                    isdragging = true
                    addmode = false
                    draggingid = presentid
                end
            else
                if isdragging && draggingid == presentid && mousein(bk) && isempty(dropblock)
                    push!(dropblock, bk)
                    isdragging = false
                end
            end
            mousein(bk) && CImGui.OpenPopupOnItemClick(id, 1)
            if CImGui.BeginPopup(id)
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertUp, " ", mlstr("Insert Above")))
                    newblock = addblockmenu(n)
                    isnothing(newblock) || insert!(blocks, i, newblock)
                    CImGui.EndMenu()
                end
                if (bk isa StrideCodeBlock || bk isa SweepBlock) && isempty(skipnull(bk.blocks))
                    if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertInside, " ", mlstr("Insert Inside")), bk.level < 6)
                        newblock = addblockmenu(n)
                        isnothing(newblock) || push!(bk.blocks, newblock)
                        CImGui.EndMenu()
                    end
                end
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.InsertDown, " ", mlstr("Insert Below")))
                    newblock = addblockmenu(n)
                    isnothing(newblock) || insert!(blocks, i + 1, newblock)
                    CImGui.EndMenu()
                end
                if CImGui.BeginMenu(stcstr(MORESTYLE.Icons.Convert, " ", mlstr("Convert to")))
                    newblock = addblockmenu(n)
                    if !(isnothing(newblock) || newblock isa typeof(bk))
                        if newblock isa StrideCodeBlock
                            bk isa SweepBlock && (newblock.blocks = bk.blocks)
                        elseif newblock isa SweepBlock
                            if bk isa StrideCodeBlock
                                newblock.blocks = bk.blocks
                            elseif typeof(bk) in instrblocks
                                newblock.instrnm = bk.instrnm
                                newblock.addr = bk.addr
                            end
                        elseif typeof(newblock) in instrblocks
                            typeof(bk) in instrblocks && (newblock.instrnm = bk.instrnm; newblock.addr = bk.addr)
                        end
                        blocks[i] = newblock
                    end
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
        if n == 1 && draggingid == presentid
            if isdragging && !CImGui.IsMouseDown(0)
                isdragging = false
            elseif !isdragging
                if !isempty(dragblock)
                    if isempty(dropblock)
                        CImGui.IsAnyItemHovered() || (addmode && CImGui.IsWindowHovered() && push!(blocks, only(dragblock)))
                    else
                        swapblock(blocks, only(dragblock), only(dropblock), addmode)
                    end
                end
                empty!(dragblock)
                empty!(dropblock)
            end
        end
    end
end #let

function addblockmenu(n)
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.CodeBlock, " ", mlstr("CodeBlock"))) && return CodeBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.StrideCodeBlock, " ", mlstr("StrideCodeBlock"))) && return StrideCodeBlock(level=n)
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.BranchBlock, " ", mlstr("BranchBlock"))) && return BranchBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SweepBlock, " ", mlstr("SweepBlock"))) && return SweepBlock(level=n)
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.SettingBlock, " ", mlstr("SettingBlock"))) && return SettingBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadingBlock, " ", mlstr("ReadingBlock"))) && return ReadingBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.WriteBlock, " ", mlstr("WriteBlock"))) && return WriteBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.QueryBlock, " ", mlstr("QueryBlock"))) && return QueryBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.ReadBlock, " ", mlstr("ReadBlock"))) && return ReadBlock()
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.FeedbackBlock, " ", mlstr("FeedbackBlock"))) && return FeedbackBlock()
    return nothing
end

function swapblock(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock, dropbk::AbstractBlock, addmode)
    (dragbk == dropbk || isininnerblocks(dropbk, dragbk)) && return
    disable_drag(blocks, dragbk)
    if typeof(dropbk) in [SweepBlock, StrideCodeBlock] && unsafe_load(CImGui.GetIO().KeyCtrl)
        push!(dropbk.blocks, dragbk)
        return
    end
    insert_drop(blocks, dragbk, dropbk, addmode)
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

function insert_drop(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock, dropbk::AbstractBlock, addmode)
    for (i, bk) in enumerate(blocks)
        bk == dropbk && (insert!(blocks, addmode ? i + 1 : i, dragbk); return true)
        typeof(bk) in [SweepBlock, StrideCodeBlock] && insert_drop(bk.blocks, dragbk, dropbk, addmode) && return true
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
    U, _ = @c getU(Ut, &bk.ui)
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
            "\t", mlstr("step"), ": ", bk.step, U,
            "\t", mlstr("stop"), ": ", bk.stop, U,
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
    U, _ = @c getU(Ut, &bk.ui)
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
            "\t", mlstr("set value"), ": ", bk.setvalue, U
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
    CImGui.BeginChild("##QueryBlockViewer", (Float32(0), bkheight(bk)), true)
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
    CImGui.BeginChild("##ReadBlockViewer", (Float32(0), bkheight(bk)), true)
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

function view(bk::FeedbackBlock)
    CImGui.BeginChild("##FeedbackBlockViewer", (Float32(0), bkheight(bk)), true)
    CImGui.TextColored(MORESTYLE.Colors.BlockIcons, MORESTYLE.Icons.FeedbackBlock)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", bk.instrnm,
            "\t", mlstr("address"), ": ", bk.addr,
            "\t", mlstr("action"), ": ", bk.action
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.EndChild()
end

function view(blocks::Vector{AbstractBlock})
    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.NormalBlockBorder)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
    for (i, bk) in enumerate(blocks)
        bk isa NullBlock && continue
        CImGui.PushID(i)
        view(bk)
        CImGui.PopID()
    end
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
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
    Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
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
              unit : $U
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
    Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
    str = """
    SettingBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
         set value : $(bk.setvalue)
              unit : $U
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
function Base.show(io::IO, bk::FeedbackBlock)
    str = """
     FeedbackBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
            action : $(bk.action)
    """
    print(io, str)
end