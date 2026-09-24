"""Scratch only. Select ending pairs; the source pixels, not these labels, are output.
Literal I is retained as uncertain OCR evidence and is never trusted without a
closed bracket plus a geometrically adjacent exact printed 2 candidate.
"""
from pathlib import Path
import json,copy
from collections import Counter
import numpy as np
import pymupdf as fitz
P=Path('.build/qc-ending-brackets')
v=json.loads((P/'all-padded-candidates.json').read_text()); cs=v['candidates'];ocr={mode:{r['id']:r['lines'] for r in json.loads((P/f'all-padded-{mode}.json').read_text())} for mode in ['accurate','fast']}
specs={'kv498':('sample_scores/normal/01_chamber/mozart_trio_eb_major_kv498_score.pdf','.build/auto-qc/kv498-headings/menuetto-inventory.json','.build/auto-qc/kv498-headings/menuetto-parts/manifest.json'),'brahms93521':('.build/auto-qc/candidate8-directions/quartet93521-parts/rectified-review-source.pdf','.build/qc-repeat-symbols/native/candidate8-headings-navigation-destinations.json','.build/auto-qc/candidate8-directions/quartet93521-parts/manifest.json')}
inv={k:{p['pageIndex']+1:p for p in json.loads(Path(s[1]).read_text())['pages']} for k,s in specs.items()};man={k:json.loads(Path(s[2]).read_text()) for k,s in specs.items()};order={k:{key:i for i,key in enumerate(sorted({(b['sourcePage'],b['system']) for p in m['parts'] for b in p['placements']}))} for k,m in man.items()}
groups=[]
for c in cs:
 p=inv[c['score']][c['sourcePage']];s=next(s for s in p['staves'] if s['id']==c['anchorStaffID']);space=(s['staffLineFractions'][4]-s['staffLineFractions'][0])*p['pageHeight']/4;c['spacePoints']=space
 group=next((g for g in groups if (g['score'],g['sourcePage'],g['system'])==(c['score'],c['sourcePage'],c['system']) and abs(g['bounds'][0]-c['bounds'][0])<space*.4 and abs(g['bounds'][1]-c['bounds'][1])<space*.5 and min(g['bounds'][2],c['bounds'][2])-max(g['bounds'][0],c['bounds'][0])>.8*min(g['bounds'][2]-g['bounds'][0],c['bounds'][2]-c['bounds'][0])),None)
 if group:
  group['members'].append(c['id']);group['bounds']=[min(group['bounds'][0],c['bounds'][0]),min(group['bounds'][1],c['bounds'][1]),max(group['bounds'][2],c['bounds'][2]),max(group['bounds'][3],c['bounds'][3])]
 else:group=copy.deepcopy(c);group['members']=[c['id']];groups.append(group)
labeled=[]
for g in groups:
 evidence=[]
 for ident in g['members']:
  for mode in ['accurate','fast']:
   lines=ocr[mode][ident]
   if len(lines)!=1:continue
   l=lines[0];text=l['text'].strip(' .')
   if text in ['1','2'] and l['confidence']>=.5:evidence.append(dict(id=ident,mode=mode,label=text,**l))
   elif text=='I' and mode=='fast' and l['confidence']>=.5:evidence.append(dict(id=ident,mode=mode,label='ambiguous-first',**l))
 if not evidence:continue
 labels={e['label'] for e in evidence}; g['evidence']=evidence
 if '1' in labels and '2' in labels:g['rejection']='conflicting numeral';continue
 g['role']='second' if '2' in labels else 'first' if '1' in labels or 'ambiguous-first' in labels else None
 g['systemOrder']=order[g['score']][(g['sourcePage'],g['system'])]
 # Proposals must belong to the verified physical first staff of this system.
 page=inv[g['score']][g['sourcePage']];bands=[b for p in man[g['score']]['parts'] for b in p['placements'] if (b['sourcePage'],b['system'])==(g['sourcePage'],g['system'])];ids=[x for b in bands for x in b['candidateIDs']]; staves=page['staves'];first=min((s for s in staves if s['id'] in ids),key=lambda s:s['staffLineFractions'][0]);g['verifiedFirstStaff']=len(ids)==len(set(ids)) and g['anchorStaffID']==first['id'];g['pageWidth']=page['pageWidth'];labeled.append(g)
# Independently measure the first bracket's right hook; endpoint ink alone is
# insufficient. This also obtains the full line/hook envelope for source copying.
for score in specs:
 d=fitz.open(specs[score][0])
 for pageNumber in sorted({g['sourcePage'] for g in labeled if g['score']==score}):
  page=d[pageNumber-1];scale=min(2400/page.rect.width,3500/page.rect.height);pix=page.get_pixmap(matrix=fitz.Matrix(scale,scale),colorspace=fitz.csGRAY);gray=np.frombuffer(pix.samples,np.uint8).reshape(pix.height,pix.width);sx=pix.width/page.rect.width;sy=pix.height/page.rect.height;black=gray<170
  for g in [g for g in labeled if g['score']==score and g['sourcePage']==pageNumber]:
   sp=g['spacePoints'];start=(g['bounds'][1]+sp*.3)*sy;end=(g['bounds'][2]-sp*.3)*sx;space=sp*sy;best=0
   for x in range(max(0,int(end-space*.4)),min(pix.width,int(end+space*.4)+1)):
    last=int(start);miss=0
    for y in range(int(start+space*.2),min(pix.height,int(start+space*3.5))):
     if black[y,max(0,x-1):min(pix.width,x+2)].any():last=y;miss=0
     else:miss+=1
     if miss>max(1,int(space*.08)):break
    length=last-start
    if length>=space*.65:best=max(best,last)
   g['closedRight']=bool(best);g['rightHookBottom']=best/sy if best else None
   # Small generic safety margin; do not stretch the crop to a golden box.
   original=g['bounds'];g['copyBounds']=[original[0]-sp*.35,original[1]-sp*.35,original[2]+sp*.35,max(original[3],best/sy+sp*.35 if best else original[3])+sp*.25]
def pairable(first,second):
 if first['score']!=second['score'] or not first['verifiedFirstStaff'] or not second['verifiedFirstStaff'] or not first['closedRight']:return False
 gap=second['systemOrder']-first['systemOrder'];sp=max(first['spacePoints'],second['spacePoints'])
 if gap==0:return abs(second['bounds'][0]-first['bounds'][2])<=sp*1.8 and abs(first['bounds'][1]-second['bounds'][1])<=sp*1.2
 if gap==1:return first['bounds'][2]>.7*first['pageWidth'] and second['bounds'][0]<.4*second['pageWidth']
 return False
pairs=[]
for first in [g for g in labeled if g['role']=='first']:
 choices=[g for g in labeled if g['role']=='second' and pairable(first,g)]
 if len(choices)==1:pairs.append({'first':first,'second':choices[0]})
selected={m for pair in pairs for role in ['first','second'] for m in pair[role]['members']};rejected=[g for g in labeled if not any(m in selected for m in g['members'])]
tests=[]
def test(name,value):tests.append({'name':name,'passed':bool(value)});assert value,name
for pair in pairs:
 a,b=pair['first'],pair['second'];test('source pair '+a['id'],pairable(a,b))
 aa=copy.deepcopy(a);aa['verifiedFirstStaff']=False;test('unresolved ownership '+a['id'],not pairable(aa,b))
 aa=copy.deepcopy(a);aa['closedRight']=False;test('unclosed line with Roman I '+a['id'],not pairable(aa,b))
 bb=copy.deepcopy(b);bb['systemOrder']=a['systemOrder']+2;test('unpaired distant 2 '+a['id'],not pairable(a,bb))
 if a['systemOrder']==b['systemOrder']:
  bb=copy.deepcopy(b);bb['bounds']=[z+15*a['spacePoints'] if i in [0,2] else z for i,z in enumerate(bb['bounds'])];test('shifted Roman I/prose alignment '+a['id'],not pairable(a,bb))
 else:
  bb=copy.deepcopy(b);bb['bounds'][0]=.8*bb['pageWidth'];test('next-system 2 at wrong side '+a['id'],not pairable(a,bb))
report={'status':'scratch paired brackets; copied source bounds require independent review','inputPageCount':len(v['pages']),'inputSystemCount':sum(p['systems'] for p in v['pages']),'geometryProposalCount':len(cs),'mergedProposalCount':len(groups),'numeralCandidateCount':len(labeled),'pairCount':len(pairs),'pairs':pairs,'unpairedNumericFalsePositives':rejected,'tests':tests,'sourcePages':v['pages']}
(P/'paired-endings-v1.json').write_text(json.dumps(report,indent=2)+'\n');print('counts',len(cs),len(groups),len(labeled),len(pairs),'unpaired',len(rejected),'tests',len(tests))
for p in pairs:print(p['first']['score'],p['first']['sourcePage'],p['first']['system'],'->',p['second']['sourcePage'],p['second']['system'],p['first']['copyBounds'],p['second']['copyBounds'])
for g in rejected:print('REJECT',g['id'],[e['text'] for e in g['evidence']])
