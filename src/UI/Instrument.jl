function autodetect()
    addrs = remote_find_resources!()
    for addr in addrs
        manualadd(addr)
    end
end

function manualadd(addr)
    addr == "" && return false
    addr == "VirtualAddress" && return true
    idn = "IDN"
    st = true
    loadattr(CONF.Communication.attrlist, addr)
    syncattr(addr)
    if occursin("VIRTUAL", addr)
        idn = split(addr, "::")[end]
    else
        idnr = remote_idn_get(addr)
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
                delete!(INSTRBUFFERVIEWERS["Others"], addr)
                return true
            end
        end
    end
    INSTRBUFFERVIEWERS["Others"][addr] = InstrBufferViewer("Others", addr)
    return false
end

function refresh_instrlist()
    if !STATES[Int(AutoDetecting)] && !STATES[Int(AutoDetectDone)]
        STATES[Int(AutoDetecting)] = true
        @async begin
            try
                for ins in keys(INSTRBUFFERVIEWERS)
                    ins == "VirtualInstr" && continue
                    empty!(INSTRBUFFERVIEWERS[ins])
                end
                autodetect()
                STATES[Int(AutoDetecting)] && (STATES[Int(AutoDetectDone)] = true)
            catch e
                STATES[Int(AutoDetecting)] && (STATES[Int(AutoDetectDone)] = true)
                @error string("[", now(), "]\n", mlstr("auto searching failed!!!")) exception = e
                showbacktrace()
            end
        end
        poll_autodetect()
    end
end

function poll_autodetect()
    @async @trycatch mlstr("task failed!!!") begin
        starttime = time()
        while true
            if STATES[Int(AutoDetectDone)] || time() - starttime > 180
                STATES[Int(AutoDetecting)] = false
                STATES[Int(AutoDetectDone)] = false
                break
            end
            sleep(0.001)
        end
    end
end

let
    addinstr::String = ""
    st::Bool = false
    time_old::Float64 = 0
    global function manualadd_from_others()
        @c ComboS("##OthersIns", &addinstr, keys(INSTRBUFFERVIEWERS["Others"]))
        CImGui.SameLine()
        if CImGui.Button(stcstr(MORESTYLE.Icons.NewFile))
            if !STATES[Int(AutoDetecting)] && !STATES[Int(AutoDetectDone)]
                STATES[Int(AutoDetecting)] = true
                st = manualadd(addinstr)
                st && (addinstr = "")
                time_old = time()
                STATES[Int(AutoDetecting)] = false
            end
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
            if !STATES[Int(AutoDetecting)] && !STATES[Int(AutoDetectDone)]
                STATES[Int(AutoDetecting)] = true
                st = manualadd(newinsaddr)
                st && (newinsaddr = "")
                time_old = time()
                STATES[Int(AutoDetecting)] = false
            end
        end
        return time() - time_old < 2, st
    end
end