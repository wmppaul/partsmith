from pathlib import Path
from collections import deque,Counter
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw
p=Path('.build/p31-spine-provenance-2026-10-03'); raw=Path('.build/ownership-alternatives-2026-10-03/rasters/page-31.png')
source=Image.open(raw).convert('RGB');mask=np.asarray(Image.open(p/'p31-separated.pgm'))<190;original=np.asarray(Image.open(p/'p31-original.pgm'))<190
h,w=mask.shape;comp=np.zeros_like(mask);q=deque([(1649,200)]);comp[200,1649]=True
while q:
 x,y=q.popleft()
 for dy in [-1,0,1]:
  for dx in [-1,0,1]:
   nx,ny=x+dx,y+dy
   if 0<=nx<w and 0<=ny<h and mask[ny,nx] and not comp[ny,nx]:comp[ny,nx]=True;q.append((nx,ny))
ys,xs=np.where(comp);bbox=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];assert bbox==[1641,200,1651,350] and len(xs)==448
rows=[]
for y in range(200,350):
 xx=np.where(comp[y])[0];rows.append({'y':y,'left':int(xx.min()),'right':int(xx.max()+1),'pixels':int(len(xx))})
# A source-only geometric bridge, deliberately inside the real white interstaff gap.
bridge=[1638,270,1658,309]; region=original[270:309,1638:1658]
rr=[]
for y in range(270,309):
 xx=np.where(original[y])[0];inside=xx[(xx>=1638)&(xx<1658)];other=xx[xx<1638]
 rr.append({'y':y,'spineLeft':int(inside.min()),'spineRight':int(inside.max()+1),'spinePixelCount':len(inside),'nearestOtherSourceInkToLeft':int(other.max()) if len(other) else None,'whiteColumnsToLeft':int(inside.min()-other.max()-1) if len(other) else None})
# Untouched scan window; grid coordinates are native raster coordinates, not source edits.
clip=(1540,178,1670,405);sc=5;im=source.crop(clip).resize(((clip[2]-clip[0])*sc,(clip[3]-clip[1])*sc),Image.Resampling.NEAREST);out=Image.new('RGB',(im.width+120,im.height+70),'white');out.paste(im,(85,40));d=ImageDraw.Draw(out);d.text((5,5),'P31 right boundary: untouched native source; x/y native pixels',fill='black')
for y in range(180,401,10):
 yy=40+(y-clip[1])*sc;d.text((5,yy-5),str(y),fill='black');d.line([(75,yy),(84,yy)],fill='black')
for x in range(1540,1670,20):
 xx=85+(x-clip[0])*sc;d.text((xx-10,22),str(x),fill='black');d.line([(xx,34),(xx,39)],fill='black')
out.save(p/'native-right-boundary-grid.png')
# Isolated component overlay does not remove source ink.
clip=(1430,170,1680,455);sc=3;im=source.crop(clip);ar=np.asarray(im).copy();ar[comp[clip[1]:clip[3],clip[0]:clip[2]]]=[220,0,160]
a=Image.new('RGB',(im.width*sc*2,im.height*sc+36),'white');a.paste(im.resize((im.width*sc,im.height*sc),Image.Resampling.NEAREST),(0,36));a.paste(Image.fromarray(ar).resize((im.width*sc,im.height*sc),Image.Resampling.NEAREST),(im.width*sc,36));ImageDraw.Draw(a).text((5,8),'Untouched source | exact 448-pixel shared component overlaid in magenta',fill='black');a.save(p/'exact-component-context.png')
summary={'rasterSHA256':hashlib.sha256(raw.read_bytes()).hexdigest(),'componentBBox':bbox,'componentPDFPoints':[bbox[0]*427/w,bbox[1]*615/h,bbox[2]*427/w,bbox[3]*615/h],'componentPixels':len(xs),'componentType':'ordinary shared, not ownership alternative','componentRowSpanCounts':dict(Counter(x['right']-x['left'] for x in rows)),'rows':rows,'sourceOnlyInteriorBridge':{'nativeRectangle':bridge,'pdfRectangle':[bridge[0]*427/w,bridge[1]*615/h,bridge[2]*427/w,bridge[3]*615/h],'rows':rr,'minimumBlankColumnsToOtherInkLeft':min(x['whiteColumnsToLeft'] for x in rr if x['whiteColumnsToLeft'] is not None),'all39RowsNonempty':all(x['spinePixelCount']>0 for x in rr)},'sourceWarning':'Geometric isolation of this bridge does not prove that an arbitrary thin line is structural; source semantics and branch preservation remain required. This diagnostic does not alter output or masks.'}
(p/'measurements.json').write_text(json.dumps(summary,indent=2)+'\n')
print({k:v for k,v in summary.items() if k not in ['rows','sourceOnlyInteriorBridge']});print('bridge minimum whitespace',summary['sourceOnlyInteriorBridge']['minimumBlankColumnsToOtherInkLeft']);print('gap widths',dict(Counter(x['spinePixelCount'] for x in rr)))
