*! pngmessage 0.2.0 24oct2026 -- experimental PNG message exchange
* Copyright (c) 2026 Choonjoo Lee, Korea National Defense University.
* Licensed under the Academic Free License version 3.0 (AFL-3.0).
* License: https://github.com/renegade68/Speak-Read-Write-Listening-Stata/blob/main/LICENSE
* Original PNG/zlib writer; uses the accompanying pngread Mata decoder.
program define pngmessage, rclass
    version 16.1
    gettoken action 0 : 0
    if !inlist("`action'", "send", "read", "respond") {
        display as error "syntax: pngmessage send|read|respond using filename, options"
        exit 198
    }
    syntax using/ [, ID(real 0) TEXT(string) SAVing(string) WAIT(integer 0)]
    if `id'<0 | `id'>2147483647 | `id'!=floor(`id') | `wait'<0 | `wait'>60 {
        display as error "id must be an integer 1..2147483647 (or omitted); wait is 0..60 seconds"
        exit 198
    }
    if "`action'"=="send" {
        if `id'==0 | `wait'!=0 | `"`saving'"'!="" {
            display as error "send requires id(); saving() and wait() are not allowed"
            exit 198
        }
        confirm new file `"`using'"'
        mata: pm_send(st_local("using"),strtoreal(st_local("id")),st_local("text"))
    }
    else {
        if `"`text'"'!="" | ("`action'"=="read" & `"`saving'"'!="") {
            display as error "text() is for send; saving() is for respond"
            exit 198
        }
        if "`action'"=="respond" {
            if `"`saving'"'=="" {
                display as error "respond requires saving()"
                exit 198
            }
            confirm new file `"`saving'"'
        }
        local started = clock("`c(current_date)' `c(current_time)'", "DMYhms")
        while 1 {
            if `wait'==0 {
                mata: pm_receive(st_local("using"),strtoreal(st_local("id")))
                continue, break
            }
            capture mata: pm_receive(st_local("using"),strtoreal(st_local("id")))
            local rc = _rc
            if `rc'==0 continue, break
            if !inlist(`rc',601,3498) {
                display as error "pngmessage: invalid message or unexpected id; return code `rc'"
                exit `rc'
            }
            local elapsed = clock("`c(current_date)' `c(current_time)'", "DMYhms") - `started'
            if `elapsed'>=1000*`wait' {
                display as error "pngmessage: timed out waiting for a complete PNG (last return code `rc')"
                exit 498
            }
            sleep 100
        }
        if "`action'"=="respond" {
            mata: pm_respond(st_local("saving"),st_nobs())
        }
    }
    mata: printf("%s id=%s: %s\n",st_global("r(type)"),strtrim(strofreal(st_numscalar("r(id)"),"%21.0f")),st_global("r(text)"))
    return add
end

* Load the decoder's Mata routines without replacing data in memory.
capture mata: snp_require(1, "")
if _rc {
    capture program drop pngread
    quietly findfile pngread.ado
    quietly do `"`r(fn)'"'
}
version 16.1
mata:
mata set matastrict on

void pm_require(real scalar ok, string scalar why)
{
    if (!ok) _error(498,"pngmessage: "+why)
}

real rowvector pm_be(real scalar value, real scalar n)
{
    real rowvector out
    real scalar i,rest
    rest=value
    out=J(1,n,0)
    for (i=n;i>=1;i--) {
        out[i]=mod(rest,256); rest=floor(rest/256)
    }
    return(out)
}

real rowvector pm_chunk(string scalar tag, real rowvector payload)
{
    real rowvector body
    body=(ascii(tag),payload)
    return((pm_be(cols(payload),4),body,pm_be(snp_crc(body,snp_crctable()),4)))
}

real rowvector pm_zlib(real rowvector raw)
{
    real rowvector out
    real scalar p,n,final
    out=(120,1); p=1
    while (p<=cols(raw)) {
        n=min((65535,cols(raw)-p+1)); final=(p+n-1==cols(raw))
        out=(out,final,mod(n,256),floor(n/256),mod(65535-n,256),floor((65535-n)/256),snp_slice(raw,p,n))
        p=p+n
    }
    return((out,pm_be(snp_adler(raw),4)))
}

// A byte is one constant 8x8 tile; 32 tiles per row, zero padding.
void pm_pixels(string scalar path, real rowvector bytes)
{
    real rowvector padded,raw,row,out,header
    real scalar h,t,y,x,p,fh,rc
    pm_require(cols(bytes)>=1 & cols(bytes)<=1039,"invalid tile count")
    h=8*ceil(cols(bytes)/32)
    padded=J(1,32*h/8,0); padded[1..cols(bytes)]=bytes
    raw=J(1,h*257,0); p=1
    for (y=0;y<h;y++) {
        row=J(1,256,0)
        for (x=0;x<256;x++) {
            t=floor(y/8)*32+floor(x/8)+1; row[x+1]=padded[t]
        }
        raw[|1,p+1 \ 1,p+256|]=row; p=p+257
    }
    header=(pm_be(256,4),pm_be(h,4),8,0,0,0,0)
    out=(137,80,78,71,13,10,26,10,pm_chunk("IHDR",header),pm_chunk("IDAT",pm_zlib(raw)),pm_chunk("IEND",J(1,0,.)))
    fh=fopen(path,"w")
    rc=_fwrite(fh,char(out))
    if (rc<0) {
        (void) _fclose(fh)
        _error(-rc,"pngmessage: PNG write failed")
    }
    rc=_fclose(fh)
    if (rc<0) _error(-rc,"pngmessage: PNG close failed")
}

void pm_results(string scalar path, real scalar id, real scalar kind, string scalar text)
{
    string rowvector names
    names=("request","reply","error")
    st_rclear()
    st_numscalar("r(id)",id); st_numscalar("r(kind)",kind)
    st_numscalar("r(bytes)",strlen(text)); st_numscalar("r(width)",256)
    st_numscalar("r(height)",8*ceil((15+strlen(text))/32))
    // Return received text as data, without inserting it in Stata command syntax.
    st_global("r(text)",text); st_global("r(type)",names[kind])
    st_global("r(file)",path)
}

void pm_write(string scalar path, real scalar id, real scalar kind, string scalar text)
{
    real rowvector body
    pm_require(id>=1 & id<=2147483647 & id==floor(id),"invalid message id")
    pm_require(any(kind:==(1,2,3)),"invalid message kind")
    pm_require(strlen(text)>=1 & strlen(text)<=1024,"text must contain 1..1024 UTF-8 bytes")
    pm_require(ustrinvalidcnt(text)==0 & !any(ascii(text):==0),"text must be valid UTF-8 without NUL bytes")
    body=(ascii("SPM1"),pm_be(id,4),kind,pm_be(strlen(text),2),ascii(text))
    pm_pixels(path,(body,pm_be(snp_crc(body,snp_crctable()),4)))
    pm_results(path,id,kind,text)
}

void pm_send(string scalar path, real scalar id, string scalar text)
{
    pm_write(path,id,1,text)
}

void pm_receive(string scalar path, real scalar expectedid)
{
    struct snp_image scalar im
    real rowvector bytes,body
    real scalar tiles,t,y,x,base,first,n,id,kind,total
    string scalar text
    im=snp_read(path)
    pm_require(im.colortype==0 & im.width==256 & im.height>=8 & im.height<=264 & mod(im.height,8)==0,"not an SPM1 grayscale tile layout")
    pm_require(all(im.rgba[,4]:==255),"transparent message tiles")
    tiles=32*im.height/8; bytes=J(1,tiles,0)
    for (t=0;t<tiles;t++) {
        base=floor(t/32)*8*256+mod(t,32)*8+1
        first=im.rgba[base,1]; bytes[t+1]=first
        for (y=0;y<8;y++) for (x=0;x<8;x++)
            pm_require(im.rgba[base+y*256+x,1]==first,"nonuniform message tile")
    }
    pm_require(char(bytes[1..4])=="SPM1","unknown message magic/version")
    id=snp_be(bytes[5..8]); kind=bytes[9]; n=snp_be(bytes[10..11]); total=15+n
    pm_require(id>=1 & id<=2147483647 & any(kind:==(1,2,3)),"invalid message header")
    pm_require(n>=1 & n<=1024 & tiles==32*ceil(total/32),"invalid message length")
    body=snp_slice(bytes,1,11+n)
    pm_require(snp_crc(body,snp_crctable())==snp_be(snp_slice(bytes,12+n,4)),"message CRC mismatch")
    if (total<tiles) pm_require(all(snp_slice(bytes,total+1,tiles-total):==0),"nonzero message padding")
    text=char(snp_slice(bytes,12,n))
    pm_require(ustrinvalidcnt(text)==0 & !any(ascii(text):==0),"invalid UTF-8 message text")
    if (expectedid!=0 & id!=expectedid) _error(459,"pngmessage: unexpected message id")
    pm_results(path,id,kind,text)
}

void pm_respond(string scalar path, real scalar nobs)
{
    string rowvector words
    string scalar request,reply
    real scalar id,kind,a,b
    id=st_numscalar("r(id)")
    pm_require(st_numscalar("r(kind)")==1,"respond requires a request, not a reply")
    request=st_global("r(text)"); words=tokens(request); kind=2
    if (cols(words)==0) {
        reply="ERROR EMPTY_REQUEST"; kind=3
    }
    else if (words[1]=="PING") {
        reply="PONG"
        if (cols(words)>1) reply=reply+" "+invtokens(words[2..cols(words)])
    }
    else if (words[1]=="SUM") {
        reply="ERROR SUM_REQUIRES_TWO_NUMBERS"; kind=3
        if (cols(words)==3) {
            a=strtoreal(words[2]); b=strtoreal(words[3])
            if (a<. & b<. & a+b<.) {
                reply="RESULT "+strtrim(strofreal(a+b,"%21.15g")); kind=2
            }
        }
    }
    else if (words[1]=="NOBS" & cols(words)==1) reply="NOBS "+strtrim(strofreal(nobs,"%21.0f"))
    else {
        reply="ERROR UNKNOWN_REQUEST"; kind=3
    }
    pm_write(path,id,kind,reply)
}
end
