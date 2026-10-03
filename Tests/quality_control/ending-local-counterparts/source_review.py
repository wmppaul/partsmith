import json, hashlib
from pathlib import Path
from PIL import Image, ImageDraw
id='medium-skewed-03-schumann-piano-quintet-op44-imslp-06822'
w=Path('.build/ending-local-counterparts')/id; origin=Path('.build/ending-corpus-2026-10-03')/id
r=Path('Tests/quality_control/ending-local-counterparts/source-review')
cps=json.loads((w/'counterparts.json').read_text()); data=json.loads((origin/'result.json').read_text()); pages={p['pageIndex']:p for p in data['analyses']}
plan=json.loads((origin/'plan.json').read_text()); groups={}
for cp in cps:
 for m in cp['members']: groups.setdefault((m['sourcePageIndex'],m['sourceSystemIndex']),[]).append(m)
index=[]
for (pi,si),members in sorted(groups.items()):
 p=pages[pi];im=Image.open(origin/f'source-page-{pi+1:03d}.png').convert('RGB');width,height=im.size
 band=next(b for pp in plan['pages'] for b in pp['assignments'] if b['partID']=='piano' and b['pageIndex']==pi and b['systemIndex']==si)
 dr=ImageDraw.Draw(im)
 for m in members:
  b=m['bounds'];dr.rectangle((b[0]*width,b[1]*height,b[2]*width,b[3]*height),outline='green',width=3)
 dr.line((0,band['topFraction']*height,width,band['topFraction']*height),fill='red',width=2)
 dr.line((0,band['bottomFraction']*height,width,band['bottomFraction']*height),fill='red',width=2)
 top=max(0,int(band['topFraction']*height)-20);bottom=min(height,int(band['bottomFraction']*height)+20)
 im=im.crop((0,top,width,bottom));dest=r/f'p{pi+1}-s{si+1}-piano-local.png';im.save(dest)
 index.append({'sourcePage':pi+1,'system':si+1,'image':str(dest),'members':members,'mainCrop':[band['leftFraction'],band['topFraction'],1-band['rightFraction'],band['bottomFraction']]})
Path('Tests/quality_control/ending-local-counterparts/source-rows.json').write_text(json.dumps(index,indent=2)+'\n')
print('\n'.join(x['image'] for x in index))
