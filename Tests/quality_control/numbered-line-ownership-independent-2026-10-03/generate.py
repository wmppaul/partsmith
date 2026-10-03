from pathlib import Path
from PIL import Image
import hashlib,json,math,shutil
import numpy as np
ROOT=Path('.build/numbered-line-ownership-independent-2026-10-03');OUT=ROOT/'inputs';OUT.mkdir(exist_ok=True)
W,H=720,500;LINES=[[103,112,120,128,136],[178,186,194,202,210],[270,278,287,295,303],[344,352,361,369,377]]
sha=lambda b:hashlib.sha256(b).hexdigest()
cases=[]
def save_case(name,gray,masks,family,scales,meta=None,png_source=None,png_masks=None):
 d=OUT/name;d.mkdir(exist_ok=True)
 if png_source:shutil.copy2(png_source,d/'source.png')
 else:Image.fromarray(gray).save(d/'source.png')
 (d/'source.gray').write_bytes(gray.tobytes())
 ownerinfo=[]
 for i,m in enumerate(masks):
  assert np.all(gray[m]==0),(name,i,'owner pixels not source ink')
  if png_masks:shutil.copy2(png_masks[i],d/f'owner{i}.png')
  else:Image.fromarray(np.where(m,0,255).astype('uint8')).save(d/f'owner{i}.png')
  (d/f'owner{i}.mask').write_bytes(m.astype('uint8').tobytes())
  yy,xx=np.where(m);ownerinfo.append({'owner':i,'partID':f'staff{i}','pixels':int(m.sum()),'envelope':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],'maskRawSHA256':sha(m.astype('uint8').tobytes()),'maskPNGSHA256':sha((d/f'owner{i}.png').read_bytes())})
 cases.append({'id':name,'family':family,'width':W,'height':H,'staffLines':LINES,'scales':scales,'sourceRawSHA256':sha(gray.tobytes()),'sourcePNGSHA256':sha((d/'source.png').read_bytes()),'owners':ownerinfo,'metadata':meta or {}})
original=Path('Tests/quality_control/four-core-independent-2026-10-03/sources')
for p in sorted(original.glob('*.png')):
 if '-owner' in p.stem:continue
 paths=[p.with_name(p.stem+f'-owner{i}.png') for i in range(4)]
 gray=np.array(Image.open(p).convert('L'));masks=[np.array(Image.open(q).convert('L'))==0 for q in paths]
 save_case('original-'+p.stem,gray,masks,'original-musical',[1.0],{'originalSource':str(p),'originalOwnerFiles':[str(q) for q in paths]},p,paths)

def fresh(kind,line=0):
 gray=np.full((H,W),255,np.uint8);bits=np.zeros((H,W),np.uint8)
 def mark(x,y,owner=0):
  if 0<=x<W and 0<=y<H:gray[y,x]=0;bits[y,x]|=owner
 def rect(x0,y0,x1,y1,owner=0):
  for y in range(y0,y1):
   for x in range(x0,x1):mark(x,y,owner)
 def head(cx,cy,hollow,owner):
  a=-math.pi/6;c=math.cos(a);s=math.sin(a)
  for y in range(math.floor(cy-7),math.ceil(cy+7)+1):
   for x in range(math.floor(cx-9),math.ceil(cx+9)+1):
    dx=x+.5-cx;dy=y+.5-cy;u=dx*c+dy*s;v=-dx*s+dy*c
    if u*u/49+v*v/16<=1 and (not hollow or u*u/25+v*v/4>=1):mark(x,y,owner)
 def tie(x0,x1,y0,height,owner):
  for x in range(x0,x1+1):
   t=(x-x0)/(x1-x0);y=math.floor(y0+height*4*t*(1-t)+.5)
   mark(x,y,owner);mark(x,y+1,owner)
 for i,staff in enumerate(LINES):
  for y in staff:rect(40,y,650,y+1)
  x=150+i*50;rect(x,staff[0]-14,x+2,staff[0]+23,1<<i);head(x-4,staff[0]+22,False,1<<i)
 rect(40,LINES[0][0],43,LINES[3][4]+1)
 for x in [350,500,600]:rect(x,LINES[0][0],x+2,LINES[3][4]+1)
 meta={}
 if kind in ['filled','hollow']:
  upper=LINES[0][line];lower=LINES[1][4-line]
  rect(500,upper,502,lower+1,3);head(505,upper,kind=='hollow',3);head(495,lower,kind=='hollow',3)
  if line in [1,3]:tie(507,579,upper,-12,3)
  contact=np.zeros((H,W),bool)
  for y in sum(LINES,[]):contact[y,:]=True
  meta={'headStyle':kind,'upperLineIndex':line,'lowerLineIndex':4-line,'sharedOwners':[0,1],'musicalPixelsExactlyOnNumberedLines':int(((bits&3)!=0)[contact].sum()),'tie':line in [1,3]}
 else:
  for i,staff in enumerate(LINES):
   rect(460,staff[0]-14,462,staff[2]+1,1<<i);head(456,staff[2],i%2==1,1<<i);tie(463,482,staff[3],5,1<<i)
  if kind=='double':rect(506,LINES[0][0],508,LINES[3][4]+1)
  if kind=='oneGapPerJunction':
   for staff in LINES:
    for y in staff:gray[y+2,500:502]=255
  if kind=='bowedLines':
   oldg=gray.copy();oldb=bits.copy();gray[:]=255;bits[:]=0
   for x in range(W):
    shift=math.floor(3*max(0,min(1,(x-360)/220))+.5)
    if shift:gray[shift:,x]=oldg[:-shift,x];bits[shift:,x]=oldb[:-shift,x]
    else:gray[:,x]=oldg[:,x];bits[:,x]=oldb[:,x]
  meta={'variant':kind,'ownedSpinePixels':int((bits[:,500:508]!=0).sum()),'boundaryColumns':[350,500,600]}
 return gray,[(bits&(1<<i))!=0 for i in range(4)],meta
for kind in ['filled','hollow']:
 for line in [0,1,3,4]:
  gray,masks,meta=fresh(kind,line);save_case(f'contact-{kind}-line{line+1}',gray,masks,'new-musical',[.5,1,1.5],meta)
for kind in ['single','double','oneGapPerJunction','bowedLines']:
 gray,masks,meta=fresh(kind);save_case(f'structural-{kind}',gray,masks,'new-structural',[.5,1,1.5],meta)
assert len(cases)==24
(OUT/'cases.json').write_text(json.dumps(cases,indent=2)+'\n')
files={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in OUT.rglob('*') if p.is_file()}
(ROOT/'input-manifest.json').write_text(json.dumps(files,indent=2,sort_keys=True)+'\n')
print('source images',len(cases),'owner masks',sum(len(c['owners']) for c in cases),'planned source/scale cases',sum(len(c['scales']) for c in cases),'files',len(files))
