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