from pathlib import Path
import json,hashlib
import pymupdf as fitz
from PIL import Image,ImageDraw
R=Path.cwd(); out=R/'Tests/quality_control/page-turn-review-2026-10-03'; base=R/'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-continuation';cand=R/'.build/page-turn-review-2026-10-03/candidate-v4-reviewed';scratch=R/'.build/page-turn-review-2026-10-03';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=json.load(open(base/'manifest.json'));b=json.load(open(cand/'manifest.json'));breaks=json.load(open(cand/'layout-page-breaks.json'));originalproject=json.load(open(base/a['project']/'project.json'))['project'];project=json.load(open(cand/b['project']/'project.json'))['project']
assert a['sourceSHA256']==b['sourceSHA256'] and a['rectifications']==b['rectifications'];assert sha(cand/b['project']/'source.pdf')==b['sourceSHA256'];assert [x['layoutSettings'] for x in project['parts']]==[x['layoutSettings'] for x in originalproject['parts']]
assert sum(x.get('pageBreakBefore',False) for x in project['bands'])==len(breaks)==7
rows=[];images=[];issues=[];parts=[];copies=0;roundoff=[]
for before,after in zip(a['parts'],b['parts']):
 assert before['id']==after['id'];assert len(after['placements'])==151
 pdf=fitz.open(cand/after['file']);pagebottom={};summaries=[]
 for x,y in zip(before['placements'],after['placements']):
  assert x['id']==y['id'];assert x['sourceRect']==y['sourceRect'];assert x['sourcePage']==y['sourcePage'];assert x['staffLineYs']==y['staffLineYs'];assert [z['sourceRect'] for z in x['sourceMarkings']]==[z['sourceRect'] for z in y['sourceMarkings']]
  copies+=len(y['sourceMarkings']);sx=x['destinationRect'];sy=y['destinationRect'];dw=(sy[2]-sy[0])-(sx[2]-sx[0]);dh=(sy[3]-sy[1])-(sx[3]-sx[1]);assert max(abs(dw),abs(dh))<1e-5
  if max(abs(dw),abs(dh))>1e-7:roundoff.append({'id':y['id'],'widthDelta':dw,'heightDelta':dh})
  rr=fitz.Rect(sy)
  for mark in y['sourceMarkings']:rr|=fitz.Rect(mark['destinationRect'])
  page=pdf[y['outputPage']-1];assert page.rect.contains(rr)
  assert rr.y0>=pagebottom.get(y['outputPage'],0)-1e-7;pagebottom[y['outputPage']]=rr.y1
  rows.append({'id':y['id'],'beforePage':x['outputPage'],'afterPage':y['outputPage'],'sourceRect':y['sourceRect'],'retainedScale':True})
  if y['id'] in breaks:
   assert next(z for z in after['placements'] if z['outputPage']==y['outputPage'])['id']==y['id']
 for n,page in enumerate(pdf):
  group=[x for x in after['placements'] if x['outputPage']==n+1];summaries.append({'page':n+1,'first':group[0]['id'],'last':group[-1]['id'],'bands':len(group)})
  pix=page.get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False);im=Image.frombytes('RGB',[pix.width,pix.height],pix.samples);dest=scratch/'rendered'/after['id'];dest.mkdir(parents=True,exist_ok=True);im.save(dest/f'page-{n+1:02}.png');images.append((f'{after["name"]} page {n+1}',im))
 parts.append({'id':after['id'],'file':after['file'],'pagesBefore':before['outputPages'],'pagesAfter':len(pdf),'bands':151,'sha256':sha(cand/after['file']),'pages':summaries})
 for n in ([13,14,15,16] if after['id']=='violin1' else [13,14] if after['id'] in ['violin2','viola'] else [12,13]):
  pdf[n-1].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False).save(out/f'final-{after["id"]}-p{n}.png')
for start in range(0,len(images),6):
 pack=images[start:start+6];sheet=Image.new('RGB',(1100,750*((len(pack)+1)//2)),'#eeeeee');draw=ImageDraw.Draw(sheet)
 for j,(label,im) in enumerate(pack):
  im=im.copy();im.thumbnail((550,718));x=(j%2)*550;y=(j//2)*750;sheet.paste(im,(x,y+25));draw.text((x+8,y+6),label,fill='black')
 sheet.save(out/f'final-pages-{start+1:02}.png')
variants=[]
for n in ['candidate-v1','candidate-v2','candidate-v3-minimal','candidate-v4-reviewed']:
 m=json.load(open(scratch/n/'manifest.json'));variants.append({'id':n,'explicitBreaks':json.load(open(scratch/n/'layout-page-breaks.json')),'pages':{x['id']:x['outputPages'] for x in m['parts']},'total':sum(x['outputPages'] for x in m['parts'])})
assert len(rows)==604 and copies==42
result={'verdict':'structural checks pass; visual review recorded separately','musicStrips':604,'copiedDirections':42,'mainSourceCropChanges':0,'sourceCopyChanges':0,'intentionalMusicScaleChanges':0,'layoutFittingRoundoff':roundoff,'sourceSHA256':b['sourceSHA256'],'rectificationCount':len(b['rectifications']),'explicitBreaks':breaks,'parts':parts,'rows':rows,'issues':issues,'variants':variants,'inputSHA256':{str(p.relative_to(R)):sha(p) for p in [base/'manifest.json',cand/'manifest.json',cand/b['project']/'project.json',scratch/'export_breaks.swift',R/'.build/brahms-continuation-release-2026-10-03/candidate/brahms-inventory.json']}}
(out/'layout-review.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'totalPages':sum(x['pagesAfter'] for x in parts),'parts':[{k:v for k,v in p.items() if k!='pages'} for p in parts],'issues':issues},indent=2))
