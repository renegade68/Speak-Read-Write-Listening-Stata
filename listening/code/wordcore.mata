// Experimental isolated-word features and DTW; no external recognition engine.
// Input: mono 16 kHz samples in [-1,1]. No automatic command execution.
version 16.1
capture mata: mata drop slk_*()
mata:
mata set matastrict on

void slk_require(real scalar ok, string scalar message)
{
    if (!ok) _error(3498,"wordcore: "+message)
}

// Frame start (seconds), RMS, one-based first and last sample.
real matrix slk_envelope(real colvector x, real scalar fs)
{
    real scalar win, hop, n, i, p
    real matrix E
    slk_require(fs==16000 & rows(x)>=320 & !hasmissing(x),"expected finite mono 16 kHz audio, >=20 ms")
    win=320; hop=160; n=floor((rows(x)-win)/hop)+1
    E=J(n,4,.)
    for (i=1;i<=n;i++) {
        p=1+(i-1)*hop
        E[i,]=((p-1)/fs,sqrt(mean(x[p..p+win-1]:^2)),p,p+win-1)
    }
    return(E)
}

// Energy detector, NOT a speech model. Returns sample bounds and active bounds.
// 20 ms frames, 10 ms hop; adaptive noise estimate; 200 ms gap merge.
real matrix slk_segments(real colvector x, real scalar fs, real scalar pad)
{
    real matrix E, groups, S
    real colvector sorted, active
    real scalar noise, high, low, i, first, last, strong, a, b, j
    E=slk_envelope(x,fs)
    sorted=sort(E[,2],1)
    noise=sorted[max((1,ceil(.20*rows(sorted))))]
    high=max((3.5*noise, .15*max(E[,2]), .0003))
    low=max((2*noise,.00015))
    // Frames above low threshold form candidate groups, anchored by high frames.
    active=selectindex(E[,2]:>=low)
    groups=J(0,2,.)
    if (!rows(active)) return(J(0,4,.))
    first=last=active[1]
    for (i=2;i<=rows(active);i++) {
        if (active[i]-last>21) {
            groups=groups\(first,last)
            first=active[i]
        }
        last=active[i]
    }
    groups=groups\(first,last)
    S=J(0,4,.)
    for (j=1;j<=rows(groups);j++) {
        a=groups[j,1]; b=groups[j,2]
        strong=sum(E[a..b,2]:>=high)
        if (strong>=5 & E[b,4]-E[a,3]+1>=.12*fs) {
            S=S\(max((1,E[a,3]-round(pad*fs))), min((rows(x),E[b,4]+round(pad*fs))), E[a,3],E[b,4])
        }
    }
    // Padding may approach adjacent candidates; split padding at their midpoint.
    for (j=2;j<=rows(S);j++) if (S[j,1]<=S[j-1,2]) {
        i=floor((S[j-1,4]+S[j,3])/2)
        S[j-1,2]=i; S[j,1]=i+1
    }
    return(S)
}

// 26 triangular mel filters, 80..7600 Hz, each normalized to unit area (bin sum).
real matrix slk_melbank()
{
    real colvector hz, edges
    real matrix B
    real scalar j, i, m0, m1
    m0=2595*log10(1+80/700); m1=2595*log10(1+7600/700)
    edges=700:*(10:^((m0:+(0::27):*(m1-m0)/27):/2595):-1)
    hz=(0::256):*16000/512
    B=J(257,26,0)
    for (j=1;j<=26;j++) {
        for (i=1;i<=257;i++) {
            if (hz[i]>=edges[j] & hz[i]<=edges[j+1])
                B[i,j]=(hz[i]-edges[j])/(edges[j+1]-edges[j])
            else if (hz[i]>edges[j+1] & hz[i]<=edges[j+2])
                B[i,j]=(edges[j+2]-hz[i])/(edges[j+2]-edges[j+1])
        }
        B[,j]=B[,j]:/sum(B[,j])
    }
    return(B)
}

// MFCC c1..c13 (c0/energy omitted). 25 ms Hamming, 10 ms hop, 512-point FFT.
// No corpus-dependent normalization; nothing is fitted on evaluation recordings.
real matrix slk_features(real colvector x, real scalar fs)
{
    real scalar n, i, k, j, p, peak
    real colvector y, pre, w, frame, power
    real rowvector energy
    real matrix B, C, F
    slk_require(fs==16000 & rows(x)>=400 & !hasmissing(x),"features require >=25 ms at 16 kHz")
    y=x:-mean(x); peak=max(abs(y))
    slk_require(peak>1e-8,"no signal for feature extraction")
    y=y:/peak
    pre=y; pre[2..rows(y)]=y[2..rows(y)]:-.97:*y[1..rows(y)-1]
    w=.54:-.46:*cos(2*pi()*(0::399):/399)
    B=slk_melbank(); C=J(26,13,.)
    for (j=1;j<=26;j++) for (k=1;k<=13;k++)
        C[j,k]=sqrt(2/26)*cos(pi()*(j-.5)*k/26)
    n=floor((rows(pre)-400)/160)+1; F=J(n,13,.)
    for (i=1;i<=n;i++) {
        p=1+(i-1)*160
        frame=(pre[p..p+399]:*w)\J(112,1,0)
        power=abs(fft(frame)):^2
        energy=power[1..257]'*B
        F[i,]=log(energy:+1e-12)*C
    }
    return(F)
}

// Symmetric weighted DTW. Diagonal has weight 2; horizontal/vertical weight 1.
// Sum of path weights is n+m, hence the normalization is path-independent.
// Band is |i/n-j/m| <= radius (minimum of one frame for very short inputs).
real scalar slk_dtw(real matrix A, real matrix B, real scalar radius)
{
    real scalar n, m, i, j, cost, r
    real matrix D
    slk_require(rows(A)>0 & rows(B)>0 & cols(A)==cols(B) & cols(A)>0,"invalid feature dimensions")
    slk_require(!hasmissing(A) & !hasmissing(B) & radius>=0 & radius<=1,"invalid DTW inputs")
    n=rows(A); m=rows(B); r=max((radius,1/n,1/m))
    D=J(n+1,m+1,.); D[1,1]=0
    for (i=1;i<=n;i++) for (j=1;j<=m;j++) {
        if (abs(i/n-j/m)<=r+1e-12) {
            cost=sum((A[i,]-B[j,]):^2)/cols(A)
            D[i+1,j+1]=min((D[i,j]+2*cost,D[i,j+1]+cost,D[i+1,j]+cost))
        }
    }
    return(D[n+1,m+1]/(n+m))
}

// Index rows: first feature row, last feature row, class ID (1..K).
// Result: class ID, minimum distance over its registered templates.
real matrix slk_scores(real matrix query, real matrix bank, real matrix index)
{
    real matrix scores
    real scalar i, k, K, a, b, d
    slk_require(rows(index)>0 & cols(index)==3 & !hasmissing(index),"invalid template index")
    slk_require(all(index:==floor(index)) & min(index[,1])>=1 & max(index[,2])<=rows(bank) & all(index[,1]:<=index[,2]) & min(index[,3])>=1,"template index out of range")
    K=max(index[,3]); scores=((1::K),J(K,1,.))
    for (i=1;i<=rows(index);i++) {
        a=index[i,1]; b=index[i,2]; k=index[i,3]
        d=slk_dtw(query,bank[a..b,],.25)
        if (d<scores[k,2]) scores[k,2]=d
    }
    slk_require(!hasmissing(scores),"each class must have a finite template match")
    return(scores)
}

// cutoff and gap must be calibrated elsewhere. Negative means 'not calibrated'.
// Return nearest class, best distance, second distance, accepted (0/1/missing).
real rowvector slk_decide(real matrix scores, real scalar cutoff, real scalar gap)
{
    real matrix ordered
    real scalar accepted
    slk_require(rows(scores)>=2 & cols(scores)==2 & !hasmissing(scores) & min(scores[,2])>=0,"invalid class scores")
    slk_require(cutoff<. & gap<.,"missing decision threshold")
    ordered=sort(scores,(2,1)); accepted=.
    if (cutoff>=0 & gap>=0) accepted=(ordered[1,2]<=cutoff & ordered[2,2]-ordered[1,2]>gap)
    return((ordered[1,1],ordered[1,2],ordered[2,2],accepted))
}

real rowvector slk_lebytes(real scalar n, real scalar width)
{
    real rowvector b
    real scalar i
    b=J(1,width,0)
    for (i=1;i<=width;i++) {
        b[i]=mod(n,256)
        n=floor(n/256)
    }
    return(b)
}

// Writes a derived PCM16 WAV. Caller controls the output path; replace is explicit.
void slk_writewav(string scalar path, real colvector pcm, real scalar replace)
{
    real scalar fh, n
    real colvector u
    real rowvector bytes
    slk_require(rows(pcm)>0 & !hasmissing(pcm) & min(pcm)>=-32768 & max(pcm)<=32767 & all(pcm:==round(pcm)),"invalid PCM samples")
    n=rows(pcm); u=mod(pcm:+65536,65536)
    bytes=vec((mod(u,256),floor(u:/256))')'
    if (replace) {
        fh=fopen(path,"rw")
        fseek(fh,0,-1); ftruncate(fh)
    }
    else fh=fopen(path,"w")
    fwrite(fh,"RIFF"+char(slk_lebytes(36+2*n,4))+"WAVEfmt "+char(slk_lebytes(16,4)))
    fwrite(fh,char((1,0,1,0,slk_lebytes(16000,4),slk_lebytes(32000,4),2,0,16,0)))
    fwrite(fh,"data"+char(slk_lebytes(2*n,4))+char(bytes))
    fclose(fh)
}
end
