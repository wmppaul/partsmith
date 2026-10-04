from pathlib import Path
from collections import Counter,defaultdict
import hashlib,json,zipfile,shutil
ROOT=Path.cwd(); OUT=ROOT/'Tests/quality_control/monotone-source-review-progress-2026-10-03'
OUT.mkdir(parents=True,exist_ok=True)
QC=Path('Tests/quality_control')
BASE=QC/'monotone-corpus-independent-2026-10-03'
C=QC/'monotone-242312-coda-loss-2026-10-03'
V=QC/'monotone-09200-source-review-2026-10-03'
S=QC/'monotone-schumann-source-review-2026-10-03'
B=QC/'brahms-raw-corrected-review-reuse-2026-10-03'
inputs={}
def sha(b): return hashlib.sha256(b).hexdigest()
def read(p):
 p=Path(p); data=p.read_bytes(); inputs[str(p)]={'sha256':sha(data),'bytes':len(data)}; return data
def load(p): return json.loads(read(p))
def dump(n,x): (OUT/n).write_text(json.dumps(x,indent=2,ensure_ascii=False)+'\n')
def verify_manifest(folder,name,selected):
 m=load(folder/name)
 if isinstance(m,dict) and 'files' in m: m={r['path']:r for r in m['files']}
 if isinstance(m,dict) and 'artifacts' in m: m=m['artifacts']
 for rel in selected:
  val=m[rel]; expected=val if isinstance(val,str) else val['sha256']
  assert sha(read(folder/rel))==expected,(folder,rel)
verify_manifest(BASE,'manifest.json',['comparison-data.zip','source-review-reuse.json','independent-summary.json'])
archive=BASE/'comparison-data.zip'; z=zipfile.ZipFile(archive)
contents={r['path']:r for r in json.loads(z.read('contents.json'))}
def archived(n):
 b=z.read(n); assert sha(b)==contents[n]['sha256']; inputs[str(archive)+'!/'+n]={'sha256':sha(b),'bytes':len(b)}; return json.loads(b)
pending=archived('pending-changed-crop-review.json'); allrows=archived('changed-crop-review-jobs.json')
assert sha(Path('.build/monotone-corpus-independent-2026-10-03/pending-changed-crop-review.json').read_bytes())==inputs[str(archive)+'!/pending-changed-crop-review.json']['sha256']
prior=load(BASE/'source-review-reuse.json')['reviewed']; totals=load(BASE/'independent-summary.json')
def key(r): return(r['id'],r['bandID'])
def unique(rows):
 d={key(r):r for r in rows}; assert len(d)==len(rows),'duplicate input score+band'; return d
allmap=unique(allrows); pendmap=unique(pending); priormap=unique(prior)
assert len(allmap)==1282 and len(pendmap)==1125 and len(priormap)==157
assert set(pendmap).isdisjoint(priormap) and set(pendmap)|set(priormap)==set(allmap)
verify_manifest(C,'hashes.json',['review.json','queue-record.json'])
verify_manifest(V,'manifest.json',['review.json'])
verify_manifest(S,'manifest.json',['per-band-review.json','reviewed-inputs.json','summary.json','shared-bindings.json'])
verify_manifest(B,'manifest.json',['reused-reviewed-bands.json','review-leaf-coordinate-validation.json','decoded-pixel-comparison.json','summary.json'])
c=load(C/'review.json'); cr=load(C/'queue-record.json'); v=load(V/'review.json'); s=load(S/'per-band-review.json'); si=load(S/'reviewed-inputs.json'); ss=load(S/'summary.json'); sb=load(S/'shared-bindings.json'); b=load(B/'reused-reviewed-bands.json')
assert c['candidateNativeSHA256']==v['candidateNativeSHA256']==ss['candidateAnalyzerSHA256']=='95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0'
csid=cr['id']; vsid=v['sourceRows'][0]['id']; ssid=si[0]['id']
indexpath=Path(c['indexBinding']['path']); cbindex=load(indexpath); assert inputs[str(indexpath)]['sha256']==c['indexBinding']['sha256']
assert isinstance(cbindex,list)
cbmap={r['bandID']:r for r in cbindex}; vimap={r['bandID']:r for r in v['sourceRows']}; simap={r['bandID']:r for r in si}
for binding in [v['inputBindings'],sb]:
 assert binding['queueSHA256']==inputs[str(archive)+'!/pending-changed-crop-review.json']['sha256']
# Existing receipts already own source inspection. Here validate their exact input rows,
# original bytes and old/new rectangles against the immutable canonical queue.
validated=[]; additions=[]; groups={}
def add(group,sid,rows,receipt,inputmap=None):
 groupkeys=[]
 for r in rows:
  k=(sid or r['id'],r['bandID']); assert k in pendmap and k not in {key(x) for x in additions}
  q=pendmap[k]; proof={'id':k[0],'bandID':k[1],'group':group,'receipt':str(receipt),'receiptSHA256':inputs[str(receipt)]['sha256'],'page':q['page'],'verdict':r.get('verdict','exact-area prior source review reused'),'sourceSHA256':q['sourceSHA256']}
  if inputmap is not None:
   inp=inputmap[r['bandID']]
   for name,value in q.items(): assert inp[name]==value,(group,k,name)
  if group=='Brahms 93521 exact reuse':
   for name in ['sourceSHA256','beforePDFBounds','afterPDFBounds']: assert r[name]==q[name],(k,name)
   assert r['candidateIDs']==q['after']['candidateIDs'] and r['partID']==q['after']['partID']
   assert r['pageAndAssignmentGeometryExact'] and r['pixelProof']['decodedPixelsExactlyEqual']
   assert r['pixelProof']['differingPixels']==0
   leaf=Path(r['leafReceipt']); assert sha(read(leaf))==r['leafReceiptSHA256']; proof['sourceReviewLeafReceipt']=str(leaf)
  elif group=='Schumann 06822':
   assert r['beforePDFBounds']==q['beforePDFBounds'] and r['afterPDFBounds']==q['afterPDFBounds']
   assert r['contextViewed']
   proof['fullSourceViewed']=r['fullSourceViewed']; proof['contextViewed']=r['contextViewed']
  sourcepath=Path(q['source']); sourcekey=str(sourcepath)
  if sourcekey not in inputs: read(sourcepath)
  assert inputs[sourcekey]['sha256']==q['sourceSHA256']
  for inventory in q['inventoryFiles']:
   ip=Path(inventory['path']); ik=str(ip)
   if ik not in inputs: read(ip)
   assert inputs[ik]['sha256']==inventory['sha256']
  additions.append(proof); groupkeys.append(k)
 groups[group]=len(groupkeys)
add('Brahms 242312',csid,c['reviewedBands'],C/'review.json',cbmap)
add('Brahms 09200',vsid,v['reviewedBands'],V/'review.json',vimap)
add('Schumann 06822',ssid,s,S/'per-band-review.json',simap)
add('Brahms 93521 exact reuse',None,b,B/'reused-reviewed-bands.json')
assert groups=={'Brahms 242312':4,'Brahms 09200':12,'Schumann 06822':32,'Brahms 93521 exact reuse':193}
newmap=unique(additions); covered=set(priormap)|set(newmap); remaining=set(pendmap)-set(newmap)
assert len(newmap)==241 and len(covered)==398 and len(remaining)==884
assert covered.isdisjoint(remaining) and covered|remaining==set(allmap)
byScore=[]
for sid in sorted({r['id'] for r in allrows}):
 rows=[r for r in allrows if r['id']==sid]; ks={key(r) for r in rows}
 rem=sorted([k[1] for k in remaining if k[0]==sid],key=lambda bid:(int(bid.split('-')[0][1:]),bid))
 byScore.append({'id':sid,'source':rows[0]['source'],'sourceSHA256':rows[0]['sourceSHA256'],'changedCrops':len(ks),'previouslyCovered':len(ks&set(priormap)),'newlyCovered':len(ks&set(newmap)),'covered':len(ks&covered),'pending':len(rem),'remainingBandIDs':rem})
assert sum(r['pending'] for r in byScore)==884
assert len(totals['zeroBandScores'])==19 and totals['after']['unassignedStaves']==15712
limits={'candidateEligibleForCropPromotion':False,'coverageIsNotPass':True,'unresolvedZeroBandProfiles':totals['zeroBandScores'],'unassignedStaves':totals['after']['unassignedStaves'],'unresolvedPages':totals['after']['pagesWithUnresolvedReasons'],'finalOutputsCertified':False,'newRenderingOrNativeAnalysis':False,'reason':'Raw crop-only plans and the default-off shared-direction path still expose Coda, Andante and numbered-tempo loss. Separate opt-in recognition fixes do not approve this cleanup candidate.'}
lossrows=[r for r in additions if ('loss' in r['verdict'].lower() or 'omission' in r['verdict'].lower()) and not r['verdict'].lower().startswith('no')]
assert {(r['id'],r['bandID']) for r in lossrows}=={(csid,'p18-s4-violin2'),(vsid,'p10-s1-violin2'),(vsid,'p22-s1-violin2')}
summary={'scope':'Exact score+band source-review coverage bookkeeping; not a crop quality pass or release approval.','candidateNativeSHA256':v['candidateNativeSHA256'],'changedCrops':1282,'previouslyCovered':157,'canonicalPendingBefore':1125,'newCoverageGroups':groups,'newlyCoveredDistinct':241,'coveredTotal':398,'remainingTotal':884,'duplicates':0,'outOfQueueIDs':0,'inputGeometryOrSourceBindingMismatches':0,'reviewedRowsWithReportedLoss':lossrows,'scopeLimits':limits,'perScore':[{k:v for k,v in r.items() if k not in ['remainingBandIDs','source','sourceSHA256']} for r in byScore]}
dump('summary.json',summary); dump('newly-covered-ids.json',additions); dump('remaining-ids-by-score.json',byScore)
dump('previously-covered-ids.json',[{'id':r['id'],'bandID':r['bandID'],'page':r['page'],'receipt':r['receipt']} for r in prior])
dump('input-bindings.json',inputs)
dump('validation.json',{'canonicalPartitionExact':True,'all241NewIDsBelongToCanonical1125':True,'allNewGroupsDisjoint':True,'allNewIDsDisjointFromPrior157':True,'all1282IDsAccountedForExactlyOnce':True,'archivedCanonicalQueueEqualsPrivateQueueByteForByte':True,'receiptHashesMatchTheirPublishedManifests':True,'newlyReviewedSourceRowsMatchCanonicalFields':True,'originalSourceAndInventoryHashesRechecked':True,'193ReuseRowsRetainExactBeforeAfterAndStaffIdentityProof':True})
shutil.copy2(__file__,OUT/'aggregate.py')
readme='''# Monotone crop source-review coverage

**398 of 1,282 changed crops are covered by a source-review receipt; 884 remain pending.** This is coverage accounting, not a pass. The tested cleanup candidate remains ineligible for production promotion.

The immutable original queue had 1,125 pending rows and 157 previously reviewed rows. Exact score-plus-band membership adds 241 distinct rows:

| Review receipt | Added rows |
| --- | ---: |
| Brahms 242312, audit review | 4 |
| Brahms 09200, root review | 12 |
| Schumann 06822, source review version 2 | 32 |
| Brahms 93521, exact reuse of corrected-source review | 193 |
| Total added | 241 |

Every new ID belongs to the original queue. None overlaps another added group or the prior 157. The original queue was read from the hash-verified frozen comparison archive; source bytes, inventory hashes and complete available source-review input records were checked against that queue. The 193 reused rows retain the previous decoded-pixel, staff-assignment and exact old/new rectangle proof. No images were rendered and no native analysis or musical review was rerun here. The Schumann receipt records all 32 context views; its individual `fullSourceViewed` flags are preserved without upgrading context-only observations into whole-page review.

Three reviewed raw-plan rows report lost shared instructions: Coda in Brahms 242312 `p18-s4-violin2`, Andante in Brahms 09200 `p10-s1-violin2`, and the numbered tempo instruction in Brahms 09200 `p22-s1-violin2`. Covered rows include these failures. Crop-only plans, and the path with optional shared-direction recognition off by default, still block cleanup promotion; a separate opt-in recognition fix does not establish safe source preservation for that path.

The broader extraction goal remains open. Nineteen initialized profiles yield no planned bands and need system assignment; 15,712 detected staves remain unassigned across the corpus. Existing neighboring fragments, source omissions and unresolved pages remain. Complete final parts and page turns are not certified by this bookkeeping.

`remaining-ids-by-score.json` is the exact 884-row remaining queue grouped by score. `newly-covered-ids.json` names all 241 added rows with their receipt hashes and recorded verdicts. `previously-covered-ids.json` preserves the 157-row starting partition. `input-bindings.json` and `validation.json` record the source and membership checks; original reports remain unchanged. `aggregate.py` reproduces the accounting from those existing inputs.
'''
(OUT/'README.md').write_text(readme)
manifest={str(p.relative_to(OUT)):{'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size} for p in sorted(OUT.iterdir()) if p.is_file() and p.name!='manifest.json'}
dump('manifest.json',manifest)
for n,r in manifest.items(): assert sha((OUT/n).read_bytes())==r['sha256']
print(json.dumps({'counts':{k:summary[k] for k in ['previouslyCovered','newlyCoveredDistinct','coveredTotal','remainingTotal']},'lossRows':[(r['id'],r['bandID']) for r in lossrows],'report':str(OUT),'manifestSHA256':sha((OUT/'manifest.json').read_bytes()),'readmeSHA256':sha((OUT/'README.md').read_bytes())},indent=2))
