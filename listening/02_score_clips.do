version 16.1
set more off
args stage model output
if !inlist("`stage'","calibration","evaluation") exit 198
confirm file "`model'"
confirm new file "`output'.dta"
confirm new file "`output'.csv"
adopath ++ "`c(pwd)'/code"
preserve
import delimited using "data/`stage'_inputs.csv", varnames(1) clear
sort sample_id
local n = _N
mata: batch_paths=st_sdata(.,"audio_path");batch_ids=st_sdata(.,"sample_id")
tempfile piece stack
clear
save `stack', emptyok
forvalues i=1/`n' {
    mata: st_local("input",batch_paths[`i']);st_local("sample",batch_ids[`i'])
    quietly wordlisten using "`input'", model("`model'") saving("`piece'") replace
    quietly use "`piece'", clear
    generate str4 sample_id = "`sample'"
    quietly append using `stack'
    quietly save `stack', replace
    if mod(`i',10)==0 display as text "`stage': `i' / `n' clips scored"
}
sort sample_id
save "`output'.dta"
export delimited using "`output'.csv"
restore
display as result "PUBLIC_CLIP_SCORING_COMPLETE: `stage'"
