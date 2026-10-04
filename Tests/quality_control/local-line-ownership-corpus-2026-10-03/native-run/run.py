#!/usr/bin/env python3
"""Frozen raw-corpus run, one invocation per score; never redetect a completed result."""
from pathlib import Path
import concurrent.futures, fcntl, hashlib, json, os, shutil, subprocess, time
ROOT=Path.cwd(); WORK=Path(__file__).resolve().parent; OUT=WORK/'candidate'
SNAP=ROOT/'.build/p34-local-ownership-v2-2026-10-03/candidate/Core'
ORIGINAL=ROOT/'.build/p34-local-ownership-v2-2026-10-03/candidate/permanent-run/runner'
BINARY=WORK/'analyzer'; BASE=ROOT/'.build/envelope-compatibility-corpus-2026-10-03/baseline'
read=lambda p:json.loads(Path(p).read_text())
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d):
 tmp=p.with_suffix(p.suffix+'.writing');tmp.write_text(json.dumps(d,indent=2)+'\n');tmp.replace(p)
def frozen(p,d):
 if p.exists():assert read(p)==d, f'Frozen binding changed: {p}'
 else:write(p,d)
lock=(WORK/'corpus.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
assert sha(ORIGINAL)=='79042a72be93269b3dc9a973ea8fe4e0e2cb9eadc5b711ad6e481f6d26d9a70c'
if not BINARY.exists():shutil.copy2(ORIGINAL,BINARY)
assert sha(BINARY)==sha(ORIGINAL)
assert sha(BASE/'status.json')=='be40d62c5a867c89b869e3cc61956199df9302df8d72d2cb0e8793e0e2ff365b'
assert sha(BASE/'manifest.json')=='31f80e02859e6528fa27f480d69b1f08f25dff7d4c56472acc5a57477681a0c6'
for rel,rec in read(BASE/'manifest.json')['files'].items():assert sha(BASE/rel)==rec['sha256'],rel
prior={r['id']:r for r in read(BASE/'status.json')['results']};corpus=read(ROOT/'Tests/quality_control/corpus.json')
assert len(prior)==len(corpus['scores'])==36
inputs=[]
for row in corpus['scores']:
 old=prior[row['id']];source=(ROOT/row['path']).resolve();profile=(ROOT/row['profilePath']).resolve();baseline=BASE/(row['id']+'.json')
 assert sha(source)==row['sha256']==old['sourceSHA256'] and sha(profile)==old['profileSHA256']
 assert sha(baseline)==old['outputSHA256'] and old['exitCode']==0 and old['rawPagesExactlyEqual']
 inputs.append(dict(id=row['id'],source=str(source),sourceSHA256=sha(source),profile=str(profile),profileSHA256=sha(profile),pages=row['pageCount'],baseline=str(baseline),baselineSHA256=sha(baseline)))
assert sum(r['pages'] for r in inputs)==1477
sourceHashes={str(p.relative_to(SNAP)):sha(p) for p in sorted(SNAP.rglob('*.swift'))}
for rel,digest in read(ROOT/'.build/p34-local-ownership-v2-2026-10-03/final-source-bindings-before-results.json').items():
 if rel.startswith('candidate/Core/'):assert sourceHashes[rel.removeprefix('candidate/Core/')]==digest
assert sourceHashes['Detection/NativeScorePageAnalyzer.swift']=='46ad9d2041991d4c9e2743519ef708d699c30b6846493abf70f7b94818d5d540'
assert sourceHashes['Detection/ScoreExtractionPlanner.swift']=='77212ba8218ba38b525e306ec40270268d44ccdcf3c0942585c790da94c2ace7'
binaryHash=sha(BINARY)
frozen(WORK/'inputs.json',inputs)
frozen(WORK/'build-binding.json',dict(binary=str(BINARY),binarySHA256=binaryHash,originalBinary=str(ORIGINAL),snapshot=str(SNAP),sourceHashes=sourceHashes,harness=str(ROOT/'.build/p34-local-ownership-v2-2026-10-03/permanent.swift'),harnessSHA256=sha(ROOT/'.build/p34-local-ownership-v2-2026-10-03/permanent.swift'),baselineManifestSHA256=sha(BASE/'manifest.json'),runnerSHA256=sha(__file__)))
frozen(WORK/'protocol-before-results.json',dict(scope='One fresh native raw-page analysis per original PDF. No saved rectification, name OCR, shared direction recognition, export, or production promotion.',scores=36,pages=1477,workers=2,sourceAndProfiles='Exact frozen corpus roster; initialized profiles retained including unresolved/zero-band inputs.',baseline='Production Native9f8 analyses replanned unchanged with planner772; not the private95 cleanup candidate.',candidate='Unchanged V2 measured local staff ownership; source masks, component bounds and original ownership kept where local evidence is unsupported or ambiguous.',comparison=['all staff and page geometry','component multisets and owner changes for every page including zero-plan pages','assignment identities/order and unresolved reasons','exact crop rectangles and every whole-foreign-staff relationship'],sourceReview='Only after canonical full comparison; coverage is not source-preservation certification.',resume='Completed hash-verified outputs skipped. Existing in-flight/failed outputs are never blindly re-executed; inspect durable PID/progress and original live session.',inputsSHA256=sha(WORK/'inputs.json'),buildBindingSHA256=sha(WORK/'build-binding.json')))
start=time.monotonic();results=[];pending=[]
for row in inputs:
 progress=OUT/(row['id']+'.progress.json');dest=OUT/(row['id']+'.json')
 if progress.exists():
  rec=read(progress)
  assert rec['status']=='complete' and rec['exitCode']==0, f'Existing incomplete invocation requires inspection, not duplicate execution: {progress}'
  assert sha(dest)==rec['outputSHA256'] and rec['binarySHA256']==binaryHash
  results.append({k:v for k,v in rec.items() if k!='status'})
 else:
  assert not dest.exists();pending.append(row)
write(WORK/'runner-state.json',dict(pid=os.getpid(),status='running',startedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),scheduled=len(pending),reused=len(results),binarySHA256=binaryHash,runnerSHA256=sha(__file__)))
def save_status():write(WORK/'status.json',dict(complete=len(results)==36,elapsedSeconds=time.monotonic()-start,results=sorted(results,key=lambda r:r['id'])))
save_status()
def run(row):
 dest=OUT/(row['id']+'.json');progress=OUT/(row['id']+'.progress.json');started=time.monotonic()
 assert sha(BINARY)==binaryHash
 with (OUT/(row['id']+'.log')).open('x') as log:
  p=subprocess.Popen([str(BINARY),'--inventory',row['source'],row['profile'],str(dest)],stdout=log,stderr=subprocess.STDOUT)
  write(progress,dict(status='running',pid=p.pid,runnerPID=os.getpid(),binarySHA256=binaryHash,sourceSHA256=row['sourceSHA256'],startedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())))
  code=p.wait()
 rec={**row,'exitCode':code,'seconds':time.monotonic()-started,'binarySHA256':binaryHash,'output':str(dest)}
 if code==0:
  data=read(dest);assert [p['pageIndex'] for p in data['pages']]==list(range(row['pages']))
  rec.update(outputSHA256=sha(dest),bands=sum(len(p['assignments']) for p in data['plan']['pages']))
 write(progress,{**rec,'status':'complete' if code==0 else 'error'})
 return rec
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 for future in concurrent.futures.as_completed([pool.submit(run,row) for row in pending]):
  rec=future.result();results.append(rec);save_status();print(json.dumps({k:rec[k] for k in ['id','exitCode','pages','seconds']}),flush=True)
assert len(results)==36 and all(r['exitCode']==0 for r in results)
assert sourceHashes=={str(p.relative_to(SNAP)):sha(p) for p in sorted(SNAP.rglob('*.swift'))} and sha(BINARY)==binaryHash
write(WORK/'runner-state.json',dict(pid=os.getpid(),status='complete',scores=36,pages=1477,seconds=time.monotonic()-start,binarySHA256=binaryHash,runnerSHA256=sha(__file__)))
print('COMPLETE: 36 scores / 1477 pages',flush=True)
