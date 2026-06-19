@kwdef mutable struct InstrAlias
    alias::String = mlstr("Alias")
    instrnm::String = mlstr("Instrument")
    addr::String = mlstr("Address")
end
global INSTRALIASLIST::OrderedDict{String,InstrAlias} = Dict(
    "Virtual" => InstrAlias(alias="Virtual", instrnm="VirtualInstr", addr="VirtualAddress")
)
let
    hold::Bool = false
    global function editinstraliaslist(p_open::Ref{Bool})
        CImGui.SetNextWindowSize((400, 600), CImGui.ImGuiCond_Once)
        isfocus = true
        if @c (CImGui.Begin(mlstr("Edit Instrument Alias List"), p_open))
            if CImGui.Button(MORESTYLE.Icons.NewFile)
                alias = string(mlstr("Alias"), " ", length(INSTRALIASLIST) + 1)
                INSTRALIASLIST[alias] = InstrAlias(alias=alias)
            end
            CImGui.SameLine()
            CImGui.Button(MORESTYLE.Icons.Delete) && !isempty(INSTRALIASLIST) && pop!(INSTRALIASLIST)
            CImGui.SameLine()
            @c ToggleButton(MORESTYLE.Icons.HoldPin, &hold)
            CImGui.Separator()
            if CImGui.BeginTable(
                mlstr("Instrument Alias List"), 3,
                CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
            )
                CImGui.TableSetupScrollFreeze(0, 1)
                CImGui.TableSetupColumn(mlstr("Alias"))
                CImGui.TableSetupColumn(mlstr("Instrument"))
                CImGui.TableSetupColumn(mlstr("Address"))
                CImGui.TableHeadersRow()

                inses = sort([ins for ins in keys(INSTRBUFFERVIEWERS) if ins != "Others" && !isempty(INSTRBUFFERVIEWERS[ins])])
                for (i, (key, item)) in enumerate(INSTRALIASLIST)
                    CImGui.TableNextRow()
                    CImGui.TableSetColumnIndex(0)
                    CImGui.PushItemWidth(-1)
                    @c InputTextWithHintRSZ(stcstr("##alias", i), mlstr("Alias"), &item.alias)
                    CImGui.PopItemWidth()
                    if CImGui.IsItemDeactivatedAfterEdit()
                        if lstrip(item.alias) == ""
                            item.alias = key
                        else
                            newkey!(INSTRALIASLIST, key, item.alias)
                        end
                    end

                    CImGui.TableSetColumnIndex(1)
                    CImGui.PushItemWidth(-1)
                    @c ComboSFiltered(stcstr("##Instrument", i), &item.instrnm, inses)
                    CImGui.PopItemWidth()

                    CImGui.TableSetColumnIndex(2)
                    inlist = haskey(INSTRBUFFERVIEWERS, item.instrnm) &&
                             haskey(INSTRBUFFERVIEWERS[item.instrnm], item.addr)
                    item.addr = inlist ? item.addr : mlstr("address")
                    addrlist = haskey(INSTRBUFFERVIEWERS, item.instrnm) ? keys(INSTRBUFFERVIEWERS[item.instrnm]) : Set{String}()
                    CImGui.PushItemWidth(-1)
                    @c ComboS(stcstr("##Address", i), &item.addr, sort(collect(addrlist)))
                    CImGui.PopItemWidth()
                end

                CImGui.EndTable()
            end
            isfocus &= CImGui.IsWindowFocused(CImGui.ImGuiFocusedFlags_ChildWindows)
        end
        CImGui.End()
        p_open[] &= (isfocus | hold)
    end
end