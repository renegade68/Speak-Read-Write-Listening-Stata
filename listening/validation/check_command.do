version 16.1
set more off
adopath ++ "`c(pwd)'/code"
clear
set obs 4
generate long sentinel = _n+200
tempfile prediction silent
wordlisten using data/audio/c001.wav, model(models/public_calibrated.mmat) saving("`prediction'")
assert _N==4 & sentinel==_n+200
assert r(candidates)==1
capture wordlisten using data/audio/c001.wav, model(models/public_calibrated.mmat) saving("`prediction'")
assert _rc==602
assert _N==4 & sentinel==_n+200
mata: slk_writewav(st_local("silent"),J(16000,1,0),0)
wordlisten using "`silent'", model(models/public_calibrated.mmat) saving("`prediction'") replace
assert r(candidates)==0 & r(accepted)==0
assert _N==4 & sentinel==_n+200
preserve
use "`prediction'", clear
assert _N==1 & decision_status=="no_signal" & accepted==0
restore

* Export public feature matrices only for independent calculation checks.
preserve
mata:
fh=fopen("models/public_templates.mmat","r")
audit_sig=fgetmatrix(fh);audit_config=fgetmatrix(fh);audit_labels=fgetmatrix(fh)
audit_bank=fgetmatrix(fh);audit_index=fgetmatrix(fh);fclose(fh)
st_matrix("audit_bank",audit_bank);st_matrix("audit_index",audit_index)
end
clear
svmat double audit_bank
export delimited using validation/template_features.csv, replace
clear
svmat double audit_index
export delimited using validation/template_index.csv, replace
foreach id in c001 c011 c021 {
    quietly wavread16 using "data/audio/`id'.wav", clear
    mata: audit_x=st_data(.,"amplitude1");audit_bounds=spc_bounds(audit_x)
    mata: st_matrix("audit_features",slk_features(audit_x[audit_bounds[1]..audit_bounds[2]],16000))
    clear
    svmat double audit_features
    export delimited using "validation/`id'_features.csv", replace
}
restore
assert _N==4 & sentinel==_n+200
display as result "PUBLIC_COMMAND_VALIDATION_PASS"
