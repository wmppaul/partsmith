#!/usr/bin/env python3
"""Independent whole-output check; reads candidate artifacts, never edits them."""
from pathlib import Path
import hashlib
import json
import sys

import numpy as np
import pymupdf as fitz
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / '.build/qc-algorithm-audit/heading-dedup'
OUT = ROOT / '.build/heading-ink-independent/output-review'
OUT.mkdir(parents=True, exist_ok=True)
SHA = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
LOAD = lambda p: json.loads(Path(p).read_text())

def inside(a, b, tol=1e-4):
    return a[0] >= b[0]-tol and a[1] >= b[1]-tol and a[2] <= b[2]+tol and a[3] <= b[3]+tol

def placement(manifest, part, page, system):
    return next(b for p in manifest['parts'] if p['id'] == part for b in p['placements']
                if b['sourcePage'] == page and b['system'] == system)

def present(manifest, part, page, system, rect):
    b = placement(manifest, part, page, system)
    return inside(rect, b['sourceRect']) or any(inside(rect, m['sourceRect']) for m in b['sourceMarkings'])

def render(path, page, scale=2):
    with fitz.open(path) as d:
        p=d[page].get_pixmap(matrix=fitz.Matrix(scale, scale), colorspace=fitz.csRGB, alpha=False)
        return np.frombuffer(p.samples, dtype=np.uint8).reshape(p.height,p.width,3).copy()

result={'method': 'Exact main-placement comparison; all output pages rendered at 144 DPI and byte-compared. Frozen independent source guards tested with original rectangles. No oracle edits.', 'scores': []}
for cfg in LOAD(ART/'inputs.json'):
    name=cfg['name']; oldp=ROOT/cfg['manifest']; newp=ART/f'{name}-native-parts/manifest.json'
    old,new=LOAD(oldp),LOAD(newp)
    assert old['sourceSHA256']==new['sourceSHA256']
    assert old['rectifications']==new['rectifications']
    report={'name':name, 'baselineManifest':str(oldp.relative_to(ROOT)), 'baselineSHA256':SHA(oldp),
            'candidateManifest':str(newp.relative_to(ROOT)), 'candidateSHA256':SHA(newp),
            'originalSHA256':new['sourceSHA256'], 'parts':[], 'changedMainCrops':[], 'changedMarkings':[], 'guards':[]}
    assert [p['id'] for p in old['parts']]==[p['id'] for p in new['parts']]
    for a,b in zip(old['parts'],new['parts']):
        assert [x['id'] for x in a['placements']]==[x['id'] for x in b['placements']]
        for x,y in zip(a['placements'],b['placements']):
            for key in ['sourcePage','system','candidateIDs','staffLineYs','kind','sourceRect','provenance']:
                if x[key]!=y[key]: report['changedMainCrops'].append({'band':x['id'],'field':key,'before':x[key],'after':y[key]})
            xm=[(m['sourceRect'],m.get('isBelow',False)) for m in x['sourceMarkings']]
            ym=[(m['sourceRect'],m.get('isBelow',False)) for m in y['sourceMarkings']]
            if xm!=ym: report['changedMarkings'].append({'band':x['id'],'before':xm,'after':ym})
        op,npth=oldp.parent/a['file'],newp.parent/b['file']
        pr={'id':b['id'],'bands':len(b['placements']),'pages':b['outputPages'],'baselinePDFSHA256':SHA(op),'candidatePDFSHA256':SHA(npth),'pageComparison':[]}
        assert a['outputPages']==b['outputPages']
        thumbnails=[]
        for pi in range(b['outputPages']):
            ar,br=render(op,pi),render(npth,pi)
            assert ar.shape==br.shape
            mask=np.any(ar!=br,axis=2);changed=int(mask.sum())
            detail={'page':pi+1,'identical':changed==0,'changedPixels':changed,'baselineRasterSHA256':hashlib.sha256(ar.tobytes()).hexdigest(),'candidateRasterSHA256':hashlib.sha256(br.tobytes()).hexdigest()}
            if changed:
                ys,xs=np.where(mask);detail['differencePixelBounds']=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
                for prefix,im in [('baseline',ar),('candidate',br)]:
                    dest=OUT/f'{name}-{b["id"]}-{pi+1:02}-{prefix}.png';Image.fromarray(im).save(dest)
                diff=np.full_like(br,255);diff[mask]=[230,35,35];Image.fromarray(diff).save(OUT/f'{name}-{b["id"]}-{pi+1:02}-difference.png')
            pr['pageComparison'].append(detail)
            im=Image.fromarray(br);im.thumbnail((245,320));tile=Image.new('RGB',(265,346),'white');tile.paste(im,((265-im.width)//2,22));ImageDraw.Draw(tile).text((8,5),f'{b["name"]} p{pi+1}',fill='black');thumbnails.append(tile)
        for chunk in range(0,len(thumbnails),12):
            batch=thumbnails[chunk:chunk+12];sheet=Image.new('RGB',(265*4,346*((len(batch)+3)//4)),(230,230,230))
            for i,im in enumerate(batch):sheet.paste(im,((i%4)*265,(i//4)*346))
            sheet.save(OUT/f'{name}-{b["id"]}-contact-{chunk//12+1}.jpg',quality=94)
        report['parts'].append(pr)
        print(name,b['id'],pr['pages'],'pages',sum(not p['identical'] for p in pr['pageComparison']),'changed',flush=True)
    if name=='ave':
        # Exact frozen own-notation envelopes used by the candidate5 review.
        # The earlier ave-map.json rectangles were broader crop proposals.
        gp=ROOT/'Tests/full_scores/ave-tight-map.json';g=LOAD(gp)
        for p in g['pages']:
            for s in p['systems']:
                for b in s['bands']:
                    for r in b['protectedRegions']:
                        report['guards'].append({'id':f"p{p['pageIndex']+1}-s{s['systemIndex']+1}-{b['partID']}",'baseline':present(old,b['partID'],p['pageIndex']+1,s['systemIndex']+1,r['rect']),'candidate':present(new,b['partID'],p['pageIndex']+1,s['systemIndex']+1,r['rect'])})
    elif name=='kv498':
        gp=ROOT/'Tests/quality_control/kv498-checkpoint975ee3d-review/source-direction-guards.json';g=LOAD(gp)
        for r in g['regions']:
            for part in r['requiredParts']:
                report['guards'].append({'id':r['id']+'-'+part,'baseline':present(old,part,r['sourcePage'],r['system'],r['sourceRect']),'candidate':present(new,part,r['sourcePage'],r['system'],r['sourceRect'])})
    else:
        gp=ROOT/'Tests/quality_control/brahms93521/shared-directions-corrected.json';g=LOAD(gp)
        for r in g['entries']:
            for part in r['targetPartIDs']:
                report['guards'].append({'id':r['id']+'-'+part,'baseline':present(old,part,r['pageNumber'],r['systemNumber'],r['rect']),'candidate':present(new,part,r['pageNumber'],r['systemNumber'],r['rect'])})
        extra=ROOT/'Tests/quality_control/brahms93521/connector8-independent-source-guards.json'
        partids={'Violin I':'violin1','Violin II':'violin2','Viola':'viola','Violoncello':'cello'}
        for r in LOAD(extra)['regions']:
            if not r['id'].startswith('93521-'):continue
            # These pages explicitly remain unrectified in the recorded correction.
            if any(x['pageIndex']==r['pageNumber']-1 for x in new['rectifications']):
                report.setdefault('inapplicableRawGuards',[]).append({'id':r['id'],'reason':'Raw-source guard is explicitly not valid on this rectified page; unchanged page pixels and corrected shared-direction oracle are checked separately.'})
                continue
            for b in r['bands']:
                part=partids[b['part']]
                report['guards'].append({'id':'note-'+r['id']+'-'+part,'baseline':present(old,part,r['pageNumber'],r['systemNumber'],b['protectedRect']),'candidate':present(new,part,r['pageNumber'],r['systemNumber'],b['protectedRect'])})
        report['additionalGuardSHA256']=SHA(extra)
        # Exact original-to-candidate corrected source pixels bind the corrected oracle.
        osrc=ROOT/cfg['reviewSource'];nsrc=newp.parent/new['reviewSourceFile']
        report['correctedSources']={'baselineSHA256':SHA(osrc),'candidateSHA256':SHA(nsrc),'pages':[]}
        with fitz.open(osrc) as d: count=len(d)
        for p in range(count):
            ar,br=render(osrc,p),render(nsrc,p)
            report['correctedSources']['pages'].append({'page':p+1,'identical':ar.shape==br.shape and bool(np.array_equal(ar,br))})
    report['guardFile']=str(gp.relative_to(ROOT));report['guardSHA256']=SHA(gp)
    result['scores'].append(report)
    (OUT/'results.json').write_text(json.dumps(result,indent=2)+'\n')
assert not any(s['changedMainCrops'] for s in result['scores'])
assert [len(s['changedMarkings']) for s in result['scores']]==[0,1,0]
assert not any(g['baseline']!=g['candidate'] for s in result['scores'] for g in s['guards'])
assert [(s['name'],p['id'],r['page']) for s in result['scores'] for p in s['parts']
        for r in p['pageComparison'] if not r['identical']]==[('kv498','clarinet',6)]
assert all(p['identical'] for p in result['scores'][2]['correctedSources']['pages'])
print('Complete: unchanged main geometry and guard outcomes on every score.',flush=True)
