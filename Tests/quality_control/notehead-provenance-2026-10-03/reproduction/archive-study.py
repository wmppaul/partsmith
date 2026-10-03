from pathlib import Path
import json,hashlib,shutil,gzip,zipfile
R=Path.cwd();W=R/'.build/notehead-provenance-2026-10-03';D=R/'Tests/quality_control/notehead-provenance-2026-10-03';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();read=lambda p:json.loads(Path(p).read_text());write=lambda p,x:Path(p).write_text(json.dumps(x,indent=2)+'\n')
f=read(W/'frozen-inputs.json');checks=0
for rel,h in f['core'].items():assert sha(W/'baseline/Core'/rel)==h;checks+=1
for rel,h in f['sourceIndependentGuards'].items():assert sha(R/rel)==h;checks+=1
sources={name:{str(p.relative_to(W/name)):sha(p)for p in sorted((W/name/'Core').rglob('*.swift'))}for name in ['baseline','candidate-v1']}
changes=[p for p in sources['baseline']if sources['baseline'][p]!=sources['candidate-v1'][p]];assert changes==['Core/Detection/NativeScorePageAnalyzer.swift']
assert sources['candidate-v1'][changes[0]]=='8c2fa3f665dd1c41f95ac44b9f30fc0a6cdc094f5cac016cd866711badd41af3'
for rel,h in sources['candidate-v1'].items():assert sha(W/rel)==h;checks+=1
for sub in ['reproduction','results','logs','fixed-source-review','real-source-review','independent-evidence']:(D/sub).mkdir(exist_ok=True)
for name in ['frozen-inputs.json','design-before-results.md','candidate-v1-binding.json','candidate-v1.patch','comparison180.json','comparison36.json','comparison297.json','comparison336.json','component-comparison.json','targeted-plan-comparison.json']:shutil.copy2(W/name,D/name)
for p in W.glob('*.log'):shutil.copy2(p,D/'logs'/p.name)
for name in ['render-fixed-examples.py','render-real-deltas.py','render-endpoint-witnesses.py','diagnose-changed.swift','endpoint-helper.swift','archive-study.py']:shutil.copy2(W/name,D/'reproduction'/name)
shutil.copy2(R/'.build/stem-ownership-2026-10-03/build.sh',D/'reproduction/build.sh')
for name in ['replay.swift','replay-plans.swift']:shutil.copy2(R/'Tests/quality_control/terminal-body-continuation-2026-10-03/reproduction'/name,D/'reproduction'/name)
shutil.copy2(W/'diagnostic/Core/Detection/NativeScorePageAnalyzer.swift',D/'reproduction/diagnostic-NativeScorePageAnalyzer.swift')
for sub in ['fixed-source-review','real-source-review']:
 for p in (W/sub).iterdir():
  if p.is_file():shutil.copy2(p,D/sub/p.name)
for name in ['notehead-independent-mask-check.json','check_notehead_masks.py']:shutil.copy2(R/'.build/brahms-review-root-2026-10-03'/name,D/'independent-evidence'/name)
compressed=[]
for src,name in [(W/('results'+n+'.json'),'candidate'+n+'.json.gz')for n in ['180','36','297','336']]+[(W/'replay-output/witnesses.json','native-replay-components.json.gz'),(W/'replayed-plans.json','native-replayed-plans.json.gz'),(W/'diagnostic-output/witnesses.json','native-diagnostic-witnesses.json.gz'),(R/'.build/terminal-body-continuation-2026-10-03/diagnostic-cases.json','native-baseline-cases.json.gz'),(W/'changed-candidate-cases.json','native-changed-candidate-cases.json.gz')]:
 out=D/'results'/name;out.write_bytes(gzip.compress(src.read_bytes(),mtime=0));compressed.append({'source':str(src),'sourceSHA256':sha(src),'archive':str(out.relative_to(D)),'archiveSHA256':sha(out)});assert gzip.decompress(out.read_bytes())==src.read_bytes();checks+=1
with zipfile.ZipFile(D/'frozen-core.zip','w',zipfile.ZIP_DEFLATED)as z:
 for name in sources:
  for p in sorted((W/name/'Core').rglob('*.swift')):z.write(p,str(p.relative_to(W)))
with zipfile.ZipFile(D/'frozen-core.zip')as z:
 assert z.testzip()is None
 for name in sources:
  for rel,h in sources[name].items():assert hashlib.sha256(z.read(name+'/'+rel)).hexdigest()==h;checks+=1
native=read(W/'replay-output/witnesses.json');old=read(R/'.build/terminal-body-continuation-2026-10-03/diagnostic-cases.json');diagnostic=read(W/'diagnostic-output/witnesses.json');assert len(native)==len(old)==12 and len(diagnostic)==3
for r,c in zip(native,old):
 assert r['id']==c['id'] and r['sourceSHA256']==sha(c['source']);checks+=1
for d in diagnostic:assert d['componentsEqualFrozenMultiset'];checks+=1
ext={}
for name in ['independent180','tied36','crop765','controls297','expanded336','replay','replay-plans','diagnose-changed']:
 p=W/name;ext[str(p)]=sha(p)
for r in native:ext[r['source']]=sha(r['source']);ext[r['imagePath']]=sha(r['imagePath'])
for d in diagnostic:ext[d['imagePath']]=sha(d['imagePath'])
I=R/'Tests/quality_control/notehead-provenance-independent-2026-10-03'
for name in ['holdouts.json','helper-inputs.json','candidate-v1-helper-results.json','local-line-helper-inputs.json','local-line-source-measurements.json','candidate-v1-local-line-results.json','helper-probe.swift','build-helper.sh','native-replay-inputs.json']:
 p=I/name;ext[str(p)]=sha(p)
T=R/'Tests/quality_control/terminal-body-independent-2026-10-03'
for name in ['controls.swift','tied-controls.swift','compare.py','build.sh','build-tied.sh','baseline-results.json','tied-baseline-results.json','frozen-protocol.json','tied-frozen-protocol.json','source-hashes.json','tied-source-hashes.json']:
 p=T/name;ext[str(p)]=sha(p)
write(D/'evidence-bindings.json',{'baselineCommit':f['baselineCommit'],'candidateDecision':'Rejected after real-source evidence; never promoted.','frozenCoreSources':sources,'onlyChangedCoreSource':changes[0],'compressedEvidence':compressed,'externalEvidence':ext,'initialIntegrityChecks':checks,'noFixturesOrProductionChanged':True,'compiledSubset':'Six Detection source files listed by reproduction/build.sh; the other Core files are archived/bound without claiming they were compiled into the lean harnesses.'})
summary={'decision':'Reject v1; no production change, no full39/corpus run, no tuning to real holdouts.','candidateAnalyzerSHA256':sources['candidate-v1'][changes[0]],'fixedControls':{'cropQuality':{'pass':765,'total':765,'explicitKnownLimit':'Third source annotation [610,295,620,304] remains outside upper crop.'},'controls297':read(W/'comparison297.json'),'expanded336':read(W/'comparison336.json'),'independent180':{'baselineFailures':58,'candidateFailures':24,'repairedCases':34,'newFailingCases':0,'worsenedOwners':0,'pureStructuralCases':72,'structuralWholeNeighbors':0},'tied36':{'baselineFailures':24,'candidateFailures':9,'repairedCases':15,'newFailingCases':0,'worsenedOwners':0}},'independentRealHelper':{'ownStemPositives':7,'recognizedOwnStemPositives':0,'withinDeclaredVerticalSearch':4,'recognizedWithinSearch':0,'locallyRemeasuredStaffGeometryRetryPositives':4,'recognizedLocalRetry':0,'nearWrongSpineNegatives':2,'wrongSpineFalseAcceptances':0,'structuralNegatives':13,'structuralFalseAcceptances':1,'falseAcceptanceID':'F05-structural-intersection','scope':'Direct helper test only. No full-two-staff musical source spine was found among these real positives.'},'nativeTargetedReplay':{'pages':12,'componentChangedPages':3,'componentsAdded':4,'allAddedComponentsAreOwnershipAlternatives':True,'componentsRemoved':0,'cropChangedPages':2,'cropChangedBands':4,'allChangedCropsStrictSupersets':True,'newWholeNeighborOccurrencesInNeutralDiagnosticRows':4,'initializedInstrumentBandsChanged':0,'unresolvedPagesRemainUnresolved':True,'loggingOnlyComponentEquivalencePages':3},'runtime':{'candidate180Seconds':{'wall':1.55,'user':1.22,'sys':.06},'baseline180Seconds':{'wall':1.24,'user':1.15,'sys':.07},'candidate36Seconds':{'wall':.48,'user':.27,'sys':.01},'candidate12ReplaySeconds':{'wall':4.46,'user':4.00,'sys':.13},'qualification':'Single timings with other build activity. Candidate180/36 used time -l, whose post-run kern.clockrate query was denied by sandbox; complete candidate output and timing prefix are retained, wrapper exit1 is not treated as a classifier failure. Later time -p runs complete without that query. No production performance certification.'}}
write(D/'validation-summary.json',summary)
print('Archived candidate evidence, baseline checks',checks)
