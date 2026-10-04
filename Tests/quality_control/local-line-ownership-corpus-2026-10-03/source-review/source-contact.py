from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
W=Path('.build/local-line-ownership-corpus-2026-10-03/source-review');font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();out=[]
for d in sorted(p for p in W.iterdir()if p.is_dir()):
 pages=sorted(d.glob('source-page-*.png'),key=lambda p:int(p.stem.split('-')[-1]));records=[]
 for k in range(0,len(pages),4):
  batch=pages[k:k+4];tiles=[]
  for p in batch:
   im=Image.open(p).convert('RGB');im.thumbnail((900,1275));tile=Image.new('RGB',(900,1305),'white');tile.paste(im,((900-im.width)//2,30));ImageDraw.Draw(tile).text((5,4),p.stem,fill='black',font=font);tiles.append(tile)
  result=Image.new('RGB',(1800,1305*((len(tiles)+1)//2)),'#ddd')
  for i,im in enumerate(tiles):result.paste(im,((i%2)*900,(i//2)*1305))
  p=d/f'original-source-contact-{k//4+1}.png';result.save(p);records.append({'path':str(p),'sha256':sha(p),'sourcePNGs':[{'path':str(q),'sha256':sha(q)}for q in batch]})
 (d/'source-contacts.json').write_text(json.dumps(records,indent=2)+'\n');out.extend(records)
(W/'source-contacts.json').write_text(json.dumps(out,indent=2)+'\n')
print(len(out),'original source contact sheets')
