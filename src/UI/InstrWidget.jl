@option mutable struct QuantityWidgetOption
    uitype::String
    textcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
end

abstract type AbstractQuantityWidget end

@option struct NullQuantityWidget <: AbstractQuantityWidget end

@option mutable struct SweepQuantityWidget <: AbstractQuantityWidget
    name::String = ""
    alias::String = ""
    options::QuantityWidgetOption = QuantityWidgetOption("button")
end

@option mutable struct SetQuantityWidget <: AbstractQuantityWidget
    name::String = ""
    alias::String = ""
    options::QuantityWidgetOption = QuantityWidgetOption("combo")
end

@option mutable struct ReadQuantityWidget <: AbstractQuantityWidget
    name::String = ""
    alias::String = ""
    options::QuantityWidgetOption = QuantityWidgetOption("text")
end

@option mutable struct InstrWidget
    instrnm::String = "VirtualInstr"
    cols::Cint = 1
    qtws::Vector{AbstractQuantityWidget} = []
end

qtwtoqt(qtw::AbstractQuantityWidget, instrnm, addr) = INSTRBUFFERVIEWERS[instrnm][addr].insbuf.quantities[qtw.name]

edit(::NullQuantityWidget, _, _) = CImGui.Text("")

function edit(qtw::SweepQuantityWidget, instrnm, addr)
    qt = qtwtoqt(qtw, instrnm, addr)
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

function edit(qtw::SetQuantityWidget, instrnm, addr)
    qt = qtwtoqt(qtw, instrnm, addr)
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

function edit(qtw::ReadQuantityWidget, _, _)
    qt = qtwtoqt(qtw, instrnm, addr)
    CImGui.TextColored(qt.options.textcolor, qt.read)
end

function edit(insw::InstrWidget, addr)
    CImGui.Columns(insw.cols)
    for qtw in insw.qtws
        edit(qtw, insw.instrnm, addr)
        CImGui.NextColumn()
    end
end

function modify(qtw::SweepQuantityWidget)
    CImGui.Button(qtw.alias, (-1, 0))
    if CImGui.BeginPopupContextItem()
        CImGui.EndPopup()
    end
end

function modify(qtw::SetQuantityWidget)
    CImGui.Button(qtw.alias, (-1, 0))
    if CImGui.BeginPopupContextItem()
        CImGui.EndPopup()
    end
end

function modify(qtw::ReadQuantityWidget)
    CImGui.Button(qtw.alias, (-1, 0))
    if CImGui.BeginPopupContextItem()
        CImGui.EndPopup()
    end
end

function modify(insw::InstrWidget)
    CImGui.Columns(insw.cols)
    for (i, qtw) in enumerate(insw.qtws)
        modify(qtw)
        CImGui.NextColumn()
        CImGui.Indent()
        if CImGui.BeginDragDropSource(0)
            @c CImGui.SetDragDropPayload("Swap Widgets", &i, sizeof(Cint))
            CImGui.Text(qtw.alias)
            CImGui.EndDragDropSource()
        end
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Swap DAQTask")
            if payload != C_NULL && unsafe_load(payload).DataSize == sizeof(Cint)
                payload_i = unsafe_load(Ptr{Cint}(unsafe_load(payload).Data))
                if i != payload_i
                    insw.qtws[i] = insw.qtws[payload_i]
                    insw.qtws[payload_i] = qtw
                end
            end
            CImGui.EndDragDropTarget()
        end
        CImGui.Unindent()
    end
end

@kwdef mutable struct InstrWidgetViewer
    instrnm::String = "VirtualInstr"
    addr::String = "VirtualAddress"
    p_open::Bool = false
    ismodify::Bool = false
    insw::InstrWidget = InstrWidget()
end

function edit(iwv::InstrWidgetViewer)
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_Once)
    ins, addr = iwv.instrnm, iwv.addr
    if @c CImGui.Begin(stcstr(INSCONF[ins].conf.icon, "  ", ins, " --- ", addr), &iwv.p_open)
        iwv.ismodify ? modify(iwv.insw) : edit(iwv.insw, addr)
    end
    CImGui.End()
    if CImGui.BeginPopupContextWindow()
        @c CImGui.Checkbox(mlstr(iwv.ismodify ? "Edit" : "View"), &iwv.ismodify)
        CImGui.EndPopup()
    end
end