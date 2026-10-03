#!/usr/bin/env python3
"""Verify the existing frozen build, preserve the old download, publish atomically."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[3]
BUILD = ROOT / '.build/rest-headings-release-2026-10-03'
EVIDENCE = Path(__file__).resolve().parent
PUBLIC = ROOT / 'artifacts/macos/Partsmith-extraction-preview-macos.zip'
ZIP = BUILD / PUBLIC.name
APP = BUILD / 'DerivedData/Build/Products/Release/Partsmith.app'
EXE = APP / 'Contents/MacOS/Partsmith'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def relative(path):
    return str(path.relative_to(ROOT))

sources = json.loads((BUILD / 'source-hashes.json').read_text())
for name, expected in sources.items():
    assert sha(BUILD / name) == expected, ('frozen source', name)
    assert sha(ROOT / name) == expected, ('production source', name)
swift = {name for name in sources if name.endswith('.swift')}
assert swift == {relative(p) for p in (ROOT / 'Partsmith').rglob('*.swift')}
assert '** BUILD SUCCEEDED **' in (BUILD / 'build.log').read_text()

tool_logs = {}
for label, command in {
    'architectures': ['lipo', '-archs', str(EXE)],
    'minimum-os': ['xcrun', 'vtool', '-show-build', str(EXE)],
    'signing': ['codesign', '-dv', str(APP)]
}.items():
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    output = result.stdout + result.stderr
    (EVIDENCE / (label + '.log')).write_text(output)
    tool_logs[label] = output
architectures = tool_logs['architectures'].split()
assert set(architectures) == {'arm64', 'x86_64'}
slice_versions = dict(re.findall(r'architecture ([^)]+)\):.*?minos ([0-9.]+)',
                                tool_logs['minimum-os'], re.S))
assert slice_versions == {'arm64': '14.0', 'x86_64': '14.0'}
info = plistlib.loads((APP / 'Contents/Info.plist').read_bytes())
assert info['LSMinimumSystemVersion'] == '14.0'
assert 'Signature=adhoc' in tool_logs['signing']

bundle = {str(p.relative_to(APP.parent)): p for p in APP.rglob('*') if p.is_file()}
assert not any(p.is_symlink() for p in APP.rglob('*'))
bundle_hashes = {name: sha(path) for name, path in sorted(bundle.items())}
with zipfile.ZipFile(ZIP) as archive:
    assert archive.testzip() is None, 'ZIP CRC failure'
    entries = archive.infolist()
    files = [entry for entry in entries if not entry.is_dir()]
    app_files = {entry.filename for entry in files if entry.filename.startswith('Partsmith.app/')}
    assert app_files == set(bundle)
    for name, expected in bundle_hashes.items():
        assert hashlib.sha256(archive.read(name)).hexdigest() == expected, name
    metadata = [entry.filename for entry in files if entry.filename not in app_files]
    assert all(name.startswith('__MACOSX/') for name in metadata)
    executable_entry = archive.getinfo('Partsmith.app/Contents/MacOS/Partsmith')
    assert executable_entry.external_attr >> 16 & 0o111, 'ZIP executable mode missing'
    zip_hashes = {entry.filename: hashlib.sha256(archive.read(entry)).hexdigest() for entry in files}

old_hash = sha(PUBLIC)
backup = BUILD / ('previous-public-' + old_hash + '.zip')
if backup.exists():
    assert sha(backup) == old_hash
else:
    shutil.copy2(PUBLIC, backup)
    assert sha(backup) == old_hash
old_readme = ROOT / 'artifacts/macos/README.md'
readme_backup = BUILD / ('previous-readme-' + sha(old_readme) + '.md')
if not readme_backup.exists():
    shutil.copy2(old_readme, readme_backup)

new_hash = sha(ZIP)
with tempfile.NamedTemporaryFile(prefix='.rest-headings-', suffix='.zip', dir=PUBLIC.parent, delete=False) as stream:
    temporary = Path(stream.name)
    stream.write(ZIP.read_bytes())
    stream.flush()
    os.fsync(stream.fileno())
try:
    assert sha(temporary) == new_hash
    os.chmod(temporary, ZIP.stat().st_mode & 0o777)
    assert sha(PUBLIC) == old_hash, 'Public ZIP changed during verification'
    os.replace(temporary, PUBLIC)
finally:
    if temporary.exists():
        temporary.unlink()
assert sha(PUBLIC) == new_hash
with zipfile.ZipFile(PUBLIC) as archive:
    assert archive.testzip() is None
    assert all(hashlib.sha256(archive.read(name)).hexdigest() == expected for name, expected in zip_hashes.items())
assert all(sha(ROOT / name) == expected for name, expected in sources.items())

shutil.copy2(BUILD / 'source-hashes.json', EVIDENCE / 'source-hashes.json')
shutil.copy2(BUILD / 'build.log', EVIDENCE / 'build.log')
record = {
    'verifiedAtUTC': datetime.now(timezone.utc).isoformat(),
    'baseCommitAtVerification': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    'status': 'Verified frozen universal build and atomically published; app not launched',
    'change': 'Copy recognized shared source headings to confirmed generated rests, preserving source provenance and Remove Copy',
    'artifact': relative(PUBLIC), 'artifactSHA256': new_hash, 'artifactBytes': PUBLIC.stat().st_size,
    'executableSHA256': sha(EXE), 'architectures': sorted(architectures),
    'minimumMacOS': '14.0', 'minimumOSByArchitecture': slice_versions,
    'signing': 'ad hoc linker signatures, no Developer ID, not notarized', 'notarized': False,
    'sourceSnapshot': relative(BUILD), 'sourceManifestSHA256': sha(BUILD / 'source-hashes.json'),
    'sourceHashes': sources, 'sourceFileCount': len(sources), 'swiftFileCount': len(swift),
    'allSnapshotAndProductionHashesMatch': True, 'completeProductionSwiftInventoryMatches': True,
    'buildLogSHA256': sha(BUILD / 'build.log'),
    'zipVerification': {'crc': 'all entries pass before and after publication',
        'entryCount': len(entries), 'bundleFileCount': len(bundle),
        'allBundleFileBytesMatch': True, 'executablePermissionRetained': True,
        'bundleFileSHA256': bundle_hashes, 'allZipFileSHA256': zip_hashes,
        'additionalFiles': 'AppleDouble metadata only'},
    'previousPublicArtifact': {'sha256': old_hash, 'privateBackup': relative(backup),
                               'backupSHA256': sha(backup)},
    'publication': {'method': 'same-directory verified temporary file and os.replace',
                    'publicHashEqualsFrozenZIP': True, 'appLaunched': False,
                    'otherAppCopiesOrDocumentsModified': False},
    'validation': {
        'sharedRestHeadingIndependentChecks': 47, 'localEndingChecks': 70,
        'independentReport': 'Tests/quality_control/generated-rest-heading-independent-2026-10-03/README.md',
        'permanentCropChecks': 796,
        'cropReport': 'Tests/quality_control/permanent-musical-preservation-2026-10-03/README.md',
        'limits': 'No new whole-score recall or live app interaction claim; Erlkonig source/output review is separate.'},
    'verificationEvidence': relative(EVIDENCE), 'verificationScriptSHA256': sha(Path(__file__))
}
destination = ROOT / 'Tests/quality_control/macos-build-2026-10-03-rest-headings.json'
destination.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
print(json.dumps({'artifactSHA256': new_hash, 'executableSHA256': sha(EXE),
                  'sourceFiles': len(sources), 'swiftFiles': len(swift),
                  'bundleFiles': len(bundle), 'previousZIP': relative(backup)}, indent=2))
