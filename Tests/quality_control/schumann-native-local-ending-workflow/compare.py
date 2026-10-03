import hashlib,json
from pathlib import Path
import pymupdf as fitz
from PIL import Image,ImageDraw
root=Path('.build/ending-local-app-native-2026-10-03');out=root/'schumann-parts'
old=Path('.build/ending-local-counterparts/medium-skewed-03-schumann-piano-quintet-op44-imslp-06822/parts')
r=Path('Tests/quality_control/schumann-native-local-ending-workflow');r.mkdir(exist_ok=True,parents=True)
for name in ['row-review','page-review','source-review']:(r/name).mkdir(exist_ok=True)
load=lambda p:json.loads(Path(p).read_text())
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def close(a,b):return len(a)==len(b) and all(abs(x-y)<1e-6 for x,y in zip(a,b))
fresh=load(root/'schumann-inventory.json');pages={p['pageIndex']:p for p in fresh['pages']}
before=load(old/'manifest.json');after=load(out/'manifest.json')
assert fresh['sourceSHA256']==before['sourceSHA256']==after['sourceSHA256']
source=fitz.open(fresh['source']);source_images={};rows=[];parts=[];changed_page_images=[]
for part in after['parts']:
 prior=next(p for p in before['parts'] if p['id']==part['id']);a=fitz.open(out/part['file']);b=fitz.open(old/prior['file'])
 assert sha(out/part['file'])==part['sha256']
 priorbands={v['id']:v for v in prior['placements']}
 changedmain=[];changedmarkings=[];changedplacements=[];added=[];removed=[];overflow=[];collisions=[]
 for band in part['placements']:
  prev=priorbands[band['id']]
  assert all(band[k]==prev[k] for k in ['id','sourcePage','system','candidateIDs','kind'])
  if not close(band['sourceRect'],prev['sourceRect']):changedmain.append({'band':band['id'],'old':prev['sourceRect'],'new':band['sourceRect']})
  if band['destinationRect']!=prev['destinationRect'] or band['outputPage']!=prev['outputPage']:changedplacements.append(band['id'])
  new=[m for m in band['sourceMarkings'] if not any(close(m['sourceRect'],n['sourceRect']) and m.get('isBelow',False)==n.get('isBelow',False) for n in prev['sourceMarkings'])]
  lost=[m for m in prev['sourceMarkings'] if not any(close(m['sourceRect'],n['sourceRect']) and m.get('isBelow',False)==n.get('isBelow',False) for n in band['sourceMarkings'])]
  if new or lost:changedmarkings.append(band['id'])
  for m in lost:removed.append({'band':band['id'],'sourcePage':band['sourcePage'],'system':band['system'],'mark':m})
  for m in new:
   pi=band['sourcePage']-1;p=pages[pi];w,h=p['pageWidth'],p['pageHeight'];norm=[m['sourceRect'][0]/w,m['sourceRect'][1]/h,m['sourceRect'][2]/w,m['sourceRect'][3]/h]
   categories=[];evidence=[]
   for key,label in [('sharedHeadings','heading'),('sharedNavigation','navigation/destination'),('sharedEndings','ending')]:
    for mark in p.get(key,[]) or []:
     if close(mark['bounds'],norm):categories.append(label);evidence.append(mark)
   item={'part':part['id'],'band':band['id'],'sourcePage':band['sourcePage'],'system':band['system'],'outputPage':band['outputPage'],'mark':m,'categories':categories,'evidence':evidence}
   idx=len(rows)+1
   union=fitz.Rect(band['destinationRect'])
   for copied in band['sourceMarkings']:union |= fitz.Rect(copied['destinationRect'])
   clip=fitz.Rect(max(0,union.x0-5),max(0,union.y0-7),min(612,union.x1+5),min(792,union.y1+7))
   image=r/'row-review'/f'{idx:03d}-{band["id"]}.png';a[band['outputPage']-1].get_pixmap(matrix=fitz.Matrix(2,2),clip=clip,alpha=False).save(image)
   item['recipientImage']=str(image)
   sx=fitz.Rect(m['sourceRect']);context=fitz.Rect(max(0,sx.x0-16),max(0,sx.y0-20),min(w,sx.x1+16),min(h,sx.y1+35))
   raw=r/'source-review'/f'{idx:03d}-{band["id"]}.png';source[pi].get_pixmap(matrix=fitz.Matrix(3,3),clip=context,alpha=False).save(raw);item['sourceContextImage']=str(raw)
   exact=r/'source-review'/f'{idx:03d}-{band["id"]}-exact.png';source[pi].get_pixmap(matrix=fitz.Matrix(3,3),clip=sx,alpha=False).save(exact);item['exactSourceImage']=str(exact)
   rows.append(item);added.append(idx)
  rectangles=[band['destinationRect']]+[m['destinationRect'] for m in band['sourceMarkings']]
  for rect in rectangles:
   if rect[0]<-1e-6 or rect[1]<-1e-6 or rect[2]>612+1e-6 or rect[3]>792+1e-6:overflow.append({'band':band['id'],'rect':rect})
 for pn in range(1,len(a)+1):
  bands=[x for x in part['placements'] if x['outputPage']==pn]
  bands=sorted(bands,key=lambda z:z['destinationRect'][1])
  extents=[(x['id'],min([x['destinationRect'][1]]+[m['destinationRect'][1] for m in x['sourceMarkings']]),max([x['destinationRect'][3]]+[m['destinationRect'][3] for m in x['sourceMarkings']])) for x in bands]
  for prev,following in zip(extents,extents[1:]):
   if prev[2]>following[1]+1e-6:collisions.append({'page':pn,'previous':prev,'next':following})
 rendered=[];changedpages=[]
 for i,p in enumerate(a):
  pix=p.get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
  same=False
  if i<len(b):
   oldpix=b[i].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False);same=(pix.width,pix.height,pix.samples)==(oldpix.width,oldpix.height,oldpix.samples)
  dest=root/'schumann-rendered'/part['id']/f'page-{i+1:03d}.png';dest.parent.mkdir(exist_ok=True,parents=True);pix.save(dest)
  rendered.append({'page':i+1,'image':str(dest),'pixelSHA256':hashlib.sha256(pix.samples).hexdigest(),'sameBaselinePage':same})
  if not same:changedpages.append(i+1);changed_page_images.append({'part':part['id'],'page':i+1,'image':str(dest)})
 parts.append({'part':part['id'],'beforePages':len(b),'pages':len(a),'bands':len(part['placements']),'changedMainCrops':changedmain,'changedMarkingBands':changedmarkings,'changedPlacements':changedplacements,'newRowIndices':added,'removedCopies':removed,'overflow':overflow,'collisions':collisions,'changedPages':changedpages,'renderedPages':rendered,'pdf':str(out/part['file']),'sha256':sha(out/part['file'])})
(r/'comparison.json').write_text(json.dumps({'sourceSHA256':fresh['sourceSHA256'],'beforeManifestSHA256':sha(old/'manifest.json'),'afterManifestSHA256':sha(out/'manifest.json'),'inventorySHA256':sha(root/'schumann-inventory.json'),'parts':parts},indent=2)+'\n')
(r/'new-copy-rows.json').write_text(json.dumps(rows,indent=2)+'\n')
# Each recipient row is readable separately; contact sheets support fast full review.
for first in range(0,len(rows),6):
 canvas=Image.new('RGB',(1900,1700),'white');d=ImageDraw.Draw(canvas)
 for k,item in enumerate(rows[first:first+6]):
  im=Image.open(item['recipientImage']);im.thumbnail((1840,240));y=k*280
  d.text((12,y+4),f'{first+k+1} {item["band"]} {item["categories"]}',fill='black');canvas.paste(im,(20,y+30))
 canvas.save(r/'row-review'/f'contact-{first//6+1:02d}.png')
for first in range(0,len(changed_page_images),4):
 canvas=Image.new('RGB',(1900,2450),'#dddddd');d=ImageDraw.Draw(canvas)
 for k,item in enumerate(changed_page_images[first:first+4]):
  im=Image.open(item['image']);im.thumbnail((930,1188));x=(k%2)*950;y=(k//2)*1225
  d.text((x+10,y+2),item['part']+' page '+str(item['page']),fill='black');canvas.paste(im,(x+10,y+25))
 canvas.save(r/'page-review'/f'contact-{first//4+1:02d}.png')
(r/'changed-page-index.json').write_text(json.dumps(changed_page_images,indent=2)+'\n')
print(json.dumps({'parts':len(parts),'pages':sum(p['pages'] for p in parts),'newCopyRows':len(rows),'changedPages':len(changed_page_images),'changedMainCrops':sum(len(p['changedMainCrops']) for p in parts),'copiesRemoved':sum(len(p['removedCopies']) for p in parts),'overflow':sum(len(p['overflow']) for p in parts),'collisions':sum(len(p['collisions']) for p in parts)},indent=2))
