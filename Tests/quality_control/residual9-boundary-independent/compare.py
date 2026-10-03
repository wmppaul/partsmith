#!/usr/bin/env python3
"""Compare frozen source-envelope controls; failed baseline cases remain protected."""
import argparse, json
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('baseline',type=Path)
p.add_argument('candidate',type=Path)
p.add_argument('output',type=Path)
a=p.parse_args()
baseline=json.loads(a.baseline.read_text()); candidate=json.loads(a.candidate.read_text())
assert len(baseline)==len(candidate)==297
changed=[];worsened=[]
for old,new in zip(baseline,candidate):
    key={k:old[k] for k in ('kind','scale','tilt','bow')}
    assert all(new[k]==v for k,v in key.items())
    if old!=new:changed.append({'case':key,'before':old,'after':new})
    assert len(old['targets'])==len(new['targets'])==3
    for o,n in zip(old['targets'],new['targets']):
        assert o['owner']==n['owner'] and o['sourceEnvelope']==n['sourceEnvelope']
        source=o['sourceEnvelope']
        def intersection(crop):
            return [max(source[0],crop[0]),max(source[1],crop[1]),min(source[2],crop[2]),min(source[3],crop[3])]
        before=intersection(o['crop']);after=intersection(n['crop'])
        if any(after[i]>before[i]+1e-7 for i in (0,1)) or any(after[i]<before[i]-1e-7 for i in (2,3)):
            worsened.append({'case':key,'owner':o['owner'],'sourceEnvelope':source,'before':o['crop'],'after':n['crop']})
summary={
    'cases':len(baseline),
    'baselineFullPreservation':sum(x['allTargetsPreserved'] for x in baseline),
    'candidateFullPreservation':sum(x['allTargetsPreserved'] for x in candidate),
    'newFailures':sum(x['allTargetsPreserved'] and not y['allTargetsPreserved'] for x,y in zip(baseline,candidate)),
    'changedCases':len(changed),
    'changedCropCases':sum(x['bounds']!=y['bounds'] for x,y in zip(baseline,candidate)),
    'worsenedSourceEnvelopes':worsened,
    'wholeNeighborsBefore':sum(x['wholeNeighborCount'] for x in baseline),
    'wholeNeighborsAfter':sum(x['wholeNeighborCount'] for x in candidate)
}
a.output.write_text(json.dumps({'summary':summary,'changedCases':changed},indent=2)+'\n')
print(json.dumps(summary,indent=2))
