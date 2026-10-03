from pathlib import Path
import hashlib
import json
import shutil
import zipfile

root = Path.cwd()
work = root / '.build/page-turn-review-2026-10-03'
report = root / 'Tests/quality_control/page-turn-review-2026-10-03'
candidate = work / 'final-alternative'
delivery = root / 'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-page-turns'
frozen = root / '.build/brahms-continuation-release-2026-10-03/candidate'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert json.loads((report / 'reexport-verification.json').read_text())['verdict'] == 'PASS'
assert not delivery.exists(), 'Refuse to overwrite an existing delivery.'
shutil.copytree(candidate, delivery)
copied = {}
for src in sorted(candidate.rglob('*')):
    if src.is_file():
        dst = delivery / src.relative_to(candidate)
        assert sha(src) == sha(dst)
        copied[str(src.relative_to(candidate))] = sha(dst)
(delivery / 'REVIEW.md').write_text('''# Brahms Quartet Op. 67: page-turn alternative

Complete draft: **67 pages**, compared with the compact version's 64. First Violin has 18 pages, Second Violin 17, Viola 17 and Cello 15. Each contains all 151 systems. The editable Partsmith project includes the original source and all six page-break choices.

First Violin's rapid passage on source page 31 now stays on output page 14, together with the following first/second ending group. Output pages 13, 14, 15 and 16 begin at source p29 s1, p31 s1, p33 s1 and p34 s3 respectively. These are printed movement, repeat/section and Doppio Movimento boundaries; a repeat boundary does not guarantee a pause. Second Violin and Viola start output page 14 at source p32 s1, where genuine whole-bar rests precede their entrances. No rests or counts were invented. Cello retains the compact 15-page layout: no sufficiently useful rest was established for an extra page.

All 604 source crops and 42 copied directions, their order and scale settings are unchanged. All pages were rendered and visually checked; the saved project was reopened and natively reexported, with identical placements and all 67 pages pixel-identical at 144 dpi. The added cost is one page in each upper part. Existing neighboring notation and other draft extraction limitations remain, and continuous-playing turns elsewhere have not all been solved.

The separate compact set remains at `../brahms-quartet-93521-continuation/`. This alternative uses the same original source, SHA-256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`, and nine saved page corrections. `manifest.json` records final placements. `plan.json` is the native extraction plan before editorial pagination; `layout-page-breaks.json` and the saved project contain the six choices.

Source images, the rejected 72/69/68-page variants, geometry checks, reopen verification and limitations are recorded in `Tests/quality_control/page-turn-review-2026-10-03/` in the repository. This is a source-reviewed layout alternative, not automatic rest-aware pagination or a whole-score performance certification.
''')
provenance = {
    'status': 'complete-parts-draft-editorial-pagination-alternative',
    'compactPredecessor': 'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-continuation',
    'sourceSHA256': json.loads((candidate / 'manifest.json').read_text())['sourceSHA256'],
    'report': 'Tests/quality_control/page-turn-review-2026-10-03/README.md',
    'explicitBreaks': json.loads((candidate / 'layout-page-breaks.json').read_text()),
    'nativeExportFilesCopiedByteExactly': copied,
    'nativeInventorySHA256': sha(frozen / 'brahms-inventory.json'),
    'profileSHA256': sha(root / 'Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json'),
    'frozenCoreSHA256': {str(p.relative_to(frozen)): sha(p) for p in sorted((frozen / 'Core').rglob('*.swift'))},
    'reexportVerificationSHA256': sha(report / 'reexport-verification.json'),
    'scaleSettingsUnchanged': True,
    'sourceCropOrDirectionChanges': 0,
    'extraPagesComparedWithCompact': 3,
}
(delivery / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
hashes = {str(p.relative_to(delivery)): sha(p) for p in sorted(delivery.rglob('*')) if p.is_file()}
(delivery / 'delivery-hashes.json').write_text(json.dumps(hashes, indent=2) + '\n')
for name, expected in hashes.items():
    assert sha(delivery / name) == expected

inputs = set()
for p in work.rglob('*'):
    if p.is_file() and p.suffix in ['.json', '.swift', '.sh', '.log']:
        inputs.add(p)
inputs.update((frozen / 'Core').rglob('*.swift'))
inputs.add(frozen / 'brahms-inventory.json')
inputs.add(root / 'Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json')
for p in sorted(frozen.glob('*.json')):
    inputs.add(p)
inputs.add(root / 'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-continuation/manifest.json')
inputs.add(root / 'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-continuation/Brahms String Quartet No. 3 Op. 67 — Auto draft.partsmithproject/project.json')
input_hashes = {str(p.relative_to(root)): sha(p) for p in sorted(inputs)}
with zipfile.ZipFile(report / 'evidence.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for p in sorted(inputs):
        archive.write(p, str(p.relative_to(root)))
    archive.writestr('evidence-entry-hashes.json', json.dumps(input_hashes, indent=2) + '\n')
with zipfile.ZipFile(report / 'evidence.zip') as archive:
    assert archive.testzip() is None
    for name, expected in input_hashes.items():
        assert hashlib.sha256(archive.read(name)).hexdigest() == expected
(report / 'delivery-verification.json').write_text(json.dumps({
    'delivery': str(delivery.relative_to(root)), 'totalPages': 67,
    'nativeFilesCopiedByteExactly': copied,
    'deliveryHashesSHA256': sha(delivery / 'delivery-hashes.json'),
    'evidenceEntries': len(input_hashes), 'allEvidenceEntryHashesVerified': True,
    'evidenceZIP_SHA256': sha(report / 'evidence.zip'),
}, indent=2) + '\n')
print(json.dumps({'delivery': str(delivery), 'nativeFiles': len(copied),
                  'evidenceEntries': len(input_hashes),
                  'deliveryHashesSHA256': sha(delivery / 'delivery-hashes.json')}, indent=2))
