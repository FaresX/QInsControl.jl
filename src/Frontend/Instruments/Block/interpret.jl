macro sweepblock(rangemark, alias, qtnm, step, stop, u, delay, startdelay, istrycatch, ex)
    esc(
        tocodes(
            SweepBlock(
                rangemark=rangemark,
                alias=alias,
                instrnm=INSTRUMENTS[alias].instrnm,
                addr=INSTRUMENTADDRS[alias].addr,
                quantity=qtnm,
                step=step,
                stop=stop,
                delay=delay,
                startdelay=startdelay,
                ui=utoui(instrnm, qtnm, u),
                istrycatch=istrycatch,
                blocks=CodeBlock(codes=string(ex))
            )
        )
    )
end


macro freesweepblock(alias, qtnm, mode, stop, u, delta, duration, delay, istrycatch, ex)
    esc(
        tocodes(
            FreeSweepBlock(
                alias=alias,
                instrnm=INSTRUMENTS[alias].instrnm,
                addr=INSTRUMENTADDRS[alias].addr,
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

macro settingblock(alias, qtnm, ischeck, sv, u, delay, istrycatch)
    esc(
        tocodes(
            SettingBlock(
                alias=alias,
                instrnm=INSTRUMENTS[alias].instrnm,
                addr=INSTRUMENTADDRS[alias].addr,
                quantity=qtnm,
                setvalue=sv,
                delay=delay,
                ui=utoui(instrnm, qtnm, u),
                ischeck=ischeck,
                istrycatch=istrycatch
            )
        )
    )
end

macro readingblock(alias, qtnm, index, mark, isasync, isobserve, isreading, istrycatch)
    esc(
        tocodes(
            ReadingBlock(
                alias=alias,
                instrnm=INSTRUMENTS[alias].instrnm,
                addr=INSTRUMENTADDRS[alias].addr,
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

macro writeblock(alias, cmd, isasync, istrycatch)
    esc(tocodes(WriteBlock(alias=alias, instrnm=INSTRUMENTS[alias].instrnm, addr=INSTRUMENTADDRS[alias].addr, cmd=cmd, isasync=isasync, istrycatch=istrycatch)))
end

macro readblock(alias, index, mark, isasync, isobserve, isreading, istrcatch)
    esc(
        tocodes(
            ReadBlock(
                alias=alias,
                instrnm=INSTRUMENTS[alias].instrnm,
                addr=INSTRUMENTADDRS[alias].addr,
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

macro queryblock(alias, cmd, index, mark, isasync, isobserve, isreading, istrcatch)
    esc(
        tocodes(
            QueryBlock(
                alias=alias,
                instrnm=INSTRUMENTS[alias].instrnm,
                addr=INSTRUMENTADDRS[alias].addr,
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

macro feedbackblock(alias, action)
    esc(tocodes(FeedbackBlock(alias=alias, instrnm=INSTRUMENTS[alias].instrnm, addr=INSTRUMENTADDRS[alias].addr, action=action)))
end

function utoui(instrnm, qtnm, u)
    utype = haskey(INSTRCONF, instrnm) && haskey(INSTRCONF[instrnm].quantities, qtnm) ? INSTRCONF[instrnm].quantities[qtnm].U : ""
    Us = haskey(CONF.U, utype) ? CONF.U[utype] : [""]
    return u in Us ? findfirst(==(u), Us) : 1
end

function compile(blocks::Vector{AbstractBlock})
    return quote
        function remote_sweep_block(controllers, databuf_lc, progress_lc, extradatabuf_lc, SYNCSTATES)
            $(tocodes.(blocks)...)
        end
    end
end

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
    utype = haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity) ? INSTRCONF[bk.instrnm].quantities[bk.quantity].U : ""
    u, _ = @c getU(utype, &bk.ui)
    quote
        @sweepblock $(bk.rangemark) $(bk.alias) $(bk.quantity) $(bk.step) $(bk.stop) $(string(u)) $(bk.delay) $(bk.startdelay) $(bk.istrycatch) begin
            $(interpret.(bk.blocks)...)
        end
    end
end
function interpret(bk::FreeSweepBlock)
    utype = haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity) ? INSTRCONF[bk.instrnm].quantities[bk.quantity].U : ""
    u, _ = @c getU(utype, &bk.ui)
    quote
        @freesweepblock $(bk.alias) $(bk.quantity) $(bk.mode) $(bk.stop) $(string(u)) $(bk.delta) $(bk.duration) $(bk.delay) $(bk.istrycatch) begin
            $(interpret.(bk.blocks)...)
        end
    end
end
function interpret(bk::SettingBlock)
    utype = haskey(INSTRCONF, bk.instrnm) && haskey(INSTRCONF[bk.instrnm].quantities, bk.quantity) ? INSTRCONF[bk.instrnm].quantities[bk.quantity].U : ""
    u, _ = @c getU(utype, &bk.ui)
    :(@settingblock $(bk.alias) $(bk.quantity) $(bk.ischeck) $(bk.setvalue) $(string(u)) $(bk.delay) $(bk.istrycatch))
end
function interpret(bk::ReadingBlock)
    :(@readingblock $(bk.alias) $(bk.quantity) $(bk.index) $(bk.mark) $(bk.isasync) $(bk.isobserve) $(bk.isreading) $(bk.istrycatch))
end
function interpret(bk::WriteBlock)
    :(@writeblock $(bk.alias) $(bk.cmd) $(bk.isasync) $(bk.istrycatch))
end
function interpret(bk::ReadBlock)
    :(@readblock $(bk.alias) $(bk.index) $(bk.mark) $(bk.isasync) $(bk.isobserve) $(bk.isreading) $(bk.istrycatch))
end
function interpret(bk::QueryBlock)
    :(@queryblock $(bk.alias) $(bk.cmd) $(bk.index) $(bk.mark) $(bk.isasync) $(bk.isobserve) $(bk.isreading) $(bk.istrycatch))
end
function interpret(bk::FeedbackBlock)
    :(@feedbackblock $(bk.alias) $(bk.action))
end