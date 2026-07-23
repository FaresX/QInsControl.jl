function OpenFileMonitor(fileviewers, dataformatters)
    filelist = filter(fv -> fv.filetree.rootpath_bnm == "", fileviewers)
    folderlist = filter(fv -> fv.filetree.rootpath_bnm != "", fileviewers)
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Files"))
    if isempty(filelist)
        CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
    else
        for (i, fv) in enumerate(filelist)
            CImGui.PushID(i)
            title = isempty(fv.filetree.filetrees) ? mlstr("no file opened") : basename(fv.filetree.filetrees[1].filepath)
            @c CImGui.MenuItem(title, C_NULL, &fv.p_open)
            if CImGui.BeginPopupContextItem()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Close"))) && (fv.noclose = false)
                CImGui.EndPopup()
            end
            CImGui.PopID()
        end
    end
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Folders"))
    if isempty(folderlist)
        CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
    else
        for (i, fv) in enumerate(folderlist)
            CImGui.PushID(i)
            @c CImGui.MenuItem(basename(fv.filetree.rootpath), C_NULL, &fv.p_open)
            if CImGui.BeginPopupContextItem()
                if CImGui.MenuItem(stcstr(MORESTYLE.Icons.InstrumentsAutoRef, " ", mlstr("Refresh")))
                    fv.filetree.filetrees = FolderFileTree(
                        fv.filetree.rootpath,
                        fv.filetree.selectedpathes,
                        fv.filetree.filter,
                        fv.filetree.valid
                    ).filetrees
                end
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Close"))) && (fv.noclose = false)
                CImGui.EndPopup()
            end
            CImGui.PopID()
        end
    end
    SeparatorTextColored(MORESTYLE.Colors.HighlightText, mlstr("Formatters"))
    if isempty(dataformatters)
        CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
    else
        for (i, dft) in enumerate(dataformatters)
            CImGui.PushID(i)
            @c CImGui.MenuItem(stcstr(mlstr("Formatter"), " ", i), C_NULL, &dft.p_open)
            if CImGui.BeginPopupContextItem()
                CImGui.MenuItem(stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Close"))) && (dft.noclose = false)
                CImGui.EndPopup()
            end
            CImGui.PopID()
        end
    end
end