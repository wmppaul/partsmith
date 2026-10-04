from pathlib import Path
import json, hashlib

w = Path('.build/hear-my-prayer-matcher-2026-10-03')
out = Path('.build/hear-my-prayer-matcher-independent-2026-10-03')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text())
source_path = Path('.build/hear-my-prayer-independent-map-2026-10-03/source-counts-before-comparison.json')
source = read(source_path)
mapping = {'Solo Soprano':'solo-soprano','Chorus Soprano':'chorus-soprano','Alto':'alto','Tenor':'tenor','Bass':'bass','Organ':'organ'}
expected, page, staff = {}, None, 0
for s in source['systems']:
    if s['page'] != page: page, staff = s['page'], 0
    ids = {}
    for part,n in zip(s['roster'],s['staffCounts']):
        ids[mapping[part]] = list(range(staff,staff+n))
        staff += n
    expected[(s['page']-1,s['system']-1)] = ids
seedkeys = set()
for p in read(w/'two-seeds.json'):
    for s in p['systems']:
        k=p['pageIndex'],s['systemIndex']
        seedkeys.add(k)
        assert {b['partID']:b['candidateIDs'] for b in s['bands']} == expected[k]
result, baseline = read(w/'candidate/result.json'), read(w/'result.json')
assert not result['cancelled'] and not baseline['suggestions']
seen, rows = set(), []
for s in result['suggestions']:
    k=s['pageIndex'],s['systemIndex']
    assert k not in seen and k not in seedkeys
    seen.add(k)
    exp=expected[k]
    assert s['presentPartIDs'] == sorted(exp)
    assert s['candidateIDs'] == sorted(x for ids in exp.values() for x in ids)
    assert s['countWasInferred'] is False
    assert s['requiresMeasureCount'] == (len(exp)<6)
    template=s['templatePageIndex'],s['templateSystemIndex']
    assert template in seedkeys and expected[template].keys()==exp.keys()
    rows.append(dict(sourceSystem=f'p{k[0]+1}-s{k[1]+1}',candidateIDs=s['candidateIDs'],
                     presentPartIDs=s['presentPartIDs'],confidence=s['confidence'],requiresOwnMeasureCount=s['requiresMeasureCount']))
assert len(rows)==26
left=sorted(set(expected)-seedkeys-seen)
assert left==[(2,0),(2,1),(2,2),(3,0),(3,1),(3,2)]
a,b=read(w/'baseline-challenge-results.json'),read(w/'candidate-challenge-results.json')
assert len(a)==len(b)==32
caseids=[]
for x,y in zip(a,b):
    assert x['id']==y['id']
    assert {k:v for k,v in x.items() if k!='elapsedSeconds'}=={k:v for k,v in y.items() if k!='elapsedSeconds'}
    caseids.append(x['id'])
for n in ['baseline-challenge-results-assessment.json','candidate-challenge-results-assessment.json']:
    z=read(w/n)
    assert z['passed']==32 and z['failed']==0
old_path=Path('Tests/quality_control/system-template-independent-2026-10-03/evaluation-v2/ScoreSystemTemplateMatcher.swift')
new_path=w/'candidate/ScoreSystemTemplateMatcher.swift'
old_gate='if abs(upper.start - lower.start) <= Int(ceil(space * 0.6)) {'
new_gate='do { // Verify actual connecting ink even when measured staff starts differ.'
assert sha(old_path)=='fe3504a1ba9b86659a6bc5bed37ef1e6424ca4c63d8deb959d45f3ad4a8d2df7'
assert old_path.read_text().count(old_gate)==1
assert old_path.read_text().replace(old_gate,new_gate)==new_path.read_text()
report = dict(
    method='Read-only independent code/source/results audit. No analyzer, matcher, challenge runner or exporter repeated. Expected identities rebuilt from independent original-notation freeze.',
    bindings={str(p):sha(p) for p in [old_path,new_path,source_path,w/'two-seeds.json',w/'candidate/result.json',w/'result.json',w/'baseline-challenge-results.json',w/'candidate-challenge-results.json',w/'all-source-connection-contexts.png',w/'context-index.json']},
    exactOneGateReplacement=True,
    actualSourcePanelsViewed='All nine original connector panels inspected in source contact sheet. Each displays a continuous printed system edge despite bracket-influenced staff-start estimates.',
    directSourceResult=dict(baselineSuggestions=0,candidateSuggestions=26,sourceSupported=sum(x['confidence']=='sourceSupported' for x in rows),needsReview=sum(x['confidence']=='needsReview' for x in rows),allSourceIDsAndRostersCorrect=rows,remainingUnseededSystems=[f'p{p+1}-s{s+1}' for p,s in left],noTargetMeasureCountInferred=True),
    existingChallenges=dict(cases=32,bothPass=32,allSemanticsExactlyEqualExcludingElapsedSeconds=caseids),
    staticFindings=[
        'Bracket-influenced uninterrupted4-of5 horizontal support can shift nominal staff starts; direct printed-connector evidence is more appropriate than rejecting solely on that proxy.',
        'Actual94% full-span occupancy,96% gap occupancy and longest missing run <=max(1,0.4staffspace) remain unchanged. The same x window and x±1 sampling are used. No source ink or crops are changed.',
        'Source/inventory recheck, outside connections, complete-system seeds, whole-page abstention for unmatched groups, clef ambiguity, seed occupancy and nil target measure counts remain unchanged.',
        'Cancellation still discards suggestions on cancelled completion. Individual connection scans remain non-interruptible, but bounded by image dimensions; displaced starts now invoke them too.'
    ],
    limitations=[
        'The existing min/max-start search can be wide for badly displaced estimates; unrelated vertical print or scan borders could imitate a connector. No concrete false suggestion was found here, but these controls do not prove every scan safe.',
        'SourceSupported establishes similarity to explicit reviewed examples, not independent instrument recognition. Suggestions still require acceptance; absent parts need their own bar counts.',
        'Six source systems remain unsuggested. This is assistive improvement, not complete one-button extraction.'
    ],
    verdict='No concrete blocker for exact candidate5d503a one-gate assistive change. No crop-algorithm promotion or broader Auto approval.'
)
(out/'review.json').write_text(json.dumps(report,indent=2)+'\n')
print(sha(out/'review.json'))
