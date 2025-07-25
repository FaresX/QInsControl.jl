idn_get(instr) = eval(Symbol(instr.attr.idnfunc))(instr)

function autodetect()
    addrs = remotecall_fetch(() -> find_resources(CPU), workers()[1])
    for addr in addrs
        manualadd(addr)
    end
end

function manualadd(addr)
    addr == "" && return false
    addr == "VirtualAddress" && return true
    idn = "IDN"
    st = true
    loadattr(addr)
    if occursin("VIRTUAL", addr)
        idn = split(addr, "::")[end]
    else
        attr=getattr(addr)
        idnr = timed_remotecall_fetch(workers()[1], addr, attr; timeout=attr.timeoutr) do addr, attr
            ct = Controller("", addr; buflen=1)
            try
                login!(CPU, ct; attr=attr)
                ct(idn_get, CPU, Val(:read); timeout=attr.timeoutr)
            catch e
                @error "[$(now())]\n$(mlstr("instrument communication failed!!!"))" instrument_address = addr exception = e
                showbacktrace()
            finally
                logout!(CPU, ct)
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
                delete!(INSTRBUFFERVIEWERS["Others"], addr)
                return true
            end
        end
    end
    INSTRBUFFERVIEWERS["Others"][addr] = InstrBufferViewer("Others", addr)
    return false
end

function refresh_instrlist()
    if !SYNCSTATES[Int(AutoDetecting)] && !SYNCSTATES[Int(AutoDetectDone)]
        SYNCSTATES[Int(AutoDetecting)] = true
        @async begin
            try
                for ins in keys(INSTRBUFFERVIEWERS)
                    ins == "VirtualInstr" && continue
                    empty!(INSTRBUFFERVIEWERS[ins])
                end
                autodetect()
                SYNCSTATES[Int(AutoDetecting)] && (SYNCSTATES[Int(AutoDetectDone)] = true)
            catch e
                SYNCSTATES[Int(AutoDetecting)] && (SYNCSTATES[Int(AutoDetectDone)] = true)
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
            if SYNCSTATES[Int(AutoDetectDone)] || time() - starttime > 180
                SYNCSTATES[Int(AutoDetecting)] = false
                SYNCSTATES[Int(AutoDetectDone)] = false
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
            if !SYNCSTATES[Int(AutoDetecting)] && !SYNCSTATES[Int(AutoDetectDone)]
                SYNCSTATES[Int(AutoDetecting)] = true
                st = manualadd(addinstr)
                st && (addinstr = "")
                time_old = time()
                SYNCSTATES[Int(AutoDetecting)] = false
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
            if !SYNCSTATES[Int(AutoDetecting)] && !SYNCSTATES[Int(AutoDetectDone)]
                SYNCSTATES[Int(AutoDetecting)] = true
                st = manualadd(newinsaddr)
                st && (newinsaddr = "")
                time_old = time()
                SYNCSTATES[Int(AutoDetecting)] = false
            end
        end
        return time() - time_old < 2, st
    end
end