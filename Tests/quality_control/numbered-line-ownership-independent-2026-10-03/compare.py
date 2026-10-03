"""Compare exact source-owned pixel sets; never adjust an oracle from crops."""
import hashlib,json,sys
from pathlib import Path
baseline=json.loads(Path(sys.argv[1]).read_text())['cases'];candidate=json.loads(Path(sys.argv[2]).read_text())['cases']
def key(x):return x['id'],x['scale']
a={key(x):x for x in baseline};b={key(x):x for x in candidate};assert set(a)==set(b) and len(a)==48
changes=[];regressions=[];invariants=[];positive=[]
for k in sorted(a):
 old,new=a[k],b[k]
 for field in ['id','family','scale','sourceRawSHA256','sourceShape','analysisShape']:assert old[field]==new[field],(k,field)
 assert len(old['targets'])==len(new['targets'])==4
 assert [t['owner'] for t in old['targets']]==[t['owner'] for t in new['targets']]==[0,1,2,3]
 if not new['analysisReturned'] or not new['canApply'] or new['bandCount']!=4 or any(t['candidateIDs']!=[t['owner']] for t in new['targets']):invariants.append(k)
 for before,after in zip(old['targets'],new['targets']):
  for field in ['owner','partID','sourcePixels','sourceEnvelope','sourceMaskSHA256']:assert before[field]==after[field],(k,field)
  previous=set(before['lostPixelIndices']);now=set(after['lostPixelIndices']);assert len(previous)==before['lostPixels'] and len(now)==after['lostPixels']
  added=sorted(now-previous);recovered=sorted(previous-now)
  item={'id':k[0],'scale':k[1],'owner':before['owner'],'baselineLost':len(previous),'candidateLost':len(now),'newlyLostPixelIndices':added,'recoveredPixelIndices':recovered,'beforeCrop':before['crop'],'afterCrop':after['crop']}
  if before!=after:changes.append(item)
  if added:regressions.append(item)
 if new['family']=='new-structural':
  def success(x):return x['analysisReturned'] and x['canApply'] and x['bandCount']==4 and all(t['lostPixels']==0 and not t['wholeNeighborCoreIDs'] for t in x['targets'])
  positive.append({'id':k[0],'scale':k[1],'baselineSeparatedAndPreserved':success(old),'candidateSeparatedAndPreserved':success(new)})
summary={'sourceScaleCases':len(a),'sourceBindingsEqual':True,'candidateInvariantFailures':invariants,'newlyLostOwnerObservations':regressions,'changedOwnerObservations':changes,'structuralSeparation':positive,'baselineZeroLossOwners':sum(t['lostPixels']==0 for x in baseline for t in x['targets']),'candidateZeroLossOwners':sum(t['lostPixels']==0 for x in candidate for t in x['targets']),'note':'Existing losses remain failures of their unchanged source oracle. A changed count alone cannot hide loss at a new pixel. Typed graph payload reconstruction is a separate audit, not established by crop containment.'}
Path(sys.argv[3]).write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k not in ['newlyLostOwnerObservations','changedOwnerObservations','structuralSeparation']},indent=2))
print('newly lost owner observations',len(regressions))
