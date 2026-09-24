from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps
p=Path('.build/qc-ending-brackets');namespace={};exec((p/'detect_geometry.py').read_text().split('results=[]; pageRecords=[]')[0],namespace);detect=namespace['geometry']
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf',40)
controls=[];candidates=[]
for kind in ['shifted-prose','unpaired-roman-i','prose-in-number-cell']:
 im=Image.new('L',(620,180),255);d=ImageDraw.Draw(im);d.line([(40,72),(40,30),(220,30),(220,72)],fill=0,width=2)
 if kind=='shifted-prose':d.text((128,39),'I',font=font,fill=0,anchor='lt')
 elif kind=='unpaired-roman-i':d.text((54,39),'I',font=font,fill=0,anchor='lt')
 else:d.text((52,39),'Chapter I',font=font,fill=0,anchor='lt')
 if kind!='unpaired-roman-i':
  d.line([(250,72),(250,30),(480,30)],fill=0,width=2);d.text((265,39),'2.',font=font,fill=0,anchor='lt')
 imagepath=p/f'negative-{kind}.png';im.save(imagepath);gray=np.array(im);props=detect(gray,20)
 for i,g in enumerate(props):
  x,y,x1,_=g['line'];bottom=max(y+44,g['hook'][3]+3);box=[int(x+8),int(y+3),int(x+66),int(bottom)];num=im.crop(box);num=num.resize((num.width*4,num.height*4));num=ImageOps.expand(num,border=60,fill=255);path=p/'candidates'/f'negative-{kind}-{i}.png';num.save(path);candidates.append({'id':f'{kind}-{i}','numberImage':str(path),'case':kind,'line':g['line'],'hook':g['hook']})
 controls.append({'id':kind,'image':str(imagepath),'geometryProposalCount':len(props),'expectedPairedEndings':0})
(p/'synthetic-negative-candidates.json').write_text(json.dumps({'candidates':candidates,'controls':controls},indent=2)+'\n');print(controls)
