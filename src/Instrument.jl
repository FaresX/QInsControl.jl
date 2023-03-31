mutable struct GPIBInstr <: Instrument
    name::String
    addr::String
    geninstr::GenericInstrument
end

mutable struct SerialInstr <: Instrument
    name::String
    addr::String
    geninstr::GenericInstrument
end

mutable struct TCPIPInstr <: Instrument
    name::String
    addr
    ip::T where {T<:IPAddr}
    port::Int
    sock::TCPSocket
end

Base.@kwdef struct VirtualInstr <: Instrument
    name::String = "VirtualInstr"
    addr::String = "VirtualAddress"
end

function instrument(name, addr)
    if occursin("GPIB", addr)
        return GPIBInstr(name, addr, GenericInstrument())
    elseif occursin("ASRL", addr)
        return SerialInstr(name, addr, GenericInstrument())
    elseif occursin("TCPIP", addr) && occursin("SOCKET", addr)
        try
            _, ip, portstr, _ = split(addr, "::")
            port = parse(Int, portstr)
            return TCPIPInstr(name, addr, IPv4(ip), port, TCPSocket())
        catch e
            @error "[$(now())]\n通信地址有误！！！" execption = e
            return GPIBInstr(name, addr, GenericInstrument())
        end
    elseif name == "VirtualInstr"
        return VirtualInstr()
    else
        return GPIBInstr(name, addr, GenericInstrument())
    end
end

Instruments.connect!(rm, instr::GPIBInstr) = connect!(rm, instr.geninstr, instr.addr)
Instruments.connect!(rm, instr::SerialInstr) = connect!(rm, instr.geninstr, instr.addr)
Instruments.connect!(rm, instr::TCPIPInstr) = (instr.sock = Sockets.connect(instr.ip, instr.port))
Instruments.connect!(rm, instr::VirtualInstr) = nothing
Instruments.connect!(instr::T) where {T<:Instrument} = connect!(ResourceManager(), instr)

Instruments.disconnect!(instr::GPIBInstr) = disconnect!(instr.geninstr)
Instruments.disconnect!(instr::SerialInstr) = disconnect!(instr.geninstr)
Instruments.disconnect!(instr::TCPIPInstr) = close(instr.sock)
Instruments.disconnect!(::VirtualInstr) = nothing

Instruments.write(instr::GPIBInstr, msg::AbstractString) = write(instr.geninstr, msg)
Instruments.write(instr::SerialInstr, msg::AbstractString) = write(instr.geninstr, string(msg, "\n"))
Instruments.write(instr::TCPIPInstr, msg::AbstractString) = println(instr.sock, msg)
Instruments.write(::VirtualInstr, ::AbstractString) = nothing

Instruments.read(instr::GPIBInstr) = read(instr.geninstr)
Instruments.read(instr::SerialInstr) = read(instr.geninstr)
Instruments.read(instr::TCPIPInstr) = readline(instr.sock)
Instruments.read(::VirtualInstr) = nothing

Instruments.query(instr::GPIBInstr, msg::AbstractString; delay=0) = query(instr.geninstr, msg; delay=delay)
Instruments.query(instr::SerialInstr, msg::AbstractString; delay=0) = query(instr.geninstr, string(msg, "\n"); delay=delay)
Instruments.query(instr::TCPIPInstr, msg::AbstractString; delay=0) = (println(instr.sock, msg); sleep(delay); readline(instr.sock))
Instruments.query(::VirtualInstr, ::AbstractString; delay=0) = nothing

function autodetect()
    rm = ResourceManager()
    addrs = find_resources(rm)
    for addr in addrs
        manualadd(rm, addr)
        yield()
    end
end

function manualadd(rm, addr)
    idn = ""
    st = true
    instr = instrument("none", addr)
    try
        connect!(rm, instr)
        idn = query(instr, "*IDN?")
        disconnect!(instr)
    catch e
        @error "[$(now())]\n仪器通讯故障！！！" instrument_address = addr exception = e
        for ins in setdiff(keys(instrlist), Set(["Others"]))
            addr in instrlist[ins] && deleteat!(instrlist[ins], findall(==(addr), instrlist[ins]))
            haskey(instrbuffer[ins], addr) && delete!(instrbuffer[ins], addr)
        end
        disconnect!(instr)
        st = false
    end
    if st
        for (ins, cf) in insconf
            if occursin(cf.conf.idn, idn)
                if addr in instrlist[ins]
                    return true
                else
                    push!(instrlist[ins], addr)
                    push!(instrbuffer[ins], addr => InstrBuffer(ins))
                    push!(instrbufferviewers[ins], addr => InstrBufferViewer(ins, addr))
                    return true
                end
            end
        end
    end
    if !(addr == "" || addr in instrlist["Others"])
        push!(instrlist["Others"], addr)
        push!(instrbuffer["Others"], addr => InstrBuffer("Others"))
    end
    return st
end

macro trylink_do(instr, casen, casee)
    ex = quote
        try
            connect!($instr)
            $casen
        catch e
            @error "[$(now())]\n仪器通讯故障！！！" instrument_address = instr.addr exception = e
            $casee
        finally
            disconnect!($instr)
        end
    end
    esc(ex)
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
                instrlist_remote::Dict{String,Vector{String}} = remotecall_fetch(() -> instrlist, workers()[1])
                instrbuffer_remote::Dict{String,Dict{String,InstrBuffer}} = remotecall_fetch(() -> instrbuffer, workers()[1])
                empty!(instrlist)
                merge!(instrlist, instrlist_remote)
                for ins in setdiff(keys(instrbuffer), Set(["VirtualInstr"]))
                    empty!(instrbuffer[ins])
                    empty!(instrbufferviewers[ins])
                    for addr in keys(instrbuffer_remote[ins])
                        push!(instrbuffer[ins], addr => InstrBuffer(ins))
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
    addinstr = ""
    st = false
    time_old = 0
    global function manualadd_from_others()
        @c ComBoS("##OthersIns", &addinstr, instrlist["Others"])
        if CImGui.Button(morestyle.Icons.NewFile * " 添加  ")
            st = manualadd(ResourceManager(), addinstr)
            if st
                for (i, v) in enumerate(instrlist["Others"])
                    v == addinstr && (deleteat!(instrlist["Others"], i); break)
                end
                addinstr = ""
            end
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
                st = manualadd(ResourceManager(), newinsaddr)
                if st
                    for (i, v) in enumerate(instrlist["Others"])
                        v == newinsaddr && (deleteat!(instrlist["Others"], i); break)
                    end
                    newinsaddr = ""
                end
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