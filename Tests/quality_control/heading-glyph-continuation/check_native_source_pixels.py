#!/usr/bin/env python3
"""Test changed native rectangles against pre-existing, immutable source-pixel guards."""
from pathlib import Path
import json
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
REPORT=Path(__file__).resolve().parent
RUN=ROOT/'.build/heading-glyph-continuation-2026-10-03/native'
index={x['number']:x for x in json.loads((REPORT/'index.json').read_text())}
comparison=json.loads((RUN/'comparison.json').read_text())
rows=[]
for g in json.loads((REPORT/'frozen-initial-A-guards.json').read_text()):
 i=index[g['number']]
 changes=next(x for x in comparison['cases'] if x['id']==i['case'])['headingChanges']
 changed=next(x for x in changes if x['pageIndex']==i['page']-1)
 before=next(x for x in changed['before'] if x['anchorStaffID']==i['anchorStaffID'])['bounds']
 after=next(x for x in changed['after'] if x['anchorStaffID']==i['anchorStaffID'])['bounds']
 im=np.array(Image.open(ROOT/f".build/accepted-heading-source-review/{i['case']}-p{i['page']}.png").convert('L'))
 height,width=im.shape
 x0,y0,x1,y1=g['sourceManualInitialALeftROI216dpi']
 ys,xs=np.nonzero(im[y0:y1,x0:x1]<128);xs=xs+x0;ys=ys+y0
 # Match the frozen audit's pixel-center convention; boxes are continuous PDF fractions.
 within=lambda b,x,y:(x+0.5>=b[0]*width)&(x+0.5<b[2]*width)&(y+0.5>=b[1]*height)&(y+0.5<b[3]*height)
 gy,gx=np.nonzero(im<128)
 added=within(after,gx,gy)&~within(before,gx,gy)
 in_guard=(gx>=x0)&(gx<x1)&(gy>=y0)&(gy<y1)
 rows.append({'number':i['number'],'case':i['case'],'page':i['page'],'before':before,'after':after,'originalEnclosed':after[0]<=before[0] and after[1]<=before[1] and after[2]>=before[2] and after[3]>=before[3], 'guardPixels':len(xs),'guardPixelsOutsideBaseline':int((~within(before,xs,ys)).sum()),'guardPixelsOutsideCandidate':int((~within(after,xs,ys)).sum()),'addedDarkPixels':int(added.sum()),'addedDarkPixelsOutsideInitialAGuard':int((added&~in_guard).sum())})
assert len(rows)==2
assert all(r['originalEnclosed'] and r['guardPixelsOutsideCandidate']==0 and r['addedDarkPixelsOutsideInitialAGuard']==0 for r in rows)
(REPORT/'native-source-pixel-results.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps(rows,indent=2))
