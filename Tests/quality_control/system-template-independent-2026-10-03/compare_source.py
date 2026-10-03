import json,pathlib,hashlib,sys
root=pathlib.Path(__file__).parent
run=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else root/'evaluation-v1'
truth=json.loads((root/'source-truth.json').read_text()); out={'scope':'Complete-source initialization identity, not crop or finished-output certification','scores':[],'failures':[]}
for score in truth['scores']:
 d=run/score['id'];inventory=json.loads((d/'inventory.json').read_text());profile=json.loads((d/'profile.json').read_text());seeds=json.loads((d/'templates.json').read_text());results=json.loads((d/'result.json').read_text())
 maps={};error=0.; ge=[]
 for p in score['pages']:
  pi=p['pageNumber']-1; det=next(x for x in inventory['pages'] if x['pageIndex']==pi); mp={};used=[]
  for s in det['staves']:
   ys=[x*p['height'] for x in s['staffLineFractions']]
   distances=[max(abs(a-b) for a,b in zip(ys,t['lineYs'])) for t in p['sourceStaffs']]; k=min(range(len(distances)),key=distances.__getitem__); delta=distances[k];error=max(error,delta)
   if delta>1.:ge.append({'page':pi+1,'id':s['id'],'maximumLineErrorPt':delta})
   rank=p['sourceStaffs'][k]['rankOneBased'];mp[s['id']]=rank;used.append(rank)
  if len(set(used))!=len(used) or sorted(used)!=[s['rankOneBased'] for s in p['sourceStaffs']]:ge.append({'page':pi+1,'staffMappingMismatch':used})
  maps[pi]=mp
 actual={(p['pageNumber']-1,s['systemNumber']-1):s for p in score['pages'] for s in p['systems']};seen={};sr=[]
 def record(pi,si,ids,roster,kind,partmap=None):
  key=(pi,si); ranks=[maps[pi][i] for i in ids];t=actual.get(key);valid=t is not None and ranks==t['staffRanksOneBased'] and set(roster)==set(t['roster'])
  if partmap is None:
   partmap={};off=0
   for part in profile['parts']:
    if part['id'] in roster: partmap[part['id']]=ranks[off:off+part['staffCount']];off+=part['staffCount']
  valid=valid and partmap==t['partStaffRanksOneBased']
  row={'page':pi+1,'system':si+1,'kind':kind,'sourceRanks':ranks,'partStaffRanks':partmap,'correctWholeSourceSystem':valid}
  if t:row.update(sourceStart=t['startBarNumber'],sourceBarCount=t['barCount'],sourceOmitted=t['missingParts'])
  if key in seen:row['duplicate']=True;valid=False
  seen[key]=row;sr.append(row)
  if not valid:out['failures'].append({'score':score['id'],**row})
 for p in seeds:
  for s in p['systems']:
   bands=[b for b in s['bands'] if b.get('kind','music')=='music']
   if not bands:continue
   roster=[b['partID'] for b in bands];ids=[i for part in profile['parts'] for b in bands if b['partID']==part['id'] for i in b['candidateIDs']];pm={b['partID']:[maps[p['pageIndex']][i] for i in b['candidateIDs']] for b in bands}
   record(p['pageIndex'],s['systemIndex'],ids,roster,'reviewedSeed',pm)
   t=actual[(p['pageIndex'],s['systemIndex'])];assert set(x['partID'] for x in s.get('omittedParts',[]))==set(t['missingParts'])
 for s in results['suggestions']:
  record(s['pageIndex'],s['systemIndex'],s['candidateIDs'],s['presentPartIDs'],'suggestion')
  row=sr[-1];row.update(confidence=s['confidence'],requiresMeasureCount=s['requiresMeasureCount'],templatePage=s['templatePageIndex']+1,templateSystem=s['templateSystemIndex']+1)
  assert bool(row['sourceOmitted'])==s['requiresMeasureCount']
 omitted=[{'page':p+1,'system':i+1,**s} for (p,i),s in actual.items() if (p,i) not in seen]
 out['scores'].append({'id':score['id'],'sourceSystems':len(actual),'sourceStaves':sum(len(p['sourceStaffs']) for p in score['pages']),'maximumObservedStaffLineErrorPt':error,'geometryFailures':ge,'seedCount':sum(r['kind']=='reviewedSeed' for r in sr),'suggestionCount':len(results['suggestions']),'sourceSupported':sum(s['confidence']=='sourceSupported' for s in results['suggestions']),'coveredSystems':len(seen),'unresolvedSystems':len(omitted),'suggestedCountPendingSystems':sum(s['requiresMeasureCount'] for s in results['suggestions']),'observations':sr,'unresolved':omitted,'diagnostics':results['diagnostics']})
 out['failures'] += [{'score':score['id'],**x} for x in ge]
out['totals']={k:sum(s[k] for s in out['scores']) for k in ['sourceSystems','sourceStaves','seedCount','suggestionCount','sourceSupported','coveredSystems','unresolvedSystems','suggestedCountPendingSystems']}
out['bindings']={'sourceTruthSHA256':hashlib.sha256((root/'source-truth.json').read_bytes()).hexdigest(),'files':{str(p.relative_to(run)):hashlib.sha256(p.read_bytes()).hexdigest() for p in run.rglob('*') if p.is_file() and p.name!='source-comparison.json'}}
(run/'source-comparison.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({'totals':out['totals'],'failures':out['failures'],'scores':[{k:s[k] for k in ['id','maximumObservedStaffLineErrorPt','coveredSystems','unresolvedSystems','suggestedCountPendingSystems']} for s in out['scores']]},indent=2))
