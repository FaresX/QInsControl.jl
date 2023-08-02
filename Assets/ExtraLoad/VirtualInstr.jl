VirtualInstr_SystemTime_get(_) = string(time())

VirtualInstr_DateTime_get(_) = string(now())

VirtualInstr_Date_get(_) = string(Date(now()))

VirtualInstr_Time_get(_) = string(Time(now()))

# let
#     sweepv::String = "0"
#     global VirtualInstr_SweepTest_set(_, setv) = (sweepv = string(setv))
#     global VirtualInstr_SweepTest_get(_) = sweepv
# end

# VirtualInstr_SweepTest2_set(, setv) = @info "VirtualInstr sweep2 : $setv"
# VirtualInstr_SweepTest2_get() = string(rand(Int8))

# let
#     setval::String = "0"
#     global VirtualInstr_SetTest_set(_, setv) = (setval = string(setv))
#     global VirtualInstr_SetTest_get(_) = setval
# end

let
    I::Float64 = 0
    Iac::Float64 = 0
    Vac::Float64 = 0
    B::Float64 = 0
    Power::String = "0"

    Ic(b) = 1e-6 * (abs(sinc(1e3b)) + randn() * 1e-2)
    IR(i) = Power == "0" ? 0 : (abs(i) > Ic(B) ? 600 * (1 + randn() * 1e-2) : 600 * (randn() * 1e-2))

    global VirtualInstr_I_set(_, setv) = (I = parse(Float64, setv))
    global VirtualInstr_I_get(_) = string(I)

    global VirtualInstr_Iac_set(_, setv) = (Iac = parse(Float64, setv))
    global VirtualInstr_Iac_get(_) = string(Iac)

    global VirtualInstr_Vac_get(_) = string(IR(I) * Iac)

    global VirtualInstr_B_set(_, setv) = (B = parse(Float64, setv))
    global VirtualInstr_B_get(_) = string(B)

    global function VirtualInstr_power_set(_, setv)
        Power = if setv in ["0", "OFF"]
            "0"
        elseif setv in ["1", "ON"]
            "1"
        else
            Power
        end
    end
    global VirtualInstr_power_get(_) = Power
end