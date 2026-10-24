version 16.1
set more off
mkdir rebuild_01
do 01_build_templates.do rebuild_01/public_templates.mmat
do 02_score_clips.do calibration rebuild_01/public_templates.mmat rebuild_01/calibration_uncalibrated
do 03_calibrate.do rebuild_01/public_templates.mmat rebuild_01/calibration_uncalibrated.dta rebuild_01/public_calibrated.mmat
display as result "PUBLIC_REBUILD_COMPLETE"
display as text "Registration/calibration only. Original models and first results are preserved."
