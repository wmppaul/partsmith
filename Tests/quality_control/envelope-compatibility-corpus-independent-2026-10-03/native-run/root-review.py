import json
import hashlib
from pathlib import Path
import pymupdf as fitz
from PIL import Image, ImageDraw, ImageFont

work = Path('.build/envelope-compatibility-corpus-2026-10-03')
ids = ['lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922',
       'lightly-skewed-10-brahms-string-quartet-no3-op67-imslp-242312']
inputs = {r['id']: r for r in json.loads((work / 'inputs.json').read_text())}
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 19)
for ident in ids:
    inp = inputs[ident]
    assert hashlib.sha256(Path(inp['source']).read_bytes()).hexdigest() == inp['sourceSHA256']
    before = json.loads((work / 'baseline' / f'{ident}.json').read_text())
    after = json.loads((work / 'candidate' / f'{ident}.json').read_text())
    assert [{k:v for k,v in p.items() if k != 'inkComponents'} for p in before['pages']] == [{k:v for k,v in p.items() if k != 'inkComponents'} for p in after['pages']]
    old = {b['id']: b for p in before['plan']['pages'] for b in p['assignments']}
    new = {b['id']: b for p in after['plan']['pages'] for b in p['assignments']}
    assert old.keys() == new.keys()
    out = work / 'root-source' / ident
    out.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(inp['source'])
    raster = {}
    rows = []
    for key, a in old.items():
        b = new[key]
        assert {k:v for k,v in a.items() if k not in ['topFraction','bottomFraction','warnings']} == {k:v for k,v in b.items() if k not in ['topFraction','bottomFraction','warnings']}
        if all(a[k] == b[k] for k in ['topFraction','bottomFraction']):
            continue
        p = a['pageIndex']
        page = before['pages'][p]
        if p not in raster:
            assert abs(doc[p].rect.width-page['pageWidth']) < .01 and abs(doc[p].rect.height-page['pageHeight']) < .01
            scale = min(1800/doc[p].rect.width,2600/doc[p].rect.height)
            pm = doc[p].get_pixmap(matrix=fitz.Matrix(scale,scale),alpha=False)
            raster[p] = Image.frombytes('RGB',(pm.width,pm.height),pm.samples)
            raster[p].save(out/f'source-page-{p+1}.png')
        im = raster[p]
        ys = [a['topFraction'], a['bottomFraction'], b['topFraction'], b['bottomFraction']]
        margin = 18/page['pageHeight']
        lo = max(0,int((min(ys)-margin)*im.height))
        hi = min(im.height,int((max(ys)+margin)*im.height)+1)
        panel = im.crop((0,lo,im.width,hi))
        d = ImageDraw.Draw(panel)
        for f in ys[:2]:
            y = f*im.height-lo
            for x in range(0,im.width,18): d.line((x,y,min(im.width,x+10),y),fill='#e54545',width=2)
        for f in ys[2:]:
            y = f*im.height-lo
            d.line((0,y,im.width,y),fill='#006eee',width=2)
        width = min(1440,panel.width)
        panel = panel.resize((width,round(panel.height*width/panel.width)))
        labeled = Image.new('RGB',(width,panel.height+30),'white')
        ImageDraw.Draw(labeled).text((5,4),key+' | old red; new blue',fill='black',font=font)
        labeled.paste(panel,(0,30))
        path = out/f'{key}.png';labeled.save(path)
        rows.append(dict(band=key,page=p+1,source=inp['source'],sourceSHA256=inp['sourceSHA256'],oldY=[ys[0]*page['pageHeight'],ys[1]*page['pageHeight']],newY=[ys[2]*page['pageHeight'],ys[3]*page['pageHeight']],context=str(path),contextSHA256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (out/'index.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(ident,len(rows),'changed crops on',len(raster),'pages',flush=True)
