# using Distributed
# nprocs() == 1 && addprocs(1)
# @everywhere using Pkg
ENV["QInsControlAssets"] = joinpath(Base.@__DIR__, "Assets")
using Pkg
Pkg.activate(Base.@__DIR__)
using QInsControl
# julia_main()
QInsControl.start()