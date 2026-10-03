#!/usr/bin/env python3
"""Independent full-payload/coverage audit, preserving unresolved score states."""
import argparse,collections,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('left');p.add_argument('right');p.add_argument('output',type=Path);args=p.parse_args()
r=Path('.build/residual9-boundary-2026-10-03')
def read(p):return json.loads(Path(p).read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def canon(x):return json.dumps(x,sort_keys=True,separators=(',',':'))
def diffs(a,b,path=''):
    if type(a)!=type(b):return [{'path':path,'before':a,'after':b}]
    if isinstance(a,dict):
        out=[]
        for k in sorted(a.keys()|b.keys()):
            if k not in a or k not in b:out.append({'path':path+'/'+k,'before':a.get(k),'after':b.get(k)})
            else:out.extend(diffs(a[k],b[k],path+'/'+k))
        return out
    if isinstance(a,list):
        if len(a)!=len(b):return [{'path':path,'before':a,'after':b}]
        out=[]
        for i,(x,y) in enumerate(zip(a,b)):out.extend(diffs(x,y,path+'/'+str(i)))
        return out
    return [] if a==b else [{'path':path,'before':a,'after':b}]
inputs=read(r/'corpus-inputs.json');assert len(inputs)==36 and len({x['id'] for x in inputs})==36
listed={Path(x['source']).resolve() for x in inputs}
actual={q.resolve() for folder in ['sample_scores','Tests/extraction/sources'] for q in Path(folder).rglob('*.pdf')}
assert listed==actual
statusrows=[]
for fn in ['corpus-status.json','corpus-v2-status.json']:
 if (r/fn).exists():statusrows+=read(r/fn)['results']
status={(x['variant'],x['id']):x for x in statusrows}
rows=[]
for item in inputs:
    assert sha(item['source'])==item['sourceSHA256'];assert sha(item['profile'])==item['profileSHA256']
    profile=read(item['profile']);parts={p['id'] for p in profile['parts']}
    variants=[];files=[]
    for variant in [args.left,args.right]:
        f=r/variant/'corpus'/(item['id']+'.json');s=status[(variant,item['id'])]
        assert s['exitCode']==0 and sha(f)==s['outputSHA256'] and sha(r/variant/'existing755')==s['binarySHA256']
        assert s['sourceSHA256']==item['sourceSHA256'] and s['profileSHA256']==item['profileSHA256']
        data=read(f);variants.append(data);files.append({'path':str(f),'sha256':sha(f)})
        assert [p['pageIndex'] for p in data['pages']]==list(range(item['pages']))
        assert [p['pageIndex'] for p in data['plan']['pages']]==list(range(item['pages']))
        ids=[b['id'] for p in data['plan']['pages'] for b in p['assignments']];assert len(ids)==len(set(ids))
        for page,plan in zip(data['pages'],data['plan']['pages']):
            staffIDs={s['id'] for s in page['staves']};assert len(staffIDs)==len(page['staves'])
            for b in plan['assignments']:
                assert b['pageIndex']==page['pageIndex'] and b['partID'] in parts and set(b['candidateIDs'])<=staffIDs
    a,b=variants
    rawInk=[];semanticInk=[];pageOther=[];changedCoverage=[]
    for ap,bp,al,bl in zip(a['pages'],b['pages'],a['plan']['pages'],b['plan']['pages']):
        idx=ap['pageIndex'];ai=ap['inkComponents'];bi=bp['inkComponents']
        if ai!=bi:rawInk.append(idx+1)
        if collections.Counter(map(canon,ai))!=collections.Counter(map(canon,bi)):
            ca,cb=collections.Counter(map(canon,ai)),collections.Counter(map(canon,bi))
            semanticInk.append({'page':idx+1,'beforeCount':len(ai),'afterCount':len(bi),'removed':[json.loads(c) for c in (ca-cb).elements()],'added':[json.loads(c) for c in (cb-ca).elements()]})
        pageOther+=diffs({k:v for k,v in ap.items() if k!='inkComponents'},{k:v for k,v in bp.items() if k!='inkComponents'},f"/pages/{idx}")
        def coverage(plan):return [{k:v for k,v in band.items() if k not in ['topFraction','bottomFraction','leftFraction','rightFraction','warnings']} for band in plan['assignments']]
        if coverage(al)!=coverage(bl):changedCoverage.append(idx+1)
    planDiff=diffs(a['plan'],b['plan'],'/plan')
    def count(what):return sum(bool(what(p)) for p in a['plan']['pages'])
    rows.append({'id':item['id'],'pages':item['pages'],'requiresSystemAssignment':profile.get('requiresSystemAssignment',False),'bands':sum(len(p['assignments']) for p in a['plan']['pages']),
                 'pagesWithAssignments':count(lambda p:p['assignments']),'pagesWithUnresolvedReasons':count(lambda p:p['unresolvedReasons']),
                 'detectedStaves':sum(len(p['staves']) for p in a['pages']),
                 'unassignedStaves':sum(len({s['id'] for s in ap['staves']}-{i for band in pp['assignments'] for i in band['candidateIDs']}) for ap,pp in zip(a['pages'],a['plan']['pages'])),
                 'rawInkDifferentPages':rawInk,'semanticInkChanges':semanticInk,'nonInkPageDifferences':pageOther,'changedCoveragePages':changedCoverage,'planDifferences':planDiff,'files':files,
                 'source':item['source'],'sourceSHA256':item['sourceSHA256'],'profile':item['profile'],'profileSHA256':item['profileSHA256']})
summary={'left':args.left,'right':args.right,'terminalInputs':len(rows),'pages':sum(x['pages'] for x in rows),'bands':sum(x['bands'] for x in rows),'scoresWithBands':sum(x['bands']>0 for x in rows),'scoresWithNoBands':sum(x['bands']==0 for x in rows),'variableProfileScores':sum(x['requiresSystemAssignment'] for x in rows),'variableProfilePages':sum(x['pages'] for x in rows if x['requiresSystemAssignment']),'pagesWithAssignments':sum(x['pagesWithAssignments'] for x in rows),'pagesWithUnresolvedReasons':sum(x['pagesWithUnresolvedReasons'] for x in rows),'detectedStaves':sum(x['detectedStaves'] for x in rows),'unassignedStaves':sum(x['unassignedStaves'] for x in rows),'rawInkDifferentPages':sum(len(x['rawInkDifferentPages']) for x in rows),'semanticInkDifferentPages':sum(len(x['semanticInkChanges']) for x in rows),'nonInkPageDifferences':sum(len(x['nonInkPageDifferences']) for x in rows),'changedCoveragePages':sum(len(x['changedCoveragePages']) for x in rows),'planFieldDifferences':sum(len(x['planDifferences']) for x in rows)}
sourceFiles=[]
for variant in [args.left,args.right]:
    manifest=r/variant/'source-hashes.json'
    for rel,digest in read(manifest).items():assert sha(r/variant/rel)==digest
    sourceFiles.append({'variant':variant,'sourceManifestSHA256':sha(manifest),'binarySHA256':sha(r/variant/'existing755')})
args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps({'summary':summary,'rows':rows,'sources':sourceFiles,'rosterSHA256':sha(r/'corpus-inputs.json'),'auditScriptSHA256':sha(__file__)},indent=2)+'\n');print(json.dumps(summary,indent=2))
