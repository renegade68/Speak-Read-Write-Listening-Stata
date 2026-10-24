Public audio word matching in Stata/Mata
wordlisten 0.2.0 — prepared 25 October 2026

This experimental command matches one isolated audio clip against templates
for yes, no, and stop. It uses public Speech Commands v0.02 recordings; no
experimenter's private voice recordings or private-voice models are included.
WAV decoding, MFCC features, DTW, decisions, and fixed response text run in
Stata/Mata. No TensorFlow installation, pretrained recognizer, Python runtime,
cloud speech service, or network connection is needed to run the supplied demo.

QUICK START

Download/extract the repository ZIP. In Stata, substitute your local path:

    cd "/your/path/Speak-Read-Write-Listening-Stata/listening"
    do replay.do

Expected: 95 isolated clips processed, 35 accepted. Of those accepts, 27 are
correct targets, 5 are wrong target labels, and 3 are out-of-vocabulary words
wrongly accepted. Rejection is part of the experiment, not a missing output.
Results go to replay_outputs/evaluation_predictions.dta and .csv. Existing
prediction files are refused. The current dataset and original results are
preserved. Use a fresh extraction for another full replay.

For one supplied clip (the result may be rejection):

    adopath ++ "`c(pwd)'/code"
    wordlisten using "data/audio/e001.wav", model("models/public_calibrated.mmat") saving("my_prediction.dta")
    return list

Inspect the saved output without losing your current dataset:

    preserve
    use "my_prediction.dta", clear
    list recognized_label decision_status response_text, noobs
    restore

Examples of response_text are "Recognized yes." and "Word not recognized.
Please try again." These strings are stored, not spoken or executed. An input
must be 16 kHz mono PCM16 WAV containing at most one isolated utterance.
This version does not segment a long conversation or record a microphone.
The existing net install pngread instructions install only the PNG package;
use the repository ZIP for this listening experiment.

FIRST FROZEN EVALUATION

Target    Clips   Correct accept   Wrong accept   Rejected   Nearest class correct
yes       20      8                3              9          14
no        20      8                1              11         16
stop      20      11               1              8          17
Total     60      27               5              28         47

Other words: 27/30 rejected, 3 false accepts (off twice, dog once).
Synthetic pink noise: five one-second slices, all rejected.
These noise clips share one source recording and are not five independent
environments. They do not establish performance on real ambient silence/noise.

Nearest-class accuracy is 47/60 (78.3%) before rejection. Correct target
acceptance is 27/60 (45.0%) after the fixed criteria. These are different measures;
the former does not mean that 78.3% were correctly accepted. The rejection
rule trades target coverage for fewer false accepts and still makes errors.
This is a small predetermined subset, not the full Speech Commands benchmark.
There was no retuning or sample substitution after viewing final results.

DATA AND SPLITS

Source: Google Speech Commands v0.02, CC BY 4.0; see DATA_LICENSES.txt.
Subset selection uses a fixed SHA256 ordering of original filenames, one clip
per speaker/session within each word and split. Official validation/testing
lists define the stages. Selected speaker/session ID sets are disjoint:
44 registration IDs, 38 calibration IDs, and 69 evaluation IDs.
The IDs represent the source dataset's speaker/session grouping, not a separately
verified identity for each person. One ID can supply different word classes.

Registration: 45 clips, 15 each for yes/no/stop, all usable templates.
Calibration: 30 target clips, 15 other words (go/up/down), 5 white-noise slices.
Evaluation: 60 targets, 30 other words (left/right/on/off/cat/dog), 5 pink-noise slices.
Total: 190 WAV files. The 180 word WAVs are byte-identical to source files.
The ten noise WAVs are exact one-second sample slices with new WAV headers;
there is no resampling, amplitude change, or noise augmentation.

data/selection_manifest.csv provides original relative paths, hashes, labels,
sample statistics, split assignments, and noise slice positions. Opaque local
filenames do not encode the word. data/*_inputs.csv contains paths and IDs only;
the recognition command never receives truth. data/truth.csv is joined after
prediction. Labels are from the source corpus, not new human transcription.

METHOD

The isolated clip is trimmed with a fixed 20 ms RMS / 10 ms step rule, selecting
the first and last frames above max(0.15*peak RMS, 0.0003), with 50 ms padding.
It then uses mean removal, peak normalization, pre-emphasis, 25 ms Hamming
windows, a 512-point FFT, 26 mel filters, and 13 MFCC coefficients excluding c0.
Symmetric weighted DTW compares each query to 15 templates per class.

Accept iff best class distance <= 7.830564382903245 AND
second-best class distance - best distance > 1.449988721599524.
Distances and gaps are not probabilities. Criteria were selected only on
calibration data by a predeclared balanced-score grid and deterministic tiebreak.
The calibrated objective was 0.70: 18/30 correct target accepts and 16/20
non-target rejects. The parameters and code were then frozen before evaluation.
protocol_frozen_before_scoring.txt contains the complete procedure recorded
before any scoring; models/frozen_before_evaluation.json is the later hash record.

REBUILD

    do rebuild_model.do

This creates a new rebuild_01 folder and refuses if it already exists. It builds
templates, scores calibration clips, and selects thresholds there. It does not
use evaluation audio for fitting or alter the distributed model/first results.
Rebuild and replay are reproducibility checks, not additional held-out tests.
All data needed are already in this ZIP. The full 2.43 GB source archive is
needed only if you independently repeat source selection with prepare_public_data.py
in a fresh working copy without an existing data/ folder.

VALIDATION AND LIMITS

Tested with Stata/MP 16.1 console on macOS Apple Silicon. Other versions and
platforms are not validated. Development checks verified clip boundaries,
nearest-class decisions, the calibration grid/tiebreak, and 135 independently
computed template distances (maximum class-score difference 8.88e-16).
Command checks covered data restoration, overwrite refusal, and a digital-zero
no_signal case. All 208 frozen file hashes matched after first evaluation.
Final decisions, response strings, labels, and aggregates were independently
checked. Python was used to prepare/audit data and package files, not for
recognition. Numerical precision and cross-platform behavior remain testable.

The model is a simple template baseline. The observed rejection/misclassification
rates limit its usefulness as a voice interface. It is not an unrestricted
transcriber, a pretrained neural speech model, or a conversational agent.

FILES

code/                Native runtime and help
data/                Public selected WAVs, manifests, labels, and source notices
models/              Public templates, calibrated model, and pre-evaluation hashes
results/             Preserved calibration/final outputs, audit, and figures
01..05 do-files      Original preparation/scoring/calibration/evaluation/plot steps
replay.do            Re-run fixed-model predictions into a new output location
rebuild_model.do     Rebuild in a new workspace
prepare_public_data.py  Deterministic source-selection script (Python, preparation only)
validation/          Selected checks and reports; machine-specific logs excluded
SHA256SUMS.txt        Distribution hashes, excluding the checksum file itself

LICENSES

Software uses the existing project AFL-3.0 license. The selected source audio,
its notices, and the audio-derived template models are separately marked
CC BY 4.0 in DATA_LICENSES.txt. Do not treat the software license as replacing
the dataset terms. The source license and notices are included verbatim.

References:
https://arxiv.org/abs/1804.03209
https://www.tensorflow.org/datasets/catalog/speech_commands
https://www.stata.com/manuals/m-5fft.pdf
https://www.stata.com/manuals/m-5fopen.pdf
