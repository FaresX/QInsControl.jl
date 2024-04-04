function autodetect()
    addrs = remotecall_fetch(() -> find_resources(CPU), workers()[1])
    for addr in addrs
        manualadd(addr)
    end
end

function manualadd(addr)
    addr == "VirtualAddress" && return true
    idn = "IDN"
    st = true
    if occursin("VIRTUAL", addr)
        idn = split(addr, "::")[end]
    else
        idnr = wait_remotecall_fetch(workers()[1], addr) do addr
            ct = Controller("", addr; ctbuflen=1 , timeout=CONF.DAQ.cttimeout)
            try
                login!(CPU, ct)
                retstr = ct(query, CPU, "*IDN?", Val(:query))
                logout!(CPU, ct)
                return retstr
            catch e
                logout!(CPU, ct)
                @error "[$(now())]\n$(mlstr("instrument communication failed!!!"))" instrument_address = addr exception = e
            end
        end
        if isnothing(idnr)
            for ins in keys(INSTRBUFFERVIEWERS)
                ins == "Others" && continue
                delete!(INSTRBUFFERVIEWERS[ins], addr)
            end
            st = false
        else
            idn = idnr
        end
    end
    if st
        for (ins, cf) in INSCONF
            if true in occursin.(split(cf.conf.idn, ';'), idn)
                get!(INSTRBUFFERVIEWERS[ins], addr, InstrBufferViewer(ins, addr))
                return true
            end
        end
    end
    addr == "" || push!(INSTRBUFFERVIEWERS["Others"], addr => InstrBufferViewer("Others", addr))
    return st
end

function refresh_instrlist()
    if !SYNCSTATES[Int(AutoDetecting)] && !SYNCSTATES[Int(AutoDetectDone)]
        SYNCSTATES[Int(AutoDetecting)] = true
        errormonitor(@async begin
            try
                for ins in keys(INSTRBUFFERVIEWERS)
                    ins == "VirtualInstr" && continue
                    empty!(INSTRBUFFERVIEWERS[ins])
                end
                autodetect()
                SYNCSTATES[Int(AutoDetecting)] && (SYNCSTATES[Int(AutoDetectDone)] = true)
            catch e
                SYNCSTATES[Int(AutoDetecting)] && (SYNCSTATES[Int(AutoDetectDone)] = true)
                @error mlstr("auto searching failed!!!") exception = e
            end
        end)
        poll_autodetect()
    end
end

function poll_autodetect()
    errormonitor(
        @async begin
            starttime = time()
            while true
                if SYNCSTATES[Int(AutoDetectDone)] || time() - starttime > 180
                    SYNCSTATES[Int(AutoDetecting)] = false
                    SYNCSTATES[Int(AutoDetectDone)] = false
                    break
                end
                sleep(0.001)
            end
        end
    )
end

let
    addinstr::String = ""
    st::Bool = false
    time_old::Float64 = 0
    global function manualadd_from_others()
        @c ComboS("##OthersIns", &addinstr, keys(INSTRBUFFERVIEWERS["Others"]))
        CImGui.SameLine()
        if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile))
            errormonitor(
                @async begin
                    if !SYNCSTATES[Int(AutoDetecting)] && !SYNCSTATES[Int(AutoDetectDone)]
                        SYNCSTATES[Int(AutoDetecting)] = true
                        st = manualadd(addinstr)
                        st && (addinstr = "")
                        time_old = time()
                        SYNCSTATES[Int(AutoDetecting)] = false
                    end
                end
            )
        end
        return time() - time_old < 2, st
    end
end

let
    newinsaddr::String = ""
    st::Bool = false
    time_old::Float64 = 0
    global function manualadd_from_input()
        @c InputTextWithHintRSZ("##manual input addr", mlstr("instrument address"), &newinsaddr)
        if CImGui.BeginPopupContextItem()
            isempty(CONF.ComAddr.addrs) && CImGui.TextColored(
                MORESTYLE.Colors.HighlightText,
                mlstr("unavailable options!")
            )
            for addr in CONF.ComAddr.addrs
                addr == "" && continue
                CImGui.MenuItem(addr) && (newinsaddr = addr)
            end
            CImGui.EndPopup()
        end
        CImGui.SameLine()
        if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile, "##manual input addr"))
            errormonitor(
                @async begin
                    if !SYNCSTATES[Int(AutoDetecting)] && !SYNCSTATES[Int(AutoDetectDone)]
                        SYNCSTATES[Int(AutoDetecting)] = true
                        st = manualadd(newinsaddr)
                        st && (newinsaddr = "")
                        time_old = time()
                        SYNCSTATES[Int(AutoDetecting)] = false
                    end
                end
            )
        end
        return time() - time_old < 2, st
    end
end