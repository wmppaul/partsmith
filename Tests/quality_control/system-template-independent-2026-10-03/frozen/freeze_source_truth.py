from pathlib import Path
import hashlib
import json
import pdfplumber
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
PRIOR = ROOT / '.build/variable-profile-audit-2026-10-03'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
rosters = json.loads((PRIOR/'source-roster.json').read_text())
prior_manifest = json.loads((PRIOR/'hashes.json').read_text())
assert all(sha(PRIOR/name) == expected for name,expected in prior_manifest.items())

# Read from the bound source pages and checked against the printed left labels.
# Final lengths were counted on the original last systems, not guessed from cadence.
starts = {
 'normal-mozart-notte-e-giorno-don-giovanni-score': [[1,5,10,15,20],[24,27,29,32,36],[39,42,44,46,48],[50,56,61,64,70]],
 'normal-schubert-erlkonig-d328-score': [[1,4,7,10,13],[16,19,22,25,28],[31,34,37,40],[43,46,49,52],
     [55,58,61,64],[67,70,73,76,79],[82,85,88,91,94],[97,100,103,106,109],
     [113,117,120,123],[127,130,133,136],[139,142,145]],
 'normal-mendelssohn-verleih-uns-frieden-gnadiglich-cpdl63797-full-score': [[1],[8,16,23,30],[37,45,52],[59,67],[74,82],[89,96]]
}
final_counts = {'normal-mozart-notte-e-giorno-don-giovanni-score':4,
                'normal-schubert-erlkonig-d328-score':4,
                'normal-mendelssohn-verleih-uns-frieden-gnadiglich-cpdl63797-full-score':7}
truth = []
external = {str(PRIOR/'hashes.json'):sha(PRIOR/'hashes.json'),str(PRIOR/'source-roster.json'):sha(PRIOR/'source-roster.json')}
for reviewed in rosters:
    ident = reviewed['id']
    source = ROOT/reviewed['sourcePath']; profile_path = ROOT/reviewed['profilePath']
    assert sha(source)==reviewed['sourceSHA256'] and sha(profile_path)==reviewed['profileSHA256']
    profile = json.loads(profile_path.read_text())
    part_counts = {p['id']:p['staffCount'] for p in profile['parts']}
    external[reviewed['sourcePath']] = sha(source);external[reviewed['profilePath']] = sha(profile_path)
    all_starts = [value for page in starts[ident] for value in page]
    all_counts = [b-a for a,b in zip(all_starts,all_starts[1:])] + [final_counts[ident]]
    pages=[]; serial=0
    with pdfplumber.open(source) as pdf:
        assert len(pdf.pages)==len(reviewed['sourcePageSystems'])
        for pi,page in enumerate(pdf.pages):
            number=pi+1
            source_png = PRIOR/ident/(f'page-{number:02d}.png' if 'erlkonig' in ident else f'page-{number}.png')
            assert sha(source_png)==prior_manifest[str(source_png.relative_to(PRIOR))]
            external[str(source_png.relative_to(ROOT))]=sha(source_png)
            # These are source PDF path objects, independent of any detector.
            # Each physically reviewed five-line staff has exactly five long,
            # parallel PDF line objects here. No part identity is inferred by modulo.
            horizontal = [(i,line) for i,line in enumerate(page.lines)
                if abs(line['y1']-line['y0'])<.02 and line['width']>page.width*.4]
            horizontal.sort(key=lambda item:item[1]['top'])
            assert len(horizontal)==reviewed['physicalStaffTotalsByPage'][pi]*5
            staff_truth=[]
            for offset in range(0,len(horizontal),5):
                group=horizontal[offset:offset+5]
                ys=[line['top'] for _,line in group]
                distances=[b-a for a,b in zip(ys,ys[1:])]
                assert max(distances)-min(distances)<.1
                assert len({round(line['x0'],2) for _,line in group})==1
                assert len({round(line['x1'],2) for _,line in group})==1
                staff_truth.append({'rankOneBased':len(staff_truth)+1,'lineYs':ys,
                    'left':group[0][1]['x0'],'right':group[0][1]['x1'],
                    'pdfLineObjectIndices':[i for i,_ in group]})
            systems=[]; cursor=0
            assert len(starts[ident][pi])==len(reviewed['sourcePageSystems'][pi])
            words=page.extract_words()
            for si,roster in enumerate(reviewed['sourcePageSystems'][pi]):
                mapping={}
                for part in roster:
                    mapping[part]=list(range(cursor+1,cursor+1+part_counts[part]));cursor+=part_counts[part]
                ranks=[rank for values in mapping.values() for rank in values]
                first=staff_truth[ranks[0]-1];last=staff_truth[ranks[-1]-1]
                start=all_starts[serial];count=all_counts[serial];serial+=1
                anchor_words=[w for w in words if w['text']==str(start) and w['x0']<75
                    and first['lineYs'][0]-25<w['top']<last['lineYs'][0]]
                assert anchor_words or start==1,(ident,pi,si,start)
                missing=[part for part in part_counts if part not in roster]
                systems.append({'systemNumber':si+1,'ordinalInScore':serial,'roster':roster,
                    'staffRanksOneBased':ranks,'partStaffRanksOneBased':mapping,'missingParts':missing,
                    'startBarNumber':start,'barCount':count,
                    'barEvidence':'Printed next-system anchor difference; terminal system counted from original barlines.' if serial<len(all_starts) else 'Terminal system visually counted from original source barlines.',
                    'startNumberSourceWords':anchor_words,
                    'sourceCoreBounds':[min(staff_truth[r-1]['left'] for r in ranks),first['lineYs'][0],
                        max(staff_truth[r-1]['right'] for r in ranks),last['lineYs'][-1]],
                    'boundaryEvidence':'Previously reviewed complete printed system, source five-line paths, braces/brackets, aligned measures and printed number anchors; identity from reviewed roster/labels/lyrics, not staff-count divisibility.',
                    'omissionRows':[{'partID':part,'startBarNumber':start,'barCount':count} for part in missing]})
            assert cursor==len(staff_truth)
            pages.append({'pageNumber':number,'width':page.width,'height':page.height,
                'sourceRender':str(source_png.relative_to(ROOT)),'sourceRenderSHA256':sha(source_png),
                'sourceStaffs':staff_truth,'systems':systems})
    truth.append({'id':ident,'sourcePath':reviewed['sourcePath'],'sourceSHA256':sha(source),
        'profilePath':reviewed['profilePath'],'profileSHA256':sha(profile_path),'partStaffCounts':part_counts,
        'reviewedTemplateRosters':list(dict.fromkeys(tuple(system['roster']) for page in pages for system in page['systems'])),
        'pages':pages})
summary={'scores':len(truth),'pages':sum(len(s['pages']) for s in truth),
    'systems':sum(len(p['systems']) for s in truth for p in s['pages']),
    'physicalStaffs':sum(len(p['sourceStaffs']) for s in truth for p in s['pages']),
    'musicRows':sum(len(sys['roster']) for s in truth for p in s['pages'] for sys in p['systems']),
    'omissionRows':sum(len(sys['missingParts']) for s in truth for p in s['pages'] for sys in p['systems'])}
assert summary=={'scores':3,'pages':21,'systems':82,'physicalStaffs':275,'musicRows':179,'omissionRows':27}
(OUT/'source-truth.json').write_text(json.dumps({'scope':'Independent source roster/system truth, frozen before candidate outcomes. Source geometry from PDF line objects, not detected staff boxes.','summary':summary,'scores':truth},indent=2,sort_keys=True)+'\n')
(OUT/'source-bindings.json').write_text(json.dumps(external,indent=2,sort_keys=True)+'\n')

# Separate source-authored ambiguity fixture. The real three-score set has no
# within-document same-count/different-roster transition, so do not imply it does.
image=Image.new('L',(800,1030),255);draw=ImageDraw.Draw(image)
synthetic=[]
for i,(top,labels,roster) in enumerate([(90,['Alto','Bass','Organ'],['alto','bass','organ']),
                                      (410,['Soprano','Bass','Organ'],['soprano','bass','organ']),
                                      (730,['','',''],None)]):
    ys=[top,top+50,top+110,top+150,top+190]
    for j,y in enumerate(ys):
        for line in range(5):draw.line((135,y+line*5,755,y+line*5),fill=0,width=1)
        draw.rectangle((436,y+5,450,y+8),fill=0)
        draw.line((755,y,755,y+20),fill=0,width=2)
    draw.line((130,ys[0],130,ys[1]+20),fill=0,width=2)
    draw.line((129,ys[0],135,ys[0]),fill=0,width=2);draw.line((129,ys[1]+20,135,ys[1]+20),fill=0,width=2)
    draw.line((132,ys[2],132,ys[4]+20),fill=0,width=1)
    draw.arc((113,ys[2],137,ys[3]+20),90,270,fill=0,width=2)
    for label,y in zip(labels,ys[:2]+[ys[2]]):draw.text((25,y+4),label,fill=0,font_size=16)
    if i<2:
        for y in ys[:2]:draw.text((250,y+25),'la',fill=0,font_size=14)
    # The third has the same vocal/organ layout but no identity labels. Its
    # intended roster is explicitly unspecified; neither template may win.
    else:
        for y in ys[:2]:draw.text((250,y+25),'la',fill=0,font_size=14)
    synthetic.append({'systemNumber':i+1,'staffRanksOneBased':list(range(i*5+1,i*5+6)),
        'staffLineYs':[[y+n*5 for n in range(5)] for y in ys],
        'sourceLabels':labels,'reviewedSeedRoster':roster,'barCount':1,
        'expected':'Explicitly reviewed seed may retain this roster.' if roster else 'Must remain ambiguous between Alto/Bass/Organ and Soprano/Bass/Organ after both seeds; no automatic assignment.'})
image.save(OUT/'same-count-source-fixture.png')
(OUT/'same-count-source-fixture.json').write_text(json.dumps({'sourceKind':'Independent synthetic boundary/identity fixture; not one of the three real scores.','width':800,'height':1030,'sha256':sha(OUT/'same-count-source-fixture.png'),'systems':synthetic},indent=2,sort_keys=True)+'\n')
print(json.dumps(summary,indent=2))
