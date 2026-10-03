from pathlib import Path
from PIL import Image
import numpy as np,json,math,collections
r=Path('.build/residual9-boundary-2026-10-03/agent-probe');out=Path('Tests/quality_control/residual9-boundary-source');old=Path('.build/residual9-endpoint-ownership-2026-10-03');base=json.loads((old/'baseline-actual.json').read_text());logs=[json.loads(l) for l in (r/'trace.jsonl').read_text().splitlines()];records=[]
for pn,ids in [(24,[6,7]),(28,[0,1]),(29,[0,1]),(31,[0,1]),(35,[0,1])]:
 p=base['pages'][pn-1];im=Image.open(old/'rasters'/f'page-{pn}.png').convert('RGB');a=np.array(Image.open(r/f'page-{pn}-separated-mask.pgm'))==0;h,w=a.shape
 ls=[np.array(next(s for s in p['staves'] if s['id']==i)['staffLineFractions'])*h for i in ids];space=min((v[-1]-v[0])/4 for v in ls);y0=round(ls[0][-1]+space*.6);y1=round(ls[1][0]-space*.6)-1
 strip=a[y0:y1+1].copy();seen=np.zeros(strip.shape,bool);bridges=[]
 for yy,xx in zip(*np.where(strip)):
  if seen[yy,xx]:continue
  queue=collections.deque([(int(xx),int(yy))]);seen[yy,xx]=True;pixels=[]
  while queue:
   x,y=queue.popleft();pixels.append((x,y))
   for dx in [-1,0,1]:
    for dy in [-1,0,1]:
     nx,ny=x+dx,y+dy
     if 0<=nx<w and 0<=ny<strip.shape[0] and strip[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;queue.append((nx,ny))
  if min(t[1] for t in pixels)!=0 or max(t[1] for t in pixels)!=strip.shape[0]-1:continue
  xs=[v[0] for v in pixels];bbox=[min(xs),y0,max(xs)+1,y1+1];nodes=set(pixels);queue=collections.deque([q for q in pixels if q[1]==0]);parent={q:None for q in queue};goal=None
  while queue:
   q=queue.popleft();x,y=q
   if y==strip.shape[0]-1:goal=q;break
   for dx in [-1,0,1]:
    for dy in [-1,0,1]:
     n=x+dx,y+dy
     if n in nodes and n not in parent:parent[n]=q;queue.append(n)
  path=[]
  while goal is not None:path.append([goal[0],goal[1]+y0]);goal=parent[goal]
  path.reverse();allRows=[]
  for yy in range(strip.shape[0]):
   xx=[x for x,y in pixels if y==yy];allRows.append({'y':yy+y0,'minX':min(xx),'maxX':max(xx),'span':max(xx)-min(xx)+1,'inkPixels':len(xx)})
  match=[v for v in logs if v.get('page')==pn and v.get('event')=='gap' and v['connector'][0]-3<=sum(t[0] for t in path)/len(path)<=v['connector'][1]+3]
  clip=(max(0,bbox[0]-round(space*3)),max(0,round(ls[0][0]-space*1.5)),min(w,bbox[2]+round(space*3)),min(h,round(ls[1][-1]+space*1.5)))
  name=f'p{pn}-surviving-link-{len(bridges)+1}';im.crop(clip).resize(((clip[2]-clip[0])*3,(clip[3]-clip[1])*3)).save(out/(name+'-source.png'))
  mask=Image.open(r/f'page-{pn}-separated-mask.pgm');mask.crop(clip).resize(((clip[2]-clip[0])*3,(clip[3]-clip[1])*3),resample=Image.Resampling.NEAREST).save(out/(name+'-analysis.png'))
  bridges.append({'bounds':bbox,'area':len(pixels),'path':path,'rows':allRows,'sourceClip':list(clip),'sourceImage':name+'-source.png','analysisImage':name+'-analysis.png','matchingConnector':[v['connector'] for v in match]})
 records.append({'page':pn,'staffIDs':ids,'rasterSize':[w,h],'staffSpace':space,'gapRowsInclusive':[y0,y1],'bridges':bridges})
 print(pn,[(b['bounds'],len(b['path']),b['matchingConnector']) for b in bridges])
(out/'surviving-paths.json').write_text(json.dumps(records,indent=2)+'\n')
# Summarize exact production gate measurements for each causal connector.
summary=[]
for record in records:
 for bridge in record['bridges']:
  for connector in bridge['matchingConnector']:
   events=[v for v in logs if v.get('page')==record['page'] and v.get('connector')==connector]
   rs=[]
   for event in events:
    if event['event']=='tracker-segment' and not event['reachableAfter']:
     candidates=event['candidates'];best=max(candidates,key=lambda c:(c['weakest'],c['sum'])) if candidates else None
     rs.append({'event':'tracker-failure-detail','staff':event['staff'],'center':event['center'],'segment':event['segment'],'count':event['count'],'bestStillFailing':best,'reachableBefore':event['reachableBefore'],'flankLength':event['flankLength']})
    elif event['event'] not in ['tracker-segment','local-shift']:rs.append(event)
    elif event['event']=='local-shift':
     best=max(event['candidates'],key=lambda c:(c['weakest'],c['sum']));rs.append({'event':'local-shift-summary','staff':event['staff'],'acceptedBest':event['acceptedBest'],'bestMinSupport':best,'flanks':event['flanks']})
   summary.append({'page':record['page'],'connector':connector,'survivingPathBounds':bridge['bounds'],'measurements':rs})
(out/'causal-gate-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
