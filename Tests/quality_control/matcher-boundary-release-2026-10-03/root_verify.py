from pathlib import Path
import hashlib,json,tarfile,zipfile,subprocess,stat
w=Path('.build/matcher-boundary-release-2026-10-03')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def audit_archive(base, archive, roster):
 rows=json.loads((base/roster).read_text()); expected={r['path']:r for r in rows}
 with tarfile.open(base/archive) as t:
  members={m.name:m for m in t.getmembers() if m.isfile()}; assert set(members)==set(expected),(archive,set(members)^set(expected))
  for name,m in members.items():
   data=t.extractfile(m).read();r=expected[name];assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256'],name
 return {'archive':str(base/archive),'sha256':sha(base/archive),'members':len(rows),'allMemberHashesVerified':True}
results=[]
for folder,archive in [('parzen-template-anchor-independent-2026-10-03','review-evidence.tar.gz'),('parzen-template-cancellation-independent-2026-10-03','test-evidence.tar.gz')]:
 b=Path('Tests/quality_control')/folder;m=json.loads((b/'manifest.json').read_text())
 for n,r in m['files'].items(): assert sha(b/n)==r['sha256'] and (b/n).stat().st_size==r['bytes']
 results.append(audit_archive(b,archive,'archive-members.json'))
results.append(audit_archive(w,'release-evidence.tar.gz','archive-members.json'))
inputs=json.loads((w/'source-hashes.json').read_text())
for p,h in inputs.items():assert sha(p)==h and sha(w/p)==h,p
manifest=json.loads((w/'private-release-manifest.json').read_text())
for n,r in manifest['files'].items():assert sha(w/n)==r['sha256'] and (w/n).stat().st_size==r['bytes'],n
bundle=w/'package-extracted/Partsmith.app'; exe=bundle/'Contents/MacOS/Partsmith'
with zipfile.ZipFile(w/'Partsmith-extraction-preview-macos.zip') as z:
 assert z.testzip() is None
 for p in bundle.rglob('*'):
  if p.is_file():
   name='Partsmith.app/'+str(p.relative_to(bundle)); zi=z.getinfo(name)
   assert z.read(name)==p.read_bytes(),name
   assert stat.S_IMODE(zi.external_attr>>16)==stat.S_IMODE(p.stat().st_mode),name
commands=[]
for cmd in [['/usr/bin/codesign','--verify','--all-architectures','--deep','--strict',str(bundle)],['/usr/bin/lipo','-archs',str(exe)]]:
 r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0;commands.append({'command':cmd,'stdout':r.stdout,'stderr':r.stderr,'exitCode':r.returncode})
assert set(commands[-1]['stdout'].split())=={'arm64','x86_64'}
log=Path('.build/parzen-template-integration-2026-10-03/batch-tests.log');assert log.read_text().strip()=='46 batch system-assignment checks passed'
r={'scope':'Root independent package, source-input and frozen reviewer evidence verification; no new musical quality claim','archives':results,'sourceInputsVerified':len(inputs),'batchTestChecks':46,'batchTestLogSHA256':sha(log),'privatePackageSHA256':sha(w/'Partsmith-extraction-preview-macos.zip'),'binarySHA256':sha(exe),'archiveFileBytesAndModesExact':True,'commands':commands,'publicationYetPerformed':False}
(w/'root-verification.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
