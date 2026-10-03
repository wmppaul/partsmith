import json,pathlib,sys,hashlib
r=pathlib.Path(__file__).parent;file=pathlib.Path(sys.argv[1]);inputs=json.loads((r/'challenge-inputs.json').read_text());results=json.loads(file.read_text());truth={x['id']:x for x in json.loads((r/'source-truth.json').read_text())['scores']};rows=[]
for c,res in zip(inputs,results):
 assert c['id']==res['id'];fail=[]; exp=c['expectation'];ss=res['suggestions'];wrong=[]
 if exp.startswith('noSuggestions') and ss:fail.append('Unexpected suggestions')
 if exp=='noSuggestionsCancelled' and not res['cancelled']:fail.append('Cancellation not marked')
 if exp=='noSourceSupportedAmbiguousChoice' and any(s['confidence']=='sourceSupported' for s in ss):fail.append('Ambiguous identity marked sourceSupported')
 if c['scoreID'] in truth:
  score=truth[c['scoreID']];actual={(p['pageNumber']-1,s['systemNumber']-1):s for p in score['pages'] for s in p['systems']};seeds={(p['pageIndex'],s['systemIndex']) for p in c['overrides'] for s in p['systems'] if s['bands']}
  known=[set(b['partID'] for b in s['bands']) for p in c['overrides'] for s in p['systems'] if s['bands']]
  for s in ss:
   key=(s['pageIndex'],s['systemIndex']);t=actual.get(key);rank=[i+1 for i in s['candidateIDs']];parts={};off=0
   for part in c['profile']['parts']:
    if part['id'] in s['presentPartIDs']:parts[part['id']]=rank[off:off+part['staffCount']];off+=part['staffCount']
   if t is None or t['staffRanksOneBased']!=rank or t['partStaffRanksOneBased']!=parts:wrong.append({'suggestion':s,'source':t})
   if key in seeds:fail.append('Reuses already seeded system')
   if s['startBarNumber'] is not None or s['barCount'] is not None:fail.append('Seed count/start leaked to target')
   if exp=='onlyKnownSourceRoster' and set(s['presentPartIDs']) not in known:fail.append('Unseen roster suggestion')
  if wrong:fail.append('Incorrect/incomplete source system proposed')
 row={'id':c['id'],'expectation':exp,'suggestionCount':len(ss),'sourceSupportedCount':sum(s['confidence']=='sourceSupported' for s in ss),'passed':not fail,'failures':fail,'wrongSourceSuggestions':wrong,'diagnostics':res['diagnostics'],'elapsedSeconds':res['elapsedSeconds']};rows.append(row)
out={'inputSHA256':hashlib.sha256((r/'challenge-inputs.json').read_bytes()).hexdigest(),'resultsSHA256':hashlib.sha256(file.read_bytes()).hexdigest(),'total':len(rows),'passed':sum(x['passed'] for x in rows),'failed':sum(not x['passed'] for x in rows),'rows':rows};file.with_name(file.stem+'-assessment.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({'total':out['total'],'passed':out['passed'],'failed':out['failed'],'failureDetails':[x for x in rows if not x['passed']]},indent=2))
