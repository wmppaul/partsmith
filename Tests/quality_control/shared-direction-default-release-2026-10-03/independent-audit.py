import json,hashlib,subprocess,zipfile,plistlib,os,re,datetime
from pathlib import Path
root=Path.cwd();base=root/'.build/shared-direction-default-release-2026-10-03'
out=root/'Tests/quality_control/shared-direction-default-release-2026-10-03/independent-package-audit.json';out.parent.mkdir(parents=True,exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
def artifact(p):return {'path':str(p.relative_to(root)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size}
def command(argv):
 r=subprocess.run(argv,capture_output=True,text=True,env={**os.environ,'DEVELOPER_DIR':'/Applications/Xcode.app/Contents/Developer'})
 return {'argv':argv,'exitCode':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
manifest=json.loads((base/'source-hashes.json').read_text());inputs=[]
for name,expected in manifest.items():
 a=base/name;b=root/name
 inputs.append({'path':name,'expectedSHA256':expected,'snapshotSHA256':sha(a.read_bytes()),'currentSHA256':sha(b.read_bytes()),'matches':sha(a.read_bytes())==sha(b.read_bytes())==expected})
assert all(r['matches'] for r in inputs)
expectedSwift={str((base/n).resolve()) for n in manifest if n.endswith('.swift')}
assert len(expectedSwift)==35
currentSwift={str(p.relative_to(root)) for p in (root/'Partsmith').rglob('*.swift')}
assert currentSwift=={p for p in manifest if p.endswith('.swift')}
compileLists=[]
for arch in ['x86_64','arm64']:
 f=base/f'DerivedData/Build/Intermediates.noindex/Partsmith.build/Release/Partsmith.build/Objects-normal/{arch}/Partsmith.SwiftFileList'
 paths=[line.strip().strip('"') for line in f.read_text().splitlines() if line.strip()]
 assert set(paths)==expectedSwift and len(paths)==len(expectedSwift)
 compileLists.append({**artifact(f),'architecture':arch,'sourceCount':len(paths),'exactFrozenSwiftSet':True})
app=base/'DerivedData/Build/Products/Release/Partsmith.app';exe=app/'Contents/MacOS/Partsmith';zipPath=base/'Partsmith-extraction-preview-macos.zip'
extract=base/'independent-extracted';extract.mkdir(exist_ok=True)
zipRows=[]
with zipfile.ZipFile(zipPath) as z:
 assert z.testzip() is None
 members=z.infolist();assert len({m.filename for m in members})==len(members)
 for m in members:
  p=Path(m.filename)
  assert not p.is_absolute() and '..' not in p.parts
  assert p.parts[0] in ('Partsmith.app','__MACOSX')
  data=z.read(m.filename) if not m.is_dir() else b''
  row={'path':m.filename,'directory':m.is_dir(),'bytes':m.file_size,'unixMode':oct(m.external_attr>>16)}
  if not m.is_dir():row['sha256']=sha(data)
  if p.parts[0]=='Partsmith.app' and not m.is_dir():
   relative=Path(*p.parts[1:]);built=app/relative
   assert built.is_file() and built.read_bytes()==data
   row['matchesBuiltBundle']=True
   target=extract/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
   mode=(m.external_attr>>16)&0o777
   if mode:target.chmod(mode)
  zipRows.append(row)
 bundleFiles={str(Path('Partsmith.app')/p.relative_to(app)) for p in app.rglob('*') if p.is_file()}
 zipBundleFiles={m.filename for m in members if not m.is_dir() and m.filename.startswith('Partsmith.app/')}
 assert bundleFiles==zipBundleFiles
extractedApp=extract/'Partsmith.app';extractedExe=extractedApp/'Contents/MacOS/Partsmith'
assert extractedExe.read_bytes()==exe.read_bytes()
checks={
 'architectures':command(['/usr/bin/lipo','-archs',str(exe)]),
 'minimumOS':command(['/usr/bin/xcrun','vtool','-show-build',str(exe)]),
 'builtStrictSignature':command(['/usr/bin/codesign','--verify','--deep','--strict','--all-architectures','--verbose=4',str(app)]),
 'extractedStrictSignature':command(['/usr/bin/codesign','--verify','--deep','--strict','--all-architectures','--verbose=4',str(extractedApp)]),
 'signatureDetails':command(['/usr/bin/codesign','-dv','--verbose=4',str(extractedApp)])}
assert all(v['exitCode']==0 for v in checks.values())
assert set(checks['architectures']['stdout'].split())=={'x86_64','arm64'}
assert checks['minimumOS']['stdout'].count('minos 14.0')==2
info=plistlib.loads((app/'Contents/Info.plist').read_bytes());assert info['LSMinimumSystemVersion']=='14.0'
assert 'Signature=adhoc' in checks['signatureDetails']['stderr']
log=(base/'build.log').read_text();assert '** BUILD SUCCEEDED **' in log and '** BUILD FAILED **' not in log
assert 'CreateUniversalBinary' in log
for arch in ['x86_64','arm64']:assert f'-target {arch}-apple-macos14.0' in log
native='Partsmith/Core/Detection/NativeScorePageAnalyzer.swift';production='9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01';assert manifest[native]==production
report={
 'auditedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'scope':'Private package identity and build integrity only. No publication, app launch, user-app modification or musical-output approval.',
 'result':'pass',
 'package':artifact(zipPath),'executable':artifact(exe),'sourceHashManifest':artifact(base/'source-hashes.json'),'buildLog':artifact(base/'build.log'),
 'sourceChecks':{'boundFiles':45,'swiftFiles':35,'allFrozenCurrentAndSnapshotHashesEqual':True,'currentSwiftFilesExactlyManifest':True,'inputs':inputs,'compileSourceLists':compileLists},
 'productionDetector':{'path':native,'sha256':production,'frozenEqualsCurrent':True,'monotoneCandidatePromoted':False},
 'build':{'succeededMarker':True,'failedMarker':False,'configuration':'Release','targets':['x86_64-apple-macos14.0','arm64-apple-macos14.0'],'universalLinkObserved':True,'minimumMacOS':'14.0','plistMinimumMacOS':info['LSMinimumSystemVersion'],'notes':'Build log includes sandbox/CoreSimulator service diagnostics but ends with BUILD SUCCEEDED; this receipt does not classify those as compile failures.'},
 'signature':{'kind':'ad hoc','allArchitecturesStrictVerificationPassesBuiltAndExtracted':True,'developerIDOrNotarizationClaim':False},
 'archive':{'crcPass':True,'memberCount':len(zipRows),'bundlePayloadFiles':len(bundleFiles),'bundlePayloadMatchesBuiltExactly':True,'executableExtractedMatchesBuiltExactly':True,'metadataRoot':'__MACOSX','unsafeOrDuplicateMembers':False,'members':zipRows},
 'commands':checks,
 'publicationStatus':'Private package remains staged pending parent source/output gates; this audit performs no publication.'}
out.write_text(json.dumps(report,indent=2)+'\n')
# Recheck immutable file bindings after inspection.
assert artifact(zipPath)==report['package'] and artifact(exe)==report['executable']
assert all(sha((root/r['path']).read_bytes())==r['expectedSHA256'] for r in inputs)
print(json.dumps({'audit':str(out.relative_to(root)),'auditSHA256':sha(out.read_bytes()),'zipSHA256':report['package']['sha256'],'executableSHA256':report['executable']['sha256'],'sources':len(inputs),'swift':35,'zipMembers':len(zipRows),'payloadFiles':len(bundleFiles),'result':'pass'},indent=2))
