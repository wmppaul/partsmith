from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, os, shutil, tempfile, zipfile

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
work = root / '.build/numbered-volta-release-2026-10-03'
public = root / 'artifacts/macos/Partsmith-extraction-preview-macos.zip'
package = work / public.name
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
audit = json.loads((evidence/'independent-package-audit.json').read_text())
assert audit['result'] == 'pass'
assert sha(package) == audit['package']['sha256']
inputs = json.loads((work/'source-hashes.json').read_text())
for name, expected in inputs.items():
    assert sha(root/name) == sha(work/name) == expected, name
assert inputs['Partsmith/Core/Detection/NativeScorePageAnalyzer.swift'] == '9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01'
assert '87 shared heading checks passed' in (root/'.build/numbered-volta-heading-2026-10-03.log').read_text()
assert '113 shared direction app checks passed' in (root/'.build/numbered-volta-direction-app-2026-10-03.log').read_text()
assert '30/30 independent controls pass' in (root/'.build/numbered-volta-heading-independent-2026-10-03/run.log').read_text()
assert '** BUILD SUCCEEDED **' in (work/'build.log').read_text()
with zipfile.ZipFile(package) as z:
    assert z.testzip() is None
    assert hashlib.sha256(z.read('Partsmith.app/Contents/MacOS/Partsmith')).hexdigest() == audit['executable']['sha256']
previous = sha(public)
assert previous == '817373ec3f6652144e3092bbdc93800f49b6bc4a6b6ff5b10b542d3226555fa9'
backup = work/f'previous-public-{previous}.zip'
shutil.copy2(public, backup)
assert sha(backup) == previous
with tempfile.NamedTemporaryFile(dir=public.parent, prefix='.numbered-volta-', suffix='.zip', delete=False) as f:
    replacement = Path(f.name)
    f.write(package.read_bytes()); f.flush(); os.fsync(f.fileno())
assert sha(replacement) == sha(package) and sha(public) == previous
os.chmod(replacement, 0o644)
os.replace(replacement, public)
assert sha(public) == audit['package']['sha256']
shutil.copy2(work/'source-hashes.json', evidence/'source-hashes.json')
with zipfile.ZipFile(evidence/'validation-logs.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for path, name in [(work/'build.log','build.log'),
                       (root/'.build/numbered-volta-heading-2026-10-03.log','heading.log'),
                       (root/'.build/numbered-volta-direction-app-2026-10-03.log','direction-app.log')]:
        z.write(path, name)
record = {
    'publishedAtUTC': datetime.now(timezone.utc).isoformat(),
    'change': 'Recognize explicit numbered-volta tempo instructions above verified systems and preserve their original source pixels for every recipient. Includes the previously shipped Preview crop controls.',
    'artifact': str(public.relative_to(root)), 'artifactSHA256': sha(public),
    'artifactBytes': public.stat().st_size, 'executableSHA256': audit['executable']['sha256'],
    'previousArtifactSHA256': previous, 'previousArtifactBackup': str(backup.relative_to(root)),
    'nativeCropDetectorUnchanged': True, 'privateMonotoneCandidateIncluded': False,
    'sharedDirectionOptionStillExperimentalAndOffByDefault': True,
    'architectures': ['arm64','x86_64'], 'minimumMacOS': '14.0',
    'signing': 'Strictly verified ad hoc signature; not notarized.',
    'validation': {'headingChecks':87, 'directionAppChecks':113, 'independentControls':30,
                   'nativeSourceWorkflowPages':2, 'candidateCropPDFsVisuallyReviewed':4,
                   'productionCropPDFsVisuallyReviewed':4,
                   'scope':'Conditional-direction fix only; no claim of complete extraction quality for all scores.'},
    'knownOutputLimitations': ['The broad production Violin II crop retains a clipped original occurrence beneath its new complete source copy. Neighboring staff fragments remain. Source preservation is verified; clean or deduplicated full-score output is not.'],
    'runningAppOrUserDocumentModified': False,
    'publication': 'Verified same-directory atomic ZIP replacement only.'
}
(evidence/'release.json').write_text(json.dumps(record,indent=2)+'\n')
(evidence/'manifest.json').write_text(json.dumps({p.name:sha(p) for p in sorted(evidence.iterdir()) if p.is_file() and p.name!='manifest.json'},indent=2)+'\n')
print(json.dumps(record,indent=2))
