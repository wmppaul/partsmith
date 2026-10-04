from pathlib import Path
import hashlib,json,shutil
D=Path('Tests/quality_control/divisi-notte-legacy-delta-2026-10-03')
I=Path('Tests/quality_control/system-template-independent-2026-10-03/challenge-inputs.json');T=I.with_name('source-truth.json')
R=Path('.build/divisi-assignment-release-v2-2026-10-03');N=R/'challenges/results.json';P=Path('.build/hear-my-prayer-matcher-2026-10-03/candidate-challenge-results.json')
read=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
id='notte-changed-profile-count';case=next(r for r in read(I)if r['id']==id);result=next(r for r in read(N)if r['id']==id)
truth=next(r for r in read(T)['scores']if r['id']==case['scoreID']);gold=truth['pages'][0];source=Path(case['sourcePath']);render=Path(gold['sourceRender'])
assert sha(I)=='6600e6b304757b0580fd773bbd87b71f3791376e53a45d0ca5fe9cae27c524b4'
assert sha(source)==truth['sourceSHA256'] and sha(render)==gold['sourceRenderSHA256']
assert case['expectation']=='noSuggestions' and len(result['suggestions'])==3
assert case['profile']['parts'][1]['staffCount']==3
page=case['pages'][0];ordered=sorted(page['staves'],key=lambda s:s['staffLineFractions'][0]);assert len(ordered)==len(gold['sourceStaffs'])==13
maxpt=max(abs(a*page['pageHeight']-b)for s,g in zip(ordered,gold['sourceStaffs'])for a,b in zip(s['staffLineFractions'],g['lineYs']))
assert maxpt<=page['pageHeight']/page['imageHeight']
rankToID={i+1:r['id']for i,r in enumerate(ordered)};rows=[]
for s in result['suggestions']:
 seedPage=next(p for p in case['overrides']if p['pageIndex']==s['templatePageIndex']);seed=next(x for x in seedPage['systems']if x['systemIndex']==s['templateSystemIndex'])
 counts={b['partID']:len(b['candidateIDs'])for b in seed['bands']if b.get('kind','music')=='music'}
 expected=gold['systems'][s['systemIndex']];groups={};offset=0
 for p in case['profile']['parts']:
  if p['id'] in s['presentPartIDs']:
   count=counts[p['id']];groups[p['id']]=s['candidateIDs'][offset:offset+count];offset+=count
 truegroups={part:[rankToID[x]for x in ranks]for part,ranks in expected['partStaffRanksOneBased'].items()}
 assert offset==len(s['candidateIDs']) and groups==truegroups
 assert s['candidateIDs']==[rankToID[x]for x in expected['staffRanksOneBased']]
 assert sorted(s['presentPartIDs'])==sorted(expected['roster'])
 assert s['requiresMeasureCount']==bool(expected['missingParts']) and s['barCount'] is None and s['startBarNumber'] is None
 rows.append({'physicalPage':1,'systemNumber':s['systemIndex']+1,'candidateIDs':s['candidateIDs'],'staffCountsDerivedFromLinkedReviewedSeed':counts,'derivedPartStaffIDs':groups,'independentGoldenPartStaffIDs':truegroups,'sourceRanksOneBased':expected['partStaffRanksOneBased'],'correctSourceOwnership':True,'requiresOwnMeasureCount':s['requiresMeasureCount'],'barCountAndStartRemainNil':True,'frozenGoldenSpanForSourceIdentificationOnly':{'start':expected['startBarNumber'],'count':expected['barCount']}})
def norm(x):return{k:v for k,v in x.items()if k!='elapsedSeconds'}
old={r['id']:norm(r)for r in read(P)};new={r['id']:norm(r)for r in read(N)};same=[k for k in old if old[k]==new[k]];changed=[k for k in old if old[k]!=new[k]]
assert len(same)==30 and set(changed)=={'mendelssohn-p2-subgroup-1,2',id}
a='mendelssohn-p2-subgroup-1,2';assert old[a]['suggestions']==new[a]['suggestions']==[] and old[a]['cancelled']==new[a]['cancelled']==False
assessment=read(R/'challenges/results-assessment.json');assert assessment['passed']==31 and assessment['failed']==1
bindings=[I,T,N,P,R/'challenges/protocol-before-results.json',R/'challenges/results-assessment.json',R/'challenges/prior-release-comparison.json',source,render,R/'source-hashes.json',R/'Partsmith/Core/Detection/ScoreSystemTemplateMatcher.swift',R/'Partsmith/Features/Project/ScoreSystemTemplatePanel.swift',Path('Tests/quality_control/system-staff-count-independent-2026-10-03/manifest.json')]
out={'scope':'Read-only source, frozen result and code audit; no new matcher/native run. Original page render directly viewed before accepting the derived part groups.','caseID':id,'oldExpectation':'noSuggestions','oldExpectationStillFails':True,'historicalSuite':{'total':32,'oldExpectationsPassing':31,'oldExpectationsFailing':1,'fullSemanticsIdenticalExcludingTiming':30,'additionalDiagnosticOnlyDelta':a,'assignmentOutcomesUnchanged':31},'verdict':'Intentional, source-correct new local-count behavior for these three proposals; not a 32/32 old-suite pass.','countObservationLimit':'The unchanged historical harness does not serialize Suggestion.staffCounts. Counts here are derived from the exact linked reviewed seed, consistent with frozen matcher construction and UI forwarding code. Separate 49 native controls verify actual count-field forwarding. This audit does not claim new runtime serialization.','sourceMaxLinePositionErrorPt':maxpt,'sourceLinePositionToleranceOneNativePixelPt':page['pageHeight']/page['imageHeight'],'rows':rows,'diagnosticOnlyChange':{'before':old[a]['diagnostics'],'after':new[a]['diagnostics'],'bothAbstain':True},'limits':['Only Notte physical page 1 source ownership reviewed here.','No new crop or output layout review; proposals still require user acceptance.','Piano-only target retains absent Voice and requires its own count; no silence duration is copied.'],'bindings':[{'path':str(p),'sha256':sha(p)}for p in bindings]}
(D/'review.json').write_text(json.dumps(out,indent=2)+'\n')
(D/'case-input.json').write_text(json.dumps(case,indent=2)+'\n');(D/'case-result.json').write_text(json.dumps(result,indent=2)+'\n')
shutil.copy2(render,D/'original-page-1.png')
print(json.dumps({'rows':len(rows),'fullSemanticMatches':len(same),'maxLineErrorPt':maxpt,'reviewSHA256':sha(D/'review.json')}))
