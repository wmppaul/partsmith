"""Read-only identity/geometry checks. Visual judgments are recorded separately."""
import hashlib
import json
from pathlib import Path
import pymupdf

work = Path('.build/brahms-motets-complete-native-2026-10-03')
own = Path('.build/brahms-motets-source-crops-independent-2026-10-03')
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
read = lambda p: json.loads(Path(p).read_text())
initial = read(work / 'parts/manifest.json')
final = read(work / 'final-parts/manifest.json')
index = read(work / 'final-render-index.json')
old_index = read(work / 'render-index.json')
source_map = read(work / 'source-map.json')
assert initial['sourceSHA256'] == final['sourceSHA256'] == sha(final['source'])
assert index['manifestSHA256'] == sha(work / 'final-parts/manifest.json')
old = {r['id']: r for p in initial['parts'] for r in p['placements']}
new = {r['id']: r for p in final['parts'] for r in p['placements']}
assert len(old) == len(new) == 225 and set(old) == set(new)
identity_keys = ['barCount', 'candidateIDs', 'id', 'kind', 'sourceBandIDs',
                 'sourcePage', 'staffLineYs', 'startBarNumber', 'system']
for key in new:
    for k in identity_keys:
        assert old[key].get(k) == new[key].get(k), (key, k)

manual = read(work / 'manual-corrections-before-final.json')
expected_rects = {r['id']: r['after'] for r in manual['changes']
                  if len(r['after']) == 4 and isinstance(r['after'][0], (int, float))}
rect_changes = {key: new[key]['sourceRect'] for key in new
                if old[key]['sourceRect'] != new[key]['sourceRect']}
assert rect_changes == expected_rects and len(rect_changes) == 8
source_copies = lambda row: [[round(v, 8) for v in m['sourceRect']] for m in row['sourceMarkings']]
copy_changes = [key for key in new if source_copies(old[key]) != source_copies(new[key])]
assert set(copy_changes) == {'p2-s1-soprano-section'} | {
    'p12-s1-' + p['id'] for p in final['parts']}
assert new['p2-s1-soprano-section']['sourceMarkings'] == []

system_keys = [(s['page'], s['system']) for s in source_map['systems']]
assert len(system_keys) == 45
for part_index, part in enumerate(final['parts']):
    assert [(r['sourcePage'], r['system']) for r in part['placements']] == system_keys
    for row, system in zip(part['placements'], source_map['systems']):
        assert len(row['candidateIDs']) == system['staffCounts'][part_index]
        assert row['kind'] == 'music'
        assert row.get('barCount') == system['completeBarCount']
        assert row.get('startBarNumber') == system['inferredStartLabel']
    pdf = work / 'final-parts' / part['file']
    assert sha(pdf) == part['sha256']
    assert len(pymupdf.open(pdf)) == part['outputPages']
assert sum(len(row['candidateIDs']) for row in new.values()) == 292

guard_results = []
for guard in read(own / 'shared-lyric-source-guards.json')['rows']:
    # The guard format preserves independent source coordinates unchanged.
    bounds = guard['sourceEnvelopePDF']
    crop = new[guard['id']]['sourceRect']
    assert crop[0] <= bounds[0] and crop[1] <= bounds[1]
    assert crop[2] >= bounds[2] and crop[3] >= bounds[3]
    guard_results.append({'id': guard['id'], 'bounds': bounds, 'contained': True})
for guard in read(own / 'piano-lower-source-guards.json')['records']:
    assert new[guard['id']]['sourceRect'][3] >= guard['minimumConservativeBottom']
    guard_results.append({'id': guard['id'], 'requiredBottom': guard['minimumConservativeBottom'], 'contained': True})

project_dir = work / 'final-parts' / final['project']
project = read(project_dir / 'project.json')['project']
source = pymupdf.open(final['source'])
assert project['pageCount'] == len(source) == 18
assert sha(project_dir / 'source.pdf') == final['sourceSHA256']
assert len(project['bands']) == 225 and len(project['parts']) == 5
assert not project.get('pageRectifications')
for part in final['parts']:
    model_part = next(p for p in project['parts'] if p['name'] == part['name'])
    bands = [b for b in project['bands'] if b['partID'] == model_part['id']]
    assert len(bands) == 45
    for band, row in zip(bands, part['placements']):
        assert band['pageIndex'] == row['sourcePage'] - 1 and not band['excluded']
        # Read literal PDF numbers, avoiding MuPDF's float32 Rect conversion.
        media = source.xref_get_key(source[band['pageIndex']].xref, 'MediaBox')[1]
        coordinates = [float(v) for v in media.strip('[]').split()]
        h = coordinates[3] - coordinates[1]
        assert abs(band['topFraction'] * h - row['sourceRect'][1]) < 1e-8
        assert abs(band['bottomFraction'] * h - row['sourceRect'][3]) < 1e-8
        if row.get('startBarNumber') is not None:
            assert band.get('barNumberValue') == row['startBarNumber']
        assert not band.get('replacement')
        assert len(band.get('sourceMarkings', [])) == len(row['sourceMarkings'])

old_pages = {(r['part'], r['page']): r for r in old_index['outputPages']}
for row in index['outputPages']:
    assert sha(row['path']) == row['sha256']
    equal = row['sha256'] == old_pages[(row['part'], row['page'])]['sha256']
    assert equal == row['unchangedInitialRaster']
for row in index['changedCropContexts'] + index['sourceCopies']:
    assert sha(row['path']) == row['sha256']

out = {
    'scope': 'Independent source/row/project/copy bindings. Visual source and output verdicts are separate.',
    'sourceSHA256': final['sourceSHA256'],
    'initialManifestSHA256': sha(work / 'parts/manifest.json'),
    'finalManifestSHA256': sha(work / 'final-parts/manifest.json'),
    'sourceMapSHA256': sha(work / 'source-map.json'),
    'manualCorrectionsSHA256': sha(work / 'manual-corrections-before-final.json'),
    'sourcePages': 18, 'systems': 45, 'parts': 5, 'musicRows': 225,
    'physicalStaffReferences': 292, 'generatedRests': 0,
    'changedSourceRectangles': rect_changes, 'changedCopyRows': copy_changes,
    'sourceCopies': sum(len(r['sourceMarkings']) for r in new.values()),
    'outputPages': len(index['outputPages']),
    'unchangedPageRasters': sum(r['unchangedInitialRaster'] for r in index['outputPages']),
    'guardChecks': guard_results,
    'projectJSONSHA256': sha(project_dir / 'project.json'),
    'nativeSaveReopenLogSHA256': sha(work / 'final-export.log'),
    'pdfs': [{'file': p['file'], 'sha256': p['sha256'], 'pages': p['outputPages']} for p in final['parts']],
    'passed': True,
}
(own / 'final-identity-proof.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps({k: out[k] for k in ['passed','musicRows','physicalStaffReferences','sourceCopies','outputPages','unchangedPageRasters']}))
