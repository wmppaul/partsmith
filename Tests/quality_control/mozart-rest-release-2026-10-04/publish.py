"""Verify frozen source and independent evidence, then publish the local Alpha 5 ZIP."""
from pathlib import Path
import hashlib
import json
import os
import shutil

root = Path('.build/mozart-rest-release-2026-10-04')
review = Path('Tests/quality_control/mozart-rest-release-2026-10-04')
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
read = lambda p: json.loads(Path(p).read_text())


def put(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + '\n')


def verify_manifest(folder):
    manifest = read(folder / 'manifest.json')
    files = manifest.get('files', manifest)
    for name, value in files.items():
        expected = value['sha256'] if isinstance(value, dict) else value
        assert sha(folder / name) == expected, str(folder / name)
    return len(files)


audit = read(root / 'private-package-audit.json')
roster = read(root / 'source-hashes.json')
assert audit['status'] == 'pass'
assert read(review / 'source-hashes.json') == roster
assert all(sha(p) == h == sha(root / p) for p, h in roster.items())

peers = []
for name, hash_files in [
    ('default-rest-joins-2026-10-04', ['source-hashes.json', 'test-source-hashes.json']),
    ('mozart-rest-detection-2026-10-04', ['source-hashes.json', 'context-source-hashes.json']),
    ('mozart_rest_source_review_2026-10-04', []),
]:
    folder = review.parent / name
    count = verify_manifest(folder)
    sources = {}
    for filename in hash_files:
        for path, expected in read(folder / filename).items():
            assert sha(path) == expected, path
            if path.startswith('Partsmith/'):
                assert roster[path] == expected, path
            sources[path] = expected
    peers.append({'path': str(folder), 'manifestSHA256': sha(folder / 'manifest.json'),
                  'evidenceFilesVerified': count, 'sourceFilesVerified': len(sources)})

joins = read(Path(peers[0]['path']) / 'verification.json')
assert joins['checks'] == 348 and joins['failures'] == 0
assert joins['productionSourcesUnchangedDuringVerification']
detector = Path(peers[1]['path'])
new_checks = read(detector / 'results.json')
assert new_checks['checks'] == 112 and not new_checks['failures']
assert '250 rest-detection checks, 34 real-score fixtures, 0 failures' in (detector / 'existing-regression.log').read_text()
assert '120 automatic-rest source-context checks, 0 failures' in (detector / 'context-regression.log').read_text()
visual = read(Path(peers[2]['path']) / 'output-review/visual-review.json')
assert visual['keyFixes']['clarinetOpeningBars'] == 5
assert visual['keyFixes']['pianoGrandStaffCombinedBars'] == 39
assert not visual['keyFixes']['pianoStartBarNumberRequired']
assert visual['detectedWholeRestStrips'] == 6
assert visual['musicallyEligibleWholeRestStrips'] == 8
assert visual['falsePositiveWholeStripReplacements'] == 0
assert visual['playingAndMixedOriginalCropsUnchanged']

output = Path('output/pdf/mozart-rests-2026-10-04')
verify_manifest(output)
end_to_end = read(review / 'end-to-end.json')
assert {d['variant'] for d in end_to_end} == {'numbered', 'unnumbered'}
for data in end_to_end:
    assert data['sourceRowsPreserved'] == 72 and data['detectedStrips'] == 6
    assert data['pianoConfirmedBars'] == 39 and data['pianoOutputPages'] == 1
    assert data['pianoCountPrintedOnce'] and len(data['outputPDFs']) == 9
    folder = Path('.build/mozart_rest_regression_2026-10-04') / (
        'unnumbered-output-v2' if data['variant'] == 'unnumbered' else 'numbered-output')
    for filename, expected in data['outputPDFs'].items():
        assert sha(folder / filename) == expected, filename
        if data['variant'] == 'unnumbered':
            assert sha(output / filename) == expected, filename

public = Path('artifacts/macos/Partsmith-extraction-preview-macos.zip')
private = root / 'Partsmith-extraction-preview-macos.zip'
assert sha(public) == audit['priorPublicZIPSHA256']
assert sha(private) == audit['privateArchiveSHA256']
shutil.copyfile(public, root / 'previous-public-package.zip')
pending = public.with_name('.pending-mozart-rests.zip')
shutil.copyfile(private, pending)
assert sha(pending) == audit['privateArchiveSHA256']
os.replace(pending, public)
put(review / 'publication.json', {
    'status': 'Published local package after source, detector, default join and independent nine-part output review',
    'publicPath': str(public), 'publicSHA256': sha(public),
    'priorPublicSHA256': audit['priorPublicZIPSHA256'],
    'independentReviews': peers, 'compiledAppSourcesPerArchitecture': 37,
    'sourceInputsVerified': len(roster), 'checksPassed': 830,
    'numberedAndUnnumberedWorkflowVerified': True,
    'reviewedOutputPath': str(output), 'outputManifestSHA256': sha(output / 'manifest.json'),
    'rootVisualReview': ['mozart_rest_source_review_2026-10-04/output-review/Piano-p1.png',
                         'mozart_rest_source_review_2026-10-04/output-review/Clarinet in A-p1.png'],
    'runningAppActions': 'none',
    'scope': 'Rest behavior in eight Mozart systems, all nine parts; not full-score crop certification or live mouse interaction testing',
    'remainingAbstentions': visual['abstentions'],
})
put(review / 'manifest.json', {'files': {
    p.relative_to(review).as_posix(): sha(p)
    for p in sorted(review.rglob('*')) if p.is_file() and p.name != 'manifest.json'
}})
put('docs/releases/v0.1.0-alpha.5.json', {
    'reviewDirectory': str(review), 'sha256': sha(public)
})
print('Published local package', sha(public))
