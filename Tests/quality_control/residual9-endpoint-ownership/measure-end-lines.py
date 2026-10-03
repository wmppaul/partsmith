from pathlib import Path
import numpy as np,json,math
from PIL import Image,ImageDraw
r=Path('.build/residual9-endpoint-ownership-2026-10-03');d=Path('Tests/quality_control/residual9-endpoint-ownership');base=json.loads((r/'baseline-actual.json').read_text());records=[]
for pn,ids in [(24,[6,7]),(28,[0,1]),(29,[0,1]),(31,[0,1]),(35,[0,1])]:
 p=base['pages'][pn-1];im=Image.open(r/'rasters'/f'page-{pn}.png').convert('RGB');a=np.array(im.convert('L'))<190;h,w=a.shape
 staves=[s for s in p['staves'] if s['id'] in ids];lines=[np.array(s['staffLineFractions'])*h for s in staves];space=min((v[-1]-v[0])/4 for v in lines);slope=math.tan(math.radians(p['analysisSkewDegrees']))
 y0=round(lines[0][-1]+space);y1=round(lines[1][0]-space);occ=a[y0:y1].mean(axis=0);eligible=np.where(occ>.55)[0];eligible=eligible[eligible>w*.8];x=int(eligible[-1]);left=slice(x-round(space*1.1),x-round(space*.25));right=slice(x+round(space*.5),x+round(space*1.4));center=(left.start+left.stop)/2
 staffrecords=[];draw=ImageDraw.Draw(im)
 for s,ls in zip(staves,lines):
  pred=ls+slope*(x-w/2);profile=a[:,left].mean(axis=1)
  best=None
  for shift in range(-round(space),round(space*3)+1):
   selected=[];scores=[]
   for v in pred+shift:
    allowed=np.arange(max(0,round(v-space*.22)),min(h,round(v+space*.22)+1));win=allowed[np.argmax(profile[allowed])];selected.append(int(win));scores.append(float(profile[win]))
   if any(not .65*space <= b-a <=1.4*space for a,b in zip(selected,selected[1:])):continue
   score=sum(scores)-.0001*abs(shift)
   if best is None or score>best[0]:best=(score,shift,selected,scores)
  _,shift,selected,scores=best;details=[]
  for i,(v,y,support) in enumerate(zip(pred,selected,scores)):
   detail={'line':i+1,'predictedRasterY':float(v),'localPeakRasterY':y,'leftSupport':support,'rightSupportAtPeak':float(a[y,right].mean()),'deltaInStaffSpaces':float((y-v)/space)};details.append(detail)
   draw.line((x-40,round(v),x+5,round(v)),fill=(0,90,255),width=1);draw.line((x-35,y,x+10,y),fill=(255,100,0),width=1)
  staffrecords.append({'staffID':s['id'],'templateShift':shift,'measurements':details})
 top=round(lines[0][0]-space*1.5);bottom=round(lines[1][-1]+space*3);crop=im.crop((x-round(space*6),top,x+round(space*3),bottom));crop=crop.resize((crop.width*3,crop.height*3));path=d/f'p{pn}-endpoint-line-probe.png';crop.save(path)
 records.append({'sourcePage':pn,'image':str(r/'rasters'/f'page-{pn}.png'),'rasterSize':[w,h],'sourceBarlineX':x,'staffSpacePixels':space,'leftProbeColumns':[left.start,left.stop],'rightProbeColumns':[right.start,right.stop],'staves':staffrecords,'overlay':str(path),'caveat':'Diagnostic local peak fit, visually cross-checked on original source; not an independently certified line tracker or a production cut rule.'})
(d/'per-line-endpoint-probe.json').write_text(json.dumps(records,indent=2)+'\n')
for p in records:print(p['sourcePage'],p['sourceBarlineX'],[(s['staffID'],[(round(m['deltaInStaffSpaces'],2),round(m['leftSupport'],2),round(m['rightSupportAtPeak'],2)) for m in s['measurements']]) for s in p['staves']])
