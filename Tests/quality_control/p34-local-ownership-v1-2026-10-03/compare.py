from pathlib import Path
import json, hashlib, collections

W = Path('.build/p34-local-ownership-2026-10-03')
def load(p): return json.loads(Path(p).read_text())
def dump(n, v): (W/n).write_text(json.dumps(v, indent=2)+'\n')
baseline = load('.build/numbered-monotone-independent-2026-10-03/baseline/controls297-pixels-run/results.json')
candidate = load(W/'candidate/controls297-pixels-run/results.json')
owners, cases = [], []
assert len(baseline) == len(candidate) == 297
for index, (b, c) in enumerate(zip(baseline, candidate)):
    for k in ['kind','scale','tilt','bow','imageSize','expectsSeparation','sourceRawSHA256','sourceOwnershipSHA256']:
        assert b[k] == c[k], (index,k)
    assert b['planCanApply'] and c['planCanApply']
    fields = {k:b[k] for k in ['kind','scale','tilt','bow']}
    for old, new in zip(b['targets'], c['targets']):
        for k in ['owner','sourceEnvelope','sourcePixels','sourcePixelIndices','sourceMaskSHA256']:
            assert old[k] == new[k], (index,k)
        lost_old, lost_new = set(old['lostPixelIndices']), set(new['lostPixelIndices'])
        owners.append(dict(fields, caseIndex=index, owner=old['owner'], baselineCrop=old['crop'],
            candidateCrop=new['crop'], baselineLost=len(lost_old), candidateLost=len(lost_new),
            newlyLostPixelIndices=sorted(lost_new-lost_old), recoveredPixelIndices=sorted(lost_old-lost_new)))
    cases.append(dict(fields,caseIndex=index,expectsSeparation=b['expectsSeparation'],
        baselineWholeNeighbors=b['wholeNeighborCount'],candidateWholeNeighbors=c['wholeNeighborCount'],
        baselineComplete=b['allTargetsPreserved'],candidateComplete=c['allTargetsPreserved']))
summary = {'cases':297,'owners':len(owners),'immutableSourceAndOwnerMasksExact':True,
    'baselineCompleteCases':sum(x['allTargetsPreserved'] for x in baseline),
    'candidateCompleteCases':sum(x['allTargetsPreserved'] for x in candidate),
    'newLostPixels':sum(len(x['newlyLostPixelIndices']) for x in owners),
    'recoveredPixels':sum(len(x['recoveredPixelIndices']) for x in owners),
    'ownersWithNewLoss':sum(bool(x['newlyLostPixelIndices']) for x in owners),
    'casesWithNewSeparationFailure':[x['caseIndex'] for x in cases if x['expectsSeparation'] and x['candidateWholeNeighbors']>x['baselineWholeNeighbors']],
    'allNewForeignCases':[x['caseIndex'] for x in cases if x['candidateWholeNeighbors']>x['baselineWholeNeighbors']]}
dump('comparison297.json', {'summary':summary,'cases':cases,'owners':owners})
print('297',json.dumps(summary))

b336=load('.build/ownership-alternatives-2026-10-03/results336.json')
c336=load(W/'candidate/expanded336-run/results.json')
assert len(b336)==len(c336)==336
for i,(b,c) in enumerate(zip(b336,c336)):
    for k in ['headStyle','kind','scale','tilt','inset','sourceEnvelope']:assert b.get(k)==c.get(k),(i,k)
result336={'cases':336,
    'baselineMusicalFailures':[i for i,x in enumerate(b336) if x.get('bothCropsPreserveSource') is False],
    'candidateMusicalFailures':[i for i,x in enumerate(c336) if x.get('bothCropsPreserveSource') is False],
    'newEnvelopeFailures':[i for i,(b,c) in enumerate(zip(b336,c336)) if b.get('bothCropsPreserveSource') is True and c.get('bothCropsPreserveSource') is False],
    'newUpperTargetFailures':[i for i,(b,c) in enumerate(zip(b336,c336)) if b['preservesUpperTarget'] and not c['preservesUpperTarget']],
    'changedCases':[{'index':i,'baseline':b,'candidate':c} for i,(b,c) in enumerate(zip(b336,c336)) if b!=c]}
dump('comparison336.json',result336)
print('336',json.dumps({k:len(v) if isinstance(v,list) else v for k,v in result336.items()}))

b=load(W/'baseline/one-page-run/results.json');c=load(W/'candidate/one-page-run/results.json')
for k in set(b)|set(c):
    if k!='inkComponents':assert b.get(k)==c.get(k),k
old_inventory=load('.build/envelope-compatibility-corpus-2026-10-03/baseline/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json')
original=next(p for p in old_inventory['pages'] if p['pageIndex']==33)
stable_fields=[k for k in set(b)|set(original) if k not in ['inkComponents','sharedHeadings','sharedNavigation','sharedEndings']]
for k in stable_fields:assert b.get(k)==original.get(k),(k,b.get(k),original.get(k))
def component_counts(page):return collections.Counter(json.dumps(x,sort_keys=True) for x in page['inkComponents'])
assert component_counts(b)==component_counts(original),'Fresh baseline components differ from frozen raw source'
bp=load(W/'baseline/one-page-run/plan.json');cp=load(W/'candidate/one-page-run/plan.json')
def bands(plan):return [a for p in plan['pages'] for a in p['assignments']]
before=bands(bp);after=bands(cp);assert len(before)==len(after)==16
def rect(x):return [x['leftFraction']*427,x['topFraction']*614,(1-x['rightFraction'])*427,x['bottomFraction']*614]
changed=[]
for x,y in zip(before,after):
    for k in ['id','partID','candidateIDs','systemIndex']:assert x[k]==y[k],k
    if rect(x)!=rect(y):changed.append({'bandID':x['id'],'before':x,'after':y,'beforePDFBounds':rect(x),'afterPDFBounds':rect(y)})
f=load('Tests/quality_control/brahms-p34-dynamic-2026-10-03/independent-symbol-obligations.json')['raw']
pixels={(x,y) for y,l,r in f['pixelRuns'] for x in range(l,r)}
assert len(pixels)==f['pixelCount']==372
def f_retention(rows):
    target=next(x for x in rows if x['id']==f['bandID']);r=rect(target)
    r=[r[0]*1800/427,r[1]*2589/614,r[2]*1800/427,r[3]*2589/614]
    full={(x,y) for x,y in pixels if x>=r[0] and y>=r[1] and x+1<=r[2] and y+1<=r[3]}
    intersects={(x,y) for x,y in pixels if x+1>r[0] and y+1>r[1] and x<r[2] and y<r[3]}
    return {'cropPDF':rect(target),'sourcePixelCrop':r,'fullyRetained':len(full),'partlyIntersected':len(intersects-full),'fullyExcluded':len(pixels-intersects),'notFullyRetainedPixels':sorted([list(v) for v in pixels-full])}
result={'freshBaselineReproducesFrozenRawAnalysis':True,'sourceStaffGeometryAndAssignmentsUnchanged':True,
    'baselineComponentCount':len(b['inkComponents']),'candidateComponentCount':len(c['inkComponents']),
    'changedCropCount':len(changed),'changedCrops':changed,'baselineF':f_retention(before),'candidateF':f_retention(after),
    'removedComponents':[json.loads(x) for x in (component_counts(b)-component_counts(c)).elements()],
    'addedComponents':[json.loads(x) for x in (component_counts(c)-component_counts(b)).elements()]}
dump('page34-comparison.json',result)
print('p34',json.dumps({k:v for k,v in result.items() if k not in ['changedCrops','removedComponents','addedComponents']}))
