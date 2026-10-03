from pathlib import Path
import hashlib,json,collections
root=Path.cwd();work=root/'.build/ownership-mozart-output-2026-10-03';out=root/'Tests/quality_control/ownership-mozart-output-2026-10-03'
load=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
summary={v:load(work/v/'mozart-summary.json') for v in ['baseline','candidate']}
for v,s in summary.items():
 assert s['planCanApply'] and s['bandCount']==476,(v,s)
 assert not s['issues'] and s['projectUnchanged'] and s['progressCleared'],v
 assert s['completionOnMainThread'] and not s['autoSkipped'],v
plans={v:load(work/v/'mozart-plan.json') for v in summary}
invs={v:load(work/v/'mozart-inventory.json') for v in summary}
a,b=invs.values();assert a['sourceSHA256']==b['sourceSHA256'] and a['rectifications']==b['rectifications']==[]
assert len(a['pages'])==len(b['pages'])==30
page_metadata_changes=[];component_changes=[]
for left,right in zip(a['pages'],b['pages']):
 for key in set(left)|set(right):
  if key!='inkComponents' and left.get(key)!=right.get(key):page_metadata_changes.append({'page':left['pageIndex']+1,'key':key,'before':left.get(key),'after':right.get(key)})
 key=lambda x:json.dumps(x,sort_keys=True)
 la=collections.Counter(map(key,left.get('inkComponents',[])));ra=collections.Counter(map(key,right.get('inkComponents',[])))
 if la!=ra:component_changes.append({'page':left['pageIndex']+1,'removed':[json.loads(x) for x in (la-ra).elements()],'added':[json.loads(x) for x in (ra-la).elements()]})
flat=lambda p:[a for page in p['pages'] for a in page['assignments']]
left,right=map(flat,plans.values());assert len(left)==len(right)==476
changes=[];warnings=[];other=[];copies=0
for a,b in zip(left,right):
 assert a['id']==b['id']
 keys={'topFraction','bottomFraction','warnings'}
 if {k:v for k,v in a.items() if k not in keys}!={k:v for k,v in b.items() if k not in keys}:other.append({'id':a['id'],'before':a,'after':b})
 copies+=len(b.get('sourceMarkings',[]))
 if [a['topFraction'],a['bottomFraction']]!=[b['topFraction'],b['bottomFraction']]:changes.append({'id':a['id'],'before':[a['topFraction'],a['bottomFraction']],'after':[b['topFraction'],b['bottomFraction']]})
 if a['warnings']!=b['warnings']:warnings.append({'id':a['id'],'before':a['warnings'],'after':b['warnings']})
result={'pages':30,'musicStrips':476,'directionCopies':copies,'componentChanges':component_changes,'staffAndDirectionMetadataChanges':page_metadata_changes,'changedCrops':changes,'changedWarnings':warnings,'otherBandChanges':other,'actualWorkerSummaries':summary,'bindings':{str(p.relative_to(root)):sha(p) for v in summary for p in [work/v/'mozart-plan.json',work/v/'mozart-inventory.json',work/v/'mozart-summary.json']}}
(out/'worker-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['actualWorkerSummaries','bindings','componentChanges']},indent=2))
assert not page_metadata_changes and not other
assert {c['id'] for c in changes}=={'p25-s1-violin','p25-s1-viola'}
