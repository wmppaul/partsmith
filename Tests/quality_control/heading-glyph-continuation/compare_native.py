#!/usr/bin/env python3
"""Exact comparison; never discard OCR/crop/ownership changes as noise."""
import json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
RUN=ROOT/'.build/heading-glyph-continuation-2026-10-03/native'
def load(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def differences(a,b,path=''):
    if type(a)!=type(b):return [{'path':path,'before':a,'after':b}]
    if isinstance(a,dict):
        return sum((differences(a[k],b[k],path+'/'+k) if k in a and k in b else [{'path':path+'/'+k,'before':a.get(k),'after':b.get(k)}] for k in sorted(a.keys()|b.keys())),[])
    if isinstance(a,list):
        if len(a)!=len(b):return [{'path':path,'before':a,'after':b}]
        return sum((differences(x,y,path+'/'+str(i)) for i,(x,y) in enumerate(zip(a,b))),[])
    return [] if a==b else [{'path':path,'before':a,'after':b}]
results=[]
for c in load(RUN/'config.json'):
    before=RUN/'baseline'/c['id'];after=RUN/'candidate'/c['id']
    if not (after/'summary.json').exists():continue
    bi,ai=load(before/'inventory.json'),load(after/'inventory.json');bp,ap=load(before/'plan.json'),load(after/'plan.json')
    bband=[b for p in bp['pages'] for b in p['assignments']];aband=[b for p in ap['pages'] for b in p['assignments']]
    heading_changes=[{'pageIndex':b['pageIndex'],'before':b.get('sharedHeadings',[]),'after':a.get('sharedHeadings',[])} for b,a in zip(bi['pages'],ai['pages']) if b.get('sharedHeadings',[])!=a.get('sharedHeadings',[])]
    strip=lambda inventory:{**inventory,'pages':[{k:v for k,v in p.items() if k!='sharedHeadings'} for p in inventory['pages']]}
    main=lambda plan:{**plan,'pages':[{**p,'assignments':[{k:v for k,v in b.items() if k!='sourceMarkings'} for b in p['assignments']]} for p in plan['pages']]}
    copies=[{'id':b['id'],'pageIndex':b['pageIndex'],'before':b['sourceMarkings'],'after':a['sourceMarkings']} for b,a in zip(bband,aband) if b['sourceMarkings']!=a['sourceMarkings']]
    results.append({'id':c['id'],'pages':len(ai['pages']),'sourceSHA256':c['sourceSHA256'],'bands':len(aband),'headingsBefore':sum(len(p.get('sharedHeadings',[])) for p in bi['pages']),'headingsAfter':sum(len(p.get('sharedHeadings',[])) for p in ai['pages']),'copiesBefore':sum(len(b['sourceMarkings']) for b in bband),'copiesAfter':sum(len(b['sourceMarkings']) for b in aband),'headingChanges':heading_changes,'copiedRowChanges':copies,'otherInventoryChanges':differences(strip(bi),strip(ai)),'otherPlanChanges':differences(main(bp),main(ap)),'ocrChanges':differences(load(before/'ocr.json'),load(after/'ocr.json')),'baselineSummary':load(before/'summary.json'),'candidateSummary':load(after/'summary.json'),'fileHashes':{f'{variant}/{name}':sha(folder/name) for variant,folder in [('baseline',before),('candidate',after)] for name in ['inventory.json','plan.json','ocr.json','summary.json']}})
summary={'completedCases':len(results),'expectedCases':len(load(RUN/'config.json')),'pages':sum(r['pages'] for r in results),'bands':sum(r['bands'] for r in results),'headingChanges':sum(len(r['headingChanges']) for r in results),'copiedRowChanges':sum(len(r['copiedRowChanges']) for r in results),'otherInventoryChanges':sum(len(r['otherInventoryChanges']) for r in results),'otherPlanChanges':sum(len(r['otherPlanChanges']) for r in results),'ocrChanges':sum(len(r['ocrChanges']) for r in results),'cases':results}
(RUN/'comparison.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='cases'},indent=2))
for r in results:
    if r['headingChanges'] or r['otherPlanChanges'] or r['ocrChanges']:print(r['id'], 'heading pages', [h['pageIndex']+1 for h in r['headingChanges']], 'copy rows',len(r['copiedRowChanges']),'OCR changes',len(r['ocrChanges']),'other plan changes',len(r['otherPlanChanges']))
