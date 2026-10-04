from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
W=Path('.build/brahms-monotone-independent-2026-10-03');R=W/'ending-review';rows=json.loads((W/'ending-expansion-rows.json').read_text());rows=rows.get('rows',rows)if isinstance(rows,dict)else rows
index={r['band']:r for r in json.loads((W/'context-index.json').read_text())};sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();panels=[];bind=[]
for r in rows:
 b=r['band'];i=index[b];p=Path('.build/brahms-source-span-full-replay-2026-10-03/rasters')/f"page-{r['page']}.png";im=Image.open(p).convert('RGB');lo,hi=i['sourcePixelRange'];assert im.height==i['sourceHeight'];im=im.crop((0,lo,im.width,hi));im=im.resize((1440,round(im.height*1440/im.width)));panel=Image.new('RGB',(1440,im.height+40),'white');panel.paste(im,(0,40));ImageDraw.Draw(panel).text((5,5),b+' | unannotated original source',fill='black',font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22));panels.append(panel);bind.append({**r,'source':str(p),'sourceSHA256':sha(p),'annotatedPanel':i['path'],'annotatedSHA256':sha(i['path']),'sourcePixelRange':i['sourcePixelRange']})
for k in range(0,len(panels),4):
 batch=panels[k:k+4];im=Image.new('RGB',(1440,sum(p.height for p in batch)+20*(len(batch)-1)),'#ccc');y=0
 for p in batch:im.paste(p,(0,y));y+=p.height+20
 im.save(R/f'original-group-{k//4+1}.png')
(R/'bindings-before-review.json').write_text(json.dumps(bind,indent=2)+'\n');print(len(bind))
