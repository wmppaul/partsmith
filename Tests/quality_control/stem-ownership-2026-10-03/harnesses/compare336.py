import json,sys
from pathlib import Path
candidate=Path(sys.argv[1]);output=Path(sys.argv[2]);baseline=Path('Tests/quality_control/residual9-boundary-independent/candidate-v2/336-results.json')
b=json.loads(baseline.read_text());c=json.loads(candidate.read_text());assert len(b)==len(c)==336
changed=[];worse=[]
for o,n in zip(b,c):
 assert all(o[k]==n[k] for k in ['headStyle','scale','tilt','inset','sourceEnvelope'])
 if o!=n:changed.append({'before':o,'after':n})
 for i,(a,z) in enumerate(zip(o['bounds'],n['bounds'])):
  e=o['sourceEnvelope'];x=[max(e[1],a[0]),min(e[3],a[1])];y=[max(e[1],z[0]),min(e[3],z[1])]
  if y[0]>x[0]+1e-7 or y[1]<x[1]-1e-7:worse.append({'case':{k:o[k] for k in ['headStyle','scale','tilt','inset']},'owner':i,'before':a,'after':z,'envelope':e})
s={'cases':336,'baselinePreserved':sum(x['bothCropsPreserveSource'] for x in b),'candidatePreserved':sum(x['bothCropsPreserveSource'] for x in c),'changed':len(changed),'worsenedSourceEnvelopes':len(worse)}
output.write_text(json.dumps({'summary':s,'worsenedSourceEnvelopes':worse,'changed':changed},indent=2)+'\n');print(s)
