using QInsControl
using Documenter

DocMeta.setdocmeta!(QInsControl, :DocTestSetup, :(using QInsControl); recursive=true)

makedocs(;
    modules=[QInsControl],
    authors="Faresx <fyzxst@sina.com> and contributors",
    repo="https://github.com/Faresx/QInsControl.jl/blob/{commit}{path}#{line}",
    sitename="QInsControl.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Faresx.github.io/QInsControl.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Faresx/QInsControl.jl",
    devbranch="master",
)
