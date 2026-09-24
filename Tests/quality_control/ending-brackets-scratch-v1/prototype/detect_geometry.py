"""Scratch only: propose ending brackets from a line and its descending left hook.
No source page IDs or oracle rectangles are used during detection.
"""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
import pymupdf as fitz
WORK=Path('.build/qc-ending-brackets')
SOURCES=[
 ('kv498','sample_scores/normal/01_chamber/mozart_trio_eb_major_kv498_score.pdf','.build/auto-qc/kv498-headings/menuetto-inventory.json','.build/auto-qc/kv498-headings/menuetto-parts/manifest.json'),
 ('brahms93521','.build/auto-qc/candidate8-directions/quartet93521-parts/rectified-review-source.pdf','.build/qc-repeat-symbols/native/candidate8-headings-navigation-destinations.json','.build/auto-qc/candidate8-directions/quartet93521-parts/manifest.json')]
def runs(row,gap=1):
 idx=np.flatnonzero(row)
 if not len(idx):return []
 breaks=np.flatnonzero(np.diff(idx)>gap+1)
 starts=np.r_[0,breaks+1];ends=np.r_[breaks,len(idx)-1]
 return [(int(idx[a]),int(idx[b]+1)) for a,b in zip(starts,ends)]
def geometry(gray,space):
 black=gray<170; h,w=black.shape;radius=max(1,int(space*.1)); pooled=black.copy()
 for n in range(1,radius+1):
  pooled[n:]|=black[:-n];pooled[:-n]|=black[n:]
 proposals=[]
 for y in range(radius,h-radius):
  for x0,x1 in runs(pooled[y],max(1,int(space*.08))):
   if x1-x0 < space*4:continue
   # A thin horizontal engraving line, not a thick beam or a distant union.
   support=float(black[y,x0:x1].mean())
   if support<.68:continue
   if black[y-radius:y+radius+1,x0:x1].sum(axis=0).mean()>space*.38:continue
   candidates=[]
   for x in range(max(0,int(x0-space*.25)),min(w,int(x0+space*.35)+1)):
    last=y;misses=0
    for yy in range(y+radius+1,min(h,int(y+space*4))):
     if black[yy,max(0,x-1):min(w,x+2)].any():last=yy;misses=0
     else:misses+=1
     if misses>max(1,int(space*.08)):break
    length=last-y
    if space*.7<=length<=space*3.1:candidates.append((length,x,last))
   if not candidates:continue
   length,x,last=max(candidates)
   proposal={'line':[x0,y,x1,y],'hook':[x,y,x,last],'support':support,'space':space}
   prior=next((p for p in proposals if abs(p['line'][1]-y)<=space*.45 and abs(p['line'][0]-x0)<=space*.4 and abs(p['line'][2]-x1)<=space*.4),None)
   if prior:
    if support>prior['support']:prior.update(proposal)
   else:proposals.append(proposal)
 return proposals
results=[]; pageRecords=[]
for score,source,inventory,manifest in SOURCES:
 d=fitz.open(source); inv=json.loads(Path(inventory).read_text()); m=json.loads(Path(manifest).read_text());pindex={p['pageIndex']+1:p for p in inv['pages']}
 for pi,page in enumerate(d):
  p=pindex[pi+1];ordered=sorted(p['staves'],key=lambda s:s['staffLineFractions'][0]);bysystem={}
  for part in m['parts']:
   for b in part['placements']:
    if b['sourcePage']==pi+1:bysystem.setdefault(b['system'],set()).update(b['candidateIDs'])
  scale=min(2400/page.rect.width,3500/page.rect.height);pix=page.get_pixmap(matrix=fitz.Matrix(scale,scale),colorspace=fitz.csGRAY); gray=np.frombuffer(pix.samples,np.uint8).reshape(pix.height,pix.width);sx=pix.width/page.rect.width;sy=pix.height/page.rect.height
  beforeCount=len(results)
  for system,ids in sorted(bysystem.items()):
   si=next(i for i,s in enumerate(ordered) if s['id'] in ids);staff=ordered[si];ys=staff['staffLineFractions'];space=(ys[4]-ys[0])*pix.height/4;top=ys[0]*pix.height;previous=ordered[si-1]['staffLineFractions'][4]*pix.height+space*.1 if si else 0;y0=max(0,int(max(previous,top-space*14)));y1=min(pix.height,int(top-space*.12))
   if y1-y0<space:continue
   for c in geometry(gray[y0:y1],space):
    x0,y,x1,_=c['line'];y+=y0;hookx,_,_,hookbottom=c['hook'];hookbottom+=y0
    bounds=[max(0,x0-space*.3),max(0,y-space*.3),min(pix.width,x1+space*.3),min(pix.height,max(y+space*2.35,hookbottom+space*.25))]
    number=[max(0,int(x0+space*.4)),max(0,int(y+space*.15)),min(pix.width,int(x0+space*3.3)),min(y1,int(max(y+space*2.2,hookbottom+space*.15)))]
    if number[3]<=number[1] or number[2]<=number[0]:continue
    index=len(results);name=f'{score}-p{pi+1:02}-s{system}-c{index:03}'
    num=Image.fromarray(gray[number[1]:number[3],number[0]:number[2]]);num.resize((num.width*4,num.height*4)).save(WORK/'candidates'/f'{name}-number.png')
    clip=[max(0,int(bounds[0]-space)),max(0,int(bounds[1]-space)),min(pix.width,int(bounds[2]+space)),min(pix.height,int(bounds[3]+space))];Image.fromarray(gray[clip[1]:clip[3],clip[0]:clip[2]]).save(WORK/'candidates'/f'{name}-context.png')
    results.append({'id':name,'score':score,'sourcePage':pi+1,'system':system,'anchorStaffID':staff['id'],'linePixels':[x0,y,x1,y],'leftHookPixels':[hookx,y,hookx,hookbottom],'bounds':[bounds[0]/sx,bounds[1]/sy,bounds[2]/sx,bounds[3]/sy],'numberBounds':[number[0]/sx,number[1]/sy,number[2]/sx,number[3]/sy],'numberImage':str(WORK/'candidates'/f'{name}-number.png'),'contextImage':str(WORK/'candidates'/f'{name}-context.png'),'lineSupport':c['support']})
  pageRecords.append({'score':score,'page':pi+1,'systems':len(bysystem),'geometryCandidates':len(results)-beforeCount});print(score,pi+1,len(results)-beforeCount,flush=True)
(WORK/'geometry-candidates.json').write_text(json.dumps({'status':'scratch geometry proposals, require verified printed number','candidates':results,'pages':pageRecords,'sources':[{'score':x[0],'source':x[1],'sha256':hashlib.sha256(Path(x[1]).read_bytes()).hexdigest()} for x in SOURCES]},indent=2)+'\n')
print('total',len(results))
