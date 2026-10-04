from pathlib import Path
import hashlib,json,shutil,os
r=Path('.build/literal-layout-release-2026-10-04');q=Path('Tests/quality_control/literal-layout-release-2026-10-04')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
def put(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
a=read(r/'private-package-audit.json');roster=read(r/'source-hashes.json')
assert a['status']=='pass' and all(sha(p)==h==sha(r/p) for p,h in roster.items())
reviews=[]
for name in ['literal-layout-regressions-2026-10-04','literal-layout-ui-2026-10-04','brahms-alignment-2026-10-04']:
 peer=Path('Tests/quality_control')/name
 manifest=read(peer/'manifest.json');manifest=manifest.get('files',manifest)
 for p,h in manifest.items():
  assert sha(peer/p)==(h['sha256'] if isinstance(h,dict) else h)
 sources=read(peer/('candidate-source-hashes.json' if name.startswith('brahms') else 'source-hashes.json'))
 for p,h in sources.items():
  assert sha(p)==h
  if p.startswith('Partsmith/'):assert roster[p]==h
 if name.startswith('literal-layout-regressions'):
  result=read(peer/'review.json')
  assert result['status']=='pass' and result['layoutChecks']==7157 and result['nativeScaleExportChecks']==411 and result['failures']==0
 elif name.startswith('literal-layout-ui'):
  result=read(peer/'results.json');assert result['count']==13 and len(result['checks'])==13
  assert set(sources)=={p for p in roster if p.endswith('.swift') and p!='Partsmith/App/PartsmithApp.swift'}
 else:
  result=read(peer/'review.json');assert result['status']=='passed' and result['beforeNativeChecks']==11 and result['afterNativeChecks']==69
  assert result['nativePixelMaximumChannelDifference']==0 and result['nativePixelPages']==7
  for p,h in read(peer/'input-hashes.json').items():assert sha(p)==h
 reviews.append({'path':str(peer),'manifestSHA256':sha(peer/'manifest.json'),'evidenceFilesVerified':len(manifest),'sourceFilesVerified':len(sources)})
public=Path('artifacts/macos/Partsmith-extraction-preview-macos.zip');private=r/'Partsmith-extraction-preview-macos.zip'
assert sha(public)==a['priorPublicZIPSHA256'] and sha(private)==a['privateArchiveSHA256']
shutil.copyfile(public,r/'previous-public-package.zip')
pending=public.with_name('.pending-literal-layout.zip');shutil.copyfile(private,pending)
assert sha(pending)==a['privateArchiveSHA256'];os.replace(pending,public);assert sha(public)==a['privateArchiveSHA256']
put(q/'publication.json',{'status':'Published local app package after independent regression, real Brahms and native Inspector reviews','publicPath':str(public),'publicSHA256':sha(public),'priorPublicSHA256':a['priorPublicZIPSHA256'],'independentReviews':reviews,'layoutAssertions':7157,'nativeExportChecks':411,'nativeInspectorChecks':13,'brahmsBaselineChecks':11,'brahmsCandidateChecks':69,'compiledAppSourcesPerArchitecture':35,'sourceInputsVerified':45,'rootVisualReview':['brahms-alignment-2026-10-04/alignment-comparison.png','literal-layout-ui-2026-10-04/inspector-340-scrolled.png'],'visualLimits':'Brahms is a four-band layout reproduction, not new whole-score extraction. Inspector is an inactive private view with supplied scale metadata; actual scale, spacing and source positions are covered by native exports. Deliberate overflow fixtures clip at paper edges.','runningAppActions':'none'})
put(q/'manifest.json',{'files':{p.relative_to(q).as_posix():sha(p) for p in sorted(q.rglob('*')) if p.is_file() and p.name!='manifest.json'}})
print('Published',sha(public),'after all independent checks passed')
