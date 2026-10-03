from pathlib import Path
import json,hashlib,datetime
from PIL import Image
P=Path(__file__).resolve().parent;ROOT=P.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
d=json.loads((P/'source-cases.json').read_text()); sourceManifest=json.loads((P/'source-freeze-manifest.json').read_text()); checks=[]
for rel,h in sourceManifest['files'].items():
 assert sha(P/rel)==h,rel
checks.append({'check':'frozen source manifest unchanged','files':len(sourceManifest['files']),'passed':True})
pageRaster={};sourcePDFs=[]
for p in d['pages']:
 pdf=Path(p['sourcePDF']);assert sha(pdf)==p['sourceSHA256'];assert sha(P/p['nativeRaster'])==p['nativeRasterSHA256'];pageRaster[p['id']]=Image.open(P/p['nativeRaster']).convert('RGB');assert list(pageRaster[p['id']].size)==p['rasterSize'];sourcePDFs.append({'path':str(pdf),'sha256':sha(pdf),'physicalPage':p['physicalPage'],'nativeRaster':p['nativeRaster'],'nativeRasterSHA256':p['nativeRasterSHA256']})
for c in d['cases']:
 im=pageRaster[c['pageID']];crop=Image.open(P/c['sourceCrop']['path']).convert('RGB');assert im.crop(c['contextROI']).tobytes()==crop.tobytes(),c['id'];assert sha(P/c['sourceCrop']['path'])==c['sourceCrop']['sha256'];assert sha(P/c['reviewImage']['path'])==c['reviewImage']['sha256'];assert c['reviewedSourceBeforePrototype'] and not c['prototypeSeenAtSourceFreeze']
 if c['genuineOwnStemHead']:
  l,t,r,b=c['mustPreserveNoteEnvelope']
  for box in [c['bodyROI'],c['spineROI']]:assert l<=box[0] and t<=box[1] and r>=box[2] and b>=box[3]
checks.append({'check':'all original PDFs, native rasters, 36 source crops and frozen overlays match hashes; crops equal original source pixels','passed':True})
assert json.loads((P/'results-v2.json').read_text())==json.loads((P/'results-diagnostic.json').read_text())
checks.append({'check':'logging-only result array and every witness value equal original candidate','passed':True,'cases':36})
core=ROOT/'.build/source-body-provenance-v2-2026-10-03/candidate-v2/Core';coreFiles={}
for q in (P/'candidate-Core').rglob('*.swift'):
 rel=q.relative_to(P/'candidate-Core');assert q.read_bytes()==(core/rel).read_bytes();coreFiles[str(rel)]=sha(q)
assert coreFiles['Detection/NativeScorePageAnalyzer.swift']=='2a76c26e292b1ba4baeb74d7388cb2172a5be41025d58de04efbef986da607db'
checks.append({'check':'durable candidate Core files byte-identical to frozen supplied snapshot','passed':True,'files':6})
summary=json.loads((P/'evaluation.json').read_text())['summary'];assert summary['positiveSelectedAccepts']==4 and summary['hollowAccepts']==0 and summary['falseBodySpineAccepts']==0
assert json.loads((P/'page-independence.json').read_text())['overlap']==[]
scratch=ROOT/'.build/source-body-real-holdouts-v2-2026-10-03';bindings={str(q.relative_to(ROOT)):sha(q) for q in [scratch/'helper-v2',scratch/'helper-diagnostic',scratch/'diagnostic-Core/Detection/NativeScorePageAnalyzer.swift',scratch/'diagnostic-probe.swift',scratch/'build-diagnostic.sh']}
result={'verifiedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sourceFreezeUTC':d['freezeUTC'],'historicalProductionCommitAtSourceFreeze':d['productionCommit'],'prototypeSourceReadOnlyAfterSourceCasesHashSentToParent':True,'sourceInputsUnchangedAfterCandidateSeen':True,'checks':checks,'sourcePDFs':sourcePDFs,'compiledCandidateCoreSHA256':coreFiles,'binariesAndDiagnosticSHA256':bindings,'reportBindings':{n:sha(P/n) for n in ['source-cases.json','local-line-measurements.json','source-freeze-manifest.json','helper-inputs.json','helper-probe.swift','build-helper.sh','results-v2.json','results-diagnostic.json','rejection-diagnostics.json','evaluation.json','page-independence.json']},'visualReview':{'all36OriginalCases':True,'all4AcceptedEllipsesMatchSelectedBody':True,'representativeMissedHollowTiedChordBeamedCases':True,'contacts':['review/contact-'+str(i)+'.png' for i in range(1,7)]+['review/v2-result-contact.png']},'unchangedExpectations':{'genuineBodies':24,'filled':12,'hollow':12,'falseAssociations':12,'terminalBodies':23,'noSourceBoundShrunk':True},'scope':{'productionEdits':False,'newCorpusWorker':False,'newNativeFullDocumentWorker':False,'exportsRun':False,'nativeCrossCoreErasureTested':False,'statisticallyRepresentativeClaim':False},'summary':summary}
(P/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
files=sorted(q for q in P.rglob('*') if q.is_file() and q.name!='hashes.json')
(P/'hashes.json').write_text(json.dumps({'files':{str(q.relative_to(P)):sha(q) for q in files},'count':len(files),'excludedSelf':'hashes.json'},indent=2)+'\n')
print('verified',len(files),'report files');print('manifest',sha(P/'hashes.json'));print('verification',sha(P/'verification.json'));print('readme',sha(P/'README.md'));print('bytes',sum(q.stat().st_size for q in P.rglob('*') if q.is_file()))
