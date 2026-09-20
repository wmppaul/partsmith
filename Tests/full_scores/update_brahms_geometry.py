"""Reviewer helper: audit-native geometry/settings and explicit source cue overrides.
This creates no PDF and changes no production algorithm. Guards are independently
source-space envelopes; all draft guards require visual source review.
"""
import json,math,statistics,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def run(name, inventory):
 path=ROOT/f'Tests/full_scores/brahms-{name}-map.json';m=json.loads(path.read_text());inv=json.loads((ROOT/inventory).read_text());profile=m['profile']
 profile.update({'topPaddingStaffSpaces':10.25 if name=='quartet' else 10,'bottomPaddingStaffSpaces':9 if name=='quartet' else 10,'leftTrimPoints':16 if name=='quartet' else 0,'rightTrimPoints':10 if name=='quartet' else 0})
 if name=='quartet':
  next(p for p in profile['parts'] if p['id']=='violin1')['topPaddingStaffSpaces']=11
 if name=='trio':
  next(p for p in profile['parts'] if p['id']=='piano').update({'topPaddingStaffSpaces':9,'bottomPaddingStaffSpaces':9})
 m['inventory']=inventory;m['reviewStatus']='source_counts_and_common_cues_reviewed_native_crop_geometry_under_review'
 overrides=[];movements={(x['pageIndex'],x['systemIndex']):x['label'] for x in m['movements']}
 for page,obs in zip(m['pages'],inv['pages']):
  assert page['pageIndex']==obs['pageIndex'];n=page['expectedPhysicalStaves'];staves=obs['staves'];page['nativeDetectedStaves']=len(staves)
  if not n:
   overrides.append({'pageIndex':page['pageIndex'],'reason':page['reason'],'nonMusicReason':page['reason'],'ignoredCandidateIDs':[s['id'] for s in staves],'systems':[]});continue
  assert len(staves)==n,(name,page['pageNumber'],n,len(staves))
  height=obs['pageHeight'];width=obs['pageWidth'];skew=abs(math.tan(math.radians(obs.get('analysisSkewDegrees',0))))*width/2
  page.update({'pageWidth':width,'pageHeight':height,'nativeAnalysisSkewDegrees':obs.get('analysisSkewDegrees',0),'systems':[],'geometryReview':'draft_profile_envelopes_need_visual_confirmation'})
  cues=[c for c in m['sharedMarkings'] if c['pageIndex']==page['pageIndex']]
  for si in range(page['expectedSystems']):
   system={'systemIndex':si,'bands':[],'omittedParts':[]};j=si*4
   if (page['pageIndex'],si) in movements:system['movementLabel']=movements[(page['pageIndex'],si)]
   for part in profile['parts']:
    selected=staves[j:j+part['staffCount']];j+=part['staffCount'];spaces=[(s['staffLineFractions'][4]-s['staffLineFractions'][0])*height/4 for s in selected];space=max(spaces)
    first=selected[0]['staffLineFractions'][0]*height;last=selected[-1]['staffLineFractions'][4]*height
    top=part.get('topPaddingStaffSpaces',profile['topPaddingStaffSpaces'])*space;bottom=part.get('bottomPaddingStaffSpaces',profile['bottomPaddingStaffSpaces'])*space
    rect=[profile['leftTrimPoints'],max(0,first-top-skew),width-profile['rightTrimPoints'],min(height,last+bottom+skew)]
    # Source-defined line-envelope guard, deliberately less generous than crop.
    guardtop=(30 if name=='quartet' else (34 if part['id']=='piano' else 28))+skew
    guardbottom=(26 if name=='quartet' else (35 if part['id']=='piano' else 28))+skew
    guard=[rect[0]+(3 if name=='quartet' else 0),max(0,math.floor(first-guardtop)),rect[2]-(3 if name=='quartet' else 0),min(height,math.ceil(last+guardbottom))]
    b={'partID':part['id'],'candidateIDs':[s['id'] for s in selected], 'sourceRect':[round(v,3) for v in rect],'staffLineRects':[[profile['leftTrimPoints'],round(s['staffLineFractions'][0]*height,3),width-profile['rightTrimPoints'],round(s['staffLineFractions'][4]*height,3)] for s in selected], 'protectedRegions':[{'rect':guard,'description':'Source-space staff and surrounding target notation envelope; source visual comparison required before final acceptance.'}],'exclusions':[],'neighborNotation':'permitted','sourceMarkings':[c['rect'] for c in cues if c['systemIndex']==si and part['id'] in c['targetPartIDs']]}
    for cue in cues:
     sourceOwner=('cello' if 'violin1' in cue['targetPartIDs'] else 'violin1') if name=='quartet' else 'clarinet'
     if cue['systemIndex']==si and part['id']==sourceOwner:
      b['protectedRegions'].append({'rect':cue['rect'],'description':'Visually verified original shared source marking: '+cue['text']})
    if 'movementLabel' in system:b['pageBreakBefore']=True
    system['bands'].append(b)
   page['systems'].append(system)
  # Only pages with movement headings/shared cues require native planner override.
  if cues or any('movementLabel' in s for s in page['systems']):
   systems=[]
   for ss in page['systems']:
    ns={'systemIndex':ss['systemIndex'],'bands':[],'omittedParts':[]}
    if 'movementLabel' in ss:ns['movementLabel']=ss['movementLabel']
    for b in ss['bands']:
     nb={k:b[k] for k in ['partID','candidateIDs','sourceMarkings','pageBreakBefore'] if k in b}
     ns['bands'].append(nb)
    systems.append(ns)
   overrides.append({'pageIndex':page['pageIndex'],'reason':'Source-reviewed common directions/movement boundary; detected staff identity/order confirmed. No detector/crop replacement.','systems':systems})
 m['nativeStaffCount']=sum(len(p['staves']) for p in inv['pages']);m['overridePurpose']='Common source markings and movement pagination; no custom source rectangles unless separately documented.'
 path.write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n');(ROOT/f'Tests/full_scores/{name}-overrides.json').write_text(json.dumps(overrides,indent=2,ensure_ascii=False)+'\n');(ROOT/f'Tests/full_scores/{name}-profile.json').write_text(json.dumps(profile,indent=2,ensure_ascii=False)+'\n')
 print(name,'systems',sum(p['expectedSystems'] for p in m['pages']),'page overrides',len(overrides),'cuefragments',len(m['sharedMarkings']))
if __name__=='__main__':run(sys.argv[1],sys.argv[2])
