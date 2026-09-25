#通用树节点："叶子 + 一级分类"的分组存储（DAQ 任务树、绘图树等复用）
#isgroup == true 为分类节点：仅使用 name/open/children；否则为叶子节点：有效载荷存于 value
#约定：根节点与一级分类的 children 只含叶子或一级分类（两级结构，叶子载荷类型需含 name 字段且可零参构造）
@kwdef mutable struct Tree{T}
    isgroup::Bool = false
    name::String = ""
    value::T = T()
    open::Bool = false #分类展开状态（仅分类节点使用）
    children::Vector{Tree{T}} = Tree{T}[]
end
Tree(value::T) where {T} = Tree{T}(value=value)
TreeGroup(::Type{T}, name::AbstractString="New Group") where {T} = Tree{T}(isgroup=true, name=String(name))

AbstractTrees.children(node::Tree) = node.children
AbstractTrees.printnode(io::IO, node::Tree) = print(io, node.isgroup ? node.name : node.value.name)

#按树遍历顺序展开所有叶子节点
leaves(root::Tree{T}) where {T} = Tree{T}[n for c in root.children for n in (c.isgroup ? c.children : [c])]
#按树遍历顺序展开所有叶子载荷
leafvalues(root::Tree) = [n.value for n in leaves(root)]

#拖拽负载：group 为 0 表示顶层，index 为容器内索引（配合 moveleaf!/movegroup! 使用）
struct TreeDragPayload
    group::Cint
    index::Cint
end

#将叶子节点移动到目标容器（dstg == 0 为顶层）的 dsti 位置
#同容器默认插到目标之前；源紧邻目标之前时插到目标之后，保证相邻平级互相拖拽必有位置交换
function moveleaf!(root::Tree, srcg::Integer, srci::Integer, dstg::Integer, dsti::Integer)
    (srcg == dstg && srci == dsti) && return
    srccontainer = srcg == 0 ? root : root.children[srcg]
    dstcontainer = dstg == 0 ? root : root.children[dstg]
    node = srccontainer.children[srci]
    deleteat!(srccontainer.children, srci)
    if srcg == dstg && srci < dsti
        insert!(dstcontainer.children, srci == dsti - 1 ? dsti : dsti - 1, node)
    else
        insert!(dstcontainer.children, dsti, node)
    end
end

#把叶子 (srcg, srci) 移到一级分类 gi 之前的顶层位置（不进入分类，用于组头无 Ctrl 释放）
#源（顶层叶子）紧邻 gi 之前时插到 gi 之后，避免原地不动
function insertleafbeforegroup!(root::Tree, srcg::Integer, srci::Integer, gi::Integer)
    srccontainer = srcg == 0 ? root : root.children[srcg]
    node = srccontainer.children[srci]
    deleteat!(srccontainer.children, srci)
    if srcg == 0 && srci < gi
        insert!(root.children, srci == gi - 1 ? gi : gi - 1, node)
    else
        insert!(root.children, gi, node)
    end
end

#按平铺顺序插入分类：把一级分类 srcg 移到叶子 (dstg, dsti) 的顺序位置
#（dstg == 0 时插到顶层目标之前；dstg != 0 时插到目标所在分类之前；目标在自身内时不动作）
#源紧邻目标之前时插到目标之后，保证相邻时互相拖拽必有位置交换
function insertgrouporder!(root::Tree, srcg::Integer, dstg::Integer, dsti::Integer)
    srcg == dstg && return
    node = root.children[srcg]
    deleteat!(root.children, srcg)
    if dstg == 0
        insert!(root.children, srcg < dsti ? (srcg == dsti - 1 ? dsti : dsti - 1) : dsti, node)
    else
        insert!(root.children, srcg < dstg ? (srcg == dstg - 1 ? dstg : dstg - 1) : dstg, node)
    end
end

#将一级分类移动到 root.children 的 dstg 位置；源紧邻目标之前时插到目标之后，避免原地不动
function movegroup!(root::Tree, srcg::Integer, dstg::Integer)
    srcg == dstg && return
    node = root.children[srcg]
    deleteat!(root.children, srcg)
    insert!(root.children, srcg < dstg ? (srcg == dstg - 1 ? dstg : dstg - 1) : dstg, node)
end

#删除 gi 分类并将其叶子移回 root.children 尾部
function ungroup!(root::Tree, gi::Integer)
    group = root.children[gi]
    deleteat!(root.children, gi)
    append!(root.children, group.children)
end
