from pathlib import Path
import json,hashlib
import pymupdf as fitz
from PIL import Image,ImageDraw
r=Path('Tests/quality_control/brahms-continuation-output'); b=Path('.build/brahms-continuation-release-2026-10-03/output-review'); h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs={str(b/v/'manifest.json'):h(b/v/'manifest.json') for v in ['baseline-parts','candidate-parts']}
old=json.load(open(b/'baseline-parts/manifest.json'));new=json.load(open(b/'candidate-parts/manifest.json'));guards=json.load(open(r/'source-guards.json'))
changes=[];moves=[];issues=[];copies=0;bands=0;pdfs=[];viewed=[];guardresults=[]
for p,q in zip(old['parts'],new['parts']):
 assert p['id']==q['id'];assert len(p['placements'])==len(q['placements'])==151
 assert [x['id'] for x in p['placements']]==[x['id'] for x in q['placements']]
 pdf=fitz.open(b/'candidate-parts'/q['file']);inputs[str(b/'candidate-parts'/q['file'])]=h(b/'candidate-parts'/q['file']);inputs[str(b/'baseline-parts'/p['file'])]=h(b/'baseline-parts'/p['file']);pdfs.append({'part':q['id'],'pages':len(pdf),'sha256':h(b/'candidate-parts'/q['file'])})
 pagebottom={}
 for x,y in zip(p['placements'],q['placements']):
  bands+=1;assert x['sourcePage']==y['sourcePage'];assert [z['sourceRect'] for z in x['sourceMarkings']]==[z['sourceRect'] for z in y['sourceMarkings']];copies+=len(y['sourceMarkings'])
  if x['sourceRect']!=y['sourceRect']:changes.append({'id':y['id'],'before':x['sourceRect'],'after':y['sourceRect']})
  if x['outputPage']!=y['outputPage']:moves.append({'id':y['id'],'beforePage':x['outputPage'],'afterPage':y['outputPage']})
  rect=fitz.Rect(y['destinationRect'])
  for c in y['sourceMarkings']:rect|=fitz.Rect(c['destinationRect'])
  assert rect.x0>=0 and rect.y0>=0 and rect.x1<=pdf[y['outputPage']-1].rect.width and rect.y1<=pdf[y['outputPage']-1].rect.height
  if y['outputPage'] in pagebottom:assert rect.y0>=pagebottom[y['outputPage']]-1e-8
  pagebottom[y['outputPage']]=rect.y1
  if y['id'] in ['p29-s1-violin1','p29-s1-violin2','p31-s2-violin1']:
   rr=fitz.Rect(rect.x0-4,rect.y0-5,rect.x1+4,rect.y1+5);out=r/('independent-'+y['id']+'-output.png');pdf[y['outputPage']-1].get_pixmap(matrix=fitz.Matrix(3,3),clip=rr,alpha=False).save(out)
  if y['id'] in ['p29-s1-violin1','p29-s1-violin2']:
   g=next(z for z in guards['guards'] if z['bandID']==y['id']);assert fitz.Rect(y['sourceRect']).contains(fitz.Rect(g['rect']));guardresults.append({'id':y['id'],'guard':g['rect'],'sourceRect':y['sourceRect'],'contains':True})
 if q['id']=='violin1':
  images=[]
  for i,page in enumerate(pdf):
   pix=page.get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False);im=Image.frombytes('RGB',[pix.width,pix.height],pix.samples);images.append((i+1,im))
   if i+1 in [12,13,14,15]:im.save(r/f'independent-violin1-page-{i+1}.png')
  for start in range(0,len(images),3):
   pack=images[start:start+3];sheet=Image.new('RGB',(918*len(pack),1212),'#eeeeee');draw=ImageDraw.Draw(sheet)
   for j,(n,im) in enumerate(pack):sheet.paste(im,(j*918,24));draw.text((j*918+10,5),f'Candidate Violin I page {n}',fill='black')
   sheet.save(r/f'independent-pages-{start+1:02}.png')
 elif q['id']=='violin2':pdf[11].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False).save(r/'independent-violin2-page-12.png')
src=b/'candidate-parts'/new['reviewSourceFile'];inputs[str(src)]=h(src);assert h(src)==new['reviewSourceSHA256'];doc=fitz.open(src);doc[28].get_pixmap(matrix=fitz.Matrix(4,4),clip=fitz.Rect(0,15,427,170),alpha=False).save(r/'independent-current-source-p29.png')
assert bands==604 and copies==42
assert {x['id'] for x in changes}=={'p29-s1-violin1','p29-s1-violin2'}
assert moves==[{'id':'p31-s2-violin1','beforePage':14,'afterPage':13}]
summary={'bands':bands,'copies':copies,'pdfs':pdfs,'changedSourceCrops':changes,'pageMoves':moves,'guardContainment':guardresults,'layoutIssues':issues,'inputSHA256':inputs}
(r/'independent-results.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k!='inputSHA256'},indent=2))
