from pathlib import Path
import json, hashlib
import pymupdf as fitz
from PIL import Image, ImageDraw

root=Path.cwd();work=root/'.build/ownership-mozart-output-2026-10-03'
report=root/'Tests/quality_control/ownership-mozart-output-2026-10-03'
base=work/'baseline/parts';candidate=work/'candidate/parts'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=json.loads((base/'manifest.json').read_text());b=json.loads((candidate/'manifest.json').read_text())
assert a['sourceSHA256']==b['sourceSHA256'] and a['profile']==b['profile'] and a['rectifications']==b['rectifications']
assert (base/'layout-page-breaks.json').read_bytes()==(candidate/'layout-page-breaks.json').read_bytes()
project=json.loads((candidate/b['project']/'project.json').read_text())['project']
oldproject=json.loads((base/a['project']/'project.json').read_text())['project']
assert sha(candidate/b['project']/'source.pdf')==b['sourceSHA256']
assert [p['layoutSettings'] for p in oldproject['parts']]==[p['layoutSettings'] for p in project['parts']]
assert sum(x.get('pageBreakBefore',False) for x in project['bands'])==0
expected={'p25-s1-violin','p25-s1-viola'}
changes=[];moved=[];parts=[];copies=0;rounding=[];changed_images=[];bandcount=0
for before,after in zip(a['parts'],b['parts']):
    assert before['id']==after['id'] and before['name']==after['name']
    assert len(before['placements'])==len(after['placements'])==119
    oldpdf=fitz.open(base/before['file']);pdf=fitz.open(candidate/after['file']);last={}
    for x,y in zip(before['placements'],after['placements']):
        bandcount+=1
        keys={'sourceRect','destinationRect','sourceMarkings','outputPage'}
        assert {k:v for k,v in x.items() if k not in keys}=={k:v for k,v in y.items() if k not in keys}
        assert [{k:v for k,v in z.items() if k!='destinationRect'} for z in x['sourceMarkings']]==[{k:v for k,v in z.items() if k!='destinationRect'} for z in y['sourceMarkings']]
        copies+=len(y['sourceMarkings'])
        changed=max(abs(u-v) for u,v in zip(x['sourceRect'],y['sourceRect']))>1e-9
        if changed:changes.append({'id':y['id'],'before':x['sourceRect'],'after':y['sourceRect'],'outputPage':y['outputPage']})
        else:
            dw=(y['destinationRect'][2]-y['destinationRect'][0])-(x['destinationRect'][2]-x['destinationRect'][0])
            dh=(y['destinationRect'][3]-y['destinationRect'][1])-(x['destinationRect'][3]-x['destinationRect'][1])
            assert max(abs(dw),abs(dh))<1e-5
            if max(abs(dw),abs(dh))>1e-7:rounding.append({'id':y['id'],'widthDelta':dw,'heightDelta':dh})
        rect=fitz.Rect(y['destinationRect'])
        for mark in y['sourceMarkings']:rect|=fitz.Rect(mark['destinationRect'])
        assert pdf[y['outputPage']-1].rect.contains(rect)
        assert rect.y0>=last.get(y['outputPage'],0)-1e-7
        last[y['outputPage']]=rect.y1
        if x['outputPage']!=y['outputPage']:moved.append({'id':y['id'],'beforePage':x['outputPage'],'afterPage':y['outputPage']})
        if changed:
            page=pdf[y['outputPage']-1]
            clip=fitz.Rect(24,max(0,rect.y0-8),588,min(page.rect.height,rect.y1+8))
            page.get_pixmap(matrix=fitz.Matrix(3,3),clip=clip,alpha=False).save(report/f'row-{y["id"]}.png')
    rendered=work/'rendered'/after['id'];rendered.mkdir(parents=True,exist_ok=True)
    same=[];different=[];page_map=[]
    for n,page in enumerate(pdf):
        pix=page.get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
        pix.save(rendered/f'page-{n+1:02}.png')
        equal=False
        if n<len(oldpdf):
            oldpix=oldpdf[n].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
            oldrender=work/'baseline-rendered'/after['id'];oldrender.mkdir(parents=True,exist_ok=True)
            oldpix.save(oldrender/f'page-{n+1:02}.png')
            equal=(pix.width,pix.height)==(oldpix.width,oldpix.height) and pix.samples==oldpix.samples
        (same if equal else different).append(n+1)
        if not equal:changed_images.append((f'{after["name"]} p{n+1}/{len(pdf)}',rendered/f'page-{n+1:02}.png'))
        rows=[x for x in after['placements'] if x['outputPage']==n+1]
        page_map.append({'page':n+1,'first':rows[0]['id'],'last':rows[-1]['id'],'systems':len(rows)})
    parts.append({'id':after['id'],'file':after['file'],'pagesBefore':len(oldpdf),'pagesAfter':len(pdf),
        'baselineSHA256':sha(base/before['file']),'candidateSHA256':sha(candidate/after['file']),
        'pixelEqualPagesAt108DPI':same,'changedPages':different,'pageMap':page_map})
assert bandcount==476 and {x['id'] for x in changes}==expected
for start in range(0,len(changed_images),6):
    group=changed_images[start:start+6];sheet=Image.new('RGB',(1100,750*((len(group)+1)//2)),'#eeeeee');draw=ImageDraw.Draw(sheet)
    for j,(label,path) in enumerate(group):
        im=Image.open(path);im.thumbnail((550,718));x=j%2*550;y=j//2*750
        sheet.paste(im,(x,y+25));draw.text((x+8,y+6),label,fill='black')
    sheet.save(report/f'changed-pages-{start+1:02}.png')
result={'status':'structural and raster comparison complete; visual judgments recorded separately','sourceSHA256':b['sourceSHA256'],
    'musicStrips':476,'directionCopies':copies,'copiedSourceMetadataExactlyUnchanged':True,'pageBreaksPersisted':0,
    'parts':parts,'cropChanges':changes,'movedBands':moved,'destinationFittingRoundoff':rounding,
    'totalPagesBefore':sum(p['pagesBefore'] for p in parts),'totalPagesAfter':sum(p['pagesAfter'] for p in parts),
    'totalChangedPages':sum(len(p['changedPages']) for p in parts),
    'bindings':{str(p.relative_to(root)):sha(p) for p in [base/'manifest.json',candidate/'manifest.json',candidate/b['project']/'project.json']}}
(report/'output-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['parts','destinationFittingRoundoff','bindings','movedBands']},indent=2))
