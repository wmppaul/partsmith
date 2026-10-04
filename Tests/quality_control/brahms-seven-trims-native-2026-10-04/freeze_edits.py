from pathlib import Path
import json,hashlib,shutil,pymupdf
base=Path('output/pdf/auto-qc-2026-10-03/brahms-quartet-93521-viola-in-tempo-repair');w=Path('.build/brahms93521-reviewed-overlap-trim-2026-10-03')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();m=json.loads((base/'manifest.json').read_text());pj=json.loads((base/m['project']/'project.json').read_text())['project'];pdf=pymupdf.open(base/'rectified-review-source.pdf')
gpath=Path('Tests/quality_control/brahms-residual-source-separation-2026-10-03/source-obligations-before-future-trials.json');g=json.loads(gpath.read_text());envelopes={r['bandID']:r for r in g['targetRegions']}
edges={'p24-s2-viola':('bottom',283.0),'p24-s2-cello':('top',271.0),'p28-s1-violin1':('bottom',65.5),'p28-s1-violin2':('top',64.5),'p31-s1-violin2':('top',67.5),'p38-s1-viola':('bottom',134.5),'p38-s1-cello':('top',131.0)}
rows=[]
for part in m['parts']:
 model=next(p for p in pj['parts'] if p['name']==part['name']);bands=[b for b in pj['bands'] if b['partID']==model['id']];assert len(bands)==len(part['placements'])==151
 for b,r in zip(bands,part['placements']):
  if r['id'] not in edges:continue
  assert b['pageIndex']==r['sourcePage']-1
  h=pdf[b['pageIndex']].rect.height;old=r['sourceRect'];assert abs(b['topFraction']*h-old[1])<1e-7 and abs(b['bottomFraction']*h-old[3])<1e-7
  edge,val=edges[r['id']];new=list(old);new[1 if edge=='top' else 3]=val;guard=envelopes[r['id']]['rect'];assert new[1]<guard[1] and new[3]>guard[3]
  rows.append({'id':r['id'],'bandUUID':b['id'],'partID':model['id'],'sourcePage':r['sourcePage'],'edge':edge,'value':val,'sourceHeight':h,'oldRect':old,'newRect':new,'frozenTargetEnvelope':guard,'sourceObligation':envelopes[r['id']]['description']})
assert len(rows)==7
report={'sourceSHA256':sha(base/m['project']/'source.pdf'),'correctedSourceSHA256':sha(base/'rectified-review-source.pdf'),'originalProjectSHA256':sha(base/m['project']/'project.json'),'parentManifestSHA256':sha(base/'manifest.json'),'sourceObligationsSHA256':sha(gpath),'scope':'Seven manual source-reviewed one-edge changes; all other edges and settings unchanged; no detector claim. Root reviewed all four corrected source system contexts and all unrectified originals before freezing. Conservative extra1.5pt beyond each target envelope; keep the original opposite edge.','changes':rows}
(w/'proposed-edits-before-output.json').write_text(json.dumps(report,indent=2)+'\n');shutil.copytree('Partsmith/Core',w/'Core');sources={str(p.relative_to(w/'Core')):sha(p) for p in (w/'Core').rglob('*.swift')};(w/'source-hashes.json').write_text(json.dumps(sources,indent=2)+'\n')
print(json.dumps({'frozenEditsSHA256':sha(w/'proposed-edits-before-output.json'),'rows':len(rows),'coreFiles':len(sources)}))
