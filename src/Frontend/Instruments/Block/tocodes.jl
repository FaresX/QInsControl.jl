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
    timeoutw = INSTRCONF[bk.instrnm].quantities[quantity].timeoutw
    timeoutr = INSTRCONF[bk.instrnm].quantities[quantity].timeoutr
    U, Us = @c getU(INSTRCONF[bk.instrnm].quantities[quantity].U, &bk.ui)
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
    start = :(parse(Float64, controllers[$instr]($getfunc, CPU, Val(:read); timeout=$timeoutr)))
    start = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $start $(CONF.DAQ.retrysendtimes) $(CONF.DAQ.retryconnecttimes)) : start
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
    setcmd = :(controllers[$instr]($setfunc, CPU, string($ijk), Val(:write); timeout=$timeoutw))
    ex2 = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $setcmd $(CONF.DAQ.retrysendtimes) $(CONF.DAQ.retryconnecttimes)) : setcmd
    ex3 = quote
        @gencontroller SweepBlock $instr
        $ex2
        sleep($(bk.delay))
        $interpcodes
    end
    return if rstrip(bk.rangemark) == ""
        quote
            let $sweeplist = gensweeplist($start, $step, $stop; equalstep=$(CONF.DAQ.equalstep))
                @progress for $ijk in $sweeplist
                    $ex3
                end
            end
        end
    else
        quote
            let $sweeplist = gensweeplist($start, $step, $stop; equalstep=$(CONF.DAQ.equalstep))
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
    @assert INSTRCONF[bk.instrnm].quantities[bk.quantity].separator == "" mlstr("no free sweeping !!!")
    timeoutr = INSTRCONF[bk.instrnm].quantities[bk.quantity].timeoutr
    getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get)
    U, Us = @c getU(INSTRCONF[bk.instrnm].quantities[quantity].U, &bk.ui)
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
    @gensym observables lasttime
    getcmd = :(controllers[$instr]($getfunc, CPU, Val(:read); timeout=$timeoutr))
    getdata = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $getcmd $(CONF.DAQ.retrysendtimes) $(CONF.DAQ.retryconnecttimes)) : getcmd
    detfunc = Dict("=" => :isarrived, "<" => :isless, ">" => :isgreater)[bk.mode]
    return quote
        let $observables = []
            $lasttime = time()
            ismoving(t=$(bk.duration)) = time() - $lasttime > $(bk.duration) ? ($lasttime = time(); _ismoving($observables, $delta, t)) : true
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
    timeoutw = INSTRCONF[bk.instrnm].quantities[quantity].timeoutw
    U, Us = @c getU(INSTRCONF[bk.instrnm].quantities[quantity].U, &bk.ui)
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
    setcmd = :(controllers[$instr]($setfunc, CPU, string($setvalue), Val(:write); timeout=$timeoutw))
    setcodes = bk.istrycatch ? quote
        @gentrycatch $(bk.instrnm) $(bk.addr) $setcmd $(CONF.DAQ.retrysendtimes) $(CONF.DAQ.retryconnecttimes)
        sleep($(bk.delay))
    end : quote
        $setcmd
        sleep($(bk.delay))
    end
    return if bk.ischeck
        timeoutr = INSTRCONF[bk.instrnm].quantities[quantity].timeoutr
        getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get)
        getcmd = :(controllers[$instr]($getfunc, CPU, Val(:read); timeout=$timeoutr))
        getcodes = bk.istrycatch ? quote
            @gentrycatch $(bk.instrnm) $(bk.addr) $getcmd $(CONF.DAQ.retrysendtimes) $(CONF.DAQ.retryconnecttimes)
        end : quote
            $getcmd
        end
        getcodes = U == "" ? getcodes : :(parse(Float64, $getcodes))
        @gensym times
        trytimes = CONF.DAQ.retryconnecttimes * CONF.DAQ.retrysendtimes
        return quote
            let $times = 0
                $setcodes
                while $times < $trytimes && $setvalue != $getcodes
                    @gencontroller SettingBlock $instr
                    $setcodes
                    $times += 1
                end
                @assert $times < $trytimes string("set value ", $(bk.setvalue), $U, " failed for ", $instr, "!!!")
            end
        end
    else
        setcodes
    end
end


tocodes(bk::ReadingBlock) = gencodes_read(bk)

function tocodes(bk::WriteBlock)
    instr = string(bk.instrnm, "/", bk.addr)
    cmd = parsedollar(bk.cmd)
    timeout = getattr(bk.addr).timeoutw
    setcmd = :(controllers[$instr](write, CPU, string($cmd), Val(:write); timeout=$timeout))
    ex = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $setcmd $(CONF.DAQ.retrysendtimes) $(CONF.DAQ.retryconnecttimes)) : setcmd
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
            SYNCSTATES[IsInterrupted] = true
            @warn "[$(now())]\n$(mlstr("interrupt!"))" FeedbackBlock = $instr
            return nothing
        elseif $(bk.action) == mlstr("Pause")
            SYNCSTATES[IsBlocked] = true
            @warn "[$(now())]\n$(mlstr("pause!"))" FeedbackBlock = $instr
            lock(() -> wait(BLOCK), BLOCK)
            @info "[$(now())]\n$(mlstr("continue!"))" FeedbackBlock = $instr
        end
    end
end

function gencodes_read(bk::Union{ReadingBlock,QueryBlock,ReadBlock})
    instr = string(bk.instrnm, "/", bk.addr)
    index = genindex(bk)
    bk isa ReadingBlock && (getfunc = Symbol(bk.instrnm, :_, bk.quantity, :_get))
    bk isa QueryBlock && (cmd = parsedollar(bk.cmd))
    if isnothing(index) || (bk isa ReadingBlock && INSTRCONF[bk.instrnm].quantities[bk.quantity].separator == "")
        key = genkey(bk)
        timeout = if bk isa ReadingBlock
            INSTRCONF[bk.instrnm].quantities[bk.quantity].timeoutr
        else
            getattr(bk.addr).timeoutr
        end
        getcmd = if bk isa ReadingBlock
            :(controllers[$instr]($getfunc, CPU, Val(:read); timeout=$timeout))
        elseif bk isa QueryBlock
            :(controllers[$instr](query, CPU, string($cmd), Val(:query); timeout=$timeout))
        elseif bk isa ReadBlock
            :(controllers[$instr](read, CPU, Val(:read); timeout=$timeout))
        end
        getdata = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $getcmd $(CONF.DAQ.retrysendtimes) $(CONF.DAQ.retryconnecttimes)) : getcmd
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
        keyall = genkeys(bk, index)
        separator = bk isa ReadingBlock ? INSTRCONF[bk.instrnm].quantities[bk.quantity].separator : ","
        separator == "" && (separator = ",")
        timeout = if bk isa ReadingBlock
            INSTRCONF[bk.instrnm].quantities[bk.quantity].timeoutr
        else
            getattr(bk.addr).timeoutr
        end
        getcmd = if bk isa ReadingBlock
            :(string.(split(controllers[$instr]($getfunc, CPU, Val(:read); timeout=$timeout), $separator)[collect($index)]))
        elseif bk isa QueryBlock
            :(string.(split(controllers[$instr](query, CPU, $cmd, Val(:query); timeout=$timeout), $separator)[collect($index)]))
        elseif bk isa ReadBlock
            :(string.(split(controllers[$instr](read, CPU, Val(:read); timeout=$timeout), $separator)[collect($index)]))
        end
        getdata = bk.istrycatch ? :(@gentrycatch $(bk.instrnm) $(bk.addr) $getcmd $(CONF.DAQ.retrysendtimes) $(CONF.DAQ.retryconnecttimes) $(length(index))) : getcmd
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

function genindex(bk)
    index = @trypasse eval(Meta.parse(bk.index)) begin
        @error "[$(now())]\n$(mlstr("codes are wrong in parsing time ($(typeof(bk)))!!!"))" bk = bk
        return
    end
    index isa Integer && (index = [index])
    return index
end
genmark(bk) = parsedollar(replace(bk.mark, "/" => "_"))
function genkey(bk::ReadingBlock)
    mark = genmark(bk)
    if mark isa Expr
        :(string($mark, "/", $(bk.instrnm), "/", $(bk.quantity), "/", $(bk.addr)))
    else
        string(mark, "/", bk.instrnm, "/", bk.quantity, "/", bk.addr)
    end
end
function genkey(bk)
    mark = genmark(bk)
    if mark isa Expr
        :(string($mark, "/", $(bk.instrnm), "/", $(bk.addr)))
    else
        string(mark, "/", bk.instrnm, "/", bk.addr)
    end
end
function genmarks(bk, index)
    marks = Vector{Union{AbstractString,Expr}}(undef, length(index))
    fill!(marks, "")
    for (i, v) in enumerate(split(bk.mark, ","))
        marks[i] = parsedollar(replace(v, "/" => "_"))
    end
    for (i, idx) in enumerate(index)
        marks[i] == "" && (marks[i] = "mark$idx")
    end
    return marks
end
function genkeys(bk::ReadingBlock, index)
    marks = genmarks(bk, index)
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
end
function genkeys(bk, index)
    marks = genmarks(bk, index)
    if true in isa.(marks, Expr)
        [
            :(string($mark, "/", $(bk.instrnm), "[", $ind, "]", "/", $(bk.addr)))
            for (mark, ind) in zip(marks, index)
        ]
    else
        [string(mark, "/", bk.instrnm, "[", ind, "]", "/", bk.addr) for (mark, ind) in zip(marks, index)]
    end
end