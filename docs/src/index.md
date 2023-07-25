```@meta
CurrentModule = QInsControl
```

# QInsControl

QInsControl is designed for controling instruments and data aquiring, which is based on the nivisa and provides a 
user-friendly GUI and a flexible script written mannar to keep both the convenience and universality.

## install
```
julia> ]
julia> add ImPlot#main
julia> add https://github.com/FaresX/QInsControl.jl.git
```

## usage
```julia
using QInsControl
QInsControl.start()
```

