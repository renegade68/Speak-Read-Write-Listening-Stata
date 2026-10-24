version 16.1
set more off
args output
if "`output'"=="" local output "models/public_templates.mmat"
confirm new file "`output'"
adopath ++ "`c(pwd)'/code"
preserve
tempfile truth
import delimited using "data/truth.csv", varnames(1) clear
save `truth'
import delimited using "data/registration_inputs.csv", varnames(1) clear
merge 1:1 sample_id using `truth', keep(match) nogenerate
sort sample_id
assert _N==45 & stage=="registration" & inrange(class_id,1,3)
run code/wordcore.mata
run code/clipcore.mata
capture mata: mata drop spc_register_one()
mata:
void spc_register_one(real scalar i, real colvector classes, real matrix bank, real matrix index, real matrix stats)
{
    real colvector x
    real rowvector bounds
    real matrix F
    x=st_data(.,"amplitude1");bounds=spc_bounds(x)
    stats[i,1..2]=(i,classes[i])
    if (cols(bounds)==2) {
        F=slk_features(x[bounds[1]..bounds[2]],16000)
        index=index\(rows(bank)+1,rows(bank)+rows(F),classes[i])
        bank=bank\F
        stats[i,3..4]=(1,rows(F))
    }
    else stats[i,3..4]=(0,0)
}
reg_paths=st_sdata(.,"audio_path");reg_ids=st_sdata(.,"sample_id")
reg_classes=st_data(.,"class_id");reg_bank=J(0,13,.);reg_index=J(0,3,.)
reg_stats=J(rows(reg_paths),4,.)
end
forvalues i=1/45 {
    mata: st_local("input",reg_paths[`i'])
    quietly wavread16 using "`input'", clear
    assert r(samplerate)==16000 & r(channels)==1
    mata: spc_register_one(`i',reg_classes,reg_bank,reg_index,reg_stats)
}
mata:
for (k=1;k<=3;k++) slk_require(sum(reg_index[,3]:==k)>0,"no usable template in a class")
reg_fh=fopen(st_local("output"),"w")
fputmatrix(reg_fh,"mata_public_words_v1");fputmatrix(reg_fh,(16000,13,-1,-1))
fputmatrix(reg_fh,("yes","no","stop"));fputmatrix(reg_fh,reg_bank);fputmatrix(reg_fh,reg_index)
fclose(reg_fh)
st_matrix("registration_stats",reg_stats)
end
clear
svmat double registration_stats, names(col)
rename (c1 c2 c3 c4) (row_id class_id usable feature_frames)
list, noobs
restore
display as result "PUBLIC_TEMPLATE_BUILD_COMPLETE"
