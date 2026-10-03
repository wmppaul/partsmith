from pathlib import Path
import hashlib,json
import pymupdf
r=Path('Tests/quality_control/residual7-source-2026-10-03');out=r/'source';out.mkdir(exist_ok=True)
source=Path('sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf')
corrected=Path('.build/brahms-continuation-release-2026-10-03/output-review/candidate-parts/rectified-review-source.pdf')
previousCorrected=Path('.build/qc-brahms-traced-ending-combination/parts/rectified-review-source.pdf')
currentInventory=Path('.build/brahms-continuation-release-2026-10-03/candidate/brahms-inventory.json')
currentPlan=Path('.build/brahms-continuation-release-2026-10-03/candidate/brahms-plan.json')
previousActual=Path('.build/residual9-boundary-2026-10-03/candidate-v2/actual.json')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
ci=json.load(open(currentInventory));cp=json.load(open(currentPlan));pa=json.load(open(previousActual))
assert ci['sourceSHA256']==pa['sourceSHA256']==sha(source)
assert ci['rectifications']==pa['rectifications'] and len(ci['rectifications'])==9
coreFields=['pageIndex','pageWidth','pageHeight','imageWidth','imageHeight','analysisSkewDegrees','staves']
for a,b in zip(ci['pages'],pa['pages']):
 assert all(a[k]==b[k] for k in coreFields)
 assert sorted(a['inkComponents'],key=lambda x:json.dumps(x,sort_keys=True))==sorted(b['inkComponents'],key=lambda x:json.dumps(x,sort_keys=True))
cb={b['id']:b for p in cp['pages'] for b in p['assignments']};pb={b['id']:b for p in pa['plan']['pages'] for b in p['assignments']};assert cb.keys()==pb.keys()
fields=['topFraction','bottomFraction','leftFraction','rightFraction','candidateIDs','partID','pageIndex','systemIndex']
diffs=[{'id':k,'changes':{f:[pb[k][f],cb[k][f]] for f in fields if pb[k][f]!=cb[k][f]}} for k in cb if any(pb[k][f]!=cb[k][f] for f in fields)]
remaining=['p24-s2-viola','p24-s2-cello','p28-s1-violin1','p28-s1-violin2','p31-s1-violin2','p35-s1-violin1','p35-s1-violin2']
assert all(all(cb[k][f]==pb[k][f] for f in fields) for k in remaining)
docs={label:pymupdf.open(path) for label,path in [('original',source),('current-corrected',corrected),('previous-corrected',previousCorrected)]}
settings={24:{'context':[0,225,427,326],'detail':[330,238,399,319],'staffIDs':[6,7],'nativeConnector':[1636,1644],'nativeSize':[1800,2593]},28:{'context':[0,0,427,112],'detail':[65,26,130,100],'staffIDs':[0,1],'nativeConnector':[244,250],'nativeSize':[1068,1538]},31:{'context':[0,0,427,123],'detail':[315,22,402,116],'staffIDs':[0,1],'nativeConnector':[1644,1651],'nativeSize':[1800,2593]},35:{'context':[0,0,426,124],'detail':[315,24,401,117],'staffIDs':[0,1],'nativeConnector':[1641,1648],'nativeSize':[1800,2594]}}
regions=[]
for pn,job in settings.items():
 row={'page':pn,**job,'images':{}}
 for label in ['original','current-corrected','previous-corrected']:
  p=docs[label][pn-1];pix=p.get_pixmap(matrix=pymupdf.Matrix(4,4),colorspace=pymupdf.csGRAY,alpha=False)
  row.setdefault('fullPageRenderSHA256',{})[label]=hashlib.sha256(pix.samples).hexdigest()
  if label=='previous-corrected':continue
  for kind,scale in [('context',4),('detail',8)]:
   rect=pymupdf.Rect(job[kind]);image=p.get_pixmap(matrix=pymupdf.Matrix(scale,scale),clip=rect,colorspace=pymupdf.csGRAY,alpha=False)
   path=out/f'p{pn}-{label}-{kind}.png';image.save(path)
   row['images'][label+'-'+kind]={'path':str(path),'sha256':sha(path),'pdfBounds':list(rect),'pixelsPerPoint':scale,'rasterSize':[image.width,image.height],'pixelOriginOnFullPage':[image.x,image.y]}
  row.setdefault('embeddedImages',{})[label]=[{'width':i[2],'height':i[3],'bits':i[4]} for i in p.get_images(full=True)]
 assert row['fullPageRenderSHA256']['current-corrected']==row['fullPageRenderSHA256']['previous-corrected']
 if pn!=28:assert row['fullPageRenderSHA256']['original']==row['fullPageRenderSHA256']['current-corrected']
 row['appliedRectification']=next((q for q in ci['rectifications'] if q['pageIndex']==pn-1),None)
 row['currentBands']=[cb[k] for k in remaining if k.startswith(f'p{pn}-')]
 regions.append(row)
files=[source,corrected,previousCorrected,currentInventory,currentPlan,previousActual,r/'source-guards.json',Path('Partsmith/Core/Detection/NativeScorePageAnalyzer.swift')]
(r/'source-binding.json').write_text(json.dumps({'head':'82b606e','files':[{'path':str(p),'sha256':sha(p)} for p in files],'all39NativeGeometryAndComponentSignaturesEqual':True,'all604BandIdentitiesEqual':True,'nineRectificationsEqual':True,'mainCropMetadataDifferences':diffs,'remainingSevenCropsExact':True,'regions':regions},indent=2)+'\n')
print('All seven target crops exact; main plan differences',diffs)
