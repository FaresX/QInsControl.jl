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
    try
        occursin("::QIC::", msg) || (@warn "Invalid message format!"; return)
        addr, cmd, action = split(msg, "::QIC::")
        fetchdata = timed_remotecall_fetch(workers()[1], addr, String(cmd), action; timeout=CONF.DAQ.cttimeout) do addr, cmd, action
            ct = Controller("", addr; buflen=CONF.DAQ.ctbuflen, timeout=CONF.DAQ.cttimeout)
            try
                login!(CPU, ct; attr=getattr(addr))
                return if action == "QICREAD"
                    ct(read, CPU, Val(:read))
                elseif action == "QICWRITE"
                    ct(write, CPU, cmd, Val(:write))
                elseif action == "QICQUERY"
                    ct(query, CPU, cmd, Val(:query))
                end
            catch e
                @error "[$(now())]\n$(mlstr("instrument communication failed!!!"))" instrument = addr exception = e
                showbacktrace()
            finally
                logout!(CPU, ct)
            end
        end
        action in ["QICREAD", "QICQUERY"] && !isnothing(fetchdata) && write(socket, string(fetchdata, termchar))
    catch e
        @error "Error processing message" exception = e
        showbacktrace()
    end
end

start!(server::QICServer) = (init!(server); run!(server))

stop!(server::QICServer) = server.running && (server.running = false; close(server.server))

const QICSERVER = QICServer()

function ServerMonitor()
    @c(CImGui.DragInt(
        mlstr("port"),
        &CONF.Server.port,
        1.0, 1, 65535, "%d",
        CImGui.ImGuiSliderFlags_AlwaysClamp
    )) && (QICSERVER.port = CONF.Server.port)
    @c(CImGui.DragInt(
        mlstr("buffer size"),
        &CONF.Server.buflen,
        1.0, 4, 4096, "%d",
        CImGui.ImGuiSliderFlags_AlwaysClamp
    )) && (QICSERVER.buflen = CONF.Server.buflen)
    if ToggleButton(mlstr(QICSERVER.running ? "Running" : "Stopped"), Ref(QICSERVER.running))
        QICSERVER.running ? stop!(QICSERVER) : start!(QICSERVER)
    end
    CImGui.SameLine()
    @c CImGui.Checkbox(mlstr(QICSERVER.fast ? "Fast Mode" : "Slow Mode"), &QICSERVER.fast)
    CImGui.BeginChild("Clients Table", (Cfloat(0), 6CImGui.GetFrameHeight()))
    if CImGui.BeginTable(
        "Clients Table", 2,
        CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
    )
        CImGui.TableSetupScrollFreeze(0, 1)
        CImGui.TableSetupColumn(mlstr("IP Address"), CImGui.ImGuiTableColumnFlags_WidthFixed, 8CImGui.GetFontSize())
        CImGui.TableSetupColumn(mlstr("Port"), CImGui.ImGuiTableColumnFlags_WidthStretch)
        CImGui.TableHeadersRow()

        @lock QICSERVER.clients for (ip, port) in QICSERVER.clients[]
            CImGui.TableNextRow()

            CImGui.TableSetColumnIndex(0)
            CImGui.Text(string(ip))

            CImGui.TableSetColumnIndex(1)
            CImGui.Text(string(port))
        end
        CImGui.EndTable()
    end
    CImGui.EndChild()
    if CImGui.BeginTable(
        "Server Buffer Table", 2,
        CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_Resizable | CImGui.ImGuiTableFlags_ScrollY
    )
        CImGui.TableSetupScrollFreeze(0, 1)
        CImGui.TableSetupColumn(mlstr("DateTime"), CImGui.ImGuiTableColumnFlags_WidthFixed, 6CImGui.GetFontSize())
        CImGui.TableSetupColumn(mlstr("Message"), CImGui.ImGuiTableColumnFlags_WidthStretch)
        CImGui.TableHeadersRow()

        @lock QICSERVER.buffer for (date, _, _, msg) in QICSERVER.buffer[]
            CImGui.TableNextRow()

            CImGui.TableSetColumnIndex(0)
            CImGui.Text(string(Time(date)))

            CImGui.TableSetColumnIndex(1)
            CImGui.Text(msg)
        end
        QICSERVER.newmsg && (CImGui.SetScrollHereY(1); QICSERVER.newmsg = false)
        CImGui.EndTable()
    end
end