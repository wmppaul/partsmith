from pathlib import Path
import json,hashlib,pymupdf as fitz
from PIL import Image,ImageDraw
ROOT=Path.cwd(); W=ROOT/'.build/qc-schumann270922-review'; ID='lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922'; BASE=ROOT/'.build/auto-qc/connector8-harmonic/corpus'/ID
m=json.load(open(BASE/'parts/manifest.json')); source=ROOT/'sample_scores/lightly_skewed/05_schumann_frauenliebe_und_leben_op42_imslp_270922.pdf'; assert hashlib.sha256(source.read_bytes()).hexdigest()==m['sourceSHA256'];d=fitz.open(source)
provenance={'source':str(source),'sourceSHA256':m['sourceSHA256'],'sourcePages':len(d),'manifest':str(BASE/'parts/manifest.json'),'manifestSHA256':hashlib.sha256((BASE/'parts/manifest.json').read_bytes()).hexdigest(),'outputs':[]}
for pi,p in enumerate(d):
 z=2.5;pm=p.get_pixmap(matrix=fitz.Matrix(z,z)); im=Image.frombytes('RGB',(pm.width,pm.height),pm.samples);im.save(W/f'source-{pi+1:02}.png');draw=ImageDraw.Draw(im)
 for part in m['parts']:
  color=(20,80,220) if part['id']=='voice' else (215,45,35)
  for b in part['placements']:
   if b['sourcePage']!=pi+1:continue
   x0,y0,x1,y1=b['sourceRect'];draw.line((0,y0*z,im.width,y0*z),fill=color,width=2);draw.line((0,y1*z,im.width,y1*z),fill=color,width=2)
   draw.text((2,y0*z+2),f"{part['id']} s{b['system']} -> out {b['outputPage']}",fill=color,stroke_width=0)
 im.save(W/f'edges-{pi+1:02}.png')
for part in m['parts']:
 f=BASE/'parts'/part['file'];out=fitz.open(f);provenance['outputs'].append({'part':part['id'],'pdf':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'pages':len(out),'bands':part['bandCount']})
 for pi,p in enumerate(out):p.get_pixmap(matrix=fitz.Matrix(2,2)).save(W/f"{part['id']}-{pi+1:02}.png")
(W/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
for part in m['parts']:
 for page in range(1,part['outputPages']+1):
  print(part['id'],page,', '.join(b['id'] for b in part['placements'] if b['outputPage']==page))
