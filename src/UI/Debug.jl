# uicdbk = UICodeBlock()
# uistbk = UISettingBlock()
# uispbk = UISweepBlock()
# uirdbk = UIReadingBlock()
# uibkch = UIBlockChain()
# uip = UIPlot([1, 2], [3, 4], 100rand(2,2))


# uip.ptype = "scatter"
# uip.z[6] = NaN
let
    # sls = fill(false, 7)
    # sl = ["A", "B", "C", "D", "E", "F", "G"]
    # ft = FileTree(pick_folder())
    cdbk = CodeBlock()
    sdcdbk = StrideCodeBlock(1)
    stbk = SettingBlock()
    spbk = SweepBlock(1)
    rdbk = ReadingBlock()
    bkch = [cdbk, sdcdbk, stbk, spbk, rdbk]
    str = "\0"^6
    # dtviewer = DataViewer("C:\\Users\\22112\\OneDrive - mails.ucas.ac.cn\\文档\\CODE\\Julia\\CImGui-examples\\QInsControl\\2022-12-09\\")
    # dtviewer.data = load(joinpath(dtviewer.filetree.rootpath, "[2022-12-09T09.47.30.743] 任务 1 .jld2"))
    id = "test"
    rnmsel = false
    rnmlabel = "test"
    global function debug(p_open::Ref)
        CImGui.SetNextWindowPos((300, 200), CImGui.ImGuiCond_Appearing)
        CImGui.SetNextWindowSize((600, 600), CImGui.ImGuiCond_Appearing)

        if CImGui.Begin("Debug", p_open)
            # global isremote
            global channel_size
            # global lowest_framerate_limit
            global packsize
            global showlogline
            global isdragging
            CImGui.Button("重置运行") && (syncstates[Int(isdaqtask_running)] = false)
            # @c CImGui.Checkbox("远程/本地", &isremote)
            channel_size_old = channel_size
            @c CImGui.DragInt("通道大小", &channel_size, 1.0, 4)
            if !syncstates[Int(isdaqtask_running)]
                if channel_size != channel_size_old
                    databuf_rc = RemoteChannel(() -> Channel(channel_size))
                    progress_rc = RemoteChannel(() -> Channel(channel_size))
                end
            end
            # @c CImGui.DragInt("最低帧数保护", &lowest_framerate_limit, 1.0, 10)
            @c CImGui.DragInt("打包尺寸", &packsize, 1.0, 1, 60)
            @c CImGui.DragInt("Logger最大行数", &showlogline, 1.0, 100, 6000)
            # @c(RenameSelectable("rename", &rnmlabel, rnmsel)) && (rnmsel ⊻= true)
            # CImGui.Text(string("isdraggin : ", isdragging))
            # CImGui.Text(string("dragblock : ", typeof.(dragblock)))
            # CImGui.Text(string("dropblock : ", typeof.(dropblock)))

            # isempty(daqtasks) || showregion(daqtasks[1].blocks)
            # @cstatic color = Cfloat[1.000, 1.000, 1.000, 1.000] begin
            #     CImGui.ColorEdit4("Test Pick Color4", color, CImGui.ImGuiColorEditFlags_AlphaBar) && CImGui.ImGuiStyle_Set_Colors(CImGui.GetStyle(), CImGui.ImGuiCol_WindowBg, color)
            # end
            # CImGui.ShowStyleSelector("Test")
            # CImGui.ShowUserGuide()
            # CImGui.ShowFlags(CImGui.ImGuiWindowFlags_)
            # CImGui.InputText("Test", str, 100, CImGui.ImGuiInputTextFlags_CallbackResize)
            # @c ComBoS("绘图类型##$id", &uipsweep.ptype, ["line", "scatter", "heatmap"])
            # @c CImGui.InputFloat("轮询时间", &sleeptime, 0, 0, "%.6f")
            # CImGui.ProgressBar(0.5)
            # if isready(progress_remotechannel)
            #     pb = take!(progress_remotechannel)
            #     inflag = false
            #     for (i, p) in enumerate(progresslist)
            #         p[1] == pb[1] && (progresslist[i] = pb; inflag = true; break)
            #     end
            #     inflag || push!(progresslist, pb)
            # end
            # for (i, pgb) in enumerate(progresslist)
            #     # pgb[2] == pgb[3] || CImGui.ProgressBar(pgb[2]/pgb[3], (-1,0), string(pgb[2], "(", tohms(pgb[2]*pgb[4]), ")/", pgb[3], "(", tohms(pgb[3]*pgb[4]), ")"))
            #     pgmark = string(pgb[2], "/", pgb[3], "(", tohms(pgb[4]), "/", tohms(pgb[3]*pgb[4]/pgb[2]), ")")
            #     if pgb[2] == pgb[3]
            #         deleteat!(progresslist, i)
            #     else
            #         CImGui.ProgressBar(pgb[2]/pgb[3], (-1,0), pgmark)
            #     end
            # end
            # view(cdbk, 1)
            # view(sdcdbk, 1)
            # view(stbk, 1)
            # view(spbk, 1)
            # view(rdbk, 1)
            # CImGui.Text("分割线")
            # view(bkch, 1)
            # if CImGui.BeginTabBar("Debug")
            #     if CImGui.BeginTabItem("Debug")
            #         view(dtviewer.data["daqtask"], dtviewer.filetree.selectpath)
            #     end
            # end
            # edit(bkch, 1)

        end

    end
end

# function showregion(blocks)
#     for bk in blocks
#         bk isa NullBlock && continue
#         CImGui.Text("(x1, y1, x2, y2) : $(bk.region)")
#         (bk isa SweepBlock || bk isa StrideCodeBlock) && (CImGui.Indent(); showregion(bk.blocks); CImGui.Unindent())
#     end
#     CImGui.Text(" ")
# end