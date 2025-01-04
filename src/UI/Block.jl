abstract type AbstractBlock end

struct NullBlock <: AbstractBlock end
skipnull(bkch::Vector{AbstractBlock}) = findall(bk -> !isa(bk, NullBlock), bkch)

@kwdef mutable struct CodeBlock <: AbstractBlock
    codes::String = ""
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct StrideCodeBlock <: AbstractBlock
    codes::String = ""
    level::Int = 1
    blocks::Vector{AbstractBlock} = AbstractBlock[]
    nohandler::Bool = false
    hideblocks::Bool = false
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct BranchBlock <: AbstractBlock
    codes::String = ""
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct SweepBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("sweep")
    step::String = ""
    stop::String = ""
    delay::Cfloat = 0.1
    ui::Int = 1
    rangemark::String = ""
    level::Int = 1
    blocks::Vector{AbstractBlock} = AbstractBlock[]
    istrycatch::Bool = true
    hideblocks::Bool = false
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct FreeSweepBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("sweep")
    mode::String = "="
    stop::String = ""
    delay::Cfloat = 0.1
    delta::Cfloat = 0
    duration::Cfloat = 6
    ui::Int = 1
    level::Int = 1
    blocks::Vector{AbstractBlock} = AbstractBlock[]
    istrycatch::Bool = true
    hideblocks::Bool = false
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct SettingBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("set")
    setvalue::String = ""
    delay::Cfloat = 0.1
    ui::Int = 1
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct ReadingBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    quantity::String = mlstr("read")
    index::String = ""
    mark::String = ""
    isasync::Bool = true
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct WriteBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    cmd::String = ""
    isasync::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct QueryBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    cmd::String = ""
    index::String = ""
    mark::String = ""
    isasync::Bool = true
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct ReadBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    index::String = ""
    mark::String = ""
    isasync::Bool = false
    isobserve::Bool = false
    isreading::Bool = false
    istrycatch::Bool = true
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

@kwdef mutable struct FeedbackBlock <: AbstractBlock
    instrnm::String = mlstr("instrument")
    addr::String = mlstr("address")
    action::String = mlstr("Pause")
    regmin::Vector{Cfloat} = [0, 0]
    regmax::Vector{Cfloat} = [0, 0]
end

iscontainer(bk::AbstractBlock) = typeof(bk) in [StrideCodeBlock, SweepBlock, FreeSweepBlock]
isinstr(bk::AbstractBlock) = typeof(bk) in [SweepBlock, FreeSweepBlock, SettingBlock, ReadingBlock, WriteBlock, QueryBlock, ReadBlock, FeedbackBlock]

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

tocodes(::NullBlock) = Expr(:block)

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
    instr = string(bk.instrnm, "/", bk.addr)
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
    satrt = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $start) : start
    Uchange = U isa Unitful.MixedUnits ? 1 : ustrip(Us[1], 1U)
    step = Expr(:call, :*, stepc, Uchange)
    stop = Expr(:call, :*, stopc, Uchange)
    innercodes = tocodes.(bk.blocks)
    isasync = false
    for inbk in bk.blocks
        typeof(inbk) in [ReadingBlock, WriteBlock, QueryBlock, ReadBlock] && inbk.isasync && (isasync = true; break)
    end
    interpcodes = isasync ? quote
        @sync begin
            $(innercodes...)
        end
    end : quote
        $(innercodes...)
    end
    @gensym ijk sweeplist
    setcmd = :(controllers[$instr]($setfunc, CPU, string($ijk), Val(:write)))
    ex2 = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $setcmd) : setcmd
    ex3 = quote
        @gencontroller SweepBlock $instr
        $ex2
        sleep($(bk.delay))
        $interpcodes
    end
    return if rstrip(bk.rangemark) == ""
        quote
            let $sweeplist = gensweeplist($start, $step, $stop)
                @progress for $ijk in $sweeplist
                    $ex3
                end
            end
        end
    else
        quote
            let $sweeplist = gensweeplist($start, $step, $stop)
                @progress $(bk.rangemark) for $ijk in $sweeplist
                    $ex3
                end
            end
        end
    end
end

function tocodes(bk::FreeSweepBlock)
    instr = string(bk.instrnm, "/", bk.addr)
    quantity = bk.quantity
    @assert INSCONF[bk.instrnm].quantities[bk.quantity].separator == "" mlstr("no free sweeping !!!")
    getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get)
    U, Us = @c getU(INSCONF[bk.instrnm].quantities[quantity].U, &bk.ui)
    U == "" && (@error "[$(now())]\n$(mlstr("input data error!!!"))" bk = bk;
    return)
    stopc = @trypass Meta.parse(bk.stop) begin
        @error "[$(now())]\n$(mlstr("codes are wrong in parsing time (FreeSweepBlock)!!!"))" bk = bk
        return nothing
    end
    Uchange = U isa Unitful.MixedUnits ? 1 : ustrip(Us[1], 1U)
    stop = Expr(:call, :*, stopc, Uchange)
    delta = bk.delta * Uchange
    innercodes = tocodes.(bk.blocks)
    isasync = false
    for inbk in bk.blocks
        typeof(inbk) in [ReadingBlock, WriteBlock, QueryBlock, ReadBlock] && inbk.isasync && (isasync = true; break)
    end
    interpcodes = isasync ? quote
        @sync begin
            $(innercodes...)
        end
    end : quote
        $(innercodes...)
    end
    @gensym observables
    getcmd = :(controllers[$instr]($getfunc, CPU, Val(:read)))
    getdata = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $getcmd) : getcmd
    detfunc = Dict("=" => isarrived, "<" => isless, ">" => isgreater)[bk.mode]
    return quote
        let $observables = []
            @progress $observables $getdata $stop $(bk.duration / 6) while !$detfunc($observables, $stop, $delta, $(bk.duration))
                @gencontroller SweepBlock $instr
                sleep($(bk.delay))
                $interpcodes
            end
        end
    end
end

function tocodes(bk::SettingBlock)
    instr = string(bk.instrnm, "/", bk.addr)
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
    return bk.istrycatch ? quote
        @gentrycatch $(bk.instrnm) $(bk.addr) $setcmd
        sleep($(bk.delay))
    end : quote
        $setcmd
        sleep($(bk.delay))
    end
end


tocodes(bk::ReadingBlock) = gencodes_read(bk)

function tocodes(bk::WriteBlock)
    instr = string(bk.instrnm, "/", bk.addr)
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
    instr = string(bk.instrnm, "/", bk.addr)
    quote
        if haskey(SWEEPCTS, $(bk.instrnm)) && haskey(SWEEPCTS[$(bk.instrnm)], $(bk.addr))
            for (sweeping, _) in values(SWEEPCTS[$(bk.instrnm)][$(bk.addr)])
                sweeping[] = false
            end
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
    instr = string(bk.instrnm, "/", bk.addr)
    index = @trypasse eval(Meta.parse(bk.index)) begin
        @error "[$(now())]\n$(mlstr("codes are wrong in parsing time (ReadingBlock)!!!"))" bk = bk
        return
    end
    index isa Integer && (index = [index])
    bk isa ReadingBlock && (getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get))
    bk isa QueryBlock && (cmd = parsedollar(bk.cmd))
    if isnothing(index) || (bk isa ReadingBlock && INSCONF[bk.instrnm].quantities[bk.quantity].separator == "")
        mark = parsedollar(replace(bk.mark, "/" => "_"))
        key = if bk isa ReadingBlock
            if mark isa Expr
                :(string($mark, "/", $(bk.instrnm), "/", $(bk.quantity), "/", $(bk.addr)))
            else
                string(mark, "/", bk.instrnm, "/", bk.quantity, "/", bk.addr)
            end
        else
            if mark isa Expr
                :(string($mark, "/", $(bk.instrnm), "/", $(bk.addr)))
            else
                string(mark, "/", bk.instrnm, "/", bk.addr)
            end
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
        marks = Vector{Union{AbstractString,Expr}}(undef, length(index))
        fill!(marks, "")
        for (i, v) in enumerate(split(bk.mark, ","))
            marks[i] = parsedollar(replace(v, "/" => "_"))
        end
        for (i, idx) in enumerate(index)
            marks[i] == "" && (marks[i] = "mark$idx")
        end
        keyall = if bk isa ReadingBlock
            if true in isa.(marks, Expr)
                [
                    :(string($mark, "/", $(bk.instrnm), "/", $(bk.quantity), "[", $ind, "]", "/", $(bk.addr)))
                    for (mark, ind) in zip(marks, index)
                ]
            else
                [
                    string(mark, "/", bk.instrnm, "/", bk.quantity, "[", ind, "]", "/", bk.addr)
                    for (mark, ind) in zip(marks, index)
                ]
            end
        else
            if true in isa.(marks, Expr)
                [
                    :(string($mark, "/", $(bk.instrnm), "[", $ind, "]", "/", $(bk.addr)))
                    for (mark, ind) in zip(marks, index)
                ]
            else
                [string(mark, "/", bk.instrnm, "[", ind, "]", "/", bk.addr) for (mark, ind) in zip(marks, index)]
            end
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
                for data in zip([$(keyall...)], $observable)
                    put!(databuf_lc, data)
                end
            end : :($observable = $getdata)
        else
            if bk.isasync
                return quote
                    @async for data in zip([$(keyall...)], $getdata)
                        put!(databuf_lc, data)
                    end
                end
            else
                return quote
                    for data in zip([$(keyall...)], $getdata)
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
                timesout::Ref{Int} = 1
                state, getval = counter(CONF.DAQ.retryconnecttimes + 1) do tout
                    timesout[] = tout
                    if tout > 1
                        @gencontroller(
                            $(mlstr("retry connecting to instrument")), string($instrnm, " ", $addr),
                            (false, $(len == 0 ? "" : fill("", len))), true
                        )
                    end
                    state, getval = counter(tout > 1 ? CONF.DAQ.retrysendtimes : 1) do tin
                        if tout > 1
                            @gencontroller(
                                $(mlstr("retry sending command")), string($instrnm, " ", $addr),
                                (false, $(len == 0 ? "" : fill("", len))), true
                            )
                            setbusy!(CPU)
                            unsetbusy!(CPU, $addr)
                        end
                        state, getval = try
                            true, $cmd
                        catch e
                            @error(
                                "[$(now())]\n$(mlstr("instrument communication failed!!!"))",
                                instrument = $(string(instrnm, ": ", addr)),
                                exception = e
                            )
                            showbacktrace()
                            println(LOGIO, "\n")
                            tout > 1 && @warn(
                                stcstr(
                                    "[", now(), "]\n",
                                    mlstr("retry sending command"), " ", tin, "\n",
                                    mlstr("retry reconnecting to instrument"), " ", tout - 1
                                ),
                                intrument = string($instrnm, "-", $addr)
                            )
                            false, $(len == 0 ? "" : fill("", len))
                        end
                        return state, getval
                    end
                    SYNCSTATES[Int(IsInterrupted)] && return state, getval
                    if !state
                        try
                            if tout == CONF.DAQ.retryconnecttimes + 1
                                reconnect!(CPU)
                            else
                                disconnect!(CPU.instrs[$addr])
                                connect!(CPU.resourcemanager, CPU.instrs[$addr])
                            end
                        catch
                        end
                    end
                    return state, getval
                end
                timesout[] == 1 || unsetbusy!(CPU)
                if SYNCSTATES[Int(IsInterrupted)]
                    @warn(
                        "[$(now())]\n$(mlstr("interrupt!"))",
                        $(mlstr("retry connecting and sending command")) = string($instrnm, " ", $addr)
                    )
                end
                state ? getval : error(string("instrument ", $instrnm, " ", $addr, " response time out!!!"))
            end
        end
    )
end

macro gencontroller(key, val, retval=nothing, quiet=false)
    esc(
        quote
            if SYNCSTATES[Int(IsInterrupted)]
                $quiet || @warn "[$(now())]\n$(mlstr("interrupt!"))" $key = $val
                return $retval
            elseif SYNCSTATES[Int(IsBlocked)]
                @warn "[$(now())]\n$(mlstr("pause!"))" $key = $val
                lock(() -> wait(BLOCK), BLOCK)
                @info "[$(now())]\n$(mlstr("continue!"))" $key = $val
            end
        end
    )
end

############macro block-------------------------------------------------------------------------------------------------
macro sweepblock(rangemark, instrnm, addr, qtnm, step, stop, u, delay, istrycatch, ex)
    esc(
        tocodes(
            SweepBlock(
                rangemark=rangemark,
                instrnm=instrnm,
                addr=addr,
                quantity=qtnm,
                step=step,
                stop=stop,
                delay=delay,
                ui=utoui(instrnm, qtnm, u),
                istrycatch=istrycatch,
                blocks=CodeBlock(codes=string(ex))
            )
        )
    )
end


macro freesweepblock(instrnm, addr, qtnm, mode, stop, u, delta, duration, delay, istrycatch, ex)
    esc(
        tocodes(
            FreeSweepBlock(
                instrnm=instrnm,
                addr=addr,
                quantity=qtnm,
                mode=mode,
                stop=stop,
                delay=delay,
                delta=delta,
                duration=duration,
                ui=utoui(instrnm, qtnm, u),
                istrycatch=istrycatch,
                blocks=CodeBlock(codes=string(ex))
            )
        )
    )
end

macro settingblock(instrnm, addr, qtnm, sv, u, delay, istrycatch)
    esc(
        tocodes(
            SettingBlock(
                instrnm=instrnm,
                addr=addr,
                quantity=qtnm,
                setvalue=sv,
                delay=delay,
                ui=utoui(instrnm, qtnm, u),
                istrycatch=istrycatch
            )
        )
    )
end

macro readingblock(instrnm, addr, qtnm, index, mark, isasync, isobserve, isreading, istrycatch)
    esc(
        tocodes(
            ReadingBlock(
                instrnm=instrnm,
                addr=addr,
                quantity=qtnm,
                index=index,
                mark=mark,
                isasync=isasync,
                isobserve=isobserve,
                isreading=isreading,
                istrycatch=istrycatch
            )
        )
    )
end

macro writeblock(instrnm, addr, cmd, isasync, istrycatch)
    esc(tocodes(WriteBlock(instrnm=instrnm, addr=addr, cmd=cmd, isasync=isasync, istrycatch=istrycatch)))
end

macro readblock(instrnm, addr, index, mark, isasync, isobserve, isreading, istrcatch)
    esc(
        tocodes(
            ReadBlock(
                instrnm=instrnm,
                addr=addr,
                index=index,
                mark=mark,
                isasync=isasync,
                isobserve=isobserve,
                isreading=isreading,
                istrycatch=istrycatch
            )
        )
    )
end

macro queryblock(instrnm, addr, cmd, index, mark, isasync, isobserve, isreading, istrcatch)
    esc(
        tocodes(
            QueryBlock(
                instrnm=instrnm,
                addr=addr,
                cmd=cmd,
                index=index,
                mark=mark,
                isasync=isasync,
                isobserve=isobserve,
                isreading=isreading,
                istrycatch=istrycatch
            )
        )
    )
end

macro feedbackblock(instrnm, addr, action)
    esc(tocodes(FeedbackBlock(instrnm=instrnm, addr=addr, action=action)))
end

function utoui(instrnm, qtnm, u)
    utype = haskey(INSCONF, instrnm) && haskey(INSCONF[instrnm].quantities, qtnm) ? INSCONF[instrnm].quantities[qtnm].U : ""
    Us = haskey(CONF.U, utype) ? CONF.U[utype] : [""]
    return u in Us ? findfirst(==(u), Us) : 1
end
############functionality-----------------------------------------------------------------------------------------------
macro logblock()
    esc(
        :(timed_remotecall_wait(eval, 1, :(log_instrbufferviewers()); timeout=60))
    )
end

macro saveblock(key, var)
    esc(
        :(put!(databuf_lc, ($key, string($var))))
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

############compile-----------------------------------------------------------------------------------------------------
function compile(blocks::Vector{AbstractBlock})
    return quote
        function remote_sweep_block(controllers, databuf_lc, progress_lc, extradatabuf_lc, SYNCSTATES)
            $(tocodes.(blocks)...)
        end
    end
end

############interpret----------------------------------------------------------------------------------
interpret(blocks::Vector{AbstractBlock}) = quote
    $(interpret.(blocks)...)
end
interpret(::NullBlock) = Expr(:block)
interpret(bk::CodeBlock) = tocodes(bk)
function interpret(bk::StrideCodeBlock)
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
                    $(interpret.(bk.blocks[branch_idx[i]+1:branch_idx[i+1]-1])...)
                end
            end : quote
                $(interpret.(bk.blocks[branch_idx[i]+1:branch_idx[i+1]-1])...)
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

function interpret(bk::SweepBlock)
    utype = haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity) ? INSCONF[bk.instrnm].quantities[bk.quantity].U : ""
    u, _ = @c getU(utype, &bk.ui)
    quote
        @sweepblock $(bk.rangemark) $(bk.instrnm) $(bk.addr) $(bk.quantity) $(bk.step) $(bk.stop) $u $(bk.delay) $(bk.istrycatch) begin
            $(interpret.(bk.blocks)...)
        end
    end
end
function interpret(bk::FreeSweepBlock)
    utype = haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity) ? INSCONF[bk.instrnm].quantities[bk.quantity].U : ""
    u, _ = @c getU(utype, &bk.ui)
    quote
        @freesweepblock $(bk.instrnm) $(bk.addr) $(bk.quantity) $(bk.mode) $(bk.stop) $u $(bk.delta) $(bk.duration) $(bk.delay) $(bk.istrycatch) begin
            $(interpret.(bk.blocks)...)
        end
    end
end
function interpret(bk::SettingBlock)
    utype = haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity) ? INSCONF[bk.instrnm].quantities[bk.quantity].U : ""
    u, _ = @c getU(utype, &bk.ui)
    :(@settingblock $(bk.instrnm) $(bk.addr) $(bk.quantity) $(bk.setvalue) $u $(bk.delay) $(bk.istrycatch))
end
function interpret(bk::ReadingBlock)
    :(@readingblock $(bk.instrnm) $(bk.addr) $(bk.quantity) $(bk.index) $(bk.mark) $(bk.isasync) $(bk.isobserve) $(bk.isreading) $(bk.istrycatch))
end
function interpret(bk::WriteBlock)
    :(@writeblock $(bk.instrnm) $(bk.addr) $(bk.cmd) $(bk.isasync) $(bk.istrycatch))
end
function interpret(bk::ReadBlock)
    :(@readblock $(bk.instrnm) $(bk.addr) $(bk.index) $(bk.mark) $(bk.isasync) $(bk.isobserve) $(bk.isreading) $(bk.istrycatch))
end
function interpret(bk::QueryBlock)
    :(@queryblock $(bk.instrnm) $(bk.addr) $(bk.cmd) $(bk.index) $(bk.mark) $(bk.isasync) $(bk.isobserve) $(bk.isreading) $(bk.istrycatch))
end
function interpret(bk::FeedbackBlock)
    :(@feedbackblock $(bk.instrnm) $(bk.addr) $(bk.action))
end
############anti-interpret----------------------------------------------------------------------------------------------
function antiinterpretblocks(ex)
    bk = antiinterpret(ex)
    return checkblocks!(bk isa StrideCodeBlock && bk.codes == "begin" ? bk.blocks : AbstractBlock[bk])
end
function checkblocks!(blocks::Vector{AbstractBlock}, level=1)
    joinablebk = []
    joining = false
    for (i, bk) in enumerate(blocks)
        if bk isa CodeBlock
            joining || (joining = true; push!(joinablebk, [i]))
        else
            joining && (joining = false; push!(joinablebk[end], i - 1))
            iscontainer(bk) && (bk.level = level; checkblocks!(bk.blocks, level + 1))
            if bk isa StrideCodeBlock && !isempty(bk.blocks)
                if bk.blocks[1] isa StrideCodeBlock &&
                   (
                    bk.blocks[1].codes == "begin" ||
                    bk.blocks[1].codes == "@sync begin" && length(bk.blocks) == 1 &&
                    count(x -> x in [ReadingBlock, ReadBlock, QueryBlock], typeof.(bk.blocks[1].blocks)) > 0
                )
                    bk.blocks[1].codes == "begin" && (bk.nohandler = bk.blocks[1].nohandler)
                    inbks = bk.blocks[1].blocks
                    deleteat!(bk.blocks, 1)
                    prepend!(bk.blocks, inbks)
                end
                if BranchBlock in typeof.(bk.blocks)
                    for _ in 1:count(==(BranchBlock), typeof.(bk.blocks))
                        for (j, inbk) in enumerate(bk.blocks)
                            if inbk isa BranchBlock && j < length(bk.blocks) && bk.blocks[j+1] isa StrideCodeBlock &&
                               (
                                   bk.blocks[j+1].codes == "begin" ||
                                   bk.blocks[j+1].codes == "@sync begin" && (j + 1 == length(bk.blocks) || bk.blocks[j+2] isa BranchBlock) &&
                                   count(x -> x in [ReadingBlock, ReadBlock, QueryBlock], typeof.(bk.blocks[j+1].blocks)) > 0
                               )
                                inbks = bk.blocks[j+1].blocks
                                deleteat!(bk.blocks, j + 1)
                                for (k, b) in enumerate(inbks)
                                    insert!(bk.blocks, j + k, b)
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    joining && (joining = false; push!(joinablebk[end], length(blocks)))
    for (i, j) in joinablebk
        i == j && continue
        jointbk = CodeBlock(codes=join([bk.codes for bk in blocks[i:j]], "\n"))
        deleteat!(blocks, i:j)
        insert!(blocks, i, jointbk)
        for ij in joinablebk
            ij .- (j - i)
        end
    end
    return blocks
end
antiinterpret(ex) = CodeBlock(codes=string(ex))
function antiinterpret(ex::Expr)
    ex.head == :toplevel && (ex.head = :block)
    pex = prettify(ex)
    return antiinterpret(pex, Val(pex.head))
end
antiinterpret(ex, ::Val) = CodeBlock(codes=string(ex))
function antiinterpret(ex, ::Val{:block})
    isempty(ex.args) && return NullBlock()
    blocks = antiinterpret.(ex.args)
    return if all(x -> x isa CodeBlock, blocks)
        codesvec = split(string(ex), "\n")
        for i in eachindex(codesvec)
            codesvec[i] = codesvec[i][5:end]
        end
        CodeBlock(codes=join(codesvec[2:end-1], "\n"))
    else
        bk1 = blocks[1]
        nohandler = !(bk1 isa CodeBlock && @capture(tocodes(bk1), @gencontroller kv__))
        StrideCodeBlock(codes="begin", blocks=nohandler ? blocks : blocks[2:end], nohandler=nohandler)
    end
end
function antiinterpret(ex, ::Val{:for})
    bk = antiinterpret(ex.args[2])
    return if bk isa CodeBlock
        CodeBlock(codes=string(ex))
    else
        StrideCodeBlock(codes=string("for ", ex.args[1]), blocks=[bk], nohandler=true)
    end
end
function antiinterpret(ex, ::Val{:while})
    bk = antiinterpret(ex.args[2])
    return if bk isa CodeBlock
        CodeBlock(codes=string(ex))
    else
        StrideCodeBlock(codes=string("while ", ex.args[1]), blocks=[bk], nohandler=true)
    end
end
function antiinterpret(ex, ::Val{:let})
    bk = antiinterpret(ex.args[2])
    return if bk isa CodeBlock
        CodeBlock(codes=string(ex))
    else
        codes = ex.args[1].head == :block ? "let" : string("let ", ex.args[1])
        StrideCodeBlock(codes=codes, blocks=[bk], nohandler=true)
    end
end
function antiinterpret(ex, ::Val{:function})
    bk = antiinterpret(ex.args[2])
    return if bk isa CodeBlock
        CodeBlock(codes=string(ex))
    else
        StrideCodeBlock(codes=string("function ", ex.args[1]), blocks=[bk], nohandler=true)
    end
end
function antiinterpret(ex, ::Val{:if})
    blocks = AbstractBlock[antiinterpret(ex.args[2])]
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            append!(blocks, antiinterpret(ex.args[3], Val(:elseif)))
        else
            push!(blocks, BranchBlock(codes="else"))
            push!(blocks, antiinterpret(ex.args[3]))
        end
    end
    return if all(x -> x isa CodeBlock || x isa BranchBlock, blocks)
        CodeBlock(codes=string(ex))
    else
        StrideCodeBlock(codes=string("if ", ex.args[1]), blocks=blocks, nohandler=true)
    end
end
function antiinterpret(ex, ::Val{:elseif})
    blocks = AbstractBlock[BranchBlock(codes=string("elseif ", ex.args[1]))]
    push!(blocks, antiinterpret(ex.args[2]))
    return if length(ex.args) == 2
        blocks
    elseif length(ex.args) == 3
        if ex.args[3].head == :elseif
            append!(blocks, antiinterpret(ex.args[3], Val(:elseif)))
        else
            push!(blocks, BranchBlock(codes="else"))
            push!(blocks, antiinterpret(ex.args[3]))
        end
    end
    return blocks
end
function antiinterpret(ex, ::Val{:try})
    blocks = AbstractBlock[antiinterpret(ex.args[1])]
    push!(blocks, BranchBlock(codes=string("catch ", ex.args[2])))
    push!(blocks, antiinterpret(ex.args[3]))
    if length(ex.args) == 4
        push!(blocks, BranchBlock(codes="finally"))
        push!(blocks, antiinterpret(ex.args[4]))
    end
    return if all(x -> x isa CodeBlock || x isa BranchBlock, blocks)
        CodeBlock(codes=string(ex))
    else
        StrideCodeBlock(codes="try", blocks=blocks, nohandler=true)
    end
end
function antiinterpret(ex, ::Val{:macrocall})
    blockmacros = Symbol.(
        [
        "@sweepblock", "@freesweepblock", "@settingblock", "@readingblock",
        "@writeblock", "@readblock", "@queryblock", "@feedbackblock"
    ]
    )
    ex.args[1] in blockmacros && return antiinterpret(ex, Val(Symbol(lstrip(string(ex.args[1]), '@'))))
    isok1 = @capture ex @m1__ @m_ p__
    isok1 && m in blockmacros && return StrideCodeBlock(
            codes=string(join(m1, " "), " begin"),
            blocks=[antiinterpret(Expr(:macrocall, m, nothing, p...), Val(Symbol(lstrip(string(m), '@'))))],
            nohandler=true
        )
    isok2 = false
    isok1 || (isok2 = @capture ex @m_ p__)
    if isok1 || isok2
        isok1 && m1[end] == m == Symbol("@sync") && return antiinterpret(Meta.parse(join(vcat(m1, p), " ")))
        if isempty(p)
            return CodeBlock(codes=string(ex))
        else
            p[end] isa Expr && p[end].head in [:block, :for, :while, :let, :function, :if, :try]
            bk = antiinterpret(p[end])
            return if bk isa CodeBlock
                CodeBlock(codes=string(ex))
            else
                codes = string(
                    join(vcat(isok1 ? m1 : [], [m], p[1:end-1]), " "), " ",
                    if p[end].head in [:for, :while, :function, :if]
                        string(p[end].head, " ", p[end].args[1])
                    elseif p[end].head == :block
                        "begin"
                    elseif p[end].head == :let
                        ex.args[1].head == :block ? "let" : string("let ", ex.args[1])
                    elseif p[end].head == :try
                        "try"
                    end
                )
                StrideCodeBlock(codes=codes, blocks=bk.blocks, nohandler=bk.nohandler)
            end
        end
    end
    return CodeBlock(codes=string(ex))
end
antiinterpret(ex, ::Val{:sweepblock}) = SweepBlock(
    rangemark=ex.args[3],
    instrnm=ex.args[4],
    addr=ex.args[5],
    quantity=ex.args[6],
    step=ex.args[7],
    stop=ex.args[8],
    ui=utoui(ex.args[4], ex.args[6], strtoU(string(ex.args[9]))),
    delay=ex.args[10],
    istrycatch=ex.args[11],
    blocks=(bk = antiinterpret(ex.args[12]); iscontainer(bk) ? bk.blocks : [bk])
)
antiinterpret(ex, ::Val{:freesweepblock}) = FreeSweepBlock(
    instrnm=ex.args[3],
    addr=ex.args[4],
    quantity=ex.args[5],
    mode=string(ex.args[6]),
    stop=ex.args[7],
    ui=utoui(ex.args[3], ex.args[5], strtoU(string(ex.args[8]))),
    delta=ex.args[9],
    duration=ex.args[10],
    delay=ex.args[11],
    istrycatch=ex.args[12],
    blocks=(bk = antiinterpret(ex.args[13]); iscontainer(bk) ? bk.blocks : [bk])
)
antiinterpret(ex, ::Val{:settingblock}) = SettingBlock(
    instrnm=ex.args[3],
    addr=ex.args[4],
    quantity=ex.args[5],
    setvalue=ex.args[6],
    ui=utoui(ex.args[3], ex.args[5], strtoU(string(ex.args[7]))),
    delay=ex.args[8],
    istrycatch=ex.args[9]
)
antiinterpret(ex, ::Val{:readingblock}) = ReadingBlock(
    instrnm=ex.args[3],
    addr=ex.args[4],
    quantity=ex.args[5],
    index=ex.args[6],
    mark=ex.args[7],
    isasync=ex.args[8],
    isobserve=ex.args[9],
    isreading=ex.args[10],
    istrycatch=ex.args[11]
)
antiinterpret(ex, ::Val{:writeblock}) = WriteBlock(
    instrnm=ex.args[3],
    addr=ex.args[4],
    cmd=ex.args[5],
    isasync=ex.args[6],
    istrycatch=ex.args[7]
)
antiinterpret(ex, ::Val{:readblock}) = ReadBlock(
    instrnm=ex.args[3],
    addr=ex.args[4],
    index=ex.args[5],
    mark=ex.args[6],
    isasync=ex.args[7],
    isobserve=ex.args[8],
    isreading=ex.args[9],
    istrycatch=ex.args[10]
)
antiinterpret(ex, ::Val{:queryblock}) = QueryBlock(
    instrnm=ex.args[3],
    addr=ex.args[4],
    cmd=ex.args[5],
    index=ex.args[6],
    mark=ex.args[7],
    isasync=ex.args[8],
    isobserve=ex.args[9],
    isreading=ex.args[10],
    istrycatch=ex.args[11]
)
antiinterpret(ex, ::Val{:feedbackblock}) = FeedbackBlock(
    instrnm=ex.args[3],
    addr=ex.args[4],
    action=ex.args[5]
)
############bkheight----------------------------------------------------------------------------------------------------

bkheight(::NullBlock) = zero(Float32)
function bkheight(bk::CodeBlock)
    (1 + length(findall("\n", bk.codes))) * CImGui.GetTextLineHeight() +
    2unsafe_load(IMGUISTYLE.FramePadding.y) +
    2unsafe_load(IMGUISTYLE.WindowPadding.y) + 1
end
function bkheight(bk::Union{StrideCodeBlock,SweepBlock,FreeSweepBlock})
    return isempty(skipnull(bk.blocks)) ? 2unsafe_load(IMGUISTYLE.WindowPadding.y) + CImGui.GetFrameHeight() :
           bk.hideblocks ? 2MORESTYLE.Variables.ContainerBlockWindowPadding[2] + CImGui.GetFrameHeight() :
           2MORESTYLE.Variables.ContainerBlockWindowPadding[2] +
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
    wp = unsafe_load(IMGUISTYLE.WindowPadding)
    bkh = bkheight(bk)
    CImGui.PushStyleVar(
        CImGui.ImGuiStyleVar_WindowPadding,
        bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
    )
    CImGui.BeginChild("##StrideCodeBlock", (Float32(0), bkh), true)
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
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
    bk.hideblocks || isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar()
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
        wp = unsafe_load(IMGUISTYLE.WindowPadding)
        bkh = bkheight(bk)
        CImGui.PushStyleVar(
            CImGui.ImGuiStyleVar_WindowPadding,
            bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
        )
        CImGui.BeginChild("##SweepBlock", (Float32(0), bkh), true)
        CImGui.PopStyleVar()
        CImGui.TextColored(
            bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
            bk.rangemark == "" ? MORESTYLE.Icons.SweepBlock : bk.rangemark
        )
        CImGui.IsItemClicked(2) && (bk.istrycatch ⊻= true)
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
        CImGui.SameLine()
        width = (CImGui.GetContentRegionAvail().x - 3CImGui.GetFontSize()) / 5
        CImGui.PushItemWidth(width)
        inses = sort([ins for ins in keys(INSCONF) if haskey(INSTRBUFFERVIEWERS, ins) && !isempty(INSTRBUFFERVIEWERS[ins])])
        @c ComboSFiltered("##SweepBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
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
        CImGui.PushItemWidth(width * 3 / 4 - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c InputTextWithHintRSZ("##SweepBlock stop", mlstr("stop"), &bk.stop)
        CImGui.PopItemWidth()
        CImGui.SameLine()

        Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
            INSCONF[bk.instrnm].quantities[bk.quantity].U
        else
            ""
        end
        CImGui.PushItemWidth(width / 2 - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c ShowUnit("##SweepBlock", Ut, &bk.ui)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(-1)
        @c CImGui.DragFloat("##SweepBlock delay", &bk.delay, 0.01, 0, 9.99, "%g", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()

        CImGui.PopStyleColor()
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
        bk.hideblocks || isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
        CImGui.EndChild()
        CImGui.PopStyleVar(2)
    end
end

let
    filter::String = ""
    global function edit(bk::FreeSweepBlock)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, (Float32(2), unsafe_load(IMGUISTYLE.ItemSpacing.y)))
        CImGui.PushStyleColor(
            CImGui.ImGuiCol_Border,
            if isempty(skipnull(bk.blocks))
                CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
            else
                ImVec4(MORESTYLE.Colors.SweepBlockBorder...)
            end
        )
        wp = unsafe_load(IMGUISTYLE.WindowPadding)
        bkh = bkheight(bk)
        CImGui.PushStyleVar(
            CImGui.ImGuiStyleVar_WindowPadding,
            bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
        )
        CImGui.BeginChild("##FreeSweepBlock", (Float32(0), bkh), true)
        CImGui.PopStyleVar()
        CImGui.TextColored(
            bk.istrycatch ? MORESTYLE.Colors.BlockTrycatch : MORESTYLE.Colors.BlockIcons,
            MORESTYLE.Icons.FreeSweepBlock
        )
        CImGui.IsItemClicked(2) && (bk.istrycatch ⊻= true)
        CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
        CImGui.SameLine()
        width = (CImGui.GetContentRegionAvail().x - 3CImGui.GetFontSize()) / 5
        CImGui.PushItemWidth(width)
        inses = sort([ins for ins in keys(INSCONF) if haskey(INSTRBUFFERVIEWERS, ins) && !isempty(INSTRBUFFERVIEWERS[ins])])
        @c ComboSFiltered("##FreeSweepBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine()

        inlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) && haskey(INSTRBUFFERVIEWERS[bk.instrnm], bk.addr)
        bk.addr = inlist ? bk.addr : mlstr("address")
        addrlist = haskey(INSTRBUFFERVIEWERS, bk.instrnm) ? keys(INSTRBUFFERVIEWERS[bk.instrnm]) : Set{String}()
        CImGui.PushItemWidth(width)
        @c ComboS("##FreeSweepBlock address", &bk.addr, sort(collect(addrlist)), CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine()

        showqt = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
            INSCONF[bk.instrnm].quantities[bk.quantity].alias
        else
            mlstr("sweep")
        end
        CImGui.PushItemWidth(width)
        if CImGui.BeginCombo("##FreeSweepBlock sweep", showqt, CImGui.ImGuiComboFlags_NoArrowButton)
            qtlist = haskey(INSCONF, bk.instrnm) ? keys(INSCONF[bk.instrnm].quantities) : Set{String}()
            qts = collect(qtlist)
            @c InputTextWithHintRSZ("##FreeSweepBlock sweep", mlstr("Filter"), &filter)
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

        CImGui.PushItemWidth(width / 4 - unsafe_load(IMGUISTYLE.ItemSpacing.x) / 2)
        @c ComboS("##FreeSweepBlock mode", &bk.mode, ["=", "<", ">"], CImGui.ImGuiComboFlags_NoArrowButton)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(width / 2 - unsafe_load(IMGUISTYLE.ItemSpacing.x) / 2)
        @c InputTextWithHintRSZ("##FreeSweepBlock stop", mlstr("stop"), &bk.stop)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(width / 2 - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c CImGui.InputFloat("##FreeSweepBlock delta", &bk.delta, 0, 0, "%g")
        CImGui.PopItemWidth()
        CImGui.SameLine()
        Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
            INSCONF[bk.instrnm].quantities[bk.quantity].U
        else
            ""
        end
        CImGui.PushItemWidth(width / 2 - unsafe_load(IMGUISTYLE.ItemSpacing.x))
        @c ShowUnit("##FreeSweepBlock", Ut, &bk.ui)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(width / 4)
        @c CImGui.DragFloat("##FreeSweepBlock duration", &bk.duration, 1, 1, 3600, "%g", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(-1)
        @c CImGui.DragFloat("##FreeSweepBlock delay", &bk.delay, 0.01, 0, 9.99, "%g", CImGui.ImGuiSliderFlags_AlwaysClamp)
        CImGui.PopItemWidth()

        CImGui.PopStyleColor()
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
        bk.hideblocks || isempty(skipnull(bk.blocks)) || edit(bk.blocks, bk.level + 1)
        CImGui.EndChild()
        CImGui.PopStyleVar(2)
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
        width = (CImGui.GetContentRegionAvail().x - 3CImGui.GetFontSize()) / 5
        CImGui.PushItemWidth(width)
        inses = sort([ins for ins in keys(INSCONF) if haskey(INSTRBUFFERVIEWERS, ins) && !isempty(INSTRBUFFERVIEWERS[ins])])
        @c ComboSFiltered("##SettingBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
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
        CImGui.PushItemWidth(3width / 2)
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
        CImGui.PushItemWidth(width / 2)
        @c ShowUnit("SettingBlock", Ut, &bk.ui)
        CImGui.PopItemWidth()
        CImGui.SameLine()
        CImGui.PushItemWidth(-1)
        @c CImGui.DragFloat("##SettingBlock delay", &bk.delay, 0.01, 0, 9.99, "%g", CImGui.ImGuiSliderFlags_AlwaysClamp)
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
        width = (CImGui.GetContentRegionAvail().x - 2CImGui.GetFontSize()) / 5
        CImGui.PushItemWidth(width)
        inses = sort([ins for ins in keys(INSCONF) if haskey(INSTRBUFFERVIEWERS, ins) && !isempty(INSTRBUFFERVIEWERS[ins])])
        @c ComboSFiltered("##ReadingBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
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
    width = (CImGui.GetContentRegionAvail().x - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    inses = sort([ins for ins in keys(INSCONF) if haskey(INSTRBUFFERVIEWERS, ins) && !isempty(INSTRBUFFERVIEWERS[ins])])
    @c ComboSFiltered("##WriteBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
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
    width = (CImGui.GetContentRegionAvail().x - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    inses = sort([ins for ins in keys(INSCONF) if haskey(INSTRBUFFERVIEWERS, ins) && !isempty(INSTRBUFFERVIEWERS[ins])])
    @c ComboSFiltered("##QueryBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
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
    width = (CImGui.GetContentRegionAvail().x - 2CImGui.GetFontSize()) / 5
    CImGui.PushItemWidth(width)
    inses = sort([ins for ins in keys(INSCONF) if haskey(INSTRBUFFERVIEWERS, ins) && !isempty(INSTRBUFFERVIEWERS[ins])])
    @c ComboSFiltered("##ReadBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
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
        width = (CImGui.GetContentRegionAvail().x - 2CImGui.GetFontSize()) / 3
        CImGui.PushItemWidth(width)
        inses = sort([ins for ins in keys(INSCONF) if haskey(INSTRBUFFERVIEWERS, ins) && !isempty(INSTRBUFFERVIEWERS[ins])])
        @c ComboSFiltered("##FeedbackBlock instrument", &bk.instrnm, inses, CImGui.ImGuiComboFlags_NoArrowButton)
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
    allblocks::Vector{Symbol} = [:CodeBlock, :StrideCodeBlock, :BranchBlock, :SweepBlock, :FreeSweepBlock,
        :SettingBlock, :ReadingBlock, :WriteBlock, :QueryBlock, :ReadBlock, :FeedbackBlock]

    global function dragblockmenu(id)
        presentid = id
        CImGui.PushFont(BIGFONT)
        ftsz = CImGui.GetFontSize()
        lbk = length(allblocks)
        availw = CImGui.GetContentRegionAvail().x / lbk - unsafe_load(IMGUISTYLE.ItemSpacing.x)
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
            CImGui.AddRectFilled(draw_list, rmin, rmax, MORESTYLE.Colors.BlockDragdrop)
            CImGui.AddText(
                draw_list,
                rmin .+ CImGui.ImVec2(ftsz / 2, ftsz / 2),
                MORESTYLE.Colors.HighlightText,
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
                CImGui.AddRectFilled(draw_list, bk.regmin, bk.regmax, MORESTYLE.Colors.BlockDragdrop, 0.0, 0)
                CImGui.PopStyleColor()
            end
            CImGui.PushID(i)
            edit(bk)
            id = stcstr(CImGui.igGetItemID())
            if iscontainer(bk)
                bk.regmin, rmax = CImGui.GetItemRectMin(), CImGui.GetItemRectMax()
                wph = unsafe_load(IMGUISTYLE.WindowPadding.y)
                extraheight = isempty(bk.blocks) ? 2wph : MORESTYLE.Variables.ContainerBlockWindowPadding[2] + unsafe_load(IMGUISTYLE.ItemSpacing.y) / 2
                bk.regmax = [rmax[1], bk.regmin[2] + CImGui.GetFrameHeight() + extraheight]
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
                if iscontainer(bk) && isempty(skipnull(bk.blocks))
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
                            iscontainer(bk) && (newblock.blocks = bk.blocks)
                        elseif iscontainer(newblock) && isinstr(newblock)
                            if bk isa StrideCodeBlock
                                newblock.blocks = bk.blocks
                            elseif iscontainer(bk) && isinstr(bk)
                                newblock.instrnm = bk.instrnm
                                newblock.addr = bk.addr
                                newblock.blocks = bk.blocks
                            elseif isinstr(bk)
                                newblock.instrnm = bk.instrnm
                                newblock.addr = bk.addr
                            end
                        elseif isinstr(newblock)
                            isinstr(bk) && (newblock.instrnm = bk.instrnm; newblock.addr = bk.addr)
                        end
                        blocks[i] = newblock
                    end
                    CImGui.EndMenu()
                end
                CImGui.Separator()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Copy, " ", mlstr("Copy"))) && (copyblock = deepcopy(blocks[i]))
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Paste, " ", mlstr("Paste"))) && insert!(blocks, i + 1, deepcopy(copyblock))
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete"))) && (blocks[i] = NullBlock())
                if typeof(bk) in [CodeBlock, StrideCodeBlock]
                    CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Clear"))) && (bk.codes = "")
                end
                ### specific menu for blocks
                if bk isa SweepBlock
                    CImGui.Separator()
                    @c InputTextRSZ(mlstr("Mark"), &bk.rangemark)
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
    CImGui.MenuItem(stcstr(MORESTYLE.Icons.FreeSweepBlock, " ", mlstr("FreeSweepBlock"))) && return FreeSweepBlock(level=n)
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
    if iscontainer(dropbk) && unsafe_load(CImGui.GetIO().KeyCtrl)
        push!(dropbk.blocks, dragbk)
        return
    end
    insert_drop(blocks, dragbk, dropbk, addmode)
end

function isininnerblocks(dropbk::AbstractBlock, dragbk::AbstractBlock)
    if iscontainer(dragbk)
        return dropbk in dragbk.blocks || true in [isininnerblocks(dropbk, bk) for bk in dragbk.blocks]
    else
        return false
    end
end

function disable_drag(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock)
    for (i, bk) in enumerate(blocks)
        bk == dragbk && (blocks[i] = NullBlock(); return true)
        iscontainer(bk) && disable_drag(bk.blocks, dragbk) && return true
    end
    return false
end

function insert_drop(blocks::Vector{AbstractBlock}, dragbk::AbstractBlock, dropbk::AbstractBlock, addmode)
    for (i, bk) in enumerate(blocks)
        bk == dropbk && (insert!(blocks, addmode ? i + 1 : i, dragbk); return true)
        iscontainer(bk) && insert_drop(bk.blocks, dragbk, dropbk, addmode) && return true
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
    wp = unsafe_load(IMGUISTYLE.WindowPadding)
    bkh = bkheight(bk)
    CImGui.PushStyleVar(
        CImGui.ImGuiStyleVar_WindowPadding,
        bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
    )
    CImGui.BeginChild("##StrideCodeBlockViewer", (Float32(0), bkh), true)
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
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
    bk.hideblocks || isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar()
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
    wp = unsafe_load(IMGUISTYLE.WindowPadding)
    bkh = bkheight(bk)
    CImGui.PushStyleVar(
        CImGui.ImGuiStyleVar_WindowPadding,
        bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
    )
    CImGui.BeginChild("##SweepBlockViewer", (Float32(0), bkh), true)
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
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
    bk.hideblocks || isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar()
end

function view(bk::FreeSweepBlock)
    CImGui.PushStyleColor(
        CImGui.ImGuiCol_Border,
        if isempty(skipnull(bk.blocks))
            CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_Border)
        else
            MORESTYLE.Colors.SweepBlockBorder
        end
    )
    wp = unsafe_load(IMGUISTYLE.WindowPadding)
    bkh = bkheight(bk)
    CImGui.PushStyleVar(
        CImGui.ImGuiStyleVar_WindowPadding,
        bk.hideblocks || isempty(skipnull(bk.blocks)) ? wp : MORESTYLE.Variables.ContainerBlockWindowPadding
    )
    CImGui.BeginChild("##FreeSweepBlockViewer", (Float32(0), bkh), true)
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
        MORESTYLE.Icons.FreeSweepBlock
    )
    CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0) && (bk.hideblocks ⊻= true)
    CImGui.SameLine()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ButtonTextAlign, (0.0, 0.5))
    CImGui.Button(
        stcstr(
            mlstr("instrument"), ": ", instrnm,
            "\t", mlstr("address"), ": ", addr,
            "\t", mlstr("sweep"), ": ", quantity,
            "\t", mlstr("stop"), ": ", bk.mode, " ", bk.stop, U,
            "\t", mlstr("delay"), ": ", bk.delay,
            "\t", mlstr("δ"), ": ", bk.delta,
            "\t", mlstr("duration"), ": ", bk.duration
        ),
        (-1, 0)
    )
    CImGui.PopStyleVar()
    CImGui.PopStyleColor()
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, wp)
    bk.hideblocks || isempty(skipnull(bk.blocks)) || view(bk.blocks)
    CImGui.PopStyleVar()
    CImGui.EndChild()
    CImGui.PopStyleVar()
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
function Base.show(io::IO, bk::FreeSweepBlock)
    Ut = if haskey(INSCONF, bk.instrnm) && haskey(INSCONF[bk.instrnm].quantities, bk.quantity)
        INSCONF[bk.instrnm].quantities[bk.quantity].U
    else
        ""
    end
    U, _ = @c getU(Ut, &bk.ui)
    str = """
    FreeSweepBlock :
        region min : $(bk.regmin)
        region max : $(bk.regmax)
             level : $(bk.level)
        instrument : $(bk.instrnm)
           address : $(bk.addr)
          quantity : $(bk.quantity)
              stop : $(bk.mode) $(bk.stop)
             delta : $(bk.delta)
          duration : $(bk.duration)
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
             delay : $(bk.delay)
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