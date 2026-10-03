from pathlib import Path
from collections import Counter
import pymupdf as fitz,json,hashlib
b=Path('.build/k488-independent-review-2026-10-03');source=Path('sample_scores/rest_detection/01_full_scores/mozart_piano_concerto_no23_kv488_mvt1_mutopia2229.pdf');d=fitz.open(source);m=json.load(open('.build/mozart-k488-complete-2026-10-03/source-reviewed-map.json'));ss=m['systems'];rows=[]
for pi,p in enumerate(d):
 lines=[]
 for dr in p.get_drawings():
  for v in dr['items']:
   if v[0]=='l':
    a,c=v[1:3]
    if abs(a.y-c.y)<.01 and abs(a.x-c.x)>400:lines.append((min(a.x,c.x),a.y,max(a.x,c.x)))
 # Each printed five-line staff has full-width horizontal lines.
 ys=sorted(set(round(a[1],2) for a in lines));groups=[]
 for y in ys:
  if not groups or y-groups[-1][-1]>5:groups.append([y])
  else:groups[-1].append(y)
 cores=[g for g in groups if len(g)==5]
 nums=[]
 for w in p.get_text('words'):
  if w[4].isdigit() and w[0]<70:
   for g in cores:
    if -.5<g[0]-w[3]<6:nums.append((int(w[4]),g,w));break
 if pi==0:nums.insert(0,(1,cores[0],None))
 nums.sort(key=lambda x:x[1][0])
 mapped=[x for x in ss if x['page']==pi+1]
 assert len(nums)==len(mapped),(pi+1,len(nums),len(mapped),nums)
 for num,g,w in nums:
  xs=[]
  for dr in p.get_drawings():
   for item in dr['items']:
    if item[0]=='l':
     a,c=item[1:3]
     if abs(a.x-c.x)<.01 and min(a.y,c.y)<=g[0]+.4 and max(a.y,c.y)>=g[-1]-.4:xs.append(a.x)
  # Staff-entry barline is structural. Group the final thin+thick closing strokes.
  positions=[]
  for x in sorted(xs):
   if not positions or x-positions[-1]>4:positions.append(x)
  positions=[x for x in positions if x>70] # all source system-entry x<=107 except opening; remove exact start below
  if pi==0 and num==1:positions=[x for x in positions if x>120]
  row={'page':pi+1,'printedStartBar':num,'firstStaffLineYs':g,'sourceBarEnds':positions,'independentBarCount':len(positions),'numberBBox':None if w is None else list(w[:4])};root=next(v for v in mapped if v['firstBar']==num);row['rootCount']=root['barCount'];row['matches']=row['independentBarCount']==row['rootCount'];rows.append(row)
(b/'source-number-verification.json').write_text(json.dumps({'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'method':'Independent extraction of full-width source staff lines, printed left-margin start numbers, and vertical lines spanning the first staff. Final thin/thick strokes within4pt merged; source system-entry strokes excluded. Does not use root barline arrays or native staff candidates.','systems':rows},indent=2)+'\n')
print('Source verify',len(rows),'systems;',sum(x['matches'] for x in rows),'matching bar counts; failures',[(x['page'],x['printedStartBar'],x['independentBarCount'],x['rootCount']) for x in rows if not x['matches']])
