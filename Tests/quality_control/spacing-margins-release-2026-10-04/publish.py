from pathlib import Path
import hashlib,json,shutil,os
r=Path('.build/spacing-margins-release-2026-10-04')
q=Path('Tests/quality_control/spacing-margins-release-2026-10-04')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
def put(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
a=read(r/'private-package-audit.json');roster=read(r/'source-hashes.json')
assert a['status']=='pass'
assert all(sha(p)==h==sha(r/p) for p,h in roster.items())
reviews=[]
for name in ['layout-controls-2026-10-04','inspector-spacing-ui-2026-10-04']:
 peer=Path('Tests/quality_control')/name
 manifest=read(peer/'manifest.json')
 for p,h in manifest.items():
  expected=h['sha256'] if isinstance(h,dict) else h
  assert sha(peer/p)==expected
 sources=read(peer/'source-hashes.json')
 for p,h in sources.items():
  assert sha(p)==h
  if p.startswith('Partsmith/'):assert roster[p]==h
 if name.startswith('layout-controls'):
  result=read(peer/'review.json')
  assert result['status']=='pass' and result['layoutAssertions']==5443 and result['nativeExportChecks']==302 and result['nativeExportFailures']==0
 else:
  result=read(peer/'results.json');assert result['count']==10 and len(result['checks'])==10
  assert set(sources)=={p for p in roster if p.endswith('.swift') and p!='Partsmith/App/PartsmithApp.swift'}
 reviews.append({'path':str(peer),'manifestSHA256':sha(peer/'manifest.json'),'evidenceFilesVerified':len(manifest),'sourceFilesVerified':len(sources)})
public=Path('artifacts/macos/Partsmith-extraction-preview-macos.zip');private=r/'Partsmith-extraction-preview-macos.zip'
assert sha(public)==a['priorPublicZIPSHA256'];assert sha(private)==a['privateArchiveSHA256']
shutil.copyfile(public,r/'previous-public-package.zip')
pending=public.with_name('.pending-spacing-margins.zip');shutil.copyfile(private,pending)
assert sha(pending)==a['privateArchiveSHA256'];os.replace(pending,public)
assert sha(public)==a['privateArchiveSHA256']
put(q/'publication.json',{'status':'Published local app package after independent layout/export and native Inspector checks','publicPath':str(public),'publicSHA256':sha(public),'priorPublicSHA256':a['priorPublicZIPSHA256'],'independentReviews':reviews,'layoutAssertions':5443,'nativeExportChecks':302,'nativeInspectorChecks':10,'compiledAppSourcesPerArchitecture':35,'sourceInputsVerified':45,'rootVisualReview':['layout-controls-2026-10-04/beethoven-flute-1.40.png','layout-controls-2026-10-04/beethoven-default-18pt-margins.png','inspector-spacing-ui-2026-10-04/inspector-340-scrolled.png'],'visualLimits':'Inspector is an inactive private view with supplied scale metadata. Layout/export tests calculate real scale and compare complete-source rendering. No live user-app walkthrough.','runningAppActions':'none'})
put(q/'manifest.json',{'files':{p.relative_to(q).as_posix():sha(p) for p in sorted(q.rglob('*')) if p.is_file() and p.name!='manifest.json'}})
print('Published',sha(public),'after all focused checks passed')
