"""Verify reviewed native artifacts, then copy them without rebuilding the PDFs."""
from pathlib import Path
import collections
import hashlib
import json
import shutil
import pymupdf

ROOT = Path(__file__).resolve().parents[3]
REPORT = Path(__file__).resolve().parent
SOURCE = ROOT / '.build/qc-ending-native-v1/brahms-parts'
DEST = ROOT / 'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-endings'


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bind(path):
    return {'path': str(path.relative_to(ROOT)), 'sha256': sha(path), 'bytes': path.stat().st_size}


review_path = ROOT / 'Tests/quality_control/native-ending-brackets-v1/review.json'
independent_path = ROOT / 'Tests/quality_control/native-endings-independent-review/review.json'
review, independent = read(review_path), read(independent_path)
bindings = review['bindings'] + review['frozenCoreBindings']
bindings += [{'path': p, 'sha256': h} for p, h in independent['hashes'].items()]
for b in bindings:
    assert sha(ROOT / b['path']) == b['sha256'], b['path']

manifest = read(SOURCE / 'manifest.json')
baseline_path = ROOT / independent['brahmsOutput']['baseline']
baseline = read(baseline_path)
baseline_parts = {p['id']: p for p in baseline['parts']}
project_path = SOURCE / manifest['project']
project = read(project_path / 'project.json')['project']
immutable_source = ROOT / 'sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf'
assert sha(immutable_source) == manifest['sourceSHA256'] == sha(project_path / 'source.pdf')
assert sha(SOURCE / manifest['reviewSourceFile']) == manifest['reviewSourceSHA256']
assert project['pageCount'] == 39 and len(project['bands']) == 604
assert project['pageRectifications'] == manifest['rectifications'] == baseline['rectifications']
assert len(project['parts']) == 4
project_counts = collections.Counter(b['partID'] for b in project['bands'])
assert sorted(project_counts.values()) == [151] * 4
assert all(not b.get('excluded', False) for b in project['bands'])

main_fields = ['id', 'sourcePage', 'sourceRect', 'candidateIDs', 'staffLineYs', 'system', 'kind']
unchanged, old_marks, new_marks, part_records = 0, 0, 0, []
for part in manifest['parts']:
    prior = baseline_parts[part['id']]
    assert len(part['placements']) == part['bandCount'] == 151
    assert [(p['sourcePage'], p['system']) for p in part['placements']] == sorted(set((p['sourcePage'], p['system']) for p in part['placements']))
    pdf_path = SOURCE / part['file']
    with pymupdf.open(pdf_path) as doc:
        assert doc.page_count == part['outputPages'] == prior['outputPages']
    for current, old in zip(part['placements'], prior['placements']):
        assert {k: current[k] for k in main_fields} == {k: old[k] for k in main_fields}, current['id']
        unchanged += 1
        current_rects = [m['sourceRect'] for m in current['sourceMarkings']]
        old_rects = [m['sourceRect'] for m in old['sourceMarkings']]
        assert all(m in current_rects for m in old_rects), current['id']
        old_marks += len(old_rects)
        new_marks += len(current_rects) - len(old_rects)
    part_records.append({'id': part['id'], 'name': part['name'], 'file': part['file'], 'pages': part['outputPages'], 'systems': 151, 'sha256': sha(pdf_path)})
assert unchanged == 604 and old_marks == 27 and new_marks == 15
assert [p['pages'] for p in part_records] == [17, 16, 16, 15]
guards_path = ROOT / 'Tests/quality_control/native-ending-brackets-v1/native-guard-comparison.json'
guards = read(guards_path)
assert len(guards) == 8 and sum(not x['fullGuardContained'] for x in guards) == 6

# Nothing is copied until every binding and structural verification above passes.
assert not DEST.exists(), 'Refusing to overwrite a delivered folder'
DEST.mkdir(parents=True)
files = [SOURCE / p['file'] for p in manifest['parts']]
files += [SOURCE / 'manifest.json', SOURCE / 'plan.json', SOURCE / manifest['reviewSourceFile']]
files += sorted(project_path.iterdir())
for source_path in files:
    relative = source_path.relative_to(SOURCE)
    destination_path = DEST / relative
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_path, destination_path)
    assert sha(source_path) == sha(destination_path), str(relative)

# Render the actual copied PDFs; these are independent of the earlier review PNGs.
render_records = []
selected = {'violin2': ['p6-s3-violin2', 'p6-s4-violin2'], 'viola': ['p32-s4-viola', 'p37-s2-viola'], 'cello': ['p36-s1-cello']}
for part in manifest['parts']:
    with pymupdf.open(DEST / part['file']) as pdf:
        for p in part['placements']:
            if p['id'] not in selected.get(part['id'], []):
                continue
            rect = pymupdf.Rect(p['destinationRect'])
            for m in p['sourceMarkings']:
                rect |= pymupdf.Rect(m['destinationRect'])
            rect = (rect + (-6, -6, 6, 6)) & pdf[p['outputPage'] - 1].rect
            image = REPORT / f"copied-{p['id']}.png"
            pdf[p['outputPage'] - 1].get_pixmap(matrix=pymupdf.Matrix(3, 3), clip=rect).save(str(image))
            render_records.append({'part': part['id'], 'band': p['id'], 'outputPage': p['outputPage'], 'render': bind(image)})
        if part['id'] == 'cello':
            image = REPORT / 'copied-cello-page14.png'
            pdf[13].get_pixmap(matrix=pymupdf.Matrix(1.5, 1.5)).save(str(image))

result = {
    'date': '2026-09-27',
    'status': 'Complete score draft; prototype paired endings, not general musical readiness certification',
    'destination': str(DEST.relative_to(ROOT)),
    'source': bind(immutable_source),
    'reviewBindings': [bind(review_path), bind(independent_path), bind(guards_path), bind(baseline_path)],
    'verifiedPriorBindings': len(bindings),
    'parts': part_records,
    'outputPages': sum(p['pages'] for p in part_records),
    'mainCropsStaffIdentitiesAndOrderUnchanged': unchanged,
    'existingSourceCopiesPreserved': old_marks,
    'newEndingSourceRows': new_marks,
    'bracketCopiesInLowerParts': 24,
    'sourceOwnerBracketsRetained': 8,
    'embeddedOriginalMatches': True,
    'savedRectificationPages': [r['pageIndex'] + 1 for r in manifest['rectifications']],
    'guardEnvelopeFailures': [g for g in guards if not g['fullGuardContained']],
    'prototype': bind(ROOT / 'Tests/quality_control/native-ending-brackets-v1/prototype/ScoreSharedEndingDetector.swift'),
    'deliveredFiles': [bind(DEST / p.relative_to(SOURCE)) for p in files],
    'newRenderedContexts': render_records,
    'limitations': [
        'Native paired-ending detector remains a scratch prototype and is not enabled in the Mac app.',
        'Six of eight frozen safety envelopes are not fully contained; reported overhang up to 2.125181 points is retained without modifying the guards.',
        'Earlier reviewers found complete intended ending ink despite those envelope failures; incidental note, slur, or rest-count fragments remain in several source copies.',
        'Main crops are unchanged from the reviewed heading baseline. This delivery does not claim a new per-note audit of all 604 main crops.',
        'Existing neighboring notation, including 11 whole-neighbor staff occurrences, and other unresolved shared directions remain.',
        'All score systems are included, but every musical page turn has not been independently optimized.',
    ],
}
(REPORT / 'delivery-check.json').write_text(json.dumps(result, indent=2) + '\n')
(DEST / 'provenance.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'destination': str(DEST), 'verifiedBindings': len(bindings), 'parts': part_records, 'mainCrops': unchanged, 'guardFailuresPreserved': 6}, indent=2))
