from pathlib import Path
import json, hashlib, subprocess, concurrent.futures, time, fcntl

root=Path.cwd(); work=root/'.build/residual9-boundary-2026-10-03'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,data):
    tmp=p.with_suffix(p.suffix+'.writing');tmp.write_text(json.dumps(data,indent=2)+'\n');tmp.replace(p)
lock=(work/'corpus.lock').open('w');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
corpus=json.loads((root/'Tests/quality_control/corpus.json').read_text())
previous=json.loads((root/'.build/auto-qc/connector8-harmonic/corpus/aggregate.json').read_text())
old={s['id']:s for s in previous['scores']}
actual={p.resolve() for folder in ['sample_scores','Tests/extraction/sources'] for p in (root/folder).rglob('*.pdf')}
listed={(root/s['path']).resolve() for s in corpus['scores']}
assert actual==listed,(actual-listed,listed-actual)
inputs=[]
for s in corpus['scores']:
    source=root/s['path'];profile=root/s['profilePath']
    assert sha(source)==s['sha256']==old[s['id']]['sourceSHA256']
    assert sha(profile)==old[s['id']]['profileSHA256']
    inputs.append({'id':s['id'],'source':str(source),'sourceSHA256':sha(source),'profile':str(profile),'profileSHA256':sha(profile),'pages':s['pageCount']})
write(work/'corpus-inputs.json',inputs)
for variant in ['baseline','candidate']:
    out=work/variant/'corpus';out.mkdir(exist_ok=True)
    assert not list(out.glob('*.json')),'Fresh run refuses to overwrite completed outputs'
    snapshot=work/variant
    for rel,digest in json.loads((snapshot/'source-hashes.json').read_text()).items(): assert sha(snapshot/rel)==digest,rel
def run(job):
    variant,row=job;binary=work/variant/'existing755';out=work/variant/'corpus';dest=out/(row['id']+'.json')
    start=time.monotonic()
    with (out/(row['id']+'.log')).open('w') as log:
        p=subprocess.Popen([str(binary),'--inventory',row['source'],row['profile'],str(dest)],stdout=log,stderr=subprocess.STDOUT)
        write(out/(row['id']+'.progress.json'),{'pid':p.pid,'binary':str(binary),'binarySHA256':sha(binary),'source':row['source'],'status':'running'})
        code=p.wait()
    result={**row,'variant':variant,'exitCode':code,'seconds':time.monotonic()-start,'binarySHA256':sha(binary),'output':str(dest)}
    if code==0:
        data=json.loads(dest.read_text())
        assert [p['pageIndex'] for p in data['pages']]==list(range(row['pages']))
        result['outputSHA256']=sha(dest)
        result['bands']=sum(len(p['assignments']) for p in data['plan']['pages'])
    write(out/(row['id']+'.progress.json'),{**result,'status':'complete' if code==0 else 'error'})
    return result
results=[]
jobs=[(v,s) for s in inputs for v in ['baseline','candidate']]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    for result in pool.map(run,jobs):
        results.append(result)
        write(work/'corpus-status.json',{'complete':len(results)==len(jobs),'results':results})
        print(json.dumps({k:result[k] for k in ['variant','id','exitCode','pages','seconds']}),flush=True)
assert len(results)==72 and all(r['exitCode']==0 for r in results)
