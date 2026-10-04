from pathlib import Path
import hashlib,json,os,shutil
r=Path('.build/system-assignment-release-2026-10-04');q=Path('Tests/quality_control/system-assignment-release-2026-10-04')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(Path(p).read_text())
def put(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n')
a=read(r/'private-package-audit.json');roster=read(r/'source-hashes.json')
assert a['status']=='pass' and all(sha(p)==h==sha(r/p) for p,h in roster.items())
reviews=[]
for name in ['system-selection-2026-10-04','system-bar-count-2026-10-04','system-bar-ui-2026-10-04']:
 peer=Path('Tests/quality_control')/name
 manifest=read(peer/'manifest.json');manifest=manifest.get('files',manifest)
 for p,h in manifest.items():assert sha(peer/p)==(h['sha256'] if isinstance(h,dict) else h)
 sources=read(peer/'source-hashes.json')
 for p,h in sources.items():
  assert sha(p)==h,p
  if p.startswith('Partsmith/'):assert roster[p]==h,p
 reviews.append({'path':str(peer),'manifestSHA256':sha(peer/'manifest.json'),'evidenceFilesVerified':len(manifest),'sourceFilesVerified':len(sources)})
selection=read(Path(reviews[0]['path'])/'results.json');assert selection['checks']==96 and not selection['failures']
count=read(Path(reviews[1]['path'])/'results.json');assert count['checks']==22 and not count['failures']
native=Path(reviews[2]['path'])
assert read(native/'ui-results.json')['count']==14
assert read(native/'request-results.json')['count']==21
existing=read(q/'existing-assignment-tests.json');assert existing['checks']==46 and existing['failures']==0
assert all(sha(p)==h for p,h in existing['testSourceHashes'].items())
assert '46 batch system-assignment checks passed' in(q/'existing-assignment-test.log').read_text()
public=Path('artifacts/macos/Partsmith-extraction-preview-macos.zip');private=r/'Partsmith-extraction-preview-macos.zip'
assert sha(public)==a['priorPublicZIPSHA256'] and sha(private)==a['privateArchiveSHA256']
shutil.copyfile(public,r/'previous-public-package.zip')
pending=public.with_name('.pending-system-assignment.zip');shutil.copyfile(private,pending)
assert sha(pending)==a['privateArchiveSHA256'];os.replace(pending,public)
put(q/'publication.json',{'status':'Published local package after independent source, geometry, count, lifecycle and native panel review','publicPath':str(public),'publicSHA256':sha(public),'priorPublicSHA256':a['priorPublicZIPSHA256'],'independentReviews':reviews,'compiledAppSourcesPerArchitecture':37,'sourceInputsVerified':47,'runningAppActions':'none','rootVisualReview':['system-bar-ui-2026-10-04/assign-system-suggested-six.png','system-bar-ui-2026-10-04/assign-system-recalled-eleven.png'],'nativePanelChecks':14,'requestLifecycleChecks':21,'interactionScope':'Inactive native panel: accessibility actions plus direct NSEvent drag selection and repeat-drag draft preservation. Captures omit some prominent buttons; actions are verified separately. Modifier/zoom/scroll variants are geometry checks, not native events.'})
put(q/'manifest.json',{'files':{p.relative_to(q).as_posix():sha(p) for p in sorted(q.rglob('*')) if p.is_file() and p.name!='manifest.json'}})
put('docs/releases/v0.1.0-alpha.4.json',{'reviewDirectory':str(q),'sha256':sha(public)})
print('Published local package',sha(public))
