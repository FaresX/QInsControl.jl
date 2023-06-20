module QInsControlCore
    using Instruments
    using Sockets
    using UUIDs

    export Controller, Processor
    export login!, logout!, start!, stop!, reconnect!, find_resources, slow!, fast!
    export instrument, connect!, disconnect!, write, read, query

    include("Instruments.jl")
    include("DataStream.jl")
end # module QInsControlCore
