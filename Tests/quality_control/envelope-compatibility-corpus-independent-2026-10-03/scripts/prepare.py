from pathlib import Path
import json,hashlib,fitz
R=Path('.build/envelope-corpus-independent-2026-10-03');W=Path('.build/envelope-compatibility-corpus-2026-10-03');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();read=lambda p:json.loads(Path(p).read_text())
corpus=read('Tests/quality_control/corpus.json');inputs=read(W/'inputs.json');prior=read('.build/combined-corpus-2026-10-03/inputs.json');priorStatus=read('.build/combined-corpus-2026-10-03/status.json');bs=read(W/'baseline/status.json');bm=read(W/'baseline/summary.json');bind=read(W/'build-binding.json');bb=read(W/'baseline/source-binding-before-results.json');history=read('.build/combined-corpus-2026-10-03/build-binding.json')
assert len(inputs)==len(corpus['scores'])==36 and sum(x['pages']for x in inputs)==1477 and bs['complete'] and priorStatus['complete']
assert sha(W/'baseline/status.json')=='be40d62c5a867c89b869e3cc61956199df9302df8d72d2cb0e8793e0e2ff365b'
assert history['sourceHashes']['Detection/NativeScorePageAnalyzer.swift']=='9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01'
assert bind['sourceHashes']['Detection/NativeScorePageAnalyzer.swift']=='e32b5a76928b505efbeba6fa5bc9aef4b58ed0e2b7d11ddeef3269b73570996f'
assert sha(bind['binary'])==bind['binarySHA256'] and sha(W/'baseline/replan')==bm['binarySHA256']
for rel,h in bind['sourceHashes'].items():assert sha(Path(bind['snapshot'])/rel)==h
for rel,h in bb['compiledDependencies'].items():assert sha(rel)==h
assert sha(W/'replan.swift')==bb['replanSourceSHA256'] and sha('.build/combined-corpus-2026-10-03/build-binding.json')==bb['historicalBuildBinding']['sha256']
co={x['id']:x for x in corpus['scores']};pr={x['id']:x for x in prior};ps={x['id']:x for x in priorStatus['results']};br={x['id']:x for x in bs['results']};rows=[]
actual={p.resolve()for f in ['sample_scores','Tests/extraction/sources']for p in Path(f).rglob('*.pdf')};assert actual=={Path(x['source']).resolve()for x in inputs}
for x in inputs:
 z=co[x['id']];p=pr[x['id']];b=br[x['id']];q=ps[x['id']]
 for k in ['source','sourceSHA256','profile','profileSHA256','pages']:assert x[k]==p[k]==b[k]
 assert Path(x['source']).resolve()==Path(z['path']).resolve() and Path(x['profile']).resolve()==Path(z['profilePath']).resolve()
 assert sha(x['source'])==x['sourceSHA256']==z['sha256'];assert sha(x['profile'])==x['profileSHA256'];assert z.get('profileSHA256',x['profileSHA256'])==x['profileSHA256']
 assert sha(x['baseline'])==x['baselineSHA256']==q['outputSHA256']==b['inventorySHA256']
 assert sha(b['output'])==b['outputSHA256'] and b['exitCode']==0 and q['exitCode']==0
 old=read(x['baseline']);new=read(b['output']);assert old['pages']==new['pages'] and old['plan']==new['plan']
 with fitz.open(x['source'])as doc:
  assert doc.page_count==x['pages']==z['pageCount']
  pdfGeometry=[{'page':i+1,'rect':list(pg.rect),'cropBox':list(pg.cropbox),'mediaBox':list(pg.mediabox),'rotation':pg.rotation}for i,pg in enumerate(doc)]
 rows.append({**x,'replannedBaseline':b['output'],'replannedBaselineSHA256':b['outputSHA256'],'requiresSystemAssignment':read(x['profile']).get('requiresSystemAssignment',False),'nativeRawPagesExactlyRetained':True,'replannedPlanExactlyHistorical':True,'physicalPDFGeometry':pdfGeometry,'rosterStatus':z.get('rosterStatus'),'instrumentation':z['instrumentation'],'evaluationRequirements':z['evaluationRequirements']})
base={'rows':rows,'sources':36,'pages':1477,'allOriginalRawPagesAndPlansEqual':True,'candidateBuildBindingSHA256':sha(W/'build-binding.json'),'replanSummarySHA256':sha(W/'baseline/summary.json'),'replanStatusSHA256':sha(W/'baseline/status.json'),'historicalBuildBindingSHA256':sha('.build/combined-corpus-2026-10-03/build-binding.json'),'historicalAnalyzerSHA256':history['sourceHashes']['Detection/NativeScorePageAnalyzer.swift'],'currentPlannerSHA256':bind['sourceHashes']['Detection/ScoreExtractionPlanner.swift'],'corpusSHA256':sha('Tests/quality_control/corpus.json')}
(R/'baseline-binding.json').write_text(json.dumps(base,indent=2)+'\n')
protocol={'scope':'Read-only independent comparison of all36 sources/1477 physical pages; no native workers. Incremental terminal candidate files only.','sourceExpectations':'Use unchanged source PDFs/profiles and production9f8 raw analyses replanned with identical current772 planner. Verify raw source/profile/output/executable/snapshot hashes and every physical PDF page. Original staff identities and unassigned coverage remain explicit.','comparison':'Every noncomponent page field, geometry/staff identity, plan metadata, assignment ID/order/part/system/kind/candidateIDs, warning/unresolved reason and crop boundary. Per-band whole-foreign ID sets compared independently of aggregatecounts, even if counts cancel. All changed crop boundaries queued.','unresolved':'Zero bands and unassigned staves cannot pass extraction coverage. Semantic component changes on unassigned staves require neutral-staff diagnostics without inventing part ownership or silence; produce jobs but do not start native workers.','visualGate':'No source-preservation verdict from geometry alone. Source-first review remains pending, especially inward edges and new complete neighbors. No source guards or fixture expectations modified.'}
(R/'independent-protocol-before-comparison.json').write_text(json.dumps(protocol,indent=2)+'\n')
print('Verified36sources1477pages; baseline-binding',sha(R/'baseline-binding.json'),'protocol',sha(R/'independent-protocol-before-comparison.json'))
