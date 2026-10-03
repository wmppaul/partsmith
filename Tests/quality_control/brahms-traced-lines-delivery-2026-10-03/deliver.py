"""Revalidate the reviewed combined export and copy it into a new delivery folder."""
from pathlib import Path
import collections
import hashlib
import json
import shutil
import pymupdf

ROOT = Path(__file__).resolve().parents[3]
REPORT = Path(__file__).resolve().parent
SOURCE = ROOT / '.build/qc-brahms-traced-ending-combination/parts'
DEST = ROOT / 'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-traced-lines'
PREVIOUS = ROOT / 'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-endings'
REVIEW = ROOT / 'Tests/quality_control/brahms-traced-endings-combination-v1/review.json'


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bind(path):
    return {'path': str(path.relative_to(ROOT)), 'sha256': sha(path), 'bytes': path.stat().st_size}


review = read(REVIEW)
checks = review['bindings'] + review['evidenceBindings']
for item in checks:
    assert sha(ROOT / item['path']) == item['sha256'], item['path']

manifest = read(SOURCE / 'manifest.json')
previous = read(PREVIOUS / 'manifest.json')
inventory_path = ROOT / '.build/qc-brahms-traced-ending-combination/inventory.json'
inventory = read(inventory_path)
assert sha(inventory_path) == '38b323b30e19ec01b0dabd38088b63de3556a537ff90d52c961954b588d90a1d'
source_path = ROOT / 'sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf'
assert sha(source_path) == manifest['sourceSHA256'] == previous['sourceSHA256'] == inventory['sourceSHA256']
package = SOURCE / manifest['project']
project = read(package / 'project.json')['project']
assert sha(package / 'source.pdf') == manifest['sourceSHA256']
assert len(project['bands']) == 604 and len(project['parts']) == 4 and project['pageCount'] == 39
assert sorted(collections.Counter(b['partID'] for b in project['bands']).values()) == [151] * 4
assert all(not b.get('excluded', False) for b in project['bands'])
assert project['pageRectifications'] == inventory['rectifications'] == manifest['rectifications'] == previous['rectifications']
assert len(manifest['rectifications']) == 9
assert sha(SOURCE / manifest['reviewSourceFile']) == manifest['reviewSourceSHA256']

expected_changes = {
    'p24-s1-viola': [0, 94.80023139220975, 427, 145.72927111453913],
    'p24-s1-cello': [0, 125.39606633243346, 427, 170.63285769379098],
}
same_crop_count = copy_count = 0
changed_crops = []
parts = []
old_hashes = {}
for old, new in zip(previous['parts'], manifest['parts']):
    assert old['id'] == new['id'] and old['bandCount'] == new['bandCount'] == 151
    assert len(new['placements']) == 151
    assert [(p['sourcePage'], p['system']) for p in new['placements']] == sorted(set((p['sourcePage'], p['system']) for p in new['placements']))
    with pymupdf.open(SOURCE / new['file']) as pdf:
        assert pdf.page_count == new['outputPages'] == old['outputPages']
    for a, b in zip(old['placements'], new['placements']):
        for key in ['id', 'sourcePage', 'system', 'candidateIDs', 'staffLineYs', 'kind']:
            assert a[key] == b[key], (b['id'], key)
        if a['sourceRect'] == b['sourceRect']:
            same_crop_count += 1
        else:
            assert b['sourceRect'] == expected_changes[b['id']], b['id']
            changed_crops.append({'bandID': b['id'], 'before': a['sourceRect'], 'after': b['sourceRect']})
        assert [(m['sourceRect'], m.get('isBelow', False)) for m in a['sourceMarkings']] == [(m['sourceRect'], m.get('isBelow', False)) for m in b['sourceMarkings']], b['id']
        copy_count += len(b['sourceMarkings'])
        if b['id'] == 'p28-s2-cello':
            assert b['sourceRect'][3] == 306.94288150920204
    old_hashes[old['file']] = sha(PREVIOUS / old['file'])
    parts.append({'id': new['id'], 'file': new['file'], 'name': new['name'], 'pages': new['outputPages'], 'systems': 151, 'sha256': sha(SOURCE / new['file'])})
assert same_crop_count == 602 and len(changed_crops) == 2 and copy_count == 42
assert [p['pages'] for p in parts] == [17, 16, 16, 15]

# Recompute the entire-staff diagnostic against the confirmed physical staff inventory.
pages = {p['pageIndex'] + 1: p for p in inventory['pages']}
neighbors = []
for part in manifest['parts']:
    for band in part['placements']:
        page = pages[band['sourcePage']]
        for staff in page['staves']:
            ys = [f * page['pageHeight'] for f in staff['staffLineFractions']]
            if staff['id'] not in band['candidateIDs'] and band['sourceRect'][1] <= min(ys) and band['sourceRect'][3] >= max(ys):
                neighbors.append({'bandID': band['id'], 'neighborStaffID': staff['id']})
assert len(neighbors) == 9

guard_path = ROOT / 'Tests/quality_control/native-ending-brackets-v1/native-guard-comparison.json'
guards = read(guard_path)
assert len(guards) == 8 and sum(not x['fullGuardContained'] for x in guards) == 6

assert not DEST.exists(), 'Never overwrite a previous delivery'
DEST.mkdir(parents=True)
files = [SOURCE / p['file'] for p in manifest['parts']]
files += [SOURCE / 'manifest.json', SOURCE / 'plan.json', SOURCE / manifest['reviewSourceFile']]
files += sorted(package.iterdir())
for src in files:
    dst = DEST / src.relative_to(SOURCE)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    assert sha(src) == sha(dst)
for name, original_hash in old_hashes.items():
    assert sha(PREVIOUS / name) == original_hash

# Fresh verification images come from the immutable original and the copied PDFs.
with pymupdf.open(source_path) as pdf:
    pdf[23].get_pixmap(matrix=pymupdf.Matrix(4, 4), clip=pymupdf.Rect(0, 5, 427, 185)).save(str(REPORT / 'source-p24-s1.png'))
for part in manifest['parts']:
    with pymupdf.open(DEST / part['file']) as pdf:
        for band in part['placements']:
            if band['id'] not in expected_changes:
                continue
            image = REPORT / f"delivered-{band['id']}.png"
            pdf[band['outputPage'] - 1].get_pixmap(matrix=pymupdf.Matrix(3, 3), clip=pymupdf.Rect(band['destinationRect']) + (-3, -3, 3, 3)).save(str(image))

result = {
    'date': '2026-10-03',
    'status': 'Complete draft delivery approved by root; existing musical limitations retained',
    'destination': str(DEST.relative_to(ROOT)),
    'verifiedReviewBindings': len(checks),
    'source': bind(source_path),
    'combinedInventory': bind(inventory_path),
    'priorReview': bind(REVIEW),
    'parts': parts,
    'outputPages': 64,
    'systemsPerPart': 151,
    'musicBands': 604,
    'mainCropsUnchangedFromPredecessor': same_crop_count,
    'changedCrops': changed_crops,
    'allPhysicalStaffIdentitiesAndScoreOrderUnchanged': True,
    'sourceCopiesUnchanged': copy_count,
    'wholeNeighborStaffOccurrences': neighbors,
    'frozenEndingEnvelopeFailures': [g for g in guards if not g['fullGuardContained']],
    'blanketEndingMarginUsed': False,
    'savedRectificationPages': [x['pageIndex'] + 1 for x in manifest['rectifications']],
    'embeddedOriginalVerified': True,
    'predecessorPreserved': {'folder': str(PREVIOUS.relative_to(ROOT)), 'pdfSHA256': old_hashes},
    'files': [bind(DEST / src.relative_to(SOURCE)) for src in files],
    'limitations': review['limitations'],
    'earlierVisualReview': review['visualReview'],
    'pageAssignmentChanges': review['pageAssignmentChanges'],
    'earlierPixelComparison': {'identicalPagesAt108DPI': 48, 'changedPagesReviewed': 16, 'overlapFailures': 0, 'outsidePageFailures': 0},
}
(REPORT / 'delivery-check.json').write_text(json.dumps(result, indent=2) + '\n')
(DEST / 'provenance.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'destination': str(DEST), 'reviewBindingsVerified': len(checks), 'parts': parts, 'wholeNeighborStaffOccurrences': len(neighbors), 'sourceCopiesPreserved': copy_count}, indent=2))
