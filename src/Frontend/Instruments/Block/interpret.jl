# 该文件原有的 8 个 DSL 宏定义(@sweepblock/@writeblock/...)已删除:它们没有任何展开点
# (DSL 解析在 antiinterpret.jl 里按宏名字符串匹配,不经宏定义),且宏体引用了全库不存在的
# INSTRUMENTADDRS——一旦被 eval 展开必然 UndefVarError。DSL 的语法与语义见 antiinterpret.jl。

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
