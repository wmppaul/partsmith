from pathlib import Path
from PIL import Image
import hashlib,json,math
import numpy as np
R=Path('.build/musical-span-attached-addendum-2026-10-03');O=R/'inputs';O.mkdir(exist_ok=True)
W,H=720,640;lines=[[t+12*i for i in range(5)]for t in [140,320,500]];cases=[]
sha=lambda b:hashlib.sha256(b).hexdigest()
for name in ['three-filled-heads','attached-pp-context','attached-flat-context']:
 a=np.full((H,W),255,np.uint8);bits=np.zeros((H,W),np.uint8)
 def rect(x0,y0,x1,y1,own=0):a[y0:y1,x0:x1]=0;bits[y0:y1,x0:x1]|=own
 def ink(x,y,own):a[y,x]=0;bits[y,x]|=own
 def ellipse(cx,cy,rx,ry,own,hollow=False,angle=-math.pi/6):
  c=math.cos(angle);s=math.sin(angle)
  for y in range(math.floor(cy-rx-2),math.ceil(cy+rx+2)):
   for x in range(math.floor(cx-rx-2),math.ceil(cx+rx+2)):
    dx=x+.5-cx;dy=y+.5-cy;u=dx*c+dy*s;v=-dx*s+dy*c
    outer=u*u/rx**2+v*v/ry**2
    inner=u*u/max(1,rx-2)**2+v*v/max(1,ry-2)**2
    if outer<=1 and(not hollow or inner>=1):ink(x,y,own)
 for i,ys in enumerate(lines):
  for y in ys:rect(40,y,650,y+1)
  x=160+70*i;rect(x,ys[0]-20,x+3,ys[0]+27,1<<i);ellipse(x-4,ys[0]+24,7,4,1<<i)
 rect(40,140,43,549);rect(620,140,623,549)
 if name=='three-filled-heads':
  rect(500,148,503,541,7)
  ellipse(507,148,7,4,7);ellipse(494,344,7,4,7);ellipse(494,540,7,4,7)
  for lo,hi in [(205,211),(349,352)]:a[lo:hi,500:503]=255;bits[lo:hi,500:503]=0
 elif name=='attached-pp-context':
  rect(500,140,503,559)
  def p(cx,cy,owner):
   rect(cx-5,cy-6,cx-3,cy+17,owner)
   ellipse(cx,cy,6,6,owner,True,0)
   rect(cx-6,cy-6,cx-2,cy-4,owner)
  for cy,own in [(201,1),(549,4)]:
   p(480,cy,own);p(496,cy,own)
 elif name=='attached-flat-context':
  rect(500,140,503,549)
  for cy,own in [(180,1),(540,4)]:
   rect(493,cy-25,495,cy+7,own)
   ellipse(497,cy,6,6,own,True,-math.pi/6)
   rect(493,cy+4,496,cy+6,own)
   # A separate note at the same height makes the preceding accidental's
   # contextual role visible; its local stem never joins the long spine.
   ellipse(529,cy,7,4,own);rect(534,cy-24,536,cy+1,own)
 masks=[(bits&(1<<i))!=0 for i in range(3)];d=O/name;d.mkdir(exist_ok=True);Image.fromarray(a).save(d/'source.png');(d/'source.gray').write_bytes(a.tobytes())
 owners=[]
 for i,m in enumerate(masks):
  assert np.all(a[m]==0);data=m.astype('uint8').tobytes();(d/f'owner{i}.mask').write_bytes(data);Image.fromarray(np.where(m,0,255).astype('uint8')).save(d/f'owner{i}.png');ys,xs=np.where(m)
  owners.append({'owner':i,'partID':'staff'+str(i),'pixels':int(m.sum()),'envelope':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],'maskRawSHA256':sha(data),'allowedWholeNeighborIDs':[j for j in range(3)if j!=i]if name=='three-filled-heads'else[]})
 candidates=[{'id':i,'staffLineFractions':[y/H for y in ys],'topFraction':(ys[0]-36)/H,'bottomFraction':(ys[-1]+36)/H}for i,ys in enumerate(lines)]
 cases.append({'id':name,'family':'new-musical-span'if name=='three-filled-heads'else'new-no-shared-span','width':W,'height':H,'staffLines':lines,'scales':[.5,1],'candidates':candidates,'sourceRawSHA256':sha(a.tobytes()),'owners':owners})
(O/'cases.json').write_text(json.dumps(cases,indent=2)+'\n')
(R/'input-manifest.json').write_text(json.dumps({str(p.relative_to(R)):sha(p.read_bytes())for p in sorted(O.rglob('*'))if p.is_file()},indent=2)+'\n')
print([(c['id'],[o['pixels']for o in c['owners']])for c in cases])
