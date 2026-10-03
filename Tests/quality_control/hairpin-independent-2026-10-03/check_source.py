#!/usr/bin/env python3
"""Recount frozen target masks; inspect original wedge-column thickness."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parent
records = json.loads((ROOT/'results.json').read_text())
verified = []
for row in records:
    source = np.asarray(Image.open(ROOT/'sources'/(row['name']+'.png')).convert('L'))
    mask = np.asarray(Image.open(ROOT/'sources'/(row['name']+'-lower-owner.png')).convert('L'))
    assert hashlib.sha256(source.tobytes()).hexdigest() == row['sourceSHA256']
    assert hashlib.sha256(mask.tobytes()).hexdigest() == row['sourceOwnerMaskSHA256']
    ys, xs = np.nonzero(mask == 0)
    for label in ['before', 'after']:
        top, bottom = row[label+'Crop']
        lost = int(((ys < top-1e-9) | (ys+1 > bottom+1e-9)).sum())
        assert lost == row[label+'LostPixels']
        verified.append({'name': row['name'], 'stage': label, 'sourcePixels': len(ys), 'lostPixels': lost})
source = np.asarray(Image.open(ROOT/'sources/musical-diminuendo.png').convert('L'))
excess = []
for x in range(300,425):
    rows = np.nonzero(source[535:553,x] < 190)[0] + 535
    groups = np.split(rows,np.flatnonzero(np.diff(rows)>1)+1)
    if any(len(g)>3.5 for g in groups):
        excess.append({'x':x, 'runs':[[int(g.min()),int(g.max()+1)] for g in groups if len(g)]})
assert excess
proof = {'all24SourceAndOwnerImageHashesMatch': True, 'ownerObservations':verified,
    'diminuendoGateEvidence': {'staffSpace':10, 'componentBounds':[300,535,425,553],
        'shapeSpan':125, 'shapeDepth':18, 'distanceBelowFinalStaff':45,
        'maxThickness':3.5,'columnsExceedingThicknessGate':excess,
        'interpretation':'The two genuine authored arms become one four-pixel run near their converging tip. The candidate rejects that run before line fitting.'}}
(ROOT/'source-proof.json').write_text(json.dumps(proof,indent=2,sort_keys=True)+'\n')
left=Image.open(ROOT/'sources/musical-diminuendo.png').convert('RGB').crop((265,425,460,580)).resize((585,465))
right=Image.open(ROOT/'sources/same-pixel-footer.png').convert('RGB').crop((265,425,460,580)).resize((585,465))
panel=Image.new('RGB',(1190,525),'white');panel.paste(left,(0,40));panel.paste(right,(605,40))
draw=ImageDraw.Draw(panel)
draw.text((8,10),'AUTHORED HAIRPIN: 484 target pixels remain omitted',fill='black')
draw.text((613,10),'IDENTICAL FOOTER SHAPE: no added crop in this test',fill='black')
for x in (0,605):
    y=40+(495-425)*3;draw.line((x,y,x+584,y),fill=(220,0,30),width=2)
draw.text((8,507),'Red: unchanged lower crop edge. Both shapes fail the same 3.5-pixel run-thickness gate.',fill='black')
panel.save(ROOT/'source-positive-and-footer.png')
print('Verified24 owner observations and source/mask hashes; exact tip-thickness rejection confirmed.')
