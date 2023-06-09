function autodetect()
    addrs = find_resources(CPU)
    for addr in addrs
        manualadd(addr)
    end
end

function manualadd(addr)
    idn = "IDN"
    st = true
    ct = Controller("", addr)
    try
        login!(CPU, ct)
        idn = ct(query, CPU, "*IDN?", Val(:query))
        logout!(CPU, ct)
    catch e
        @error "[$(now())]\n仪器通讯故障！！！" instrument_address = addr exception = e
        logout!(CPU, addr)
        for ins in keys(instrbufferviewers)
            ins == "Others" && continue
            if haskey(instrbufferviewers[ins], addr)
                delete!(instrbufferviewers[ins], addr)
            end
        end
        st = false
    end
    if st
        for (ins, cf) in insconf
            if true in occursin.(split(cf.conf.idn, ';'), idn)
                if haskey(instrbufferviewers[ins], addr)
                    return true
                else
                    push!(instrbufferviewers[ins], addr => InstrBufferViewer(ins, addr))
                    return true
                end
            end
        end
    end
    if addr != ""
        push!(instrbufferviewers["Others"], addr => InstrBufferViewer("Others", addr))
    end
    return st
end

function refresh_instrlist()
    if !SyncStates[Int(autodetecting)] && !SyncStates[Int(autodetect_done)]
        SyncStates[Int(autodetecting)] = true
        remote_do(workers()[1], SyncStates) do SyncStates
            errormonitor(@async begin
                try
                    for ins in keys(instrbufferviewers)
                        ins == "VirtualInstr" && continue
                        empty!(instrbufferviewers[ins])
                    end
                    autodetect()
                    SyncStates[Int(autodetecting)] && (SyncStates[Int(autodetect_done)] = true)
                catch e
                    SyncStates[Int(autodetecting)] && (SyncStates[Int(autodetect_done)] = true)
                    @error "自动查询失败!!!" exception = e
                end
            end)
        end
        poll_autodetect()
    end
end

function poll_autodetect()
    errormonitor(
        @async begin
            starttime = time()
            while true
                if time() - starttime > 180
                    SyncStates[Int(autodetecting)] = false
                    SyncStates[Int(autodetect_done)] = false
                    break
                end
                if SyncStates[Int(autodetect_done)]
                    instrbufferviewers_remote = remotecall_fetch(() -> instrbufferviewers, workers()[1])
                    for ins in keys(instrbufferviewers_remote)
                        ins == "VirtualInstr" && continue
                        empty!(instrbufferviewers[ins])
                        for addr in keys(instrbufferviewers_remote[ins])
                            push!(instrbufferviewers[ins], addr => InstrBufferViewer(ins, addr))
                        end
                    end
                    SyncStates[Int(autodetecting)] = false
                    SyncStates[Int(autodetect_done)] = false
                    break
                else
                    yield()
                end
            end
        end
    )
end

function fetch_ibvs(addinstr)
    remotecall_wait(workers()[1], addinstr) do addinstr
        delete!(instrbufferviewers["Others"], addinstr)
    end
    delete!(instrbufferviewers["Others"], addinstr)
    instrbufferviewers_remote = remotecall_fetch(() -> instrbufferviewers, workers()[1])
    for ins in keys(instrbufferviewers_remote)
        ins == "VirtualInstr" && continue
        for addr in keys(instrbufferviewers_remote[ins])
            haskey(instrbufferviewers[ins], addr) && continue
            push!(instrbufferviewers[ins], addr => InstrBufferViewer(ins, addr))
        end
    end
end

let
    addinstr::String = ""
    st::Bool = false
    time_old::Float64 = 0
    global function manualadd_from_others()
        @c ComBoS("##OthersIns", &addinstr, keys(instrbufferviewers["Others"]))
        if CImGui.Button(morestyle.Icons.NewFile * " 添加  ")
            st = remotecall_fetch(manualadd, workers()[1], addinstr)
            st && (fetch_ibvs(addinstr); addinstr = "")
            time_old = time()
        end
        if time() - time_old < 2
            CImGui.SameLine()
            if st
                CImGui.TextColored(morestyle.Colors.HighlightText, "添加成功！")
            else
                CImGui.TextColored(morestyle.Colors.LogError, "添加失败！！！")
            end
        end
    end
end

let
    newinsaddr::String = ""
    st::Bool = false
    time_old::Float64 = 0
    global function manualadd_ui()
        if CImGui.CollapsingHeader("\t\t\tOthers\t\t\t\t\t\t")
            manualadd_from_others()
        end
        if CImGui.CollapsingHeader("\t\t\t手动输入\t\t\t\t\t\t")
            @c InputTextWithHintRSZ("##手动输入仪器地址", "仪器地址", &newinsaddr)
            if CImGui.BeginPopup("选择常用地址")
                for addr in conf.ComAddr.addrs
                    addr == "" && (CImGui.TextColored(morestyle.Colors.HighlightText, "不可用的选项！");
                    continue)
                    CImGui.MenuItem(addr) && (newinsaddr = addr)
                end
                CImGui.EndPopup()
            end
            CImGui.OpenPopupOnItemClick("选择常用地址", 1)
            if CImGui.Button(morestyle.Icons.NewFile * " 添加  ##手动输入仪器地址")
                st = remotecall_fetch(manualadd, workers()[1], newinsaddr)
                st && (fetch_ibvs(newinsaddr); newinsaddr = "")
                time_old = time()
            end
            if time() - time_old < 2
                CImGui.SameLine()
                if st
                    CImGui.TextColored(morestyle.Colors.HighlightText, "添加成功！")
                else
                    CImGui.TextColored(morestyle.Colors.LogError, "添加失败！！！")
                end
            end
        end
    end
end