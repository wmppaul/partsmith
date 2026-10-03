"""Independent structural/source-guard comparison; never edits run inputs."""
from pathlib import Path
import hashlib,json,sys

root=Path('.build/heading-blocks-2026-10-03')
out=Path('Tests/quality_control/heading-block-independent')
config=json.loads((root/'config.json').read_text())
candidate_variant=sys.argv[1] if len(sys.argv)>1 else 'candidate'
guards=json.loads((out/'frozen-direction-guards.json').read_text())['guards']
def read(path):return json.loads(path.read_text())
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def contains(a,b):return all([a[0]<=b[0]+1e-12,a[1]<=b[1]+1e-12,a[2]>=b[2]-1e-12,a[3]>=b[3]-1e-12])
def music_rect(b):return [b['leftFraction'],b['topFraction'],1-b['rightFraction'],b['bottomFraction']]
def mark_rect(m):return [m['leftFraction'],m['topFraction'],1-m['rightFraction'],m['bottomFraction']]
reports=[];pending=[]
for case in config:
    a=root/'baseline'/case['id'];b=root/candidate_variant/case['id']
    files=[a/'inventory.json',a/'plan.json',a/'summary.json',b/'inventory.json',b/'plan.json',b/'summary.json']
    if not all(f.exists() for f in files):pending.append(case['id']);continue
    ai,ap,asu,bi,bp,bsu=map(read,files)
    pages_a={p['pageIndex']:p for p in ai['pages']};pages_b={p['pageIndex']:p for p in bi['pages']}
    report={'id':case['id'],'sourceSHA256':case['sourceSHA256'],'before':asu,'after':bsu,'changedBlocks':[],
        'missingOriginalFragments':[],'newUnsupportedBlocks':[],'changedMainCrops':[],'changedCopies':[],
        'sourceGuards':[],'artifactSHA256':{str(f):digest(f) for f in files}}
    for index,pa in pages_a.items():
        pb=pages_b[index];ha=pa.get('sharedHeadings',[]) or [];hb=pb.get('sharedHeadings',[]) or []
        for h in ha:
            if not any(g['anchorStaffID']==h['anchorStaffID'] and contains(g['bounds'],h['bounds']) for g in hb):
                report['missingOriginalFragments'].append({'page':index+1,'heading':h})
        for h in hb:
            constituents=[g for g in ha if g['anchorStaffID']==h['anchorStaffID'] and contains(h['bounds'],g['bounds'])]
            if not constituents:report['newUnsupportedBlocks'].append({'page':index+1,'heading':h})
            elif not any(g['bounds']==h['bounds'] and g['recognizedText']==h['recognizedText'] for g in ha):
                report['changedBlocks'].append({'page':index+1,'before':constituents,'after':h})
        if case['id']=='medium-skewed-03-schumann-piano-quintet-op44-imslp-06822':
            for guard in guards:
                if guard['page']!=index+1:continue
                q=[guard['guard'][0]/pb['pageWidth'],guard['guard'][1]/pb['pageHeight'],guard['guard'][2]/pb['pageWidth'],guard['guard'][3]/pb['pageHeight']]
                supported=[g for g in hb if contains(g['bounds'],q)]
                report['sourceGuards'].append({'page':index+1,'role':guard['role'],'boundsContain':bool(supported),
                    'inkContains':any(g.get('inkBounds') and contains(g['inkBounds'],q) for g in supported),'guard':guard['guard']})
    bands_a={b['id']:b for p in ap['pages'] for b in p['assignments']}
    bands_b={b['id']:b for p in bp['pages'] for b in p['assignments']}
    report['bandIDsUnchanged']=bands_a.keys()==bands_b.keys()
    for id,n in bands_b.items():
        if id not in bands_a:continue
        o=bands_a[id]
        fields=['candidateIDs','kind','partID','systemIndex','topFraction','bottomFraction','leftFraction','rightFraction']
        difference={k:[o.get(k),n.get(k)] for k in fields if o.get(k)!=n.get(k)}
        if difference:report['changedMainCrops'].append({'id':id,'difference':difference})
        if o['sourceMarkings']!=n['sourceMarkings']:
            report['changedCopies'].append({'id':id,'page':n['pageIndex']+1,'partID':n['partID'],'systemIndex':n['systemIndex'],
                'before':o['sourceMarkings'],'after':n['sourceMarkings']})
    reports.append(report)
result={'candidateVariant':candidate_variant,'pending':pending,'completeCases':len(reports),'cases':reports}
(out/f'native-comparison-{candidate_variant}.json').write_text(json.dumps(result,indent=2))
print(json.dumps({'pending':len(pending),'complete':len(reports),'changedBlocks':sum(len(r['changedBlocks']) for r in reports),
    'missingOriginalFragments':sum(len(r['missingOriginalFragments']) for r in reports),
    'newUnsupportedBlocks':sum(len(r['newUnsupportedBlocks']) for r in reports),
    'changedMainCrops':sum(len(r['changedMainCrops']) for r in reports),
    'changedCopies':sum(len(r['changedCopies']) for r in reports)}))
