using QInsControl
using Documenter

DocMeta.setdocmeta!(QInsControl, :DocTestSetup, :(using QInsControl); recursive=true)

makedocs(;
    modules=[QInsControl],
    authors="FaresX <fyzxst@sina.com> and contributors",
    repo="https://github.com/FaresX/QInsControl.jl/blob/{commit}{path}#{line}",
    sitename="QInsControl.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://FaresX.github.io/QInsControl.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Workflow" => "Workflow.md",
        "New Instrument" => "New Instrument.md",
        "Tips" => "Tips.md",
        "QInsControlCore" => "QInsControlCore.md"
    ],
)

deploydocs(;
    repo="github.com/FaresX/QInsControl.jl",
    devbranch="master",
)
