from pathlib import Path
import json,hashlib
from collections import deque
from PIL import Image,ImageDraw,ImageFont
import numpy as np
P=Path('.build/brahms-remaining-2026-10-03/upper-review');actual=json.loads(Path('.build/ownership-alternatives-2026-10-03/actual.json').read_text());results=[]
for pn in [28,31]:
 orig=np.asarray(Image.open(P/f'p{pn}-original-musical.pgm'))<190
 mask=np.asarray(Image.open(P/f'p{pn}-separated-musical.pgm'))<190
 h,w=mask.shape;page=actual['pages'][pn-1]
 rows=[c for c in page['inkComponents'] if 0 in c['staffIDs'] and 1 in c['staffIDs']]
 assert len(rows)==1;bound=rows[0]['bounds'];bbox=[round(bound[0]*w),round(bound[1]*h),round(bound[2]*w),round(bound[3]*h)]
 l,t,r,b=bbox
 # Independently flood the exact surviving source-connected pixels, not the metadata box.
 found=[];visited=set()
 for yy in range(t,b):
  for xx in range(l,r):
   if not mask[yy,xx] or (xx,yy) in visited:continue
   q=deque([(xx,yy)]);visited.add((xx,yy));pixels=[]
   while q:
    x,y=q.popleft();pixels.append((x,y))
    for dy in [-1,0,1]:
     for dx in [-1,0,1]:
      nx,ny=x+dx,y+dy
      if 0<=nx<w and 0<=ny<h and mask[ny,nx] and (nx,ny) not in visited:visited.add((nx,ny));q.append((nx,ny))
   bb=[min(x for x,y in pixels),min(y for x,y in pixels),max(x for x,y in pixels)+1,max(y for x,y in pixels)+1]
   if bb==bbox:found.append(pixels)
 assert len(found)==1,(pn,bbox,len(found));pixels=found[0];component=np.zeros(mask.shape,dtype=np.uint8)
 for x,y in pixels:component[y,x]=255
 Image.fromarray(component).save(P/f'p{pn}-causal-component-mask.png')
 lineRows=[[v*h for v in s['staffLineFractions']] for s in page['staves'][:4]]
 gap=(round(lineRows[0][4]+min((lineRows[0][4]-lineRows[0][0])/4,(lineRows[1][4]-lineRows[1][0])/4)*.6),round(lineRows[1][0]-min((lineRows[0][4]-lineRows[0][0])/4,(lineRows[1][4]-lineRows[1][0])/4)*.6))
 byrow=[]
 for y in range(t,b):
  xs=[x for x,yy in pixels if yy==y];runs=[]
  for x in sorted(xs):
   if runs and runs[-1][1]==x:runs[-1][1]=x+1
   else:runs.append([x,x+1])
  byrow.append({'y':y,'runs':runs,'totalInk':len(xs),'span':max(xs)-min(xs)+1})
 cuts= [242,142,252,173] if pn==28 else [1642,253,1653,309]
 modified=component.copy();modified[cuts[1]:cuts[3],cuts[0]:cuts[2]]=0
 seen=set();split=[]
 for x,y in pixels:
  if not modified[y,x] or (x,y) in seen:continue
  q=deque([(x,y)]);seen.add((x,y));part=[]
  while q:
   xx,yy=q.popleft();part.append((xx,yy))
   for dy in [-1,0,1]:
    for dx in [-1,0,1]:
     nx,ny=xx+dx,yy+dy
     if 0<=nx<w and 0<=ny<h and modified[ny,nx] and (nx,ny) not in seen:seen.add((nx,ny));q.append((nx,ny))
  bb=[min(xx for xx,yy in part),min(yy for xx,yy in part),max(xx for xx,yy in part)+1,max(yy for xx,yy in part)+1]
  owners=[i for i,lines in enumerate(lineRows) if bb[1]<=lines[4] and bb[3]>=lines[0]]
  split.append({'pixelBounds':bb,'ownersByUnchangedLineIntersection':owners,'pixels':len(part)})
 src=Image.open(f'.build/ownership-alternatives-2026-10-03/rasters/page-{pn}.png').convert('RGB');assert src.size==(w,h)
 crop=[200,75,290,240] if pn==28 else [1470,150,1670,450]
 im=src.crop(crop);mark=im.copy();ar=np.asarray(mark).copy();local=component[crop[1]:crop[3],crop[0]:crop[2]]>0;ar[local]=[200,0,140];mark=Image.fromarray(ar);sc=4
 sheet=Image.new('RGB',(im.width*sc*2,im.height*sc+35),'white');sheet.paste(im.resize((im.width*sc,im.height*sc),Image.Resampling.NEAREST),(0,35));sheet.paste(mark.resize((im.width*sc,im.height*sc),Image.Resampling.NEAREST),(im.width*sc,35));dr=ImageDraw.Draw(sheet);dr.text((4,6),f'p{pn}: untouched source | surviving ambiguous component in magenta',fill='black');sheet.save(P/f'p{pn}-source-component.png')
 r={'physicalPage':pn,'rasterSize':[w,h],'pdfSize':[page['pageWidth'],page['pageHeight']],'frozenComponent':rows[0],'exactRasterBounds':bbox,'pixels':len(pixels),'rowGeometry':byrow,'staffLineRows':lineRows,'gapRows':list(gap),'soleGapBridge':{'testedRectangle':cuts,'removedPixelCount':int(np.count_nonzero(component[cuts[1]:cuts[3],cuts[0]:cuts[2]])),'allCausalComponentPixelsInGapInsideRectangle':all(cuts[0]<=x<cuts[2] for x,y in pixels if gap[0]<=y<gap[1]),'remainingComponentsAfterDiagnosticRemoval':split,'diagnosticOnlyNoClassifierOrSourceEdit':True}}
 results.append(r)
(P/'causal-components.json').write_text(json.dumps(results,indent=2)+'\n')
for r in results:print({k:v for k,v in r.items() if k not in ['rowGeometry','staffLineRows']})
