from pathlib import Path
import json,sys,pymupdf as f
from PIL import Image,ImageDraw
W=Path('.build/schumann-directions');v=W/(sys.argv[1] if len(sys.argv)>1 else 'candidate-v2');m=json.load(open(v/'parts/manifest.json'));src=f.open(m['source']);rows=[];v.joinpath('review').mkdir(exist_ok=True)
for p in m['parts']:
 pdf=f.open(v/'parts'/p['file'])
 for page in range(len(pdf)):
  pdf[page].get_pixmap(matrix=f.Matrix(1.5,1.5)).save(v/'review'/f"{p['id']}-{page+1:02}.png")
 for b in p['placements']:
  for i,mark in enumerate(b['sourceMarkings']):
   r=f.Rect(mark['sourceRect']);sr=r+(-3,-3,3,3);dr=f.Rect(mark['destinationRect']);k=4
   pix=src[b['sourcePage']-1].get_pixmap(matrix=f.Matrix(k,k),clip=sr);si=Image.frombytes('RGB',(pix.width,pix.height),pix.samples);draw=ImageDraw.Draw(si);draw.rectangle(((r.x0-sr.x0)*k,(r.y0-sr.y0)*k,(r.x1-sr.x0)*k,(r.y1-sr.y0)*k),outline='red',width=2)
   pix=pdf[b['outputPage']-1].get_pixmap(matrix=f.Matrix(k,k),clip=dr);oi=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
   width=max(si.width,oi.width)+20;row=Image.new('RGB',(width,si.height+oi.height+70),'white');d=ImageDraw.Draw(row);d.text((5,5),f"{b['id']} -> {p['id']} page {b['outputPage']} (source then actual new copy)",fill='black');row.paste(si,(10,24));row.paste(oi,(10,si.height+50));row.save(v/'review'/f"{b['id']}-mark{i+1}.png");rows.append(row)
for n in range(0,len(rows),5):
 selected=rows[n:n+5];c=Image.new('RGB',(max(x.width for x in selected),sum(x.height for x in selected)+12*(len(selected)-1)),'#ccc');y=0
 for r in selected:c.paste(r,(0,y));y+=r.height+12
 c.save(v/'review'/f'directions-contact-{n//5+1}.png')
print('Rendered 19 output pages and',len(rows),'source/output copy comparisons')
