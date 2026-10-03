from pathlib import Path
import json,hashlib
import pymupdf as fitz
from PIL import Image,ImageDraw,ImageFont
P=Path('.build/erlkonig-complete-2026-10-03');R=P/'independent-review';M=json.loads((P/'parts/manifest.json').read_text());S=json.loads((P/'source-reviewed-map.json').read_text());I=json.loads((P/'inventory.json').read_text());src=fitz.open(M['source']);F=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',16)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(Path(M['source']))==M['sourceSHA256']
for sub in ['source','output','systems']: (R/sub).mkdir(exist_ok=True)
def render(page,rect=None,scale=2):
 p=page.get_pixmap(matrix=fitz.Matrix(scale,scale),clip=fitz.Rect(rect) if rect else None,alpha=False);return Image.frombytes('RGB',[p.width,p.height],p.samples)
for n,page in enumerate(src):render(page).save(R/'source'/f'p{n+1:02}.png')
outs={}
for part in M['parts']:
 f=P/'parts'/part['file'];doc=fitz.open(f);assert len(doc)==part['outputPages'];outs[part['id']]=doc
 for n,page in enumerate(doc):render(page).save(R/'output'/f'{part["id"]}-p{n+1:02}.png')
index=[]
for system in S['systems']:
 pn=system['page'];sn=system['system'];page=I['pages'][pn-1];staff={s['id']:s for s in page['staves']};ids=[i for b in system['bands'] for i in b['candidateIDs']];lines=[y*page['pageHeight'] for i in ids for y in staff[i]['staffLineFractions']];context=[0,max(0,min(lines)-42),page['pageWidth'],min(page['pageHeight'],max(lines)+45)]
 # Source context comes from complete system geometry, not proposed part crop edges.
 raw=render(src[pn-1],context,2);pieces=[];placements=[]
 for part in M['parts']:
  p=next(p for p in part['placements'] if p['sourcePage']==pn and p['system']==sn);placements.append({'partID':part['id'],**p});r=list(p['destinationRect'])
  for cue in p.get('sourceMarkings',[]):
   b=cue['destinationRect'];r=[min(r[0],b[0]),min(r[1],b[1]),max(r[2],b[2]),max(r[3],b[3])]
  r=[r[0],max(0,r[1]-2),r[2],r[3]+2];im=render(outs[part['id']][p['outputPage']-1],r,2)
  # Same displayed score width on both sides; source/part aspect ratio stays intact.
  nw=raw.width;nh=round(im.height*nw/im.width);im=im.resize((nw,nh),Image.Resampling.LANCZOS);c=Image.new('RGB',(nw,nh+28),'white');c.paste(im,(0,28));ImageDraw.Draw(c).text((4,4),part['name']+f' output page{p["outputPage"]} / '+p['kind'],fill='black',font=F);pieces.append(c)
 right=Image.new('RGB',(raw.width,sum(p.height for p in pieces)+8),'#dddddd');y=0
 for im in pieces:right.paste(im,(0,y));y+=im.height+8
 canvas=Image.new('RGB',(raw.width*2+12,max(raw.height,right.height)+32),'white');canvas.paste(raw,(0,32));canvas.paste(right,(raw.width+12,32));d=ImageDraw.Draw(canvas);d.text((4,5),f'Source p{pn} system{sn} bars{system["firstBar"]}–{system["firstBar"]+system["barCount"]-1}',font=F,fill='black');d.text((raw.width+16,5),'Actual exported PDF rows (same displayed score width)',font=F,fill='black');name=f'systems/p{pn:02}-s{sn}.png';canvas.save(R/name)
 index.append({'page':pn,'system':sn,'bars':[system['firstBar'],system['firstBar']+system['barCount']-1],'context':context,'placements':placements,'image':name,'imageSHA256':sha(R/name)})
bind={str(p):sha(p) for p in [P/'parts/manifest.json',P/'parts/plan.json',P/'inventory.json',P/'source-reviewed-map.json',P/'profile.json',P/'overrides.json',Path(M['source']),*[P/'parts'/x['file'] for x in M['parts']]]}
(R/'index.json').write_text(json.dumps(index,indent=2)+'\n');(R/'bindings.json').write_text(json.dumps(bind,indent=2)+'\n');print('rendered11source pages,13output pages,48system comparisons; source/output files hash bound')
