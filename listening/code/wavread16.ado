*! wavread16 0.2.0 24oct2026 -- PCM16 WAV, including a restricted extensible header
program define wavread16, rclass
    version 16.1
    syntax using/ [, CLEAR]
    if "`clear'" == "" & (c(k)>0 | c(N)>0) {
        display as error "data in memory; specify clear to replace"
        exit 4
    }
    mata: slw_import(st_local("using"))
    return scalar samplerate = `wavrate'
    return scalar channels = `wavchannels'
    return scalar frames = `wavframes'
    return scalar duration = `wavframes'/`wavrate'
    return scalar bits = 16
    display as text "PCM16 WAV: `wavframes' frames, `wavrate' Hz, `wavchannels' channel(s)."
end

version 16.1
mata:
mata set matastrict on

struct slw_audio {
    real scalar rate, channels
    real matrix pcm
}

void slw_require(real scalar ok, string scalar message)
{
    if (!ok) _error(3498, "wavread16: " + message)
}

real scalar slw_le(real rowvector b)
{
    real scalar i, n
    n=0
    for (i=1; i<=cols(b); i++) n=n+b[i]*256^(i-1)
    return(n)
}

struct slw_audio scalar slw_read(string scalar path)
{
    struct slw_audio scalar a
    real scalar fh, size, p, len, fmt, data, start, bytes, align, ratebytes, tag, bits
    real rowvector b, v
    real matrix pairs
    string scalar kind
    fh=fopen(path,"r")
    fseek(fh,0,1); size=ftell(fh); fseek(fh,0,-1)
    if (size<12 | size>16777216) {
        fclose(fh)
        _error(3498,"wavread16: file size outside 12 bytes..16 MiB")
    }
    b=ascii(fread(fh,size)); fclose(fh)
    slw_require(cols(b)==size,"short file read")
    slw_require(char(b[1..4])=="RIFF" & char(b[9..12])=="WAVE", "expected RIFF/WAVE")
    slw_require(slw_le(b[5..8])+8==size,"RIFF size mismatch")
    p=13; fmt=data=start=bytes=0
    while (p<=size) {
        slw_require(p+7<=size,"truncated chunk header")
        kind=char(b[p..p+3]); len=slw_le(b[p+4..p+7])
        slw_require(p+7+len+mod(len,2)<=size,"truncated chunk or padding")
        if (kind=="fmt ") {
            slw_require(!fmt & (len==16 | len==18 | len==40),"duplicate or unsupported fmt chunk")
            fmt=1
            tag=slw_le(b[p+8..p+9]); a.channels=slw_le(b[p+10..p+11])
            a.rate=slw_le(b[p+12..p+15]); ratebytes=slw_le(b[p+16..p+19])
            align=slw_le(b[p+20..p+21]); bits=slw_le(b[p+22..p+23])
            slw_require((tag==1 | tag==65534) & bits==16,"only integer PCM16 supported")
            slw_require(a.channels==1 | a.channels==2,"only mono/stereo supported")
            slw_require(a.rate>=1 & a.rate<=384000,"unsupported sample rate")
            slw_require(align==2*a.channels & ratebytes==a.rate*align,"invalid byte rate or block alignment")
            if (tag==1) {
                slw_require(len==16 | len==18,"unexpected PCM fmt size")
                if (len==18) slw_require(slw_le(b[p+24..p+25])==0,"unexpected PCM extension")
            }
            else {
                slw_require(len==40,"extensible fmt must contain 40 bytes")
                slw_require(slw_le(b[p+24..p+25])==22 & slw_le(b[p+26..p+27])==16,"extensible PCM requires 16 valid bits")
                slw_require(all(b[p+32..p+47]:==(1,0,0,0,0,0,16,0,128,0,0,170,0,56,155,113)),"extensible subtype is not integer PCM")
                slw_require(slw_le(b[p+28..p+31])==0 | (a.channels==1 & slw_le(b[p+28..p+31])==4) | (a.channels==2 & slw_le(b[p+28..p+31])==3),"unsupported channel mask")
            }
        }
        else if (kind=="data") {
            slw_require(!data & len>0,"duplicate or empty data chunk")
            data=1; start=p+8; bytes=len
        }
        p=p+8+len+mod(len,2)
    }
    slw_require(fmt & data,"missing fmt or data chunk")
    slw_require(mod(bytes,2*a.channels)==0,"partial audio frame")
    pairs=colshape(b[start..start+bytes-1],2)
    v=(pairs[,1]+256*pairs[,2])'
    v=v:-65536:*(v:>=32768)
    a.pcm=colshape(v,a.channels)
    return(a)
}

void slw_import(string scalar path)
{
    struct slw_audio scalar a
    real scalar n, j
    string scalar suffix
    a=slw_read(path); n=rows(a.pcm)
    // No change to the dataset until the entire file has been decoded.
    stata("clear")
    st_addobs(n)
    (void) st_addvar("long","sample")
    (void) st_addvar("double","time")
    st_store(.,"sample",(0::n-1))
    st_store(.,"time",(0::n-1):/a.rate)
    for (j=1; j<=a.channels; j++) {
        suffix=strofreal(j)
        // Stata int cannot store every signed PCM16 value; use long.
        (void) st_addvar("long","pcm"+suffix)
        (void) st_addvar("double","amplitude"+suffix)
        st_store(.,"pcm"+suffix,a.pcm[,j])
        st_store(.,"amplitude"+suffix,a.pcm[,j]:/32768)
    }
    st_local("wavrate",strofreal(a.rate))
    st_local("wavchannels",strofreal(a.channels))
    st_local("wavframes",strofreal(n))
}
end
