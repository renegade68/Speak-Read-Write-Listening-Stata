// Fixed preprocessing for already isolated clips, specified before scoring.
version 16.1
capture mata: mata drop spc_bounds()
mata:
real rowvector spc_bounds(real colvector x)
{
    real matrix E
    real colvector active
    real scalar a,b,threshold
    if (rows(x)<400) return(J(1,0,.))
    E=slk_envelope(x,16000)
    threshold=max((.15*max(E[,2]),.0003))
    active=selectindex(E[,2]:>=threshold)
    if (!rows(active)) return(J(1,0,.))
    a=max((1,E[active[1],3]-800))
    b=min((rows(x),E[active[rows(active)],4]+800))
    if (b-a+1<400) return(J(1,0,.))
    return((a,b))
}
end
