from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,math,collections,shutil
import numpy as np
root=Path.cwd();w=root/'.build/brahms-p34-dynamic-2026-10-03';o=root/'Tests/quality_control/brahms-p34-dynamic-2026-10-03';o.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def dump(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
rawImg=Path('.build/brahms-raw60-source-review-2026-10-03/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521/source-page-34.png'); correctedImg=Path('.build/brahms-source-span-full-replay-2026-10-03/rasters/page-34.png')
rawpaths=[Path('.build/envelope-compatibility-corpus-2026-10-03/baseline/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json'),Path('.build/monotone-line-corpus-2026-10-03/candidate/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json')]
correctedpaths=[Path('.build/ownership-alternatives-2026-10-03/actual.json'),Path('.build/brahms-monotone-compatibility-full-2026-10-03/candidate.json')]
raws=[json.loads(p.read_text()) for p in rawpaths];cors=[json.loads(p.read_text()) for p in correctedpaths]
assert sha(correctedImg)==json.loads(Path('.build/brahms-source-span-full-replay-2026-10-03/inputs.json').read_text())[str(correctedImg)]
def band(inv):return next(b for p in inv['plan']['pages'] if p['pageIndex']==33 for b in p['assignments'] if b['id']=='p34-s4-viola')
raw=Image.open(rawImg).convert('L');arr=np.array(raw);roi=(1185,2325,1280,2400);x0,y0,x1,y1=roi;m=arr[y0:y1,x0:x1]<255;seen=set();comps=[]
for y,x in zip(*np.where(m)):
 if(y,x) in seen:continue
 todo=[(y,x)];seen.add((y,x));cells=[]
 while todo:
  yy,xx=todo.pop();cells.append((int(xx+x0),int(yy+y0)))
  for dy in [-1,0,1]:
   for dx in [-1,0,1]:
    z=(yy+dy,xx+dx)
    if 0<=z[0]<m.shape[0] and 0<=z[1]<m.shape[1] and m[z] and z not in seen:seen.add(z);todo.append(z)
 comps.append(cells)
rawpixels=next(c for c in comps if len(c)==372);assert [min(x for x,y in rawpixels),min(y for x,y in rawpixels),max(x for x,y in rawpixels)+1,max(y for x,y in rawpixels)+1]==[1205,2347,1238,2385]
co=Image.open(correctedImg).convert('L');ca=np.array(co);cbox=(723,1389,744,1413);yy,xx=np.where(ca[cbox[1]:cbox[3],cbox[0]:cbox[2]]<255);cpixels=[(int(x+cbox[0]),int(y+cbox[1])) for y,x in zip(yy,xx)]
def obligation(name,pixels,image,im,b):
 bbox=[min(x for x,y in pixels),min(y for x,y in pixels),max(x for x,y in pixels)+1,max(y for x,y in pixels)+1]
 bottom=b['bottomFraction']*im.height
 runs=[]
 for y in sorted({y for x,y in pixels}):
  xs=sorted(x for x,yy in pixels if yy==y); start=prev=xs[0]
  for x in xs[1:]:
   if x!=prev+1:runs.append([y,start,prev+1]);start=x
   prev=x
  runs.append([y,start,prev+1])
 return {'name':name,'instrument':'Viola','sourcePage':34,'systemIndex':3,'bandID':'p34-s4-viola','symbol':'f','ownership':'The forte printed directly below the Viola low double stop, above Cello, confirmed visually in original full system.','image':str(image),'imageSHA256':sha(image),'imageSize':[im.width,im.height],'nonwhiteRule':'Original grayscale sample <255; unit pixel cells, including antialiasing. Raw mask is the isolated 8-connected f component; corrected mask uses the independently viewed tight f-only ROI, with source glyph and neighbor separated.','inkPixelBounds':bbox,'pdfBoundsInItsOwnCoordinateSpace':[bbox[0]/im.width*427,bbox[1]/im.height*614,bbox[2]/im.width*427,bbox[3]/im.height*614],'pixelCount':len(pixels),'pixelRuns':runs,'cropBottomPixel':bottom,'fullyIncludedPixels':sum(y+1<=bottom for x,y in pixels),'partiallyIntersectedPixels':sum(y<bottom<y+1 for x,y in pixels),'fullyOutsidePixels':sum(y>=bottom for x,y in pixels),'fullEnvelopePreserved':bbox[3]<=bottom}
rb,cb=band(raws[0]),band(cors[0]);assert rb['bottomFraction']==band(raws[1])['bottomFraction'];assert cb==band(cors[1])
rawobs=obligation('original uncorrected source',rawpixels,rawImg,raw,rb);cobs=obligation('saved corrected native source',cpixels,correctedImg,co,cb)
assert rawobs['fullyOutsidePixels']==184 and not rawobs['fullEnvelopePreserved'] and cobs['fullyOutsidePixels']==0 and cobs['fullEnvelopePreserved']
# Exact positive symbol masks: no existing guard is edited or reinterpreted.
dump(o/'independent-symbol-obligations.json',{'purpose':'New positive source preservation regression, separate from every pre-existing guard. Entire f is required in both source representations.','raw':rawobs,'corrected':cobs})
components=[]
for name,ins,path in [('raw production',raws[0],rawpaths[0]),('raw private95',raws[1],rawpaths[1]),('corrected production',cors[0],correctedpaths[0]),('corrected private95',cors[1],correctedpaths[1])]:
 p=ins['pages'][33];rw,rh=p['imageWidth'],p['imageHeight'];s14=next(s for s in p['staves'] if s['id']==14);s15=next(s for s in p['staves'] if s['id']==15)
 expected=[.67,.9068778979907264,.6877777777777778,.9211746522411128] if name.startswith('raw') else [.6779026217228464,.904885993485342,.6956928838951311,.9192182410423453]
 matches=[(i,c) for i,c in enumerate(p['inkComponents']) if c['bounds']==expected];assert len(matches)==1;i,c=matches[0]
 bounds=[v*(rw if j%2==0 else rh) for j,v in enumerate(c['bounds'])];mid=(bounds[0]+bounds[2])/2;nominal=s15['staffLineFractions'][0]*rh;slope=math.tan(math.radians(p['analysisSkewDegrees']));predicted=nominal+slope*(mid-rw/2)
 entry={'case':name,'inventory':str(path),'inventorySHA256':sha(path),'nativeImageSize':[rw,rh],'analysisSkewDegrees':p['analysisSkewDegrees'],'componentIndex':i,'component':c,'componentNativePixelBounds':bounds,'targetStaff':s14,'neighborStaff':s15,'neighborNominalFirstLinePixel':nominal,'neighborSkewProjectedFirstLineAtSymbolCenter':predicted,'componentOverlapsNominalNeighborCore':bounds[3]>=nominal,'componentOverlapsSkewProjectedNeighborCoreAtCenter':bounds[3]>=predicted,'crop':band(ins),'cropBottomPDFPoints':band(ins)['bottomFraction']*614,'cropBottomNativePixel':band(ins)['bottomFraction']*rh}
 components.append(entry)
rawcomponent=components[0];assert rawcomponent['component']['staffIDs']==[15];assert components[1]['component']['staffIDs']==[15];assert components[2]['component']['staffIDs']==components[3]['component']['staffIDs']==[]
# Source support and bounds formulas are read from the unchanged planner.
p=raws[0]['pages'][33];h=p['imageHeight'];st=rawcomponent['targetStaff'];space=(st['staffLineFractions'][4]-st['staffLineFractions'][0])/4;clear=max(space*.5,2/614)
selectedLast=next(c for c in p['inkComponents'] if c['bounds']==[.6894444444444444,.9076506955177743,.6922222222222222,.9099690880989181]);assert abs(selectedLast['bounds'][3]+clear-rb['bottomFraction'])<1e-12
near=arr[2385:2401,1205:1238];rowhits=np.where(np.any(near<255,axis=1))[0];assert int(rowhits.min()+2385)==2391
cause={'verdict':'Confirmed existing raw-source dynamic omission; corrected counterpart fully retained by both algorithms.','rawSourceFNonwhitePixels':372,'rawFullyOutsidePixels':184,'rawPartiallyIntersectedPixels':7,'rawFullyIncludedPixels':181,'correctedNonwhitePixels':len(cpixels),'correctedFullyOutsidePixels':0,'rawFBottomCellExclusive':2385,'rawNextCelloLineFirstNonwhiteRowInSameXSpan':2391,'originalSourceWhiteRowsBetweenSymbolAndNextLine':[2385,2391],'mechanism':'The analyzer assigns owners by global vertical component bounds intersecting nominal staff-row intervals, ignoring x-dependent staff slope/curvature. The detached raw f bottom2384 overlaps the Cello nominal first row2382.994 but is above the locally projected row2387.378. It therefore receives sole Cello ownership[15] although original source pixels show a gap. The planner skips foreign-owned components, detects possible low-dynamic ambiguity and emits a warning rather than retaining this component. The selected own dot sets the raw bottom; corrected f is unowned and is retained by detached-mark discovery.','rawBottomDerivation':{'selectedDot':selectedLast,'bottomClearanceNormalized':clear,'computedBottomNormalized':selectedLast['bounds'][3]+clear,'cropBottomNormalized':rb['bottomFraction']},'coordinateLimit':'The original visual landmark is measured in the1800x2589 PyMuPDF source render; native component geometry is in1800x2588. They are separately bound to the same PDF and must not be equated pixel-for-pixel. Corrected image is1068x1535 and its saved rectification is included. Global skew projection is a diagnostic; local original line position differs by several pixels, so it is not claimed to be exact measured tracing.','productionModified':False,'oldGuardsModified':False,'nativeReruns':False,'nextStep':'A private test should measure ownership against actual local numbered staff-line/core geometry at retained component pixels, instead of treating a global bbox/mean-row overlap as physical contact. Preserve original connected musical branches and baseline ownership evidence separately; any changed ownership must also be tested for crop shrinkage elsewhere. This is a falsifiable design hypothesis, not a proven safe patch.','mustPreserve':['All original filled/hollow head, ledger, tie and cross-staff musical-stem source masks at low resolution.','The original four-core mixed musical/structural fixtures and all27 head-at-junction separation negatives.','Case176 complete musical ownership, including its original650 missed middle-owner pixels, must remain an explicit unsolved requirement rather than be hidden by unchanged aggregates.','p35 independent ledger-note/slur guard and the unchanged other frozen Brahms source envelopes.','Detached dynamic touching or nearly touching a genuine next-staff beam must never erase that beam or neighboring notation.','Page curvature and per-line endpoints must be measured locally; the page-average skew alone is insufficient.']}
dump(o/'component-mapping.json',components);dump(o/'cause.json',cause);dump(o/'saved-page34-rectification.json',next(r for r in cors[0]['rectifications'] if r['pageIndex']==33))
# Display only: original pixels plus a separate red crop-edge annotation.
for name,im,box,bottom in [('raw',Image.open(rawImg).convert('RGB'),(1185,2325,1280,2400),rawobs['cropBottomPixel']),('corrected',Image.open(correctedImg).convert('RGB'),(700,1360,780,1430),cobs['cropBottomPixel'])]:
 detail=im.crop(box).resize(((box[2]-box[0])*6,(box[3]-box[1])*6),Image.Resampling.NEAREST);detail.save(o/(name+'-source-detail.png'));d=ImageDraw.Draw(detail);d.line((0,(bottom-box[1])*6,detail.width,(bottom-box[1])*6),fill='red',width=2);detail.save(o/(name+'-crop-edge.png'))
sourcepaths=[*rawpaths,*correctedpaths,rawImg,correctedImg,Path('.build/brahms-source-span-full-replay-2026-10-03/inputs.json'),Path('Partsmith/Core/Detection/NativeScorePageAnalyzer.swift'),Path('Partsmith/Core/Detection/ScoreExtractionPlanner.swift')]
dump(o/'input-bindings.json',{str(p):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sourcepaths})
(o/'README.md').write_text('''# Brahms page 34: existing Viola forte omission

The original raw crop cuts the lower hook of the Viola **f** at system 4. This is an actual target-preservation defect in both the production and private95 raw plans. The source-defined symbol mask contains372 nonwhite pixels:184 lie entirely below the crop, seven intersect its edge, and181 are fully included. The whole symbol is required; compatibility between algorithms does not excuse the loss.

The saved corrected page retains the complete counterpart. Both corrected plans have exactly the same crop, ending at566.4 PDF points / native y1416. The independently viewed corrected symbol ends by native y1412, leaving four pixels of space. This finding does not assert a defect in the corrected delivery.

The frozen raw component is separate from the Cello graph, but the analyzer gives it Cello owner15 because its vertical bounding box reaches y2384 while the nominal Cello core starts at2382.994. Ownership currently tests these global vertical intervals without accounting for the component x position. At the symbol center, the existing0.78-degree skew projects that first line to2387.378. The original source also visibly has blank space between the f and the Cello line. The corrected component receives no owner and is kept by the planner; the raw foreign-owned component is excluded and a lower-edge warning is emitted.

The two raster coordinate systems remain distinct: original source review is1800x2589, frozen raw native geometry1800x2588, corrected native raster1068x1535. The global skew estimate is diagnostic, not an exact local trace; the measured original line lies several pixels beyond its projection. `component-mapping.json` binds all four inventories and records the exact values. `independent-symbol-obligations.json` adds positive source masks for the complete dynamic without modifying any old guard.

A bounded next test could replace nominal-row ownership inference with contact against measured local numbered line geometry at the component pixels, while preserving musical branches and auditing every ownership change for lost ink. This is only a hypothesis. It must preserve existing ledger/head/slur and mixed four-core controls, including low-resolution and junction negatives; merely capping the crop or deleting neighbor pixels is not a solution. No production change, native rerun or source-mask relaxation was made here.
''')
# Normalize prose spacing without changing numerical evidence.
p=o/'README.md';s=p.read_text();
for a,b in [('contains372','contains 372'),(':184',': 184'),('and181','and 181'),('at566.4','at 566.4'),('owner15','owner 15'),('y2384','y2384'),('at2382.994','at 2382.994'),('existing0.78','existing 0.78'),('to2387.378','to 2387.378'),('is1800','is 1800'),('geometry1800','geometry 1800'),('raster1068','raster 1068')]:s=s.replace(a,b)
p.write_text(s)
shutil.copy2(__file__,o/'freeze.py');manifest={str(p.relative_to(o)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(o.iterdir()) if p.is_file() and p.name!='manifest.json'};dump(o/'manifest.json',manifest)
print(json.dumps({'raw':{k:rawobs[k] for k in ['inkPixelBounds','pdfBoundsInItsOwnCoordinateSpace','pixelCount','fullyIncludedPixels','partiallyIntersectedPixels','fullyOutsidePixels']},'corrected':{k:cobs[k] for k in ['inkPixelBounds','pdfBoundsInItsOwnCoordinateSpace','pixelCount','fullyOutsidePixels']},'report':str(o),'manifestSHA256':sha(o/'manifest.json')},indent=2))
