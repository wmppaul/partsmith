"""Read-only source review: freeze contexts before inspecting accepted boxes."""
from pathlib import Path
import hashlib, json, math, subprocess, sys
from PIL import Image, ImageDraw, ImageFont
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SCRATCH = ROOT / '.build/accepted-heading-source-review'
RUN = ROOT / '.build/heading-blocks-2026-10-03'
MODE = sys.argv[1] if len(sys.argv) > 1 else 'contexts'
FONT = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 15)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
if MODE != 'contexts':
    assert len(json.loads((OUT/'frozen-source-obligations.json').read_text())['rows']) == 63

items = []
inputs = {}
for case in json.loads((RUN/'config.json').read_text()):
    invpath = RUN/'baseline'/case['id']/'inventory.json'
    inv = json.loads(invpath.read_text())
    source = Path(case['source'])
    assert sha(source) == case['sourceSHA256'] == inv['sourceSHA256']
    assert sha(ROOT/case['profile']) == case['profileSHA256']
    review_source = source
    if inv['rectifications']:
        assert case['id'] == 'brahms'
        folder = ROOT/'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-auto-endings'
        manifest = json.loads((folder/'manifest.json').read_text())
        provenance = json.loads((folder/'provenance.json').read_text())
        assert manifest['rectifications'] == inv['rectifications']
        assert len(inv['rectifications']) == 9
        review_source = folder/'rectified-review-source.pdf'
        assert sha(review_source) == provenance['files'][review_source.name]
    reader = PdfReader(review_source)
    inputs[case['id']] = dict(source=str(source), sourceSHA256=sha(source), inventory=str(invpath),
        inventorySHA256=sha(invpath), reviewSource=str(review_source), reviewSourceSHA256=sha(review_source),
        rectificationCount=len(inv['rectifications']), pageCount=len(reader.pages))
    for page in inv['pages']:
        headings = page.get('sharedHeadings', [])
        if not headings: continue
        pi=page['pageIndex']; pw=page['pageWidth']; ph=page['pageHeight']
        assert abs(float(reader.pages[pi].mediabox.width)-pw)<.05
        assert abs(float(reader.pages[pi].mediabox.height)-ph)<.05
        prefix=SCRATCH/f"{case['id']}-p{pi+1}"
        if not prefix.with_suffix('.png').exists():
            subprocess.run(['pdftoppm','-f',str(pi+1),'-l',str(pi+1),'-singlefile','-r','216','-png',
                            str(review_source),str(prefix)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        im=Image.open(prefix.with_suffix('.png')).convert('RGB')
        for hi,h in enumerate(headings):
            number=len(items)+1
            staff=next(s for s in page['staves'] if s['id']==h['anchorStaffID'])
            # Context is derived from physical staff position, not accepted box.
            top=max(0,staff['staffLineFractions'][0]-.105)
            bottom=min(1,staff['staffLineFractions'][4]+.045)
            region=[0,top,1,bottom]
            entry=dict(number=number,case=case['id'],page=pi+1,anchorStaffID=h['anchorStaffID'],
                       pageSize=[pw,ph],sourceContext=region,sourceSHA256=inputs[case['id']]['reviewSourceSHA256'],
                       acceptedHeading=h)
            if MODE=='contexts':
                crop=im.crop((0,math.floor(top*im.height),im.width,math.ceil(bottom*im.height)))
            else:
                r=h['bounds']
                crop=im.crop((math.floor(r[0]*im.width),math.floor(r[1]*im.height),
                              math.ceil(r[2]*im.width),math.ceil(r[3]*im.height)))
                crop=crop.resize((crop.width*2,crop.height*2))
            folder=OUT/MODE; folder.mkdir(exist_ok=True)
            crop.save(folder/f'{number:02}.png')
            items.append(entry)

assert len(items)==63
(OUT/'inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
(OUT/'index.json').write_text(json.dumps(items,indent=2)+'\n')
rows=[]
for item in items:
    number=item['number']; im=Image.open(OUT/MODE/f'{number:02}.png')
    width=1400
    if MODE=='contexts': im=im.resize((width,round(im.height*width/im.width)))
    row=Image.new('RGB',(width,max(im.height+36,100)),'#e9edf1')
    row.paste(im,(0,36));draw=ImageDraw.Draw(row)
    draw.text((8,8),f"{number:02} | {item['case']} | p{item['page']} staff {item['anchorStaffID']}",font=FONT,fill='black')
    rows.append(row)
for start in range(0,len(rows),7 if MODE=='contexts' else 10):
    subset=rows[start:start+(7 if MODE=='contexts' else 10)]
    sheet=Image.new('RGB',(1400,sum(r.height+8 for r in subset)), 'white');y=0
    for row in subset:sheet.paste(row,(0,y));y+=row.height+8
    sheet.save(OUT/MODE/f'sheet-{start+1:02}.png')
print(MODE,len(items),'source regions; all source/profile/inventory/rectification bindings verified')
