# using Distributed
# nprocs() == 1 && addprocs(1)
# @everywhere using Pkg
using Pkg
Pkg.activate(Base.@__DIR__)
using QInsControl
# julia_main()
QInsControl.start()