from pathlib import Path
import json,hashlib,datetime,copy
from PIL import Image
R=Path('Tests/quality_control/notehead-provenance-independent-2026-10-03');a=json.load(open(R/'helper-inputs.json'));D={r['id'].split('-')[0]:r for r in a['cases']}; measured=[]; cases=[]
for id,cols in [('P01',(885,907)),('P02',(204,218)),('P03',(223,233)),('P05',(415,421))]:
 c=copy.deepcopy(D[id]);im=Image.open(c['imagePath']).convert('L'); records=[]; lines=[]
 for i,pred in enumerate(c['staffLinesAtSpine']):
  x0,x1=cols;y0,y1=round(pred)-4,round(pred)+4
  if id=='P05' and i==4:x0,x1,y0,y1=437,441,367,375
  profile=[sum(255-im.getpixel((x,y)) for x in range(x0,x1)) for y in range(y0,y1)]
  center=sum(y*v for y,v in zip(range(y0,y1),profile))/sum(profile)
  lines.append(center);records.append({'lineOrdinal':i,'sourceSampleROI':[x0,y0,x1,y1],'rowTotalDarkness':profile,'center':center,'method':'Weighted center of untouched grayscale darkness in independently inspected short staff-only fragment; no candidate fit or output used.'})
 c['staffLinesAtSpine']=lines;c['geometryProvenance']='Separate source-measured local-line diagnostic. Fixed source body/spine, physical stroke, staffSpace and slope unchanged from first helper adapter.';cases.append(c);measured.append({'id':c['id'],'originalLines':D[id]['staffLinesAtSpine'],'sourceMeasuredLines':lines,'samples':records})
(R/'local-line-source-measurements.json').write_text(json.dumps({'frozenBeforeDiagnosticHelperRun':True,'timeUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'holdoutsSHA256':hashlib.sha256((R/'holdouts.json').read_bytes()).hexdigest(),'measurements':measured},indent=2)+'\n')
(R/'local-line-helper-inputs.json').write_text(json.dumps({'holdoutsSHA256':hashlib.sha256((R/'holdouts.json').read_bytes()).hexdigest(),'scope':'Only four in-search own-stem positives; source-measured local staff rows replace original global fit. All other inputs remain exact. This was prepared after v1 primary results to audit input fidelity, not a blind new holdout.','cases':cases},indent=2)+'\n')
print('measurementSHA',hashlib.sha256((R/'local-line-source-measurements.json').read_bytes()).hexdigest())
for x in measured:print(x['id'],[round(v,3) for v in x['sourceMeasuredLines']])
