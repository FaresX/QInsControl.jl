mutable struct SelfAdaptedSweep
    start::Real
    minstep::Real
    maxstep::Real
    stop::Real
    x::Vector{Real}
    y::Vector{Real}
    k::Vector{Real}
    dk::Real
    km::Real
    dkm::Real
    ksigma::Real
    dksigma::Real
    count::Int
    nextstep::Real
    stepm::Real
    nextx::Real
    isgoback::Bool
    isstop::Bool
    selectbyk::Function
    selectbydk::Function
end
SelfAdaptedSweep(start, minstep, maxstep, stop) = SelfAdaptedSweep(
    start, sign(stop - start) * abs(minstep), sign(stop - start) * abs(maxstep), stop,
    [start, start + minstep, start + 2minstep], [0, 0, 0], [0, 0], 0, 0, 0, 0, 0, 1,
    minstep, sign(stop - start) * abs(minstep), start, false, false,
    (k, km, ksigma) -> exp(-abs2(abs(k) / (km + 3ksigma))), (dk, dkm, dksigma) -> exp(-abs2(abs(dk) / (dkm + 3dksigma)))
)

function (sas::SelfAdaptedSweep)(y; goback=false, gobackc=6)
    if sas.count == 1
        sas.y[1] = y
        sas.count += 1
        sas.nextx = sas.x[2]
    elseif sas.count == 2
        sas.y[2] = y
        sas.k[1] = (sas.y[2] - sas.y[1]) / (sas.x[2] - sas.x[1])
        sas.km = abs(sas.k[1])
        sas.count += 1
        sas.nextx = sas.x[3]
    elseif sas.count == 3
        sas.y[3] = y
        sas.k[1] = (sas.y[2] - sas.y[1]) / (sas.x[2] - sas.x[1])
        sas.k[2] = (sas.y[3] - sas.y[2]) / (sas.x[3] - sas.x[2])
        dx1 = sas.x[2] - sas.x[1]
        dx2 = sas.x[3] - sas.x[2]
        sas.dk = (sas.k[2] - sas.k[1]) * min(dx1, dx2)
        sas.km = (sas.km + abs(sas.k[2])) / 2
        sas.dkm = abs(sas.dk)
        sas.ksigma = √(sum(abs2.(abs.(sas.k) .- sas.km)))
        sas.count += 1
        sas.nextx = sas.x[3] + sas.nextstep
    else
        xb = copy(sas.x)
        yb = copy(sas.y)
        kb = copy(sas.k)
        sas.x[1] = sas.x[2]
        sas.x[2] = sas.x[3]
        sas.x[3] = sas.nextx
        sas.y[1] = sas.y[2]
        sas.y[2] = sas.y[3]
        sas.y[3] = y
        sas.k[1] = sas.k[2]
        sas.k[2] = (sas.y[3] - sas.y[2]) / (sas.x[3] - sas.x[2])
        dx1 = sas.x[2] - sas.x[1]
        dx2 = sas.x[3] - sas.x[2]
        sas.dk = (sas.k[2] - sas.k[1]) * min(dx1, dx2)
        if goback && abs(sas.dk) / (sas.dkm + 5sas.dksigma) > gobackc && sas.nextstep > sas.minstep
            sas.x .= xb
            sas.y .= yb
            sas.k .= kb
            sas.nextstep = sas.minstep
            sas.nextx = sas.x[3] + sas.nextstep
            sas.nextx > sas.stop && (sas.nextx = sas.stop)
            sas.isgoback = true
            sas.isstop = sas.x[3] == sas.stop
        else
            rk = sas.selectbyk(sas.k[2], sas.km, sas.ksigma)
            rdk = sas.selectbydk(sas.dk, sas.dkm, sas.dksigma)
            ktom = min(abs(sas.k[2]), 5sas.km)
            dktom = min(abs(sas.dk), 5sas.dkm)
            sas.km = ((sas.count - 2) * sas.km + ktom) / (sas.count - 1)
            sas.dkm = ((sas.count - 3) * sas.dkm + dktom) / (sas.count - 2)
            sas.ksigma = ((sas.count - 2) * abs2(sas.ksigma) + abs2(ktom - sas.km)) / (sas.count - 1)
            sas.dksigma = ((sas.count - 3) * abs2(sas.dksigma) + abs2(dktom - sas.dkm)) / (sas.count - 2)
            sas.count += 1
            sas.nextstep = rk * rdk * (sas.maxstep - sas.minstep) + sas.minstep
            sas.stepm = ((sas.count - 1) * sas.stepm + sas.nextstep) / sas.count
            sas.nextx = sas.x[3] + sas.nextstep
            sas.nextx > sas.stop && (sas.nextx = sas.stop)
            sas.isgoback = false
            sas.isstop = sas.x[3] == sas.stop
        end
    end
    return nothing
end

macro sas(sas, block)
    @gensym pgid tn
    ex = quote
        let
            $pgid = uuid4()
            $tn = time()
            while !$sas.isstop
                $(block.args...)
                put!(progress_lc, ($pgid, $sas.count - 1, ceil(Int, ($sas.stop - $sas.start) / $sas.stepm), time() - $tn))
            end
        end
    end
    esc(ex)
end

macro sas(sasnm, start, minstep, maxstep, stop, block)
    @gensym pgid tn
    ex = quote
        let
            $sasnm = SelfAdaptedSweep($start, $minstep, $maxstep, $stop)
            $pgid = uuid4()
            $tn = time()
            while !$sasnm.isstop
                $(block.args...)
                put!(progress_lc, ($pgid, $sasnm.count - 1, ceil(Int, ($sasnm.stop - $sasnm.start) / $sasnm.stepm), time() - $tn))
            end
        end
    end
    esc(ex)
end