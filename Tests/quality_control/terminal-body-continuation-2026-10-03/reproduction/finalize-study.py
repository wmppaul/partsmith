from pathlib import Path
import json,hashlib,shutil,gzip,zipfile,collections
from PIL import Image
ROOT=Path.cwd(); S=ROOT/'.build/terminal-body-continuation-2026-10-03'; D=ROOT/'Tests/quality_control/terminal-body-continuation-2026-10-03'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(Path(p).read_text())
write=lambda p,x:Path(p).write_text(json.dumps(x,indent=2)+'\n')
frozen=read(S/'frozen-inputs.json'); verified=[]
for p,h in frozen['productionCoreSources'].items():
 q=S/'baseline/Core'/Path(p).relative_to('Partsmith/Core');assert sha(q)==h,(q,'baseline changed');verified.append(str(q))
for group in ['fixedGuards','baselineEvidence']:
 for p,h in frozen[group].items():assert sha(ROOT/p)==h,(p,'guard changed');verified.append(p)
cores={n:{str(p.relative_to(S/n)):sha(p)for p in sorted((S/n/'Core').rglob('*.swift'))}for n in ['baseline','rejected-v1']}
changed=[p for p in cores['baseline']if cores['baseline'][p]!=cores['rejected-v1'][p]];assert changed==['Core/Detection/NativeScorePageAnalyzer.swift'],changed
for p,h in cores['rejected-v1'].items():assert sha(S/p)==h,('active candidate diverged',p)
a=read(ROOT/'.build/ownership-alternatives-2026-10-03/results297.json');b=read(S/'results297.json');assert len(a)==len(b)==297
for before,after in zip(a,b):
 for key in ['kind','scale','tilt','bow','imageSize','expectsSeparation']:assert before[key]==after[key]
 for x,y in zip(before['targets'],after['targets']):assert(x['owner'],x['sourceEnvelope'])==(y['owner'],y['sourceEnvelope'])
assert read(ROOT/'.build/ownership-alternatives-2026-10-03/results336.json')==read(S/'results336.json')
c297=read(S/'comparison297.json'); idx=read(S/'diagnostics/witnesses.json');replay=read(S/'rejected-v1/replay-output/witnesses.json'); plans=read(S/'rejected-v1/targeted-plan-comparison.json')
assert len(idx)==len(replay)==len(plans)==12
cases=read(S/'diagnostic-cases.json')
for x,y,z in zip(idx,replay,cases):
 assert x['id']==y['id']==z['id'] and x['componentsEqualFrozenMultiset']
 assert x['sourceSHA256']==sha(x['source'])==y['sourceSHA256']
 assert sha(x['imagePath'])==sha(y['imagePath'])
 if z.get('imagePath'):
  ax=Image.open(x['imagePath']).convert('RGBA');az=Image.open(z['imagePath']).convert('RGBA')
  assert ax.size==az.size and ax.tobytes()==az.tobytes(), 'rectified raster pixels changed on re-encoding'
old={x['id']:x['page']for x in cases}
componentChanges=[]
for x in replay:
 before=old[x['id']]['inkComponents']; after=x['components']; key=lambda c:json.dumps(c,sort_keys=True,separators=(',',':'))
 A=collections.Counter(map(key,before));B=collections.Counter(map(key,after));removed=[json.loads(k)for k,n in (A-B).items()for _ in range(n)];added=[json.loads(k)for k,n in (B-A).items()for _ in range(n)]
 assert not added and all(c.get('isOwnershipAlternative') for c in removed)
 if removed:assert len(removed)==1
 componentChanges.append({'id':x['id'],'beforeComponentCount':len(before),'afterComponentCount':len(after),'removed':removed,'added':added})
assert sum(bool(x['removed'])for x in componentChanges)==7
assert sum(len(x['changedBands'])for x in plans)==13
# This historical source/algorithm study deliberately binds frozen d2a Core,
# rather than any concurrent edits in the shared working tree.
(D/'reproduction').mkdir(exist_ok=True);(D/'logs').mkdir(exist_ok=True);(D/'source-review-images').mkdir(exist_ok=True);(D/'results').mkdir(exist_ok=True)
for p in ['frozen-inputs.json','candidate-v1.patch','comparison297.json','source-body-profiles.json']:
 shutil.copy2(S/p,D/p)
for p in ['diagnose.swift','replay.swift','replay-plans.swift','profile-source-bodies.py','render-p38-review.py','finalize-study.py']:
 shutil.copy2(S/p,D/'reproduction'/p)
shutil.copy2(ROOT/'.build/stem-ownership-2026-10-03/build.sh',D/'reproduction/build.sh')
for p in S.glob('*-run.log'):shutil.copy2(p,D/'logs'/p.name)
for p in S.glob('*-build.log'):shutil.copy2(p,D/'logs'/p.name)
for p in (S/'rejected-v1').glob('*.log'):shutil.copy2(p,D/'logs'/p.name)
for p in (S/'diagnostics').glob('*-witness*.png'):shutil.copy2(p,D/'source-review-images'/p.name)
for p in (S/'rejected-v1/p38-review').glob('*.png'):shutil.copy2(p,D/'source-review-images'/p.name)
shutil.copy2(S/'diagnostics/branch-summary.json',D/'branch-summary.json')
shutil.copy2(S/'rejected-v1/targeted-plan-comparison.json',D/'targeted-plan-comparison.json')
write(D/'component-changes.json',componentChanges)
packed=[]
for src,dst in [('results297.json','results297.json.gz'),('results336.json','results336.json.gz'),('results180.json','results180.json.gz'),('diagnostic-cases.json','diagnostic-cases.json.gz'),('diagnostics/witnesses.json','diagnostic-witnesses.json.gz'),('rejected-v1/replay-output/witnesses.json','replay-components.json.gz'),('rejected-v1/replayed-plans.json','replayed-plans.json.gz')]:
 raw=S/src;out=D/'results'/dst;out.write_bytes(gzip.compress(raw.read_bytes(),mtime=0));assert gzip.decompress(out.read_bytes())==raw.read_bytes();packed.append({'source':str(raw),'sourceSHA256':sha(raw),'archive':str(out.relative_to(D)),'archiveSHA256':sha(out)})
with zipfile.ZipFile(D/'frozen-core.zip','w',zipfile.ZIP_DEFLATED)as z:
 for name in cores:
  for p in sorted((S/name/'Core').rglob('*.swift')):z.write(p,str(p.relative_to(S)))
with zipfile.ZipFile(D/'frozen-core.zip')as z:
 assert z.testzip()is None
 for n in cores:
  for p,h in cores[n].items():assert hashlib.sha256(z.read(n+'/'+p)).hexdigest()==h
ext={}
for p in [*[(S/n)for n in ['crop765','controls297','expanded336','independent180','diagnose']],S/'rejected-v1/replay',S/'rejected-v1/replay-plans']:
 ext[str(p)]=sha(p)
for r in idx:ext[r['imagePath']]=sha(r['imagePath']);ext[r['source']]=r['sourceSHA256']
for p in ['candidate-v1-review.json','candidate-v1-comparison.json','candidate-v1-tied-comparison.json','controls.swift','tied-controls.swift','frozen-protocol.json','tied-frozen-protocol.json','hashes.json']:
 q=ROOT/'Tests/quality_control/terminal-body-independent-2026-10-03'/p;ext[str(q)]=sha(q)
write(D/'evidence-bindings.json',{'baselineCommit':frozen['baselineCommit'],'frozenCoreSources':cores,'onlyChangedCoreFile':changed[0],'compressedEvidence':packed,'externalEvidence':ext,'baselineAndGuardHashesVerified':len(verified),'diagnosticPageCount':12,'diagnosticBaselineComponentMultisetsEqualFrozen':True,'diagnosticRasterHashesEqualCandidateReplay':True,'productionUnmodifiedByThisStudy':True})
write(D/'validation-summary.json',{'decision':'Reject v1; no production promotion; no v2 threshold trial justified by the source profiles.','candidateAnalyzerSHA256':cores['rejected-v1'][changed[0]],'baselineAnalyzerSHA256':cores['baseline'][changed[0]],'plannerSHA256':cores['baseline']['Core/Detection/ScoreExtractionPlanner.swift'],'cropQualityChecks':{'passed':765,'total':765,'knownLimit':'Detached third annotation [610,295,620,304] still outside upper crop; this preexisting failure is explicitly printed, not silently counted as success.'},'controls297':{'baselinePass':c297['baselinePass'],'candidatePass':c297['candidatePass'],'newFailingCases':len(c297['newFailures']),'worsenedOwnerEnvelopes':len(c297['worsenedTargetEnvelopes']),'fixedSourceEnvelopeIdentitiesUnchanged':True},'expanded336':{'passed':336,'total':336,'entireDecodedResultsExactlyEqualBaseline':True},'independent180':'58 failures before and after; every crop unchanged; see bound independent comparison.','tiedSupplement36':'24 failures before and after; every crop unchanged; see bound independent comparison.','nativeTargetedReplay':{'pages':12,'changedPages':7,'removedOwnershipAlternatives':7,'newComponents':0,'changedBands':13,'ordinaryComponentsExactlyRetained':True,'fiveUnchangedPages':[x['id']for x in componentChanges if not x['removed']]},'full39NativeWorkerRun':False,'full36CorpusRun':False,'reasonLargerRunsOmitted':'Strict unchanged fixed-source controls already reject the candidate; targeted replay diagnoses real source effects without treating crop cleanup as a safety pass.'})
print('Archived',len(list(D.rglob('*'))),'paths; production never edited; baseline hash checks',len(verified))
