from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
import numpy as np,json,hashlib,subprocess,math
root=Path('.build/mozart-k488-complete-2026-10-03');out=Path('.build/k488-number-review-2026-10-03');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((root/'baseline-parts/manifest.json').read_text());c=json.loads((root/'numbered-parts/manifest.json').read_text())
assert len(b['parts'])==len(c['parts'])==9
rows=[];jobs=[]
for x,y in zip(b['parts'],c['parts']):
 assert x['id']==y['id'];assert x['placements']==y['placements'],x['name']
 rows.append({'part':x['name'],'placements':len(x['placements']),'outputPages':x['outputPages'],'completePartManifestEqual':x==y,'placementMetadataExact':x['placements']==y['placements'],'differingPartManifestFields':[k for k in set(x)|set(y) if x.get(k)!=y.get(k)]})
 for kind in ['baseline-parts','numbered-parts']:
  pdf=root/kind/x['file'];prefix=out/'rendered'/kind/x['id'];prefix.parent.mkdir(parents=True,exist_ok=True)
  jobs.append((pdf,prefix))
def render(job):
 pdf,prefix=job
 subprocess.run(['pdftoppm','-r','144','-gray','-png',str(pdf),str(prefix)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 return {'pdf':str(pdf),'sha256':sha(pdf),'prefix':str(prefix)}
with ThreadPoolExecutor(max_workers=2) as pool:rendered=list(pool.map(render,jobs))
pages=[]
for part in b['parts']:
 for page in range(1,part['outputPages']+1):
  a=out/'rendered/baseline-parts'/f"{part['id']}-{page}.png";z=out/'rendered/numbered-parts'/f"{part['id']}-{page}.png"
  aa=np.array(Image.open(a).convert('L'));zz=np.array(Image.open(z).convert('L'));assert aa.shape==zz.shape
  diff=aa!=zz;regions=[];overlap=0
  for placement in part['placements']:
   if placement['outputPage']!=page:continue
   for category,rect in [('retainedBand',placement['destinationRect'])]+[('copiedMark',m['destinationRect']) for m in placement.get('sourceMarkings',[])]:
    x0,y0,x1,y1=rect;x0,y0=int(math.floor(x0*2)),int(math.floor(y0*2));x1,y1=int(math.ceil(x1*2)),int(math.ceil(y1*2))
    n=int(diff[y0:y1,x0:x1].sum());overlap+=n;regions.append({'id':placement['id'],'category':category,'changedPixels':n})
  ys,xs=np.where(diff)
  pages.append({'part':part['name'],'page':page,'baselinePNG':str(a),'numberedPNG':str(z),'baselinePNG_SHA256':sha(a),'numberedPNG_SHA256':sha(z),'changedPixels':int(diff.sum()),'changeBoundsPixels':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)] if len(xs) else None,'changedPixelsInsideRetainedNotationOrCopies':overlap,'regions':regions,'removedDarkPixels':int(((zz>aa)&diff).sum()),'addedDarkPixels':int(((zz<aa)&diff).sum())})
def differences(a,b,path=''):
 if type(a)!=type(b):return [(path,a,b)]
 if isinstance(a,dict):
  d=[]
  for key in sorted(set(a)|set(b)):
   if key not in a or key not in b:d.append((path+'/'+key,a.get(key),b.get(key)))
   else:d += differences(a[key],b[key],path+'/'+key)
  return d
 if isinstance(a,list):
  if len(a)!=len(b):return [(path,a,b)]
  return [d for i,(x,y) in enumerate(zip(a,b)) for d in differences(x,y,path+'/'+str(i))]
 return [] if a==b else [(path,a,b)]
plans=[json.loads((root/k/'plan.json').read_text()) for k in ['baseline-parts','numbered-parts']]
plan_diff=differences(*plans)
projects=[]
for kind in ['baseline-parts','numbered-parts']:
 p=json.loads((root/kind/'Mozart K488 — I. Allegro.partsmithproject/project.json').read_text())['project']
 ids={p['id']:'project'};ids.update({part['id']:'part:'+part['name'] for part in p['parts']});ids.update({band['id']:'band:'+str(i) for i,band in enumerate(p['bands'])})
 def canonical(v):
  if isinstance(v,dict):return {k:canonical(x) for k,x in v.items() if k not in ['createdAt','updatedAt']}
  if isinstance(v,list):return [canonical(x) for x in v]
  return ids.get(v,v) if isinstance(v,str) else v
 projects.append(canonical(p))
project_diff=differences(*projects)
result={'parts':rows,'totalPlacements':sum(r['placements'] for r in rows),'totalPages':len(pages),'allPlacementMetadataExact':all(r['placementMetadataExact'] for r in rows),'allRetainedNotationAndCopiedPixelsExact':all(p['changedPixelsInsideRetainedNotationOrCopies']==0 for p in pages),'removedDarkPixels':sum(p['removedDarkPixels'] for p in pages),'addedDarkPixels':sum(p['addedDarkPixels'] for p in pages),'planDifferenceFields':dict((f,sum(p[0].split('/')[-1]==f for p in plan_diff)) for f in sorted(set(p[0].split('/')[-1] for p in plan_diff))),'projectDifferenceFields':dict((f,sum(p[0].split('/')[-1]==f for p in project_diff)) for f in sorted(set(p[0].split('/')[-1] for p in project_diff))),'projectCanonicalization':'Map project/part/band UUIDs to stable semantic IDs and ignore creation/update timestamps only. All other values compared.','rendered':rendered,'pages':pages,'planDifferences':plan_diff,'projectDifferences':project_diff}
(out/'export-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['rendered','pages','planDifferences','projectDifferences']},indent=2))
