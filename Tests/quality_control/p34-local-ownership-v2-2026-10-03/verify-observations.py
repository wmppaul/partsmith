from pathlib import Path
import hashlib, json, math, collections
import numpy as np

W=Path('.build/p34-local-ownership-v2-2026-10-03')
load=lambda p:json.loads(Path(p).read_text())
counter=lambda rows:collections.Counter(json.dumps(x,sort_keys=True) for x in rows)
candidate=load(W/'candidate/one-page-run/results.json')
observed=load(W/'observed/one-page-run/results.json')
assert counter(candidate.pop('inkComponents'))==counter(observed.pop('inkComponents'))
assert candidate==observed
assert load(W/'candidate/one-page-run/plan.json')==load(W/'observed/one-page-run/plan.json')
candidate164=load(W/'candidate/controls297-pixels-run/results.json')[164]
observed164=load(W/'observed/case164-observer-run/results.json')[0]
assert counter(candidate164.pop('components'))==counter(observed164.pop('components'))
assert candidate164==observed164
records=[]
for case in ['p34','case164']:
    p=W/'observations'/case/'musical-observations.json'
    observation=load(p)
    raw=(p.parent/'musical-gray.bin').read_bytes()
    width,height=observation['width'],observation['height']
    gray=np.frombuffer(raw,dtype=np.uint8).reshape(height,width)
    original=gray<190
    tested=[]
    for row in observation['cores']:
        staff=row['staffIndex'];lines=observation['lines'][staff]
        space=observation['spaces'][staff];slope=observation['slope']
        radius=max(1,math.floor(space*.49));xs=range(row['lo'],row['hi'])
        supports=[];accepted=[]
        for shift in range(-radius,radius+1):
            counts=[]
            for line in lines:
                n=0
                for x in xs:
                    center=x-width/2
                    y=math.floor((line+slope*center)+shift+.5)
                    if any(0<=y+dy<height and original[y+dy,x] for dy in [-1,0,1]):n+=1
                counts.append(n)
            if all(n>=(row['hi']-row['lo'])*.8 for n in counts):accepted.append(shift)
            supports.append({'shift':shift,'lineSupportCounts':counts})
        assert accepted==row['acceptedShifts'],(case,row,accepted)
        expected=[]
        if accepted:
            delta=slope*(row['x']-width/2)
            expected=[lines[0]+delta+accepted[0]-1,lines[4]+delta+accepted[-1]+1]
        assert len(expected)==len(row['coreBounds'])
        assert all(abs(a-b)<1e-9 for a,b in zip(expected,row['coreBounds']))
        tested.append({**row,'independentSupport':supports})
    records.append({'case':case,'sourceGraySHA256':hashlib.sha256(raw).hexdigest(),
        'allLoggedCertificatesIndependentlyReproduced':True,'certificates':tested})

p34=records[0]['certificates']
f=[r for r in p34 if r['staffIndex']==15 and 1206<=r['x']<1238]
assert len(f)==32 and all(r['coreBounds'][0]>2384 for r in f)
case164=records[1]['certificates']
assert len(case164)==1
assert case164[0]['coreBounds'][0]<=190 and case164[0]['coreBounds'][1]>=114
summary={'observerSemanticOutputsExactlyEqualFrozenCandidates':True,
    'independentlyReproducedLocalCertificates':sum(len(r['certificates']) for r in records),
    'p34FAll32ColumnsHaveMeasuredFiveLineSeparation':True,
    'p34FMeasuredCelloCoreTopRange':[min(r['coreBounds'][0] for r in f),max(r['coreBounds'][0] for r in f)],
    'p34FComponentBottom':2384,'case164NominalUpperOwnerRetainedByActualLocalCoreContact':True,
    'case164FirstLocalCore':case164[0],
    'limits':'Numeric reproduction establishes what this bounded source certificate measured. It does not establish a universal musical ownership theorem or certify all source notes.'}
(W/'local-evidence-verification.json').write_text(json.dumps({'summary':summary,'cases':records},indent=2)+'\n')
print(json.dumps(summary,indent=2))
