@option mutable struct QuantityControlOption
    textcolor::Vector{Cfloat} = [1.000, 1.000, 1.000, 1.000]
end

@option mutable struct QuantityControl
    qtname::String = ""
    type::String = ""
    options::QuantityControlOption = QuantityControlOption()
end

@option mutable struct InstrControl
    qtctls::Vector{QuantityControl} = []
end

renderqt(qt::AbstractQuantity, instrnm, addr, type=:button) = renderqt(qt, instrnm, addr, Val(type))

function renderqt(
    qt::SweepQuantity, instrnm, addr, ::Val{:button};
    option=Dict()
)
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

function renderqt(
    qt::SetQuantity, instrnm, addr ::Val{:combo};
    option=Dict()
)
    presentv = qt.optkeys[qt.optedidx]
    if @c ComBoS(qt.alias, &presentv, qt.optkeys)
        qt.optedidx = findfirst(==(presentv), qt.optkeys)
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
    end
end

function renderqt(
    qt::SetQuantity, instrnm, addr ::Val{:togglebutton};
    option=Dict()
)
    ison = qt.read == qt.optvalues[1]
    if @c ToggleButton(ison ? qt.optkeys[1] : qt.optkeys[2], &ison)
        qt.optedidx = ison ? 1 : 2
        qt.set = qt.optvalues[qt.optedidx]
        apply!(qt, instrnm, addr)
    end
end

function renderqt(
    qt::ReadQuantity, ::Val{:text};
    option=Dict("textcolor" => CImGui.c_get!(IMGUISTYLE.Colors, CImGui.ImGuiCol_Text))
)
    CImGui.TextColored(option["textcolor"], qt.read)
end

function renderquantities(qts::Matrix{AbstractQuantity}, types::Matrix{Symbol}, options, instrnm, addr; editmode=false)
    isequalsize = size(qts) == size(types)
    if !isequalsize
        resizets = similar(types, size(qts)...)
        trow, tcol = size(types)
        @views resizets[1:trow,1:tcol] = types
    end
    CImGui.Columns(size(qts, 2))
    for (i, qt) in enumerate(qts)
        renderqt(qt, instrnm, addr, isequalsize ? types[i] : resizets[i])
        CImGui.NextColumn()
    end
end

function renderquantities(qts::Matrix{AbstractString}, types::Matrix{AbstractString}, options, instrnm, addr; editmode=false)
    toqts = (qt -> get!(INSCONF[instrnm].quantities, qt.name, "null")).(qts)
    totypes = Symbol.(types)
    renderquantities(toqts, totypes, options, instrnm, addr; editmode=editmode)
end

function ShowInstrWidget(
    p_open, qts::Matrix{AbstractQuantity}, types::Matrix{Symbol}, options, instrnm, addr, widgetnm="widget";
    editmode=false)
    if CImGui.Begin(widgetnm, p_open)
    end
    CImGui.End()
end