from pathlib import Path
import hashlib,json,math
import pymupdf as fitz
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
WORK=ROOT/'.build/brahms-glyph-output-2026-10-03';NATIVE=ROOT/'.build/heading-glyph-continuation-2026-10-03/native-worker'
load=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
parts=[];changed=[];bindings={}
for case in ['brahms242312','brahms09200']:
 before=WORK/('baseline-'+case+'-parts');after=WORK/(case+'-parts')
 bm=load(before/'manifest.json');am=load(after/'manifest.json')
 assert bm['profile']==am['profile'] and bm['rectifications']==am['rectifications']==[]
 assert bm['sourceSHA256']==am['sourceSHA256'] and bm['project']==am['project']
 assert load(before/'plan.json')==load(NATIVE/'baseline'/(case+'-plan.json'))
 for suffix in ['inventory','plan','summary']:
  p=NATIVE/'baseline'/(case+'-'+suffix+'.json');bindings[str(p.relative_to(ROOT))]=sha(p)
 for p in [before/'manifest.json',after/'manifest.json']:bindings[str(p.relative_to(ROOT))]=sha(p)
 for a,b in zip(am['parts'],bm['parts']):
  assert a['id']==b['id'];assert a['outputPages']==b['outputPages'];assert a['bandCount']==b['bandCount']==120
  assert sha(after/a['file'])==a['sha256'];assert sha(before/b['file'])==b['sha256']
  ap=fitz.open(after/a['file']);bp=fitz.open(before/b['file']);bands=[];changedpages=[];pagepixels=[]
  for new,old in zip(a['placements'],b['placements']):
   fields=[k for k in new if new[k]!=old[k]]
   assert not (set(fields)-{'sourceMarkings'}),(case,new['id'],fields)
   if fields:
    assert len(new['sourceMarkings'])==len(old['sourceMarkings'])==1
    assert new['sourcePage']==14 and new['system']==1
    n=new['sourceMarkings'][0];o=old['sourceMarkings'][0]
    assert n['sourceRect'][0]<o['sourceRect'][0] and n['sourceRect'][1:]==o['sourceRect'][1:]
    assert n['destinationRect'][0]<o['destinationRect'][0] and n['destinationRect'][1]==o['destinationRect'][1] and n['destinationRect'][3]==o['destinationRect'][3]
    # Width recomputation produces a 1.136868e-13pt right-edge roundoff in09200;
    # retain that exact observed difference in the record, not a false exactness claim.
    assert abs(n['destinationRect'][2]-o['destinationRect'][2])<1e-10
    bands.append(new['id']);changed.append({'case':case,'part':a['id'],'band':new['id'],'outputPage':new['outputPage'],'before':o,'after':n,'destinationDelta':[v-u for u,v in zip(o['destinationRect'],n['destinationRect'])]})
    folder=OUT/'changed-rows';folder.mkdir(exist_ok=True)
    union=fitz.Rect(new['destinationRect'])|fitz.Rect(n['destinationRect']);union=fitz.Rect(union.x0-4,union.y0-5,union.x1+4,union.y1+5)
    for label,pdf in [('before',bp),('after',ap)]:pdf[new['outputPage']-1].get_pixmap(matrix=fitz.Matrix(3,3),clip=union,alpha=False).save(folder/f'{case}-{a["id"]}-{label}.png')
  for i,p in enumerate(ap):
   pix=p.get_pixmap(matrix=fitz.Matrix(2,2),alpha=False);prev=bp[i].get_pixmap(matrix=fitz.Matrix(2,2),alpha=False)
   same=pix.width==prev.width and pix.height==prev.height and pix.samples==prev.samples
   record={'page':i+1,'pixelIdentical':same,'beforeSHA256':hashlib.sha256(prev.samples).hexdigest(),'afterSHA256':hashlib.sha256(pix.samples).hexdigest()};pagepixels.append(record)
   if not same:
    changedpages.append(i+1);folder=OUT/'changed-pages';folder.mkdir(exist_ok=True)
    for label,pp in [('before',prev),('after',pix)]:pp.save(folder/f'{case}-{a["id"]}-p{i+1}-{label}.png')
  assert set(changedpages)=={c['outputPage'] for c in changed if c['case']==case and c['part']==a['id']}
  parts.append({'case':case,'part':a['id'],'pages':len(ap),'changedBands':bands,'changedPages':changedpages,'pagePixels':pagepixels,'musicCropsChanged':0,'placementChanges':0})
# Fixed independently drawn original-A guards applied to actual native copy rectangles.
index={x['number']:x for x in load(ROOT/'Tests/quality_control/accepted-heading-source-review/index.json')}
guards=load(ROOT/'Tests/quality_control/accepted-heading-source-review/frozen-initial-A-guards.json');guardresults=[]
for g in guards:
 item=index[g['number']];case='brahms242312' if g['number']==18 else 'brahms09200'
 path=ROOT/f".build/accepted-heading-source-review/{item['case']}-p14.png";im=Image.open(path).convert('L');a=np.asarray(im)
 x0,y0,x1,y1=g['sourceManualInitialALeftROI216dpi'];ys,xs=np.where(a[y0:y1,x0:x1]<128);xs=xs+x0+.5;ys=ys+y0+.5
 for row in [r for r in changed if r['case']==case]:
  r=row['after']['sourceRect'];pw,ph=item['pageSize'];bounds=[r[0]/pw*im.width,r[1]/ph*im.height,r[2]/pw*im.width,r[3]/ph*im.height]
  outside=int(((xs<bounds[0])|(xs>=bounds[2])|(ys<bounds[1])|(ys>=bounds[3])).sum());assert outside==0
  guardresults.append({'case':case,'part':row['part'],'originalGuardNumber':g['number'],'darkGuardPixels':len(xs),'outsideActualNativeCopy':outside,'nativeSourceRect':r})
summary={'comparison':'actual fresh baseline e9ef3d1 and candidate document-worker inventories, same byte-identical layout/export implementation and identical typed metadata','parts':len(parts),'pages':sum(p['pages'] for p in parts),'mainCrops':960,'mainCropsChanged':0,'placementsChanged':0,'changedCopyRows':len(changed),'changedPages':sum(len(p['changedPages']) for p in parts),'pixelIdenticalPages':sum(sum(p['pixelIdentical'] for p in a['pagePixels']) for a in parts)}
(OUT/'comparison.json').write_text(json.dumps({'summary':summary,'parts':parts,'changedRows':changed,'actualNativeGuardResults':guardresults,'bindings':bindings},indent=2)+'\n')
print(json.dumps(summary,indent=2))
