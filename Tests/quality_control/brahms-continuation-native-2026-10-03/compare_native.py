from pathlib import Path
import hashlib
import json

work = Path(__file__).resolve().parent


def load(variant, suffix):
    path = work / variant / ('brahms-' + suffix + '.json')
    return json.loads(path.read_text())


def diffs(a, b, path=''):
    if type(a) is not type(b):
        return [{'path': path, 'before': a, 'after': b}]
    if isinstance(a, dict):
        result = []
        for key in sorted(a.keys() | b.keys()):
            result.extend(diffs(a.get(key), b.get(key), path + '/' + key))
        return result
    if isinstance(a, list):
        if len(a) != len(b):
            return [{'path': path, 'beforeCount': len(a), 'afterCount': len(b)}]
        return [d for i, (x, y) in enumerate(zip(a, b)) for d in diffs(x, y, path + '/' + str(i))]
    return [] if a == b else [{'path': path, 'before': a, 'after': b}]


a, b = (load(v, 'inventory') for v in ['baseline', 'candidate'])
assert a['sourceSHA256'] == b['sourceSHA256']
assert a['rectifications'] == b['rectifications']
assert len(a['pages']) == len(b['pages']) == 39
component_changes = []
for x, y in zip(a['pages'], b['pages']):
    if x['inkComponents'] != y['inkComponents']:
        old = sorted(x['inkComponents'], key=lambda o: json.dumps(o, sort_keys=True))
        new = sorted(y['inkComponents'], key=lambda o: json.dumps(o, sort_keys=True))
        component_changes.append({'page': x['pageIndex'] + 1, 'orderOnly': old == new,
                                  'beforeCount': len(old), 'afterCount': len(new)})
        x['inkComponents'], y['inkComponents'] = old, new
normalized_inventory_diff = diffs(a, b)
pa, pb = (load(v, 'plan') for v in ['baseline', 'candidate'])
plan_diff = diffs(pa, pb)
expected_edges = {'p29-s1-violin1': 'bottomFraction', 'p29-s1-violin2': 'topFraction'}
connection_warning = ('Notation connected to this staff also touches a neighboring staff. '
                      'The complete ambiguous ink is retained; review this crop locally.')
allowed_changes = []
normalized_plan = json.loads(json.dumps(pb))
for old_page, new_page in zip(pa['pages'], normalized_plan['pages']):
    assert [v['id'] for v in old_page['assignments']] == [v['id'] for v in new_page['assignments']]
    for old, new in zip(old_page['assignments'], new_page['assignments']):
        if old['id'] in expected_edges:
            edge = expected_edges[old['id']]
            assert old[edge] != new[edge]
            assert connection_warning in old['warnings']
            assert new['warnings'] == [v for v in old['warnings'] if v != connection_warning]
            allowed_changes.append({'id': old['id'], 'edge': edge, 'removedWarning': connection_warning})
            new[edge] = old[edge]
            new['warnings'] = old['warnings']
assert len(allowed_changes) == 2 and normalized_plan == pa
bands = [band for page in pb['pages'] for band in page['assignments']]
copies = sum(len(band.get('sourceMarkings', [])) for band in bands)
summaries = {v: load(v, 'summary') for v in ['baseline', 'candidate']}
for summary in summaries.values():
    assert summary['planCanApply'] and summary['bandCount'] == 604
    assert summary['projectUnchanged'] and summary['progressCleared']
    assert summary['completionOnMainThread'] and not summary['issues']
bindings = {str(p.relative_to(work)): hashlib.sha256(p.read_bytes()).hexdigest()
            for v in ['baseline', 'candidate']
            for p in (work / v).glob('*.json')}
result = {'sourcePages': 39, 'bands': len(bands), 'copies': copies,
          'exactExpectedPlanDelta': allowed_changes,
          'componentChanges': component_changes,
          'normalizedInventoryDifferences': normalized_inventory_diff,
          'planDifferences': plan_diff,
          'summary': {v: {k: value for k, value in s.items() if k != 'progress'}
                      for v, s in summaries.items()},
          'sha256': bindings}
(work / 'native-comparison.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items()
                  if k not in ['normalizedInventoryDifferences', 'sha256']}, indent=2))
