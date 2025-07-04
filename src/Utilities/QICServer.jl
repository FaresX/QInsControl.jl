@kwdef mutable struct QICServer
    server::Sockets.TCPServer = Sockets.TCPServer()
    port::Int = 6060
    clients::Base.Lockable{Vector{Tuple{IPAddr,UInt16}},ReentrantLock} = Base.Lockable(Tuple{IPAddr,UInt16}[])
    termchar::Char = '\n'
    buflen::Int = 1024
    buffer::Base.Lockable{Vector{Tuple{DateTime,IPv4,Int,String}},ReentrantLock} = Base.Lockable(Tuple{DateTime,IPv4,Int,String}[])
    running::Bool = false
    fast::Bool = false
    newmsg::Bool = false
end

function init!(server::QICServer)
    server.running && close(server.server)
    server.port = CONF.Server.port
    server.running = false
    server.fast = false
    server.newmsg = false
    @lock server.clients empty!(server.clients[])
    @lock server.buffer empty!(server.buffer[])
end

function run!(server::QICServer)
    Threads.@spawn try
        server.running = true
        server.server = listen(server.port)
        while server.running
            socket = accept(server.server)
            @lock server.clients push!(server.clients[], getpeername(socket))
            @async try
                while server.running
                    msg = readuntil(socket, server.termchar)
                    if msg == ""
                        @lock server.clients begin
                            idx = findfirst(==(getpeername(socket)), server.clients[])
                            deleteat!(server.clients[], idx)
                            close(socket)
                        end
                        break
                    end
                    if server.fast
                        yield()
                    else
                        ip, port = getpeername(socket)
                        @lock server.buffer begin
                            push!(server.buffer[], (now(), ip, port, msg))
                            length(server.buffer[]) > server.buflen && popfirst!(server.buffer[])
                        end
                        server.newmsg = true
                        sleep(0.001)
                    end
                    process_message(socket, msg; termchar=server.termchar)
                end
            catch e
                @error "comunication error" exception = e
                showbacktrace()
            finally
                close(socket)
            end
            server.fast ? yield() : sleep(0.001)
        end
    catch e
        @error "Server error" exception = e
        showbacktrace()
    finally
        close(server.server)
        server.running = false
    end
end

function process_message(socket, msg::String; termchar='\n')
    ct = Controller("", "")
    try
        occursin(":Q:", msg) || (@warn "Invalid message format!"; return)
        addr, cmd, action = split(msg, ":Q:")
        ct = Controller("", addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
        login!(CPU, ct; attr=getattr(addr))
        if action == "R"
            write(socket, string(ct(read, CPU, Val(:read)), termchar))
        elseif action == "W"
            ct(write, CPU, String(cmd), Val(:write))
        elseif action == "Q"
            write(socket, string(ct(query, CPU, String(cmd), Val(:query)), termchar))
        end
    catch e
        @error "Error processing message" exception = e
        showbacktrace()
    finally
        logout!(CPU, ct)
    end
end

start!(server::QICServer) = (init!(server); run!(server))

stop!(server::QICServer) = server.running && (server.running = false; close(server.server))

const QICSERVER = QICServer()