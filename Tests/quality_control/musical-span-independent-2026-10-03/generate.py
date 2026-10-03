from pathlib import Path
from PIL import Image
import hashlib,json,math,shutil
import numpy as np
ROOT=Path('.build/musical-span-independent-2026-10-03');OUT=ROOT/'inputs';OUT.mkdir(exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest();cases=[]
def save(name,gray,masks,lines,padding,family,scales,allowed,meta=None,original=None,ownerOriginals=None,partPrefix='staff'):
 h,w=gray.shape;d=OUT/name;d.mkdir(exist_ok=True)
 if original and original.suffix=='.png':shutil.copy2(original,d/'source.png')
 else:Image.fromarray(gray).save(d/'source.png')
 if original:shutil.copy2(original,d/('original-source'+original.suffix))
 (d/'source.gray').write_bytes(gray.tobytes());owners=[]
 for i,mask in enumerate(masks):
  assert mask.shape==gray.shape and np.all(gray[mask]==0),(name,i)
  if ownerOriginals and ownerOriginals[i] is not None:
   old=ownerOriginals[i];shutil.copy2(old,d/(f'original-owner{i}'+old.suffix))
   if old.suffix=='.png':shutil.copy2(old,d/f'owner{i}.png')
   else:Image.fromarray(np.where(mask,0,255).astype('uint8')).save(d/f'owner{i}.png')
  else:Image.fromarray(np.where(mask,0,255).astype('uint8')).save(d/f'owner{i}.png')
  data=mask.astype('uint8').tobytes();(d/f'owner{i}.mask').write_bytes(data);yy,xx=np.where(mask)
  owners.append({'owner':i,'partID':partPrefix+str(i),'pixels':int(mask.sum()),'envelope':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],'maskRawSHA256':sha(data),'allowedWholeNeighborIDs':[x for x in allowed[i] if x!=i]})
 candidates=[{'id':i,'staffLineFractions':[y/h for y in ys],'topFraction':(ys[0]-padding[0])/h,'bottomFraction':(ys[-1]+padding[1])/h} for i,ys in enumerate(lines)]
 cases.append({'id':name,'family':family,'width':w,'height':h,'staffLines':lines,'scales':scales,'candidates':candidates,'sourceRawSHA256':sha(gray.tobytes()),'sourcePNGSHA256':sha((d/'source.png').read_bytes()),'owners':owners,'metadata':meta or {}})
# Original four-core sources and every owner mask are untouched.
orig=Path('Tests/quality_control/four-core-independent-2026-10-03/sources');lines4=[[103,112,120,128,136],[178,186,194,202,210],[270,278,287,295,303],[344,352,361,369,377]]
for p in sorted(orig.glob('*.png')):
 if '-owner' in p.stem:continue
 paths=[p.with_name(p.stem+f'-owner{i}.png') for i in range(4)];gray=np.array(Image.open(p).convert('L'));masks=[np.array(Image.open(q).convert('L'))==0 for q in paths]
 save('original-'+p.stem,gray,masks,lines4,[24,24],'original-mixed-four-core',[1],[[0,1],[0,1],[2],[3]],{'originalSource':str(p),'originalOwnerFiles':[str(q) for q in paths]},p,paths)
# Reproduce the unchanged case176 source constructor without calling an analyzer.
w,h=720,760;ink=np.full((h,w),255,np.uint8);owners=np.zeros((h,w),np.uint8)
def rect(x0,y0,x1,y1,bits=0):ink[y0:y1,x0:x1]=0;owners[y0:y1,x0:x1]|=bits
def oldhead(cx,cy,bits):
 for y in range(cy-4,cy+4):
  for x in range(cx-8,cx+8):
   if ((x-cx+.5)/8)**2+((y-cy+.5)/4)**2<=1:ink[y,x]=0;owners[y,x]|=bits
for i,top in enumerate([180,330,480]):
 for l in range(5):rect(40,top+12*l,603,top+12*l+1)
 x=160+70*i;rect(x,top-20,x+3,top+27,1<<i);oldhead(x-4,top+24,1<<i)
rect(40,180,43,529);rect(600,180,603,529,7);oldhead(601,184,7);oldhead(601,525,7);ink[217:225,600:603]=255;owners[217:225,600:603]=0
warped=np.full_like(ink,255);bits=np.zeros_like(owners)
for x in range(w):
 shift=math.floor(10*min(1,max(0,(x-360)/240))+.5)
 if shift:warped[shift:,x]=ink[:-shift,x];bits[shift:,x]=owners[:-shift,x]
 else:warped[:,x]=ink[:,x];bits[:,x]=owners[:,x]
old=Path('.build/brahms-numbered-lines-2026-10-03/candidate-v2');source=old/'case176-source.pgm';middle=old/'case176-middle-owner.pgm'
assert sha(source.read_bytes())=='049c67488a80a525c46e7c697fd01d41c3dc7cb903bccb2efd1b990fca0e89ab'
assert sha(middle.read_bytes())=='bd31b41d07d6904cd8b9cff8aa1ec535c8cf8a8cbb9987b709085ae5658d82a6'
assert np.array_equal(warped,np.array(Image.open(source)));masks=[(bits&(1<<i))!=0 for i in range(3)];assert np.array_equal(masks[1],np.array(Image.open(middle))==0)
oldcase=json.loads(Path('.build/ownership-alternatives-2026-10-03/results297.json').read_text())[176]
save('original-case176',warped,masks,[[t+12*l for l in range(5)] for t in [180,330,480]],[36,36],'original-case176',[1],[[0,1,2]]*3,{'originalConstructor':'.build/brahms-numbered-lines-2026-10-03/controls297.swift','originalSourcePGM':str(source),'originalMiddleOwnerPGM':str(middle),'middleOwnerFullRecoveryRequired':True,'requiredMiddleEnvelope':[218,190,609,539],'analysisAtScaleOne':'original image without extra redraw'},source,[None,middle,None],partPrefix='p')
for owner,target in zip(cases[-1]['owners'],oldcase['targets']):assert owner['envelope']==target['sourceEnvelope'],(owner,target)
# Fresh complementary sources: two genuine broken musical spans and six traps.
W,H=720,640;lines=[[t+12*i for i in range(5)] for t in [140,320,500]]
def fresh(kind):
 a=np.full((H,W),255,np.uint8);bits=np.zeros((H,W),np.uint8)
 def mark(x,y,owner=0):a[y,x]=0;bits[y,x]|=owner
 def r(x0,y0,x1,y1,owner=0):a[y0:y1,x0:x1]=0;bits[y0:y1,x0:x1]|=owner
 def head(cx,cy,hollow,owner):
  angle=-math.pi/6;c=math.cos(angle);s=math.sin(angle)
  for y in range(math.floor(cy-7),math.ceil(cy+7)+1):
   for x in range(math.floor(cx-9),math.ceil(cx+9)+1):
    dx=x+.5-cx;dy=y+.5-cy;u=dx*c+dy*s;v=-dx*s+dy*c
    if u*u/49+v*v/16<=1 and (not hollow or u*u/25+v*v/4>=1):mark(x,y,owner)
 for i,ys in enumerate(lines):
  for y in ys:r(40,y,650,y+1)
  x=160+70*i;r(x,ys[0]-20,x+3,ys[0]+27,1<<i);head(x-4,ys[0]+24,False,1<<i)
 r(40,140,43,549);r(620,140,623,549)
 is_music=kind.startswith('music-');hollow='hollow' in kind
 if is_music:
  r(500,148,503,541,7);head(507,148,hollow,7);head(494,540,hollow,7)
  for lo,hi in [(205,211),(349,352)]:a[lo:hi,500:503]=255;bits[lo:hi,500:503]=0
 else:
  r(500,140,503,549)
  if kind.startswith('staffline-'):
   for i,ys in enumerate(lines):
    r(492,ys[0]-16,494,ys[2]+1,1<<i);head(486,ys[2],hollow,1<<i)
   if kind.endswith('-broken'):
    for lo,hi in [(205,211),(349,352)]:a[lo:hi,500:503]=255
  elif kind=='detached-dynamic':
   r(487,202,489,224,1)
   for y in range(201,213):
    for x in range(487,497):
     d=((x+.5-491.5)/5)**2+((y+.5-207)/5)**2
     inner=((x+.5-491.5)/3)**2+((y+.5-207)/3)**2
     if d<=1 and inner>=1:mark(x,y,1)
  elif kind=='detached-sharp':
   r(486,202,488,222,1);r(493,199,495,219,1);r(483,207,497,209,1);r(483,214,497,216,1)
  else:raise ValueError(kind)
 # A negative's added notation has no non-staff-row path into the spine.
 if not is_music:
  guard=a[190:300,497:500];assert np.all(guard==255)
 return a,[(bits&(1<<i))!=0 for i in range(3)],is_music
for kind in ['music-filled','music-hollow','staffline-filled-intact','staffline-hollow-intact','staffline-filled-broken','staffline-hollow-broken','detached-dynamic','detached-sharp']:
 gray,masks,music=fresh(kind);allowed=[[0,1,2]]*3 if music else [[0],[1],[2]]
 save(kind,gray,masks,lines,[36,36],'new-musical-span' if music else 'new-no-shared-span',[.5,1],allowed,{'kind':kind,'musicalGapRuns':[[205,211],[349,352]] if music else [],'forbidSharedMusicalSpan':not music,'headStafflineOnly':kind.startswith('staffline-')})
assert len(cases)==21 and sum(len(c['scales']) for c in cases)==29 and sum(len(c['scales'])*len(c['owners']) for c in cases)==99
(OUT/'cases.json').write_text(json.dumps(cases,indent=2)+'\n');manifest={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in OUT.rglob('*') if p.is_file()};(ROOT/'input-manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
print('sources',len(cases),'source/scale observations',sum(len(c['scales']) for c in cases),'owner observations',sum(len(c['scales'])*len(c['owners']) for c in cases),'files',len(manifest))
