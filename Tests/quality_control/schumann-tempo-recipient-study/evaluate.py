from pathlib import Path
import json,sys,hashlib
import pymupdf as fitz
import numpy as np
W=Path('.build/schumann-directions');folder=W/sys.argv[1];m=json.load(open(folder/'parts/manifest.json'));base=json.load(open(W/'baseline/parts/manifest.json'));original=json.load(open('.build/auto-qc/connector8-harmonic/corpus/lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922/parts/manifest.json'))
source=fitz.open(m['source']);by={(p['id'],b['sourcePage'],b['system']):b for p in m['parts'] for b in p['placements']};prior={b['id']:b for p in original['parts'] for b in p['placements']}
result={'variant':sys.argv[1],'originalCropChanges':[],'outputParts':[],'outsidePage':[],'overlap':[],'obligations':[],'copyCount':sum(len(b['sourceMarkings']) for p in m['parts'] for b in p['placements'])}
for p in m['parts']:
 pdf=fitz.open(folder/'parts'/p['file']);result['outputParts'].append({'part':p['id'],'pages':len(pdf),'bands':p['bandCount'],'sha256':hashlib.sha256((folder/'parts'/p['file']).read_bytes()).hexdigest()})
 envelopes={}
 for b in p['placements']:
  if any(b[k]!=prior[b['id']][k] for k in ['sourceRect','candidateIDs','staffLineYs','sourcePage','system']):result['originalCropChanges'].append(b['id'])
  items=[b]+b['sourceMarkings'];un=None
  for item in items:
   r=fitz.Rect(item['destinationRect'])
   if not pdf[b['outputPage']-1].rect.contains(r):result['outsidePage'].append(b['id'])
   un=r if un is None else un|r
  envelopes.setdefault(b['outputPage'],[]).append((b['id'],un))
 for page,env in envelopes.items():
  for (aid,a),(bid,b) in zip(env,env[1:]):
   if a.y1>b.y0+1e-6:result['overlap'].append([p['id'],page,aid,bid])
for obligation in json.load(open(W/'frozen-obligations.json'))['obligations']:
 r=fitz.Rect(obligation['sourceRegion']);pix=source[obligation['sourcePage']-1].get_pixmap(matrix=fitz.Matrix(4,4),clip=r,alpha=False)
 pixels=np.frombuffer(pix.samples,np.uint8).reshape(pix.height,pix.width,3);mask=np.min(pixels,axis=2)<255
 yy,xx=np.where(mask);xs=(xx+pix.x+.5)/4;ys=(yy+pix.y+.5)/4
 for part in obligation['affectedParts']:
  b=by[(part,obligation['sourcePage'],obligation['system'])];rects=[b['sourceRect']]+[x['sourceRect'] for x in b['sourceMarkings']];covered=np.zeros(len(xs),bool)
  for x0,y0,x1,y1 in rects:covered|=(xs>=x0)&(xs<x1)&(ys>=y0)&(ys<y1)
  missed=np.where(~covered)[0]; item={'id':obligation['id'],'part':part,'sourcePage':obligation['sourcePage'],'system':obligation['system'],'text':obligation['text'],'sourcePixelCount':len(xs),'missingSourcePixels':len(missed),'sourcePixelFullyContained':len(missed)==0,'sourceRects':rects,'outputPage':b['outputPage']}
  if len(missed):item['missingBounds']=[float(xs[missed].min()),float(ys[missed].min()),float(xs[missed].max()),float(ys[missed].max())]
  result['obligations'].append(item)
for category in ['tempo','indices']:
 obs=[x for x in result['obligations'] if x['id'].startswith('song-index') == (category=='indices')];result[category]={'total':len(obs),'completeSourceEnvelope':sum(x['sourcePixelFullyContained'] for x in obs)}
(folder/'evaluation.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
print(sys.argv[1],result['tempo'],result['indices'],'copies',result['copyCount'],'changed crops',len(result['originalCropChanges']),'outside',len(result['outsidePage']),'overlap',len(result['overlap']))
for r in result['obligations']:
 if not r['id'].startswith('song-index'):print(r['id'],r['sourcePixelFullyContained'],r['missingSourcePixels'],r.get('missingBounds'))
