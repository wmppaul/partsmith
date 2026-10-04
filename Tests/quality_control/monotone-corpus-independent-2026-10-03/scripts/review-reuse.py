from pathlib import Path
import json,hashlib,collections
R=Path('.build/monotone-corpus-independent-2026-10-03');P=Path('.build/envelope-corpus-independent-2026-10-03');read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();cur=read(R/'comparison.json');prev=read(P/'comparison.json');base=read(R/'baseline-binding.json');sources={r['id']:r for r in base['rows']};oldRows={r['id']:r for r in prev['rows']};nowRows={r['id']:r for r in cur['rows']};prior={};direct={};bindings=[]
def bind(p):bindings.append({'path':str(p),'sha256':sha(p)})
p=Path('Tests/quality_control/envelope-corpus-two-score-source-review-2026-10-03/review.json');rev=read(p);bind(p)
for score in rev['scores']:
 sid=score['id'];assert score['sourceSHA256']==sources[sid]['sourceSHA256']
 for row in score['reviewedRows']:prior[(sid,row['bandID'])]={'before':row['before'],'after':row['after'],'reviewer':'crop_algorithm_audit','receipt':str(p),'contextSHA256':row['contextSHA256']}
p=Path('.build/envelope-compatibility-corpus-2026-10-03/root-schumann-source-review.json');rev=read(p);bind(p);sid='lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922'
for row in rev['rows']:
 assert row['sourceSHA256']==sources[sid]['sourceSHA256'];old=next(b for b in oldRows[sid]['changedBands']if b['bandID']==row['band']);assert [old['beforePDFBounds'][i]for i in [1,3]]==row['oldY'] and [old['afterPDFBounds'][i]for i in [1,3]]==row['newY'];prior[(sid,row['band'])]={'before':old['beforePDFBounds'],'after':old['afterPDFBounds'],'reviewer':'root','receipt':str(p),'contextSHA256':row['contextSHA256']}
p=Path('.build/numbered-line-monotone-compatibility-2026-10-03/root-three-page-review/review.json');rev=read(p);bind(p);sid='lightly-skewed-10-brahms-string-quartet-no3-op67-imslp-242312';assert rev['sourcePDFSHA256']==sources[sid]['sourceSHA256'];assert sha('.build/numbered-line-monotone-compatibility-2026-10-03/source-comparison.json')==rev['sourceComparisonSHA256']
for row in rev['rows']:
 panel=p.parent/(row['bandID']+'.png');assert sha(panel)==row['contextSHA256'];candidate=next(b for b in nowRows[sid]['changedBands']if b['bandID']==row['bandID']);assert [candidate['beforePDFBounds'][i]for i in [1,3]]==row['oldY'] and [candidate['afterPDFBounds'][i]for i in [1,3]]==row['newY']
 # Full-native result also matches the independently bound frozen-staff replay on all semantic assignment fields.
 frozen=read(p.parent.parent/'source-observer'/f"p{row['page']}"/'plan.json');f=next(b for b in frozen['pages'][0]['assignments']if b['id']==row['bandID']);assert candidate['after']==f
 direct[(sid,row['bandID'])]={'reviewer':'root','receipt':str(p),'contextSHA256':row['contextSHA256']}
reviewed=[];pending=[];previousReviewedButChanged=[];stats=[]
for score in cur['rows']:
 sid=score['id'];ss=sources[sid];count=collections.Counter()
 for band in score['changedBands']:
  if not band.get('geometryChanged'):continue
  key=(sid,band['bandID']);receipt=None;method=None
  if key in direct:receipt=direct[key];method='new native candidate source review, exact fresh full-worker assignment equality'
  elif key in prior:
   r=prior[key];old=next(b for b in oldRows[sid]['changedBands']if b['bandID']==band['bandID'])
   if r['before']==band['beforePDFBounds'] and r['after']==band['afterPDFBounds'] and old['before']['candidateIDs']==band['before']['candidateIDs'] and old['after']['candidateIDs']==band['after']['candidateIDs'] and old['before']['partID']==band['before']['partID'] and old['after']['partID']==band['after']['partID']:
    receipt=r;method='exact same source, ownership, before crop and after crop as prior reviewed source area'
   else:previousReviewedButChanged.append({'id':sid,'bandID':band['bandID'],'prior':r,'currentBefore':band['beforePDFBounds'],'currentAfter':band['afterPDFBounds']})
  if receipt:
   reviewed.append({'id':sid,'bandID':band['bandID'],'page':band['page'],'method':method,**receipt});count['reviewed']+=1
  else:
   pending.append({'id':sid,'source':ss['source'],'sourceSHA256':ss['sourceSHA256'],'profile':ss['profile'],'inventoryFiles':score['files'],**band});count['pending']+=1
  count['changed']+=1
 stats.append({'id':sid,**count})
result={'sourceReviewReferences':bindings,'summary':{'changedCrops':len(reviewed)+len(pending),'exactPriorReviewReuse':sum(x['method'].startswith('exact same')for x in reviewed),'newCandidateReviewedSourceRows':sum(x['method'].startswith('new native')for x in reviewed),'reviewedTotal':len(reviewed),'pending':len(pending),'priorReviewedRowsWithDifferentGeometryNeedingNewReview':len(previousReviewedButChanged),'newWholeForeignRelations':cur['summary']['newForeignIDRelations'],'limits':'Geometry comparison is complete, visual source coverage is not. Reuse never relies on similar words, aggregate counts, or source identity alone; both exact crops and staff ownership must match. No exported part/PDF/pagination review in this comparison.'},'reviewed':reviewed,'perScore':stats,'priorReviewedButDifferentGeometry':previousReviewedButChanged}
(R/'source-review-reuse.json').write_text(json.dumps(result,indent=2)+'\n');(R/'pending-changed-crop-review.json').write_text(json.dumps(pending,indent=2)+'\n');print(json.dumps(result['summary'],indent=2))
