from pathlib import Path
import json
import pymupdf as fitz
from PIL import Image,ImageDraw
b=Path('.build/mozart-auxiliary-review-2026-10-03/edge-completion');(b/'images').mkdir(exist_ok=True)
a=json.load(open(b/'results/comparison.json'))
paths={'mozart':'sample_scores/medium_skewed/01_mozart_piano_quartet_k478_imslp_86903.pdf','brahms':'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-preservation/rectified-review-source.pdf'}
for name,c in a.items():
 d=fitz.open(paths[name]);strips=[];pairs=[]
 for q in c['changes']:
  p=d[q['sourcePage']-1];r=q['candidate'];ctx=fitz.Rect(0,max(0,r[1]-32),p.rect.width,min(p.rect.height,r[3]+32));tag=name+'-'+q['id'];f=b/'images'/f'{tag}-context.png';p.get_pixmap(matrix=fitz.Matrix(2.5,2.5),clip=ctx).save(f);strips.append((tag,Image.open(f).convert('RGB')))
  ims=[]
  for kind in ['baseline','candidate']:
   ff=b/'images'/f'{tag}-{kind}.png';p.get_pixmap(matrix=fitz.Matrix(2.5,2.5),clip=fitz.Rect(q[kind])).save(ff);im=Image.open(ff).convert('RGB');ims.append(im)
  canvas=Image.new('RGB',(max(x.width for x in ims),sum(x.height for x in ims)+56),'#ddd');dr=ImageDraw.Draw(canvas);y=0
  for kind,im in zip(['BEFORE','CANDIDATE'],ims):dr.text((4,y+3),tag+' '+kind,fill='black');canvas.paste(im,(0,y+24));y+=im.height+28
  canvas.save(b/'images'/f'{tag}-pair.png');pairs.append((tag,canvas))
 for kind,values in [('source-contexts',strips),('pairs',pairs)]:
  for j in range(0,len(values),3):
   group=values[j:j+3];width=max(v.width for _,v in group);height=sum(v.height+30 for _,v in group);out=Image.new('RGB',(width,height),'#ddd');dr=ImageDraw.Draw(out);y=0
   for tag,im in group:dr.text((4,y+5),tag+' '+kind,fill='black');out.paste(im,(0,y+28));y+=im.height+30
   out.save(b/'images'/f'{name}-{kind}-{j//3+1}.png')
print('rendered 16 source contexts and candidate pairs')
