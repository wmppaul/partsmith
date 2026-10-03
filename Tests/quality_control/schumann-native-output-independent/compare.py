from pathlib import Path
import json,hashlib
p=Path('.build/schumann-native-output-independent')
a=Path('.build/ending-local-counterparts/medium-skewed-03-schumann-piano-quintet-op44-imslp-06822/parts')
b=Path('.build/ending-local-app-native-2026-10-03/schumann-parts')
old=json.load(open(a/'manifest.json'));new=json.load(open(b/'manifest.json'))
assert old['sourceSHA256']==new['sourceSHA256'];assert old['rectifications']==new['rectifications']==[]
fields=['sourcePage','sourceRect','system','candidateIDs','staffLineYs','kind'];changed=[];newmarks=[];removedmarks=[];parts=[];overlaps=[];guards=[]
local=json.load(open(p/'frozen-local-ending-guards.json'))['guards']
for part in new['parts']:
 before=next(x for x in old['parts'] if x['id']==part['id']);oldrows={r['id']:r for r in before['placements']};assert set(oldrows)=={r['id'] for r in part['placements']}
 for r in part['placements']:
  o=oldrows[r['id']];diff={k:{'old':o.get(k),'new':r.get(k)} for k in fields if o.get(k)!=r.get(k)}
  if diff:changed.append({'part':part['id'],'row':r['id'],'diff':diff})
  os=[m['sourceRect'] for m in o['sourceMarkings']];ns=[m['sourceRect'] for m in r['sourceMarkings']]
  for m in r['sourceMarkings']:
   if m['sourceRect'] in os:continue
   s,d=m['sourceRect'],m['destinationRect'];src=r['sourceRect'];dst=r['destinationRect'];scale=(dst[2]-dst[0])/(src[2]-src[0]);newmarks.append({'part':part['id'],'row':r['id'],'sourcePage':r['sourcePage'],'system':r['system'],'outputPage':r['outputPage'],'sourceRect':s,'destinationRect':d,'musicSourceRect':src,'musicDestinationRect':dst,'horizontalError':abs(d[0]-(dst[0]+(s[0]-src[0])*scale)),'scaleError':abs((d[2]-d[0])/(s[2]-s[0])-scale),'musicGap':dst[1]-d[3]})
  for m in o['sourceMarkings']:
   if m['sourceRect'] not in ns:removedmarks.append({'part':part['id'],'row':r['id'],'sourceRect':m['sourceRect']})
  if part['id']=='piano':
   for g in local:
    if r['sourcePage']!=g['page'] or r['system']!=g['system']:continue
    s=r['sourceRect'];q=g['guard'];guards.append({'row':r['id'],'role':g['role'],'guard':q,'musicSourceRect':s,'contains':s[0]<=q[0] and s[1]<=q[1] and s[2]>=q[2] and s[3]>=q[3],'sourceMarkings':r['sourceMarkings'],'outputPage':r['outputPage']})
 for n in range(1,part['outputPages']+1):
  rows=sorted([r for r in part['placements'] if r['outputPage']==n],key=lambda r:r['destinationRect'][1]);end=None
  for r in rows:
   rects=[r['destinationRect']]+[m['destinationRect'] for m in r['sourceMarkings']];top=min(x[1] for x in rects);bottom=max(x[3] for x in rects)
   if end and top<end[1]-1e-6:overlaps.append({'part':part['id'],'page':n,'rows':[end[0],r['id']],'amount':end[1]-top})
   end=r['id'],bottom
 parts.append({'part':part['id'],'beforePages':before['outputPages'],'pages':part['outputPages'],'beforePDFSHA256':hashlib.sha256((a/before['file']).read_bytes()).hexdigest(),'PDFSHA256':hashlib.sha256((b/part['file']).read_bytes()).hexdigest()})
r={'beforeManifest':str(a/'manifest.json'),'manifest':str(b/'manifest.json'),'sourceSHA256':new['sourceSHA256'],'parts':parts,'changedMusicRows':changed,'newCopies':newmarks,'removedCopies':removedmarks,'localEndingGuardChecks':guards,'overlaps':overlaps}
(p/'comparison.json').write_text(json.dumps(r,indent=2))
print('PARTS',parts);print('changed main rows',len(changed),'newcopies',len(newmarks),'removedcopies',len(removedmarks),'localguardfails',sum(not x['contains'] for x in guards),'overlaps',len(overlaps))
