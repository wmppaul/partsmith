import json,sys,hashlib
from pathlib import Path
r=Path('.build/residual9-endpoint-ownership-2026-10-03');a=json.loads((r/'baseline-actual.json').read_text());b=json.loads((r/f'{sys.argv[1]}-actual.json').read_text())
basepages={p['pageIndex']:p for p in a['pages']};pages={p['pageIndex']:p for p in b['pages']}
flat=lambda d:{v['id']:v for p in d['plan']['pages'] for v in p['assignments']}
x,y=flat(a),flat(b)
assert x.keys()==y.keys()
fields=['pageWidth','pageHeight','imageWidth','imageHeight','analysisSkewDegrees','staves']
geometry=[(i,[f for f in fields if p.get(f)!=basepages[i].get(f)]) for i,p in pages.items() if any(p.get(f)!=basepages[i].get(f) for f in fields)]
def neighbors(v,p):return [s['id'] for s in p['staves'] if s['id'] not in v['candidateIDs'] and v['topFraction']<=min(s['staffLineFractions']) and v['bottomFraction']>=max(s['staffLineFractions'])]
def rect(v):
 p=pages[v['pageIndex']];return [v['leftFraction']*p['pageWidth'],v['topFraction']*p['pageHeight'],(1-v['rightFraction'])*p['pageWidth'],v['bottomFraction']*p['pageHeight']]
changes=[]
for k,v in y.items():
 if any(v[f]!=x[k][f] for f in ['leftFraction','topFraction','rightFraction','bottomFraction']):changes.append({'id':k,'before':rect(x[k]),'after':rect(v),'beforeNeighbors':neighbors(x[k],basepages[v['pageIndex']]),'afterNeighbors':neighbors(v,pages[v['pageIndex']])})
guards=json.loads(Path('Tests/quality_control/residual9-endpoint-ownership/source-guards.json').read_text())['guards'];guardchecks=[]
for g in guards:
 c=rect(y[g['bandID']]);bounds=g['rect'];guardchecks.append({'id':g['bandID'],'sourceEnvelope':bounds,'candidate':c,'contains':c[1]<=bounds[1] and c[3]>=bounds[3]})
summary={'variant':sys.argv[1],'bands':len(y),'geometryChanges':geometry,'neighborBefore':sum(len(neighbors(v,basepages[v['pageIndex']])) for v in x.values()),'neighborAfter':sum(len(neighbors(v,pages[v['pageIndex']])) for v in y.values()),'changedBands':len(changes),'allFrozenGuardsPass':all(g['contains'] for g in guardchecks)}
(r/f'{sys.argv[1]}-comparison.json').write_text(json.dumps({'summary':summary,'changes':changes,'guards':guardchecks},indent=2)+'\n');print(json.dumps(summary,indent=2));print(json.dumps(changes,indent=2))
