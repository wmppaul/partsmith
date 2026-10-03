#!/usr/bin/env python3
"""Read-only full raw-corpus diff. Never starts native workers or changes inputs."""
from pathlib import Path
import argparse,collections,hashlib,json,math
P=argparse.ArgumentParser();P.add_argument('--work',type=Path,default=Path('.build/combined-corpus-2026-10-03'));P.add_argument('--allow-partial',action='store_true');P.add_argument('--expected-analyzer');A=P.parse_args()
OUT=Path(__file__).resolve().parent;read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();canon=lambda x:json.dumps(x,sort_keys=True,separators=(',',':'))
def differences(a,b,path=''):
 if type(a)!=type(b):return [{'path':path,'before':a,'after':b}]
 if isinstance(a,dict):
  result=[]
  for k in sorted(a.keys()|b.keys()):
   if k not in a or k not in b:result.append({'path':path+'/'+k,'before':a.get(k),'after':b.get(k)})
   else:result+=differences(a[k],b[k],path+'/'+k)
  return result
 if isinstance(a,list):
  if len(a)!=len(b):return [{'path':path,'before':a,'after':b}]
  return [z for i,(x,y) in enumerate(zip(a,b)) for z in differences(x,y,path+'/'+str(i))]
 return [] if a==b else [{'path':path,'before':a,'after':b}]
def payload_check(d,row):
 assert [p['pageIndex'] for p in d['pages']]==[p['pageIndex'] for p in d['plan']['pages']]==list(range(row['pages']))
 parts={p['id'] for p in read(row['profile'])['parts']};seen=set()
 for pg,pp in zip(d['pages'],d['plan']['pages']):
  staffIDs={s['id'] for s in pg['staves']};assert len(staffIDs)==len(pg['staves'])
  for c in pg['inkComponents']:assert set(c['staffIDs'])<=staffIDs and len(c['bounds'])==4 and all(math.isfinite(x) for x in c['bounds'])
  for b in pp['assignments']:
   assert b['id'] not in seen and b['pageIndex']==pg['pageIndex'] and b['partID'] in parts and set(b['candidateIDs'])<=staffIDs
   seen.add(b['id'])
 return seen
def crop(b,pg):return [b['leftFraction']*pg['pageWidth'],b['topFraction']*pg['pageHeight'],(1-b['rightFraction'])*pg['pageWidth'],b['bottomFraction']*pg['pageHeight']]
def contains(a,b):return a[0]<=b[0] and a[1]<=b[1] and a[2]>=b[2] and a[3]>=b[3]
def whole_neighbors(b,pg):return [s['id'] for s in pg['staves'] if s['id'] not in b['candidateIDs'] and b['topFraction']<=min(s['staffLineFractions']) and b['bottomFraction']>=max(s['staffLineFractions'])]
def counts(d):
 return {'bands':sum(len(p['assignments']) for p in d['plan']['pages']),'pagesWithAssignments':sum(bool(p['assignments']) for p in d['plan']['pages']),'pagesWithUnresolvedReasons':sum(bool(p['unresolvedReasons']) for p in d['plan']['pages']),'detectedStaves':sum(len(p['staves']) for p in d['pages']),'unassignedStaves':sum(len({s['id'] for s in pg['staves']}-{i for b in pp['assignments'] for i in b['candidateIDs']}) for pg,pp in zip(d['pages'],d['plan']['pages'])),'wholeNeighborOccurrences':sum(len(whole_neighbors(b,pg)) for pg,pp in zip(d['pages'],d['plan']['pages']) for b in pp['assignments'])}
base=read(OUT/'baseline-binding.json');byID={r['id']:r for r in base['rows']};inputs=read(A.work/'inputs.json');assert len(inputs)==36 and {x['id'] for x in inputs}==set(byID)
binding=read(A.work/'build-binding.json');snapshot=Path(binding['snapshot']);binary=Path(binding['binary']);assert sha(binary)==binding['binarySHA256']
for rel,digest in binding['sourceHashes'].items():assert sha(snapshot/rel)==digest
analyzers=[(k,v) for k,v in binding['sourceHashes'].items() if k.endswith('/NativeScorePageAnalyzer.swift') or k=='NativeScorePageAnalyzer.swift'];assert len(analyzers)==1
if A.expected_analyzer:assert analyzers[0][1]==A.expected_analyzer
status=read(A.work/'status.json');states={r['id']:r for r in status['results']};assert len(states)==len(status['results']) and set(states)<=set(byID)
if not A.allow_partial:assert status['complete'] and len(states)==36
rows=[];queue=[];jobs=[]
for inp in inputs:
 old=byID[inp['id']]
 for key in ['id','source','sourceSHA256','profile','profileSHA256','pages','baseline','baselineSHA256']:assert inp[key]==old[key],(inp['id'],key)
 assert sha(inp['source'])==old['sourceSHA256'] and sha(inp['profile'])==old['profileSHA256'] and sha(inp['baseline'])==old['baselineSHA256']
 if inp['id'] not in states:continue
 state=states[inp['id']];assert state['exitCode']==0 and state['binarySHA256']==binding['binarySHA256']
 for key in ['id','sourceSHA256','profileSHA256','pages','baselineSHA256']:assert state[key]==inp[key]
 candidate=Path(state['output']);assert sha(candidate)==state['outputSHA256']
 progress=read(candidate.with_name(candidate.stem+'.progress.json'));assert progress['status']=='complete' and progress['outputSHA256']==state['outputSHA256']
 before=read(inp['baseline']);after=read(candidate);oldIDs=payload_check(before,inp);newIDs=payload_check(after,inp)
 raw=[];semantic=[];nonink=[];bands=[];pagePlans=[]
 for pg0,pg1,pp0,pp1 in zip(before['pages'],after['pages'],before['plan']['pages'],after['plan']['pages']):
  n=pg0['pageIndex']+1;oldComponents=collections.Counter(map(canon,pg0['inkComponents']));newComponents=collections.Counter(map(canon,pg1['inkComponents']))
  if pg0['inkComponents']!=pg1['inkComponents']:raw.append(n)
  removed=[json.loads(s) for s in (oldComponents-newComponents).elements()];added=[json.loads(s) for s in (newComponents-oldComponents).elements()]
  ink=None
  if removed or added:
   groups=collections.defaultdict(lambda:{'before':[],'after':[]})
   for side,arr in [('before',removed),('after',added)]:
    for c in arr:groups[canon({k:v for k,v in c.items() if k!='staffIDs'})][side].append(c['staffIDs'])
   ownership=[{'geometry':json.loads(k),**v} for k,v in groups.items() if v['before'] and v['after']]
   ink={'page':n,'removed':removed,'added':added,'ownershipAtSameGeometry':ownership};semantic.append(ink)
  pageDiff=differences({k:v for k,v in pg0.items() if k!='inkComponents'},{k:v for k,v in pg1.items() if k!='inkComponents'},f'/pages/{n-1}');nonink+=pageDiff
  pld=differences({k:v for k,v in pp0.items() if k!='assignments'},{k:v for k,v in pp1.items() if k!='assignments'},f'/plan/pages/{n-1}');pagePlans+=pld
  b0={b['id']:b for b in pp0['assignments']};b1={b['id']:b for b in pp1['assignments']};local=[]
  for bid in sorted(b0.keys()|b1.keys()):
   x,y=b0.get(bid),b1.get(bid)
   if x==y:continue
   rec={'page':n,'bandID':bid,'before':x,'after':y,'fieldDifferences':differences(x,y)}
   if x is not None and y is not None:
    r0,r1=crop(x,pg0),crop(y,pg1);rec.update({'beforePDFBounds':r0,'afterPDFBounds':r1,'geometryChanged':r0!=r1,'warningChanges':x['warnings']!=y['warnings'],'assignmentChanged':{k:v for k,v in x.items() if k not in ['topFraction','bottomFraction','leftFraction','rightFraction','warnings']}!={k:v for k,v in y.items() if k not in ['topFraction','bottomFraction','leftFraction','rightFraction','warnings']},'candidateContainsPreviousCrop':contains(r1,r0),'previousContainsCandidateCrop':contains(r0,r1),'beforeWholeNeighbors':whole_neighbors(x,pg0),'afterWholeNeighbors':whole_neighbors(y,pg1)})
   bands.append(rec);local.append(rec)
  if ink or pageDiff or pld or local:
   staffIDs=sorted({s for c in removed+added for s in c['staffIDs']}|{s for rec in local for side in ['before','after'] if rec[side] for s in rec[side]['candidateIDs']})
   key=inp['id']+f':p{n}'
   queue.append({'key':key,'id':inp['id'],'page':n,'source':inp['source'],'sourceSHA256':inp['sourceSHA256'],'profile':inp['profile'],'profileRequiresSystemAssignment':old['requiresSystemAssignment'],'beforeBandCount':len(pp0['assignments']),'afterBandCount':len(pp1['assignments']),'beforeUnresolvedReasons':pp0['unresolvedReasons'],'afterUnresolvedReasons':pp1['unresolvedReasons'],'affectedStaffIDs':staffIDs,'componentChanges':ink,'changedBands':local,'otherPageChanges':pageDiff,'otherPlanPageChanges':pld,'status':'pending source-first review','instrumentIdentityMustNotBeInferred':not pp0['assignments']})
   jobs.append({'id':inp['id'],'page':n,'beforeInventory':inp['baseline'],'afterInventory':str(candidate)})
 top0={k:v for k,v in before['plan'].items() if k!='pages'};top1={k:v for k,v in after['plan'].items() if k!='pages'}
 rows.append({'id':inp['id'],'pages':inp['pages'],'requiresSystemAssignment':old['requiresSystemAssignment'],'beforeCounts':counts(before),'afterCounts':counts(after),'addedBandIDs':sorted(newIDs-oldIDs),'removedBandIDs':sorted(oldIDs-newIDs),'componentOrderOrSemanticDifferentPages':raw,'semanticComponentDifferentPages':[x['page'] for x in semantic],'componentOrderOnlyPages':sorted(set(raw)-{x['page'] for x in semantic}),'nonInkPageDifferences':nonink,'topPlanDifferences':differences(top0,top1,'/plan'),'nonAssignmentPagePlanDifferences':pagePlans,'changedBands':bands,'files':[{'path':inp['baseline'],'sha256':inp['baselineSHA256']},{'path':str(candidate),'sha256':state['outputSHA256']}]})
summary={'complete':len(rows)==36,'terminalScores':len(rows),'pages':sum(x['pages'] for x in rows),'before':{k:sum(x['beforeCounts'][k] for x in rows) for k in rows[0]['beforeCounts']} if rows else {},'after':{k:sum(x['afterCounts'][k] for x in rows) for k in rows[0]['afterCounts']} if rows else {},'semanticComponentChangedPages':sum(len(x['semanticComponentDifferentPages']) for x in rows),'componentOrderOnlyPages':sum(len(x['componentOrderOnlyPages']) for x in rows),'changedBandRows':sum(len(x['changedBands']) for x in rows),'changedCropRows':sum(b.get('geometryChanged',False) for x in rows for b in x['changedBands']),'pendingSourceReviewPages':len(queue)}
result={'summary':summary,'rows':rows,'buildBinding':binding,'analyzerSHA256':analyzers[0][1],'inputsSHA256':sha(A.work/'inputs.json'),'statusSHA256':sha(A.work/'status.json'),'baselineBindingSHA256':sha(OUT/'baseline-binding.json'),'comparatorSHA256':sha(__file__),'scope':'Raw source comparison. Unresolved pages remain in coverage and review queue; neutral staff plans are diagnostics only.'}
for name,data in [('comparison.json',result),('source-review-queue.json',queue),('neutral-staff-jobs.json',jobs)]:
 target=OUT/name;tmp=target.with_suffix('.json.writing');tmp.write_text(json.dumps(data,indent=2)+'\n');tmp.replace(target)
print(json.dumps(summary,indent=2))
