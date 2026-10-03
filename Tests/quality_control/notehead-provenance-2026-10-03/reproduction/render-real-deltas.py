from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont
W=Path(__file__).resolve().parent;O=W/'real-source-review';O.mkdir(exist_ok=True)
rows=json.loads((W/'targeted-plan-comparison.json').read_text());src={r['id']:r for r in json.loads((W/'replay-output/witnesses.json').read_text())};pages={r['id']:r['page']for r in json.loads(Path('.build/terminal-body-continuation-2026-10-03/diagnostic-cases.json').read_text())};font=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',18);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();idx=[]
for p in rows:
 if not p['changes']:continue
 im=Image.open(src[p['id']]['imagePath']).convert('RGB');w,h=im.size
 ylo=max(0,int(min(c[t]['topFraction']for c in p['changes']for t in ['before','after'])*h)-35);yhi=min(h,int(max(c[t]['bottomFraction']for c in p['changes']for t in ['before','after'])*h)+35)
 stem=p['id'].replace(':','-');context=O/(stem+'-context.png');im.crop((0,ylo,w,yhi)).save(context)
 for c in p['changes']:
  imgs=[];boxes={};neighbors={}
  for tag in ['before','after']:
   b=c[tag];box=[round(b['leftFraction']*w),round(b['topFraction']*h),round((1-b['rightFraction'])*w),round(b['bottomFraction']*h)];boxes[tag]=box;imgs.append((tag,im.crop(box)))
   neighbors[tag]=[s['id']for s in pages[p['id']]['staves']if s['id']not in b['candidateIDs']and b['topFraction']<=s['staffLineFractions'][0]and b['bottomFraction']>=s['staffLineFractions'][4]]
  canvas=Image.new('RGB',(w,sum(i.height+50 for _,i in imgs)),'#eeeeee');d=ImageDraw.Draw(canvas);y=0
  for tag,i in imgs:d.text((8,y+12),('Baseline'if tag=='before'else'Rejected candidate')+' '+c['bandID']+' '+str(boxes[tag]),font=font,fill='black');y+=45;canvas.paste(i,(0,y));y+=i.height+5
  file=O/(stem+'-'+c['bandID']+'.png');canvas.save(file)
  idx.append({'id':p['id'],'bandID':c['bandID'],'neutralDiagnosticOnly':True,'originalProfileStillUnresolved':True,'sourceSHA256':src[p['id']]['sourceSHA256'],'nativeRasterSHA256':sha(src[p['id']]['imagePath']),'contextImage':str(context),'contextImageSHA256':sha(context),'contextSourcePixels':[0,ylo,w,yhi],'comparisonImage':str(file),'comparisonImageSHA256':sha(file),'displayCropPixels':boxes,'fullNeighborStaffIDs':neighbors,'exactBandChange':c})
(O/'index.json').write_text(json.dumps(idx,indent=2)+'\n');print('Rendered',len(idx),'neutral band comparisons')
