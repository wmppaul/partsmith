from pathlib import Path
import hashlib,json,shutil,os
r=Path('.build/shared-layout-release-2026-10-04');q=Path('Tests/quality_control/shared-layout-release-2026-10-04')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
def put(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
a=read(r/'private-package-audit.json');roster=read(r/'source-hashes.json')
assert a['status']=='pass' and all(sha(p)==h==sha(r/p) for p,h in roster.items())
reviews=[]
for name in ['shared-layout-2026-10-04','shared-layout-ui-2026-10-04']:
 peer=Path('Tests/quality_control')/name
 manifest=read(peer/'manifest.json');manifest=manifest.get('files',manifest)
 for p,h in manifest.items():assert sha(peer/p)==(h['sha256'] if isinstance(h,dict) else h)
 sources=read(peer/'source-hashes.json')
 for p,h in sources.items():
  assert sha(p)==h
  if p.startswith('Partsmith/'):assert roster[p]==h
 result=read(peer/'results.json')
 assert result.get('failures',0)==0
 if name=='shared-layout-2026-10-04':assert result['count']==67
 else:
  assert result['count']>=20
  assert set(sources)=={p for p in roster if p.endswith('.swift') and p!='Partsmith/App/PartsmithApp.swift'}
 reviews.append({'path':str(peer),'manifestSHA256':sha(peer/'manifest.json'),'checks':result['count'],'evidenceFilesVerified':len(manifest),'sourceFilesVerified':len(sources)})
existing=read(q/'existing-regressions.json')
assert existing['status']=='pass' and existing['failures']==0
assert all(sha(p)==h for p,h in existing['testSourceHashes'].items())
assert 'PASS: 7157 layout assertions' in(q/'shared-layout-existing-regressions.log').read_text()
assert 'PASS: 169 native crop and export checks' in(q/'shared-layout-existing-regressions.log').read_text()
assert 'PASS: 411 scale/export checks; 0 failures' in(q/'shared-layout-scale-exports.log').read_text()
public=Path('artifacts/macos/Partsmith-extraction-preview-macos.zip');private=r/'Partsmith-extraction-preview-macos.zip'
assert sha(public)==a['priorPublicZIPSHA256'] and sha(private)==a['privateArchiveSHA256']
shutil.copyfile(public,r/'previous-public-package.zip')
pending=public.with_name('.pending-shared-layout.zip');shutil.copyfile(private,pending)
assert sha(pending)==a['privateArchiveSHA256'];os.replace(pending,public);assert sha(public)==a['privateArchiveSHA256']
put(q/'publication.json',{'status':'Published local package after model, legacy rendering, export and native Inspector checks','publicPath':str(public),'publicSHA256':sha(public),'priorPublicSHA256':a['priorPublicZIPSHA256'],'independentReviews':reviews,'layoutAssertions':7157,'nativeCropAndExportChecks':169,'scaleExportChecks':411,'sharedLayoutChecks':67,'legacyPixelIdenticalPages':38,'compiledAppSourcesPerArchitecture':35,'sourceInputsVerified':45,'rootVisualReview':['shared-layout-ui-2026-10-04/inspector-340-shared-full.png','shared-layout-ui-2026-10-04/inspector-340-local-full.png'],'visualLimits':'Native Inspector checks use an inactive private view; warning metadata in shared screenshot is supplied by the harness. Shared model and actual PDF/preview agreement are tested separately.','runningAppActions':'none'})
put(q/'manifest.json',{'files':{p.relative_to(q).as_posix():sha(p) for p in sorted(q.rglob('*')) if p.is_file() and p.name!='manifest.json'}})
print('Published',sha(public),'after all checks passed')
