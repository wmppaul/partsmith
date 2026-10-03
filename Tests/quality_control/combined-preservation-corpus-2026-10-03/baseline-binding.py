#!/usr/bin/env python3
"""Read-only independent binding for the36-score production82 raw baseline."""
from pathlib import Path
import collections,hashlib,json,subprocess
import pymupdf
ROOT=Path.cwd();OUT=ROOT/'Tests/quality_control/combined-preservation-corpus-2026-10-03';OLD=ROOT/'.build/residual9-boundary-2026-10-03';SNAP=OLD/'candidate-v2'
read=lambda p:json.loads(Path(p).read_text())
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
roster=read(OLD/'corpus-v2-inputs.json');assert len(roster)==36 and len({x['id'] for x in roster})==36
status=read(OLD/'corpus-v2-status.json');assert status['complete'];states={x['id']:x for x in status['results']};assert len(states)==36
current=read(ROOT/'Tests/quality_control/corpus.json');currentByID={x['id']:x for x in current['scores']};assert set(currentByID)=={x['id'] for x in roster}
actual={p.resolve() for folder in ['sample_scores','Tests/extraction/sources'] for p in (ROOT/folder).rglob('*.pdf')};assert actual=={Path(x['source']).resolve() for x in roster}
manifest=read(SNAP/'source-hashes.json');assert len(manifest)==23
for relative,digest in manifest.items():assert sha(SNAP/relative)==digest
compiled=['StaffBandDetector.swift','ScoreExtractionPlanner.swift','ScoreSharedEnding.swift','ScoreSharedEndingDetector.swift','ScoreLocalEndingPreservation.swift','NativeScorePageAnalyzer.swift']
compiledSources=[]
for name in compiled:
 rel='Partsmith/Core/Detection/'+name;blob=subprocess.check_output(['git','show','82b606e:'+rel]);expected=hashlib.sha256(blob).hexdigest();path=SNAP/'Core/Detection'/name
 assert sha(path)==expected
 compiledSources.append({'path':str(path),'sha256':expected,'matchesCommit':'82b606e','gitPath':rel})
assert compiledSources[-1]['sha256']=='e6541355b65590e66b9f893a12a12f1d66e73f82ebc328436dbb3d52bcd0a353'
binaryHash=sha(SNAP/'existing755');rows=[]
for item in roster:
 s=states[item['id']];catalog=currentByID[item['id']];source=Path(item['source']);profile=Path(item['profile']);dest=SNAP/'corpus'/(item['id']+'.json')
 assert s['variant']=='candidate-v2' and s['exitCode']==0 and s['binarySHA256']==binaryHash and sha(dest)==s['outputSHA256']
 assert sha(source)==item['sourceSHA256']==s['sourceSHA256']==catalog['sha256']
 assert sha(profile)==item['profileSHA256']==s['profileSHA256'];assert item['pages']==s['pages']==catalog['pageCount']==len(pymupdf.open(source))
 d=read(dest);p=read(profile);assert [x['pageIndex'] for x in d['pages']]==[x['pageIndex'] for x in d['plan']['pages']]==list(range(item['pages']))
 partIDs={x['id'] for x in p['parts']};seen=set();unassigned=0
 for pg,pp in zip(d['pages'],d['plan']['pages']):
  staffIDs={x['id'] for x in pg['staves']};assert len(staffIDs)==len(pg['staves']);owners=set()
  for b in pp['assignments']:
   assert b['id'] not in seen and b['partID'] in partIDs and b['pageIndex']==pg['pageIndex'] and set(b['candidateIDs'])<=staffIDs
   seen.add(b['id']);owners.update(b['candidateIDs'])
  unassigned+=len(staffIDs-owners)
 rows.append({**item,'baseline':str(dest),'baselineSHA256':sha(dest),'bands':len(seen),'requiresSystemAssignment':p.get('requiresSystemAssignment',False),'pagesWithAssignments':sum(bool(x['assignments']) for x in d['plan']['pages']),'pagesWithUnresolvedReasons':sum(bool(x['unresolvedReasons']) for x in d['plan']['pages']),'detectedStaves':sum(len(x['staves']) for x in d['pages']),'unassignedStaves':unassigned})
summary={'scores':36,'pages':sum(x['pages'] for x in rows),'bands':sum(x['bands'] for x in rows),'scoresWithBands':sum(x['bands']>0 for x in rows),'scoresWithoutBands':sum(x['bands']==0 for x in rows),'variableProfileScores':sum(x['requiresSystemAssignment'] for x in rows),'variableProfilePages':sum(x['pages'] for x in rows if x['requiresSystemAssignment']),'pagesWithAssignments':sum(x['pagesWithAssignments'] for x in rows),'pagesWithUnresolvedReasons':sum(x['pagesWithUnresolvedReasons'] for x in rows),'detectedStaves':sum(x['detectedStaves'] for x in rows),'unassignedStaves':sum(x['unassignedStaves'] for x in rows)}
assert summary=={'scores':36,'pages':1477,'bands':6936,'scoresWithBands':17,'scoresWithoutBands':19,'variableProfileScores':19,'variableProfilePages':976,'pagesWithAssignments':490,'pagesWithUnresolvedReasons':987,'detectedStaves':23801,'unassignedStaves':15712}
files=[OLD/'corpus-v2-inputs.json',OLD/'corpus-v2-status.json',SNAP/'source-hashes.json',SNAP/'existing755',OLD/'existing755.swift',ROOT/'Tests/quality_control/corpus.json']
(OUT/'baseline-binding.json').write_text(json.dumps({'summary':summary,'compiledSources':compiledSources,'files':[{'path':str(p),'sha256':sha(p)} for p in files],'rows':rows,'rawSourcePages':True,'savedBrahmsRectificationsApplied':False,'scope':'Raw full36 baseline; unresolved assignments are retained as unresolved. Six compiledCore source files match production82; other snapshotfiles merely bound, not claimed compiled.'},indent=2)+'\n')
print(json.dumps(summary,indent=2))
