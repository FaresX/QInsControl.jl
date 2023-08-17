Base.convert(::Type{OrderedDict{String,T}}, vec::Vector{T}) where {T} = OrderedDict(string(i) => v for (i, v) in enumerate(vec))
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Vector{Node}) = OrderedDict(node.id => node for node in nodes)
Base.convert(::Type{OrderedDict{Cint,AbstractNode}}, nodes::Type{OrderedDict{Cint,Node}}) = OrderedDict{Cint,AbstractNode}(node.id => node for node in nodes)

# mutable struct InstrQuantity <: AbstractQuantity
#     # back end
#     enable::Bool
#     name::String
#     alias::String
#     step::String
#     stop::String
#     delay::Cfloat
#     set::String
#     optkeys::Vector{String}
#     optvalues::Vector{String}
#     optedidx::Cint
#     read::String
#     utype::String
#     uindex::Int
#     type::Symbol
#     help::String
#     isautorefresh::Bool
#     issweeping::Bool
#     # front end
#     show_edit::String
#     show_view::String
#     passfilter::Bool
# end

# InstrQuantity() = InstrQuantity(
#     true, "", "", "", "", Cfloat(0.1), "", [], [], 1, "", "", 1, :set, "", false, false,
#     "", "", true
# )
# InstrQuantity(name, qtcf::QuantityConf) = InstrQuantity(
#     qtcf.enable, name, qtcf.alias,
#     "", "", Cfloat(0.1),
#     "", qtcf.optkeys, qtcf.optvalues, 1,
#     "",
#     qtcf.U, 1,
#     Symbol(qtcf.type),
#     qtcf.help,
#     false,
#     false,
#     "", "", true
# )