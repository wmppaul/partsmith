"""Read immutable source envelopes; retain failures rather than moving guards."""
import hashlib,json,sys
from pathlib import Path
root=Path(__file__).resolve().parent
load=lambda p:json.loads(Path(p).read_text())
old_inventory,old_plan,new_inventory,new_plan=map(load,sys.argv[1:5])
assert old_inventory['sourceSHA256']==new_inventory['sourceSHA256']=='662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a'
assert old_inventory['rectifications']==new_inventory['rectifications']
guards=load(root/'real-source/source-guards.json');oracle=load(root/'real-source/source-oracle.json')
assert hashlib.sha256((root/'real-source/source-guards.json').read_bytes()).hexdigest()=='e097a2b80032e18b85606f4f02c13e24870162857a02bf95f6b58786f2cdbe0c'
def bounds(inventory,plan):
 pages={p['pageIndex']:p for p in inventory['pages']};result={}
 for p in plan['pages']:
  for b in p['assignments']:
   a=pages[b['pageIndex']];w=a['pageWidth'];h=a['pageHeight']
   assert b['id'] not in result
   result[b['id']]=[b['leftFraction']*w,b['topFraction']*h,(1-b['rightFraction'])*w,b['bottomFraction']*h]
 return result
a=bounds(old_inventory,old_plan);b=bounds(new_inventory,new_plan)
def contains(crop,rect):return crop is not None and crop[0]<=rect[0]+1e-9 and crop[1]<=rect[1]+1e-9 and crop[2]>=rect[2]-1e-9 and crop[3]>=rect[3]-1e-9
rows=[]
for g in guards['guards']:
 key=g['bandID'];rows.append({'id':key,'guard':g['rect'],'baselineCrop':a.get(key),'candidateCrop':b.get(key),'baselineContains':contains(a.get(key),g['rect']),'candidateContains':contains(b.get(key),g['rect']),'available':key in a and key in b})
parts={'Violin I':'violin1','Violin II':'violin2','Viola':'viola','Cello':'cello'};local=[]
for g in oracle['protectedMusicalRegions']:
 pn=g['page'];key=f'p{pn}-s{2 if pn==24 else 1}-{parts[g["owner"]]}'
 local.append({'id':key,'frozenSourceBox':g['pdfBounds'],'frozenObservedInkBox':g['observedInkBounds'],'coordinateSpace':g['coordinateSpace'],'baselineBoxContains':contains(a.get(key),g['pdfBounds']),'candidateBoxContains':contains(b.get(key),g['pdfBounds']),'baselineInkBoxContains':contains(a.get(key),g['observedInkBounds']),'candidateInkBoxContains':contains(b.get(key),g['observedInkBounds']),'available':key in a and key in b})
result={'fullGuards':rows,'localEnvelopes':local,'newFullGuardFailures':[r['id'] for r in rows if r['baselineContains'] and not r['candidateContains']],'unchangedFullGuardFailures':[r['id'] for r in rows if not r['baselineContains'] and not r['candidateContains']],'missingBands':[r['id'] for r in rows if not r['available']],'rectificationsEqual':True,'note':'Local ink rectangles are independent supplementary evidence, not replacements for strict full-target guards. The p35 bottom-68 failure remains recorded if still present.'}
Path(sys.argv[5]).write_text(json.dumps(result,indent=2)+'\n')
