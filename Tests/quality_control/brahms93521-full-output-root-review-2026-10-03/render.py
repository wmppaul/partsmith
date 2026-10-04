from pathlib import Path
import subprocess, json, hashlib
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageOps,ImageDraw
root=Path.cwd(); work=root/'.build/brahms93521-full-output-review-2026-10-03'
base=root/'.build/brahms93521-full-workflow-draft-2026-10-03/private-crop-draft-parts'
m=json.loads((base/'manifest.json').read_text())
def one(p):
 d=work/p['id'];d.mkdir(exist_ok=True)
 subprocess.run(['pdftoppm','-png','-r','110',str(base/p['file']),str(d/'page')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 files=sorted(d.glob('page-*.png'), key=lambda x:int(x.stem.split('-')[-1]))
 assert len(files)==p['outputPages']
 sheets=[]
 for start in range(0,len(files),4):
  sheet=Image.new('RGB',(1440,1944),'#d8d8d8');draw=ImageDraw.Draw(sheet)
  for j,f in enumerate(files[start:start+4]):
   im=Image.open(f).convert('RGB');im.thumbnail((700,930));x=10+(j%2)*720;y=36+(j//2)*972
   sheet.paste(im,(x,y));draw.text((x,y-25),f"{p['name']} — output {start+j+1}/{len(files)}",fill='black')
  dest=d/f'sheet-{start//4+1}.png';sheet.save(dest);sheets.append(str(dest.relative_to(root)))
 return {'part':p['id'],'pages':len(files),'sheets':sheets,'pdfSHA256':hashlib.sha256((base/p['file']).read_bytes()).hexdigest(),'placements':[{k:x[k] for k in ['id','sourcePage','system','outputPage']} for x in p['placements']]}
with ThreadPoolExecutor(max_workers=4) as ex: records=list(ex.map(one,m['parts']))
(work/'render-index.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps([{k:v for k,v in x.items() if k!='placements'} for x in records],indent=2))
