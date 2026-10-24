version 16.1
set more off
capture mkdir replay_outputs
do 02_score_clips.do evaluation models/public_calibrated.mmat replay_outputs/evaluation_predictions
preserve
use replay_outputs/evaluation_predictions.dta, clear
quietly count
local clips = r(N)
quietly count if accepted==1
local accepts = r(N)
list sample_id recognized_label decision_status, noobs
restore
display as result "PUBLIC_REPLAY_COMPLETE: `clips' clips, `accepts' accepted."
display as text "Expected for these supplied clips: 95 clips, 35 accepts (including 8 false accepts)."
display as text "See results/evaluation_summary.csv for the original truth-based breakdown."
