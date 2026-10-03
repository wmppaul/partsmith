from pathlib import Path
import json, subprocess, hashlib, concurrent.futures, time
import sys
MODE=sys.argv[1]
ROOT=Path.cwd(); OUT=ROOT/('.build/qc-low-resolution-preservation/corpus-'+MODE); AGG=ROOT/'.build/auto-qc/connector8-harmonic/corpus/aggregate.json'
data=json.loads(AGG.read_text()); executable=ROOT/('.build/qc-low-resolution-preservation/crop-quality-'+MODE)
OUT.mkdir(exist_ok=True)
def one(row):
 source=ROOT/row['path']; profile=ROOT/row['profilePath']; dest=OUT/(row['id']+'.json')
 assert hashlib.sha256(source.read_bytes()).hexdigest()==row['sourceSHA256'],row['id']
 assert hashlib.sha256(profile.read_bytes()).hexdigest()==row['profileSHA256'],row['id']
 started=time.time()
 with (OUT/(row['id']+'.log')).open('w') as f:
  result=subprocess.run([str(executable),'--inventory',str(source),str(profile),str(dest)],stdout=f,stderr=subprocess.STDOUT)
 summary={'id':row['id'],'exitCode':result.returncode,'elapsedSeconds':round(time.time()-started,3),'pages':row['pageCount'],'output':str(dest),'sourceSHA256':row['sourceSHA256'],'profileSHA256':row['profileSHA256']}
 print(json.dumps(summary),flush=True);return summary
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for result in pool.map(one,data['scores']):
  results.append(result);(OUT/'run-status.json').write_text(json.dumps({'executableSHA256':hashlib.sha256(executable.read_bytes()).hexdigest(),'results':results,'complete':len(results)==len(data['scores'])},indent=2)+'\n')
