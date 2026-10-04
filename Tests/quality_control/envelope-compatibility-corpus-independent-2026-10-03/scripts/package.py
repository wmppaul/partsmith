from pathlib import Path
import json,hashlib,zipfile,shutil,gzip,datetime
R=Path.cwd(); W=R/'.build/envelope-compatibility-corpus-2026-10-03'; S=R/'.build/envelope-corpus-independent-2026-10-03'; D=R/'Tests/quality_control/envelope-compatibility-corpus-independent-2026-10-03'; D.mkdir(exist_ok=True)
read=lambda p:json.loads(Path(p).read_text()); sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def copy(p,n):q=D/n;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q);return q
summary=read(S/'independent-summary.json');comp=read(S/'comparison.json');inputs=read(W/'inputs.json'); rows={x['id']:x for x in comp['rows']};base=read(S/'baseline-binding.json');br={x['id']:x for x in base['rows']}
assert summary['complete'] and summary['terminalScores']==36 and summary['invalidGeometryRecords']==0
for n in ['independent-protocol-before-comparison.json','independent-summary.json','baseline-binding.json','priority-by-score.json']:copy(S/n,n)
for n in ['prepare.py','compare.py','finish-comparison.py','final-comparison.log','finish-comparison.log']:copy(S/n,'scripts/'+n)
copy(Path(__file__),'scripts/package.py')
for n in ['build-binding.json','inputs.json','status.json','protocol-before-results.json','run.py','replan.swift','corpus.log','root-review.py','write-root-review.py']:copy(W/n,'native-run/'+n)
for n in ['status.json','summary.json','source-binding-before-results.json','inputs-before-results.json']:copy(W/'baseline'/n,'native-run/baseline/'+n)
for n in ['protocol-before-results.json','source-bindings-before-results.json','build-run.sh','existing795.swift']:copy(R/'.build/numbered-line-envelope-compatibility-2026-10-03'/n,'native-run/candidate-construction/'+n)
copy(R/'Tests/quality_control/corpus.json','native-run/corpus.json')
external=R/'Tests/quality_control/envelope-corpus-two-score-source-review-2026-10-03'; extHashes=read(external/'hashes.json')
for n,h in extHashes.items():assert sha(external/n)==h
review=read(external/'review.json');seen=set();coverage=[]
for score in review['scores']:
 for rr in score['reviewedRows']:
  rec=next(b for b in rows[score['id']]['changedBands'] if b['bandID']==rr['bandID']);assert rec['beforePDFBounds']==rr['before'] and rec['afterPDFBounds']==rr['after'];seen.add((score['id'],rr['bandID']))
 coverage.append({'score':score['id'],'reviewer':'crop_algorithm_audit','reviewed':len(score['reviewedRows']),'totalChangedCrops':sum(b.get('geometryChanged',False)for b in rows[score['id']]['changedBands']),'newTargetOmissionsObserved':0,'newWholeNeighbors':0})
externalBinding={'report':str((external/'review.json').relative_to(R)),'reportSHA256':sha(external/'review.json'),'hashManifest':str((external/'hashes.json').relative_to(R)),'hashManifestSHA256':sha(external/'hashes.json'),'archive':str((external/'reviewed-contexts.tar.xz').relative_to(R)),'archiveSHA256':sha(external/'reviewed-contexts.tar.xz'),'scope':'147 changed crops, archived once in sibling report; source-area review, not exported PDFs.'};write(D/'independent-source-review-reference.json',externalBinding)
rootcontexts=[]
for receipt,sid in [('root-brahms242312-source-regressions.json','lightly-skewed-10-brahms-string-quartet-no3-op67-imslp-242312'),('root-schumann-source-review.json','lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922')]:
 data=read(W/receipt);copy(W/receipt,'source-review/'+receipt);idx=W/'root-source'/sid/'index.json';assert sha(idx)==data['indexSHA256'];copy(idx,'source-review/'+sid+'-context-index.json')
 for rr in data['rows']:
  p=R/rr['context'];assert sha(p)==rr['contextSHA256'];assert sha(rr['source'])==rr['sourceSHA256'];rec=next(b for b in rows[sid]['changedBands']if b['bandID']==rr['band']);assert [rec['beforePDFBounds'][1],rec['beforePDFBounds'][3]]==rr['oldY'] and [rec['afterPDFBounds'][1],rec['afterPDFBounds'][3]]==rr['newY'];seen.add((sid,rr['band']));rootcontexts.append((p,'changed-crops/'+sid+'/'+p.name))
 coverage.append({'score':sid,'reviewer':'root','reviewed':len(data['rows']),'totalChangedCrops':sum(b.get('geometryChanged',False)for b in rows[sid]['changedBands']),'newTargetOmissionsObserved':0,'newWholeNeighbors':3 if 'brahms' in receipt else 0})
for n in ['root-k478-footnote-review.json','root-trio-empty-review/review.json']:copy(W/n,'source-review/'+n)
foot=read(W/'root-k478-footnote-review.json');assert sha(foot['render'])==foot['renderSHA256'];rootcontexts.append((Path(foot['render']),'unresolved-pages/k478-page-38.png'))
for rr in read(W/'root-trio-empty-review/review.json')['pages']:
 assert sha(rr['render'])==rr['renderSHA256'];rootcontexts.append((Path(rr['render']),'unresolved-pages/trio-'+Path(rr['render']).name))
assert len(rootcontexts)==16 and len(seen)==160
write(D/'source-review-accounting.json',{'candidateDisposition':'Rejected: three new whole-neighbor crops, confirmed on original source.','reviewedChangedCrops':len(seen),'totalChangedCrops':summary['changedCropRows'],'remainingChangedCropsNotVisuallyReviewed':summary['changedCropRows']-len(seen),'reviews':coverage,'unassignedDiagnosticPages':summary['unassignedDiagnosticPages'],'neutralDiagnosticRendersPerformed':False,'unresolvedSourceSupplement':'Three original full pages classified separately by root; this does not modify raw plans or resolve all 961 diagnostic pages.','limits':'Full corpus source preservation and complete parts/pagination were not certified; review stopped after decisive cleanliness regressions.'})
foreign=read(S/'per-band-foreign-staves.json');new=[x for x in foreign if x['newWholeNeighbors']];assert len(new)==3;write(D/'new-whole-neighbor-regressions.json',new)
# Compact comparison evidence. Complete component deltas are retained separately in gzip.
dataNames=['comparison.json','compact-source-review-queue.json','changed-crop-review-jobs.json','per-band-foreign-staves.json','page-coverage.json','order-and-geometry-validation.json','unassigned-diagnostic-jobs.json']
archiveMan=[]
def archive(name,files):
 entries=[]
 with zipfile.ZipFile(D/name,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for path,arc in files:
   z.write(path,arc);entries.append({'path':arc,'sha256':sha(path),'bytes':path.stat().st_size})
  z.writestr('contents.json',json.dumps(entries,indent=2)+'\n')
 with zipfile.ZipFile(D/name)as z:
  for row in entries:assert hashlib.sha256(z.read(row['path'])).hexdigest()==row['sha256']
 archiveMan.append({'archive':name,'payloads':len(entries),'sha256':sha(D/name),'entries':entries})
archive('comparison-data.zip',[(S/n,n)for n in dataNames]);copy(S/'component-deltas.json.gz','component-deltas.json.gz')
archive('reviewed-source-images.zip',rootcontexts)
files=[]
for inp in inputs:
 sid=inp['id'];files += [(Path(br[sid]['replannedBaseline']),'baseline/'+sid+'.json'),(Path(rows[sid]['files'][1]['path']),'candidate/'+sid+'.json'),(Path(inp['profile']),'profiles/'+Path(inp['profile']).name)]
 for p,a in files[-3:-1]:assert sha(p)==next(x['sha256']for x in rows[sid]['files']if Path(x['path'])==p)
snap=Path(read(W/'build-binding.json')['snapshot'])
for rel,h in read(W/'build-binding.json')['sourceHashes'].items():assert sha(snap/rel)==h;files.append((snap/rel,'candidate-Core/'+rel))
archive('native-inventories.zip',files);write(D/'archive-payloads.json',archiveMan)
# Verify the full component delta gzip is readable and each page is represented once.
with gzip.open(D/'component-deltas.json.gz','rt')as f:deltas=json.load(f)
write(D/'compressed-delta-verification.json',{'gzipSHA256':sha(D/'component-deltas.json.gz'),'decodedContainerType':type(deltas).__name__,'decodedEntries':len(deltas),'expectedSemanticPages':summary['semanticComponentChangedPages']});assert len(deltas)==summary['semanticComponentChangedPages']
print(json.dumps({'archives':[{k:v for k,v in a.items()if k!='entries'}for a in archiveMan],'reviewedCrops':len(seen),'directory':str(D)},indent=2),flush=True)
