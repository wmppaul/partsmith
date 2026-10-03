from pathlib import Path
from PIL import Image, ImageDraw
import json,math,hashlib
r=Path('.build/source-body-provenance-v2-2026-10-03')
inputs={x['id']:x for x in json.loads(Path('Tests/quality_control/notehead-provenance-independent-2026-10-03/helper-inputs.json').read_text())['cases']}
results=json.loads((r/'development22-results.json').read_text())
out=r/'development-review';out.mkdir(exist_ok=True)
index=[]
for result in results:
 if not result['accepted']:continue
 c=inputs[result['id']];w=result['witness'];source=Path(c['imagePath']);im=Image.open(source).convert('RGB')
 cx,cy=w['center'];rx,ry=w['radii'];ang=math.radians(w['angleDegrees']);space=c['staffSpace']
 box=[int(cx-space*3),int(cy-space*3),int(cx+space*3),int(cy+space*3)]
 raw=im.crop(box).resize((480,480),Image.Resampling.NEAREST);marked=raw.copy();d=ImageDraw.Draw(marked)
 sx=480/(box[2]-box[0]);sy=480/(box[3]-box[1]);conv=lambda x,y:((x-box[0])*sx,(y-box[1])*sy)
 points=[conv(cx+rx*math.cos(t)*math.cos(ang)-ry*math.sin(t)*math.sin(ang),cy+rx*math.cos(t)*math.sin(ang)+ry*math.sin(t)*math.cos(ang)) for t in [i*2*math.pi/128 for i in range(129)]]
 d.line(points,fill=(20,160,60),width=2)
 for x in [c['strokeLeft'],c['strokeRight']]:d.line([conv(x,box[1]),conv(x,box[3])],fill=(235,130,0),width=2)
 panel=Image.new('RGB',(960,525),'white');panel.paste(raw,(0,45));panel.paste(marked,(480,45));d=ImageDraw.Draw(panel)
 d.text((8,5),result['id'],fill='black');d.text((8,24),'Original native source',fill='black');d.text((488,24),'Source-derived ellipse (green), exact tested spine (orange)',fill='black')
 path=out/(result['id']+'.png');panel.save(path)
 index.append({'id':result['id'],'imagePath':str(source),'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'nativeContextBounds':box,'witness':w,'panelPath':str(path),'panelSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),'fullNativeErasurePathTested':False})
(out/'index.json').write_text(json.dumps(index,indent=2)+'\n')
