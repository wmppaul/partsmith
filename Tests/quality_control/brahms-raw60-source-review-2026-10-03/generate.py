from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import pymupdf as fitz
import collections,json,hashlib,sys
work=Path('.build/brahms-raw60-source-review-2026-10-03')
queue=Path('Tests/quality_control/brahms-raw-corrected-review-reuse-2026-10-03/remaining-pending-bands.json')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=json.loads(queue.read_text());groups=collections.defaultdict(list)
for row in rows:groups[row['id']].append(row)
ids=sys.argv[1:] or list(groups)
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
for sid in ids:
 selected=groups[sid];out=work/sid;out.mkdir(exist_ok=True)
 assert not(out/'index.json').exists(),'Refuse overwriting a frozen rendered set'
 first=selected[0];source=Path(first['source']);assert sha(source)==first['sourceSHA256']
 inv=[]
 for record in first['inventoryFiles']:
  path=Path(record['path']);assert sha(path)==record['sha256'];inv.append(json.loads(path.read_text()))
 old,new=inv
 doc=fitz.open(source);rasters={};panels=[];index=[]
 for r in selected:
  pn=r['page'];page=old['pages'][pn-1];actual=doc[pn-1]
  assert abs(actual.rect.width-page['pageWidth'])<.02 and abs(actual.rect.height-page['pageHeight'])<.02,(sid,pn,'page geometry')
  for data,entry in [(old,r['before']),(new,r['after'])]:
   matched=next(b for p in data['plan']['pages'] if p['pageIndex']==pn-1 for b in p['assignments'] if b['id']==r['bandID'])
   assert matched==entry
  if pn not in rasters:
   factor=min(1800/actual.rect.width,2600/actual.rect.height);pm=actual.get_pixmap(matrix=fitz.Matrix(factor,factor),alpha=False)
   im=Image.frombytes('RGB',(pm.width,pm.height),pm.samples);im.save(out/f'source-page-{pn}.png');rasters[pn]=im
  im=rasters[pn];ys=[r[k][f] for k in ['before','after'] for f in ['topFraction','bottomFraction']]
  halo=18/page['pageHeight'];lo=max(0,int((min(ys)-halo)*im.height));hi=min(im.height,int((max(ys)+halo)*im.height)+1)
  panel=im.crop((0,lo,im.width,hi));d=ImageDraw.Draw(panel)
  for f in ys[:2]:
   y=f*im.height-lo
   for x in range(0,im.width,18):d.line((x,y,min(im.width,x+10),y),fill='#e54545',width=2)
  for f in ys[2:]:d.line((0,f*im.height-lo,im.width,f*im.height-lo),fill='#006eee',width=2)
  width=1440;panel=panel.resize((width,round(panel.height*width/panel.width)))
  q=Image.new('RGB',(width,panel.height+28),'white');ImageDraw.Draw(q).text((5,3),r['bandID']+' | production red / candidate blue',fill='black',font=font);q.paste(panel,(0,28));f=out/(r['bandID']+'.png');q.save(f);panels.append(q)
  index.append({**r,'context':str(f),'contextSHA256':sha(f),'sourceRaster':str(out/f'source-page-{pn}.png'),'sourceRasterSHA256':sha(out/f'source-page-{pn}.png'),'sourceRasterSize':[im.width,im.height],'contextSourcePixelRect':[0,lo,im.width,hi],'displayWidth':width,'displayHeaderHeight':28})
 sheets=[]
 for start in range(0,len(panels),4):
  group=panels[start:start+4];s=Image.new('RGB',(1440,sum(p.height+12 for p in group)),'#ccc');y=0
  for panel in group:s.paste(panel,(0,y));y+=panel.height+12
  path=out/f'sheet-{start//4+1:03d}.png';s.save(path);sheets.append({'path':str(path),'sha256':sha(path),'bands':[r['bandID'] for r in index[start:start+4]]})
 (out/'index.json').write_text(json.dumps(index,indent=2)+'\n');(out/'sheets.json').write_text(json.dumps(sheets,indent=2)+'\n')
 (out/'priority.json').write_text(json.dumps(sorted([{'band':r['bandID'],'page':r['page'],'largestContractionPT':r['largestContractionPT'],'context':r['context']} for r in index],key=lambda x:-x['largestContractionPT']),indent=2)+'\n')
 (out/'bindings.json').write_text(json.dumps({'queueSHA256':sha(queue),'sourceSHA256':sha(source),'inventoryFiles':first['inventoryFiles'],'indexSHA256':sha(out/'index.json'),'sheetManifestSHA256':sha(out/'sheets.json'),'scope':'Original PDF full-page PyMuPDF renders at max1800x2600, matching physical dimensions, with old/new edges overlaid for visual review. Full-page rasters unchanged; colored context copies only. No inference of musical ownership or passed reviews.'},indent=2)+'\n')
 print(sid,len(index),'crops',len(rasters),'source pages',len(sheets),'sheets',flush=True)
