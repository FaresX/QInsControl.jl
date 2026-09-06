@kwdef mutable struct QICClient
    socket::TCPSocket = TCPSocket()
    addr::IPv4 = ip"127.0.0.1"
    port::Int = 0
    controllers::Dict{String,Controller} = Dict()
    buffer::Vector{Tuple{DateTime,String,String,String}} = []
    connected::Bool = false
end

@kwdef mutable struct QICServer
    server::Sockets.TCPServer = Sockets.TCPServer()
    port::Int = 6060
    clients::Vector{QICClient} = []
    termchar::Char = '\n'
    maxclients::Int = 36
    buflen::Int = 64
    running::Bool = false
    fast::Bool = false
    newmsg::Bool = false
end

function init!(server::QICServer)
    server.running && close(server.server)
    server.port = 6060
    server.running = false
    server.fast = false
    server.newmsg = false
    for client in server.clients
        isopen(client.socket) && close(client.socket)
    end
    empty!(server.clients)
end

function run!(server::QICServer; buflen=4, attrlist=Dict())
    @spawn_record "QICServer" try
        server.running = true
        server.server = listen(server.port)
        while server.running
            if length(server.clients) < server.maxclients
                socket = accept(server.server)
                ip, port = getpeername(socket)
                push!(
                    server.clients,
                    QICClient(socket=socket, addr=ip, port=port, connected=true)
                )
                @async_record "QICClient $ip:$port" handle_client(server, server.clients[end]; buflen, attrlist)
            else
                sleep(1)
            end
            server.fast ? yield() : sleep(0.001)
        end
    catch e
        @error "[$(now())]\nServer error" exception = e
        showbacktrace()
    finally
        close(server.server)
        server.running = false
    end
end

function handle_client(server::QICServer, client::QICClient; buflen=4, attrlist=Dict())
    try
        while server.running
            msg = readuntil(client.socket, server.termchar)
            msg == "" && (client.connected = false)
            client.connected || break
            process_message(server, client, msg; buflen, attrlist)
            server.fast ? yield() : sleep(0.001)
        end
    catch e
        @error "[$(now())]\nClient error" exception = e
        showbacktrace()
    finally
        client.connected = false
        for ct in values(client.controllers)
            logout!(CPU, ct)
        end
        close(client.socket)
        dellist = []
        for (i, client) in enumerate(server.clients)
            client.connected || push!(dellist, i)
        end
        deleteat!(server.clients, dellist)
    end
end

function process_message(server::QICServer, client::QICClient, msg::String; buflen=4, attrlist=Dict())
    try
        if occursin(":Q:", msg)
            strs = split(msg, ":Q:")
            length(strs) == 3 || (@warn "Invalid message format!"; return)
            addr, cmd, action = strs
            push!(client.buffer, (now(), addr, cmd, action))
            length(client.buffer) > server.buflen && popfirst!(client.buffer)
            server.newmsg = true
        else
            push!(client.buffer, (now(), "", msg, ""))
            length(client.buffer) > server.buflen && popfirst!(client.buffer)
            server.newmsg = true
            @warn "Invalid message format!"; return
        end
        if !haskey(client.controllers, addr)
            client.controllers[addr] = Controller("", addr; buflen=buflen)
        end
        ct = client.controllers[addr]
        login!(CPU, ct; attrlist)
        attr = getattr(String(addr), attrlist)
        if action == "R"
            write(client.socket, string(ct(read, CPU, Val(:read); timeout=attr.timeoutr), server.termchar))
        elseif action == "W"
            ct(write, CPU, String(cmd), Val(:write); timeout=attr.timeoutw)
        elseif action == "Q"
            str = ct(query, CPU, String(cmd), Val(:query); timeout=attr.timeoutr)
            write(client.socket, string(str, server.termchar))
        end
    catch e
        @error "[$(now())]\nError processing message)" exception = e
        showbacktrace()
    end
end

start!(server::QICServer; buflen=4, attrlist=Dict()) = (init!(server); run!(server; buflen, attrlist))

function stop!(server::QICServer)
    server.running && (server.running = false; close(server.server))
    for client in server.clients
        for ct in values(client.controllers)
            logout!(CPU, ct)
        end
        isopen(client.socket) && close(client.socket)
    end
    empty!(server.clients)
end