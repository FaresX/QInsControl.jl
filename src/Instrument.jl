function autodetect()
    addrs = find_resources(CPU.resourcemanager)
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
                delete!(instrcontrollers[ins], addr)
            end
        end
        st = false
    end
    if st
        for (ins, cf) in insconf
            if occursin(cf.conf.idn, idn)
                if haskey(instrbufferviewers[ins], addr)
                    return true
                else
                    push!(instrbufferviewers[ins], addr => InstrBufferViewer(ins, addr))
                    newct = Controller(ins, addr)
                    push!(instrcontrollers[ins], addr => newct)
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
    if !syncstates[Int(autodetecting)] && !syncstates[Int(autodetect_done)]
        syncstates[Int(autodetecting)] = true
        remote_do(workers()[1], syncstates) do syncstates
            errormonitor(@async begin
                try
                    autodetect()
                    syncstates[Int(autodetect_done)] = true
                catch e
                    syncstates[Int(autodetect_done)] = true
                    @error "自动查询失败!!!" exception = e
                end
            end)
        end
        poll_autodetect()
    end
end

function poll_autodetect()
    errormonitor(
        @async while true
            if waittime("Autodetect Instruments", 120)
                syncstates[Int(autodetecting)] = false
                syncstates[Int(autodetect_done)] = false
                break
            end
            if syncstates[Int(autodetect_done)]
                instrbufferviewers_remote = remotecall_fetch(() -> instrbufferviewers, workers()[1])
                for ins in keys(instrbufferviewers_remote)
                    ins == "VirtualInstr" && continue
                    empty!(instrbufferviewers[ins])
                    for addr in keys(instrbufferviewers_remote[ins])
                        push!(instrbufferviewers[ins], addr => InstrBufferViewer(ins, addr))
                    end
                end
                syncstates[Int(autodetecting)] = false
                syncstates[Int(autodetect_done)] = false
                break
            else
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
            st = remotecall_fetch(manualadd, workers()[1], addinstr)
            st && (delete!(instrbufferviewers["Others"], addinstr); addinstr = "")
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
                st && (delete!(instrbufferviewers["Others"], newinsaddr); newinsaddr = "")
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