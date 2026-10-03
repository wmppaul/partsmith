from pathlib import Path
import json, hashlib
r=Path('.build/stem-ownership-2026-10-03')
baseline=Path('.build/residual9-boundary-2026-10-03/candidate-v2/actual.json')
candidate=r/'unified-geometry-v1-actual.json'
a=json.loads(baseline.read_text());b=json.loads(candidate.read_text())
assert a['sourceSHA256']==b['sourceSHA256'] and a['rectifications']==b['rectifications']
flat=lambda d:{v['id']:v for p in d['plan']['pages'] for v in p['assignments']}
aa,bb=flat(a),flat(b); assert aa.keys()==bb.keys()
ap={p['pageIndex']:p for p in a['pages']};bp={p['pageIndex']:p for p in b['pages']}
assert ap.keys()==bp.keys() and len(bp)==39
for i in ap:
    for key in ['pageWidth','pageHeight','imageWidth','imageHeight','analysisSkewDegrees','staves']:
        assert ap[i][key]==bp[i][key],(i,key)
def neighbors(b,p):
    return [s['id'] for s in p['staves'] if s['id'] not in b['candidateIDs'] and b['topFraction']<=min(s['staffLineFractions']) and b['bottomFraction']>=max(s['staffLineFractions'])]
def rect(b):
    p=bp[b['pageIndex']]
    return [b['leftFraction']*p['pageWidth'],b['topFraction']*p['pageHeight'],(1-b['rightFraction'])*p['pageWidth'],b['bottomFraction']*p['pageHeight']]
changes=[]
for k,new in bb.items():
    old=aa[k]
    assert old['candidateIDs']==new['candidateIDs'] and old['partID']==new['partID']
    if rect(old)!=rect(new):
        changes.append({'bandID':k,'before':rect(old),'after':rect(new),'beforeNeighbors':neighbors(old,ap[old['pageIndex']]),'afterNeighbors':neighbors(new,bp[new['pageIndex']])})
guards=json.loads(Path('Tests/quality_control/residual9-endpoint-ownership/source-guards.json').read_text())['guards']
checks=[]
for g in guards:
    box=rect(bb[g['bandID']]);gr=g['rect']
    checks.append({'id':g['bandID'],'sourceEnvelope':gr,'crop':box,'contains':box[0]<=gr[0] and box[1]<=gr[1] and box[2]>=gr[2] and box[3]>=gr[3]})
summary={'pages':39,'bands':len(bb),'geometryChanges':0,'changedCrops':len(changes),
    'wholeNeighborsBefore':sum(len(neighbors(v,ap[v['pageIndex']])) for v in aa.values()),
    'wholeNeighborsAfter':sum(len(neighbors(v,bp[v['pageIndex']])) for v in bb.values()),
    'frozenGuardsPassed':sum(c['contains'] for c in checks),'frozenGuardsTotal':len(checks)}
result={'summary':summary,'changes':changes,'guards':checks,'inputs':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [baseline,candidate]}}
(r/'unified-geometry-v1-actual-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(summary,indent=2))
