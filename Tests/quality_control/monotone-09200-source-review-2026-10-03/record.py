from pathlib import Path
from PIL import Image
import hashlib, json, numpy as np, shutil, zipfile

root = Path('.build/monotone-pending-source-review-2026-10-03/medium-skewed-05-brahms-string-quartet-no3-op67-imslp-09200')
out = Path('Tests/quality_control/monotone-09200-source-review-2026-10-03')
out.mkdir(parents=True, exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
rows = {r['bandID']: r for r in json.loads((root/'index.json').read_text())}
observations = {
    'p10-s4-viola': 'Top contracts through neighboring violin I material; own viola notes, ties, accidentals, triplets and dynamics remain. Most of violin II remains inside the crop.',
    'p22-s1-violin2': 'Top removes the shared conditional tempo instruction 2da volta rit. Own violin II notes, slurs, dolce and molto dolce remain. Production already clipped the top of the ordinal; candidate excludes all measured text pixels. Full direction workflow must be checked separately.',
    'p25-s4-cello': 'Top removes neighboring violin/viola material. Own cello high accidentals, descending slurs, dim., pizz., low chords and p remain.',
    'p17-s5-violin1': 'Top removes preceding cello material. Own violin I beams, hairpins, slurs, high notes and f remain; preceding cello hairpin fragments still appear at the new edge.',
    'p25-s4-viola': 'Bottom removes neighboring cello low notes and dim./p. Own viola ties, hairpin, dim., high notes, triplets and p remain.',
    'p10-s4-violin1': 'Bottom removes neighboring viola material and part of violin II. Own violin I high slurs, triplets, trills, f and p remain.',
    'p17-s2-cello': 'Bottom removes following violin material. Own cello slurs, low hairpins, accidentals and p/f remain.',
    'p24-s2-violin1': 'Top removes preceding cello staff/beam material. Own violin I high slurs, accidentals, low hairpins, dynamics, numbered ending brackets and time signature remain.',
    'p10-s1-violin2': 'Top removes the shared Andante heading from this raw crop. Own violin II notes, low slurs, hairpins and p remain. Separate direction recognition is required to retain the movement tempo.',
    'p17-s1-viola': 'Top removes neighboring violin I low material while retaining the viola notes, low hairpins, ties, accidentals, p, pp and dim. Violin II remains within the crop.',
    'p4-s2-violin1': 'Top removes previous cello staff material, leaving some neighboring low notes. Own violin I high slurs, accidentals, hairpins and sotto voce remain.',
    'p22-s4-cello': 'Top and bottom contract through neighboring viola and following violin I material. Own cello high notes, slurs, low notes and f remain.'
}
selected = [rows[k] for k in observations]
target = rows['p22-s1-violin2']
source_raster = Path(target['sourceRaster'])
a = np.asarray(Image.open(source_raster).convert('L'))
x0,y0,x1,y1 = 882,136,1107,184
ys,xs = np.where(a[y0:y1,x0:x1] < 255)
xs += x0; ys += y0
box = [int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
finding = {
    'bandID': target['bandID'], 'printedText': '2da volta rit.',
    'interpretation': 'Ritardando on the second pass applies to the ensemble at this musical position.',
    'roi': [x0,y0,x1,y1], 'nonwhitePixelBounds': box, 'nonwhitePixels': int(len(xs)),
    'measurementRule': 'All grayscale samples below 255 in a visually isolated word box; original unmodified source render. No thresholded cleanup mask used.',
    'baselineTopPixel': target['before']['topFraction']*a.shape[0],
    'candidateTopPixel': target['after']['topFraction']*a.shape[0],
    'baselineFullyIncludedPixelCells': int(sum(ys >= target['before']['topFraction']*a.shape[0])),
    'candidateIntersectedPixelCells': int(sum(ys+1 > target['after']['topFraction']*a.shape[0])),
    'baselineAlreadyClipsOrdinal': True,
    'sourceMarkingsBefore': target['before']['sourceMarkings'],
    'sourceMarkingsAfter': target['after']['sourceMarkings'],
    'scope': 'New loss in the tested raw crop plan. Raw corpus omits the optional shared-direction workflow; not yet an assertion about opt-in app recognition.'
}
report = {
    'scope': 'Independent root visual inspection of twelve largest-contraction Brahms 09200 contexts, plus original full source page 22 and isolated conditional-tempo detail. No full-score pass.',
    'candidateNativeSHA256': '95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0',
    'inputBindings': json.loads((root/'bindings.json').read_text()),
    'reviewedBands': [{'bandID': k, 'verdict': 'shared-direction loss in raw plan' if k in [finding['bandID'],'p10-s1-violin2'] else 'no new intended-staff notation loss observed', 'observation': v} for k,v in observations.items()],
    'finding': finding,
    'coverage': {'pendingQueue': 199, 'reviewed': 12, 'unreviewed': 187},
    'sourceRows': selected,
    'limits': 'No fresh review of the remaining 187 changes, no full part export certification, no assertion that old crops were complete, and no production analyzer change.'
}
(out/'review.json').write_text(json.dumps(report,indent=2)+'\n')
files = [Path(r['context']) for r in selected] + [source_raster,root/'p22-conditional-tempo-detail.png',root/'bindings.json']
with zipfile.ZipFile(out/'source-contexts.zip','w',zipfile.ZIP_DEFLATED) as z:
    for p in files: z.write(p,p.name)
shutil.copy2(__file__,out/'record.py')
(out/'manifest.json').write_text(json.dumps({p.name: sha(p) for p in sorted(out.iterdir()) if p.name != 'manifest.json'},indent=2)+'\n')
print(json.dumps(finding,indent=2))
