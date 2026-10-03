import json,hashlib
from pathlib import Path
b=Path('.build/mozart-auxiliary-review-2026-10-03/edge-completion');result={}
inputs={'mozart':'.build/ownership-mozart-output-2026-10-03/candidate/mozart-inventory.json','brahms':'.build/ownership-alternatives-output-2026-10-03/brahms-inventory.json'}
def flat(plan):return [x for page in plan['pages'] for x in page['assignments']]
for name,ip in inputs.items():
 inv=json.load(open(ip));a=json.load(open(b/'results'/f'baseline-{name}-plan.json'));c=json.load(open(b/'results'/f'candidate-{name}-plan.json'));ab=flat(a);cb=flat(c);pages={p['pageIndex']:p for p in inv['pages']};assert len(ab)==len(cb);changes=[];loss=[];fields=[]
 for old,new in zip(ab,cb):
  assert old['id']==new['id'];pg=pages[old['pageIndex']];h=pg['pageHeight'];w=pg['pageWidth'];ro=[old['leftFraction']*w,old['topFraction']*h,(1-old['rightFraction'])*w,old['bottomFraction']*h];rn=[new['leftFraction']*w,new['topFraction']*h,(1-new['rightFraction'])*w,new['bottomFraction']*h]
  if rn[0]>ro[0]+1e-8 or rn[1]>ro[1]+1e-8 or rn[2]<ro[2]-1e-8 or rn[3]<ro[3]-1e-8:loss.append(old['id'])
  def cores(rect):return [s['id'] for s in pg['staves'] if s['id'] not in old['candidateIDs'] and s['staffLineFractions'][0]*h>=rect[1]-1e-7 and s['staffLineFractions'][4]*h<=rect[3]+1e-7]
  if ro!=rn:changes.append({'id':old['id'],'sourcePage':old['pageIndex']+1,'baseline':ro,'candidate':rn,'baselineForeignCores':cores(ro),'candidateForeignCores':cores(rn)})
  old2={k:v for k,v in old.items() if k not in ['topFraction','bottomFraction']};new2={k:v for k,v in new.items() if k not in ['topFraction','bottomFraction']}
  if old2!=new2:fields.append(old['id'])
 result[name]={'source':inv['source'],'sourceSHA256':inv['sourceSHA256'],'inventory':ip,'inventorySHA256':hashlib.sha256(Path(ip).read_bytes()).hexdigest(),'pages':len(inv['pages']),'bands':len(ab),'changedBands':len(changes),'changedPages':sorted(set(x['sourcePage'] for x in changes)),'cropShrinkage':loss,'otherBandFieldsChanged':fields,'additionalWholeForeignCores':[x for x in changes if set(x['candidateForeignCores'])-set(x['baselineForeignCores'])],'unresolvedBaseline':[(p['pageIndex']+1,p['unresolvedReasons']) for p in a['pages'] if p['unresolvedReasons']],'unresolvedCandidate':[(p['pageIndex']+1,p['unresolvedReasons']) for p in c['pages'] if p['unresolvedReasons']],'changes':changes}
 print(name,len(changes),'bands',len(result[name]['changedPages']),'pages','new foreign cores',len(result[name]['additionalWholeForeignCores']),'shrinks',loss,'otherfields',fields)
 for x in changes:print(x)
(b/'results/comparison.json').write_text(json.dumps(result,indent=2)+'\n')
