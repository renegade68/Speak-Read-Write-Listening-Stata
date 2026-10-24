"""Select by source filename only, then copy licensed PCM inputs; no recognition."""
from pathlib import Path, PurePosixPath
import csv, hashlib, io, json, sys, tarfile, wave
from array import array

ROOT = Path(__file__).resolve().parent
ARCHIVE = Path(sys.argv[1]) if len(sys.argv)>1 else Path('speech_commands_v0.02.tar.gz')
SHA = 'af14739ee7dc311471de98f5f9d2c9191b18aedfe957f4a6ff791c709868ff58'
SEED = 'mata-public-20261025|'
DATA = ROOT/'data'
if DATA.exists(): raise SystemExit('Refusing to replace selected data.')
digest=hashlib.sha256()
with ARCHIVE.open('rb') as f:
    for chunk in iter(lambda:f.read(8*1024*1024),b''): digest.update(chunk)
assert ARCHIVE.stat().st_size==2428923189 and digest.hexdigest()==SHA
print('PASS official archive size and SHA256',flush=True)
paths=[]; metadata={}
def clean(name):
    p=PurePosixPath(name)
    assert not p.is_absolute() and '..' not in p.parts
    return str(p)
with tarfile.open(ARCHIVE,'r|gz') as t:
    for m in t:
        if not m.isfile():continue
        name=clean(m.name)
        if name.endswith('.wav'):paths.append(name)
        elif name in ['validation_list.txt','testing_list.txt','LICENSE','README.md','_background_noise_/README.md']:
            metadata[name]=t.extractfile(m).read()
valid=set(metadata['validation_list.txt'].decode().splitlines())
test=set(metadata['testing_list.txt'].decode().splitlines())
assert not valid & test
def split(p):return 'calibration' if p in valid else 'evaluation' if p in test else 'registration'
def speaker(p):return Path(p).name.split('_nohash_')[0]
plan={'registration':{'yes':15,'no':15,'stop':15},
      'calibration':{'yes':10,'no':10,'stop':10,'go':5,'up':5,'down':5},
      'evaluation':{'yes':20,'no':20,'stop':20,'left':5,'right':5,'on':5,'off':5,'cat':5,'dog':5}}
rows=[]
for stage,counts in plan.items():
    for word,count in counts.items():
        pool=[p for p in paths if p.startswith(word+'/') and split(p)==stage]
        pool.sort(key=lambda p:hashlib.sha256((SEED+p).encode()).hexdigest())
        seen=set();chosen=[]
        for p in pool:
            sid=speaker(p)
            if sid in seen:continue
            seen.add(sid);chosen.append(p)
            if len(chosen)==count:break
        assert len(chosen)==count
        for p in chosen:
            rows.append(dict(stage=stage,source_path=p,source_split={'registration':'training','calibration':'validation','evaluation':'testing'}[stage],
                             label=word,class_id={'yes':1,'no':2,'stop':3}.get(word,0),kind='target' if word in ['yes','no','stop'] else 'other_word',
                             speaker_id=speaker(p),source_start_sample=0,source_end_sample=-1))
    if stage!='registration':
        source='_background_noise_/'+('white_noise.wav' if stage=='calibration' else 'pink_noise.wav')
        assert source in paths
        for i in range(5):
            rows.append(dict(stage=stage,source_path=source,source_split='background_source',label=Path(source).stem,
                             class_id=0,kind='synthetic_noise',speaker_id='',source_start_sample=i*16000,source_end_sample=(i+1)*16000))
sets={stage:{r['speaker_id'] for r in rows if r['stage']==stage and r['speaker_id']} for stage in plan}
assert not sets['registration']&sets['calibration']
assert not sets['registration']&sets['evaluation']
assert not sets['calibration']&sets['evaluation']
(DATA/'audio').mkdir(parents=True)
(DATA/'source_notices').mkdir()
for name,body in metadata.items():
    if name in ['LICENSE','README.md','_background_noise_/README.md']:
        (DATA/'source_notices'/name.replace('/','_')).write_bytes(body)
needed={r['source_path'] for r in rows}; blobs={}
with tarfile.open(ARCHIVE,'r|gz') as t:
    for m in t:
        if m.isfile() and clean(m.name) in needed:
            blobs[clean(m.name)]=t.extractfile(m).read()
assert set(blobs)==needed
stage_indices={s:0 for s in plan}
for row in rows:
    stage_indices[row['stage']]+=1
    sid={'registration':'r','calibration':'c','evaluation':'e'}[row['stage']]+f"{stage_indices[row['stage']]:03d}"
    row['sample_id']=sid;row['audio_path']='data/audio/'+sid+'.wav'
    raw=blobs[row['source_path']]
    row['source_sha256']=hashlib.sha256(raw).hexdigest()
    with wave.open(io.BytesIO(raw),'rb') as w:
        assert (w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getcomptype())==(1,2,16000,'NONE')
        pcm=w.readframes(w.getnframes())
    if row['kind']=='synthetic_noise':
        pcm=pcm[2*row['source_start_sample']:2*row['source_end_sample']]
        buff=io.BytesIO()
        with wave.open(buff,'wb') as w:
            w.setparams((1,2,16000,0,'NONE','not compressed'));w.writeframes(pcm)
        output=buff.getvalue()
    else:
        output=raw;row['source_end_sample']=len(pcm)//2
    vals=array('h',pcm)
    if sys.byteorder!='little':vals.byteswap()
    row.update(frames=len(vals),sample_rate=16000,peak=max(abs(v) for v in vals)/32768,
               clipped_samples=sum(v in (-32768,32767) for v in vals),audio_sha256=hashlib.sha256(output).hexdigest())
    (ROOT/row['audio_path']).write_bytes(output)
fields=['sample_id','stage','audio_path','label','class_id','kind','speaker_id','source_split','source_path','source_start_sample','source_end_sample','frames','sample_rate','peak','clipped_samples','source_sha256','audio_sha256']
with (DATA/'selection_manifest.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
for stage in plan:
    with (DATA/(stage+'_inputs.csv')).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['sample_id','audio_path']);w.writeheader()
        w.writerows({k:r[k] for k in w.fieldnames} for r in rows if r['stage']==stage)
with (DATA/'truth.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=['sample_id','stage','label','class_id','kind']);w.writeheader()
    w.writerows({k:r[k] for k in w.fieldnames} for r in rows)
record={'dataset':'Google Speech Commands v0.02','archive_sha256':SHA,'archive_bytes':ARCHIVE.stat().st_size,
        'license':'CC-BY-4.0','url':'https://storage.googleapis.com/download.tensorflow.org/data/speech_commands_v0.02.tar.gz',
        'selection_seed':SEED,'stage_counts':stage_indices,'stage_speaker_session_counts':{s:len(v) for s,v in sets.items()},
        'speaker_session_sets_disjoint':True,'word_wav_bytes_unchanged':True,
        'source_list_sha256':{k:hashlib.sha256(metadata[k]).hexdigest() for k in ['validation_list.txt','testing_list.txt']},
        'protocol_sha256':hashlib.sha256((ROOT/'protocol_frozen_before_scoring.txt').read_bytes()).hexdigest(),
        'selection_manifest_sha256':hashlib.sha256((DATA/'selection_manifest.csv').read_bytes()).hexdigest()}
(DATA/'provenance.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2),flush=True)
