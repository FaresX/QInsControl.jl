abstract type FileTree end

mutable struct FileFileTree <: FileTree
    filepath::String
    filepath_bnm::String
    selectedpath::Ref{String}
    isdeleted::Bool
end
mutable struct FolderFileTree <: FileTree
    rootpath::String
    rootpath_bnm::String
    selectedpath::Ref{String}
    filetrees::Vector{T} where {T<:FileTree}
    function FolderFileTree(rootpath::String, selectedpath::Ref{String}=Ref(""))
        ft = new()
        ft.rootpath = rootpath
        ft.rootpath_bnm = basename(ft.rootpath)
        ft.selectedpath = selectedpath
        ft.filetrees = FileTree[]
        dircontent = readdir(rootpath, join=true)
        for p in dircontent
            if isdir(p)
                push!(ft.filetrees, FolderFileTree(p, ft.selectedpath))
            elseif isfile(p)
                push!(ft.filetrees, FileFileTree(p, basename(p), ft.selectedpath, false))
            end
        end
        ft
    end
    function FolderFileTree(pathes::Vector{String}, selectedpath::Ref{String}=Ref(""))
        new(dirname(pathes[1]), "", selectedpath, [FileFileTree(p, basename(p), selectedpath, false) for p in pathes])
    end
end

function edit(filetree::FolderFileTree, isrename::Dict{String,Bool}, bnm=false)
    if CImGui.TreeNode(bnm ? filetree.rootpath_bnm : filetree.rootpath)
        for ft in filetree.filetrees
            edit(ft, isrename, true)
        end
        CImGui.TreePop()
    end
end

function edit(filetree::FileFileTree, isrename::Dict{String,Bool}, ::Bool)
    filetree.isdeleted || filemenu(filetree, isrename)
end

let
    deldialog::Bool = false
    yesnodialog_ids::Dict{String,String} = Dict()
    global function filemenu(filetree::FileFileTree, isrename)
        path = filetree.filepath
        file = filetree.filepath_bnm
        get!(isrename, path, false)
        isrnm = isrename[path]
        CImGui.PushID(path)
        CImGui.PushItemWidth(-1)
        @c(RenameSelectable("##path", &isrnm, &file, filetree.selectedpath[] == path)) && (filetree.selectedpath[] = path)
        CImGui.PopItemWidth()
        if file != "" && (isrename[path] && !isrnm)
            newpath = joinpath(dirname(path), file)
            if newpath != filetree.selectedpath[]
                Base.Filesystem.rename(path, newpath)
                filetree.filepath = newpath
                filetree.filepath_bnm = basename(filetree.filepath)
                delete!(isrename, path)
                push!(isrename, newpath => false)
                filetree.selectedpath[] = newpath
            end
        else
            isrename[path] = isrnm
        end
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem("删除") && (deldialog = true)
            CImGui.EndPopup()
        end
        haskey(yesnodialog_ids, path) || push!(yesnodialog_ids, path => "##是否删除$path")
        if YesNoDialog(yesnodialog_ids[path], "确认删除？", CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            Base.Filesystem.rm(path)
            filetree.isdeleted = true
        end
        deldialog && (CImGui.OpenPopup(yesnodialog_ids[path]);
        deldialog = false)
        CImGui.PopID()
    end
end