from pathlib import Path
import datetime, hashlib, json, os, shutil, tempfile

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
work = root / '.build/divisi-assignment-release-v2-2026-10-03'
public = root / 'artifacts/macos/Partsmith-extraction-preview-macos.zip'
package = work / public.name
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
record = json.loads((out / 'release.json').read_text())
assert record['status'] == 'verified-private-package-not-yet-published'
assert sha(package) == record['packageSHA256'] == 'db824e17bcb11f909110273a8dba68f4fd1693bf7f517b72a182fdad3ac2eba0'
for n, h in json.loads((work / 'source-hashes.json').read_text()).items():
    assert sha(root / n) == sha(work / n) == h
delta = root / 'Tests/quality_control/divisi-notte-legacy-delta-2026-10-03/manifest.json'
assert sha(delta) == 'a985f1b12a59665b0c6b04306808c859a0299aafe93ebe96c1a8ffb2ac019d4c'
previous = sha(public)
assert previous == '7b3e5344a340be05973b465453c7c89b35f4a04d1f76b6456ed26f8495fc57ff'
backup = work / f'previous-public-{previous}.zip'
shutil.copy2(public, backup)
assert sha(backup) == previous
with tempfile.NamedTemporaryFile(dir=public.parent, prefix='.divisi-assignment-', suffix='.zip', delete=False) as f:
    replacement = Path(f.name)
    f.write(package.read_bytes()); f.flush(); os.fsync(f.fileno())
assert sha(replacement) == record['packageSHA256'] and sha(public) == previous
os.chmod(replacement, 0o644)
os.replace(replacement, public)
assert sha(public) == record['packageSHA256']
record.update(status='published', artifact=str(public.relative_to(root)), artifactBytes=public.stat().st_size,
              publishedAtUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              previousArtifactSHA256=previous, previousArtifactBackup=str(backup.relative_to(root)),
              publication='Verified atomic replacement of the download ZIP; running app and user documents untouched.')
record['independentEvidence'][str(delta.relative_to(root))] = sha(delta)
(out / 'release.json').write_text(json.dumps(record, indent=2) + '\n')
(out / 'manifest.json').write_text(json.dumps({str(p.relative_to(out)): {'sha256': sha(p), 'bytes': p.stat().st_size}
    for p in sorted(out.rglob('*')) if p.is_file() and p.name != 'manifest.json'}, indent=2) + '\n')
print(json.dumps({'published': str(public), 'sha256': sha(public)}, indent=2))
