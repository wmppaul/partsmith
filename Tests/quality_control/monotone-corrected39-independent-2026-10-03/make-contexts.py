import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

work = Path('.build/brahms-monotone-independent-2026-10-03')
source = Path('.build/brahms-source-span-full-replay-2026-10-03/rasters')
old = json.loads(Path('.build/ownership-alternatives-2026-10-03/actual.json').read_text())
changes = json.loads((work / 'review-context-changes.json').read_text())['changedBands']
out = work / 'contexts'
out.mkdir(exist_ok=True)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 20)
panels = []
for change in changes:
    page = change['page']
    image = Image.open(source / f'page-{page}.png').convert('RGB')
    ph = old['pages'][page - 1]['pageHeight']
    scale = image.height / ph
    lo = max(0, math.floor((min(change['oldY'][0], change['newY'][0]) - 18) * scale))
    hi = min(image.height, math.ceil((max(change['oldY'][1], change['newY'][1]) + 18) * scale))
    # Original full-width source, exact source dimensions. Dashed old edges
    # leave source visible; solid new edges show included/excluded ink.
    context = image.crop((0, lo, image.width, hi))
    d = ImageDraw.Draw(context)
    for y in change['oldY']:
        yy = y * scale - lo
        for x in range(0, image.width, 18):
            d.line((x, yy, min(image.width, x+10), yy), fill='#e54545', width=2)
    for y in change['newY']:
        yy = y * scale - lo
        d.line((0, yy, image.width, yy), fill='#006eee', width=2)
    width = min(1440, context.width)
    context = context.resize((width, round(context.height * width / context.width)))
    panel = Image.new('RGB', (width, context.height + 56), 'white')
    d = ImageDraw.Draw(panel)
    d.text((8, 4), change['band'] + ' | old red dashes; new blue', fill='black', font=font)
    d.text((8, 29), f"old {change['oldY'][0]:.2f}–{change['oldY'][1]:.2f} pt; new {change['newY'][0]:.2f}–{change['newY'][1]:.2f} pt", fill='black', font=font)
    panel.paste(context, (0, 56))
    path = out / f"{change['band']}.png"
    panel.save(path)
    panels.append(dict(band=change['band'], page=page, path=str(path), sourcePixelRange=[lo, hi], sourceHeight=image.height, pageHeight=ph))
(work / 'context-index.json').write_text(json.dumps(panels, indent=2)+'\n')
print(f'{len(panels)} full-width contexts written')
