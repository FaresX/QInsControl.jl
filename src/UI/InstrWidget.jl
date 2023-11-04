@option mutable struct QuantityControlOption
    uitype::String
    textcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
end

abstract type AbstractQuantityControl end

@option struct NullQuantityControl <: AbstractQuantityControl end

@option mutable struct SweepQuantityControl <: AbstractQuantityControl
    name::String = ""
    options::QuantityControlOption = QuantityControlOption()
end

@option mutable struct SetQuantityControl <: AbstractQuantityControl
    name::String = ""
    options::QuantityControlOption = QuantityControlOption()
end

@option mutable struct ReadQuantityControl <: AbstractQuantityControl
    name::String = ""
    options::QuantityControlOption = QuantityControlOption()
end

@option mutable struct InstrControl
    instrnm::String
    cols::Cint = 1
    qtctls::Vector{AbstractQuantityControl} = []
end

edit(::NullQuantityControl, _, _) = CImGui.Text("")

function edit(qt::SweepQuantityControl, instrnm, addr)
    CImGui.TextColored(options["textcolor"], qt.read)
    @c InputTextWithHintRSZ("##step", mlstr("step"), &qt.step)
    @c InputTextWithHintRSZ("##stop", mlstr("stop"), &qt.stop)
    @c CImGui.DragFloat("##delay", &qt.delay, 0.05, 0, 60, "%3f", CImGui.ImGuiSliderFlags_AlwaysClamp)
    if qt.issweeping
        CImGui.Button(mlstr(" Stop "), (-0.1, 0.0)) && (qt.issweeping = false)
    else
        CImGui.Button(mlstr(" Start "), (-0.1, 0.0)) && apply!(qt, instrnm, addr)
    end
end

function edit(qt::SetQuantityControl, instrnm, addr)
    if qt.options.uitype == "combo"
        presentv = qt.optkeys[qt.optedidx]
        if @c ComBoS(qt.alias, &presentv, qt.optkeys)
            qt.optedidx = findfirst(==(presentv), qt.optkeys)
            qt.set = qt.optvalues[qt.optedidx]
            apply!(qt, instrnm, addr)
        end
    elseif qt.options.uitype == "toggle"
        ison = qt.read == qt.optvalues[1]
        if @c ToggleButton(ison ? qt.optkeys[1] : qt.optkeys[2], &ison)
            qt.optedidx = ison ? 1 : 2
            qt.set = qt.optvalues[qt.optedidx]
            apply!(qt, instrnm, addr)
        end
    end
end

function edit(qt::ReadQuantityControl, _, _)
    CImGui.TextColored(qt.options.textcolor, qt.read)
end

function edit(insctl::InstrControl, addr)
    CImGui.Columns(insctl.cols)
    for qt in insctl.qtctls
        edit(qt, insctl.instrnm, addr)
        CImGui.NextColumn()
    end
end

function modify(qt::AbstractQuantityControl)
    CImGui.Button(qt.name)
    if CImGui.BeginPopupContextItem()
        CImGui.EndPopup()
    end
end

mutable struct InstrControlViewer
    instrnm::String
    addr::String
    p_open::Bool
    insctl::InstrControl
end

function ShowInstrWidget(icv::InstrControlViewer)
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
    ins, addr = icv.instrnm, icv.addr
    if @c CImGui.Begin(stcstr(INSCONF[ins].conf.icon, "  ", ins, " --- ", addr), &icv.p_open)
        edit(icv.insctl, addr)
    end
    CImGui.End()
end