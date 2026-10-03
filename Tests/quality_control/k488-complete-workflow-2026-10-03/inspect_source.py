from pathlib import Path
import hashlib, json
import pymupdf as fitz
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
SOURCE = Path('sample_scores/rest_detection/01_full_scores/mozart_piano_concerto_no23_kv488_mvt1_mutopia2229.pdf').resolve()
analysis = json.load(open('.build/combined-corpus-2026-10-03/candidate/rest-detection-mozart-piano-concerto-no23-kv488-mvt1-mutopia2229.json'))['pages']
doc = fitz.open(SOURCE)
systems = []
pages = []
for pi, page in enumerate(doc):
    staves = analysis[pi]['staves']
    spans = [s for b in page.get_text('dict')['blocks'] for l in b.get('lines', []) for s in l['spans']]
    starts = [s for s in spans if s['font'] == 'CenturySchL-Roma' and s['text'].isdigit() and s['bbox'][0] < 40 and s['bbox'][3]-s['bbox'][1] < 8]
    starts.sort(key=lambda s: s['bbox'][1])
    if pi == 0:
        starts.insert(0, {'text':'1','bbox':[0,110,0,117]})
    indices = []
    for s in starts:
        y = s['bbox'][3]
        idx = min(range(len(staves)), key=lambda k: abs(staves[k]['staffLineFractions'][0]*page.rect.height-y))
        assert abs(staves[idx]['staffLineFractions'][0]*page.rect.height-y) < 16, (pi,s,idx)
        indices.append(idx)
    assert indices[0] == 0 and indices == sorted(set(indices)), (pi, indices)
    for si,(s,idx) in enumerate(zip(starts,indices)):
        end = indices[si+1] if si+1<len(indices) else len(staves)
        group = staves[idx:end]
        top = max(0,group[0]['staffLineFractions'][0]*page.rect.height-28)
        bottom = min(page.rect.height,group[-1]['staffLineFractions'][-1]*page.rect.height+27)
        clefs = []
        for staff in group:
            cy = sum(staff['staffLineFractions'])/5*page.rect.height
            items = [t for t in spans if t['font']=='Emmentaler-14' and t['bbox'][0]<120 and any(c in t['text'] for c in '\x08\x0b\x0c') and abs((t['bbox'][1]+t['bbox'][3])/2-cy)<22]
            items.sort(key=lambda t:t['bbox'][0])
            clefs.append([{'text': t['text'], 'bbox': t['bbox'], 'origin':t['origin']} for t in items[:1]])
        systems.append({'page':pi+1,'system':si+1,'firstBar':int(s['text']),'candidateIDs':[x['id'] for x in group], 'top':top,'bottom':bottom,'clefs':clefs})
    pix=page.get_pixmap(matrix=fitz.Matrix(0.95,0.95),alpha=False)
    im=Image.frombytes('RGB',[pix.width,pix.height],pix.samples)
    draw=ImageDraw.Draw(im)
    for staff in staves:
        y=staff['staffLineFractions'][0]*im.height
        draw.text((6,y),str(staff['id']),fill='red')
    pages.append(im)
    im.save(ROOT/f'page-{pi+1:02}.png')
for start in range(0,len(pages),6):
    sheet=Image.new('RGB',(pages[0].width*3,pages[0].height*2),'#ddd')
    for offset,im in enumerate(pages[start:start+6]):
        x=offset%3*im.width;y=offset//3*im.height
        sheet.paste(im,(x,y));ImageDraw.Draw(sheet).text((x+150,y+10),f'SOURCE PAGE {start+offset+1}',fill='red')
    sheet.save(ROOT/f'source-contact-{start+1:02}-{min(start+6,len(pages)):02}.png')
for i,s in enumerate(systems):
    s['barCountFromNextStart'] = systems[i+1]['firstBar']-s['firstBar'] if i+1<len(systems) else None
    print(s['page'],s['system'],s['firstBar'],s['barCountFromNextStart'],s['candidateIDs'],''.join((c[0]['text'][0] if c else '?') for c in s['clefs']).encode())
(ROOT/'source-system-proposal.json').write_text(json.dumps({'source':str(SOURCE),'sourceSHA256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'status':'unreviewed source proposals, not instrument assignments or verified bar counts','systems':systems},indent=2))
