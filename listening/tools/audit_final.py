from pathlib import Path
import csv, hashlib, json, math
ROOT=Path(__file__).resolve().parents[1]
def read(p):
    with (ROOT/p).open(newline='') as f:return list(csv.DictReader(f))
freeze=json.loads((ROOT/'models/frozen_before_evaluation.json').read_text())
for name,digest in freeze['sha256'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
if (ROOT/'04_evaluate_frozen.log').exists():
    assert 'FIRST_PUBLIC_EVALUATION_COMPLETE\n' in (ROOT/'04_evaluate_frozen.log').read_text()
pred=read('results/evaluation_predictions.csv')
truth={r['sample_id']:r for r in read('data/truth.csv')}
scored={r['sample_id']:r for r in read('results/evaluation_scored.csv')}
selection=read('results/calibration_selection.csv')[0]
cut,gap=float(selection['cutoff']),float(selection['minimum_gap'])
keys=['known_total','correct_accept','wrong_accept','known_reject','nearest_correct','other_total','other_reject','other_accept','noise_total','noise_reject','noise_accept','no_signal']
totals=dict.fromkeys(keys,0);by_word={};confusion={}
assert len(pred)==95 and 'label' not in pred[0] and 'class_id' not in pred[0]
for r in pred:
    t=truth[r['sample_id']];y=int(t['class_id']);kind=t['kind'];label=t['label']
    assert t['stage']=='evaluation'
    assert (float(r['cutoff']),float(r['minimum_gap']))==(cut,gap)
    a=int(float(r['accepted']));c=int(float(r['candidate_id'])) if r['candidate_id'] else 0
    if r['decision_status']=='no_signal':
        assert a==0 and r['recognized_label']=='no signal'
        response='No usable signal found.'
        totals['no_signal']+=1
    else:
        s=[float(r[k]) for k in ['d_yes','d_no','d_stop']]
        ix=sorted(range(3),key=lambda j:(s[j],j))
        assert c==ix[0]+1
        assert abs(float(r['best_distance'])-s[ix[0]])<1e-12
        assert abs(float(r['distance_gap'])-(s[ix[1]]-s[ix[0]]))<1e-12
        assert a==int(s[ix[0]]<=cut and s[ix[1]]-s[ix[0]]>gap)
        expected_label=['yes','no','stop'][c-1] if a else 'unrecognized'
        assert r['recognized_label']==expected_label
        assert r['decision_status']==('accepted' if a else 'distance_reject' if s[ix[0]]>cut else 'ambiguous')
        response='Recognized '+expected_label+'.' if a else 'Word not recognized. Please try again.'
    assert r['response_text']==response
    for k,v in r.items():assert scored[r['sample_id']][k]==v
    assert scored[r['sample_id']]['label']==label
    by_word.setdefault(label,dict(total=0,correct_accept=0,wrong_accept=0,reject=0,nearest_correct=0))
    b=by_word[label];b['total']+=1;b['reject']+=not a
    if y:
        totals['known_total']+=1;totals['nearest_correct']+=c==y
        b['nearest_correct']+=c==y
        if not a:totals['known_reject']+=1
        elif c==y:totals['correct_accept']+=1;b['correct_accept']+=1
        else:totals['wrong_accept']+=1;b['wrong_accept']+=1
    else:
        prefix='other' if kind=='other_word' else 'noise'
        totals[prefix+'_total']+=1;totals[prefix+'_reject']+=not a;totals[prefix+'_accept']+=a
        b['wrong_accept']+=a
    confusion.setdefault(label,{})[r['recognized_label']]=confusion.setdefault(label,{}).get(r['recognized_label'],0)+1
expected={k:int(v) for k,v in read('results/evaluation_summary.csv')[0].items()}
assert totals==expected
report={'status':'PASS','first_public_evaluation_preserved':True,'model_refitted_after_evaluation':False,
        'frozen_hashes_match_after_evaluation':len(freeze['sha256']),
        'truth_source':'Speech Commands source directory labels; attached after prediction',
        'personal_voice_or_model_used':False,'metrics':totals,'per_word':by_word,'confusion':confusion,
        'cutoff':cut,'minimum_gap':gap,'target_nearest_class_accuracy':totals['nearest_correct']/60,
        'target_correct_accept_rate':totals['correct_accept']/60,'other_word_reject_rate':totals['other_reject']/30}
(ROOT/'results/final_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
