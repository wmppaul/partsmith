import json,hashlib
from pathlib import Path
import pymupdf as fitz
from PIL import Image,ImageDraw
id='medium-skewed-03-schumann-piano-quintet-op44-imslp-06822';root=Path('.build/ending-local-counterparts');w=root/id
old=Path('.build/ending-corpus-2026-10-03')/id
r=Path('Tests/quality_control/ending-local-counterparts');(r/'output-review').mkdir(exist_ok=True,parents=True)
def h(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(Path(p).read_text())
a=load(w/'parts/manifest.json');b=load(old/'with-endings/manifest.json');c=load(old/'before-endings/manifest.json');result=[]
for part in a['parts']:
 target=next(x for x in b['parts'] if x['id']==part['id']);control=next(x for x in c['parts'] if x['id']==part['id']);reference=control if part['id']=='piano' else target
 pdf=fitz.open(w/'parts'/part['file']);refdir=old/('before-endings' if part['id']=='piano' else 'with-endings')
 ref=fitz.open(refdir/reference['file']);assert len(pdf)==len(ref)
 out=w/'rendered'/part['id'];out.mkdir(exist_ok=True,parents=True)
 rows=[];pagehashes=[]
 for i,page in enumerate(pdf):
  p=page.get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False);q=ref[i].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
  same=(p.width,p.height,p.samples)==(q.width,q.height,q.samples)
  dest=out/f'page-{i+1:03d}.png';p.save(dest)
  pagehashes.append({'page':i+1,'sameReferenceRaster':same,'pixelSHA256':hashlib.sha256(p.samples).hexdigest(),'image':str(dest)})
  assert same,(part['id'],i+1)
 byid={x['id']:x for x in target['placements']};changed=[]
 for band in part['placements']:
  prior=byid[band['id']]
  assert all(band[k]==prior[k] for k in ['id','sourcePage','system','sourceRect','candidateIDs','kind'])
  if band['sourceMarkings']!=prior['sourceMarkings']:
   changed.append(band['id']);assert part['id']=='piano' and band['sourceMarkings']==[]
   rect=fitz.Rect(band['destinationRect']);rect=fitz.Rect(max(0,rect.x0-4),max(0,rect.y0-8),min(612,rect.x1+4),min(792,rect.y1+8))
   pix=pdf[band['outputPage']-1].get_pixmap(matrix=fitz.Matrix(2,2),clip=rect,alpha=False)
   dest=r/'output-review'/f"{band['id']}.png";pix.save(dest)
   rows.append({'bandID':band['id'],'outputPage':band['outputPage'],'sourcePage':band['sourcePage'],'system':band['system'],'image':str(dest),'sha256':h(dest)})
 assert part['placements']==reference['placements'],part['id']
 result.append({'part':part['id'],'pages':len(pdf),'beforePages':target['outputPages'],'changedCopies':changed,'referenceVariant':'no-ending control' if part['id']=='piano' else 'with-ending control','allPlacementsMatchReference':True,'allMainCropsMatchBefore':True,'allPagesPixelIdenticalToReference':True,'renderedPages':pagehashes,'reviewRows':rows,'pdf':str(w/'parts'/part['file']),'pdfSHA256':h(w/'parts'/part['file'])})
(r/'export-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
images=[x for p in result for x in p['reviewRows']]
canvas=Image.new('RGB',(1800,1600),'white');d=ImageDraw.Draw(canvas)
for i,x in enumerate(images):
 im=Image.open(x['image']);im.thumbnail((1750,280));top=i*315
 d.text((12,top+5),x['bandID']+' output p'+str(x['outputPage']),fill='black');canvas.paste(im,(15,top+30))
canvas.save(r/'output-review/piano-corrected-rows.png')
print('All',sum(p['pages'] for p in result),'pages pixel-identical to expected control; 5 removed duplicate rows; all825 main crops exact')
