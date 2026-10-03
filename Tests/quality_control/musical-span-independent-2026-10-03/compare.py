"""Source-owned musical span assessment; no output-derived ownership oracle."""
import json,sys
from pathlib import Path
base=json.loads(Path(sys.argv[1]).read_text())['cases'];candidate=json.loads(Path(sys.argv[2]).read_text())['cases'];key=lambda x:(x['id'],x['scale']);a={key(x):x for x in base};b={key(x):x for x in candidate};assert set(a)==set(b) and len(a)==29
regressions=[];recoveries=[];changed=[];spurious=[];invalid=[];negativeEvidence=[];case176=None
for k in sorted(a):
 old,new=a[k],b[k]
 for field in ['id','family','scale','sourceRawSHA256','sourceShape','analysisShape']:assert old[field]==new[field],(k,field)
 assert len(old['targets'])==len(new['targets']) and len(new['targets']) in [3,4]
 assert [t['owner'] for t in old['targets']]==[t['owner'] for t in new['targets']]==list(range(len(new['targets'])))
 if not new['analysisReturned'] or not new['canApply'] or new['bandCount']!=len(new['targets']) or any(t['candidateIDs']!=[t['owner']] for t in new['targets']):invalid.append(k)
 for before,after in zip(old['targets'],new['targets']):
  for field in ['owner','partID','sourcePixels','sourceEnvelope','sourceMaskSHA256','allowedWholeNeighborIDs']:assert before[field]==after[field],(k,field)
  past=set(before['lostPixelIndices']);now=set(after['lostPixelIndices']);assert len(past)==before['lostPixels'] and len(now)==after['lostPixels']
  added=sorted(now-past);repaired=sorted(past-now)
  item={'id':k[0],'scale':k[1],'owner':before['owner'],'sourcePixels':before['sourcePixels'],'baselineLost':len(past),'candidateLost':len(now),'newlyLostPixelIndices':added,'recoveredPixelIndices':repaired,'beforeCrop':before['crop'],'afterCrop':after['crop']}
  if before!=after:changed.append(item)
  if added:regressions.append(item)
  if repaired:recoveries.append(item)
  oldn=set(before['spuriousWholeNeighborCoreIDs']);newn=set(after['spuriousWholeNeighborCoreIDs'])
  if oldn or newn:spurious.append({'id':k[0],'scale':k[1],'owner':before['owner'],'baselineSpuriousWholeNeighborIDs':sorted(oldn),'candidateSpuriousWholeNeighborIDs':sorted(newn),'newSpuriousWholeNeighborIDs':sorted(newn-oldn)})
  if k[0]=='original-case176' and before['owner']==1:
   env=after['sourceEnvelope'];crop=after['crop'];contains=crop[0]<=env[0]+1e-9 and crop[1]<=env[1]+1e-9 and crop[2]>=env[2]-1e-9 and crop[3]>=env[3]-1e-9
   assert env==[218,190,609,539] and before['sourcePixels']==1400
   case176={**item,'requiredEnvelope':env,'fullEnvelopeRetained':contains,'fullPixelRecovery':not now,'targetAlgorithmClaimSatisfied':contains and not now,'note':'Restoring the nine V2 losses or baseline crop is not full recovery.'}
 if new['family']=='new-no-shared-span':
  def alternatives(x):return [c for c in x['components'] if c.get('isOwnershipAlternative') is True and len(set(c['staffIDs']))>1]
  prev=alternatives(old);cur=alternatives(new)
  newEvidence=[c for c in cur if c not in prev]
  negativeEvidence.append({'id':k[0],'scale':k[1],'baselineMultiOwnerAlternatives':prev,'candidateMultiOwnerAlternatives':cur,'newMultiOwnerAlternatives':newEvidence,'allSourcePixelsRetained':all(t['lostPixels']==0 for t in new['targets']),'noSpuriousWholeNeighbors':all(not t['spuriousWholeNeighborCoreIDs'] for t in new['targets']),'note':'This checks exposed ScoreInkComponent alternatives. Any separate internal musical-span records require an additional source-evidence audit.'})
assert case176 is not None
summary={'sourceScaleCases':29,'ownerObservations':sum(len(x['targets']) for x in candidate),'sourceBindingsEqual':True,'invariantFailures':invalid,'newlyLostOwnerObservations':regressions,'recoveredOwnerObservations':recoveries,'changedOwnerObservations':changed,'spuriousWholeNeighbors':spurious,'negativeSourceEvidence':negativeEvidence,'case176':case176,'baselineCompleteOwners':sum(t['lostPixels']==0 for x in base for t in x['targets']),'candidateCompleteOwners':sum(t['lostPixels']==0 for x in candidate for t in x['targets']),'note':'Source-owner masks and permitted shared groups were fixed before candidate inspection. Existing losses remain failures; original masked pixels remain the oracle.'}
Path(sys.argv[3]).write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n');print(json.dumps({'cases':29,'owners':summary['ownerObservations'],'newlyLostOwners':len(regressions),'recoveredOwners':len(recoveries),'fullCase176TargetRecovered':case176['targetAlgorithmClaimSatisfied'],'candidateCompleteOwners':summary['candidateCompleteOwners'],'newSpuriousNeighborObservations':sum(bool(x['newSpuriousWholeNeighborIDs']) for x in spurious)},indent=2))
