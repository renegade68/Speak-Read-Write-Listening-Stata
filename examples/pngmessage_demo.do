* Copyright (c) 2026 Choonjoo Lee.
* Licensed under the Academic Free License version 3.0; see repository LICENSE.
* Two independent Stata sessions, one new shared folder; current data are kept.
* Start B, then A within 60 seconds. Use a new folder for each run.
* do pngmessage_demo.do B "/your/path/new_exchange"
* do pngmessage_demo.do A "/your/path/new_exchange"
version 16.1
args role exchange
if !inlist("`role'", "A", "B") | `"`exchange'"'=="" {
    display as error "specify A or B and a new shared-folder path"
    exit 198
}
capture mkdir `"`exchange'"'
if "`role'"=="B" {
    forvalues id=417/421 {
        pngmessage respond using "`exchange'/request_`id'.png", ///
            saving("`exchange'/reply_`id'.png") id(`id') wait(60)
    }
}
else {
    local request417 "PING 417"
    local request418 "SUM 2 3"
    local request419 "SUM 10 -4"
    local request420 "NOBS"
    local request421 "SUM 2 banana"
    forvalues id=417/421 {
        pngmessage send using "`exchange'/request_`id'.png", ///
            id(`id') text("`request`id''")
        pngmessage read using "`exchange'/reply_`id'.png", id(`id') wait(60)
        if `id'==417 assert r(type)=="reply" & r(text)=="PONG 417"
        if `id'==418 assert r(type)=="reply" & r(text)=="RESULT 5"
        if `id'==419 assert r(type)=="reply" & r(text)=="RESULT 6"
        if `id'==420 assert r(type)=="reply" & substr(r(text),1,5)=="NOBS "
        if `id'==421 assert r(type)=="error" & r(text)=="ERROR SUM_REQUIRES_TWO_NUMBERS"
    }
}
display as result "PNG exchange finished for session `role'."
