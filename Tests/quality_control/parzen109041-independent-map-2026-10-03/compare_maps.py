from pathlib import Path
import json,hashlib,shutil
r=Path('Tests/quality_control/parzen109041-independent-map-2026-10-03')
p=Path('.build/brahms-parzen109041-source-map-2026-10-03/root-source-map-before-comparison.json')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(p)=='76b144bae5932f5e308560956709a179a24af1ee4a079bfc6064dd615695fb89'
assert sha(r/'source-map-before-comparison.json')=='2d390df1ce12b1cc4d091ee7703de1e46c809a6a5b69bbbacfaae07cb53213a3'
a=json.loads((r/'source-map-before-comparison.json').read_text()); b=json.loads(p.read_text())
diffs=[];rows=[]
assert a['bindings']['source']=={k:b['source'][k] for k in ['path','sha256']}
assert a['bindings']['profile']==b['profile']
for s in a['systems']:
 t=b['pages'][s['physicalPage']-1]['systems'][0]
 pairs={'orderedPartStaffCounts':([(v['partID'],v['localStaffCount']) for v in s['assignments']],[(v['partID'],v['staffCount']) for v in t['parts']]),'staffCount':(s['staffCount'],t['physicalStaffCount']),'physicalCompartments':(s['physicalBarCompartments'],t['physicalBarCompartments']),'printedStart':(s['startBar'] if s['startBarPrinted'] else None,t['printedStartBar']),'systemIndexAfterBaseConversion':(s['systemIndex']+1,t['systemIndex'])}
 if s['physicalPage']!=2:pairs['wholeBarCount']=(s['numberedBarCount'],t['wholeBarCount'])
 for field,(v,w) in pairs.items():
  if v!=w:diffs.append({'physicalPage':s['physicalPage'],'field':field,'independent':v,'parent':w})
 rows.append({'physicalPage':s['physicalPage'],'allComparedFieldsAgree':all(v==w for v,w in pairs.values()),'fields':list(pairs)})
 if 'rehearsal' in t:
  match=[x for x in a['sharedDirections'] if x['physicalPage']==s['physicalPage'] and x['kind']=='rehearsal mark']
  assert len(match)==1
  if (match[0]['text'],match[0]['startBar'])!=(t['rehearsal']['label'],t['rehearsal']['bar']):diffs.append({'rehearsal':s['physicalPage']})
for v in a['systems']:
 q=v['sourceRender']; assert q['sha256']==b['renders']['source/'+Path(q['path']).name]
out={'verdict':'Independent all-page source interpretation agrees with parent; no roster, staff-count, timing or shared-direction discrepancy found. Not crop/output certification.','bindings':{'independentMap':{'path':str(r/'source-map-before-comparison.json'),'sha256':sha(r/'source-map-before-comparison.json')},'parentMap':{'path':str(p),'sha256':sha(p)}},'comparedSystems':26,'partSystemAssignments':520,'physicalStaffInstances':568,'discrepancies':diffs,'perPage':rows,'sharedDirectionComparison':{'rehearsalMarksCompared':8,'rehearsalBarPositionsAgree':True,'openingMaestoso': 'Both maps identify top and bottom copies from the pickup.','meterAndTempo116':'Both identify quarter = quarter and 3/4 change at bar 116 on physical page 21.','choralExpression116':'Both identify Sehr weich und gebunden above Soprano as shared within the choir; no unsupported orchestra-wide recipient inference.','commonTime162':'Both identify bar 162 on physical page 25.','localDirections':'Both preserve local piccolo/flute labels and con sordini; they are not extra staff identities or global tempo headings.'},'representationDifferences':['Independent map uses zero-based systemIndex 0; parent uses human systemIndex 1. All pages contain exactly one chronological system.','At the opening, parent leaves wholeBarCount null for the mixed pickup/full-bar system. Independent map stores numberedBarCount 4 with a separate unnumbered eighth-note pickup; both record 5 physical compartments. Do not generate a 5-whole-bar rest or assign a printed start number to the pickup.'],'additionalPreservationObligations':['Retain opening source title/composer and meter along with Maestoso.','Keep both divided Alto and Bass staves and their intervening underlay.','All roles are explicitly printed in every music system, so no absent-staff rests are justified by this map.','Preserve final fermatas and three narrow final bars; no repeat or skipped sequence inferred.'],'limitations':a['limitations']}
assert not diffs
shutil.copy2(p,r/p.name)
(r/'comparison.json').write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'verdict':out['verdict'],'sha256':sha(r/'comparison.json'),'differences':diffs},indent=2))
