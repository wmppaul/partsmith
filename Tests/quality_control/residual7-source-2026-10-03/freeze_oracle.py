from pathlib import Path
import json,hashlib
import numpy as np
import pymupdf
from PIL import Image
out=Path('Tests/quality_control/residual7-source-2026-10-03');src=out/'source'
original=Path('sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf')
corrected=Path('.build/brahms-continuation-release-2026-10-03/output-review/candidate-parts/rectified-review-source.pdf')
docs={'original':pymupdf.open(original),'corrected':pymupdf.open(corrected)}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def runs(values,base,step):
 result=[];start=0
 for i in range(1,len(values)+1):
  if i==len(values) or values[i]!=values[start]:
   result.append({'observedInk':bool(values[start]),'begin':base+start*step,'end':base+i*step,'length':(i-start)*step});start=i
 return result
def raster(page,rect,scale=16):
 pix=page.get_pixmap(matrix=pymupdf.Matrix(scale,scale),clip=pymupdf.Rect(rect),colorspace=pymupdf.csGRAY,alpha=False)
 return pix,np.frombuffer(pix.samples,np.uint8).reshape(pix.height,pix.width)
# Manually identified after full-source and local-context visual inspection.
# Corridors are NOT imported from an analyzer or fitted to a proposed new crop.
spines=[(24,'original',[388,252.5,390.5,300]),(28,'original',[101,38,104,83]),(28,'corrected',[97.5,40,100.5,85]),(31,'original',[389.5,47,392.5,92]),(35,'original',[388,48,390.5,95])]
struct=[]
for pn,label,rect in spines:
 p=docs[label][pn-1];pix,a=raster(p,rect);path=src/f'p{pn}-{label}-structural-spine.png';pix.save(path)
 # Per source row retain ALL observed dark x-runs in the hand-selected corridor.
 # Gap rows remain gaps. No bridge pixels are invented.
 rows=[]
 for yi,row in enumerate(a):
  ink=row<128
  rows.append({'y':(pix.y+yi)/16,'darkRuns':[[pix.x/16+r['begin'],pix.x/16+r['end']] for r in runs(ink,0,1/16) if r['observedInk']]})
 present=(a<128).any(axis=1)
 struct.append({'page':pn,'coordinateSpace':label,'pdfBounds':rect,'pixelsPerPoint':16,'pixelOrigin':[pix.x,pix.y],'path':str(path),'sha256':sha(path),'note':'Observed source raster only; interpolation adds no source resolution. A line junction can occupy a row even where the longitudinal spine is absent. This envelope is not permission to delete attachments.','verticalRuns':runs(present,pix.y/16,1/16),'rows':rows})
lineSettings=[(31,[330,43,394,65],[345,391],[46.5,48.8],[[345,357.375]],[[360.8125,364],[367.8125,373.5],[375,379.25]],'The late descending noteheads intersect this corridor. Column ink is not independently observed staff-line continuity.'),(35,[235,44,278,65],[240,275],[49,51.2],[[240,248.9375],[249.1875,251.0625],[252.75,253.125],[254.3125,256.8125],[261.75,274.9375]],[[253.125,254.3125]],'One vertical stem crosses the line near x254; source ink on that crossing is ambiguous. Clear horizontal fragments flank it.')]
lineRows=[]
for pn,rect,xrange,yrange,certified,occluded,note in lineSettings:
 pix,a=raster(docs['original'][pn-1],rect);path=src/f'p{pn}-line-fragments.png';pix.save(path)
 row={'page':pn,'coordinateSpace':'original','pdfBounds':rect,'pixelOrigin':[pix.x,pix.y],'pixelsPerPoint':16,'image':str(path),'sha256':sha(path),'measuredXInterval':xrange,'measuredYCorridor':yrange,'visuallyCertifiedHorizontalFragments':certified,'musicalOrCrossingOcclusions':occluded,'interpretation':note,'thresholds':[]}
 for threshold in [128,224]:
  y0=int(yrange[0]*16)-pix.y;y1=int(yrange[1]*16)-pix.y
  x0=int(xrange[0]*16)-pix.x;x1=int(xrange[1]*16)-pix.x
  present=(a[y0:y1,x0:x1]<threshold).any(axis=0);rr=runs(present,xrange[0],1/16)
  row['thresholds'].append({'grayLessThan':threshold,'runs':rr,'longestLiteralWhiteGapPoints':max(r['length'] for r in rr if not r['observedInk'])})
 lineRows.append(row)
# Local musical preservation obligations supplement, never replace, the ten
# frozen whole-target guards. Bounds are source-first, not candidate crop edges.
protected=[
 (24,'Viola','final note, stem and slur',[377,253,388.5,268.5]),
 (24,'Viola','final hairpin pair',[348.5,268,388,274]),
 (24,'Cello','high final note and slur',[378,273.5,388.5,295]),
 (24,'Cello','sharp and preceding high half note',[360.5,278,373,295]),
 (24,'Cello','final hairpin pair',[348,302,387,307.5]),
 (28,'Violin I','pre-barline flagged note and slur endpoint',[87.5,33,95,52]),
 (28,'Violin I','post-barline note and upper slur start',[102.5,29,116,49]),
 (28,'Violin II','pre-barline low flagged note',[88.5,75,97,90]),
 (28,'Violin II','post-barline low note, stem and dot',[103,75,110.5,95]),
 (31,'Violin I','final beamed descending notes, slur and detached last note',[349,33,386.5,65]),
 (31,'Violin II','last flagged note pair, lower slur and crescendo',[353,73,389.5,102]),
 (35,'Violin I','last beamed melody, dots and ledger notes',[327,26,378,66]),
 (35,'Violin II','rising beamed figure, low ledger note and full lower slur',[337.5,65,385.5,106])]
regions=[]
for i,(pn,owner,label,rect) in enumerate(protected,1):
 coordinate='corrected' if pn==28 else 'original';pix,a=raster(docs[coordinate][pn-1],rect,8)
 path=src/f'protected-{i:02d}-p{pn}-{owner.lower().replace(" ","-")}.png';pix.save(path)
 ys,xs=np.where(a<128)
 regions.append({'page':pn,'coordinateSpace':coordinate,'owner':owner,'content':label,'pdfBounds':rect,'pixelsPerPoint':8,'pixelOrigin':[pix.x,pix.y],'path':str(path),'sha256':sha(path),'observedInkBounds':[(pix.x+xs.min())/8,(pix.y+ys.min())/8,(pix.x+xs.max()+1)/8,(pix.y+ys.max()+1)/8],'obligation':'Retain complete crop envelope for this instrument. This box can contain staff-line pixels; it is not a per-pixel musical-ownership label.'})
result={'sourceFiles':[{'path':str(p),'sha256':sha(p)} for p in [original,corrected]],'existingTenGuardSHA256':sha(out/'source-guards.json'),'units':'Top-down PDF points; raster origins absolute. Row/run intervals half-open. Source labels refer to original vs rectified PDF, never inferred affine coordinates.','structuralSpines':struct,'staffLineMeasurements':lineRows,'protectedMusicalRegions':regions,'limitations':['Raster corridor membership is not stroke ownership. Shared note/barline pixels cannot be classified for deletion from this evidence alone.','No candidate crop bounds were used for local musical obligations. Complete instrument preservation still requires frozen whole-target guards and full-source inspection.','p28 corrected source is1780x2563 grayscale; original is2376x3417 monochrome.16ppi visualization adds interpolation, not underlying detail.']}
(out/'source-oracle.json').write_text(json.dumps(result,indent=2)+'\n')
print('Frozen',len(struct),'observed spines;',len(regions),'local musical obligations; SHA',sha(out/'source-oracle.json'))
