from pathlib import Path
from collections import deque
import json, hashlib, math
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
IND=Path('Tests/quality_control/terminal-body-independent-2026-10-03').resolve()
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

def measure(a, origin, stroke, centerY, space):
    # Diagnostic only, never used as a crop oracle or threshold decision.
    # Use unchanged source pixels; mask only physical spine for square thickness.
    cx=(stroke[0]+stroke[1])/2
    box=[math.floor(cx-1.2*space),math.floor(centerY-.65*space),math.ceil(cx+1.2*space),math.ceil(centerY+.65*space)]
    x0,y0,x1,y1=box; ox,oy=origin
    region=a[y0-oy:y1-oy,x0-ox:x1-ox].copy()
    assert region.shape==(y1-y0,x1-x0)
    removed=region.copy(); removed[:,max(0,stroke[0]-x0):min(x1-x0,stroke[1]-x0)]=False
    dp=np.zeros_like(removed,dtype=int); best=0
    for y in range(len(removed)):
      for x in range(len(removed[0])):
       if removed[y,x]:
        dp[y,x]=1+(min(dp[y-1,x],dp[y,x-1],dp[y-1,x-1]) if y and x else 0)
        best=max(best,int(dp[y,x]))
    # Closed white regions inside local source box. Report every enclosure;
    # staff/barline intersections may create one too, so this is NOT a head test.
    h,w=region.shape; visited=set();holes=[]
    for y in range(h):
      for x in range(w):
       if region[y,x] or (x,y) in visited:continue
       q=[(x,y)];visited.add((x,y));i=0;touch=False
       while i<len(q):
        px,py=q[i];i+=1
        if px in (0,w-1) or py in (0,h-1):touch=True
        for nx,ny in [(px-1,py),(px+1,py),(px,py-1),(px,py+1)]:
         if 0<=nx<w and 0<=ny<h and not region[ny,nx] and (nx,ny) not in visited:
          visited.add((nx,ny));q.append((nx,ny))
       if not touch:holes.append({'pixels':len(q),'bounds':[min(x for x,y in q)+x0,min(y for x,y in q)+y0,max(x for x,y in q)+x0+1,max(y for x,y in q)+y0+1]})
    return {'diagnosticBox':box,'sourceInkPixels':int(region.sum()),'offSpineInkPixels':int(removed.sum()),'maxFilledSquareOutsideSpine':best,'squareOverStaffSpace':best/space,'closedWhiteRegions':holes}
rows=[]
for case in json.loads((ROOT/'diagnostics/witnesses.json').read_text()):
 for i,w in enumerate(case['witnesses']):
  a=np.array([[c=='#' for c in line]for line in w['originalPatch']])
  row={'name':case['id']+':w'+str(i),'group':'real-source false body witness','sourceSHA256':case['sourceSHA256'],'nativeImageSHA256':sha(case['imagePath']),'witness':{k:v for k,v in w.items()if 'Patch'not in k},'measurements':{}}
  for anchor,cy in [('observed-body',(w['body'][1]+w['body'][3])/2),('outer-staff-boundary',w['boundary'])]:
   row['measurements'][anchor]=measure(a,w['patchBounds'][:2],w['stroke'],cy,w['space'])
  rows.append(row)
for sub,kinds in [('sources',['filledOuter','hollowOuter','mixedOuter','filledFirstSpace','hollowFirstSpace','hollowSecondLine','filledStemInterrupted','hollowStemInterrupted','filledStaffInterrupted','hollowStaffInterrupted','attachedTie','attachedSlur','tieAcrossBarline','slurAcrossBarline','tieStaffInterrupted','slurStaffInterrupted','tieBarlineInterrupted','filledAtJunction','hollowAtJunction','bareBarline']),('tied-sources',['filledIncomingTie','filledOutgoingTie','filledLowerTie','hollowIncomingTie'])]:
 for kind in kinds:
  for transform,tilt,bow in [('straight',0,0),('rotated',2,0),('bowed',-1,7)]:
   p=IND/sub/(kind+'-'+transform+'.png')
   a=np.array(Image.open(p).convert('L'))<190
   shift=round(math.tan(tilt*math.pi/180)*(501-360)+bow*min(1,max(0,(501-360)/240))**2)
   inset=7 if kind in ('filledFirstSpace','hollowFirstSpace') else 14 if kind=='hollowSecondLine'else 0
   row={'name':kind+'-'+transform,'group':'independent source fixture, native resolution only','sourceSHA256':sha(p),'sourceImage':str(p),'measurements':{}}
   for anchor,cy in [('upper-authored-endpoint',170+inset+shift),('lower-authored-endpoint',396-inset+shift)]:row['measurements'][anchor]=measure(a,[0,0],[500,503],cy,14)
   rows.append(row)
result={'scope':'Diagnostic source-local mass/enclosure measurements only. No classification threshold, candidate or source-oracle changes. Fixture profiles use native scale1 source PNGs; do not claim 0.5/1.5 native resampling equivalence. Center is authored endpoint for fixtures and observed source witness/body or outer staff boundary for real scans; these are different anchors, explicitly retained.','rows':rows}
(ROOT/'source-body-profiles.json').write_text(json.dumps(result,indent=2)+'\n')
for r in rows[:13]:print(r['name'],[(k,v['maxFilledSquareOutsideSpine'],len(v['closedWhiteRegions']))for k,v in r['measurements'].items()])
for kind in ['filledOuter-straight','hollowOuter-straight','filledIncomingTie-straight','hollowIncomingTie-straight','bareBarline-straight']:
 r=next(x for x in rows if x['name']==kind);print(kind,r['measurements'])
