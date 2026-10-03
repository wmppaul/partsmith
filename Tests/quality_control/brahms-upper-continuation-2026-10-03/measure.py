from pathlib import Path
from PIL import Image
import numpy as np,json
P=Path('.build/brahms-remaining-2026-10-03/upper-review');a=json.loads(Path('.build/ownership-alternatives-2026-10-03/actual.json').read_text());out=[]
for pn,l,r,shift in [(28,242,252,-1),(31,1642,1653,0)]:
 raw=np.asarray(Image.open(P/f'p{pn}-original-musical.pgm'))<190;h,w=raw.shape;p=a['pages'][pn-1];rows=[]
 for idx,s in enumerate(p['staves'][:4]):
  lines=[y*h+(shift if idx==0 else 0) for y in s['staffLineFractions']];t=round(lines[0]);b=round(lines[4])+1;occupied=raw[t:b,l:r].any(axis=1);gaps=[]
  for k,v in enumerate(occupied):
   if not v:
    y=t+k
    if gaps and gaps[-1][1]==y:gaps[-1][1]=y+1
    else:gaps.append([y,y+1])
  rows.append({'staff':idx,'coreRows':[t,b],'supported':int(occupied.sum()),'coreRowsCount':b-t,'fraction':float(occupied.mean()),'missingRuns':gaps,'lines':lines})
 out.append({'page':pn,'columns':[l,r],'firstFourStaffCoreSupport':rows,'pixelToPDF':[p['pageWidth']/w,p['pageHeight']/h]})
print(json.dumps(out,indent=2));(P/'core-support.json').write_text(json.dumps(out,indent=2)+'\n')
