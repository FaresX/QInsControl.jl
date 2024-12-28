let
    DATABUFranges = Dict{String,Tuple{Ref{Cint},Ref{Cint}}}()
    DATABUFPARSEDranges = Dict{String,Tuple{Ref{Cint},Ref{Cint}}}()
    extension_module = Base.get_extension(CImGui, :GlfwOpenGLBackend)
    global function Debugger(p_open::Ref{Bool})
        CImGui.SetNextWindowSize(CImGui.ImVec2(400, 600), CImGui.ImGuiCond_Once)
        if CImGui.Begin("Debugger", p_open)

            if CImGui.TreeNode("Global Variables")

                if CImGui.TreeNode("SYNCSTATES")
                    if CImGui.BeginTable(
                        "SYNCSTATES",
                        length(instances(SyncStatesIndex)),
                        CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable
                    )
                        for state in instances(SyncStatesIndex)
                            CImGui.TableSetupColumn(string(state))
                        end
                        CImGui.TableHeadersRow()
                        CImGui.TableNextRow()
                        for state in instances(SyncStatesIndex)
                            CImGui.TableNextColumn()
                            CImGui.Text(stcstr(SYNCSTATES[Int(state)]))
                        end
                        CImGui.EndTable()
                    end
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("DATABUF ($(length(DATABUF)))###DATABUF")
                    for (key, val) in DATABUF
                        n = length(val)
                        haskey(DATABUFranges, key) || (DATABUFranges[key] = (1, min(10, n)))
                        CImGui.DragIntRange2(
                            stcstr("##", key),
                            DATABUFranges[key][1], DATABUFranges[key][2],
                            1, 1, n, "begin: %d", "end: %d",
                            CImGui.ImGuiSliderFlags_AlwaysClamp
                        )
                        SeparatorTextColored(MORESTYLE.Colors.HighlightText, key)
                        CImGui.PushTextWrapPos(0)
                        CImGui.TextUnformatted(string(val[DATABUFranges[key][1][]:DATABUFranges[key][2][]]))
                        CImGui.PopTextWrapPos()
                    end
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("DATABUFPARSED ($(length(DATABUFPARSED)))###DATABUFPARSED")
                    for (key, val) in DATABUFPARSED
                        n = length(val)
                        haskey(DATABUFPARSEDranges, key) || (DATABUFPARSEDranges[key] = (1, min(10, n)))
                        CImGui.DragIntRange2(
                            stcstr("##", key),
                            DATABUFPARSEDranges[key][1], DATABUFPARSEDranges[key][2],
                            1, 1, n, "begin: %d", "end: %d",
                            CImGui.ImGuiSliderFlags_AlwaysClamp
                        )
                        SeparatorTextColored(MORESTYLE.Colors.HighlightText, key)
                        CImGui.PushTextWrapPos(0)
                        CImGui.TextUnformatted(string(val[DATABUFPARSEDranges[key][1][]:DATABUFPARSEDranges[key][2][]]))
                        CImGui.PopTextWrapPos()
                    end
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("PROGRESSLIST ($(length(PROGRESSLIST)))###PROGRESSLIST")
                    for (key, val) in PROGRESSLIST
                        SeparatorTextColored(MORESTYLE.Colors.HighlightText, string(key))
                        CImGui.PushTextWrapPos(0)
                        CImGui.TextUnformatted(string(val))
                        CImGui.PopTextWrapPos()
                    end
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("STYLES ($(length(STYLES)))###STYLES")
                    CImGui.PushTextWrapPos(0)
                    CImGui.TextUnformatted(string(keys(STYLES)))
                    CImGui.PopTextWrapPos()
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("MLSTRINGS ($(length(MLSTRINGS)))###MLSTRINGS")
                    for (key, val) in MLSTRINGS
                        CImGui.TextColored(MORESTYLE.Colors.HighlightText, string(key, " : "))
                        CImGui.SameLine()
                        CImGui.Text(val)
                    end
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("STATICSTRINGS ($(length(STATICSTRINGS)))###STATICSTRINGS")
                    for (key, val) in STATICSTRINGS
                        CImGui.TextColored(MORESTYLE.Colors.HighlightText, string(key, " : "))
                        CImGui.SameLine()
                        CImGui.Text(val.str)
                        CImGui.SameLine()
                        CImGui.TextColored(
                            val.update ? MORESTYLE.Colors.InfoText : MORESTYLE.Colors.WarnText,
                            string(val.update)
                        )
                    end
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("IMAGES ($(length(IMAGES)))###IMAGES")
                    for (key, val) in IMAGES
                        SeparatorTextColored(MORESTYLE.Colors.HighlightText, key)
                        availwidth = CImGui.GetCursorScreenPos().x + CImGui.GetContentRegionAvail().x
                        for (i, id) in enumerate(val.data)
                            CImGui.Image(CImGui.ImTextureID(id), CImGui.ImVec2(60, 60))
                            CImGui.GetItemRectMax().x + 60 + unsafe_load(IMGUISTYLE.ItemSpacing.x) < availwidth &&
                                i != length(val) && CImGui.SameLine()
                            id == val[] && CImGui.AddRect(
                                CImGui.GetWindowDrawList(),
                                CImGui.GetItemRectMin(), CImGui.GetItemRectMax(),
                                MORESTYLE.Colors.InfoText, 0, 0, 2
                            )
                        end
                    end
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("Textures ($(length(extension_module.g_ImageTexture)))###Textures")
                    availwidth = CImGui.GetCursorScreenPos().x + CImGui.GetContentRegionAvail().x
                    for (i, id) in enumerate(keys(extension_module.g_ImageTexture))
                        CImGui.BeginGroup()
                        CImGui.Text(string(id))
                        CImGui.Image(CImGui.ImTextureID(id), CImGui.ImVec2(60, 60))
                        CImGui.EndGroup()
                        CImGui.GetItemRectMax().x + 60 + unsafe_load(IMGUISTYLE.ItemSpacing.x) < availwidth &&
                            i != length(extension_module.g_ImageTexture) && CImGui.SameLine()
                    end
                    CImGui.TreePop()
                end

                if CImGui.TreeNode("FIGURES ($(length(FIGURES)))###FIGURES")
                    CImGui.PushTextWrapPos(0)
                    CImGui.TextUnformatted(string(keys(FIGURES)))
                    CImGui.PopTextWrapPos()
                    CImGui.TreePop()
                end

                CImGui.TreePop()
            end

        end
        CImGui.End()
    end
end