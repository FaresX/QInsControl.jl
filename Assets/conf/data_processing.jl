function intIbias(I, R)
    interp = LinearInterpolation(R, I)
    V = similar(I)
    for i in eachindex(I)
        V[i] = I[i] > 0 ? integral(interp, 0..I[i]) : -integral(interp, (I[i])..0)
    end
    V
end

function intIbiasmap(I, Rs)
    intV = similar(Rs)
    for i in 1:size(Rs, 2)
        intV[:,i] = intIbias(I, Rs[:,i])
    end
    intV
end

function normalization(z) 
    zn = copy(z)
    for j in 1:size(z, 2)
        all(ismissing, z[:,j]) && continue
        minj, maxj = extrema(skipmissing(z[:,j]))
        maxj == minj && continue
        for i in 1:size(z, 1)
            zn[i,j] = (z[i,j]-minj)/(maxj-minj)
        end
    end
    zn
end

function interpVs(Vs, Rs)
    minv, maxv = extrema(Vs)
    rangev = range(minv, maxv, length=size(Rs, 1))
    Rsn = similar(Rs, Union{Float64, Missing})
    for j in 1:size(Rs, 2)
        interp = LinearInterpolation(Rs[:,j], Vs[:,j])
        minvj, maxvj = extrema(Vs[:,j])
        for i in eachindex(rangev)
            if minvj <= rangev[i] <= maxvj
                Rsn[i,j] = interp(rangev[i])
            else
                Rsn[i,j] = missing
            end
        end
    end
    rangev, Rsn
end