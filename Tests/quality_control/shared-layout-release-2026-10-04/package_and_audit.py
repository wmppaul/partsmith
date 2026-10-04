from pathlib import Path
import datetime,hashlib,json,os,plistlib,re,stat,subprocess,zipfile
R=Path('.build/shared-layout-release-2026-10-04');P=Path('.build/literal-layout-release-2026-10-04')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def write(p,x):Path(p).write_text(json.dumps(x,indent=2)+'\n')
def run(args):
 result=subprocess.run([str(x)for x in args],text=True,capture_output=True)
 row={'args':[str(x)for x in args],'exitCode':result.returncode,'stdout':result.stdout,'stderr':result.stderr}
 commands.append(row)
 if result.returncode:raise RuntimeError(json.dumps(row))
 return row
commands=[]
roster=read(R/'source-hashes.json');old=read(P/'source-hashes.json');snapshot=read(R/'snapshot-receipt.json')
assert len(roster)==45 and sum(p.endswith('.swift')for p in roster)==35
assert set(roster)==set(old)
assert all(sha(R/p)==h==sha(p)for p,h in roster.items())
changed=[p for p in roster if roster[p]!=old[p]]
assert changed==['Partsmith/Core/DocumentModel/PartsmithDocument.swift', 'Partsmith/Core/DocumentModel/ProjectModels.swift', 'Partsmith/Core/Export/PartPDFExporter.swift', 'Partsmith/Core/Layout/PartLayoutEngine.swift', 'Partsmith/Features/Inspector/InspectorView.swift']
assert all(now==old[name] for name,now in roster.items() if name.startswith(("Partsmith/Core/Detection/",)))
assert '** BUILD SUCCEEDED **' in(R/'build.log').read_text()
compile_lists=[]
for p in sorted((R/'DerivedData/Build/Intermediates.noindex').rglob('*.SwiftFileList')):
 paths=[Path(s.strip().strip('"'))for s in p.read_text().splitlines()if s.strip()]
 rels=[str(p.relative_to(R.resolve()))for p in paths]
 assert len(rels)==35 and set(rels)=={p for p in roster if p.endswith('.swift')}
 compile_lists.append({'path':str(p.relative_to(R)),'sha256':sha(p),'compiledSources':rels})
assert len(compile_lists)==2 and compile_lists[0]['compiledSources']==compile_lists[1]['compiledSources']
assert {Path(x['path']).parent.name for x in compile_lists}=={'arm64','x86_64'}
app=R/'DerivedData/Build/Products/Release/Partsmith.app';exe=app/'Contents/MacOS/Partsmith'
run(['/usr/bin/codesign','--force','--deep','--sign','-',app])
run(['/usr/bin/codesign','--verify','--all-architectures','--deep','--strict','--verbose=2',app])
built_signature=run(['/usr/bin/codesign','-d','--verbose=4',app]);assert 'Signature=adhoc'in built_signature['stderr']
archs=run(['/usr/bin/lipo','-archs',exe])['stdout'].split();assert set(archs)=={'arm64','x86_64'}
load=run(['/usr/bin/otool','-arch','all','-l',exe]);load_text=load.pop('stdout');(R/'load-commands.txt').write_text(load_text);load['stdoutArtifact']='load-commands.txt'
mins=re.findall(r'\bminos\s+(\S+)',load_text);assert mins==['14.0','14.0'],mins
info=plistlib.loads((app/'Contents/Info.plist').read_bytes());assert info['LSMinimumSystemVersion']=='14.0'
assert info['CFBundleIdentifier']=='com.example.Partsmith'
def bundle_manifest(base):
 rows=[]
 for p in sorted(base.rglob('*')):
  if p.is_symlink():rows.append({'path':str(p.relative_to(base)),'symlinkTarget':os.readlink(p)})
  elif p.is_file():rows.append({'path':str(p.relative_to(base)),'bytes':p.stat().st_size,'sha256':sha(p),'mode':stat.S_IMODE(p.stat().st_mode)})
 return rows
built_files=bundle_manifest(app);assert built_files
archive=R/'Partsmith-extraction-preview-macos.zip'
run(['/usr/bin/ditto','-c','-k','--sequesterRsrc','--keepParent',app,archive])
with zipfile.ZipFile(archive)as z:
 assert z.testzip()is None
 assert len(z.namelist())==len(set(z.namelist()))
 bundle_entries={n[len('Partsmith.app/'):]:n for n in z.namelist()if n.startswith('Partsmith.app/')and not n.endswith('/')}
 assert set(bundle_entries)=={f['path']for f in built_files}
 for f in built_files:
  data=z.read(bundle_entries[f['path']])
  if 'symlinkTarget'in f:assert data.decode()==f['symlinkTarget']
  else:assert hashlib.sha256(data).hexdigest()==f['sha256']and len(data)==f['bytes']
 assert all(n.startswith(('Partsmith.app/','__MACOSX/'))for n in z.namelist())
extract=R/'package-extracted';assert not extract.exists(),'Use a fresh extraction folder for an independent byte comparison'
run(['/usr/bin/ditto','-x','-k',archive,extract]);extracted=extract/'Partsmith.app'
assert bundle_manifest(extracted)==built_files,'ZIP extraction changed bundle files, modes or symlinks'
run(['/usr/bin/codesign','--verify','--all-architectures','--deep','--strict','--verbose=2',extracted])
extracted_signature=run(['/usr/bin/codesign','-d','--verbose=4',extracted]);assert 'Signature=adhoc'in extracted_signature['stderr']
assert set(run(['/usr/bin/lipo','-archs',extracted/'Contents/MacOS/Partsmith'])['stdout'].split())==set(archs)
old_app=P/'DerivedData/Build/Products/Release/Partsmith.app';old_files={f['path']:f for f in bundle_manifest(old_app)}
assert set(old_files)=={f['path']for f in built_files}
bundle_delta=[f['path']for f in built_files if f!=old_files[f['path']]]
assert set(bundle_delta)<={'Contents/MacOS/Partsmith','Contents/_CodeSignature/CodeResources'},bundle_delta
assert all(sha(R/p)==h==sha(p)for p,h in roster.items()),'Source changed during build'
assert sha('artifacts/macos/Partsmith-extraction-preview-macos.zip')==snapshot['previousPublicZIPSHA256'],'Published ZIP changed during private audit'
result={'status':'pass','scope':'Private release build/package verification; not published and no running-app actions','builtAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'snapshot':str(R),'sourceInputs':45,'compiledSwiftSourcesPerArchitecture':35,'sourceSnapshotAndCurrentTreeEqual':True,'sourceRosterSHA256':sha(R/'source-hashes.json'),'onlySourceDeltaFromReleasedSnapshot':changed,'priorReleasedSnapshot':str(P),'priorPublicZIPSHA256':snapshot['previousPublicZIPSHA256'],'staffDetectionCodeUnchanged':True,'architectureSet':archs,'minimumMacOSPerArchitecture':mins,'plistMinimumMacOS':info['LSMinimumSystemVersion'],'bundleIdentifier':info['CFBundleIdentifier'],'builtAndExtractedAdHocSignaturesValid':True,'zipCRCIntegrity':'pass','everyBundleFileExactAfterExtraction':True,'bundleFiles':built_files,'bundleDeltaFromPriorReleasedApp':bundle_delta,'compileLists':compile_lists,'privateArchive':str(archive),'privateArchiveSHA256':sha(archive),'privateArchiveBytes':archive.stat().st_size,'binarySHA256':sha(exe),'releaseBuildLogSHA256':sha(R/'build.log'),'commands':commands,'publishedZIPModified':False,'runningAppActions':'none'}
write(R/'private-package-audit.json',result)
print(json.dumps({k:result[k]for k in ['status','sourceInputs','compiledSwiftSourcesPerArchitecture','onlySourceDeltaFromReleasedSnapshot','architectureSet','minimumMacOSPerArchitecture','builtAndExtractedAdHocSignaturesValid','everyBundleFileExactAfterExtraction','bundleDeltaFromPriorReleasedApp','privateArchiveSHA256','binarySHA256','publishedZIPModified']},indent=2))
