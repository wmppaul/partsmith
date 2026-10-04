from pathlib import Path
import argparse, json, hashlib, subprocess, concurrent.futures, time, fcntl, os
parser=argparse.ArgumentParser();parser.add_argument('--binary',type=Path,required=True);parser.add_argument('--snapshot',type=Path,required=True);args=parser.parse_args()
root=Path.cwd();work=root/'.build/monotone-line-corpus-2026-10-03';binary=args.binary.resolve();snapshot=args.snapshot.resolve();out=work/'candidate';out.mkdir(exist_ok=True)
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):
 t=p.with_suffix(p.suffix+'.writing');t.write_text(json.dumps(d,indent=2)+'\n');t.replace(p)
lock=(work/'corpus.lock').open('w');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
assert not list(out.glob('*.json')),'Refusing to overwrite existing results'
corpus=json.loads((root/'Tests/quality_control/corpus.json').read_text())
previous=json.loads((root/'.build/combined-corpus-2026-10-03/inputs.json').read_text());byid={v['id']:v for v in previous}
prior_status=json.loads((root/'.build/combined-corpus-2026-10-03/status.json').read_text());assert prior_status['complete'];prior_byid={v['id']:v for v in prior_status['results']}
actual={p.resolve() for folder in ['sample_scores','Tests/extraction/sources'] for p in (root/folder).rglob('*.pdf')}
assert actual=={(root/s['path']).resolve() for s in corpus['scores']}
inputs=[]
for s in corpus['scores']:
 source=root/s['path'];profile=root/s['profilePath'];old=byid[s['id']]
 assert sha(source)==s['sha256']==old['sourceSHA256'] and sha(profile)==old['profileSHA256']
 baseline=root/'.build/combined-corpus-2026-10-03/candidate'/(s['id']+'.json')
 assert baseline.exists() and sha(baseline)==prior_byid[s['id']]['outputSHA256']
 assert prior_byid[s['id']]['exitCode']==0
 inputs.append({'id':s['id'],'source':str(source),'sourceSHA256':sha(source),'profile':str(profile),'profileSHA256':sha(profile),'pages':s['pageCount'],'baseline':str(baseline),'baselineSHA256':sha(baseline)})
source_hashes={str(p.relative_to(snapshot)):sha(p) for p in sorted(snapshot.rglob('*.swift'))}
assert source_hashes
binary_hash=sha(binary)
write(work/'inputs.json',inputs);write(work/'build-binding.json',{'binary':str(binary),'binarySHA256':binary_hash,'snapshot':str(snapshot),'sourceHashes':source_hashes})
def run(row):
 dest=out/(row['id']+'.json');start=time.monotonic()
 assert sha(binary)==binary_hash
 with (out/(row['id']+'.log')).open('w') as log:
  p=subprocess.Popen([str(binary),'--inventory',row['source'],row['profile'],str(dest)],stdout=log,stderr=subprocess.STDOUT)
  write(out/(row['id']+'.progress.json'),{'status':'running','pid':p.pid,'binarySHA256':binary_hash,'sourceSHA256':row['sourceSHA256']})
  code=p.wait()
 result={**row,'exitCode':code,'seconds':time.monotonic()-start,'binarySHA256':binary_hash,'output':str(dest)}
 if code==0:
  data=json.loads(dest.read_text());assert [p['pageIndex'] for p in data['pages']]==list(range(row['pages']))
  result['outputSHA256']=sha(dest);result['bands']=sum(len(p['assignments']) for p in data['plan']['pages'])
 write(out/(row['id']+'.progress.json'),{**result,'status':'complete' if code==0 else 'error'})
 return result
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 futures=[pool.submit(run,row) for row in inputs]
 for future in concurrent.futures.as_completed(futures):
  result=future.result();results.append(result)
  write(work/'status.json',{'complete':len(results)==len(inputs),'results':results})
  print(json.dumps({k:result[k] for k in ['id','exitCode','pages','seconds']}),flush=True)
assert len(results)==36 and all(r['exitCode']==0 for r in results)
assert source_hashes=={str(p.relative_to(snapshot)):sha(p) for p in sorted(snapshot.rglob('*.swift'))}
assert sha(binary)==binary_hash
