version 16.1
set more off
preserve
use results/evaluation_scored.dta, clear
keep if known_total
collapse (sum) correct_accept wrong_accept known_reject, by(class_id label)
sort class_id
export delimited using results/target_word_summary.csv
graph bar (asis) correct_accept wrong_accept known_reject, ///
    over(label, sort(class_id)) stack ///
    bar(1, color(navy)) bar(2, color(maroon)) bar(3, color(gs12)) ///
    ylabel(0(5)20, angle(horizontal)) ytitle("Clips (20 per target word)") ///
    title("Public audio: first frozen evaluation") ///
    subtitle("Speakers/sessions disjoint from registration and calibration") ///
    legend(order(1 "Correct accept" 2 "Wrong accept" 3 "Rejected" ) rows(1)) ///
    note("Other words: 27/30 rejected. Synthetic pink noise: 5/5 rejected." ///
         "Small predetermined subset of Speech Commands v0.02; not the full benchmark.")
graph export results/target_decisions.png, width(1600)
graph export results/target_decisions.svg
restore
