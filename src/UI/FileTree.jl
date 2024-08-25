abstract type FileTree end

mutable struct FileFileTree <: FileTree
    filepath::String
    filepath_bnm::String
    selectedpathes::Vector{String}
    filter::Ref{String}
    valid::Bool
    isdeleted::Bool
end
mutable struct FolderFileTree <: FileTree
    rootpath::String
    rootpath_bnm::String
    selectedpathes::Vector{String}
    filter::Ref{String}
    valid::Ref{Bool}
    filetrees::Vector{T} where {T<:FileTree}
    function FolderFileTree(rootpath::String, selectedpathes=[], filter=Ref(""), valid=Ref(false))
        ft = new()
        ft.rootpath = rootpath
        ft.rootpath_bnm = basename(ft.rootpath)
        ft.selectedpathes = selectedpathes
        ft.filter = filter
        ft.valid = valid
        ft.filetrees = FileTree[]
        dircontent = readdir(rootpath, join=true)
        for p in dircontent
            if isdir(p)
                push!(ft.filetrees, FolderFileTree(p, ft.selectedpathes, ft.filter, ft.valid))
            elseif isfile(p)
                push!(
                    ft.filetrees,
                    FileFileTree(
                        p, basename(p), ft.selectedpathes, ft.filter,
                        split(basename(p), '.')[end] in ["qdt", "cfg"] ? loadvalid(p) : false,
                        false
                    )
                )
            end
        end
        ft
    end
    function FolderFileTree(pathes::Vector{String}, selectedpathes=[], filter=Ref(""), valid=Ref(false))
        ft = new()
        ft.rootpath = pathes[1]
        ft.rootpath_bnm = ""
        ft.selectedpathes = selectedpathes
        ft.filter = filter
        ft.valid = valid
        ft.filetrees = FileTree[]
        for p in pathes
            push!(
                ft.filetrees,
                FileFileTree(
                    p, basename(p), ft.selectedpathes, ft.filter,
                    split(basename(p), '.')[end] in ["qdt", "cfg"] ? loadvalid(p) : false,
                    false
                )
            )
        end
        ft
    end
end

function edit(filetree::FolderFileTree, isrename::Dict{String,Bool}, ::Bool, bnm=false)
    if CImGui.TreeNode(stcstr(MORESTYLE.Icons.OpenFolder, " ", bnm ? filetree.rootpath_bnm : filetree.rootpath))
        for ft in filetree.filetrees
            edit(ft, isrename, filetree.valid[], true)
        end
        CImGui.TreePop()
    end
end

function edit(filetree::FileFileTree, isrename::Dict{String,Bool}, valid::Bool, ::Bool)
    if !filetree.isdeleted &&
       (filetree.filter[] == "" || !isvalid(filetree.filter[]) ||
        occursin(lowercase(filetree.filter[]), lowercase(filetree.filepath_bnm))) &&
       (!valid || (valid && filetree.valid[]))
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
        @c(RenameSelectable(
            "##path", &isrnm, &file, path in filetree.selectedpathes;
            size2=(-1, 0),
            fixedlabel=stcstr(MORESTYLE.Icons.OpenFile, " ")
        )) && (path in filetree.selectedpathes ? deleteat!(filetree.selectedpathes, findall(==(path), filetree.selectedpathes)) : push!(filetree.selectedpathes, path))
        CImGui.PopItemWidth()
        if file != "" && (isrename[path] && !isrnm)
            newpath = joinpath(dirname(path), file)
            if newpath != path
                Base.Filesystem.rename(path, newpath)
                filetree.filepath = newpath
                filetree.filepath_bnm = basename(filetree.filepath)
                delete!(isrename, path)
                isrename[newpath] = false
                deleteat!(filetree.selectedpathes, findall(==(path), filetree.selectedpathes))
                push!(filetree.selectedpathes, newpath)
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

loadvalid(path) = (valid = @trypasse load(path, "valid") false; valid isa Bool ? valid : false)