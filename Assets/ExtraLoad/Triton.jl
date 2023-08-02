Triton_temperatureT5_get(instr) = split(query(instr, "READ:DEV:T5:TEMP:SIG:TEMP"), "TEMP:")[end][1:end-1]

Triton_temperatureT8_get(instr) = split(query(instr, "READ:DEV:T8:TEMP:SIG:TEMP"), "TEMP:")[end][1:end-1]

Triton_temperatureT13_get(instr) = split(query(instr, "READ:DEV:T13:TEMP:SIG:TEMP"), "TEMP:")[end][1:end-1]