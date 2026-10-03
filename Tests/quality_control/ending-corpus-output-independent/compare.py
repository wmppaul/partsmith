from pathlib import Path
import json, hashlib
from PIL import Image, ImageChops

p = Path('.build/ending-corpus-output-independent')
root = Path('.build/ending-corpus-2026-10-03')
jobs = json.loads((root/'export-jobs.json').read_text())
ids = list(dict.fromkeys(j['id'] for j in jobs))
guards = {(g['id'],g['page'],g['system']):g for g in json.loads((p/'frozen-source-mark-guards.json').read_text())['guards']}
parts, marks, changed = [], [], []
for score in ids:
    before = json.loads((root/score/'before-endings/manifest.json').read_text())
    after = json.loads((root/score/'with-endings/manifest.json').read_text())
    assert before['sourceSHA256'] == after['sourceSHA256']
    assert before['rectifications'] == after['rectifications'] == []
    for part in after['parts']:
        old = next(x for x in before['parts'] if x['id']==part['id'])
        oldrows = {r['id']:r for r in old['placements']}
        assert set(oldrows) == {r['id'] for r in part['placements']}
        flags, overlaps, count = [], [], 0
        for row in part['placements']:
            br = oldrows[row['id']]
            for field in ['sourcePage','sourceRect','system','candidateIDs','staffLineYs','kind']:
                if row.get(field) != br.get(field): flags.append({'row':row['id'],'field':field})
            ds, bs = row['destinationRect'], br['destinationRect']
            if abs((ds[2]-ds[0])-(bs[2]-bs[0]))>1e-8 or abs((ds[3]-ds[1])-(bs[3]-bs[1]))>1e-8:
                flags.append({'row':row['id'],'field':'destinationSize'})
            for mark in row['sourceMarkings']:
                if mark in br['sourceMarkings']: continue
                count += 1
                s,d = mark['sourceRect'], mark['destinationRect']
                g = guards[(score,row['sourcePage'],row['system'])]['protectedRect']
                scale = (ds[2]-ds[0])/(row['sourceRect'][2]-row['sourceRect'][0])
                expected = ds[0]+(s[0]-row['sourceRect'][0])*scale
                marks.append({'score':score,'part':part['id'],'file':part['file'],'id':row['id'],
                    'sourcePage':row['sourcePage'],'system':row['system'],'outputPage':row['outputPage'],
                    'musicRect':ds,'beforeMusicRect':bs,'beforeOutputPage':br['outputPage'],
                    'musicSourceRect':row['sourceRect'],'sourceMarking':mark,'guard':g,
                    'containsIndependentSourceGuard':s[0]<=g[0] and s[1]<=g[1] and s[2]>=g[2] and s[3]>=g[3],
                    'horizontalErrorPoints':abs(expected-d[0]),
                    'copyScaleError':abs(scale-(d[2]-d[0])/(s[2]-s[0])),
                    'musicGapPoints':ds[1]-d[3]})
        for page in range(1,max(part['outputPages'],old['outputPages'])+1):
            rows = sorted((r for r in part['placements'] if r['outputPage']==page),key=lambda r:r['destinationRect'][1])
            previous = None
            for row in rows:
                top = min([row['destinationRect'][1]]+[m['destinationRect'][1] for m in row['sourceMarkings']])
                if previous and top < previous[1]-1e-7:
                    overlaps.append({'page':page,'row':row['id'],'previous':previous[0],'overlap':previous[1]-top})
                previous = (row['id'],row['destinationRect'][3])
            a = root/score/'rendered/with-endings'/part['id']/f'page-{page:03}.png'
            b = root/score/'rendered/before-endings'/part['id']/f'page-{page:03}.png'
            ia,ib = (Image.open(a) if a.exists() else None),(Image.open(b) if b.exists() else None)
            bbox = ImageChops.difference(ia,ib).getbbox() if ia and ib else [0,0,*(ia or ib).size]
            if bbox: changed.append({'score':score,'part':part['id'],'page':page,'image':str(a) if ia else None,
                'beforeImage':str(b) if ib else None,'pixelDiffBounds':bbox,'imageSize':(ia or ib).size})
        parts.append({'score':score,'part':part['id'],'file':part['file'],'pages':part['outputPages'],
            'beforePages':old['outputPages'],'newMarkRows':count,'sourceOrSizeChanges':flags,'placementOverlaps':overlaps,
            'withPDFSHA256':hashlib.sha256((root/score/'with-endings'/part['file']).read_bytes()).hexdigest(),
            'beforePDFSHA256':hashlib.sha256((root/score/'before-endings'/part['file']).read_bytes()).hexdigest()})
report = {'parts':parts,'newRows':marks,'changedPages':changed}
(p/'independent-comparison.json').write_text(json.dumps(report,indent=2)+'\n')
print('parts',len(parts),'candidatePages',sum(x['pages'] for x in parts),'controlPages',sum(x['beforePages'] for x in parts),'newRows',len(marks),'changedPages',len(changed))
print('guardsFailed',[(x['score'],x['id']) for x in marks if not x['containsIndependentSourceGuard']])
print('geometryFlags',[(x['part'],x['sourceOrSizeChanges'],x['placementOverlaps']) for x in parts if x['sourceOrSizeChanges'] or x['placementOverlaps']])
print('pageCounts',[(x['score'].split('imslp-')[-1],x['part'],x['beforePages'],x['pages']) for x in parts])
