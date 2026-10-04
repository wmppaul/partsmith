from pathlib import Path
import json, hashlib
from collections import deque
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).parent
P10_LOG = Path('.build/source-musical-spans-2026-10-03/candidate-v3-p10-observed/span-records/000.json')
POS_LOG = Path('Tests/quality_control/musical-span-independent-2026-10-03/candidate-v3/span-witnesses.json')
P10_SOURCE = Path('.build/brahms-source-span-full-replay-2026-10-03/rasters/page-10.png')
CASE176_SOURCE = Path('.build/source-musical-spans-2026-10-03/candidate-v3/case176-source.pgm')

def cross(o,a,b): return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
def hull(points):
    pts=sorted(set(points)); lo=[]; hi=[]
    for p in pts:
        while len(lo)>=2 and cross(lo[-2],lo[-1],p)<=0:lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi)>=2 and cross(hi[-2],hi[-1],p)<=0:hi.pop()
        hi.append(p)
    return lo[:-1]+hi[:-1]
def inside(point,poly):return all(cross(poly[i],poly[(i+1)%len(poly)],point)>=-1e-9 for i in range(len(poly)))
def bounds(p):return [min(x for x,y in p),min(y for x,y in p),max(x for x,y in p)+1,max(y for x,y in p)+1]
def components(pixels,diag=False):
    remaining=set(pixels); out=[]
    steps=[(-1,0),(1,0),(0,-1),(0,1)]+([(-1,-1),(-1,1),(1,-1),(1,1)] if diag else [])
    while remaining:
        s=remaining.pop(); seen={s}; todo=[s]
        for x,y in todo:
            for dx,dy in steps:
                n=(x+dx,y+dy)
                if n in remaining: remaining.remove(n);seen.add(n);todo.append(n)
        out.append(seen)
    return out

def describe(pixels):
    x0,y0,x1,y1=bounds(pixels)
    h=hull((x+dx,y+dy) for x,y in pixels for dx,dy in [(0,0),(1,0),(1,1),(0,1)])
    area=abs(sum(h[i][0]*h[(i+1)%len(h)][1]-h[(i+1)%len(h)][0]*h[i][1] for i in range(len(h))))/2
    centers={(x,y) for y in range(y0,y1) for x in range(x0,x1) if inside((x+.5,y+.5),h)}
    voids=centers-pixels
    paper={(x,y) for y in range(y0-1,y1+1) for x in range(x0-1,x1+1)}-pixels
    white=components(paper); outside=set(); holes=[]
    for c in white:
        if any(x==x0-1 or x==x1 or y==y0-1 or y==y1 for x,y in c):outside|=c
        else:holes.append(c)
    gaps=[]
    for y in range(y0,y1):
        xs=[x for x,yy in pixels if yy==y]
        if xs:
            missing=[x for x in range(min(xs),max(xs)+1) if (x,y) not in pixels]
            if missing:gaps.append({'y':y,'missingXs':missing})
    return {'pixels':len(pixels),'bounds': [x0,y0,x1,y1], 'bboxFill':len(pixels)/((x1-x0)*(y1-y0)),
            'unitCellHull':h,'unitCellHullArea':area,'pixelAreaOverHullArea':len(pixels)/area,
            'hullPixelCenters':len(centers),'pixelCenterHullOccupancy':len(pixels)/len(centers),
            'hullVoidPixelCenters':len(voids),'exteriorConnectedHullVoidCenters':len(voids & outside),
            'holeCount':len(holes),'holeSizes':sorted(map(len,holes)),'foregroundComponents8':len(components(pixels,True)),
            'rowsWithInternalWhiteGaps':gaps},h,voids,holes

p10=json.loads(P10_LOG.read_text()); pos=json.loads(POS_LOG.read_text()); cases=[]
for i,s in enumerate(p10['spans']):
    for j,b in enumerate(s['bodies']):cases.append((f'p10-span{i}-body{j}',b,s,P10_SOURCE,1))
for c in pos:
    if c['id']=='original-case176' or (c['id']=='music-filled' and c['scale']==.5):
        for i,s in enumerate(c['spans']):
            for j,b in enumerate(s['bodies']):cases.append((f"{c['id']}-scale{c['scale']}-body{j}",b,s,CASE176_SOURCE if c['id']=='original-case176' else None,c['scale']))

results=[]
for ident,b,s,source,scale in cases:
    off={(x,y) for y,a,z in b['footprintRuns'] for x in range(a,z)}
    shaft=set(map(tuple,b['shaftBodyPixels'])); union=off|shaft
    info,h,voids,holes=describe(union)
    rec={'id':ident,'scale':scale,'reportedOffShaftBounds':b['bounds'],'offShaftPixels':len(off),'restoredOriginalShaftPixels':len(shaft),'intersectionPixels':len(off & shaft),'filledDisk':b['filledDisk'],'wholeFootprint':info,'sourcePath':str(source) if source else None,'sourceLimit':None if source else 'Exact logged half-scale footprint only. Original fixture source is720x640; no guessed resampling was used to reconstruct native360x320 gray pixels.'}
    x0,y0,x1,y1=info['bounds'];context=(x0-8,y0-8,x1+8,y1+15)
    if source:
        gray=np.array(Image.open(source).convert('L')); black=gray<190
        rec['sourceSHA256']=hashlib.sha256(source.read_bytes()).hexdigest()
        rec['allLoggedPixelsOriginalBlack']=all(bool(black[y,x]) for x,y in union)
        original={(x,y) for y in range(y0,y1) for x in range(x0,x1) if black[y,x]}
        original_info,_,_,_=describe(original)
        rec['originalBlackInsideWholeBox']=original_info
        explained={(x,y) for x,a,z in b['explainedThinRuns'] for y in range(a,z)}
        rec['sourceBlackInBoxNotInWholeFootprint']=len(original-union)
        rec['sourceBlackInBoxExplainedAsThinPath']=len((original-union)&explained)
        if ident.startswith('p10'):
            left,right=s['stroke']; nearby={(x,y) for y in range(context[1],context[3]) for x in range(context[0],context[2]) if black[y,x] and (x<left or x>=right)}
            cc=components(nearby,True);rec['originalOffShaftContextComponents']=[{'bounds':bounds(c),'pixels':len(c),'touchesLoggedFootprint':bool(c & off),'touchesContextBoundary':any(x in [context[0],context[2]-1] or y in [context[1],context[3]-1] for x,y in c)} for c in cc]
        im=Image.fromarray(gray).convert('RGB').crop(context)
    else:
        im=Image.new('RGB',(context[2]-context[0],context[3]-context[1]),'white')
        for x,y in union:im.putpixel((x-context[0],y-context[1]),(0,0,0))
    zoom=9;leftim=im.resize((im.width*zoom,im.height*zoom),Image.Resampling.NEAREST)
    diag=im.copy()
    for x,y in voids:diag.putpixel((x-context[0],y-context[1]),(255,190,190))
    for x,y in off:diag.putpixel((x-context[0],y-context[1]),(0,90,0))
    for x,y in shaft:diag.putpixel((x-context[0],y-context[1]),(0,90,230))
    diag=diag.resize((diag.width*zoom,diag.height*zoom),Image.Resampling.NEAREST);dr=ImageDraw.Draw(diag)
    hp=[((x-context[0])*zoom,(y-context[1])*zoom) for x,y in h];dr.line(hp+[hp[0]],fill=(255,110,0),width=2)
    can=Image.new('RGB',(leftim.width*2+20,leftim.height+55),'white');can.paste(leftim,(0,55));can.paste(diag,(leftim.width+20,55));dr=ImageDraw.Draw(can);dr.text((4,5),ident,fill='black');dr.text((4,23),f"area {len(union)} / hull {info['unitCellHullArea']} = {info['pixelAreaOverHullArea']:.4f}; green=body blue=source-shaft red=hull-void",fill='black');can.save(HERE/f'{ident}.png');rec['overlay']=f'{ident}.png';results.append(rec)

out={'scope':'Descriptive complete-shape measurements, not a classifier pass/fail. No threshold chosen or production mutation.','pixelGeometry':'Pixel units are half-open unit squares. Continuous hull uses all cell corners; center metric counts pixel centers inside that hull. White4/black8 topology; original black threshold190.','bodies':results,'inputHashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [P10_LOG,POS_LOG,P10_SOURCE,CASE176_SOURCE]}}
(HERE/'measurements.json').write_text(json.dumps(out,indent=2)+'\n')
for r in results:
    q=r['wholeFootprint'];print(r['id'],r['offShaftPixels'],r['restoredOriginalShaftPixels'],q['unitCellHullArea'],round(q['pixelAreaOverHullArea'],5),'center',round(q['pixelCenterHullOccupancy'],5),'externalVoid',q['exteriorConnectedHullVoidCenters'],'holes',q['holeCount'],'original',r.get('originalBlackInsideWholeBox',{}).get('pixelAreaOverHullArea'))
