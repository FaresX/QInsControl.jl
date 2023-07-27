abstract type FileTree end

mutable struct FileFileTree <: FileTree
    filepath::String
    filepath_bnm::String
    selectedpath::Ref{String}
    filter::Ref{String}
    isdeleted::Bool
end
mutable struct FolderFileTree <: FileTree
    rootpath::String
    rootpath_bnm::String
    selectedpath::Ref{String}
    filter::Ref{String}
    filetrees::Vector{T} where {T<:FileTree}
    function FolderFileTree(rootpath::String, selectedpath::Ref{String}=Ref(""), filter::Ref{String}=Ref(""))
        ft = new()
        ft.rootpath = rootpath
        ft.rootpath_bnm = basename(ft.rootpath)
        ft.selectedpath = selectedpath
        ft.filter = filter
        ft.filetrees = FileTree[]
        dircontent = readdir(rootpath, join=true)
        for p in dircontent
            if isdir(p)
                push!(ft.filetrees, FolderFileTree(p, ft.selectedpath, ft.filter))
            elseif isfile(p)
                push!(ft.filetrees, FileFileTree(p, basename(p), ft.selectedpath, ft.filter, false))
            end
        end
        ft
    end
    function FolderFileTree(pathes::Vector{String}, selectedpath::Ref{String}=Ref(""), filter::Ref{String}=Ref(""))
        new(
            dirname(pathes[1]),
            "",
            selectedpath,
            filter,
            [FileFileTree(p, basename(p), selectedpath, filter, false) for p in pathes]
        )
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
    if !filetree.isdeleted && (filetree.filter[] == "" ||
                               !isvalid(filetree.filter[]) || occursin(lowercase(filetree.filter[]), lowercase(filetree.filepath_bnm)))
        filemenu(filetree, isrename)
    end
end

let
    deldialog::Bool = false
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
            if newpath != path
                Base.Filesystem.rename(path, newpath)
                filetree.filepath = newpath
                filetree.filepath_bnm = basename(filetree.filepath)
                delete!(isrename, path)
                push!(isrename, newpath => false)
                filetree.selectedpath[] = newpath
            else
                isrename[path] = isrnm
            end
        else
            isrename[path] = isrnm
        end
        if CImGui.BeginPopupContextItem()
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.CloseFile, " ", mlstr("Delete"))) && (deldialog = true)
            CImGui.EndPopup()
        end
        if YesNoDialog(stcstr("##if delete", path), mlstr("Confirm delete?"), CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            Base.Filesystem.rm(path)
            filetree.isdeleted = true
        end
        deldialog && (CImGui.OpenPopup(stcstr("##if delete", path));
        deldialog = false)
        CImGui.PopID()
    end
end