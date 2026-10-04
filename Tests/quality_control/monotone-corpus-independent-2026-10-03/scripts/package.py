from pathlib import Path
import hashlib,json,zipfile,shutil,gzip
R=Path.cwd();S=R/'.build/monotone-corpus-independent-2026-10-03';W=R/'.build/monotone-line-corpus-2026-10-03';D=R/'Tests/quality_control/monotone-corpus-independent-2026-10-03';P=R/'Tests/quality_control/envelope-compatibility-corpus-independent-2026-10-03';read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();D.mkdir(exist_ok=True)
def write(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def copy(p,n):q=D/n;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
summary=read(S/'independent-summary.json');reuses=read(S/'source-review-reuse.json');assert summary['complete'] and summary['terminalScores']==36 and summary['invalidGeometryRecords']==0 and summary['newForeignIDRelations']==0
assert sha(P/'manifest.json')=='12a5c0d1c3f17b848e4f9e5e6397743f0d91c3ead9d13b61ec73ff3189689ff3';assert sha(P/'native-inventories.zip')=='04637fd157e6564bec6f5794da4b00edb437af90a0b87a6f69f8405e69d82a85'
write(D/'baseline-archive-reference.json',{'path':str((P/'native-inventories.zip').relative_to(R)),'sha256':sha(P/'native-inventories.zip'),'manifestPath':str((P/'manifest.json').relative_to(R)),'manifestSHA256':sha(P/'manifest.json'),'contents':'All 36 production9f8 baseline inventories replanned by current772, exact raw pages and plans; source/profile geometry bindings verified again for this candidate. Not duplicated here.'})
for n in ['independent-summary.json','independent-protocol-before-comparison.json','baseline-binding.json','source-review-reuse.json','priority-by-score.json']:copy(S/n,n)
for n in ['prepare.py','compare.py','finish-comparison.py','review-reuse.py','final-comparison.log','finish-comparison.log']:copy(S/n,'scripts/'+n)
copy(Path(__file__),'scripts/package.py')
for n in ['build-binding.json','inputs.json','status.json','protocol-before-results.json','run.py','corpus.log']:copy(W/n,'native-run/'+n)
# Hash-bind the completed bounded gate report and separate corrected39 source review.
refs=[]
for p in [R/'Tests/quality_control/numbered-monotone-independent-2026-10-03/manifest.json',R/'Tests/quality_control/envelope-corpus-two-score-source-review-2026-10-03/hashes.json',R/'Tests/quality_control/monotone-corrected39-independent-2026-10-03/review.json']:
 if p.exists():refs.append({'path':str(p.relative_to(R)),'sha256':sha(p)})
write(D/'related-studies.json',refs)
archives=[]
def archive(name,files):
 entries=[]
 with zipfile.ZipFile(D/name,'w',zipfile.ZIP_DEFLATED,compresslevel=6)as z:
  for p,arc in files:z.write(p,arc);entries.append({'path':arc,'sha256':sha(p),'bytes':p.stat().st_size})
  z.writestr('contents.json',json.dumps(entries,indent=2)+'\n')
 with zipfile.ZipFile(D/name)as z:
  for row in entries:assert hashlib.sha256(z.read(row['path'])).hexdigest()==row['sha256']
 archives.append({'archive':name,'sha256':sha(D/name),'payloads':entries})
ns=['comparison.json','compact-source-review-queue.json','changed-crop-review-jobs.json','per-band-foreign-staves.json','page-coverage.json','order-and-geometry-validation.json','unassigned-diagnostic-jobs.json','pending-changed-crop-review.json'];archive('comparison-data.zip',[(S/n,n)for n in ns]);copy(S/'component-deltas.json.gz','component-deltas.json.gz')
comp=read(S/'comparison.json');inputs={x['id']:x for x in read(W/'inputs.json')};files=[]
for row in comp['rows']:
 p=Path(row['files'][1]['path']);assert sha(p)==row['files'][1]['sha256'];files.append((p,'candidate/'+row['id']+'.json'));profile=Path(inputs[row['id']]['profile']);assert sha(profile)==inputs[row['id']]['profileSHA256'];files.append((profile,'profiles/'+profile.name))
b=read(W/'build-binding.json')
for rel,h in b['sourceHashes'].items():p=Path(b['snapshot'])/rel;assert sha(p)==h;files.append((p,'candidate-Core/'+rel))
archive('candidate-inventories.zip',files)
# Archive newly reviewed contexts once; prior reviewed images and unresolved-page classifications remain in the hash-bound predecessor/sibling reports.
p=R/'.build/numbered-line-monotone-compatibility-2026-10-03/root-three-page-review/review.json';copy(p,'source-review/root-three-page-review.json');rev=read(p);imgs=[]
for row in rev['rows']:
 image=p.parent/(row['bandID']+'.png');assert sha(image)==row['contextSHA256'];imgs.append((image,image.name))
assert len(imgs)==30;archive('reviewed-three-page-contexts.zip',imgs)
write(D/'archive-payloads.json',archives)
with gzip.open(D/'component-deltas.json.gz','rt')as f:d=json.load(f)
assert len(d)==summary['semanticComponentChangedPages'];write(D/'component-delta-verification.json',{'decodedPages':len(d),'gzipSHA256':sha(D/'component-deltas.json.gz')})
print(json.dumps({'path':str(D),'reviewCoverage':reuses['summary'],'archives':[{'archive':x['archive'],'payloads':len(x['payloads']),'sha256':x['sha256']}for x in archives]},indent=2),flush=True)
