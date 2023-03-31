using Logging
using Dates
using Distributed
using TOML

logio = IOBuffer()
global_logger(SimpleLogger(logio))

function update_log()
    date = today()
    logdir = joinpath(conf.Logs.dir, string(year(date)), string(year(date), "-", month(date)))
    isdir(logdir) || mkpath(logdir)
    logfile = joinpath(logdir, string(date, ".log"))
    if myid() == 1
        flush(logio)
        msg = String(take!(logio))
        isempty(msg) || open(file -> write(file, msg), logfile, "a+")
    else
        flush(logio)
        msg = String(take!(logio))
        if !isempty(msg)
            open(logfile, "a+") do file
                msgsp = split(msg, '\n')
                for (i, s) in enumerate(msgsp)
                    isempty(rstrip(s)) || (msgsp[i] = string("from worker $(myid()): ", msgsp[i], '\n'))
                end
                write(file, string(msgsp...))
            end
        end
    end
end

errormonitor(@async while true
    sleep(1)
    update_log()
end)