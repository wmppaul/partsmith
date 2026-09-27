import json,hashlib
from pathlib import Path
w=Path('.build/qc-native-app-worker-v1');configs=json.loads((w/'config.json').read_text());all=[]
def delta(a,b):
 if isinstance(a,(float,int)) and isinstance(b,(float,int)):return abs(a-b)
 if isinstance(a,list) and isinstance(b,list) and len(a)==len(b):return max((delta(x,y) for x,y in zip(a,b)),default=0)
 if isinstance(a,dict) and isinstance(b,dict) and set(a)==set(b):return max((delta(a[k],b[k]) for k in a),default=0)
 return 0 if a==b else float('inf')
for c in configs:
 if not (w/f'{c["id"]}-summary.json').exists():continue
 s=json.loads((w/f'{c["id"]}-summary.json').read_text());native=json.loads((w/f'{c["id"]}-inventory.json').read_text());baseline=json.loads(Path(c['baselineInventory']).read_text());np=json.loads((w/f'{c["id"]}-plan.json').read_text());bp=json.loads(Path(c['baselineManifest']).with_name('plan.json').read_text())
 nb={a['id']:a for p in np['pages'] for a in p['assignments']};bb={a['id']:a for p in bp['pages'] for a in p['assignments']}
 geometryChanges=[];metadataChanges=[]
 for a,b in zip(native['pages'],baseline['pages']):
  g={}
  for k in ['pageIndex','pageWidth','pageHeight','imageWidth','imageHeight','staves','inkComponents']:
   d=delta(a.get(k),b.get(k))
   if d>1e-12:g[k]=d if d<float('inf') else 'structural difference'
  if g:geometryChanges.append({'pageIndex':a['pageIndex'],'changes':g})
  for k in ['sharedHeadings','sharedNavigation']:
   aa=a.get(k) or [];ba=b.get(k) or []
   if delta(aa,ba)>1e-12:metadataChanges.append({'pageIndex':a['pageIndex'],'field':k,'native':aa,'baseline':ba})
 cropChanges=[];copyChanges=[]
 for ident in sorted(set(nb)&set(bb)):
  a,b=nb[ident],bb[ident]
  keys=['candidateIDs','pageIndex','systemIndex','partID','topFraction','bottomFraction','leftFraction','rightFraction']
  if any(delta(a.get(k),b.get(k))>1e-12 for k in keys):cropChanges.append({'id':ident,'native':{k:a.get(k) for k in keys},'baseline':{k:b.get(k) for k in keys}})
  if delta(a.get('sourceMarkings',[]),b.get('sourceMarkings',[]))>1e-12:copyChanges.append({'id':ident,'native':a.get('sourceMarkings',[]),'baseline':b.get('sourceMarkings',[])})
 counts=lambda j:{'headings':sum(len(p.get('sharedHeadings') or []) for p in j['pages']),'navigation':sum(len(p.get('sharedNavigation') or []) for p in j['pages'])}
 r={'id':c['id'],'summary':s,'nativeCounts':counts(native),'baselineCounts':counts(baseline),'pageGeometryChanges':geometryChanges,'metadataChanges':metadataChanges,'bandIDsEqual':set(nb)==set(bb),'nativeBandCount':len(nb),'baselineBandCount':len(bb),'mainCropChanges':cropChanges,'copyChanges':copyChanges,'nativeCopyCount':sum(len(b.get('sourceMarkings',[])) for b in nb.values()),'baselineCopyCount':sum(len(b.get('sourceMarkings',[])) for b in bb.values()),'recordedRectificationsEqual':native['rectifications']==baseline.get('rectifications',[])}
 all.append(r);print(c['id'], 'elapsed',s['elapsedSeconds'],'heartbeatmax',s['heartbeatMaxIntervalSeconds'],'geometrypages',len(geometryChanges),'metadatapages',len(metadataChanges),'maincropchanges',len(cropChanges),'copychanges',len(copyChanges),'counts',r['nativeCounts'],'issues',len(s['issues']))
(w/'comparison.json').write_text(json.dumps(all,indent=2)+'\n')
