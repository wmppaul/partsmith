#!/usr/bin/env python3
"""Source-pixel check and diagnostic plot. No detector masks are used."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
RUN = ROOT / '.build/brahms-remaining-2026-10-03/four-core-independent'
REPORT = Path(__file__).resolve().parent
base = json.loads((RUN/'baseline/results.json').read_text())
candidate = json.loads((RUN/'candidate/results.json').read_text())
verified = []
for kind, rows in [('baseline', base), ('candidate', candidate)]:
    for row in rows:
        for target in row['targets']:
            path = RUN/kind/'sources'/f"{row['id']}-owner{target['owner']}.png"
            ink = np.asarray(Image.open(path)) == 0
            y, x = np.nonzero(ink)
            envelope = [int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1)]
            top, bottom = target['crop']
            lost = int(((y < top-1e-9) | (y+1 > bottom+1e-9)).sum())
            assert envelope == target['sourceEnvelope']
            assert len(y) == target['sourcePixels']
            assert lost == target['lostPixels']
            verified.append({'kind': kind, 'id': row['id'], 'scale': row['scale'],
                             'owner': target['owner'], 'lostPixels': lost})
(REPORT/'independent-mask-check.json').write_text(json.dumps({'observations': len(verified),
        'allRecordedCountsAndSourceEnvelopesMatch': True, 'results': verified}, indent=2)+'\n')
for shape in ['filledOuter', 'hollowTiedOuter']:
    ident = shape+'-fiveMissingRows'
    old = next(r for r in base if r['id']==ident and r['scale']==1)
    new = next(r for r in candidate if r['id']==ident and r['scale']==1)
    source = Image.open(RUN/'baseline/sources'/f'{ident}.png').convert('RGB')
    panel = Image.new('RGB',(1480,605),'white')
    draw = ImageDraw.Draw(panel)
    for column, (label, row, color) in enumerate([('BASELINE: upper source retained', old, (0,90,220)),
                                                ('CANDIDATE: source stem and head lost', new, (220,0,30))]):
        xoff = 10+column*740
        panel.paste(source,(xoff,60))
        d = ImageDraw.Draw(panel)
        d.text((xoff,10),label,fill=color)
        t = row['targets'][0]
        for y in t['crop']:
            d.line((xoff,60+y,xoff+719,60+y),fill=color,width=2)
        mask = np.asarray(Image.open(RUN/'baseline/sources'/f'{ident}-owner0.png'))==0
        ys, xs = np.nonzero(mask)
        top,bottom = t['crop']
        for x,y in zip(xs,ys):
            if y < top-1e-9 or y+1 > bottom+1e-9:
                panel.putpixel((xoff+int(x),60+int(y)),(235,0,20))
        d.text((xoff,575),f"Upper owner crop {top:.3f}..{bottom:.3f}; lost source pixels: {t['lostPixels']}",fill=color)
    panel.save(REPORT/f'{shape}-counterexample.png')
print(f'Independently verified {len(verified)} owner observations; rendered two source comparisons.')
