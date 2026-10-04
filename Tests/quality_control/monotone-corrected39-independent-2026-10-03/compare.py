from pathlib import Path
import json, sys, hashlib
from collections import Counter

HERE = Path(__file__).parent
requirements = json.loads((HERE / 'requirements-before-results.json').read_text())
baseline_path = Path('.build/ownership-alternatives-2026-10-03/actual.json')
candidate_path = Path(sys.argv[1])
b = json.loads(baseline_path.read_text())
c = json.loads(candidate_path.read_text())
fresh = set(range(1, 40))

def bands(inv):
    return {a['id']: a for p in inv['plan']['pages'] for a in p['assignments']}

def rect(inv, a):
    p = inv['pages'][a['pageIndex']]
    return [a.get('leftFraction', 0) * p['pageWidth'], a['topFraction'] * p['pageHeight'],
            (1 - a.get('rightFraction', 0)) * p['pageWidth'], a['bottomFraction'] * p['pageHeight']]

def contains(a, z):
    return a[0] <= z[0] + 1e-8 and a[1] <= z[1] + 1e-8 and a[2] >= z[2] - 1e-8 and a[3] >= z[3] - 1e-8

bb, cb = bands(b), bands(c)
out = {'scope': 'Independent all39 original-resolution comparison of monotone nominal plus measured erasure and legacy single-owner envelope support; no source-span helpers.',
       'baselineSHA256': hashlib.sha256(baseline_path.read_bytes()).hexdigest(),
       'candidateSHA256': hashlib.sha256(candidate_path.read_bytes()).hexdigest(),
       'requirementsSHA256': hashlib.sha256((HERE / 'requirements-before-results.json').read_bytes()).hexdigest(),
       'sourceSHAEqual': b['sourceSHA256'] == c['sourceSHA256'] if 'sourceSHA256' in c else None,
       'correctionsExact': b['rectifications'] == c['rectifications'] if 'rectifications' in c else None,
       'allBandIDsExact': list(bb) == list(cb), 'pages': [], 'guardChecks': [], 'changedBands': []}

for bp, cp, bplan, cplan in zip(b['pages'], c['pages'], b['plan']['pages'], c['plan']['pages']):
    pn = bp['pageIndex'] + 1
    bs, cs = bp['staves'], cp['staves']
    deltas = []
    for x, y in zip(bs, cs):
        deltas.append({'idBefore': x['id'], 'idAfter': y['id'],
                       'linesDeltaPt': [(v-u) * bp['pageHeight'] for u, v in zip(x['staffLineFractions'], y['staffLineFractions'])]})
    counts = Counter(i for a in cplan['assignments'] for i in a['candidateIDs'])
    identities = lambda pp: [(a['id'], a['partID'], a['pageIndex'], a['systemIndex'], a['candidateIDs']) for a in pp['assignments']]
    out['pages'].append({'page': pn, 'fresh': pn in fresh, 'analysisExact': bp == cp, 'staffRecordsExact': bs == cs,
                         'dimensionsExact': [bp['pageWidth'],bp['pageHeight']] == [cp['pageWidth'],cp['pageHeight']],
                         'imageDimensionsBefore': [bp['imageWidth'], bp['imageHeight']],
                         'imageDimensionsAfter': [cp['imageWidth'], cp['imageHeight']],
                         'staffCountBefore': len(bs), 'staffCountAfter': len(cs), 'staffLineDeltas': deltas,
                         'assignmentIdentitiesExact': identities(bplan) == identities(cplan),
                         'eachObservedStaffAssignedOnce': counts == Counter({s['id']: 1 for s in cs}),
                         'unresolvedBefore': bplan['unresolvedReasons'], 'unresolvedAfter': cplan['unresolvedReasons']})

for key in bb.keys() & cb.keys():
    br, cr = rect(b, bb[key]), rect(c, cb[key])
    if br != cr:
        out['changedBands'].append({'bandID': key, 'before': br, 'after': cr,
                                    'removedTopPt': max(0, cr[1] - br[1]), 'removedBottomPt': max(0, br[3] - cr[3])})
out['changedBands'].sort(key=lambda r: (bb[r['bandID']]['pageIndex'], bb[r['bandID']]['systemIndex'], bb[r['bandID']]['candidateIDs']))
for guard in requirements['guards']:
    key = guard['bandID']
    br, cr = rect(b, bb[key]), rect(c, cb[key])
    out['guardChecks'].append(dict(guard, before=br, after=cr, containedBefore=contains(br, guard['rect']), containedAfter=contains(cr, guard['rect'])))

out['summary'] = {'totalBands': [len(bb),len(cb)], 'freshPages': len(fresh),
                  'changedBands': len(out['changedBands']),
                  'reducedBands': sum(x['removedTopPt']>0 or x['removedBottomPt']>0 for x in out['changedBands']),
                  'unchangedRetainedAnalyses': sum(not p['fresh'] and p['analysisExact'] for p in out['pages']),
                  'guardCount': len(out['guardChecks']),
                  'baselineGuardPasses': sum(g['containedBefore'] for g in out['guardChecks']),
                  'candidateGuardPasses': sum(g['containedAfter'] for g in out['guardChecks']),
                  'newGuardFailures': [g for g in out['guardChecks'] if g['containedBefore'] and not g['containedAfter']],
                  'allStaffRecordsExact': all(p['staffRecordsExact'] for p in out['pages']),
                  'allAssignmentIdentitiesExact': all(p['assignmentIdentitiesExact'] for p in out['pages']),
                  'allObservedStaffAssignedOnce': all(p['eachObservedStaffAssignedOnce'] for p in out['pages']),
                  'newUnresolvedPages': [p['page'] for p in out['pages'] if p['unresolvedAfter'] and p['unresolvedBefore'] != p['unresolvedAfter']]}
(HERE / 'comparison.json').write_text(json.dumps(out,indent=2) + '\n')
print(json.dumps(out['summary'],indent=2))
