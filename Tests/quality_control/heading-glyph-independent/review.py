"""Independent source-pixel accounting; frozen guards are never modified."""
from pathlib import Path
import hashlib, json, math
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
PREV=ROOT/'Tests/quality_control/accepted-heading-source-review'
load=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
items=load(PREV/'index.json')
results=load(OUT/'results.json')
bindings=load(OUT/'input-bindings.json')
guards={g['number']:g for g in load(OUT/'frozen-initial-A-guards.json')}
for path,expected in bindings['candidateSourceHashes'].items():
    assert sha(ROOT/path)==expected,path
for item in bindings['sourceRecords'].values():
    for key in ['source','inventory','reviewSource']:
        assert sha(Path(item[key]))==item[key+'SHA256'],item[key]
font=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',14)
rows=[];records=[]
(OUT/'crops').mkdir(exist_ok=True)
for item,res in zip(items,results['sourceResults']):
    n=item['number'];assert n==res['number']
    p=ROOT/f".build/accepted-heading-source-review/{item['case']}-p{item['page']}.png"
    im=Image.open(p).convert('RGB');g=np.asarray(im.convert('L'))
    w,h=im.size;b=res['before'];a=res['after']
    yy,xx=np.ogrid[:h,:w]
    # Pixel-center containment preserves the original frozen ROI accounting;
    # counting integer left edges instead would include partially retained edge pixels.
    yy=yy+0.5;xx=xx+0.5
    def inside(r): return (xx>=r[0]*w)&(xx<r[2]*w)&(yy>=r[1]*h)&(yy<r[3]*h)
    old,new=inside(b),inside(a);added=new&~old;lost=old&~new
    rec={'number':n,'sourceRasterSHA256':sha(p),'changed':res['changed'],
         'boundsBefore':b,'boundsAfter':a,'newDarkPixels':int(((g<128)&added).sum()),
         'lostDarkPixels':int(((g<128)&lost).sum()),
         'lostAnyPixelPositions':int(lost.sum())}
    if n in guards:
        x0,y0,x1,y1=guards[n]['sourceManualInitialALeftROI216dpi']
        guard=np.zeros((h,w),bool);guard[y0:y1,x0:x1]=True
        rec.update(initialADarkPixels=int(((g<128)&guard).sum()),
                   initialADarkOutsideBefore=int(((g<128)&guard&~old).sum()),
                   initialADarkOutsideAfter=int(((g<128)&guard&~new).sum()),
                   newDarkPixelsOutsideFixedGuard=int(((g<128)&added&~guard).sum()),
                   growthPoints=(b[0]-a[0])*item['pageSize'][0])
        # Show source pixels with old and new edges; do not erase or repair ink.
        box=(x0-8,y0-8,x1+14,y1+8)
        zoom=im.crop(box).resize(((box[2]-box[0])*10,(box[3]-box[1])*10),Image.Resampling.NEAREST)
        d=ImageDraw.Draw(zoom)
        for val,color in [(b[0]*w,'red'),(a[0]*w,'green')]:
            x=round((val-box[0])*10);d.line((x,0,x,zoom.height),fill=color,width=2)
        zoom.save(OUT/f'initial-A-{n}-original-with-edges.png')
    # Candidate source box, source pixels only, side-by-side loss indicated by outlines separately.
    bounds=(math.floor(a[0]*w),math.floor(a[1]*h),math.ceil(a[2]*w),math.ceil(a[3]*h))
    crop=im.crop(bounds)
    scale=min(2,1360/crop.width)
    crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.NEAREST)
    crop.save(OUT/'crops'/f'{n:02}.png')
    row=Image.new('RGB',(1400,max(74,crop.height+30)),'#e9edf1')
    row.paste(crop,(4,29));d=ImageDraw.Draw(row)
    d.text((5,5),f"{n:02} | {item['case']} p{item['page']} | {'EXPANDED' if res['changed'] else 'unchanged'}",font=font,fill='black')
    rows.append(row);records.append(rec)
for start in range(0,len(rows),9):
    part=rows[start:start+9];sheet=Image.new('RGB',(1400,sum(x.height+5 for x in part)),'white');y=0
    for row in part:sheet.paste(row,(0,y));y+=row.height+5
    sheet.save(OUT/'crops'/f'sheet-{start+1:02}.png')
summary={'regionCount':len(records),'changed':[r['number'] for r in records if r['changed']],
         'lostOriginalPixelPositions':sum(r['lostAnyPixelPositions'] for r in records),
         'newDarkPixels':sum(r['newDarkPixels'] for r in records),
         'fixedGuardResults':[r for r in records if r['number'] in guards],
         'coordinateConvention':'Source pixel centers compared with fractional normalized source edges; <128 dark threshold, fixed216dpi A ROIs.'}
(OUT/'source-pixel-review.json').write_text(json.dumps({'summary':summary,'regions':records},indent=2)+'\n')
print(json.dumps(summary,indent=2))
