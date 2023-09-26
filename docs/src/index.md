```@meta
CurrentModule = QInsControl
```

# QInsControl

QInsControl is designed for controling instruments and data acquiring, which is based on the NI VISA and provides a 
friendly GUI and a flexible script written mannar to keep both the convenience and universality.

## install
Before installation, make sure you have NI VISA installed!
```
julia> ]
(@v1.9) pkg> add https://github.com/FaresX/QInsControl.jl.git
```

## usage
```julia
using QInsControl
QInsControl.start()
```

