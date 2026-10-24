{smcl}
{title:wordlisten 0.2.0 — Experimental yes/no/stop matching of public audio clips}

{p 4 4 2}
{cmd:wordlisten using} {it:clip.wav}{cmd:, model(}{it:model.mmat}{cmd:) saving(}{it:output.dta}{cmd:)} [{cmd:replace}]

{p 4 4 2}
This version processes a single isolated clip, using a public Speech Commands
yes/no/stop template model. It is not continuous speech detection, microphone
capture, or unrestricted transcription. It is distinct from the earlier private
three-Korean-word prototype. WAV reading, MFCC features, DTW, acceptance criteria,
and fixed response text use Stata/Mata only.

{title:Input and processing}
{p 4 4 2}
Input must be 16 kHz mono PCM16 WAV. The tested inputs are one-second-or-shorter
clips. A fixed short-time energy rule trims the clip with 50 ms padding, then
the existing 13-coefficient MFCC and weighted DTW functions score three classes.
The current model uses 15 templates per class from training speakers/sessions.
The per-file processing assumes at most one utterance; it does not count words
in a longer recording. Very short or low-level input returns {cmd:no_signal}.

{title:Outputs}
{p 4 4 2}
The command restores the current dataset and writes one output row. Existing
output is refused without {cmd:replace}. Variables include {cmd:d_yes},
{cmd:d_no}, {cmd:d_stop}, {cmd:candidate_id}, {cmd:candidate_label},
{cmd:recognized_label}, {cmd:accepted}, {cmd:decision_status}, and
{cmd:response_text}. Distances are not probabilities. The response is stored
as English text, without audio playback or command execution.

{p 4 4 2}
States are {cmd:accepted}, {cmd:distance_reject}, {cmd:ambiguous},
{cmd:uncalibrated}, and {cmd:no_signal}. The last gives segment 0, accepted 0,
and no candidate; it does not establish general background-noise robustness.

{title:Returned results}
{p 4 4 2}
{cmd:r(candidates)} is 0 or 1, {cmd:r(accepted)} is the number accepted,
and {cmd:r(cutoff)}, {cmd:r(minimum_gap)}, {cmd:r(saved)} describe the run.

{title:Example from the listening folder}
{phang2}{cmd:adopath ++ "`c(pwd)'/code"}{p_end}
{phang2}{cmd:wordlisten using "data/audio/e001.wav", model("models/public_calibrated.mmat") saving("my_prediction.dta")}{p_end}

{p 4 4 2}
Run {cmd:do replay.do} for all supplied final clips or {cmd:do rebuild_model.do}
for a new registration/calibration workspace. Neither is a new held-out test.
See README.txt, protocol_frozen_before_scoring.txt, and DATA_LICENSES.txt.
