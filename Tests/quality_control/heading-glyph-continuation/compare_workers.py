#!/usr/bin/env python3
"""Compare genuine fresh baseline/candidate native app runs without smoothing crop differences."""
import json,hashlib,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
RUN=ROOT/'.build/heading-glyph-continuation-2026-10-03/native-worker'
REPORT=Path(__file__).resolve().parent
load=lambda p:json.loads(p.read_text())
def diff(a,b,path=''):
 if type(a)!=type(b):return [{'path':path,'before':a,'after':b}]
 if isinstance(a,dict):return sum((diff(a[k],b[k],path+'/'+k) if k in a and k in b else [{'path':path+'/'+k,'before':a.get(k),'after':b.get(k)}] for k in sorted(a.keys()|b.keys())),[])
 if isinstance(a,list):
  if len(a)!=len(b):return [{'path':path,'before':a,'after':b}]
  return sum((diff(x,y,path+'/'+str(i)) for i,(x,y) in enumerate(zip(a,b))),[])
 return [] if a==b else [{'path':path,'before':a,'after':b}]
rows=[]
for c in load(RUN/'config.json'):
 id=c['id']
 if not (RUN/'baseline'/f'{id}-summary.json').exists():continue
 a=load(RUN/'baseline'/f'{id}-inventory.json');b=load(RUN/f'{id}-inventory.json')
 ap=load(RUN/'baseline'/f'{id}-plan.json');bp=load(RUN/f'{id}-plan.json')
 strip=lambda inventory:{**inventory,'pages':[{k:v for k,v in p.items() if k!='sharedHeadings'} for p in inventory['pages']]}
 main=lambda plan:{**plan,'pages':[{**p,'assignments':[{k:v for k,v in x.items() if k!='sourceMarkings'} for x in p['assignments']]} for p in plan['pages']]}
 ab=[x for p in ap['pages'] for x in p['assignments']];bb=[x for p in bp['pages'] for x in p['assignments']]
 # Keep the full raw diff below. Separately identify exact object permutations,
 # without changing or rounding any component, crop, or source obligation.
 key=lambda x:json.dumps(x,sort_keys=True,separators=(',',':'))
 component_pages=[{'pageIndex':x['pageIndex'],'beforeCount':len(x.get('inkComponents',[])),'afterCount':len(y.get('inkComponents',[])),'exactMultisetsEqual':collections.Counter(map(key,x.get('inkComponents',[])))==collections.Counter(map(key,y.get('inkComponents',[])))} for x,y in zip(a['pages'],b['pages']) if x.get('inkComponents')!=y.get('inkComponents')]
 
 rows.append({'id':id,'inkComponentOrderChanges':component_pages,'pages':len(b['pages']),'bands':len(bb),'headingChanges':[{'pageIndex':x['pageIndex'],'before':x.get('sharedHeadings'),'after':y.get('sharedHeadings')} for x,y in zip(a['pages'],b['pages']) if x.get('sharedHeadings')!=y.get('sharedHeadings')],'copiedRowChanges':[{'id':x['id'],'pageIndex':x['pageIndex'],'before':x['sourceMarkings'],'after':y['sourceMarkings']} for x,y in zip(ab,bb) if x['sourceMarkings']!=y['sourceMarkings']],'otherInventoryChanges':diff(strip(a),strip(b)),'otherPlanChanges':diff(main(ap),main(bp)),'baselineSummary':load(RUN/'baseline'/f'{id}-summary.json'),'candidateSummary':load(RUN/f'{id}-summary.json'),'fileHashes':{f'{v}/{name}':hashlib.sha256((folder/name).read_bytes()).hexdigest() for v,folder in [('baseline',RUN/'baseline'),('candidate',RUN)] for name in [f'{id}-inventory.json',f'{id}-plan.json',f'{id}-summary.json']}})
result={'completedCases':len(rows),'expectedCases':2,'pages':sum(r['pages'] for r in rows),'bands':sum(r['bands'] for r in rows),'headingChanges':sum(len(r['headingChanges']) for r in rows),'copiedRowChanges':sum(len(r['copiedRowChanges']) for r in rows),'otherInventoryChanges':sum(len(r['otherInventoryChanges']) for r in rows),'otherPlanChanges':sum(len(r['otherPlanChanges']) for r in rows),'cases':rows}
(RUN/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
(REPORT/'worker-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='cases'},indent=2))
for row in rows:
 for field in ['otherInventoryChanges','otherPlanChanges']:
  if row[field]:print(row['id'],field,[(x['path'],x['before'],x['after']) for x in row[field]][:8])
