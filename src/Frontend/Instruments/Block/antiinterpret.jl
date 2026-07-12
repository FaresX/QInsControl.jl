function antiinterpretblocks(ex)
    bk = antiinterpret(ex)
    return checkblocks!(bk isa StrideCodeBlock && bk.codes == "begin" ? bk.blocks : AbstractBlock[bk])
end
function checkblocks!(blocks::Vector{AbstractBlock}, level=1)
    joinablebk = []
    joining = false
    for (i, bk) in enumerate(blocks)
        if bk isa CodeBlock
            if @capture(tocodes(bk), @gencontroller kv__)
                blocks[i] = NullBlock()
                joining && (joining = false; push!(joinablebk[end], i - 1))
            else
                joining || (joining = true; push!(joinablebk, [i]))
            end
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
            ij .-= (j - i)
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
function antiinterpret(ex, ::Val{:sweepblock})
    instrnm = haskey(INSTRALIASLIST, ex.args[4]) ? INSTRALIASLIST[ex.args[4]].instrnm : mlstr("instrument")
    addr = haskey(INSTRALIASLIST, ex.args[4]) ? INSTRALIASLIST[ex.args[4]].addr : mlstr("address")
    SweepBlock(
        rangemark=ex.args[3],
        alias=ex.args[4],
        instrnm=instrnm,
        addr=addr,
        quantity=ex.args[5],
        step=ex.args[6],
        stop=ex.args[7],
        ui=utoui(instrnm, ex.args[5], strtoU(string(ex.args[8]))),
        delay=ex.args[9],
        istrycatch=ex.args[10],
        blocks=(bk = antiinterpret(ex.args[11]); bk isa StrideCodeBlock && occursin("begin", bk.codes) ? bk.blocks : [bk])
    )
end
function antiinterpret(ex, ::Val{:freesweepblock})
    instrnm = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].instrnm : mlstr("instrument")
    addr = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].addr : mlstr("address")
    FreeSweepBlock(
        alias=ex.args[3],
        instrnm=instrnm,
        addr=addr,
        quantity=ex.args[4],
        mode=string(ex.args[5]),
        stop=ex.args[6],
        ui=utoui(instrnm, ex.args[4], strtoU(string(ex.args[7]))),
        delta=ex.args[8],
        duration=ex.args[9],
        delay=ex.args[10],
        istrycatch=ex.args[11],
        blocks=(bk = antiinterpret(ex.args[12]); bk isa StrideCodeBlock && occursin("begin", bk.codes) ? bk.blocks : [bk])
    )
end
function antiinterpret(ex, ::Val{:settingblock})
    instrnm = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].instrnm : mlstr("instrument")
    addr = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].addr : mlstr("address")
    SettingBlock(
        alias=ex.args[3],
        instrnm=instrnm,
        addr=addr,
        quantity=ex.args[4],
        ischeck=ex.args[5],
        setvalue=ex.args[6],
        ui=utoui(instrnm, ex.args[4], strtoU(string(ex.args[7]))),
        delay=ex.args[8],
        istrycatch=ex.args[9]
    )
end
function antiinterpret(ex, ::Val{:readingblock})
    instrnm = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].instrnm : mlstr("instrument")
    addr = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].addr : mlstr("address")
    return ReadingBlock(
        alias=ex.args[3],
        instrnm=instrnm,
        addr=addr,
        quantity=ex.args[4],
        index=ex.args[5],
        mark=ex.args[6],
        isasync=ex.args[7],
        isobserve=ex.args[8],
        isreading=ex.args[9],
        istrycatch=ex.args[10]
    )
end
function antiinterpret(ex, ::Val{:writeblock})
    instrnm = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].instrnm : mlstr("instrument")
    addr = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].addr : mlstr("address")
    return WriteBlock(
        alias=ex.args[3],
        instrnm=instrnm,
        addr=addr,
        cmd=ex.args[4],
        isasync=ex.args[5],
        istrycatch=ex.args[6]
    )
end
function antiinterpret(ex, ::Val{:readblock})
    instrnm = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].instrnm : mlstr("instrument")
    addr = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].addr : mlstr("address")
    return ReadBlock(
        alias=ex.args[3],
        instrnm=instrnm,
        addr=addr,
        index=ex.args[4],
        mark=ex.args[5],
        isasync=ex.args[6],
        isobserve=ex.args[7],
        isreading=ex.args[8],
        istrycatch=ex.args[9]
    )
end
function antiinterpret(ex, ::Val{:queryblock})
    instrnm = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].instrnm : mlstr("instrument")
    addr = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].addr : mlstr("address")
    return QueryBlock(
        alias=ex.args[3],
        instrnm=instrnm,
        addr=addr,
        cmd=ex.args[4],
        index=ex.args[5],
        mark=ex.args[6],
        isasync=ex.args[7],
        isobserve=ex.args[8],
        isreading=ex.args[9],
        istrycatch=ex.args[10]
    )
end
function antiinterpret(ex, ::Val{:feedbackblock})
    instrnm = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].instrnm : mlstr("instrument")
    addr = haskey(INSTRALIASLIST, ex.args[3]) ? INSTRALIASLIST[ex.args[3]].addr : mlstr("address")
    return FeedbackBlock(
        alias=ex.args[3],
        instrnm=instrnm,
        addr=addr,
        action=ex.args[4]
    )
end