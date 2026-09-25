const init_funcs = []
include("Win32Chrome.jl")
include("CustomWidgets/CustomWidgets.jl")
include("Instruments/Instruments.jl")
include("Windows/Windows.jl")
include("Utilities/Utilities.jl")
include("Renderer.jl")

function initialize_frontend!()
    for init_func in init_funcs
        init_func()
    end

    empty!(DATABUF)
    empty!(DATABUFPARSED)
    empty!(PROGRESSLIST)
    empty!(STYLES)
    empty!(INSTRCONF)
    empty!(INSWCONF)
    empty!(INSTRBUFFERVIEWERS)
    empty!(IMAGES)
    empty!(FIGURES)
    empty!(WINVIEWPORTS)
    empty!(CLOSEPENDING)
    empty!(WINTICONS)
    empty!(WINBORDERLESS_AUTO)
    empty!(WINBORDERLESS_SET)
    resetshadowtexture!()

    loadconf()
end
