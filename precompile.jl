using Distributed
nprocs() == 1 && addprocs(1)
@everywhere using Pkg
@everywhere Pkg.activate(Base.@__DIR__)
@everywhere using QInsControl
julia_main()