@kwdef mutable struct FileViewer
    filetree::FileTree = FileTree()
    isrename::Dict{String,Bool} = Dict()
    dtviewers::Dict{String,DataViewer} = Dict()
    p_open::Bool = true
    noclose::Bool = true
end

function edit(fv::FileViewer, id)
    CImGui.SetNextWindowSize((520, 720) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Once)
    nm = fv.filetree.rootpath_bnm == "" ?
         stcstr(MORESTYLE.Icons.OpenFile, "  ", mlstr("Data Browse"), "###dtv", id) :
         stcstr(MORESTYLE.Icons.OpenFolder, "  ", mlstr("Data Browse"), "###dtv", id)
    begun, own, popenarg = @c BeginNoClose(nm, &fv.p_open)
    if begun
        SetWindowShadow()
        SetWindowBgImage(CONF.BGImage.filetree.path; rate=CONF.BGImage.filetree.rate, use=CONF.BGImage.filetree.use)

        oldfiles = copy(fv.filetree.selectedpathes)
        ImGuiTextFilter_Draw(fv.filetree.filter, stcstr(mlstr("Filter"), "##", id), 0)
        CImGui.SameLine()
        CImGui.Checkbox(mlstr("Valid"), fv.filetree.valid)
        CImGui.SameLine()
        CImGui.Button(MORESTYLE.Icons.InstrumentsAutoRef) && refresh!(fv.filetree)
        CImGui.BeginChild("FileTree")
        CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, MORESTYLE.Colors.ToolBarBg)
        edit(fv.filetree, fv.isrename, false)
        if fv.filetree.selectedpathes != oldfiles
            for path in fv.filetree.selectedpathes
                haskey(fv.dtviewers, path) || push!(fv.dtviewers, path => DataViewer())
                path in oldfiles || loaddtviewer!(fv.dtviewers[path], path, stcstr("DataViewer", id, path))
            end
            for path in collect(keys(fv.dtviewers)) #快照遍历:循环体内 delete! 会打断 Dict 迭代
                if path ∉ fv.filetree.selectedpathes
                    atclosedtviewer!(fv.dtviewers[path])
                    delete!(fv.dtviewers, path)
                end
            end
        end
        CImGui.PopStyleColor()
        fv.filetree.rootpath_bnm != "" && CImGui.IsMouseClicked(1) && !CImGui.IsAnyItemHovered() &&
            CImGui.IsWindowHovered(CImGui.ImGuiHoveredFlags_RootAndChildWindows) && CImGui.OpenPopup("File Menu")
        if CImGui.BeginPopup("File Menu")
            CImGui.MenuItem(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Refresh"))) && refresh!(fv.filetree)
            CImGui.EndPopup()
        end
        CImGui.EndChild()
    end
    @c EndNoClose(own, &fv.p_open, popenarg)
    closedpaths = String[] #循环内 deleteat!/delete! 会打断 selectedpathes/dtviewers 的迭代,先收集再统一删
    for path in fv.filetree.selectedpathes
        haskey(fv.dtviewers, path) || push!(fv.dtviewers, path => DataViewer())
        dtviewer = fv.dtviewers[path]
        CImGui.SetNextWindowSize((600, 800) .* CImGui.GetWindowDpiScale(), CImGui.ImGuiCond_Once)
        nmd = stcstr(basename(path), "##", path)
        begun, own, popenarg = @c BeginNoClose(nmd, &dtviewer.p_open)
        if begun
            SetWindowShadow()
            SetWindowBgImage(
                CONF.BGImage.fileviewer.path;
                rate=CONF.BGImage.fileviewer.rate,
                use=CONF.BGImage.fileviewer.use
            )
            edit(dtviewer, path, string(id, path))
        end
        @c EndNoClose(own, &dtviewer.p_open, popenarg)
        if dtviewer.p_open
            haskey(dtviewer.data, "data") && renderplots(dtviewer.dtps, stcstr("DataViewer", id, path))
        else
            atclosedtviewer!(fv.dtviewers[path])
            delete!(fv.dtviewers, path)
            push!(closedpaths, path)
        end
    end
    filter!(!in(closedpaths), fv.filetree.selectedpathes)
end

function atclosefileviewer!(fv::FileViewer)
    for dtv in values(fv.dtviewers)
        dtv.p_open && atclosedtviewer!(dtv)
    end
end