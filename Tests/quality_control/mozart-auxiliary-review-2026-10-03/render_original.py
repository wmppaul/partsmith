from pathlib import Path
import pymupdf as fitz
from PIL import Image,ImageOps,ImageDraw
base=Path('.build/mozart-auxiliary-review-2026-10-03')
doc=fitz.open('sample_scores/medium_skewed/01_mozart_piano_quartet_k478_imslp_86903.pdf')
(base/'original-pages').mkdir(exist_ok=True)
for i,p in enumerate(doc):
 p.get_pixmap(matrix=fitz.Matrix(2,2)).save(base/'original-pages'/f'p{i+1:02}.png')
for start in range(0,len(doc),6):
 canvas=Image.new('RGB',(1800,1750),'#dddddd');draw=ImageDraw.Draw(canvas)
 for j in range(6):
  idx=start+j
  if idx>=len(doc):break
  im=Image.open(base/'original-pages'/f'p{idx+1:02}.png').convert('RGB')
  im.thumbnail((590,840))
  x=(j%3)*600;y=(j//3)*875
  canvas.paste(im,(x,y+30));draw.text((x+8,y+7),f'ORIGINAL SOURCE — physical page {idx+1}',fill='black')
 canvas.save(base/f'original-contact-{start+1:02}-{min(start+6,len(doc)):02}.png')
print('rendered 30 original pages, 5 source contacts')
