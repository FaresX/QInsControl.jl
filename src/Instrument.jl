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
        lk = ReentrantLock()
        errormonitor(Threads.@spawn begin
            lock(lk)
            try
                for ins in keys(instrbufferviewers)
                    ins == "VirtualInstr" && continue
                    empty!(instrbufferviewers[ins])
                end
                autodetect()
                SyncStates[Int(autodetect_done)] = true
            catch e
                SyncStates[Int(autodetect_done)] = true
                @error "自动查询失败!!!" exception = e
            finally
                unlock(lk)
            end
        end)
    end
    poll_autodetect()
end

function poll_autodetect()
    errormonitor(
        @async begin
            starttime = time()
            while true
                if time() - starttime > 120 || SyncStates[Int(autodetect_done)]
                    SyncStates[Int(autodetecting)] = false
                    SyncStates[Int(autodetect_done)] = false
                    break
                end
                yield()
            end
        end
    )
end

let
    addinstr::String = ""
    st::Bool = false
    time_old::Float64 = 0
    global function manualadd_from_others()
        @c ComBoS("##OthersIns", &addinstr, keys(instrbufferviewers["Others"]))
        if CImGui.Button(morestyle.Icons.NewFile * " 添加  ")
            st = manualadd(addinstr)
            st && (addinstr = "")
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
                st = manualadd(newinsaddr)
                st && (newinsaddr = "")
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