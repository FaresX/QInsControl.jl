function autodetect()
    addrs = remote_find_resources!()
    for addr in addrs
        manualadd(addr)
    end
end

function manualadd(addr)
    addr == "" && return false
    addr == "VIRTUAL::ADDRESS" && return true
    idn = "IDN"
    st = true
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
        for (ins, cf) in INSTRCONF
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
    if !STATES[AutoDetecting] && !STATES[AutoDetectDone]
        STATES[AutoDetecting] = true
        @async_record "refresh_instrlist" begin
            try
                for ins in keys(INSTRBUFFERVIEWERS)
                    ins == "VirtualInstr" && continue
                    empty!(INSTRBUFFERVIEWERS[ins])
                end
                autodetect()
                STATES[AutoDetecting] && (STATES[AutoDetectDone] = true)
            catch e
                STATES[AutoDetecting] && (STATES[AutoDetectDone] = true)
                @error string("[", now(), "]\n", mlstr("auto searching failed!!!")) exception = e
                showbacktrace()
            end
        end
        poll_autodetect()
    end
end

function poll_autodetect()
    @async_record "poll_autodetect" @trycatch mlstr("task failed!!!") begin
        starttime = time()
        while true
            if STATES[AutoDetectDone] || time() - starttime > 180
                STATES[AutoDetecting] = false
                STATES[AutoDetectDone] = false
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
            if !STATES[AutoDetecting] && !STATES[AutoDetectDone]
                STATES[AutoDetecting] = true
                st = manualadd(addinstr)
                st && (addinstr = "")
                time_old = time()
                STATES[AutoDetecting] = false
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
            if !STATES[AutoDetecting] && !STATES[AutoDetectDone]
                STATES[AutoDetecting] = true
                st = manualadd(newinsaddr)
                st && (newinsaddr = "")
                time_old = time()
                STATES[AutoDetecting] = false
            end
        end
        return time() - time_old < 2, st
    end
end