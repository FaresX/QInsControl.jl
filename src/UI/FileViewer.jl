@kwdef mutable struct FileViewer
    filetree::FileTree = FileTree()
    isrename::Dict{String,Bool} = Dict()
    dtviewers::Dict{String,DataViewer} = Dict()
    p_open::Bool = true
    noclose::Bool = true
end

function edit(fv::FileViewer, id)
    CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Once)
    if @c CImGui.Begin(
        if fv.filetree.rootpath_bnm == ""
            stcstr(MORESTYLE.Icons.OpenFile, "  ", mlstr("Data Browse"), "###dtv", id)
        else
            stcstr(MORESTYLE.Icons.OpenFolder, "  ", mlstr("Data Browse"), "###dtv", id)
        end,
        &fv.p_open
    )
        SetWindowBgImage(CONF.BGImage.filetree.path; rate=CONF.BGImage.filetree.rate, use=CONF.BGImage.filetree.use)

        oldfiles = copy(fv.filetree.selectedpathes)
        InputTextRSZ(stcstr(mlstr("Filter"), "##", id), fv.filetree.filter)
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
            for path in keys(fv.dtviewers)
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
    CImGui.End()
    for path in fv.filetree.selectedpathes
        haskey(fv.dtviewers, path) || push!(fv.dtviewers, path => DataViewer())
        dtviewer = fv.dtviewers[path]
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Once)
        if @c CImGui.Begin(stcstr(basename(path), "##", id, path), &dtviewer.p_open)
            SetWindowBgImage(
                CONF.BGImage.fileviewer.path;
                rate=CONF.BGImage.fileviewer.rate,
                use=CONF.BGImage.fileviewer.use
            )
            edit(dtviewer, path, string(id, path))
        end
        CImGui.End()
        if dtviewer.p_open
            haskey(dtviewer.data, "data") && renderplots(dtviewer.dtp, stcstr("DataViewer", id, path))
        else
            atclosedtviewer!(fv.dtviewers[path])
            delete!(fv.dtviewers, path)
            deleteat!(fv.filetree.selectedpathes, findall(==(path), fv.filetree.selectedpathes))
        end
    end
end

function atclosefileviewer!(fv::FileViewer)
    for dtv in values(fv.dtviewers)
        dtv.p_open && atclosedtviewer!(dtv)
    end
end