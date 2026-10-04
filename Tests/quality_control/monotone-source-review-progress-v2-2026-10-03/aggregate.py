from pathlib import Path
from collections import Counter
import hashlib
import json
import shutil
import zipfile

QC = Path('Tests/quality_control')
OUT = QC / 'monotone-source-review-progress-v2-2026-10-03'
PRIOR = QC / 'monotone-source-review-progress-2026-10-03'
BASE = QC / 'monotone-corpus-independent-2026-10-03'
NEW = QC / 'brahms-raw60-source-review-2026-10-03'
DYNAMIC = QC / 'brahms-p34-dynamic-2026-10-03'
OUT.mkdir(parents=True, exist_ok=True)
inputs = {}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def read(path):
    path = Path(path)
    data = path.read_bytes()
    inputs[str(path)] = {'sha256': digest(data), 'bytes': len(data)}
    return data

def load(path):
    return json.loads(read(path))

def dump(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')

def verify(folder, expected_manifest=None):
    manifest = load(folder / 'manifest.json')
    if expected_manifest:
        assert inputs[str(folder / 'manifest.json')]['sha256'] == expected_manifest
    for name, record in manifest.items():
        data = read(folder / name)
        assert digest(data) == record['sha256'], (folder, name)
        assert len(data) == record['bytes'], (folder, name)

verify(PRIOR, '2728da97efc22f347bf920f6170a9fcabc121f663273ee3cddb4fd7c8a90e0d8')
verify(NEW, 'c86de9e856915b783ccf8c9a30054d29a5952ec8bfb06bbf3a8a978bc07aa26f')
verify(DYNAMIC, 'efffd121445f583e9559d75c13dcad1c2c2bb22f236d87959790dcae7f06374b')
prior_manifest_sha = inputs[str(PRIOR / 'manifest.json')]['sha256']
base_manifest = load(BASE / 'manifest.json')
if 'files' in base_manifest:
    base_manifest = {r['path']: r for r in base_manifest['files']}
elif 'artifacts' in base_manifest:
    base_manifest = base_manifest['artifacts']
archive = BASE / 'comparison-data.zip'
archive_data = read(archive)
assert digest(archive_data) == base_manifest['comparison-data.zip']['sha256']
with zipfile.ZipFile(archive) as z:
    content = {r['path']: r for r in json.loads(z.read('contents.json'))}
    def archived(name):
        data = z.read(name)
        assert digest(data) == content[name]['sha256']
        inputs[str(archive) + '!/' + name] = {'sha256': digest(data), 'bytes': len(data)}
        return json.loads(data)
    canonical = archived('changed-crop-review-jobs.json')
    original_pending = archived('pending-changed-crop-review.json')

def key(row):
    return row['id'], row['bandID']

def unique(rows):
    result = {key(r): r for r in rows}
    assert len(result) == len(rows), 'Duplicate score-plus-band identity'
    return result

all_map = unique(canonical)
pending_original = unique(original_pending)
prior_rows = load(PRIOR / 'previously-covered-ids.json') + load(PRIOR / 'newly-covered-ids.json')
prior_map = unique(prior_rows)
prior_pending_by_score = load(PRIOR / 'remaining-ids-by-score.json')
prior_pending = {(r['id'], b) for r in prior_pending_by_score for b in r['remainingBandIDs']}
prior_summary = load(PRIOR / 'summary.json')
assert len(all_map) == 1282 and len(pending_original) == 1125
assert len(prior_map) == 398 and len(prior_pending) == 884
assert set(prior_map).isdisjoint(prior_pending)
assert set(prior_map) | prior_pending == set(all_map)

rows = load(NEW / 'per-band-review.json')
new_map = unique(rows)
index = unique(load(NEW / 'index.json'))
new_summary = load(NEW / 'summary.json')
assert len(new_map) == 60 and set(new_map) == set(index)
assert set(new_map) <= prior_pending and set(new_map).isdisjoint(prior_map)
assert new_summary['candidateNativeSHA256'] == prior_summary['candidateNativeSHA256']
additions = []
verified_files = set()
for k, row in new_map.items():
    q = all_map[k]
    for field, value in q.items():
        assert index[k][field] == value, (k, field)
    for field in ['sourceSHA256', 'beforePDFBounds', 'afterPDFBounds', 'beforeWholeNeighbors', 'afterWholeNeighbors']:
        assert row[field] == q[field], (k, field)
    assert row['candidateIDs'] == q['after']['candidateIDs']
    assert row['fullSourceViewed'] and row['contextViewed']
    for binding in [{'path': q['source'], 'sha256': q['sourceSHA256']}] + q['inventoryFiles']:
        name = binding['path']
        if name not in verified_files:
            read(name)
            verified_files.add(name)
        assert inputs[name]['sha256'] == binding['sha256'], name
    additions.append({**row, 'receipt': str(NEW / 'per-band-review.json'),
        'receiptSHA256': inputs[str(NEW / 'per-band-review.json')]['sha256']})

covered = set(prior_map) | set(new_map)
remaining = set(all_map) - covered
assert len(covered) == 458 and len(remaining) == 824
assert covered.isdisjoint(remaining) and covered | remaining == set(all_map)
assert {r['bandID'] for r in rows if r['existingOwnDynamicOmission']} == {'p34-s4-viola'}
assert not any(r['newOwnStaffNoteLossObserved'] or r['newLocalMarkLossObserved'] or r['newSharedInstructionLossObserved'] for r in rows)
by_score = []
for sid in sorted({r['id'] for r in canonical}):
    source_rows = [r for r in canonical if r['id'] == sid]
    keys = {key(r) for r in source_rows}
    pending_ids = sorted(k[1] for k in remaining if k[0] == sid)
    by_score.append({'id': sid, 'source': source_rows[0]['source'],
        'sourceSHA256': source_rows[0]['sourceSHA256'], 'changedCrops': len(keys),
        'coveredAtV1': len(keys & set(prior_map)), 'addedInV2': len(keys & set(new_map)),
        'covered': len(keys & covered), 'pending': len(pending_ids), 'remainingBandIDs': pending_ids})
assert sum(r['pending'] for r in by_score) == 824
assert next(r for r in by_score if r['id'].endswith('93521'))['pending'] == 0
limits = dict(prior_summary['scopeLimits'])
limits['reason'] = ('Coverage includes failed and unfinished crops. The frozen raw crop-only/default-off '
    'direction plans lose Coda, Andante and numbered-tempo instructions. This v2 receipt also retains the '
    'existing raw p34 Viola f omission. Separate newer direction-workflow changes do not retrospectively '
    'approve these frozen crop plans or certify full outputs.')
summary = {'version': 2, 'scope': 'Exact source-review coverage only, not a musical preservation pass.',
    'candidateNativeSHA256': prior_summary['candidateNativeSHA256'], 'changedCrops': 1282,
    'originalCovered': 157, 'originalPending': 1125, 'coveredAtV1': 398, 'pendingAtV1': 884,
    'newlyCoveredDistinct': 60, 'coveredTotal': 458, 'remainingTotal': 824,
    'duplicates': 0, 'outOfQueueIDs': 0, 'inputGeometryOrSourceBindingMismatches': 0,
    'newReviewReceipt': str(NEW / 'per-band-review.json'),
    'priorReviewedRowsWithReportedLoss': prior_summary['reviewedRowsWithReportedLoss'],
    'newReceiptExistingTargetDefect': {'id': next(iter(new_map))[0], 'bandID': 'p34-s4-viola',
        'description': 'Own forte lower hook is cut in both frozen raw plans; corrected counterpart is complete.',
        'independentEvidence': str(DYNAMIC / 'cause.json'),
        'independentEvidenceSHA256': inputs[str(DYNAMIC / 'cause.json')]['sha256']},
    'newReviewNewOwnNoteOrMarkLossObserved': 0, 'newReviewNewSharedInstructionLossObserved': 0,
    'newReviewWholeForeignRelationsRemoved': 3, 'newReviewWholeForeignRelationsAdded': 0,
    'scopeLimits': limits, 'perScore': [{k: v for k, v in r.items() if k not in ['remainingBandIDs', 'source', 'sourceSHA256']} for r in by_score]}
dump('summary.json', summary)
dump('newly-covered-ids.json', additions)
dump('previously-covered-ids.json', prior_rows)
dump('remaining-ids-by-score.json', by_score)
dump('validation.json', {'canonical1282PartitionExact': True, 'all60AreExactCanonicalRows': True,
    'all60BelongToPrior884Pending': True, 'all60DisjointFromPrior398': True,
    'all60SourceGeometryAndAssignmentsExact': True, 'originalSourceAndInventoriesHashVerified': True,
    'inputReceiptPayloadsHashVerified': True, 'priorReceiptUnchanged': True,
    'priorManifestSHA256': prior_manifest_sha, 'renderingPerformed': False, 'nativeAnalysisPerformed': False})
dump('input-bindings.json', inputs)
shutil.copy2(__file__, OUT / 'aggregate.py')
(OUT / 'README.md').write_text('''# Monotone crop source-review coverage, version 2

**458 of 1,282 changed crops have a source-review receipt; 824 remain pending.** This adds the exact 60 raw Brahms 93521 rows to the prior 398. Every added score-plus-band ID belongs to the canonical queue and was previously pending. There are no overlaps or missing identities. All 253 changed raw Brahms 93521 areas are now covered: 193 by proven exact-area reuse and 60 by direct original-source review.

Coverage is not a pass. The added review found no new own-note, local-mark or shared-instruction loss in those 60 changed areas and confirmed three whole-neighbor removals. It also identified an existing target defect: both raw plans cut the lower hook of the Viola **f** on page 34, system 4. The separately documented corrected counterpart is fully retained. Existing neighboring notation fragments and shared instructions outside both raw crops remain unresolved.

The earlier raw Coda, Andante and numbered-tempo losses remain recorded. Those crop-only plans, including the frozen path with direction recognition off, do not satisfy the preservation requirement. Later direction-workflow changes do not retrospectively approve these frozen crop plans. The cleanup candidate is not approved for promotion here.

The original 157-row starting coverage, subsequent 241 additions, and current 60 additions are distinct. The canonical 1,282-row partition was revalidated from the frozen comparison archive. All 60 full input rows, old/new rectangles, assignment identities, source PDF and inventory hashes match the original queue. The prior receipt and source reports remain unchanged. This accounting performs no rendering, detection or fresh musical review.

The larger goal remains unfinished: 19 initialized profiles have no planned bands, 15,712 detected staves are unassigned, and 987 pages have unresolved reasons in this frozen corpus. Final complete parts and page turns are not certified.

`summary.json` preserves the failures and unresolved scope. `newly-covered-ids.json` contains the 60 direct-review rows and verdicts; `previously-covered-ids.json` retains the prior 398. `remaining-ids-by-score.json` lists the exact remaining 824 IDs. `input-bindings.json`, `validation.json`, and `aggregate.py` preserve reproducible provenance. The original v1 receipt is at `../monotone-source-review-progress-2026-10-03/`.
''')
manifest = {p.name: {'sha256': digest(p.read_bytes()), 'bytes': p.stat().st_size}
    for p in sorted(OUT.iterdir()) if p.is_file() and p.name != 'manifest.json'}
dump('manifest.json', manifest)
assert digest((PRIOR / 'manifest.json').read_bytes()) == prior_manifest_sha
for name, record in manifest.items():
    assert digest((OUT / name).read_bytes()) == record['sha256']
print(json.dumps({'covered': len(covered), 'pending': len(remaining), 'report': str(OUT),
    'manifestSHA256': digest((OUT / 'manifest.json').read_bytes())}, indent=2))
