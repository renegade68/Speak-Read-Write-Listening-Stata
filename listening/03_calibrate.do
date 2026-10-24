version 16.1
set more off
args templates predictions output
confirm new file "`output'"
preserve
tempfile truth
import delimited using "data/truth.csv", varnames(1) clear
save `truth'
use "`predictions'", clear
merge 1:1 sample_id using `truth', keep(match) nogenerate
sort sample_id
assert _N==50 & stage=="calibration"
quietly count if class_id>0
assert r(N)==30
mata:
cal_d=st_data(.,"best_distance");cal_g=st_data(.,"distance_gap")
cal_c=st_data(.,"candidate_id");cal_y=st_data(.,"class_id")
cal_cuts=uniqrows(sort(0\select(cal_d,cal_d:<.),1))
cal_gaps=uniqrows(sort(0\select(cal_g,cal_g:<.),1))
cal_grid=J(rows(cal_cuts)*rows(cal_gaps),6,.)
q=0
for (i=1;i<=rows(cal_cuts);i++) for (j=1;j<=rows(cal_gaps);j++) {
    a=(cal_d:<.):&(cal_d:<=cal_cuts[i]):&(cal_g:<.):&(cal_g:>cal_gaps[j])
    correct=sum(a:&(cal_y:>0):&(cal_c:==cal_y))
    rejected=sum((!a):&(cal_y:==0))
    false_accept=sum(a:&((cal_y:==0):|((cal_y:>0):&(cal_c:!=cal_y))))
    cal_grid[++q,]=(20*correct+30*rejected,false_accept,cal_cuts[i],cal_gaps[j],correct,rejected)
}
cal_grid=sort(cal_grid,(-1,2,3,-4))
cal_cut=cal_grid[1,3];cal_gap=cal_grid[1,4]
st_numscalar("public_cutoff",cal_cut);st_numscalar("public_gap",cal_gap)
st_matrix("calibration_best",cal_grid[1,])
fh=fopen(st_local("templates"),"r")
sig=fgetmatrix(fh);config=fgetmatrix(fh);labels=fgetmatrix(fh);bank=fgetmatrix(fh);index=fgetmatrix(fh);fclose(fh)
assert(sig=="mata_public_words_v1")
config[3]=cal_cut;config[4]=cal_gap
fh=fopen(st_local("output"),"w")
fputmatrix(fh,sig);fputmatrix(fh,config);fputmatrix(fh,labels);fputmatrix(fh,bank);fputmatrix(fh,index);fclose(fh)
end
matrix colnames calibration_best = integer_objective false_accept cutoff minimum_gap correct_accept negative_reject
matrix list calibration_best
restore
display as result "PUBLIC_CALIBRATION_COMPLETE"
