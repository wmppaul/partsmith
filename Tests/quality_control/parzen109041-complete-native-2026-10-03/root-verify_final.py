from pathlib import Path
import hashlib, json, math
import fitz

ROOT = Path('/Users/will/Documents/git/partsmith')
W = ROOT / '.build/brahms-parzen109041-complete-native-2026-10-03'
OUT = Path(__file__).parent
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
read = lambda p: json.loads(Path(p).read_text())
near = lambda a, b: len(a) == len(b) and all(abs(x-y) < 1e-7 for x,y in zip(a,b))
mf = W / 'final-reviewed-stage/parts/manifest.json'
m = read(mf)
idxf = W / 'copied-source-review-final/index.json'
idx = read(idxf)
old = read(W / 'dedup-stage/parts/manifest.json')
oldidx = read(W / 'copied-source-review/index.json')
assert sha(mf) == idx['manifestSHA256']
assert sha(m['source']) == m['sourceSHA256'] == idx['sourceSHA256']
assert len(m['parts']) == 20
parts = {p['id']: p for p in m['parts']}
rows = {(p['id'], b['id']): b for p in m['parts'] for b in p['placements']}
oldrows = {(p['id'], b['id']): b for p in old['parts'] for b in p['placements']}
assert len(rows) == 520 and set(rows) == set(oldrows)
assert sum(len(b['candidateIDs']) for b in rows.values()) == 568
assert sum(len(b.get('sourceMarkings', [])) for b in rows.values()) == 183
assert len(idx['recipientMappings']) == 183 and len(idx['sourceRectangles']) == 11
pdfs = {}
for pid, p in parts.items():
    f = mf.parent / p['file']
    with fitz.open(f) as doc: count = len(doc)
    assert count == p['outputPages']
    pdfs[pid] = {'file':str(f.relative_to(ROOT)), 'sha256':sha(f), 'pages':count}
assert sum(p['pages'] for p in pdfs.values()) == 62
changed = []
for key,b in rows.items():
    before = oldrows[key]
    assert b['outputPage'] == before['outputPage']
    assert b['candidateIDs'] == before['candidateIDs']
    if not near(b['sourceRect'], before['sourceRect']):
        changed.append({'partID':key[0], 'bandID':key[1], 'before':before['sourceRect'], 'after':b['sourceRect']})
assert {d['bandID'] for d in changed} == {'p21-s1-horns12', 'p24-s1-trombones12'}
for d in changed:
    expected = list(d['before'])
    expected[1 if d['partID'] == 'horns12' else 3] = 177.25 if d['partID'] == 'horns12' else 346.5
    assert near(d['after'], expected)
sourceboxes = {d['id']: d for d in idx['sourceRectangles']}
oldboxes = {d['id']: d for d in oldidx['sourceRectangles']}
seen = set()
for d in sourceboxes.values():
    assert sha(ROOT / d['sourcePNG']) == d['sourcePNGSHA256'] == oldboxes[d['id']]['sourcePNGSHA256']
    assert near(d['sourceRect'], oldboxes[d['id']]['sourceRect'])
for r in idx['recipientMappings']:
    key = (r['partID'], r['sourceBandID'])
    b = rows[key]
    s = sourceboxes[r['directionID']]
    assert (key,r['directionID']) not in seen
    seen.add((key,r['directionID']))
    assert r['sourcePage'] == b['sourcePage'] == s['physicalPage']
    assert r['outputPage'] == b['outputPage']
    assert near(r['sourceRect'], s['sourceRect'])
    matches = [c for c in b.get('sourceMarkings', []) if near(c['sourceRect'],r['sourceRect']) and near(c['destinationRect'],r['destinationRect'])]
    assert len(matches) == 1
    assert r['pdfSHA256'] == pdfs[r['partID']]['sha256']
    br,dr = b['sourceRect'],b['destinationRect']
    sr,cr = r['sourceRect'],r['destinationRect']
    scale = (dr[2]-dr[0])/(br[2]-br[0])
    assert abs(scale-r['sourceScale']) < 1e-7
    assert abs(cr[0]-(dr[0]+(sr[0]-br[0])*scale)) < 1e-7
    assert abs((cr[2]-cr[0])-(sr[2]-sr[0])*scale) < 1e-7
    assert abs((cr[3]-cr[1])-(sr[3]-sr[1])*scale) < 1e-7
    assert cr[1] >= dr[3] if r['isBelow'] else cr[3] <= dr[1]
for did,d in sourceboxes.items():
    recipients = [r['partID'] for r in idx['recipientMappings'] if r['directionID'] == did]
    assert len(recipients) == len(set(recipients)) == d['recipientCount']
    assert set(recipients) == set(d['recipients'])
    assert set(recipients) == (set(parts)-{'flutes','bass'} if d['recipientCount'] == 18 else {'alto-section','tenor','bass-section'})
bassf = W / 'local-bass-before-dedup/source-proof.json'
bass = read(bassf)
assert len(bass['records']) == 10
for r in bass['records']:
    assert sha(ROOT/r['sourceImage']) == r['sourceImageSHA256']
    b = rows['bass',f"p{r['physicalPage']}-s1-bass"]
    assert near(b['sourceRect'],r['sourceCrop'])
    crop,g = b['sourceRect'],r['reviewedLocalGuard']
    assert crop[0] <= g[0] < g[2] <= crop[2] and crop[1] <= g[1] < g[3] <= crop[3]
detailsf = W / 'final-reviewed-stage/repair-output-details/index.json'
for d in read(detailsf):
    assert sha(ROOT/d['outputDetail']) == d['sha256']
    if d['stage'] == 'final-reviewed-stage':
        pid = 'horns12' if 'horns12' in d['bandID'] else 'trombones12'
        assert d['outputPDFSHA256'] == pdfs[pid]['sha256']
receipt = {
    'scope':'Independent root geometry/hash verification plus directly viewed source and actual PDF details; not an automatic musical-completeness certificate.',
    'sourceSHA256':m['sourceSHA256'], 'finalManifestSHA256':sha(mf), 'copyIndexSHA256':sha(idxf),
    'initial208SourceReviewSHA256':sha(OUT/'initial-208-source-review.json'),
    'verified':{'parts':20,'pages':62,'sourceRows':520,'staffReferences':568,'sourceCopyMappings':183,'uniqueCopiedBoxes':11,'retainedDoubleBassLocalMarkings':10,'changedCropEdges':2},
    'visualReview':[
        'All 208 assigned initial Flutes–Trumpets source context rows directly viewed; remaining 312 belong to independent peer review.',
        'All 11 unique copied-source boxes viewed in three original panels; all source-image hashes identical in final stage.',
        'All four actual choir PDF contexts at source page21 viewed: complete expression above, quarter relation below at the matching bar position, no collision observed.',
        'All ten retained local DoubleBass markings viewed in three panels; the six removed duplicate copies were not needed for complete local glyphs.',
        'Original high-resolution Horn slur and Trombone dim. source details compared with final actual exported row details; both previously clipped marks now complete.'
    ],
    'repairs':changed,
    'limits':['Seven known whole-neighbor rows remain across combined reviews.','Foreign instrument directions and fragments remain; manual Preview cleanup is still needed.','Author reviewed all62 initial final pages and changed pages; root reviewed the specified source/recipient details, not all62 full pages.','This is an assisted preservation draft, not auto-only or performance-ready.'],
    'pdfs':pdfs,
    'evidence':{'doubleBassSourceProofSHA256':sha(bassf),'repairDetailIndexSHA256':sha(detailsf)}
}
p = OUT/'final-copy-and-repair-review.json'
p.write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'receipt':str(p),'sha256':sha(p),'verified':receipt['verified']},indent=2))
