from pathlib import Path
import json,hashlib
import pymupdf as f
from PIL import Image,ImageDraw,ImageFont
P=Path('.build/erlkonig-complete-2026-10-03');R=P/'independent-review';F=P/'reviewed-parts';B=R/'baseline-exports';old=json.loads((B/'manifest.json').read_text());new=json.loads((F/'manifest.json').read_text());font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',16)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert new['sourceSHA256']==old['sourceSHA256']==sha(Path(new['source']))
assert new['profile']==old['profile'];(R/'reviewed-output').mkdir(exist_ok=True);(R/'reviewed-rows').mkdir(exist_ok=True)
changes=[];pages=[];bindings={str(F/'manifest.json'):sha(F/'manifest.json'),str(F/'plan.json'):sha(F/'plan.json')};src=f.open(new['source'])
for po,pn in zip(old['parts'],new['parts']):
 assert po['id']==pn['id'];assert len(po['placements'])==len(pn['placements'])==48
 d=f.open(F/pn['file']);bindings[str(F/pn['file'])]=sha(F/pn['file'])
 for i,page in enumerate(d):
  pix=page.get_pixmap(matrix=f.Matrix(2,2),alpha=False);im=Image.frombytes('RGB',[pix.width,pix.height],pix.samples);name=f'{pn["id"]}-p{i+1:02}.png';im.save(R/'reviewed-output'/name)
  before=Image.open(R/'output'/name);same=before.size==im.size and before.tobytes()==im.tobytes();pages.append({'partID':pn['id'],'page':i+1,'pixelIdentical':same,'image':f'reviewed-output/{name}','imageSHA256':sha(R/'reviewed-output'/name)})
 for a,b in zip(po['placements'],pn['placements']):
  for k in ['id','candidateIDs','sourcePage','system','kind','generatedRest','staffLineYs']:assert a.get(k)==b.get(k),(k,a['id'])
  oldmarks=[c['sourceRect'] for c in a['sourceMarkings']];newmarks=[c['sourceRect'] for c in b['sourceMarkings']]
  if a['sourceRect']!=b['sourceRect'] or oldmarks!=newmarks:
   record={'id':a['id'],'partID':pn['id'],'sourcePage':a['sourcePage'],'system':a['system'],'oldSourceRect':a['sourceRect'],'newSourceRect':b['sourceRect'],'oldSourceCopies':oldmarks,'newSourceCopies':newmarks,'oldOutputPage':a['outputPage'],'newOutputPage':b['outputPage']};changes.append(record)
   top=min([a['sourceRect'][1],b['sourceRect'][1]]+[m[1] for m in oldmarks+newmarks]);bot=max([a['sourceRect'][3],b['sourceRect'][3]]+[m[3] for m in oldmarks+newmarks]);sp=src[a['sourcePage']-1].get_pixmap(matrix=f.Matrix(2,2),clip=f.Rect(0,max(0,top-8),595.28,bot+8),alpha=False);raw=Image.frombytes('RGB',[sp.width,sp.height],sp.samples)
   r=list(b['destinationRect'])
   for m in b['sourceMarkings']:
    v=m['destinationRect'];r=[min(r[0],v[0]),min(r[1],v[1]),max(r[2],v[2]),max(r[3],v[3])]
   pp=d[b['outputPage']-1].get_pixmap(matrix=f.Matrix(2,2),clip=f.Rect(r[0],r[1]-2,r[2],r[3]+2),alpha=False);out=Image.frombytes('RGB',[pp.width,pp.height],pp.samples);out=out.resize((raw.width,round(out.height*raw.width/out.width)),Image.Resampling.LANCZOS)
   canvas=Image.new('RGB',(raw.width*2+12,max(raw.height,out.height)+30),'white');canvas.paste(raw,(0,30));canvas.paste(out,(raw.width+12,30));dr=ImageDraw.Draw(canvas);dr.text((4,4),'Complete original source context',font=font,fill='black');dr.text((raw.width+16,4),a['id']+' actual corrected output',font=font,fill='black');name=a['id']+'.png';canvas.save(R/'reviewed-rows'/name);record['image']=f'reviewed-rows/{name}';record['imageSHA256']=sha(R/'reviewed-rows'/name)
expected={'p1-s1-voice','p1-s1-piano','p2-s3-voice','p4-s4-voice','p4-s4-piano','p6-s2-voice'};assert set(c['id'] for c in changes)==expected
assert sum(x['id']=='p1-s1-voice' for x in changes)==1
by={a['id']:a for p in new['parts'] for a in p['placements']}
G=json.loads((R/'voice-top-source-obligations.json').read_text());checks=[]
for g in G['rows']:
 id=f'p{g["page"]}-s{g["system"]}-voice';a=by[id];r=a['sourceRect'];e=g['targetUpperInkEnvelope'];before=next(x for p in old['parts'] for x in p['placements'] if x['id']==id);checks.append({'id':id,'topSourceObligationContained':r[0]<=e[0] and r[1]<=e[1] and r[2]>=e[2] and r[3]>=e[3],'other3EdgesUnchanged':all(r[i]==before['sourceRect'][i] for i in [0,2,3]),'sourceGuardSHA256':sha(R/'voice-top-source-obligations.json')})
g=json.loads((R/'hairpin-source-obligation.json').read_text());r=by['p4-s4-piano']['sourceRect'];e=g['guardUnion'];checks.append({'id':'p4-s4-piano','completeSourceStrokeEnvelopeContained':r[0]<=e[0] and r[1]<=e[1] and r[2]>=e[2] and r[3]>=e[3],'sourceGuardSHA256':sha(R/'hairpin-source-obligation.json')})
assert all(all(v is True for k,v in x.items() if k.endswith('Contained') or k=='other3EdgesUnchanged') for x in checks)
J={'bindings':bindings,'same48OrderedSystemsBothParts':True,'allSourceAssignmentsAndGeneratedRestCountsExact':True,'changes':changes,'sourceObligationChecks':checks,'outputPages':pages,'visuallyReviewed':False};(R/'reviewed-comparison.json').write_text(json.dumps(J,indent=2)+'\n');print(json.dumps({'changes':[x['id'] for x in changes],'changedPages':[f'{x["partID"]}:{x["page"]}' for x in pages if not x['pixelIdentical']],'bindings':bindings},indent=2))
