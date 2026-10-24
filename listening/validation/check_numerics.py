"""Independent audit before final evaluation; uses only public calibration data."""
from pathlib import Path
from array import array
import csv, hashlib, json, math, sys, wave

ROOT=Path(__file__).resolve().parents[1]
def rows(p):
    with (ROOT/p).open(newline='') as f:return list(csv.DictReader(f))
def num(x):return float(x) if x not in ('','.') else math.inf
pred=rows('results/calibration_uncalibrated.csv')
truth={r['sample_id']:r for r in rows('data/truth.csv')}
assert len(pred)==50 and all(truth[r['sample_id']]['stage']=='calibration' for r in pred)
for r in pred:
    with wave.open(str(ROOT/'data/audio'/(r['sample_id']+'.wav')),'rb') as w:
        a=array('h',w.readframes(w.getnframes()))
    if sys.byteorder!='little':a.byteswap()
    rms=[math.sqrt(sum((v/32768)**2 for v in a[p:p+320])/320) for p in range(0,len(a)-319,160)]
    threshold=max(.15*max(rms),.0003)
    active=[i for i,v in enumerate(rms) if v>=threshold]
    if not active:assert int(float(r['segment']))==0
    else:
        start=max(0,active[0]*160-800)
        end=min(len(a),active[-1]*160+320+800)
        assert abs(float(r['start_sec'])-start/16000)<1e-12
        assert abs(float(r['end_sec'])-end/16000)<1e-12
        scores=[float(r[k]) for k in ['d_yes','d_no','d_stop']]
        order=sorted(range(3),key=lambda k:(scores[k],k))
        assert int(float(r['candidate_id']))==order[0]+1
        assert abs(float(r['distance_gap'])-(scores[order[1]]-scores[order[0]]))<1e-12
cuts=sorted({0,*[num(r['best_distance']) for r in pred if num(r['best_distance'])<math.inf]})
gaps=sorted({0,*[num(r['distance_gap']) for r in pred if num(r['distance_gap'])<math.inf]})
grid=[]
for cut in cuts:
    for gap in gaps:
        correct=reject=false=0
        for r in pred:
            y=int(truth[r['sample_id']]['class_id'])
            accept=num(r['best_distance'])<=cut and gap<num(r['distance_gap'])<math.inf
            c=num(r['candidate_id'])
            correct+=accept and y>0 and c==y
            reject+=not accept and y==0
            false+=accept and (y==0 or c!=y)
        grid.append((-(20*correct+30*reject),false,cut,-gap,correct,reject))
best=min(grid);selected=rows('results/calibration_selection.csv')[0]
assert abs(best[2]-float(selected['cutoff']))<1e-12
assert abs(-best[3]-float(selected['minimum_gap']))<1e-12
assert best[4]==int(selected['correct_accept']) and best[5]==int(selected['negative_reject'])
def matrix(p):
    with (ROOT/p).open() as f:
        reader=csv.reader(f);next(reader);return [[float(v) for v in row] for row in reader]
bank=matrix('validation/template_features.csv')
index=matrix('validation/template_index.csv')
assert len(index)==45
assert [sum(int(r[2])==k for r in index) for k in (1,2,3)]==[15,15,15]
def dtw(A,B):
    n,m=len(A),len(B);radius=max(.25,1/n,1/m)
    previous=[0]+[math.inf]*m
    for i,a in enumerate(A,1):
        current=[math.inf]*(m+1)
        for j,b in enumerate(B,1):
            if abs(i/n-j/m)<=radius+1e-12:
                cost=sum((x-y)**2 for x,y in zip(a,b))/13
                current[j]=min(previous[j-1]+2*cost,previous[j]+cost,current[j-1]+cost)
        previous=current
    return previous[m]/(n+m)
max_error=0
for sid in ['c001','c011','c021']:
    F=matrix('validation/'+sid+'_features.csv');scores=[math.inf]*3
    for a,b,k in index:
        scores[int(k)-1]=min(scores[int(k)-1],dtw(F,bank[int(a)-1:int(b)]))
    expected=next(r for r in pred if r['sample_id']==sid)
    max_error=max(max_error,*[abs(x-float(expected[k])) for x,k in zip(scores,['d_yes','d_no','d_stop'])])
assert max_error<1e-10
result={'status':'PASS','calibration_clips_audited':50,'template_count':45,
        'independent_template_distances':135,'maximum_class_score_error':max_error,
        'calibration_grid_rule_and_tiebreak_match':True,
        'cutoff':best[2],'minimum_gap':-best[3],
        'correct_target_accepts':best[4],'negative_rejects':best[5],
        'final_evaluation_scored':False}
(ROOT/'validation/pre_evaluation_audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
