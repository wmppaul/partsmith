import json,hashlib,shutil
from pathlib import Path
base=Path('.build/parzen109041-independent-map-2026-10-03')
report=Path('Tests/quality_control/parzen109041-independent-map-2026-10-03'); report.mkdir(parents=True,exist_ok=True)
read=lambda p: json.loads(Path(p).read_text())
sha=lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
protocol=read(base/'protocol-before-comparison.json')
for b in [protocol['source'],protocol['profile']]+protocol['renderBindings']: assert sha(b['path'])==b['sha256'],b['path']
parts=read(protocol['profile']['path'])['parts']; ids=[p['id'] for p in parts]
starts=[1,5,12,21,26,31,37,42,47,53,58,64,70,76,82,87,93,100,106,111,119,130,141,153,163,168]
counts=[4,7,9,5,5,6,5,5,6,5,6,6,6,6,5,6,7,6,5,8,11,11,12,10,5,9]
assert len(starts)==len(counts)==26
assert all(starts[i]+counts[i]==starts[i+1] for i in range(25))
assert sum(counts)==176
systems=[]
for i,(start,count) in enumerate(zip(starts,counts)):
    page=i+2; ranks=[]; next_rank=1
    for part in parts:
        n=2 if page>=4 and part['id'] in ('alto-section','bass-section') else 1
        ranks.append({'partID':part['id'],'localStaffCount':n,'physicalStaffOrdinals':list(range(next_rank,next_rank+n))})
        next_rank+=n
    systems.append({'physicalPage':page,'pageIndex':page-1,'systemIndex':0,'printedEditionPage':page+1,
      'startBar':start,'startBarPrinted':page!=2,'numberedBarCount':count,'lastNumberedBar':start+count-1,
      'physicalBarCompartments':count+(page==2),'pickupBeforeBar1':{'duration':'eighth note','numbered':False} if page==2 else None,
      'staffCount':next_rank-1,'assignments':ranks,'omittedRoles':[],
      'barCountEvidence':'Visible aligned barlines counted independently across the system; checked against the next printed start.' if page<27 else 'Nine visible compartments from printed 168 through the final double bar; final three narrow whole-note/rest bars counted separately.',
      'sourceRender':protocol['renderBindings'][page-1]})
def direction(page,bar,text,kind,scope,locations,notes=''):
    return dict(physicalPage=page,startBar=bar,text=text,kind=kind,recipientScope=scope,printedLocations=locations,notes=notes)
shared=[direction(2,1,'Maestoso','tempo',ids,['above Flutes at pickup','below Double bass at pickup'],'Applies from the unnumbered opening eighth-note pickup; text appears at both outer edges of the full system.')]
for page,bar,letter in [(4,18,'A'),(7,35,'B'),(10,48,'C'),(12,60,'D'),(15,80,'E'),(17,90,'F'),(23,130,'G'),(24,144,'H')]:
    shared.append(direction(page,bar,letter,'rehearsal mark',ids,['above Flutes','below Double bass']))
shared += [direction(21,116,'quarter note = quarter note','tempo equivalence',ids,['above Flutes','below Double bass'],'Parentheses are printed around the two equal filled quarter-note symbols. Preserve original source glyphs; no metronome number. Coincides with 4/4 to 3/4 change.'),
 direction(21,116,'Sehr weich und gebunden','shared choral expression',['soprano','alto-section','tenor','bass-section'],['above Soprano at the 3/4 entrance'],'Printed once over the choral group. This review establishes the choral obligation; it does not infer that every orchestral recipient requires this expression.')]
local=[
 {'physicalPage':2,'text':'pesante','scope':'Printed beside individual orchestral/string rows; retain their own source notation, not a single whole-score heading.'},
 {'physicalPage':15,'text':'sempre più f','scope':'Repeated above all six choral voices near bar 79; local source retention.'},
 {'physicalPage':16,'text':'molto marcato','scope':'Printed for Bassoons/Contrabassoon and lower strings at bar 84; not a global tempo change.'},
 {'physicalPage':19,'text':'p sotto voce','scope':'Repeated at the separate choral entrances, not a single global heading.'},
 {'physicalPage':22,'text':'p dolcissimo / espress.','scope':'Local instrumental phrases / Tenor entrance; do not apply to every part.'},
 {'physicalPage':24,'text':'dolcissimo / pizz. / arco','scope':'Printed local technique/expression marks; preserve per source staff.'},
 {'physicalPage':25,'text':'1. kl. Flöte; con sordini; pp sempre, ma marcato','scope':'Piccolo doubling remains on the Flutes row. Con sordini appears separately for Violin I, Violin II, Viola and Cello; not Double bass. Expression remains local.'},
 {'physicalPage':26,'text':'2. gr. Flöte','scope':'Second large flute entry on the same Flutes staff; not an extra physical staff.'},
 {'physicalPage':27,'text':'1. kl. Flöte / 2. gr. Flöte; perdendosi','scope':'Doubling/player directions and final diminuendo instructions are local printed source obligations.'}]
result={
 'status':'Independent source map frozen before reading or comparing the parent map or native staff inventory.',
 'method':'Directly viewed all 27 original source renders, identified printed role labels/brackets and voice continuity, counted physical bar compartments, then cross-checked printed starts. Revisited pages 2–15 for global instructions and opening exception. No extraction, detection, staff-coordinate transfer or production edit.',
 'bindings':{'source':protocol['source'],'profile':protocol['profile'],'protocolSHA256':sha(base/'protocol-before-comparison.json')},
 'sourceOnlyPages':[{'physicalPage':1,'classification':'Title and Goethe text; no music staff.'}],
 'summary':{'physicalPages':27,'musicPages':26,'systems':26,'roles':20,'partSystemRows':520,'printedStaffInstances':sum(s['staffCount'] for s in systems),'numberedBars':176,'physicalCompartmentsIncludingPickup':177,'combinedChoirPages':[2,3],'dividedChoirPages':list(range(4,28)),'missingRoles':0},
 'roles':[{'partID':p['id'],'profileName':p['name'],'sourceOrder':i+1} for i,p in enumerate(parts)],
 'systems':systems,'sharedDirections':shared,'localInstructionCautions':local,
 'meterChanges':[{'physicalPage':2,'bar':1,'meter':'common time (4/4)','exception':'Preceded by an unnumbered eighth-note pickup.'},{'physicalPage':21,'bar':116,'meter':'3/4','quarterPulseUnchanged':True},{'physicalPage':25,'bar':162,'meter':'common time (4/4)'}],
 'exceptions':['Page 2 has FIVE physical compartments: one eighth-note pickup plus four numbered bars. Earlier partial notes described only the four numbered bars under physicalBarCompartments; the partial receipt is retained and this complete map explicitly corrects that field.','Page 18 ends with courtesy key signatures after bar 99; the courtesy area is not an additional bar.','The internal key-change double line on page 16 at bar 84 and meter-change double lines at bars 116 and 162 do not add extra compartments.','Instrument rows combine multiple players by the printed score convention. This map does not split shared instrumental staves into separate player parts.'],
 'limitations':['This is a source role/timing/direction map, not a crop or final-output musical certification.','Physical staff ordinals are top-to-bottom source positions, not native analyzer IDs. The inventory must be independently matched before any assignment.','No individual-note transcription or complete local dynamic catalogue was attempted; local source marks and lyrics still require crop preservation review.','No output or project was generated by this task.']}
for name in ['protocol-before-comparison.json','partial-observations-before-pause.json','opening-pickup-detail.png','meter-tempo-detail.png']:
    shutil.copy2(base/name,report/name)
(report/'source-map-before-comparison.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'map':str(report/'source-map-before-comparison.json'),'sha256':sha(report/'source-map-before-comparison.json'),'summary':result['summary']},indent=2))
