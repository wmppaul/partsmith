"""Archive completed evidence; no detection, compilation, export, or source mutations."""
from pathlib import Path
import hashlib,json,shutil,zipfile
repo=Path.cwd();run=repo/'.build/heading-blocks-2026-10-03';out=repo/'Tests/quality_control/heading-block-native-2026-10-03'
load=lambda p:json.loads(p.read_text())
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
 return h.hexdigest()
def record(p):return {'path':str(p.relative_to(repo)),'bytes':p.stat().st_size,'sha256':sha(p)}
config=load(run/'config.json');comparison=load(run/'candidate-final-comparison.json')
assert len(config)==len(comparison)==16
assert {c['id'] for c in config}=={c['id'] for c in comparison}
assert sum(c['pages'] for c in comparison)==449 and sum(c['bands'] for c in comparison)==6324
assert sum(len(c['changedCopies']) for c in comparison)==4
assert all(not c[k] for c in comparison for k in ['changedMainCrops','sourceHeadingEnvelopesLost','changedOtherBandData','baselineErrors','candidateErrors'])
assert all(c['ocrObservationsExact'] for c in comparison)
selected={p for p in run.rglob('*') if p.is_file() and p.suffix in {'.json','.swift','.sh','.log'}}
external=[];normalization=[];rows=[]
for c in config:
 source=Path(c['source']);profile=(repo/c['profile']).resolve();inventory=Path(c['inventory'])
 assert sha(source)==c['sourceSHA256'] and sha(profile)==c['profileSHA256'] and sha(inventory)==c['inventorySHA256'],c['id']
 external.append({'role':'original score PDF — intentionally not duplicated',**record(source)})
 selected.update([profile,inventory])
 if 'originalInventory' in c:
  original=Path(c['originalInventory']['path']);assert sha(original)==c['originalInventory']['sha256'];selected.add(original)
  a=load(original);b=load(inventory);assert a['pages']==b['pages']
  normalization.append({'id':c['id'],'original':record(original),'normalized':record(inventory),'pagesExact':True,'note':'Wrapped pages retained exactly; source path/hash and rectifications supplied by the bound configuration.'})
 summaries=[]
 for variant in ['baseline','candidate-final']:
  folder=run/variant/c['id'];s=load(folder/'summary.json');assert s['errors']==[] and s['sourceSHA256']==c['sourceSHA256'];summaries.append(s)
 rows.append({'id':c['id'],'pages':summaries[1]['pages'],'bands':summaries[1]['bandCount'],'sourceSHA256':c['sourceSHA256'],'profile':c['profile'],'profileSHA256':c['profileSHA256'],'planCanApply':summaries[1]['planCanApply'],'emptyStaffPagesZeroBased':summaries[1]['emptyStaffPages'],'baselineHeadingFragments':summaries[0]['headingCount'],'finalHeadingBlocks':summaries[1]['headingCount'],'copiedRows':summaries[1]['copiedRows']})
for variant in ['baseline','candidate','candidate-final']:
 for name,h in load(run/variant/'source-hashes.json').items():assert sha(run/variant/name)==h,(variant,name)
for name,h in load(run/'release-source-hashes.json').items():
 p=repo/name;assert sha(p)==h,name;selected.add(p)
for name in ['test_score_planner.sh','test_score_planner.swift','test_shared_direction_app.sh','test_shared_direction_app.swift','test_heading_overrides.sh','test_heading_overrides.swift','test_heading_categories.sh','test_heading_categories.swift']:
 selected.add(repo/'tools'/name)
worker=load(run/'native-worker-final/schumann-summary.json');assert worker['issues']==[] and worker['planCanApply'] and worker['bandCount']==825 and worker['projectUnchanged'] and worker['progressCleared']
assert len(load(run/'native-worker-final/schumann-inventory.json')['pages'])==56
assert load(run/'native-worker-final/comparison.json')['fullWorkerBandPlanExactToHeadingOnlyFinal']
assert 'PASS 83' in (run/'regressions/planner-final.log').read_text()
assert '113 shared direction app checks passed' in (run/'regressions/shared-direction-app-final.log').read_text()
assert '** BUILD SUCCEEDED **' in (run/'release-build.log').read_text()
release=load(run/'archive-validation.json');releaseArchive=run/'Partsmith-heading-blocks-preview.zip';assert sha(releaseArchive)==release['archiveSHA256']
with zipfile.ZipFile(releaseArchive) as z:
 assert z.testzip() is None
 exe=next(n for n in z.namelist() if n.endswith('Contents/MacOS/Partsmith'))
 assert hashlib.sha256(z.read(exe)).hexdigest()==release['executableSHA256']
external.append({'role':'validated app archive — intentionally excluded from evidence archive',**record(releaseArchive)})
delivery=repo/'output/pdf/auto-qc-2026-09-21/schumann-quintet-06822-heading-blocks';deliveryHashes=load(delivery/'delivery-hashes.json')
for name,h in deliveryHashes.items():assert sha(delivery/name)==h,name
for name in ['README.md','delivery-hashes.json']:external.append({'role':'delivered reviewed parts record',**record(delivery/name)})
# Small readily readable artifacts accompany the raw archive.
for origin,dest in [('candidate-final-comparison.json','comparison.json'),('config.json','config.json'),('original-config.json','original-config.json'),('candidate-final/source-hashes.json','final-core-hashes.json'),('baseline/source-hashes.json','baseline-core-hashes.json'),('release-source-hashes.json','release-source-hashes.json'),('native-worker-final/schumann-summary.json','fresh-auto-summary.json'),('native-worker-final/comparison.json','fresh-auto-comparison.json'),('regressions/planner-final.log','planner-final.log'),('regressions/shared-direction-app-final.log','shared-direction-app-final.log'),('release-build.log','release-build.log'),('archive-validation.json','archive-validation.json'),('baseline/input-format-error.log','input-format-error.log')]:shutil.copy2(run/origin,out/dest)
(out/'normalization-verification.json').write_text(json.dumps(normalization,indent=2)+'\n')
(out/'corpus-summary.json').write_text(json.dumps(rows,indent=2)+'\n')
summary={'scope':'16 initialized-profile heading replays over retained staff inventories; separate fresh 56-page native Auto','scores':16,'pages':449,'bands':6324,'musicCropChanges':0,'changedSourceCopyRows':4,'lostHeadingEnvelopes':0,'headingFragmentsBefore':63,'headingBlocksAfter':62,'ocrObservationsExact':True,'recognitionErrors':0,'freshAuto':{'pages':56,'bands':825,'copies':35,'issues':0,'planExactToHeadingReplay':True},'plannerChecks':83,'sharedDirectionAppChecks':113,'releaseArchitectures':release['architectures'],'delivery':str(delivery.relative_to(repo))}
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
entries=[record(p) for p in sorted(selected)];assert all(not e['path'].startswith('../') for e in entries)
manifest={'archive':'evidence.zip','paths':'Entries preserve repository-relative original paths. Original PDFs and binaries are excluded; listed PDF source hashes bind them. Configurations retain their recorded absolute paths.','entries':entries,'externalInputsAndArtifacts':external,'excludedBinaries':[record(p) for p in [run/'baseline/run_headings',run/'candidate/run_headings',run/'candidate-final/run_headings',run/'native-worker-final/native_worker']]}
(out/'data-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
archive=out/'evidence.zip';assert not archive.exists(),'Preserve existing evidence package'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for item in entries:
  p=repo/item['path'];assert sha(p)==item['sha256'];z.write(p,item['path'])
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 assert sorted(z.namelist())==sorted(e['path'] for e in entries)
 for item in entries:
  data=z.read(item['path']);assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256'],item['path']
verified={'archiveSHA256':sha(archive),'compressedBytes':archive.stat().st_size,'uncompressedBytes':sum(e['bytes'] for e in entries),'entriesVerified':len(entries),'allEntrySHA256AndSizesMatch':True,'zipCRCVerified':True,'originalInputHashesVerified':True,'allFrozenCoreHashesVerified':True,'deliveryPayloadHashesVerified':len(deliveryHashes)}
(out/'archive-verification.json').write_text(json.dumps(verified,indent=2)+'\n');print(json.dumps(verified,indent=2))
