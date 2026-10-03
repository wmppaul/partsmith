from pathlib import Path
import json,math,statistics,hashlib
from PIL import Image
R=Path('Tests/quality_control/notehead-provenance-independent-2026-10-03');h=json.load(open(R/'holdouts.json')); pages={x['id']:x for x in h['pages']}
old=json.load(open('.build/terminal-body-continuation-2026-10-03/diagnostics/witnesses.json')); old={r['id']:r for r in old}
replay=json.load(open(R/'native-replay-inputs.json'));rp={r['id']:r for r in replay}
positives={'P01':(3,False),'P02':(7,True),'P03':(3,False),'P04':(0,True),'P05':(3,False),'P06':(17,True),'P07':(18,False),'N01':(3,False),'N02':(3,False)}
out=[]
for c in h['cases']:
 pid=c['pageID']; p=pages[pid]; native=rp[pid]['page'];W,H=p['rasterSize'];slope=math.tan(native.get('analysisSkewDegrees',0)*math.pi/180); box=c['testedSpineROI'];cx=(box[0]+box[2])/2
 if c['id'].startswith('F'):
  w=old[pid]['witnesses'][c['priorFalseWitness']['witnessIndex']];staffid=w['staffID'];upper=w['upper'];staff=next(s for s in native['staves'] if s['id']==staffid);lines=[a*H+w['shift'] for a in staff['staffLineFractions']];space=w['space'];geo='Exact frozen diagnostic staff-line coordinates plus recorded actual core shift; old witness only specifies test location, not expected classification.'
 else:
  staffid,upper=positives[c['id'].split('-')[0]];staff=next(s for s in native['staves'] if s['id']==staffid);lines=[a*H+slope*(cx-W/2) for a in staff['staffLineFractions']];space=(lines[4]-lines[0])/4;geo='Frozen native staff geometry at independently source-selected tested spine; no body labels inferred from native component ownership.'
 # Measure actual black spine columns inside the immutable corridor using rows away from the head and staff lines.
 im=Image.open(R/p['raster']).convert('L'); xs=[]
 for y in range(box[1],box[3]):
  if c['bodyROI'][1]<=y<c['bodyROI'][3] or any(abs(y-v)<=2 for v in lines):continue
  cols=[x for x in range(box[0],box[2]) if im.getpixel((x,y))<190]
  if cols:xs.append((min(cols),max(cols)+1))
 physical=[round(statistics.median(x[0] for x in xs)),round(statistics.median(x[1] for x in xs))] if xs else [box[0],box[2]]
 out.append({'id':c['id'],'pageID':pid,'imagePath':str((R/p['raster']).resolve()),'imageSHA256':p['rasterSHA256'],'strokeLeft':physical[0],'strokeRight':physical[1],'staffSpace':space,'staffLinesAtSpine':lines,'skewSlope':slope,'upper':upper,'sourceCorridor':box,'physicalSpineMeasurement':{'method':'Median black row-run endpoints inside frozen corridor, excluding frozen head vertical interval and staff lines +/-2 rows; threshold190 matches native original pixels. Measurements fixed before helper execution.','sampleRows':len(xs)},'geometryProvenance':geo,'sourceBodyROI':c['bodyROI'],'bodyCenterInHelperVerticalSearchRange':(-.5*space <= ((sum(c['bodyROI'][1::2])/2-lines[0]) if upper else (lines[4]-sum(c['bodyROI'][1::2])/2)) <=1.5*space)})
(R/'helper-inputs.json').write_text(json.dumps({'holdoutsSHA256':hashlib.sha256((R/'holdouts.json').read_bytes()).hexdigest(),'parametersPreparedBeforeHelperExecution':True,'cases':out},indent=2)+'\n')
print([(r['id'],[r['strokeLeft'],r['strokeRight']],r['bodyCenterInHelperVerticalSearchRange']) for r in out[:9]])
