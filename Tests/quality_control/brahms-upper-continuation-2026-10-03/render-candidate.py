from pathlib import Path
import json,hashlib
import fitz
from PIL import Image,ImageDraw,ImageFont
P=Path('.build/brahms-remaining-2026-10-03/upper-review');pdf=Path('output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-preservation/rectified-review-source.pdf');assert hashlib.sha256(pdf.read_bytes()).hexdigest()=='1a3ef93cd28c5539a4732b185a6489ea4a93e16382266c387657d64e3400feb8'
doc=fitz.open(pdf);rows=json.loads((P/'candidate-v1/comparison.json').read_text())['changedBands'];f=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22);out=[]
for r in rows:
 ims=[]
 for k in ['before','after']:
  pix=doc[27].get_pixmap(matrix=fitz.Matrix(4,4),clip=fitz.Rect(r[k]),alpha=False);im=Image.frombytes('RGB',[pix.width,pix.height],pix.samples);label=Image.new('RGB',(im.width,im.height+35),'white');label.paste(im,(0,35));ImageDraw.Draw(label).text((5,5),r['id']+' '+k+' y='+str(r[k][1:4:2]),font=f,fill='black');ims.append(label)
 sheet=Image.new('RGB',(max(i.width for i in ims),sum(i.height for i in ims)+10),'#dddddd');sheet.paste(ims[0],(0,0));sheet.paste(ims[1],(0,ims[0].height+10));path=P/'candidate-v1'/f'{r["id"]}-source-comparison.png';sheet.save(path);out.append({'id':r['id'],'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(P/'candidate-v1/source-review-images.json').write_text(json.dumps({'correctedSourcePath':str(pdf),'correctedSHA256':hashlib.sha256(pdf.read_bytes()).hexdigest(),'images':out,'pixelsPerPDFPoint':4,'sourcePixelsUnmodified':True,'notAnExport':True},indent=2)+'\n')
