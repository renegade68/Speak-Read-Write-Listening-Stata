*! pngread 0.1.0 24oct2026 -- experimental pure Stata/Mata PNG reader
* Copyright (c) 2026 Choonjoo Lee, Korea National Defense University.
* Licensed under the Academic Free License version 3.0 (AFL-3.0).
* License: https://github.com/renegade68/Speak-Read-Write-Listening-Stata/blob/main/LICENSE
* Original implementation from PNG, RFC1950 and RFC1951 specifications.
* No shell, Python, Java, plugin, external library or unzip executable is called.
program define pngread, rclass
    version 16.1
    syntax using/ [, CLEAR]
    if "`clear'" == "" & (c(k)>0 | c(N)>0) {
        display as error "data in memory; specify clear to replace"
        exit 4
    }
    mata: snp_import(st_local("using"))
    return scalar width = `pngwidth'
    return scalar height = `pngheight'
    return scalar bitdepth = 8
    return scalar colortype = `pngtype'
    return scalar has_icc = `pngicc'
    return scalar has_srgb = `pngsrgb'
    display as text "Read `pngwidth' x `pngheight' PNG; raw 8-bit RGBA samples."
end

version 16.1
mata:
mata set matastrict on

struct snp_tree {
    real matrix node
}
struct snp_image {
    real scalar width, height, colortype, icc, srgb
    real matrix rgba
    real rowvector filters, blocks
}

void snp_require(real scalar ok, string scalar message)
{
    if (!ok) _error(3498, "pngread: " + message)
}

real scalar snp_xor(real scalar a, real scalar b)
{
    real scalar r, p
    r=0; p=1
    while (a!=0 | b!=0) {
        if (mod(a,2)!=mod(b,2)) r=r+p
        a=floor(a/2); b=floor(b/2); p=p*2
    }
    return(r)
}

real rowvector snp_crctable()
{
    real rowvector t
    real scalar i,j,c
    t=J(1,256,0)
    for (i=0;i<256;i++) {
        c=i
        for (j=1;j<=8;j++) {
            if (mod(c,2)) c=snp_xor(floor(c/2),3988292384)
            else c=floor(c/2)
        }
        t[i+1]=c
    }
    return(t)
}

real scalar snp_crc(real rowvector b, real rowvector table)
{
    real scalar i,c
    c=4294967295
    for (i=1;i<=cols(b);i++)
        c=snp_xor(floor(c/256),table[snp_xor(mod(c,256),b[i])+1])
    return(4294967295-c)
}

real scalar snp_be(real rowvector b)
{
    real scalar i,r
    r=0
    for (i=1;i<=cols(b);i++) r=256*r+b[i]
    return(r)
}

real rowvector snp_slice(real rowvector a, real scalar start, real scalar n)
{
    if (n==0) return(J(1,0,.))
    return(a[|1,start \ 1,start+n-1|])
}

real scalar snp_bits(real rowvector b, real scalar pos, real scalar n)
{
    real scalar j,r
    snp_require(pos+n<=8*cols(b),"truncated DEFLATE stream")
    r=0
    for (j=0;j<n;j++) {
        r=r+mod(floor(b[floor(pos/8)+1]/2^mod(pos,8)),2)*2^j
        pos++
    }
    return(r)
}

struct snp_tree scalar snp_treebuild(real rowvector lens)
{
    struct snp_tree scalar t
    real rowvector count, next
    real scalar i,j,len,code,left,nodes,at,bit,child
    snp_require(all(lens:>=0) & all(lens:<=15),"invalid Huffman lengths")
    count=J(1,15,0); next=J(1,15,0)
    for (i=1;i<=cols(lens);i++) if (lens[i]) count[lens[i]]=count[lens[i]]+1
    left=1; code=0
    for (len=1;len<=15;len++) {
        left=2*left-count[len]
        snp_require(left>=0,"oversubscribed Huffman tree")
        if (len>1) code=2*(code+count[len-1])
        next[len]=code
    }
    t.node=J(1+sum(lens),3,0); t.node[,3]=J(rows(t.node),1,-1)
    nodes=1
    for (i=1;i<=cols(lens);i++) {
        len=lens[i]
        if (!len) continue
        code=next[len]; next[len]=next[len]+1; at=1
        for (j=len-1;j>=0;j--) {
            bit=mod(floor(code/2^j),2)
            child=t.node[at,bit+1]
            if (!child) {
                nodes++; child=nodes; t.node[at,bit+1]=child
            }
            at=child
        }
        t.node[at,3]=i-1
    }
    return(t)
}

real scalar snp_symbol(real rowvector b, real scalar pos, struct snp_tree scalar t)
{
    real scalar at,bit,j
    at=1
    for (j=1;j<=15;j++) {
        bit=snp_bits(b,pos,1); at=t.node[at,bit+1]
        snp_require(at>0,"invalid Huffman code")
        if (t.node[at,3]>=0) return(t.node[at,3])
    }
    _error(3498,"pngread: Huffman code exceeds 15 bits")
    return(.)
}

real scalar snp_adler(real rowvector b)
{
    real scalar s1,s2,i,j,n
    real rowvector part
    s1=1; s2=0
    for (i=1;i<=cols(b);i=i+4096) {
        n=min((4096,cols(b)-i+1)); part=snp_slice(b,i,n)
        s2=s2+n*s1
        for (j=1;j<=n;j++) s2=s2+(n-j+1)*part[j]
        s1=mod(s1+sum(part),65521); s2=mod(s2,65521)
    }
    return(s2*65536+s1)
}

real rowvector snp_inflate(real rowvector z, real scalar expected, real rowvector blocks)
{
    struct snp_tree scalar lit, dist, cl
    real rowvector data,out,ll,dd,order,codelens,lengths,lb,le,db,de
    real scalar pos,n,final,kind,len,nlen,hlit,hdist,hclen,i,sym,k,v,rep,d,j,window
    snp_require(cols(z)>=6,"short zlib stream")
    snp_require(mod(z[1],16)==8 & floor(z[1]/16)<=7,"unsupported zlib method/window")
    snp_require(mod(z[1]*256+z[2],31)==0 & mod(floor(z[2]/32),2)==0,"bad zlib header/dictionary")
    window=2^(floor(z[1]/16)+8)
    data=snp_slice(z,3,cols(z)-6); pos=0; n=0; final=0
    out=J(1,expected,0); blocks=J(1,3,0)
    lb=(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258)
    le=(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0)
    db=(1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577)
    de=(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13)
    while (!final) {
        final=snp_bits(data,pos,1); kind=snp_bits(data,pos,2)
        snp_require(kind<3,"reserved DEFLATE block type")
        blocks[kind+1]=blocks[kind+1]+1
        if (kind==0) {
            pos=8*ceil(pos/8)
            len=snp_bits(data,pos,16); nlen=snp_bits(data,pos,16)
            snp_require(len+nlen==65535,"stored block length check failed")
            snp_require(n+len<=expected,"DEFLATE exceeds declared image size")
            for (j=1;j<=len;j++) {
                n++; out[n]=snp_bits(data,pos,8)
            }
            continue
        }
        if (kind==1) {
            ll=(J(1,144,8),J(1,112,9),J(1,24,7),J(1,8,8))
            dd=J(1,32,5)
        }
        else {
            hlit=snp_bits(data,pos,5)+257; hdist=snp_bits(data,pos,5)+1
            hclen=snp_bits(data,pos,4)+4
            snp_require(hlit<=286,"invalid literal alphabet length")
            order=(16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15)
            codelens=J(1,19,0)
            for (i=1;i<=hclen;i++) codelens[order[i]+1]=snp_bits(data,pos,3)
            cl=snp_treebuild(codelens)
            lengths=J(1,hlit+hdist,0); k=1
            while (k<=cols(lengths)) {
                sym=snp_symbol(data,pos,cl)
                if (sym<=15) {
                    lengths[k]=sym; k++; continue
                }
                if (sym==16) {
                    snp_require(k>1,"Huffman repeat without preceding length")
                    v=lengths[k-1]; rep=snp_bits(data,pos,2)+3
                }
                else if (sym==17) {
                    v=0; rep=snp_bits(data,pos,3)+3
                }
                else {
                    v=0; rep=snp_bits(data,pos,7)+11
                }
                snp_require(k+rep-1<=cols(lengths),"Huffman repeat overflow")
                for (j=1;j<=rep;j++) {
                    lengths[k]=v; k++
                }
            }
            ll=snp_slice(lengths,1,hlit); dd=snp_slice(lengths,hlit+1,hdist)
        }
        snp_require(ll[257]>0,"missing DEFLATE end-of-block symbol")
        lit=snp_treebuild(ll); dist=snp_treebuild(dd)
        while (1) {
            sym=snp_symbol(data,pos,lit)
            if (sym==256) break
            if (sym<256) {
                snp_require(n<expected,"DEFLATE exceeds declared image size")
                n++; out[n]=sym
            }
            else {
                snp_require(sym<=285,"reserved length code")
                i=sym-256; len=lb[i]+snp_bits(data,pos,le[i])
                sym=snp_symbol(data,pos,dist)
                snp_require(sym<30,"reserved distance code")
                d=db[sym+1]+snp_bits(data,pos,de[sym+1])
                snp_require(d<=n & d<=window & n+len<=expected,"invalid DEFLATE back-reference")
                for (j=1;j<=len;j++) {
                    n++; out[n]=out[n-d]
                }
            }
        }
    }
    snp_require(n==expected & ceil(pos/8)==cols(data),"DEFLATE size or trailing-data mismatch")
    snp_require(snp_adler(out)==snp_be(snp_slice(z,cols(z)-3,4)),"zlib Adler-32 mismatch")
    return(out)
}

real scalar snp_paeth(real scalar a, real scalar b, real scalar c)
{
    real scalar p,pa,pb,pc
    p=a+b-c; pa=abs(p-a); pb=abs(p-b); pc=abs(p-c)
    if (pa<=pb & pa<=pc) return(a)
    if (pb<=pc) return(b)
    return(c)
}

real matrix snp_unfilter(real rowvector raw, real scalar w, real scalar h,
                         real scalar channels, real rowvector filters)
{
    real matrix result
    real rowvector current,previous
    real scalar row,stride,p,f,j,a,b,c,pred
    stride=w*channels; p=1; previous=J(1,stride,0)
    result=J(h,stride,0); filters=J(1,5,0)
    for (row=1;row<=h;row++) {
        f=raw[p]; p++; snp_require(f<=4,"unknown PNG row filter")
        filters[f+1]=filters[f+1]+1; current=snp_slice(raw,p,stride); p=p+stride
        if (f==2) current=mod(current+previous,256)
        else if (f!=0) {
            for (j=1;j<=stride;j++) {
                a=0; c=0; b=previous[j]
                if (j>channels) {
                    a=current[j-channels]; c=previous[j-channels]
                }
                if (f==1) pred=a
                else if (f==3) pred=floor((a+b)/2)
                else pred=snp_paeth(a,b,c)
                current[j]=mod(current[j]+pred,256)
            }
        }
        result[row,]=current; previous=current
    }
    return(colshape(result,channels))
}

struct snp_image scalar snp_read(string scalar path)
{
    struct snp_image scalar im
    real rowvector bytes,table,payload,packed,palette,trans,raw
    real scalar fh,size,p,len,ihdr,idat,ended,idatclosed,channels,needed,i,t
    real matrix samples,pal
    string scalar type
    fh=fopen(path,"r"); fseek(fh,0,1); size=ftell(fh); fseek(fh,0,-1)
    if (size>16777216 | size<8) {
        fclose(fh); _error(3498,"pngread: file size outside 8 bytes..16 MiB")
    }
    bytes=ascii(fread(fh,size)); fclose(fh)
    snp_require(all(snp_slice(bytes,1,8):==(137,80,78,71,13,10,26,10)),"not a PNG file")
    table=snp_crctable(); packed=palette=trans=J(1,0,.)
    p=9; ihdr=idat=ended=idatclosed=0; im.icc=im.srgb=0
    while (p<=cols(bytes)) {
        snp_require(p+11<=cols(bytes),"truncated PNG chunk")
        len=snp_be(snp_slice(bytes,p,4)); type=char(snp_slice(bytes,p+4,4))
        snp_require(p+len+11<=cols(bytes),"PNG chunk exceeds file size")
        snp_require(snp_crc(snp_slice(bytes,p+4,len+4),table)==snp_be(snp_slice(bytes,p+8+len,4)),"PNG chunk CRC mismatch: "+type)
        payload=snp_slice(bytes,p+8,len)
        snp_require(ihdr | type=="IHDR","IHDR must be first")
        if (idat & type!="IDAT") idatclosed=1
        if (type=="IHDR") {
            snp_require(!ihdr & len==13,"invalid or duplicate IHDR")
            ihdr=1; im.width=snp_be(snp_slice(payload,1,4)); im.height=snp_be(snp_slice(payload,5,4))
            im.colortype=payload[10]
            snp_require(payload[9]==8,"only 8-bit samples supported in this version")
            snp_require(payload[11]==0 & payload[12]==0 & payload[13]==0,"unsupported compression/filter/interlace method")
            snp_require(any(im.colortype:==(0,2,3,4,6)),"unsupported PNG color type")
            channels=1
            if (im.colortype==2) channels=3
            if (im.colortype==4) channels=2
            if (im.colortype==6) channels=4
            needed=im.height*(1+im.width*channels)
            snp_require(im.width>0 & im.height>0 & needed<=8388608,"invalid dimensions or decoded data exceeds 8 MiB limit")
        }
        else if (type=="PLTE") {
            snp_require(!idat & cols(palette)==0 & len>=3 & len<=768 & mod(len,3)==0,"invalid PLTE")
            palette=payload
        }
        else if (type=="tRNS") {
            snp_require(!idat & cols(trans)==0 & len>0,"invalid tRNS")
            trans=payload
        }
        else if (type=="IDAT") {
            snp_require(!idatclosed,"nonconsecutive IDAT chunks")
            idat=1; packed=(packed,payload)
        }
        else if (type=="IEND") {
            snp_require(idat & len==0 & p+11==cols(bytes),"invalid IEND or trailing data")
            ended=1
        }
        else if (type=="iCCP") im.icc=1
        else if (type=="sRGB") {
            snp_require(len==1 & payload[1]<=3,"invalid sRGB chunk")
            im.srgb=1
        }
        else {
            snp_require(type!="acTL" & type!="fcTL" & type!="fdAT","animated PNG not supported")
            snp_require(mod(floor(bytes[p+4]/32),2)==1,"unknown critical PNG chunk: "+type)
        }
        p=p+len+12
    }
    snp_require(ended,"missing IEND")
    raw=snp_inflate(packed,needed,im.blocks)
    samples=snp_unfilter(raw,im.width,im.height,channels,im.filters)
    im.rgba=J(rows(samples),4,255)
    if (im.colortype==0 | im.colortype==4) {
        im.rgba[,1]=im.rgba[,2]=im.rgba[,3]=samples[,1]
        if (im.colortype==4) im.rgba[,4]=samples[,2]
    }
    else if (im.colortype==2 | im.colortype==6) {
        im.rgba[,1..3]=samples[,1..3]
        if (im.colortype==6) im.rgba[,4]=samples[,4]
    }
    else {
        snp_require(cols(palette)>0,"indexed PNG lacks PLTE")
        pal=colshape(palette,3)
        snp_require(max(samples)<rows(pal),"palette index out of bounds")
        im.rgba[,1..3]=pal[samples[,1]:+1,]
    }
    if (cols(trans)) {
        if (im.colortype==3) {
            snp_require(cols(trans)<=rows(pal),"palette transparency exceeds PLTE")
            for (i=1;i<=rows(samples);i++) if (samples[i,1]<cols(trans)) im.rgba[i,4]=trans[samples[i,1]+1]
        }
        else if (im.colortype==0) {
            snp_require(cols(trans)==2,"invalid grayscale transparency")
            t=snp_be(trans)
            for (i=1;i<=rows(samples);i++) if (samples[i,1]==t) im.rgba[i,4]=0
        }
        else if (im.colortype==2) {
            snp_require(cols(trans)==6,"invalid RGB transparency")
            trans=(snp_be(trans[1..2]),snp_be(trans[3..4]),snp_be(trans[5..6]))
            for (i=1;i<=rows(samples);i++) if (all(samples[i,]:==trans)) im.rgba[i,4]=0
        }
        else _error(3498,"pngread: tRNS is not valid with an alpha channel")
    }
    return(im)
}

void snp_import(string scalar path)
{
    struct snp_image scalar im
    real scalar n
    real colvector index
    im=snp_read(path); n=rows(im.rgba)
    // Replace data only after decoding has succeeded.
    stata("clear")
    st_addobs(n)
    (void) st_addvar("long",("x","y"))
    (void) st_addvar("int",("red","green","blue","alpha"))
    index=(0::n-1)
    st_store(.,("x","y"),(mod(index,im.width),floor(index:/im.width)))
    st_store(.,("red","green","blue","alpha"),im.rgba)
    st_local("pngwidth",strofreal(im.width)); st_local("pngheight",strofreal(im.height))
    st_local("pngtype",strofreal(im.colortype)); st_local("pngicc",strofreal(im.icc))
    st_local("pngsrgb",strofreal(im.srgb))
}
end
