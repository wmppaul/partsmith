from pathlib import Path
from datetime import datetime, timezone
import hashlib,json,os,plistlib,re,shutil,subprocess,tempfile,zipfile
root=Path(__file__).resolve().parents[3]
work=root/'.build/preview-crop-release-2026-10-03'
evidence=Path(__file__).resolve().parent
app=work/'DerivedData/Build/Products/Release/Partsmith.app'
exe=app/'Contents/MacOS/Partsmith'
package=work/'Partsmith-extraction-preview-macos.zip'
public=root/'artifacts/macos/Partsmith-extraction-preview-macos.zip'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources=json.loads((work/'source-hashes.json').read_text())
for name,h in sources.items():assert sha(root/name)==sha(work/name)==h,name
assert {name for name in sources if name.endswith('.swift')}=={str(p.relative_to(root)) for p in (root/'Partsmith').rglob('*.swift')}
assert '** BUILD SUCCEEDED **' in (work/'build.log').read_text()
outputs={}
for name,cmd in {'architectures':['lipo','-archs',str(exe)],'minimum-os':['xcrun','vtool','-show-build',str(exe)],'signing':['codesign','-dv',str(app)],'signature-verification':['codesign','--verify','--deep','--strict',str(app)]}.items():
 p=subprocess.run(cmd,check=True,capture_output=True,text=True);outputs[name]=p.stdout+p.stderr;(evidence/f'{name}.log').write_text(outputs[name])
assert set(outputs['architectures'].split())=={'arm64','x86_64'}
minimum=dict(re.findall(r'architecture ([^)]+)\):.*?minos ([0-9.]+)',outputs['minimum-os'],re.S))
assert minimum=={'arm64':'14.0','x86_64':'14.0'}
assert plistlib.loads((app/'Contents/Info.plist').read_bytes())['LSMinimumSystemVersion']=='14.0'
assert 'Signature=adhoc' in outputs['signing']
files={str(p.relative_to(app.parent)):sha(p) for p in app.rglob('*') if p.is_file()}
with zipfile.ZipFile(package) as z:
 assert z.testzip() is None
 actual={i.filename for i in z.infolist() if not i.is_dir() and i.filename.startswith('Partsmith.app/')}
 assert actual==set(files)
 for name,h in files.items():assert hashlib.sha256(z.read(name)).hexdigest()==h,name
 assert z.getinfo('Partsmith.app/Contents/MacOS/Partsmith').external_attr>>16&0o111
old=sha(public);backup=work/f'previous-public-{old}.zip';shutil.copy2(public,backup);assert sha(backup)==old
new=sha(package)
with tempfile.NamedTemporaryFile(dir=public.parent,prefix='.preview-crop-',suffix='.zip',delete=False) as f:
 temp=Path(f.name);f.write(package.read_bytes());f.flush();os.fsync(f.fileno())
assert sha(temp)==new and sha(public)==old
os.chmod(temp,0o644);os.replace(temp,public);assert sha(public)==new
with zipfile.ZipFile(public) as z:assert z.testzip() is None
for name,h in sources.items():assert sha(root/name)==h
shutil.copy2(work/'source-hashes.json',evidence/'source-hashes.json')
with zipfile.ZipFile(evidence/'build-log.zip','w',zipfile.ZIP_DEFLATED) as z:z.write(work/'build.log','build.log')
record={'verifiedAtUTC':datetime.now(timezone.utc).isoformat(),'change':'Drag top/bottom crop edges directly in part Preview; shared source crop and Undo, snapshot-safe gestures, stable layout during drag and selected-system reflow anchor.','artifact':str(public.relative_to(root)),'artifactSHA256':new,'artifactBytes':public.stat().st_size,'executableSHA256':sha(exe),'architectures':['arm64','x86_64'],'minimumMacOS':minimum,'signing':'ad hoc; strict bundle verification passed; not notarized','sourceHashes':sources,'bundleFileSHA256':files,'previousArtifactSHA256':old,'previousArtifactBackup':str(backup.relative_to(root)),'validation':{'coreChecks':110,'nativeInteractionChecks':34,'layoutChecks':5389,'exportChecks':169,'fullPartPreviewChecks':24,'largePartBands':131,'largePartPages':10,'largePartEnqueueMilliseconds':0.23,'scope':'Hidden native AppKit interaction and model/export checks. No live user app walkthrough or automatic musical-quality claim.'},'detectorUnchanged':True,'privateMonotoneCandidateIncluded':False,'runningAppOrUserDocumentModified':False,'sourceSnapshot':str(work.relative_to(root)),'publication':'Verified same-directory atomic ZIP replacement only; running app bundle remains untouched.'}
(evidence/'release.json').write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
(evidence/'manifest.json').write_text(json.dumps({str(p.relative_to(evidence)):sha(p) for p in sorted(evidence.iterdir()) if p.is_file() and p.name!='manifest.json'},indent=2)+'\n')
print(json.dumps({k:record[k] for k in ['artifactSHA256','artifactBytes','executableSHA256','runningAppOrUserDocumentModified']},indent=2))
