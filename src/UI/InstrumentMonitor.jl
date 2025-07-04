let
    st::Bool = false
    showst::Bool = false
    global function InstrumentMonitor(instrwidgets)
        btw = 2CImGui.GetFrameHeight() + unsafe_load(IMGUISTYLE.ItemSpacing.y)
        CImGui.PushStyleColor(CImGui.ImGuiCol_Border, MORESTYLE.Colors.ItemBorder)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ChildBorderSize, 1)
        CImGui.BeginChild("border1", (Cfloat(0), btw + 2unsafe_load(IMGUISTYLE.WindowPadding.y)), true)
        showst |= SYNCSTATES[Int(AutoDetecting)]
        showst && CImGui.PushStyleColor(
            CImGui.ImGuiCol_Button,
            SYNCSTATES[Int(AutoDetecting)] ? MORESTYLE.Colors.InfoBg : st ? MORESTYLE.Colors.HighlightText : MORESTYLE.Colors.ErrorBg
        )
        igBeginDisabled(SYNCSTATES[Int(IsDAQTaskRunning)] || hassweeping())
        CImGui.Button(MORESTYLE.Icons.InstrumentsAutoDetect, (btw, btw)) && refresh_instrlist()
        showst && CImGui.PopStyleColor()
        CImGui.SameLine()
        CImGui.BeginGroup()
        CImGui.PushItemWidth(CImGui.GetContentRegionAvail().x - unsafe_load(IMGUISTYLE.ItemSpacing.x) - CImGui.GetFrameHeight())
        showst1, st1 = manualadd_from_others()
        showst2, st2 = manualadd_from_input()
        showst = showst1 || showst2
        st = st1 || st2
        CImGui.PopItemWidth()
        CImGui.EndGroup()
        igEndDisabled()
        CImGui.EndChild()

        CImGui.BeginChild("border2", (0, 0), true)
        for (ins, inses) in INSTRBUFFERVIEWERS
            isempty(inses) && continue
            # isempty(inses) && CImGui.PushStyleColor(
            #     CImGui.ImGuiCol_Text, CImGui.c_get(IMGUISTYLE.Colors, CImGui.ImGuiCol_TextDisabled)
            # )
            isrefreshingdict = Dict(addr => hasref(ibv) for (addr, ibv) in inses)
            # hasrefreshing = !isempty(inses) && SYNCSTATES[Int(IsAutoRefreshing)] && (|)(values(isrefreshingdict)...)
            hasrefreshing = SYNCSTATES[Int(IsAutoRefreshing)] && (|)(values(isrefreshingdict)...)
            hasrefreshing && CImGui.PushStyleColor(CImGui.ImGuiCol_Text, MORESTYLE.Colors.DAQTaskRunning)
            insnode = CImGui.TreeNode(
                stcstr(INSCONF[ins].conf.icon, " ", ins, "  ", "(", length(inses), ")", "###", ins)
            )
            hasrefreshing && CImGui.PopStyleColor()
            if insnode
                # if isempty(inses)
                #     CImGui.TextDisabled(stcstr("(", mlstr("Null"), ")"))
                # else
                for (addr, ibv) in inses
                    isrefreshingdict[addr] && CImGui.PushStyleColor(
                        CImGui.ImGuiCol_Text, MORESTYLE.Colors.DAQTaskRunning
                    )
                    addrnode = CImGui.TreeNode(addr)
                    isrefreshingdict[addr] && CImGui.PopStyleColor()
                    if CImGui.BeginPopupContextItem()
                        sweeping = hassweeping(ibv)
                        if CImGui.MenuItem(
                            stcstr(MORESTYLE.Icons.Delete, " ", mlstr("Delete")),
                            C_NULL,
                            false,
                            ins != "VirtualInstr" && !SYNCSTATES[Int(IsDAQTaskRunning)] && !sweeping
                        )
                            delete!(INSTRBUFFERVIEWERS[ins], addr)
                            remotecall_fetch(addr -> logout!(CPU, addr), workers()[1], addr)
                        end
                        if CImGui.BeginMenu(
                            stcstr(MORESTYLE.Icons.NewFile, " ", mlstr("Add to")),
                            ins == "Others" && !SYNCSTATES[Int(IsDAQTaskRunning)] && !sweeping
                        )
                            for (cfins, cf) in INSCONF
                                cfins in ["Others", "VirtualInstr"] && continue
                                if CImGui.MenuItem(stcstr(cf.conf.icon, " ", cfins))
                                    delete!(INSTRBUFFERVIEWERS[ins], addr)
                                    get!(INSTRBUFFERVIEWERS[cfins], addr, InstrBufferViewer(cfins, addr))
                                end
                            end
                            CImGui.EndMenu()
                        end
                        CImGui.EndPopup()
                    end
                    if addrnode
                        @c CImGui.MenuItem(mlstr("Common"), C_NULL, &ibv.p_open)
                        if haskey(INSWCONF, ins)
                            haskey(instrwidgets, addr) || (instrwidgets[addr] = Dict())
                            for w in INSWCONF[ins]
                                if !haskey(instrwidgets[addr], w.name)
                                    instrwidgets[addr][w.name] = (Ref(false), [])
                                end
                                if CImGui.MenuItem(w.name, C_NULL, instrwidgets[addr][w.name][1])
                                    if instrwidgets[addr][w.name][1][]
                                        push!(instrwidgets[addr][w.name][2], deepcopy(w))
                                        initialize!(only(instrwidgets[addr][w.name][2]), addr)
                                    end
                                end
                            end
                        end
                        CImGui.TreePop()
                    end
                end
                # end
                CImGui.TreePop()
            end
            # isempty(inses) && CImGui.PopStyleColor()
        end
        CImGui.EndChild()
        CImGui.PopStyleVar()
        CImGui.PopStyleColor()
    end
end