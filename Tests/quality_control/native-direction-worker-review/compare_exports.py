import json,hashlib
from pathlib import Path
import fitz,numpy as np
w=Path('.build/qc-native-app-worker-v1')
def h(p):return hashlib.sha256(p.read_bytes()).hexdigest()
results=[]
for c in json.loads((w/'config.json').read_text()):
 npath=w/f"{c['id']}-parts"/'manifest.json'
 if not npath.exists():continue
 bpath=Path(c['baselineManifest']);n=json.loads(npath.read_text());b=json.loads(bpath.read_text());parts=[]
 assert n['sourceSHA256']==b['sourceSHA256']==c['sourceSHA256']
 assert n['rectifications']==b['rectifications']
 for npart,bpart in zip(n['parts'],b['parts']):
  assert npart['id']==bpart['id']
  geometry=npart['placements']==bpart['placements']
  ndoc=fitz.open(npath.parent/npart['file']);bdoc=fitz.open(bpath.parent/bpart['file']);assert len(ndoc)==len(bdoc)
  diffs=[];blank=[];bounds=[];rasters=[]
  for i in range(len(ndoc)):
   ni=ndoc[i].get_pixmap(matrix=fitz.Matrix(150/72,150/72),colorspace=fitz.csGRAY,alpha=False)
   bi=bdoc[i].get_pixmap(matrix=fitz.Matrix(150/72,150/72),colorspace=fitz.csGRAY,alpha=False)
   a=np.frombuffer(ni.samples,dtype=np.uint8);z=np.frombuffer(bi.samples,dtype=np.uint8)
   assert a.shape==z.shape
   count=int(np.count_nonzero(a!=z));md=int(np.max(np.abs(a.astype(np.int16)-z.astype(np.int16))))
   if count:diffs.append({'outputPage':i+1,'differentPixels':count,'fraction':count/a.size,'maximumGrayDelta':md})
   if not np.any(a<220):blank.append(i+1)
   rasters.append({'page':i+1,'sha256':hashlib.sha256(ni.samples).hexdigest(),'width':ni.width,'height':ni.height})
  for pl in npart['placements']:
   page=ndoc[pl['outputPage']-1]
   for typ,r in [('music',pl['destinationRect'])]+[('marking',v['destinationRect']) for v in pl['sourceMarkings']]:
    if not (0<=r[0]<r[2]<=page.rect.width+1e-7 and 0<=r[1]<r[3]<=page.rect.height+1e-7):bounds.append({'id':pl['id'],'type':typ,'rectangle':r})
  parts.append({'name':npart['name'],'pdfSHA256':h(npath.parent/npart['file']),'outputPages':len(ndoc),'bands':len(npart['placements']),'sourceCopies':sum(len(p['sourceMarkings']) for p in npart['placements']),'allPlacementGeometryIdenticalToBaseline':geometry,'blankPages':blank,'outOfPagePlacements':bounds,'pixelDifferencesAt150DPI':diffs,'rasters':rasters})
  print(c['id'],npart['name'],len(ndoc),'geometry',geometry,'differentpages',len(diffs),flush=True)
 package=npath.parent/n['project']
 assert h(package/'source.pdf')==c['sourceSHA256']
 results.append({'id':c['id'],'sourceSHA256':c['sourceSHA256'],'manifestSHA256':h(npath),'projectJSONSHA256':h(package/'project.json'),'rectifications':c['rectifications'],'parts':parts})
(w/'export-comparison.json').write_text(json.dumps(results,indent=2)+'\n')
