from pathlib import Path
import json,hashlib
import pymupdf as f
w=Path('.build/brahms93521-reviewed-overlap-trim-2026-10-03');old=Path('output/pdf/auto-qc-2026-10-03/brahms-quartet-93521-viola-in-tempo-repair');new=w/'parts'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
a=json.loads((old/'manifest.json').read_text());b=json.loads((new/'manifest.json').read_text());ed=json.loads((w/'proposed-edits-before-output.json').read_text());edits={x['id']:x for x in ed['changes']};out=w/'output-review';out.mkdir(exist_ok=True)
changed=[];same=[];details=[]
for ap,bp in zip(a['parts'],b['parts']):
 assert ap['id']==bp['id'] and ap['outputPages']==bp['outputPages']
 da=f.open(old/ap['file']);db=f.open(new/bp['file']);assert sha(new/bp['file'])==bp['sha256']
 for ar,br in zip(ap['placements'],bp['placements']):
  assert ar['id']==br['id']
  if ar['id'] in edits:
   assert all(abs(x-y)<1e-7 for x,y in zip(br['sourceRect'],edits[ar['id']]['newRect']))
   for stage,doc,row in [('before',da,ar),('after',db,br)]:
    rect=f.Rect(row['destinationRect']);rect.x0=20;rect.x1=592;rect.y0=max(0,rect.y0-24);rect.y1=min(792,rect.y1+24)
    q=out/(br['id']+'-'+stage+'.png');doc[row['outputPage']-1].get_pixmap(matrix=f.Matrix(3,3),clip=rect,alpha=False).save(q)
    details.append({'id':br['id'],'stage':stage,'path':str(q),'sha256':sha(q),'outputPage':row['outputPage']})
  else:assert ar['sourceRect']==br['sourceRect'],ar['id']
  assert [x['sourceRect'] for x in ar['sourceMarkings']]==[x['sourceRect'] for x in br['sourceMarkings']]
 for i in range(len(da)):
  pa=da[i].get_pixmap(matrix=f.Matrix(2,2),alpha=False);pb=db[i].get_pixmap(matrix=f.Matrix(2,2),alpha=False)
  r={'part':bp['id'],'page':i+1,'PDFSHA256':sha(new/bp['file'])}
  if pa.samples==pb.samples:same.append(r)
  else:
   q=out/(bp['id']+'-page-'+str(i+1)+'.png');pb.save(q);r.update(path=str(q),sha256=sha(q));changed.append(r)
report={'oldManifestSHA256':sha(old/'manifest.json'),'newManifestSHA256':sha(new/'manifest.json'),'pages':64,'changedPages':changed,'unchangedPages':same,'changedDetails':details,'onlySevenSourceCropsChanged':True,'sourceMarkingsUnchanged':True}
(w/'output-comparison.json').write_text(json.dumps(report,indent=2)+'\n');print('Changed',len(changed),'Unchanged',len(same),'Detail images',len(details))
