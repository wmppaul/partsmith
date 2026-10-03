#!/usr/bin/env python3
from pathlib import Path
import json,collections
ROOT=Path(__file__).resolve().parents[3];R=Path(__file__).resolve().parent
W=ROOT/'.build/brahms-continuation-release-2026-10-03/output-review'
load=lambda p:json.loads(p.read_text())
guards=load(R/'source-guards.json')['guards'];geometry=[];source=[]
for variant in ['baseline','candidate']:
 manifest=load(W/(variant+'-parts')/'manifest.json');byid={p['id']:p for part in manifest['parts'] for p in part['placements']}
 for guard in guards:
  p=byid[guard['bandID']];a=p['sourceRect'];b=guard['rect'];retained=a[0]<=b[0]+1e-9 and a[1]<=b[1]+1e-9 and a[2]>=b[2]-1e-9 and a[3]>=b[3]-1e-9
  assert retained,(variant,guard,a)
  source.append({'variant':variant,'id':guard['bandID'],'sourceRect':a,'guard':b,'outputPage':p['outputPage'],'retained':retained})
 for part in manifest['parts']:
  grouped=collections.defaultdict(list);outside=[]
  for p in part['placements']:
   rr=[p['destinationRect']]+[x['destinationRect'] for x in p['sourceMarkings']];u=[min(x[0] for x in rr),min(x[1] for x in rr),max(x[2] for x in rr),max(x[3] for x in rr)];grouped[p['outputPage']].append((p['id'],u))
   if u[0]<48-1e-7 or u[1]<48-1e-7 or u[2]>564+1e-7 or u[3]>744+1e-7:outside.append((p['id'],u))
  gaps=[{'outputPage':page,'before':a[0],'after':b[0],'gap':b[1][1]-a[1][3]} for page,rr in grouped.items() for a,b in zip(rr,rr[1:])]
  negative=[x for x in gaps if x['gap']< -1e-7];assert not negative and not outside
  geometry.append({'variant':variant,'part':part['id'],'outsideMargins':outside,'minimumBlockGap':min(x['gap'] for x in gaps),'negativeBlockGaps':negative})
(R/'layout-geometry.json').write_text(json.dumps(geometry,indent=2)+'\n');(R/'output-guards.json').write_text(json.dumps(source,indent=2)+'\n')
print('20 source-envelope checks pass; all output blocks and copies inside 48pt margins with no overlap.')
