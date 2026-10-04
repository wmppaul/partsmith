from pathlib import Path
import json,hashlib,zipfile,shutil
W=Path('.build/local-line-ownership-corpus-2026-10-03');D=Path('Tests/quality_control/local-line-ownership-corpus-2026-10-03');D.mkdir(parents=True,exist_ok=True)
read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def put(rel,source):
 target=D/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
for n in ['inputs.json','build-binding.json','protocol-before-results.json','status.json','runner-state.json','run.py','run.log']:put('native-run/'+n,W/n)
for p in (W/'comparison').iterdir():
 if p.is_file()and p.suffix in ['.py','.json','.gz','.log']:put('comparison/'+p.name,p)
for n in ['protocol-before-review.json','per-band-review.json','review-summary.json','source-contacts.json','generate.py','source-contact.py','write-review.py']:put('source-review/'+n,W/'source-review'/n)
for p in (W/'source-review').iterdir():
 if p.is_dir()and(p/'index.json').exists():
  for n in ['index.json','sheets.json','bindings.json','source-contacts.json']:put('source-review/bindings/'+p.name+'/'+n,p/n)
for p in (W/'source-review/p8-in-tempo').glob('*.json'):put('source-review/p8-in-tempo/'+p.name,p)
for n in ['protocol-before-results.json','run.sh','build.log','run.log','compare.py','comparison.json']:put('fresh-production-40163/'+n,W/'fresh-production-40163'/n)
# Reuse the already durable exact production inventories; verify all36 compressed payloads.
B=Path('Tests/quality_control/envelope-compatibility-corpus-independent-2026-10-03');oldzip=B/'native-inventories.zip';refs=[]
with zipfile.ZipFile(oldzip)as z:
 for r in read(W/'inputs.json'):
  entry='baseline/'+r['id']+'.json';data=z.read(entry);assert hashlib.sha256(data).hexdigest()==r['baselineSHA256'];refs.append({'id':r['id'],'archiveEntry':entry,'sha256':r['baselineSHA256']})
(D/'baseline-reference.json').write_text(json.dumps({'archive':str(oldzip),'archiveSHA256':sha(oldzip),'manifest':str(B/'manifest.json'),'manifestSHA256':sha(B/'manifest.json'),'verifiedEntries':refs,'scope':'Exact36 production9f8/raw baseline inventories already archived once; no duplication and no substitution with private95.'},indent=2)+'\n')
# New native outputs once; no binaries, no original PDFs.
payloads=[]
with zipfile.ZipFile(D/'native-candidate-evidence.zip','w',compression=zipfile.ZIP_DEFLATED,compresslevel=6)as z:
 files=[]
 for r in read(W/'status.json')['results']:
  p=Path(r['output']);assert sha(p)==r['outputSHA256'];files.append(('candidate/'+p.name,p))
  files.extend(('candidate/'+q.name,q)for q in [p.with_suffix('.log'),p.with_name(p.stem+'.progress.json')])
 files.append(('fresh-production-40163/inventory.json',W/'fresh-production-40163/inventory.json'))
 core=Path(read(W/'build-binding.json')['snapshot'])
 files.extend(('candidate-Core/'+str(p.relative_to(core)),p)for p in sorted(core.rglob('*.swift')))
 baseline=Path('.build/p34-local-ownership-2026-10-03/baseline/Core')
 for n in ['StaffBandDetector.swift','ScoreExtractionPlanner.swift','ScoreSharedEnding.swift','ScoreSharedEndingDetector.swift','ScoreLocalEndingPreservation.swift','NativeScorePageAnalyzer.swift']:files.append(('focused-baseline-Core/Detection/'+n,baseline/'Detection'/n))
 files.append(('permanent-inventory-harness.swift',Path('.build/p34-local-ownership-v2-2026-10-03/permanent.swift')))
 for entry,p in files:
  z.write(p,entry);payloads.append({'archive':'native-candidate-evidence.zip','entry':entry,'sha256':sha(p),'bytes':p.stat().st_size})
print('native archive written',flush=True)
# All65 reviewed source contexts, critical unaltered source page and output evidence. No duplicate contact sheets.
with zipfile.ZipFile(D/'reviewed-source-images.zip','w',compression=zipfile.ZIP_DEFLATED,compresslevel=6)as z:
 files=[]
 for d in (W/'source-review').iterdir():
  if d.is_dir()and(d/'index.json').exists():
   for r in read(d/'index.json'):files.append((d.name+'/'+Path(r['context']).name,Path(r['context'])))
 p=W/'source-review/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521'
 for n in ['source-page-8.png','p8-s2-viola-in-tempo-original-detail.png','p8-s2-viola-in-tempo-edges.png','p39-s2-viola-lower-edge-detail.png','p36-s3-viola-lower-edge-detail.png','p17-s1-violin2-lower-edge-detail.png']:files.append((p.name+'/'+n,p/n))
 files.extend(('p8-in-tempo/'+p.name,p)for p in (W/'source-review/p8-in-tempo').glob('*.png'))
 for entry,p in files:z.write(p,entry);payloads.append({'archive':'reviewed-source-images.zip','entry':entry,'sha256':sha(p),'bytes':p.stat().st_size})
(D/'archive-payloads.json').write_text(json.dumps(payloads,indent=2)+'\n')
for name in ['native-candidate-evidence.zip','reviewed-source-images.zip']:
 with zipfile.ZipFile(D/name)as z:
  expected=[r for r in payloads if r['archive']==name];assert len(z.namelist())==len(expected)
  for r in expected:assert hashlib.sha256(z.read(r['entry'])).hexdigest()==r['sha256']
print('all archive payload hashes verified',len(payloads),flush=True)
