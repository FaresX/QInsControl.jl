# QInsControl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://FaresX.github.io/QInsControl.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://FaresX.github.io/QInsControl.jl/dev/)
[![Build Status](https://github.com/FaresX/QInsControl.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/FaresX/QInsControl.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/FaresX/QInsControl.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/FaresX/QInsControl.jl)

QInsControl is designed for controling instruments and data aquiring, which is based on the nivisa and provides a 
user-friendly GUI and a flexible script written mannar to keep both the convenience and universality.

## install
```
julia> ]
(@v1.9) pkg> add ImPlot#main
(@v1.9) pkg> add https://github.com/FaresX/QInsControl.jl.git
```

## usage
```julia
using QInsControl
QInsControl.start()
```

## example
A simple project file [demo.daq](example) is in the example folder, which may give some ideas to write your own scripts.
One can load it as follows
![image](example/loadproject.gif)

## <font color=#FF0000>**Note**</font>
At present, the GUI may get crashed thanks to some bugs that does not interrupt the running DAQ program. When encountered, 
one could run
```julia
QInsControl.UI(true)
```
to restart the interface and give feedback on github Issues.