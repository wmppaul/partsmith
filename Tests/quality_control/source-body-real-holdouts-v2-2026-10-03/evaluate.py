from pathlib import Path
import json,hashlib,math
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent
D=json.loads((P/'source-cases.json').read_text());C={c['id']:c for c in D['cases']};pages={p['id']:p for p in D['pages']};R=json.loads((P/'results-v2.json').read_text());diag=json.loads((P/'rejection-diagnostics.json').read_text());G={r['id']:r for r in diag['cases']}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(P/'source-cases.json')=='f15934008b238a8e76a284216f3b99084b92de0aa57eae4dca6e965f30ce4d7e'
assert sha(P/'local-line-measurements.json')=='c6b46b3da5ead57cfe0c1a0d3df7afb83a3d05a8d56f14d59650d19434013b65'
rows=[]
for r in R:
 c=C[r['id']];row=dict(id=c['id'],genuineOwnStemHead=c['genuineOwnStemHead'],headKind=c['headKind'],terminalBodyOnTestedSpine=c['terminalBodyOnTestedSpine'],helperAccepted=r['accepted'],selectedBodyAccepted=False,fullNativeErasurePathTested=False,sourceFinding=c['sourceFinding'])
 if r['accepted']:
  w=r['witness'];cx,cy=w['center'];rx,ry=w['radii'];a=math.radians(w['angleDegrees']);hx=math.hypot(rx*math.cos(a),ry*math.sin(a));hy=math.hypot(rx*math.sin(a),ry*math.cos(a));l,t,rr,b=c['bodyROI']
  row.update(witness=w,witnessCenterInsideSelectedBody=l<=cx<rr and t<=cy<b,witnessEnvelope=[cx-hx,cy-hy,cx+hx,cy+hy],witnessWholeEnvelopeInsideSelectedBody=l<=cx-hx and cx+hx<=rr and t<=cy-hy and cy+hy<=b)
  row['selectedBodyAccepted']=row['witnessCenterInsideSelectedBody'] and row['witnessWholeEnvelopeInsideSelectedBody']
 g=G[c['id']];row['diagnosticGuards']=g['guardCounts'];row['helperRemeasuredLines']=g['measuredLines'];row['earlyStaffSpacingRejected']='93' in g['guardCounts'];rows.append(row)
positives=[r for r in rows if r['genuineOwnStemHead']];negative=[r for r in rows if not r['genuineOwnStemHead']]
summary={'sourceCasesSHA256':sha(P/'source-cases.json'),'lineMeasurementsSHA256':sha(P/'local-line-measurements.json'),'resultSHA256':sha(P/'results-v2.json'),'cases':36,'positiveSelectedAccepts':sum(r['selectedBodyAccepted'] for r in positives),'positiveCases':24,'filledAccepts':sum(r['selectedBodyAccepted'] for r in positives if r['headKind']=='filled'),'filledCases':12,'hollowAccepts':sum(r['selectedBodyAccepted'] for r in positives if r['headKind']=='hollow'),'hollowCases':12,'terminalPositiveCases':sum(r['terminalBodyOnTestedSpine'] for r in positives),'terminalPositiveAccepts':sum(r['selectedBodyAccepted'] and r['terminalBodyOnTestedSpine'] for r in positives),'falseBodySpineAccepts':sum(r['helperAccepted'] for r in negative),'negativeCases':12,'earlyStaffSpacingPositiveRejects':[r['id'] for r in positives if r['earlyStaffSpacingRejected']],'wrongBodyAccepts':[r['id'] for r in rows if r['helperAccepted'] and not r['selectedBodyAccepted']],'instrumentationMatchesOriginalResults':diag['instrumentationResultsExact'],'perPage':{p:{'positives':sum(c['pageID']==p and c['genuineOwnStemHead'] for c in C.values()),'selectedAccepts':sum(C[r['id']]['pageID']==p and r['selectedBodyAccepted'] for r in rows),'negatives':sum(c['pageID']==p and not c['genuineOwnStemHead'] for c in C.values()),'falseAccepts':sum(C[r['id']]['pageID']==p and r['helperAccepted'] for r in negative)} for p in pages},'scope':'Helper shape/attachment evidence only; no native connector, crop, export or full-part preservation assertions.'}
(P/'evaluation.json').write_text(json.dumps({'summary':summary,'cases':rows},indent=2)+'\n')
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',16);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',13)
chosen=['M-F01','M-F02','M-F03','M-F04','T-H01','T-H02','T-H03','S-F01','M-H03']
images=[]
for id in chosen:
 c=C[id];r=next(r for r in rows if r['id']==id);box=c['contextROI'];im=Image.open(P/pages[c['pageID']]['nativeRaster']).convert('RGB').crop(box);scale=min(5,360/im.width,400/im.height);ww,hh=round(im.width*scale),round(im.height*scale);im=im.resize((ww,hh),Image.Resampling.NEAREST);canvas=Image.new('RGB',(400,500),'white');origin=((400-ww)//2,50);canvas.paste(im,origin);d=ImageDraw.Draw(canvas)
 def pt(x,y):return(origin[0]+(x-box[0])*scale,origin[1]+(y-box[1])*scale)
 def rect(b,color):d.rectangle([pt(b[0],b[1]),pt(b[2],b[3])],outline=color,width=1)
 rect(c['bodyROI'],'#1976d2');rect(c['spineROI'],'#e47f20')
 label='selected filled head accepted' if r['selectedBodyAccepted'] else 'genuine head missed'
 d.text((10,8),id+' — '+label,font=font,fill='black')
 if r['helperAccepted']:
  w=r['witness'];a=math.radians(w['angleDegrees']);rx,ry=w['radii'];cx,cy=w['center'];curve=[]
  for i in range(129):
   t=i*math.pi/64;x=cx+rx*math.cos(t)*math.cos(a)-ry*math.sin(t)*math.sin(a);y=cy+rx*math.cos(t)*math.sin(a)+ry*math.sin(t)*math.cos(a);curve.append(pt(x,y))
  d.line(curve,fill='#00843d',width=2);d.text((10,466),'Green: accepted fitted body.',font=small,fill='#00843d')
 elif r['earlyStaffSpacingRejected']:
  for y in r['helperRemeasuredLines']:d.line([pt(box[0],y),pt(box[0]+8,y)],fill='#ba1263',width=2)
  d.text((10,466),'Magenta left ticks: helper remeasured rows.',font=small,fill='#ba1263')
 else:d.text((10,466),'No accepted witness. Source body remains genuine.',font=small,fill='black')
 d.text((10,485),'Blue: frozen body ROI. Orange: tested spine corridor.',font=small,fill='black')
 name=f'review/{id}-v2-result.png';canvas.save(P/name);images.append(canvas)
contact=Image.new('RGB',(1200,1500),'#dddddd')
for i,im in enumerate(images):contact.paste(im,((i%3)*400,(i//3)*500))
contact.save(P/'review/v2-result-contact.png')
prior=Path('.build/notehead-provenance-2026-10-03/replay-output/witnesses.json');old=json.loads(prior.read_text());oldpairs={(r['sourceSHA256'],r['sourcePageIndex']+1) for r in old};newpairs={(p['sourceSHA256'],p['physicalPage']) for p in pages.values()};assert not oldpairs&newpairs
(P/'page-independence.json').write_text(json.dumps({'prior12ReplayPath':str(prior),'prior12ReplaySHA256':sha(prior),'priorPages':[{'id':r['id'],'pdfSHA256':r['sourceSHA256'],'physicalPage':r['sourcePageIndex']+1} for r in old],'newPages':[{'id':p['id'],'pdfSHA256':p['sourceSHA256'],'physicalPage':p['physicalPage']} for p in pages.values()],'overlap':[]},indent=2)+'\n')
print(json.dumps(summary,indent=2))
