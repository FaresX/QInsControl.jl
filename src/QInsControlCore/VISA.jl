import Instruments: libvisa, check_status, check_connected
import Instruments: ViStatus, ViUInt32, ViPUInt32, ViSession, ViBuf, VI_NULL, ViEventType, ViUInt16, ViEventFilter
import Instruments: VI_EVENT_IO_COMPLETION, ViPEvent, VI_QUEUE

ViPJobId = Ref{Cuint}
ViPEventType = Ref{ViEventType}

function viEnableEvent(vi, eventtype, mechanism, context=VI_NULL)
    check_status(
        ccall(
            (:viEnableEvent, libvisa), ViStatus,
            (ViSession, ViEventType, ViUInt16, ViEventFilter), vi, eventtype, mechanism, context
        )
    )
end

function viDisableEvent(vi, eventtype, mechanism, context=VI_NULL)
    check_status(
        ccall(
            (:viDisableEvent, libvisa), ViStatus,
            (ViSession, ViEventType, ViUInt16, ViEventFilter), vi, eventtype, mechanism, context
        )
    )
end

function viWaitOnEvent(vi, ineventtype, timeout, outeventtype=VI_NULL, outcontext=VI_NULL)
    check_status(
        ccall(
            (:viWaitOnEvent, libvisa), ViStatus,
            (ViSession, ViEventType, ViUInt32, ViPEventType, ViPEvent), vi, ineventtype, timeout, outeventtype, outcontext
        )
    )
end

function viWriteAsync(vi, buf, count=length(buf), jobid=VI_NULL)
    check_status(
        ccall(
            (:viWriteAsync, libvisa), ViStatus,
            (ViSession, ViBuf, ViUInt32, ViPJobId), vi, pointer(buf), count, jobid
        )
    )
end

function viReadAsync(vi, buf, count=length(buf), jobid=VI_NULL)
    check_status(
        ccall(
            (:viReadAsync, libvisa), ViStatus,
            (ViSession, ViBuf, ViUInt32, ViPJobId), vi, pointer(buf), count, jobid
        )
    )
end

function writeasync(instr::GenericInstrument, msg::AbstractString; timeout=6)
    check_connected(instr)
    viEnableEvent(instr.handle, VI_EVENT_IO_COMPLETION, VI_QUEUE)
    viWriteAsync(instr.handle, msg)
    viWaitOnEvent(instr.handle, VI_EVENT_IO_COMPLETION, timeout*1E3)
    viDisableEvent(instr.handle, VI_EVENT_IO_COMPLETION, VI_QUEUE)
end
function readasync(instr::GenericInstrument; buflen=1024, timeout=6)
    check_connected(instr)
    buf = zeros(UInt8, buflen)
    viEnableEvent(instr.handle, VI_EVENT_IO_COMPLETION, VI_QUEUE)
    viReadAsync(instr.handle, buf)
    viWaitOnEvent(instr.handle, VI_EVENT_IO_COMPLETION, timeout*1E3)
    viDisableEvent(instr.handle, VI_EVENT_IO_COMPLETION, VI_QUEUE)
    rstrip(unsafe_string(pointer(buf)), ['\r', '\n'])
end
function queryasync(instr::GenericInstrument, msg::AbstractString; buflen=1024, delay=0, timeout=6)
    check_connected(instr)
    viEnableEvent(instr.handle, VI_EVENT_IO_COMPLETION, VI_QUEUE)
    viWriteAsync(instr.handle, msg)
    viWaitOnEvent(instr.handle, VI_EVENT_IO_COMPLETION, timeout*1E3)
    delay < 0.001 || sleep(delay)
    buf = zeros(UInt8, buflen)
    viReadAsync(instr.handle, buf)
    viWaitOnEvent(instr.handle, VI_EVENT_IO_COMPLETION, timeout*1E3)
    viDisableEvent(instr.handle, VI_EVENT_IO_COMPLETION, VI_QUEUE)
    rstrip(unsafe_string(pointer(buf)), ['\r', '\n'])
end

function find_visa()
    BinDeps.@setup
    visa = library_dependency("visa", aliases=["visa64", "VISA", "/Library/Frameworks/VISA.framework/VISA", "librsvisa"])
    # librsvisa is the specific Rohde & Schwarz VISA library name
    visa_path_found = BinDeps._find_library(visa)
    return isempty(visa_path_found) ? "" : visa_path_found[1][end]
end