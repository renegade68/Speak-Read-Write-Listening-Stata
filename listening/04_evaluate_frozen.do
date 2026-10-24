version 16.1
set more off
confirm file models/frozen_before_evaluation.json
confirm new file results/evaluation_predictions.dta
do 02_score_clips.do evaluation models/public_calibrated.mmat results/evaluation_predictions
preserve
tempfile truth
import delimited using data/truth.csv, varnames(1) clear
save `truth'
use results/evaluation_predictions.dta, clear
merge 1:1 sample_id using `truth', keep(match) nogenerate
sort sample_id
assert _N==95 & stage=="evaluation"
generate byte known_total = class_id>0
generate byte correct_accept = known_total & accepted==1 & candidate_id==class_id
generate byte wrong_accept = known_total & accepted==1 & candidate_id!=class_id
generate byte known_reject = known_total & accepted==0
generate byte nearest_correct = known_total & candidate_id==class_id
generate byte other_total = kind=="other_word"
generate byte other_reject = other_total & accepted==0
generate byte other_accept = other_total & accepted==1
generate byte noise_total = kind=="synthetic_noise"
generate byte noise_reject = noise_total & accepted==0
generate byte noise_accept = noise_total & accepted==1
generate byte no_signal = decision_status=="no_signal"
assert accepted==0 | accepted==1
assert correct_accept+wrong_accept+known_reject==known_total
save results/evaluation_scored.dta
export delimited using results/evaluation_scored.csv
tabulate label recognized_label, missing
collapse (sum) known_total correct_accept wrong_accept known_reject nearest_correct other_total other_reject other_accept noise_total noise_reject noise_accept no_signal
assert known_total==60 & other_total==30 & noise_total==5
save results/evaluation_summary.dta
export delimited using results/evaluation_summary.csv
list, noobs
restore
display as result "FIRST_PUBLIC_EVALUATION_COMPLETE"
