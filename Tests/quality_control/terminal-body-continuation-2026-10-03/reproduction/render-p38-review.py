from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parent
rows=json.loads((R/'rejected-v1/targeted-plan-comparison.json').read_text())
p=next(x for x in rows if x['id']=='corrected-brahms93521:p38')
case=next(x for x in json.loads((R/'diagnostic-cases.json').read_text())if x['id']==p['id'])
im=Image.open(case['imagePath']).convert('RGB');W,H=im.size
out=R/'rejected-v1/p38-review';out.mkdir(exist_ok=True)
for ch in p['changedBands']:
 canv=Image.new('RGB',(W,520),'#dddddd');d=ImageDraw.Draw(canv); y=0
 for tag in ['before','after']:
  b=ch[tag]; box=(round(b['leftFraction']*W),round(b['topFraction']*H),round((1-b['rightFraction'])*W),round(b['bottomFraction']*H))
  d.text((8,y+8),('Production'if tag=='before'else'Rejected v1')+' '+ch['bandID']+' source '+str(box),fill='black');y+=30
  crop=im.crop(box);canv.paste(crop,(0,y));y+=crop.height+15
 canv.crop((0,0,W,y)).save(out/(ch['bandID']+'.png'))
# Untouched whole first system for musical context; bands never define this crop.
im.crop((0,130,W,430)).save(out/'source-first-system.png')
