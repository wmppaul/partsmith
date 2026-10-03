from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont
W=Path(__file__).resolve().parent; I=Path('Tests/quality_control/terminal-body-independent-2026-10-03').resolve();O=W/'fixed-source-review';O.mkdir(exist_ok=True)
font=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',16)
sets={False:({x['name']:x for x in json.loads((I/'baseline-results.json').read_text())},{x['name']:x for x in json.loads((W/'results180.json').read_text())}),True:({x['name']:x for x in json.loads((I/'tied-baseline-results.json').read_text())},{x['name']:x for x in json.loads((W/'results36.json').read_text())})}
cases=[('filledOuter-rotated-r0.5',False,'Repaired filled body'),('hollowOuter-straight-r1.0',False,'Repaired hollow body'),('filledIncomingTie-bowed-r1.0',True,'Repaired head with incoming tie'),('filledStemInterrupted-straight-r1.0',False,'Unresolved interrupted stem'),('hollowOuter-straight-r0.5',False,'Unresolved half-resolution hollow head')]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();records=[]
for name,tied,verdict in cases:
 old,new=(s[name]for s in sets[tied]);src=Image.open(old['sourceImage']).convert('RGB');assert sha(old['sourceImage'])==sha(new['sourceImage']); a=np.array(src);h,w=a.shape[:2]
 canv=Image.new('RGB',(3*w,2*(h+68)+45),'white');d=ImageDraw.Draw(canv);d.text((8,8),name+' — '+verdict,font=font,fill='black'); rows=[]
 for owner in range(2):
  maskpath=old['ownerMasks'][owner];assert sha(maskpath)==sha(new['ownerMasks'][owner]);m=np.array(Image.open(maskpath).convert('L'))<190;ybase=45+owner*(h+68)
  yy,xx=np.indices((h,w));row={'owner':owner,'sourceMask':maskpath,'sourceMaskSHA256':sha(maskpath),'before':old['targets'][owner],'after':new['targets'][owner]}
  for col,(label,result)in enumerate([('SOURCE OWNED PIXELS',None),('BASELINE',old['targets'][owner]),('CANDIDATE',new['targets'][owner])]):
   pixels=a.copy();pixels[m]=[15,95,190]
   if result:
    x0,y0,x1,y1=result['crop'];outside=(xx<x0-1e-9)|(yy<y0-1e-9)|(xx+1>x1+1e-9)|(yy+1>y1+1e-9);lost=m&outside;assert int(lost.sum())==result['sourcePixelsOutsideCrop'];pixels[lost]=[220,15,35]
    title=f"{label}: owner {owner}, missing {int(lost.sum())} pixels"
   else:title=f"{label}: owner {owner}, {int(m.sum())} pixels"
   d.text((col*w+8,ybase+4),title,font=font,fill='black')
   d.text((col*w+8,ybase+26),'Blue = source target; red = outside crop'if result else'Original score context retained in black',font=font,fill='#444444')
   canv.paste(Image.fromarray(pixels),(col*w,ybase+64))
   if result:
    d.rectangle((col*w+x0,ybase+64+y0,col*w+min(w-1,x1),ybase+64+min(h-1,y1)),outline='#00a888',width=3)
  rows.append(row)
 out=O/(name+'.png');canv.save(out)
 records.append({'name':name,'finding':verdict,'usesTiedSupplement':tied,'sourceImage':old['sourceImage'],'sourceImageSHA256':sha(old['sourceImage']),'analysisImageSize':new['analysisImageSize'],'sourceSize':[w,h],'rows':rows,'reviewImage':str(out),'reviewImageSHA256':sha(out)})
(O/'index.json').write_text(json.dumps(records,indent=2)+'\n');print('Rendered five unchanged source/mask comparisons with exact lost-pixel assertions')
