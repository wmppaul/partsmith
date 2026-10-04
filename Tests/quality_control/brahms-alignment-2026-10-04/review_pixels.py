from pathlib import Path
import json,hashlib
import pymupdf as f
import numpy as np
from PIL import Image,ImageDraw,ImageFont
r=Path('.build/brahms-alignment-2026-10-04')
reports=[]
for variant in ['before','after']:
 cases=json.loads((r/variant/'results.json').read_text())['cases']
 for case in cases:
  p=r/variant/(case['case']+'.pdf'); ref=p.with_name(p.stem+'-full-crop-reference.pdf')
  a=f.open(p);b=f.open(ref);rows=[]
  assert len(a)==len(b)==case['pageCount']
  for index,(ap,bp) in enumerate(zip(a,b)):
   import re
   def transforms(page):
    return re.findall(rb'q ([^qQ]*?) cm /Im1 Do',page.read_contents())
   actual=transforms(ap);reference=transforms(bp)
   assert actual==reference,(p,index,actual,reference)
   rows.append({'page':index+1,'sourceImageTransformsIdentical':True,'placements':len(actual)})
  reports.append({'variant':variant,'case':case['case'],'pages':rows})
  a[0].get_pixmap(matrix=f.Matrix(1.4,1.4),alpha=False).save(r/variant/(case['case']+'.png'))
(r/'source-transform-review.json').write_text(json.dumps(reports,indent=2)+'\n')
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20)
small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',15)
images=[]
for variant,title in [('before','Before: each crop centered separately'),('after','After: one source-coordinate frame')]:
 case=json.loads((r/variant/'results.json').read_text())['cases'][0]
 img=Image.open(r/variant/(case['case']+'.png')).convert('RGB')
 factor=1.4
 ybottom=int((792-min(p['destinationRect'][1] for p in case['placements']))*factor)+15
 cropped=img.crop((20,45,img.width-20,ybottom))
 pane=Image.new('RGB',(cropped.width,cropped.height+75),'white');pane.paste(cropped,(0,75));draw=ImageDraw.Draw(pane)
 draw.text((12,8),title,fill='#172338',font=font)
 draw.text((12,36),'Same 1.05× scale; all four systems from source page 3',fill='#344055',font=small)
 first=case['placements'][0];anchor=(first['sourceX0OutputX']+35*first['renderScale'])*factor-20
 for y in range(75,pane.height,8):draw.line((anchor,y,anchor,min(y+3,pane.height)),fill='#bf6526',width=1)
 images.append(pane)
canvas=Image.new('RGB',(sum(im.width for im in images)+20,max(im.height for im in images)),'#dce2e9');x=0
for im in images:canvas.paste(im,(x,0));x+=im.width+20
canvas.save(r/'alignment-comparison.png')
print('PDF source image transform checks',len(reports),'cases',sum(len(x['pages']) for x in reports),'pages: all identical')
for variant in ['before','after']:
 print(variant)
 for case in json.loads((r/variant/'results.json').read_text())['cases']:
  print(case['case'],'scale',case['appliedScale'],'shift',case['sameSourceXTransformSpread'],'gaps',case['realizedGaps'],'pages',case['pageCount'])
