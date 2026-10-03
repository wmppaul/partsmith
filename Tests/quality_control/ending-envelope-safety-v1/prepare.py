from pathlib import Path
import copy, json, hashlib
import numpy as np
import pymupdf as fitz
from PIL import Image, ImageDraw

W = Path('.build/qc-ending-envelope-safety')
def read(p): return json.loads(Path(p).read_text())
def digest(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def union(rs): return [min(x[0] for x in rs), min(x[1] for x in rs), max(x[2] for x in rs), max(x[3] for x in rs)]
def contains(a,b): return a[0]<=b[0]+1e-8 and a[1]<=b[1]+1e-8 and a[2]>=b[2]-1e-8 and a[3]>=b[3]-1e-8
def margin(c):
 b=c['bounds'];s=c['staffSpace']
 return [max(0,b[0]-s),max(0,b[1]-s),min(c['pageWidth'],b[2]+s),min(c['pageHeight'],max(b[3],c.get('rightHookBottom') or b[3])+s)]

configs={
 'brahms':{'report':'Tests/quality_control/native-ending-brackets-v1/brahms-native-final.json','inventory':'.build/qc-ending-native-v1/brahms-native-endings-inventory.json','source':'sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf'},
 'kv498':{'report':'Tests/quality_control/native-ending-brackets-v1/kv498-native-final.json','inventory':'.build/qc-algorithm-audit/heading-dedup/kv498-native-inventory.json','source':'sample_scores/normal/01_chamber/mozart_trio_eb_major_kv498_score.pdf'},
}
guards=read('Tests/quality_control/native-ending-brackets-v1/native-guard-comparison.json')
kvguard=next(r for r in read('Tests/quality_control/kv498-checkpoint975ee3d-review/source-direction-guards.json')['regions'] if r['id']=='volta-1-2')
records=[];changedmetadata=[];fullpages=0;allcandidates=0
for score,cfg in configs.items():
 report=read(cfg['report']);inventory=read(cfg['inventory']);source=fitz.open(cfg['source'])
 fullpages+=len(report['pages']);allcandidates+=sum(len(p['candidates']) for p in report['pages'])
 bypage={p['pageIndex']:p for p in inventory['pages']}
 for pairIndex,pair in enumerate(report['pairs']):
  grouped={}
  for role in ['first','second']:
   c=pair[role];old=c['copyBounds'];new=margin(c)
   assert contains(new,old)
   key=(c['pageIndex'],c['systemIndex'],c['anchorStaffID'])
   grouped.setdefault(key,[]).append((old,new))
   guard=next((g['guardRect'] for g in guards if score=='brahms' and g['pageNumber']==c['pageIndex']+1 and g['systemNumber']==c['systemIndex']+1 and fitz.Rect(g['guardRect']).intersects(fitz.Rect(old))),None)
   # Distinguish neighboring pair members by maximum overlap, not first match.
   if score=='brahms':
    options=[g for g in guards if g['pageNumber']==c['pageIndex']+1 and g['systemNumber']==c['systemIndex']+1]
    guard=max(options,key=lambda g:(fitz.Rect(g['guardRect'])&fitz.Rect(old)).get_area())['guardRect']
   ctx=fitz.Rect(new)+(-5,-5,5,5);ctx &=source[c['pageIndex']].rect
   scale=8
   pix=source[c['pageIndex']].get_pixmap(matrix=fitz.Matrix(scale,scale),clip=ctx,alpha=False)
   im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
   base=im.copy();draw=ImageDraw.Draw(im)
   def xy(r):return [r[0]*scale-pix.x,r[1]*scale-pix.y,r[2]*scale-pix.x,r[3]*scale-pix.y]
   draw.rectangle(xy(new),outline='#a000d0',width=2)
   draw.rectangle(xy(old),outline='#00a8cf',width=2)
   if guard:draw.rectangle(xy(guard),outline='#ee0000',width=2)
   name=f'{score}-p{c["pageIndex"]+1:02d}-s{c["systemIndex"]+1}-{role}'
   base.save(W/'source-contexts'/f'{name}-source.png');im.save(W/'source-contexts'/f'{name}-bounds.png')
   pixels=np.asarray(base);ink=pixels.min(axis=2)<170
   xx=(np.arange(pix.width)+pix.x+.5)/scale;yy=(np.arange(pix.height)+pix.y+.5)/scale
   def mask(r):return (xx[None,:]>=r[0])&(xx[None,:]<r[2])&(yy[:,None]>=r[1])&(yy[:,None]<r[3])
   added=ink&mask(new)&~mask(old)
   missed=ink&mask(guard)&~mask(old) if guard else np.zeros(ink.shape,dtype=bool)
   overlay=np.asarray(base).copy();overlay[missed]=[255,0,0]
   Image.fromarray(overlay).save(W/'source-contexts'/f'{name}-guard-only-ink.png')
   records.append({'score':score,'page':c['pageIndex']+1,'system':c['systemIndex']+1,'role':role,'staffSpace':c['staffSpace'],'oldCopyBounds':old,'candidateCopyBounds':new,'fixedGuard':guard,'oldContainsGuard':contains(old,guard) if guard else None,'candidateContainsGuard':contains(new,guard) if guard else None,'addedDarkPixelsAt576DPI':int(added.sum()),'guardOutsideOldDarkPixelsAt576DPI':int(missed.sum()),'contextPrefix':name})
  for (pageIndex,systemIndex,anchor),rects in grouped.items():
   page=bypage[pageIndex];old=union([r[0] for r in rects]);new=union([r[1] for r in rects])
   norm=lambda r:[r[0]/page['pageWidth'],r[1]/page['pageHeight'],r[2]/page['pageWidth'],r[3]/page['pageHeight']]
   nav=page.setdefault('sharedNavigation',[])
   if score=='brahms':
    matching=[i for i,m in enumerate(nav) if m['anchorStaffID']==anchor and m['recognizedText']=='' and max(abs(x-y) for x,y in zip(m['bounds'],norm(old)))<1e-8]
    assert len(matching)==1,(pageIndex,anchor,matching)
    nav[matching[0]]['bounds']=norm(new)
   else:nav.append({'anchorStaffID':anchor,'bounds':norm(new),'recognizedText':'','isBelow':False})
   changedmetadata.append({'score':score,'page':pageIndex+1,'system':systemIndex+1,'anchor':anchor,'oldUnionBounds':old,'candidateUnionBounds':new})
   if score=='kv498':
    records.append({'score':score,'role':'pair guard','fixedGuard':kvguard['sourceRect'],'oldCopyBounds':old,'candidateCopyBounds':new,'oldContainsGuard':contains(old,kvguard['sourceRect']),'candidateContainsGuard':contains(new,kvguard['sourceRect'])})
 (W/f'{score}-candidate-inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
meta={'marginRule':'One local staff space on all four sides around detected bracket/number geometry, using max(geometry bottom, measured right hook bottom). No source IDs or guard coordinates enter margin choice.','completeInputPages':fullpages,'frozenNumericCandidates':allcandidates,'selectedPairs':sum(len(read(c['report'])['pairs']) for c in configs.values()),'recognitionReused':True,'recognitionAndPairSelectionUnchanged':True,'sourceBindings':[{'path':c['source'],'sha256':digest(c['source'])} for c in configs.values()],'records':records,'changedMetadata':changedmetadata}
(W/'geometry-comparison.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps({'completePages':fullpages,'numericCandidates':allcandidates,'testedGuards':sum(r.get('fixedGuard') is not None for r in records),'oldGuardFailures':sum(r.get('oldContainsGuard')==False for r in records),'candidateGuardFailures':sum(r.get('candidateContainsGuard')==False for r in records),'guardOnlyInk':[(r['contextPrefix'],r['guardOutsideOldDarkPixelsAt576DPI']) for r in records if 'contextPrefix' in r]},indent=2))
