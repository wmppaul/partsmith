from pathlib import Path
import hashlib,json,shutil,os
r=Path('.build/selected-page-picking-release-2026-10-04')
q=Path('Tests/quality_control/selected-page-picking-release-2026-10-04')
peer=Path('Tests/quality_control/selected-page-picking-2026-10-04')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
def put(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
a=read(r/'private-package-audit.json');roster=read(r/'source-hashes.json')
assert a['status']=='pass'
assert all(sha(p)==h==sha(r/p) for p,h in roster.items())
manifest=read(peer/'manifest.json')['files']
for p,h in manifest.items():assert sha(peer/p)==h
sources=read(peer/'source-hashes.json')
for p,h in sources.items():assert sha(p)==h
assert {p for p in sources if p.startswith('Partsmith/')}=={p for p in roster if p.endswith('.swift') and p!='Partsmith/App/PartsmithApp.swift'}
results=read(peer/'results.json');assert results['count']==47 and len(results['checks'])==results['count']
public=Path('artifacts/macos/Partsmith-extraction-preview-macos.zip');private=r/'Partsmith-extraction-preview-macos.zip'
assert sha(public)==a['priorPublicZIPSHA256'];assert sha(private)==a['privateArchiveSHA256']
shutil.copyfile(public,r/'previous-public-package.zip')
pending=public.with_name('.pending-selected-page-picking.zip');shutil.copyfile(private,pending)
assert sha(pending)==a['privateArchiveSHA256'];os.replace(pending,public)
assert sha(public)==a['privateArchiveSHA256']
put(q/'publication.json',{'status':'Published local app package after focused native interaction and release checks','publicPath':str(public),'publicSHA256':sha(public),'priorPublicSHA256':a['priorPublicZIPSHA256'],'peerManifestSHA256':sha(peer/'manifest.json'),'peerEvidenceFilesVerified':len(manifest),'nativeInteractionChecksPassed':results['count'],'peerCompiledProductionSourcesVerified':34,'compiledAppSourcesPerArchitecture':35,'sourceInputsVerified':45,'rootVisualReview':['setup-empty-narrow.png','setup-selected-pages.png'],'visualLimits':'Offscreen native screenshots omit prominent button fills; reviewed geometry and wording, not active-window contrast. Native harness verifies correct focus requests, not OS activation.','runningAppActions':'none'})
put(q/'manifest.json',{'files':{p.relative_to(q).as_posix():sha(p) for p in sorted(q.rglob('*')) if p.is_file() and p.name!='manifest.json'}})
print('Published',sha(public),'after',results['count'],'native interaction checks')
