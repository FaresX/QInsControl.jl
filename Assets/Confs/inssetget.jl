######VirtualInstr######------------------------------------------------------------------------------------------------
VirtualInstr_SystemTime_get(_) = string(time())

VirtualInstr_DateTime_get(_) = string(now())

VirtualInstr_Date_get(_) = string(Date(now()))

VirtualInstr_Time_get(_) = string(Time(now()))

let 
    sweepv::String = "0"
    global VirtualInstr_SweepTest_set(_, setv) = (sweepv = string(setv))
    global VirtualInstr_SweepTest_get(_) = sweepv
end

# VirtualInstr_SweepTest2_set(, setv) = @info "VirtualInstr sweep2 : $setv"
# VirtualInstr_SweepTest2_get() = string(rand(Int8))

let 
    setval::String = "0"
    global VirtualInstr_SetTest_set(_, setv) = (setval = string(setv))
    global VirtualInstr_SetTest_get(_) = setval
end

# VirtualInstr_SetTest2_set(, setv) = @info "VirtualInstr set2 : $setv"
# VirtualInstr_SetTest2_get() = string(rand(Int8))

######LI5640######------------------------------------------------------------------------------------------------------
# LI5640_tconst_set(instr, val) = query(instr, "BTC $val")
# LI5640_tconst_get(instr) = query(instr, "?BTC")

# LI5640_dynres_set(instr, val) = query(instr, "BDR $val")
# LI5640_dynres_get(instr) = query(instr, "?BDR")

######Mercury IPS######-------------------------------------------------------------------------------------------------
###X Field###
MercuryIPS_sigrfstx_set(instr, val) = query(instr, "SET:DEV:GRPX:PSU:SIG:RFST:$val")
MercuryIPS_sigrfstx_get(instr) = split(query(instr, "READ:DEV:GRPX:PSU:SIG:RFST"), "RFST:")[end][1:end-3]

MercuryIPS_sigfsetx_set(instr, val) = query(instr, "SET:DEV:GRPX:PSU:SIG:FSET:$val")
MercuryIPS_sigfsetx_get(instr) = split(query(instr, "READ:DEV:GRPX:PSU:SIG:FSET"), "FSET:")[end][1:end-1]

MercuryIPS_sigactnx_set(instr, val) = query(instr, "SET:DEV:GRPX:PSU:ACTN:$val")
MercuryIPS_sigactnx_get(instr) = split(query(instr, "READ:DEV:GRPX:PSU:ACTN"), "ACTN:")[end]

MercuryIPS_sigpfldx_get(instr) = split(query(instr, "READ:DEV:GRPX:PSU:SIG:PFLD"), "PFLD:")[end][1:end-1]

MercuryIPS_sigfldx_get(instr) = split(query(instr, "READ:DEV:GRPX:PSU:SIG:FLD"), "FLD:")[end][1:end-1]

###Y Field###
MercuryIPS_sigrfsty_set(instr, val) = query(instr, "SET:DEV:GRPY:PSU:SIG:RFST:$val")
MercuryIPS_sigrfsty_get(instr) = split(query(instr, "READ:DEV:GRPY:PSU:SIG:RFST"), "RFST:")[end][1:end-3]

MercuryIPS_sigfsety_set(instr, val) = query(instr, "SET:DEV:GRPY:PSU:SIG:FSET:$val")
MercuryIPS_sigfsety_get(instr) = split(query(instr, "READ:DEV:GRPY:PSU:SIG:FSET"), "FSET:")[end][1:end-1]

MercuryIPS_sigactny_set(instr, val) = query(instr, "SET:DEV:GRPY:PSU:ACTN:$val")
MercuryIPS_sigactny_get(instr) = split(query(instr, "READ:DEV:GRPY:PSU:ACTN"), "ACTN:")[end]

MercuryIPS_sigpfldy_get(instr) = split(query(instr, "READ:DEV:GRPY:PSU:SIG:PFLD"), "PFLD:")[end][1:end-1]

MercuryIPS_sigfldy_get(instr) = split(query(instr, "READ:DEV:GRPY:PSU:SIG:FLD"), "FLD:")[end][1:end-1]

###Z Field###
MercuryIPS_sigrfstz_set(instr, val) = query(instr, "SET:DEV:GRPZ:PSU:SIG:RFST:$val")
MercuryIPS_sigrfstz_get(instr) = split(query(instr, "READ:DEV:GRPZ:PSU:SIG:RFST"), "RFST:")[end][1:end-3]

MercuryIPS_sigfsetz_set(instr, val) = query(instr, "SET:DEV:GRPZ:PSU:SIG:FSET:$val")
MercuryIPS_sigfsetz_get(instr) = split(query(instr, "READ:DEV:GRPZ:PSU:SIG:FSET"), "FSET:")[end][1:end-1]

MercuryIPS_sigactnz_set(instr, val) = query(instr, "SET:DEV:GRPZ:PSU:ACTN:$val")
MercuryIPS_sigactnz_get(instr) = split(query(instr, "READ:DEV:GRPZ:PSU:ACTN"), "ACTN:")[end]

MercuryIPS_sigpfldz_get(instr) = split(query(instr, "READ:DEV:GRPZ:PSU:SIG:PFLD"), "PFLD:")[end][1:end-1]

MercuryIPS_sigfldz_get(instr) = split(query(instr, "READ:DEV:GRPZ:PSU:SIG:PFLD"), "FLD:")[end][1:end-1]

######Triton######------------------------------------------------------------------------------------------------------
Triton_temperatureT5_get(instr) = split(query(instr, "READ:DEV:T5:TEMP:SIG:TEMP"), "TEMP:")[end][1:end-1]

Triton_temperatureT8_get(instr) = split(query(instr, "READ:DEV:T8:TEMP:SIG:TEMP"), "TEMP:")[end][1:end-1]

Triton_temperatureT13_get(instr) = split(query(instr, "READ:DEV:T13:TEMP:SIG:TEMP"), "TEMP:")[end][1:end-1]