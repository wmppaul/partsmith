"""Read-only independent manifest/PDF comparison and review images."""
from pathlib import Path
import hashlib,json,sys
import pymupdf
from PIL import Image,ImageDraw

old_dir=Path('.build/ending-local-app-native-2026-10-03/schumann-parts')
new_dir=Path(sys.argv[1]);out=Path('Tests/quality_control/heading-block-independent/export-review');out.mkdir(exist_ok=True)
old=json.loads((old_dir/'manifest.json').read_text());new=json.loads((new_dir/'manifest.json').read_text())
assert old['sourceSHA256']==new['sourceSHA256']
assert old['rectifications']==new['rectifications']
result={'baseline':str(old_dir),'candidate':str(new_dir),'sourceSHA256':new['sourceSHA256'],'parts':[],
    'mainCropChanges':[],'copyChanges':[],'changedPlacementPages':[],'layoutOverlaps':[],
    'outOfPage':[],'p26CopyGuards':[],'hashes':{}}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def contains(a,b):return a[0]<=b[0] and a[1]<=b[1] and a[2]>=b[2] and a[3]>=b[3]
guard=[65.9,40.56666666666666,146.1,58.1]
page_reviews=[]
for part in new['parts']:
    previous=next(x for x in old['parts'] if x['id']==part['id'])
    pa=pymupdf.open(old_dir/previous['file']);pb=pymupdf.open(new_dir/part['file'])
    a={r['id']:r for r in previous['placements']};b={r['id']:r for r in part['placements']}
    assert set(a)==set(b)
    changed_pages=set();changed_rows=[]
    for id,row in b.items():
        before=a[id]
        diff={k:[before[k],row[k]] for k in ['candidateIDs','sourcePage','sourceRect','system','kind','staffLineYs'] if before[k]!=row[k]}
        if diff:result['mainCropChanges'].append({'row':id,'diff':diff})
        if [x['sourceRect'] for x in before['sourceMarkings']]!=[x['sourceRect'] for x in row['sourceMarkings']]:
            result['copyChanges'].append({'row':id,'before':before['sourceMarkings'],'after':row['sourceMarkings']})
            changed_rows.append(row)
        if row['sourcePage']==26 and row['system']==1 and part['id']!='violin1':
            result['p26CopyGuards'].append({'row':id,'contains':any(contains(m['sourceRect'],guard) for m in row['sourceMarkings'])})
        if before['destinationRect']!=row['destinationRect'] or before['outputPage']!=row['outputPage'] or before['sourceMarkings']!=row['sourceMarkings']:
            changed_pages.update([before['outputPage'],row['outputPage']])
    for row in changed_rows:
        rects=[row['destinationRect']]+[m['destinationRect'] for m in row['sourceMarkings']]
        box=pymupdf.Rect(min(r[0] for r in rects)-5,min(r[1] for r in rects)-5,max(r[2] for r in rects)+5,max(r[3] for r in rects)+5)
        pix=pb[row['outputPage']-1].get_pixmap(matrix=pymupdf.Matrix(3,3),clip=box,alpha=False)
        pix.save(str(out/f'{row["id"]}-actual-output.png'))
    for num in range(1,part['outputPages']+1):
        rows=sorted([r for r in part['placements'] if r['outputPage']==num],key=lambda x:x['destinationRect'][1]);last=None
        for row in rows:
            rects=[row['destinationRect']]+[m['destinationRect'] for m in row['sourceMarkings']]
            top=min(r[1] for r in rects);bottom=max(r[3] for r in rects)
            if last and top<last[1]-1e-7:result['layoutOverlaps'].append({'part':part['id'],'page':num,'rows':[last[0],row['id']]})
            for r in rects:
                if r[0]<0 or r[1]<0 or r[2]>pb[num-1].rect.width+1e-7 or r[3]>pb[num-1].rect.height+1e-7:result['outOfPage'].append({'row':row['id'],'rect':r})
            last=row['id'],bottom
    for num in sorted(changed_pages):
        if num>len(pb):continue
        pix=pb[num-1].get_pixmap(matrix=pymupdf.Matrix(1,1),alpha=False)
        image=Image.frombytes('RGB',[pix.width,pix.height],pix.samples);image.thumbnail((400,518))
        tile=Image.new('RGB',(420,550),'#ddd');ImageDraw.Draw(tile).text((10,6),f'{part["name"]} page {num}',fill='black');tile.paste(image,(10,26));page_reviews.append(tile)
    result['changedPlacementPages'].extend({'part':part['id'],'page':n} for n in sorted(changed_pages))
    result['parts'].append({'id':part['id'],'baselinePages':len(pa),'pages':len(pb),'changedRows':len(changed_rows),'changedPlacementPages':sorted(changed_pages)})
    for p in [old_dir/previous['file'],new_dir/part['file']]:result['hashes'][str(p)]=sha(p)
for offset in range(0,len(page_reviews),4):
    sheet=Image.new('RGB',(840,1100),'#ddd')
    for j,im in enumerate(page_reviews[offset:offset+4]):sheet.paste(im,((j%2)*420,(j//2)*550))
    sheet.save(out/f'changed-pages-{offset//4+1:02d}.png')
for p in [old_dir/'manifest.json',new_dir/'manifest.json']:result['hashes'][str(p)]=sha(p)
(out/'comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:len(result[k]) for k in ['mainCropChanges','copyChanges','changedPlacementPages','layoutOverlaps','outOfPage']}))
