from pathlib import Path
import json, hashlib, math
import pymupdf as fitz
from PIL import Image, ImageDraw, ImageFont

w = Path('.build/brahms-reviewed-cleanup-2026-10-03')
prior = Path('output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-preservation')
report = Path('Tests/quality_control/brahms-reviewed-cleanup-2026-10-03')
load = lambda p: json.loads(p.read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
before = load(w/'baseline-parts/manifest.json')
after = load(w/'manual-parts/manifest.json')
delivered = load(prior/'manifest.json')
proposals = {p['bandID']:p for p in load(report/'manual-proposals-v1.json')['proposals']}
results = {'parts':[], 'changedCropIDs':[], 'copiedDirections':0, 'placementIssues':[], 'changedPages':[], 'baselinePagesExactToDelivery':0, 'nativeSubpixelSizeDifferences':[]}
font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',16)
def close(a,b):
    return len(a)==len(b) and all(abs(x-y)<1e-8 for x,y in zip(a,b))
def overlap(a,b):
    return min(a[2],b[2])>max(a[0],b[0])+1e-6 and min(a[3],b[3])>max(a[1],b[1])+1e-6
def page_rows(rows):
    return [{'page':n,'first':items[0]['id'],'last':items[-1]['id'],'rows':len(items)} for n in sorted({r['outputPage'] for r in rows}) for items in [[r for r in rows if r['outputPage']==n]]]
all_changed_images=[]
for old,new,deliv in zip(before['parts'],after['parts'],delivered['parts']):
    assert old['id']==new['id']==deliv['id']
    assert len(old['placements'])==len(new['placements'])==151
    changed_rows=[];moved=[];dimensions=[]
    for a,b,d in zip(old['placements'],new['placements'],deliv['placements']):
        assert a['id']==b['id']==d['id']
        assert a==d, 'Current native baseline geometry differs from delivered baseline'
        intended=proposals.get(a['id'],{}).get('proposedRect',a['sourceRect'])
        assert close(b['sourceRect'],intended)
        if not close(a['sourceRect'],b['sourceRect']):results['changedCropIDs'].append(a['id']);changed_rows.append(a['id'])
        for key in ['candidateIDs','sourcePage','system','staffLineYs','kind','editorialLabel']:
            assert a[key]==b[key],(a['id'],key)
        assert len(a['sourceMarkings'])==len(b['sourceMarkings'])
        for am,bm in zip(a['sourceMarkings'],b['sourceMarkings']):
            assert close(am['sourceRect'],bm['sourceRect']) and am.get('isBelow',False)==bm.get('isBelow',False)
        results['copiedDirections']+=len(b['sourceMarkings'])
        if a['outputPage']!=b['outputPage']:moved.append({'id':a['id'],'before':a['outputPage'],'after':b['outputPage']})
        if a['id'] not in proposals:
            old_size=[a['destinationRect'][2]-a['destinationRect'][0],a['destinationRect'][3]-a['destinationRect'][1]]
            new_size=[b['destinationRect'][2]-b['destinationRect'][0],b['destinationRect'][3]-b['destinationRect'][1]]
            if not close(old_size,new_size):
                results['nativeSubpixelSizeDifferences'].append({'id':a['id'],'before':old_size,'after':new_size,'difference':[y-x for x,y in zip(old_size,new_size)]})
                assert all(abs(x-y)<1e-4 for x,y in zip(old_size,new_size))
    docs={label:fitz.open(folder/new['file']) for label,folder in [('baseline',w/'baseline-parts'),('manual',w/'manual-parts'),('delivery',prior)]}
    pageinfo=[];changed=[]
    for label,doc in docs.items():
        out=w/'rendered'/label/new['id'];out.mkdir(parents=True,exist_ok=True)
        for i,page in enumerate(doc):
            pix=page.get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False);path=out/f'page-{i+1:02}.png';pix.save(path)
            if label=='manual':
                rows=[r for r in new['placements'] if r['outputPage']==i+1]
                extents=[]
                for r in rows:
                    boxes=[r['destinationRect']]+[mark['destinationRect'] for mark in r['sourceMarkings']]
                    for box in boxes:
                        if not (0<=box[0]<box[2]<=page.rect.width and 0<=box[1]<box[3]<=page.rect.height):results['placementIssues'].append({'id':r['id'],'issue':'outside-page','rect':box})
                    extents.append((r['id'],[min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes)]))
                for (aid,a),(bid,b) in zip(extents,extents[1:]):
                    if overlap(a,b):results['placementIssues'].append({'ids':[aid,bid],'issue':'row-overlap'})
    for i in range(len(docs['baseline'])):
        a=w/'rendered/baseline'/new['id']/f'page-{i+1:02}.png';d=w/'rendered/delivery'/new['id']/f'page-{i+1:02}.png'
        assert a.read_bytes()==d.read_bytes();results['baselinePagesExactToDelivery']+=1
    for i in range(len(docs['manual'])):
        a=w/'rendered/baseline'/new['id']/f'page-{i+1:02}.png';b=w/'rendered/manual'/new['id']/f'page-{i+1:02}.png'
        same=a.exists() and a.read_bytes()==b.read_bytes()
        pageinfo.append({'page':i+1,'pixelIdentical':same,'manualImage':str(b),'manualImageSHA256':sha(b)})
        if not same:
            changed.append(i+1);results['changedPages'].append({'part':new['id'],'page':i+1,'image':str(b)});all_changed_images.append((b,f'{new["name"]} p{i+1}'))
    results['parts'].append({'id':new['id'],'name':new['name'],'baselinePages':old['outputPages'],'manualPages':new['outputPages'],'changedCropIDs':changed_rows,'movedRows':moved,'changedPages':changed,'baselinePageTurns':page_rows(old['placements']),'manualPageTurns':page_rows(new['placements']),'pages':pageinfo,'baselinePDFSHA256':sha(w/'baseline-parts'/new['file']),'manualPDFSHA256':sha(w/'manual-parts'/new['file'])})
assert sorted(results['changedCropIDs'])==sorted(proposals)
assert results['copiedDirections']==42 and not results['placementIssues']
results['manualTotalPages']=sum(p['manualPages'] for p in results['parts'])
results['baselineTotalPages']=sum(p['baselinePages'] for p in results['parts'])
results['renderedPages']=2*results['baselineTotalPages']+results['manualTotalPages']
results['explicitBreaksExact']=load(w/'manual-parts/layout-page-breaks.json')==load(prior/'layout-page-breaks.json')
results['originalSourceExact']=after['sourceSHA256']==delivered['sourceSHA256']
results['rectificationsExact']=after['rectifications']==delivered['rectifications']
results['changedPageContactSheets']=[]
for start in range(0,len(all_changed_images),6):
    batch=all_changed_images[start:start+6];sheet=Image.new('RGB',(1380,1210),'#e8e8e8');dr=ImageDraw.Draw(sheet)
    for k,(path,label) in enumerate(batch):
        im=Image.open(path);im.thumbnail((450,570));x=(k%3)*460;y=(k//3)*605
        dr.text((x+8,y+7),label,fill='black',font=font);sheet.paste(im,(x+5,y+30))
    out=w/f'changed-pages-{start//6+1:02}.png';sheet.save(out);results['changedPageContactSheets'].append(str(out))
(w/'output-comparison.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps({k:v for k,v in results.items() if k not in ['parts','changedPages']},indent=2))
for p in results['parts']:print(p['name'],p['baselinePages'],p['manualPages'],'changed',p['changedPages'],'moved',len(p['movedRows']))
