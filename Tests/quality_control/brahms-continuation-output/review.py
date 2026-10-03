#!/usr/bin/env python3
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,hashlib,subprocess,math
from PIL import Image,ImageDraw
import numpy as np
ROOT=Path(__file__).resolve().parents[3];REPORT=Path(__file__).resolve().parent
WORK=ROOT/'.build/brahms-continuation-release-2026-10-03';OUT=WORK/'output-review'
load=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=load(ROOT/'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-auto-endings/manifest.json')
plans={};mans={}
for v in ['baseline','candidate']:
 folder=OUT/f'{v}-parts';mans[v]=load(folder/'manifest.json');plans[v]=load(folder/'plan.json')
 assert plans[v]==load(WORK/v/'brahms-plan.json'),f'{v}: export plan differs from genuine native worker'
 assert mans[v]['rectifications']==old['rectifications'] and mans[v]['sourceSHA256']==old['sourceSHA256']
 proj=load(folder/mans[v]['project']/'project.json')['project'];prior=load(ROOT/'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-auto-endings'/old['project']/'project.json')['project']
 assert proj['projectSettings']==prior['projectSettings'],f'{v}: title/layout settings changed'
 assert {p['name']:p['layoutSettings'] for p in proj['parts']}=={p['name']:p['layoutSettings'] for p in prior['parts']}
 assert sha(folder/mans[v]['project']/'source.pdf')==mans[v]['sourceSHA256']
 for part in mans[v]['parts']:assert sha(folder/part['file'])==part['sha256']

def render(job):
 v,part=job;folder=OUT/'renders'/v/part['id'];folder.mkdir(parents=True,exist_ok=True)
 subprocess.run(['pdftoppm','-r','110','-gray','-png',str(OUT/f'{v}-parts'/part['file']),str(folder/'page')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 pages=sorted(folder.glob('page-*.png'));assert len(pages)==part['outputPages']
 return v,part['id'],pages
rendered={}
with ThreadPoolExecutor(max_workers=4) as pool:
 for v,id,files in pool.map(render,[(v,p) for v in mans for p in mans[v]['parts']]):rendered[v,id]=files
results=[]
for before,after in zip(mans['baseline']['parts'],mans['candidate']['parts']):
 assert before['id']==after['id']
 id=after['id'];changes=[];pages=[]
 for a,b in zip(before['placements'],after['placements']):
  d={k:{'before':a.get(k),'after':b.get(k)} for k in a.keys()|b.keys() if a.get(k)!=b.get(k)}
  if d:changes.append({'id':a['id'],'beforePage':a['outputPage'],'afterPage':b['outputPage'],'fields':d})
 assert len(before['placements'])==len(after['placements'])==151
 for i,(a,b) in enumerate(zip(rendered['baseline',id],rendered['candidate',id]),1):
  aa=np.array(Image.open(a).convert('L'));bb=np.array(Image.open(b).convert('L'));assert aa.shape==bb.shape
  yy,xx=np.where(aa!=bb);box=None if len(xx)==0 else [int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
  pages.append({'page':i,'pixelIdentical':len(xx)==0,'changedPixels':len(xx),'differenceBounds':box,'baselineRasterSHA256':sha(a),'candidateRasterSHA256':sha(b)})
  if len(xx):
   ca=Image.open(a).convert('RGB');cb=Image.open(b).convert('RGB');canvas=Image.new('RGB',(ca.width+cb.width,ca.height+36),'white');canvas.paste(ca,(0,36));canvas.paste(cb,(ca.width,36));d=ImageDraw.Draw(canvas);d.text((12,10),f'{after["name"]} page {i} — baseline',fill='black');d.text((ca.width+12,10),'candidate',fill='black');canvas.save(REPORT/f'{id}-page-{i:02d}-comparison.png')
 imgs=[Image.open(p).convert('RGB') for p in rendered['candidate',id]]
 thumbw=280;thumbh=math.ceil(imgs[0].height*thumbw/imgs[0].width);cols=4;rows=math.ceil(len(imgs)/cols)
 sheet=Image.new('RGB',(cols*thumbw,rows*(thumbh+28)),(232,232,232));d=ImageDraw.Draw(sheet)
 for i,im in enumerate(imgs):
  im.thumbnail((thumbw,thumbh));x=i%cols*thumbw;y=i//cols*(thumbh+28);sheet.paste(im,(x,y+28));d.text((x+8,y+8),f'{after["name"]} · {i+1}',fill='black')
 sheet.save(REPORT/f'{id}-all-pages.png')
 results.append({'id':id,'name':after['name'],'pagesBefore':before['outputPages'],'pagesAfter':after['outputPages'],'bands':after['bandCount'],'copies':sum(len(p['sourceMarkings']) for p in after['placements']),'systemsPerPageBefore':before['systemsPerPage'],'systemsPerPageAfter':after['systemsPerPage'],'placementChanges':changes,'rasterPages':pages})
summary={'sourcePages':39,'rectifications':len(mans['candidate']['rectifications']),'bands':sum(r['bands'] for r in results),'copies':sum(r['copies'] for r in results),'pagesBefore':sum(r['pagesBefore'] for r in results),'pagesAfter':sum(r['pagesAfter'] for r in results),'rasterPagesCompared':sum(len(r['rasterPages']) for r in results),'identicalRasterPages':sum(p['pixelIdentical'] for r in results for p in r['rasterPages']),'changedRasterPages':[{'part':r['id'],'page':p['page'],'differenceBounds':p['differenceBounds']} for r in results for p in r['rasterPages'] if not p['pixelIdentical']],'parts':results}
(REPORT/'comparison.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='parts'},indent=2))
for r in results:print(r['name'],r['pagesBefore'],r['pagesAfter'],'placement changes',len(r['placementChanges']),'page grouping equal',r['systemsPerPageBefore']==r['systemsPerPageAfter'])
