from pathlib import Path
import json,math,hashlib
from PIL import Image,ImageDraw,ImageFont
W=Path(__file__).resolve().parent; O=W/'real-source-review';records=[]
for r in json.loads((W/'diagnostic-output/witnesses.json').read_text()):
 assert r['componentsEqualFrozenMultiset'];im=Image.open(r['imagePath']).convert('RGB');iw,ih=im.size
 for i,p in enumerate(r['endpointWitnesses']):
  cx,cy=p['center'];rx,ry=p['radii'];rad=p['space']*3;box=[max(0,int(cx-rad)),max(0,int(cy-rad)),min(iw,int(cx+rad)+1),min(ih,int(cy+rad)+1)];crop=im.crop(box);a=crop.resize((crop.width*6,crop.height*6),Image.Resampling.NEAREST); b=a.copy();d=ImageDraw.Draw(b);angle=p['angleDegrees']*math.pi/180;c=math.cos(angle);s=math.sin(angle);pts=[]
  for j in range(101):
   t=j*2*math.pi/100;u=rx*math.cos(t);v=ry*math.sin(t);pts.append(((cx+u*c-v*s-box[0])*6,(cy+u*s+v*c-box[1])*6))
  d.line(pts,fill='red',width=2)
  for x in p['stroke']:d.line(((x-box[0])*6,0,(x-box[0])*6,b.height),fill='#0055aa',width=1)
  panel=Image.new('RGB',(a.width*2,a.height+35),'white');panel.paste(a,(0,35));panel.paste(b,(a.width,35));d=ImageDraw.Draw(panel);d.text((8,8),'Untouched source pixels',fill='black');d.text((a.width+8,8),'Fit: ellipse red; proposed spine blue',fill='black');out=O/(r['id'].replace(':','-')+'-endpoint'+str(i)+'.png');panel.save(out)
  records.append({'id':r['id'],'witness':p,'sourceBox':box,'image':str(out),'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
(O/'endpoint-witnesses.json').write_text(json.dumps(records,indent=2)+'\n')
