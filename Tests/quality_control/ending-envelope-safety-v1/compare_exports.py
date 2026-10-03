from pathlib import Path
import json, hashlib
import pymupdf as fitz
from PIL import Image, ImageDraw
W=Path('.build/qc-ending-envelope-safety')
configs={
 'brahms':(Path('output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-endings'),W/'brahms-parts'),
 'kv498':(Path('output/pdf/auto-qc-2026-09-21/mozart-kv498-directions'),W/'kv498-parts-matched-title'),
}
(W/'output-contexts').mkdir(exist_ok=True);(W/'changed-pages').mkdir(exist_ok=True)
record={'scores':[],'mainCropChanges':[],'pageComparisons':[],'sourceCopyChanges':[],'unexplainedCopyCountChanges':[],'overlaps':[],'outsidePage':[]}
mainfields=['id','sourcePage','sourceRect','candidateIDs','staffLineYs','system','kind']
for score,(aDir,bDir) in configs.items():
 a=json.loads((aDir/'manifest.json').read_text());b=json.loads((bDir/'manifest.json').read_text())
 assert a['sourceSHA256']==b['sourceSHA256'] and a['rectifications']==b['rectifications']
 assert a['profile']==b['profile']
 scoreRecord={'score':score,'parts':[],'oldCopyRows':0,'newCopyRows':0,'unchangedCopies':0,'mainCrops':0,'changedOutputPages':0}
 for old,new in zip(a['parts'],b['parts']):
  assert old['id']==new['id'] and old['bandCount']==new['bandCount'] and old['outputPages']==new['outputPages']
  opdf=fitz.open(aDir/old['file']);npdf=fitz.open(bDir/new['file'])
  sourceRows=[];pageEnvelopes={}
  for x,y in zip(old['placements'],new['placements']):
   scoreRecord['mainCrops']+=1
   if {k:x[k] for k in mainfields}!={k:y[k] for k in mainfields}:record['mainCropChanges'].append({'score':score,'before':x,'after':y})
   oldMarks=x['sourceMarkings'];newMarks=y['sourceMarkings']
   scoreRecord['oldCopyRows']+=len(oldMarks);scoreRecord['newCopyRows']+=len(newMarks)
   if len(oldMarks)!=len(newMarks):record['unexplainedCopyCountChanges'].append({'score':score,'band':y['id'],'before':len(oldMarks),'after':len(newMarks)})
   for om,nm in zip(oldMarks,newMarks):
    if om['sourceRect']==nm['sourceRect'] and om.get('isBelow')==nm.get('isBelow'):scoreRecord['unchangedCopies']+=1
    else:
     record['sourceCopyChanges'].append({'score':score,'bandID':y['id'],'oldSourceRect':om['sourceRect'],'sourceRect':nm['sourceRect'],'outputPage':y['outputPage']})
     clip=fitz.Rect(y['destinationRect'])
     for m in newMarks:clip|=fitz.Rect(m['destinationRect'])
     clip+=(-2,-2,2,2)
     pix=npdf[y['outputPage']-1].get_pixmap(matrix=fitz.Matrix(3,3),clip=clip,alpha=False)
     im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
     fname=f'{score}-{y["id"]}.png';im.save(W/'output-contexts'/fname)
     row=Image.new('RGB',(im.width,im.height+30),'white');row.paste(im,(0,30));ImageDraw.Draw(row).text((5,8),f'{score} {y["id"]} -> output page {y["outputPage"]}',fill='black');sourceRows.append(row)
   envelopes=[fitz.Rect(y['destinationRect'])]+[fitz.Rect(m['destinationRect']) for m in newMarks]
   for i,r in enumerate(envelopes):
    if not npdf[y['outputPage']-1].rect.contains(r):record['outsidePage'].append({'score':score,'part':new['id'],'band':y['id'],'item':i})
   combined=fitz.Rect(envelopes[0])
   for r in envelopes[1:]:combined|=r
   pageEnvelopes.setdefault(y['outputPage'],[]).append((y['id'],combined))
  for page,envs in pageEnvelopes.items():
   for (previous,prevRect),(current,curRect) in zip(envs,envs[1:]):
    if prevRect.y1>curRect.y0+1e-6:record['overlaps'].append({'score':score,'part':new['id'],'page':page,'bands':[previous,current],'verticalOverlap':prevRect.y1-curRect.y0})
  for i in range(len(npdf)):
   aa=opdf[i].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False);bb=npdf[i].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
   equal=aa.samples==bb.samples;record['pageComparisons'].append({'score':score,'part':new['id'],'page':i+1,'pixelIdenticalAt108DPI':equal})
   if not equal:
    scoreRecord['changedOutputPages']+=1;bb.save(str(W/'changed-pages'/f'{score}-{new["id"]}-{i+1:03d}.png'))
  scoreRecord['parts'].append({'id':new['id'],'pages':new['outputPages'],'systems':new['bandCount'],'sha256':hashlib.sha256((bDir/new['file']).read_bytes()).hexdigest()})
  if sourceRows:
   sheet=Image.new('RGB',(max(i.width for i in sourceRows),sum(i.height for i in sourceRows)+10*(len(sourceRows)-1)),'#ccc');y=0
   for im in sourceRows:sheet.paste(im,(0,y));y+=im.height+10
   sheet.save(W/'output-contexts'/f'{score}-{new["id"]}-all.png')
 record['scores'].append(scoreRecord)
(W/'export-comparison.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:v for k,v in record.items() if k not in ['pageComparisons','sourceCopyChanges']},indent=2));print('changed source rows',len(record['sourceCopyChanges']))
