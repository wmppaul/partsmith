from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
r=Path('.build/brahms-spine-branches-2026-10-03');results=[]
for p in sorted(r.glob('*-graph.json')):
 j=json.loads(p.read_text());w,h=j['sourceShape'];x0,y0,x1,y1=j['context'];counts=np.zeros((h,w),np.uint8)
 groups=[j['spineRuns']]+[n['runs'] for n in j['staffChannels']]+[n['runs'] for n in j['branches']]
 for runs in groups:
  for y,a,b in runs:counts[y,a:b]+=1
 if j['id'].startswith('p'):
  pn=int(j['id'][1:]);src=Path(f'.build/residual9-boundary-2026-10-03/agent-probe/page-{pn}-native-mask.pgm');source=np.array(Image.open(src))==0;owners=[]
 elif j['id'].startswith('network-'):
  src=r/(j['id']+'-source.png');source=np.array(Image.open(src))<190;orig=Path('Tests/quality_control/four-core-independent-2026-10-03/sources')/(j['id'][len('network-'):]+'-fiveMissingRows.png');owners=[orig.with_stem(orig.stem+f'-owner{i}') for i in range(4)]
 else:
  src=Path('Tests/quality_control/four-core-independent-2026-10-03/sources')/(j['id'][len('fourcore-'):]+'.png');source=np.array(Image.open(src))<190;owners=[src.with_stem(src.stem+f'-owner{i}') for i in range(4)]
 expected=np.zeros_like(source);expected[y0:y1,x0:x1]=source[y0:y1,x0:x1]
 assert np.array_equal(counts>0,expected) and counts.max()==1
 checks=[]
 for op in owners:
  owned=np.array(Image.open(op))<190;lost=int((owned&~(counts>0)).sum());assert lost==0
  checks.append({'path':str(op),'sha256':hashlib.sha256(op.read_bytes()).hexdigest(),'ownedPixels':int(owned.sum()),'unrepresentedPixels':lost})
 results.append({'id':j['id'],'source':str(src),'sourceSHA256':hashlib.sha256(src.read_bytes()).hexdigest(),'reconstructionExact':True,'payloadsDisjoint':True,'sourcePixels':int(expected.sum()),'owners':checks,'unresolvedSpineContacts':len(j['attachedBranchIDs']),'cropModified':False})
(r/'independent-payload-check.json').write_text(json.dumps(results,indent=2)+'\n')
print(f'{len(results)} graph contexts exact; {sum(len(x["owners"]) for x in results)} original owner masks preserved; no crop change or extraction claim')
