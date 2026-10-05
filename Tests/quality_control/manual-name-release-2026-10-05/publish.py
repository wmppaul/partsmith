"""Verify the frozen build and independent name-entry checks before publication."""
from pathlib import Path
import hashlib
import json
import os
import shutil

snapshot = Path('.build/manual-name-release-2026-10-05')
review = Path('Tests/quality_control/manual-name-release-2026-10-05')
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
read = lambda path: json.loads(Path(path).read_text())


def put(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + '\n')


audit = read(snapshot / 'private-package-audit.json')
roster = read(snapshot / 'source-hashes.json')
assert audit['status'] == 'pass'
assert read(review / 'source-hashes.json') == roster
assert all(sha(path) == expected == sha(snapshot / path) for path, expected in roster.items())

peers = []
for name in ['manual-instrument-names-2026-10-05', 'manual-name-regressions-2026-10-05',
             'manual-name-ui-2026-10-05']:
    folder = review.parent / name
    manifest = read(folder / 'manifest.json')
    manifest = manifest.get('files', manifest)
    for path, expected in manifest.items():
        if isinstance(expected, dict):
            expected = expected['sha256']
        assert sha(folder / path) == expected, str(folder / path)
    sources = read(folder / 'source-hashes.json')
    if (folder / 'test-source-hashes.json').exists():
        sources.update(read(folder / 'test-source-hashes.json'))
    for path, expected in sources.items():
        assert sha(path) == expected, path
        if path.startswith('Partsmith/'):
            assert roster[path] == expected, path
    verification = read(folder / 'verification.json')
    assert verification['checks'] > 0 and verification['failures'] == 0
    peers.append({'path': str(folder), 'manifestSHA256': sha(folder / 'manifest.json'),
                  'evidenceFilesVerified': len(manifest), 'sourceFilesVerified': len(sources),
                  'checksPassed': verification['checks']})
assert peers[0]['checksPassed'] == 87
assert peers[1]['checksPassed'] == 252
assert peers[2]['checksPassed'] >= 30

public = Path('artifacts/macos/Partsmith-extraction-preview-macos.zip')
private = snapshot / 'Partsmith-extraction-preview-macos.zip'
assert sha(public) == audit['priorPublicZIPSHA256']
assert sha(private) == audit['privateArchiveSHA256']
shutil.copyfile(public, snapshot / 'previous-public-package.zip')
pending = public.with_name('.pending-manual-names.zip')
shutil.copyfile(private, pending)
assert sha(pending) == audit['privateArchiveSHA256']
os.replace(pending, public)
put(review / 'publication.json', {
    'status': 'Published local package after model, existing regressions and native name-entry UI review',
    'publicPath': str(public), 'publicSHA256': sha(public),
    'priorPublicSHA256': audit['priorPublicZIPSHA256'], 'independentReviews': peers,
    'checksPassed': sum(peer['checksPassed'] for peer in peers),
    'sourceInputsVerified': len(roster), 'compiledAppSourcesPerArchitecture': 37,
    'rootVisualReview': ['manual-name-ui-2026-10-05/source-pending-name-narrow.png',
                         'manual-name-ui-2026-10-05/source-added-name.png'],
    'runningAppActions': 'none',
    'scope': 'Name-entry interactions in isolated native windows; no new musical extraction or full-score quality claim',
})
put(review / 'manifest.json', {'files': {
    path.relative_to(review).as_posix(): sha(path)
    for path in sorted(review.rglob('*')) if path.is_file() and path.name != 'manifest.json'
}})
put('docs/releases/v0.1.0-alpha.6.json', {'reviewDirectory': str(review), 'sha256': sha(public)})
print('Published reviewed local package:', sha(public))
