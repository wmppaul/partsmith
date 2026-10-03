from pathlib import Path
import json,hashlib
R=Path('.build/musical-span-attached-addendum-2026-10-03')
base=json.loads((R/'baseline/results.json').read_text());cand=json.loads((R/'candidate-v1/results.json').read_text());logged=json.loads((R/'candidate-v1-witnesses/results.json').read_text())
def strip(x):
 if isinstance(x,dict):return{k:strip(v)for k,v in x.items()if k!='elapsedSeconds'}
 if isinstance(x,list):return[strip(v)for v in x]
 return x
assert strip(cand)==strip(logged)
records=[];pending=None
for line in(R/'candidate-v1-witnesses/run.log').read_text().splitlines():
 if line.startswith('SOURCE_CASE '):assert pending is None;pending=json.loads(line[12:])
 if line.startswith('SOURCE_SPANS '):assert pending is not None;pending['spans']=json.loads(line[13:]);records.append(pending);pending=None
assert pending is None and len(records)==len(base['cases'])==len(cand['cases'])==6
out=[]
for b,c,w in zip(base['cases'],cand['cases'],records):
 for f in ['id','family','scale','sourceRawSHA256','sourceShape','analysisShape']:assert b[f]==c[f]
 assert (b['id'],b['scale'])==(w['id'],w['scale']);assert b['canApply'] and c['canApply']
 for bt,ct in zip(b['targets'],c['targets']):
  for f in ['owner','partID','sourcePixels','sourceEnvelope','sourceMaskSHA256','allowedWholeNeighborIDs']:assert bt[f]==ct[f]
  old=set(bt['lostPixelIndices']);new=set(ct['lostPixelIndices']);env=ct['sourceEnvelope'];crop=ct['crop'];full=crop[0]<=env[0]+1e-9 and crop[1]<=env[1]+1e-9 and crop[2]>=env[2]-1e-9 and crop[3]>=env[3]-1e-9
  out.append({'id':c['id'],'family':c['family'],'scale':c['scale'],'owner':ct['owner'],'sourcePixels':ct['sourcePixels'],'sourceEnvelope':env,'baselineCrop':bt['crop'],'candidateCrop':crop,'baselineLost':len(old),'candidateLost':len(new),'newlyLostPixelIndices':sorted(new-old),'recoveredPixelIndices':sorted(old-new),'fullSourceRetained':not new and full,'baselineSpuriousWholeNeighborIDs':bt['spuriousWholeNeighborCoreIDs'],'candidateSpuriousWholeNeighborIDs':ct['spuriousWholeNeighborCoreIDs'],'newSpuriousWholeNeighborIDs':sorted(set(ct['spuriousWholeNeighborCoreIDs'])-set(bt['spuriousWholeNeighborCoreIDs']))})
report={'sourceScaleCases':6,'ownerObservations':18,'blinding':'Informed by V1, fixed before these results, original29 unchanged.','sourceBindingsEqual':True,'instrumentedResultsSemanticallyEqual':True,'baselineElapsedSeconds':base['elapsedSeconds'],'candidateElapsedSeconds':cand['elapsedSeconds'],'baselineCompleteOwners':sum(x['baselineLost']==0 for x in out),'candidateCompleteOwners':sum(x['candidateLost']==0 for x in out),'newlyLostOwners':sum(bool(x['newlyLostPixelIndices'])for x in out),'newSpuriousNeighborOwnerObservations':sum(bool(x['newSpuriousWholeNeighborIDs'])for x in out),'positiveFullRecoveryOwners':sum(x['family']=='new-musical-span' and x['fullSourceRetained']for x in out),'positiveOwnerObservations':sum(x['family']=='new-musical-span'for x in out),'falseSpanObservations':sum(x['family']=='new-no-shared-span'and bool(x['spans'])for x in records),'owners':out,'spanWitnesses':records}
(R/'comparison.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['owners','spanWitnesses']},indent=2))
