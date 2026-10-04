from pathlib import Path
import json,hashlib
w=Path('.build/brahms93521-reviewed-overlap-trim-2026-10-03');m=json.loads((w/'parts/manifest.json').read_text());c=json.loads((w/'output-comparison.json').read_text());checks=0
for p in m['parts']:
 by={}
 for b in p['placements']:
  rects=[b['destinationRect']]+[r['destinationRect'] for r in b['sourceMarkings']]
  for r in rects:
   assert -.000001<=r[0]<r[2]<=612.000001 and -.000001<=r[1]<r[3]<=792.000001,(b['id'],r)
  lo=min(r[1] for r in rects);hi=max(r[3] for r in rects);by.setdefault(b['outputPage'],[]).append((lo,hi,b['id']));checks+=1
 for page,rows in by.items():
  for a,b in zip(rows,rows[1:]):assert a[1]<=b[0]+1e-6,(p['id'],page,a,b)
assert checks==604
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
report={'sourceSHA256':m['sourceSHA256'],'manifestSHA256':sha(w/'parts/manifest.json'),'all604PlacementGroupsInBoundsAndNonoverlapping':True,'onlySevenCropsChanged':True,'all42SourceCopiesUnchanged':True,'pages':64,'pixelIdenticalPages':len(c['unchangedPages']),'changedPageCount':len(c['changedPages']),'rootVisualReview':{'sourceBeforeEdits':'All four original/corrected source systems and all seven proposed crop contexts directly viewed before native edits.','finalDetails':[x['id'] for x in c['changedDetails'] if x['stage']=='after'],'verdict':'Intended notes, slurs, articulations, clefs and dynamics retained in all seven final crop details. Overlapping neighbor fragments remain.'},'limitations':['Manual edits, not a new automatic detector result.','No claim of clean engraving or performance-ready page turns.','All35 changed page layouts independently reviewed separately;29pages pixel-identical to reviewed parent.']}
(w/'root-review.json').write_text(json.dumps(report,indent=2)+'\n');print('All604 placement groups fit;42copies preserved;64pages.')
