from pathlib import Path
import json,hashlib
r=Path('.build/residual9-boundary-2026-10-03')
inputs=json.loads((r/'corpus-inputs.json').read_text())
rows=[];pending=[]
geometry=['pageWidth','pageHeight','imageWidth','imageHeight','analysisSkewDegrees','staves']
crop=['topFraction','bottomFraction','leftFraction','rightFraction']
def flat(data):return {b['id']:b for p in data['plan']['pages'] for b in p['assignments']}
def neighbors(b,p):return [s['id'] for s in p['staves'] if s['id'] not in b['candidateIDs'] and b['topFraction']<=min(s['staffLineFractions']) and b['bottomFraction']>=max(s['staffLineFractions'])]
for inp in inputs:
    files=[r/v/'corpus'/(inp['id']+'.json') for v in ['baseline','candidate']]
    if not all(p.exists() for p in files):pending.append(inp['id']);continue
    a,b=[json.loads(p.read_text()) for p in files]
    ap={p['pageIndex']:p for p in a['pages']};bp={p['pageIndex']:p for p in b['pages']}
    assert list(ap)==list(bp)==list(range(inp['pages']))
    aa,bb=flat(a),flat(b)
    geo=[];ink=[];changed=[];other=[]
    for i in ap:
        fields=[k for k in geometry if ap[i][k]!=bp[i][k]]
        if fields:geo.append({'page':i+1,'fields':fields})
        if ap[i]['inkComponents']!=bp[i]['inkComponents']:ink.append(i+1)
    for k in aa.keys()&bb.keys():
        old,new=aa[k],bb[k]
        if any(old[f]!=new[f] for f in crop):
            page=bp[new['pageIndex']];w,h=page['pageWidth'],page['pageHeight']
            def rect(v):return [v['leftFraction']*w,v['topFraction']*h,(1-v['rightFraction'])*w,v['bottomFraction']*h]
            changed.append({'id':k,'before':rect(old),'after':rect(new),'beforeNeighbors':neighbors(old,ap[old['pageIndex']]),'afterNeighbors':neighbors(new,bp[new['pageIndex']])})
        fields=[f for f in old.keys()|new.keys() if f not in crop and old.get(f)!=new.get(f)]
        if fields:other.append({'id':k,'fields':fields})
    rows.append({**inp,'baselineSHA256':hashlib.sha256(files[0].read_bytes()).hexdigest(),'candidateSHA256':hashlib.sha256(files[1].read_bytes()).hexdigest(),
        'geometryChanges':geo,'changedInkPages':ink,'addedBands':sorted(bb.keys()-aa.keys()),'removedBands':sorted(aa.keys()-bb.keys()),'beforeBands':len(aa),'afterBands':len(bb),
        'changedCrops':changed,'otherBandChanges':other,
        'wholeNeighborsBefore':sum(len(neighbors(v,ap[v['pageIndex']])) for v in aa.values()),'wholeNeighborsAfter':sum(len(neighbors(v,bp[v['pageIndex']])) for v in bb.values())})
summary={'completedInputs':len(rows),'pendingInputs':len(pending),'pages':sum(x['pages'] for x in rows),'bands':sum(x['afterBands'] for x in rows),
    'geometryChangedPages':sum(len(x['geometryChanges']) for x in rows),'inkChangedPages':sum(len(x['changedInkPages']) for x in rows),
    'changedCrops':sum(len(x['changedCrops']) for x in rows),'otherBandChanges':sum(len(x['otherBandChanges']) for x in rows),
    'addedBands':sum(len(x['addedBands']) for x in rows),'removedBands':sum(len(x['removedBands']) for x in rows),
    'wholeNeighborsBefore':sum(x['wholeNeighborsBefore'] for x in rows),'wholeNeighborsAfter':sum(x['wholeNeighborsAfter'] for x in rows)}
(r/'corpus-comparison.json').write_text(json.dumps({'summary':summary,'rows':rows,'pending':pending},indent=2)+'\n')
print(json.dumps(summary,indent=2))
for row in rows:
    if row['changedCrops'] or row['geometryChanges']:print(json.dumps({k:row[k] for k in ['id','geometryChanges','changedCrops']},indent=2))
