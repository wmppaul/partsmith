from pathlib import Path
import json,hashlib,math
import pymupdf as fitz
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
WORK=ROOT/'.build/brahms-glyph-output-2026-10-03'
NATIVE=ROOT/'.build/heading-glyph-continuation-2026-10-03/native-worker'
load=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
font=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',15)
def close(a,b):return len(a)==len(b) and all(abs(x-y)<1e-6 for x,y in zip(a,b))
def extent(b):
 rs=[b['destinationRect']]+[m['destinationRect'] for m in b['sourceMarkings']]
 return [min(r[0] for r in rs),min(r[1] for r in rs),max(r[2] for r in rs),max(r[3] for r in rs)]
for p,h in load(OUT/'input-bindings.json').items():assert sha(ROOT/p)==h,p
parts=[];copied=[];pages=[];issues=[]
for case in ['brahms242312','brahms09200']:
 folder=WORK/(case+'-parts');m=load(folder/'manifest.json');inv=load(NATIVE/(case+'-inventory.json'))
 assert load(folder/'plan.json')==load(NATIVE/(case+'-plan.json'))
 source=fitz.open(m['source']);assert sha(Path(m['source']))==m['sourceSHA256']==inv['sourceSHA256']
 assert sha(folder/m['project']/'source.pdf')==m['sourceSHA256']
 project=load(folder/m['project']/'project.json')['project']
 assert project['pageCount']==len(source)
 assert len(m['parts'])==4 and m['rectifications']==[] and m['reviewedOverrides']==[]
 planned=[b for p in load(folder/'plan.json')['pages'] for b in p['assignments']]
 for part in m['parts']:
  assert sha(folder/part['file'])==part['sha256']
  expected=[x['id'] for x in planned if x['partID']==part['id']]
  assert [b['id'] for b in part['placements']]==expected
  pdf=fitz.open(folder/part['file']);assert len(pdf)==part['outputPages']
  pdir=WORK/'rendered'/case/part['id'];pdir.mkdir(parents=True,exist_ok=True)
  for i,page in enumerate(pdf):
   pix=page.get_pixmap(matrix=fitz.Matrix(2,2),alpha=False);path=pdir/f'page-{i+1:03}.png';pix.save(path)
   pages.append({'case':case,'part':part['id'],'page':i+1,'image':str(path.relative_to(ROOT)),'pixelSHA256':hashlib.sha256(pix.samples).hexdigest()})
   placed=[b for b in part['placements'] if b['outputPage']==i+1]
   extents=sorted([(extent(b),b['id']) for b in placed],key=lambda t:t[0][1])
   for (a,aid),(b,bid) in zip(extents,extents[1:]):
    if a[3]>b[1]+1e-6:issues.append({'case':case,'part':part['id'],'page':i+1,'type':'row collision','previous':aid,'next':bid})
   for b in placed:
    e=extent(b)
    if min(e[:2])<0 or e[2]>page.rect.width+1e-6 or e[3]>page.rect.height+1e-6:issues.append({'case':case,'band':b['id'],'type':'page overflow'})
  for band in part['placements']:
   sx=band['sourceRect'];dx=band['destinationRect'];sp=source[band['sourcePage']-1]
   if not (0<=sx[0]<sx[2]<=sp.rect.width+.01 and 0<=sx[1]<sx[3]<=sp.rect.height+.01):issues.append({'case':case,'band':band['id'],'type':'source out of bounds'})
   if abs((dx[2]-dx[0])/(sx[2]-sx[0])-(dx[3]-dx[1])/(sx[3]-sx[1]))>1e-6:issues.append({'case':case,'band':band['id'],'type':'aspect mismatch'})
   for ys in band['staffLineYs']:
    if min(ys)<sx[1] or max(ys)>sx[3]:issues.append({'case':case,'band':band['id'],'type':'target staff not fully retained'})
   for mi,mark in enumerate(band['sourceMarkings']):
    idx=len(copied)+1;p=inv['pages'][band['sourcePage']-1]
    norm=[mark['sourceRect'][0]/p['pageWidth'],mark['sourceRect'][1]/p['pageHeight'],mark['sourceRect'][2]/p['pageWidth'],mark['sourceRect'][3]/p['pageHeight']]
    evidence=[]
    for key in ['sharedHeadings','sharedNavigation','sharedEndings']:
     for v in p.get(key,[]) or []:
      if close(v['bounds'],norm):evidence.append({'category':key,'metadata':v})
    rr=fitz.Rect(extent(band));rr=fitz.Rect(max(0,rr.x0-4),max(0,rr.y0-5),min(612,rr.x1+4),min(792,rr.y1+5))
    rd=OUT/'copied-rows';rd.mkdir(exist_ok=True);row=rd/f'{idx:03}-{case}-{band["id"]}.png'
    pdf[band['outputPage']-1].get_pixmap(matrix=fitz.Matrix(3,3),clip=rr,alpha=False).save(row)
    sd=OUT/'copied-sources';sd.mkdir(exist_ok=True);sr=fitz.Rect(mark['sourceRect']);sourceimage=sd/f'{idx:03}-{case}-{band["id"]}.png'
    context=fitz.Rect(max(0,sr.x0-10),max(0,sr.y0-10),min(sp.rect.width,sr.x1+10),min(sp.rect.height,sr.y1+20))
    sp.get_pixmap(matrix=fitz.Matrix(3,3),clip=context,alpha=False).save(sourceimage)
    exact=sd/f'{idx:03}-exact.png';sp.get_pixmap(matrix=fitz.Matrix(3,3),clip=sr,alpha=False).save(exact)
    scale=(dx[2]-dx[0])/(sx[2]-sx[0]);mr=mark['sourceRect'];md=mark['destinationRect']
    if abs((mr[2]-mr[0])*scale-(md[2]-md[0]))>1e-6 or abs((mr[3]-mr[1])*scale-(md[3]-md[1]))>1e-6:issues.append({'case':case,'band':band['id'],'type':'copy scale mismatch'})
    if abs(dx[0]+(mr[0]-sx[0])*scale-md[0])>1e-6:issues.append({'case':case,'band':band['id'],'type':'copy horizontal mapping mismatch'})
    copied.append({'number':idx,'case':case,'part':part['id'],'band':band['id'],'outputPage':band['outputPage'],'sourcePage':band['sourcePage'],'mark':mark,'evidence':evidence,'recipientImage':str(row.relative_to(ROOT)),'sourceContextImage':str(sourceimage.relative_to(ROOT)),'exactSourceImage':str(exact.relative_to(ROOT))})
  parts.append({'case':case,'part':part['id'],'file':part['file'],'pages':len(pdf),'bands':len(part['placements']),'copies':sum(len(b['sourceMarkings']) for b in part['placements']),'sha256':part['sha256']})

def sheets(entries,key,folder,perpage,columns,cell):
 folder.mkdir(exist_ok=True);cw,ch=cell
 for first in range(0,len(entries),perpage):
  rows=math.ceil(min(perpage,len(entries)-first)/columns);canvas=Image.new('RGB',(cw*columns,ch*rows),'#ddd');d=ImageDraw.Draw(canvas)
  for i,v in enumerate(entries[first:first+perpage]):
   im=Image.open(ROOT/v[key]);im.thumbnail((cw-14,ch-40));x=(i%columns)*cw;y=(i//columns)*ch
   title=f"{v['case']} {v['part']} p{v.get('page',v.get('outputPage'))}"
   if 'number' in v:title=f"{v['number']:03} "+title+' '+v['band']
   d.text((x+7,y+5),title,font=font,fill='black');canvas.paste(im,(x+7,y+32))
  canvas.save(folder/f'sheet-{first+1:03}.png')
sheets(pages,'image',OUT/'pages',4,2,(720,980))
sheets(copied,'recipientImage',OUT/'rows',5,1,(1700,260))
sheets(copied,'sourceContextImage',OUT/'sources',8,1,(1700,185))
(OUT/'output-review.json').write_text(json.dumps({'parts':parts,'pages':pages,'copiedRows':copied,'issues':issues},indent=2)+'\n')
print(json.dumps({'parts':parts,'pageCount':len(pages),'copiedRows':len(copied),'issues':issues},indent=2))
assert not issues
