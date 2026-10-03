from pathlib import Path
from PIL import Image
import numpy as np, json, math, hashlib, collections, time
ROOT=Path('.build/brahms-spine-branches-2026-10-03');ROOT.mkdir(exist_ok=True)

def rle(mask,xoff=0,yoff=0):
 out=[]
 for y,row in enumerate(mask):
  changes=np.flatnonzero(np.diff(np.r_[False,row,False].astype(np.int8)))
  out.extend([[int(y+yoff),int(a+xoff),int(b+xoff)] for a,b in zip(changes[::2],changes[1::2])])
 return out

def graph(name,original,staff_lines,spine_columns,yspan,space,local_shifts=None,skew=0):
 h,w=original.shape;y0,y1=yspan
 # Keep all original source pixels in this full-width context. Each is in
 # exactly one graph payload; channels are hypotheses, never erased pixels.
 source=original[y0:y1].copy(); hh=y1-y0
 local_shifts=local_shifts or [0]*len(staff_lines)
 spine=np.zeros_like(source)
 for y in range(hh):
  l,r=spine_columns(y+y0)
  spine[y,max(0,l):min(w,r)]=source[y,max(0,l):min(w,r)]
 channels=[];line_union=np.zeros_like(source)
 thickness=max(0,round(space*.09)) # unchanged native staff-channel width
 for si,ys in enumerate(staff_lines):
  for li,y in enumerate(ys):
   mask=np.zeros_like(source)
   for x in range(w):
    yy=round(y+skew*(x-w/2)+local_shifts[si])-y0
    for dy in range(-thickness,thickness+1):
     if 0<=yy+dy<hh:mask[yy+dy,x]=source[yy+dy,x] and not spine[yy+dy,x]
   mask &= ~line_union
   channels.append({'id':f'line-{si}-{li}','staff':si,'line':li,'runs':rle(mask,0,y0),'pixelCount':int(mask.sum()),'role':'provisional-staff-line-with-possible-musical-overlap'})
   line_union|=mask
 residual=source&~spine&~line_union
 labels=np.full(source.shape,-1,np.int32);branches=[]
 for yy,xx in zip(*np.where(residual)):
  if labels[yy,xx]>=0:continue
  ident=len(branches);queue=collections.deque([(int(xx),int(yy))]);labels[yy,xx]=ident;pixels=[];touches=[];cut=False
  while queue:
   x,y=queue.popleft();pixels.append((x,y));cut |= y in [0,hh-1] or x in [0,w-1]
   for dy in [-1,0,1]:
    for dx in [-1,0,1]:
     nx,ny=x+dx,y+dy
     if nx<0 or nx>=w or ny<0 or ny>=hh:continue
     if spine[ny,nx]:touches.append((nx,ny+y0))
     if residual[ny,nx] and labels[ny,nx]<0:labels[ny,nx]=ident;queue.append((nx,ny))
  xs=[q[0] for q in pixels];ys=[q[1]+y0 for q in pixels]
  owners=[i for i,ls in enumerate(staff_lines) if min(ys)<=max(ls)+local_shifts[i] and max(ys)>=min(ls)+local_shifts[i]]
  branches.append({'id':ident,'role':'unresolved-source-branch','bounds':[min(xs),min(ys),max(xs)+1,max(ys)+1],'pixels':len(pixels),'contactsWithSpine':[list(p) for p in sorted(set(touches),key=lambda p:(p[1],p[0]))],'touchesContextBoundary':bool(cut),'geometricCoreContacts':owners,'runs':rle(labels==ident,0,y0)})
 assert np.array_equal(source,spine|line_union|residual)
 assert int(source.sum())==int(spine.sum())+int(line_union.sum())+sum(n['pixels'] for n in branches)
 attached=[b for b in branches if b['contactsWithSpine']]
 result={'id':name,'sourceShape':[w,h],'context':[0,y0,w,y1],'space':space,'sourcePixels':int(source.sum()),'spinePixels':int(spine.sum()),'staffChannelPixels':int(line_union.sum()),'branchPixels':int(residual.sum()),'sourcePayloadConserved':True,'spineRole':'candidate-structural-or-mixed-unknown','spineRuns':rle(spine,0,y0),'staffChannels':channels,'branches':branches,'attachedBranchIDs':[b['id'] for b in attached],'exclusiveStructuralOwnershipProved':False,'noUnexplainedDirectBranch':len(attached)==0,'note':'Zero unexplained branches would be necessary, not sufficient. Audit-seeded candidate spine and provisional staff channels are not an automatic musical classifier.'}
 (ROOT/(name+'-graph.json')).write_text(json.dumps(result,indent=2)+'\n')
 # All pixels keep their payload. Colors show data roles, not a rendered score.
 rgb=np.repeat(np.where(source,0,255)[:,:,None],3,axis=2).astype(np.uint8)
 rgb[line_union]=[180,180,180];rgb[spine]=[20,80,220]
 for b in attached:rgb[labels==b['id']]=[230,50,40]
 Image.fromarray(rgb).save(ROOT/(name+'-graph.png'))
 return {k:v for k,v in result.items() if k not in ['spineRuns','staffChannels','branches']}|{'attachedBranches':[{k:v for k,v in b.items() if k!='runs'} for b in attached]}

start=time.time();reports=[]
baseline=json.loads(Path('.build/residual9-endpoint-ownership-2026-10-03/baseline-actual.json').read_text())
paths=json.loads(Path('Tests/quality_control/residual9-boundary-source/surviving-paths.json').read_text())
for pn,ids,shifts in [(24,[6,7],[-2,-1]),(28,[0,1],[-1,0])]:
 p=baseline['pages'][pn-1];native=Path(f'.build/residual9-boundary-2026-10-03/agent-probe/page-{pn}-native-mask.pgm');a=np.array(Image.open(native))==0;h,w=a.shape
 ls=[np.array(next(s for s in p['staves'] if s['id']==i)['staffLineFractions'])*h for i in ids];space=min((l[-1]-l[0])/4 for l in ls);slope=math.tan(math.radians(p['analysisSkewDegrees']))
 bridge=next(x for x in paths if x['page']==pn)['bridges'][0];points=np.array(bridge['path']);m,b=np.polyfit(points[:,1],points[:,0],1)
 width=4 if pn==24 else 2 # measured physical stroke width from frozen audit
 def columns(y,m=m,b=b,width=width):
  left=round(m*y+b);return left,left+width
 shift=slope*(float(np.mean(points[:,0]))-w/2)
 span=[max(0,math.floor(ls[0][0]+shifts[0]+shift-space)),min(h,math.ceil(ls[-1][-1]+shifts[-1]+shift+space))]
 reports.append(graph(f'p{pn}',a,ls,columns,span,space,shifts,skew=slope))

lines=[[103,112,120,128,136],[178,186,194,202,210],[270,278,287,295,303],[344,352,361,369,377]]
for path in sorted(Path('Tests/quality_control/four-core-independent-2026-10-03/sources').glob('*.png')):
 if '-owner' in path.stem:continue
 a=np.array(Image.open(path).convert('L'))<190
 reports.append(graph('fourcore-'+path.stem,a,lines,lambda y:(500,502),[0,500],8.25))
for kind in ['filledOuter','hollowTiedOuter']:
 path=Path('Tests/quality_control/four-core-independent-2026-10-03/sources')/(kind+'-fiveMissingRows.png')
 a=np.array(Image.open(path).convert('L'))<190
 a[103:378,350:352]=True;a[103:378,600:602]=True
 Image.fromarray(np.where(a,0,255).astype(np.uint8)).save(ROOT/('network-'+kind+'-source.png'))
 reports.append(graph('network-'+kind,a,lines,lambda y:(500,502),[0,500],8.25))
(ROOT/'summary.json').write_text(json.dumps({'seconds':time.time()-start,'records':reports},indent=2)+'\n')
for r in reports:print(r['id'],'branches',len(r['attachedBranchIDs']),'source pixels',r['sourcePixels'],'attached bounds',[b['bounds'] for b in r['attachedBranches']])
