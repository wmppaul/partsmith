from pathlib import Path
import json,collections,hashlib
base=Path('.build/mozart-k488-complete-2026-10-03');out=Path('.build/k488-independent-review-2026-10-03');m=json.load(open(base/'source-reviewed-map.json'));over=json.load(open(base/'overrides.json'));plan=json.load(open(base/'directed-parts/plan.json'));manifest=json.load(open(base/'directed-parts/manifest.json'))
# Independently transcribed from all original page overviews, with opening labels
# and brace/clef/key grouping, including both distinct six-staff layouts.
observed=['A O','O O','O O','O O','O O','O O','O O','A PS PS','A A','PS PS A','WP P A','A A','A A','A A','A A','A A','PS P A','A A','A A','WP A','A A','A A','WP A','A A','A A','PS A','WP P A','A A','PS A PS','A WP','WP A','A A','A A','O O','A O','O O']
# Page16 lower has eight staves, so its group is orchestral without Piano.
observed[15]='A O'
parts=['flute','clarinet','bassoon','horn','piano','violin-1','violin-2','viola','cello-bass'];layouts={'A':parts,'O':[x for x in parts if x!='piano'],'PS':parts[4:],'WP':parts[:5],'P':['piano']}
systems=m['systems'];expected=[];failures=[];omitted=collections.Counter();omittedBars=collections.Counter()
for page,codes in enumerate(observed,1):
 rows=[s for s in systems if s['page']==page];assert len(rows)==len(codes.split())
 for row,code in zip(rows,codes.split()):
  expectedIDs=layouts[code];actualIDs=[a['partID'] for a in row['instrumentAssignments']];assert expectedIDs==actualIDs,(page,row['system'],code,actualIDs)
  override=over[page-1]['systems'][row['system']-1];om=[x for x in parts if x not in expectedIDs];assert [x['partID'] for x in override['omittedParts']]==om
  assert override['startBarNumber']==row['firstBar'] and override['barCount']==row['barCount']
  for x in om:omitted[x]+=1;omittedBars[x]+=row['barCount']
  expected.append({'page':page,'system':row['system'],'independentLayout':code,'partIDs':expectedIDs,'omittedPartIDs':om,'start':row['firstBar'],'count':row['barCount']})
assert systems[0]['firstBar']==1
for a,b in zip(systems,systems[1:]):assert a['firstBar']+a['barCount']==b['firstBar']
assert systems[-1]['firstBar']+systems[-1]['barCount']-1==314
bands=[b for p in plan['pages'] for b in p['assignments']];assert len(bands)==702
for part in parts:
 items=[b for b in bands if b['partID']==part];assert len(items)==78
 for item,sys in zip(items,systems):
  assert item['pageIndex']==sys['page']-1 and item['systemIndex']==sys['system']-1
  assert item['startBarNumber']==sys['firstBar'] and item['barCount']==sys['barCount']
  isMissing=part not in [a['partID'] for a in sys['instrumentAssignments']]
  assert (item.get('generatedRest') is not None)==isMissing
  if isMissing:assert item['generatedRest']['barCount']==sys['barCount'] and item['generatedRest']['startBarNumber']==sys['firstBar']
summary={'verdict':'No identity or timing mismatch found in this source-specific manual mapping. Not crop certification or automatic-identification validation.','source':m['source'],'sourceSHA256':m['sourceSHA256'],'sourceReviewedMapSHA256':hashlib.sha256((base/'source-reviewed-map.json').read_bytes()).hexdigest(),'overridesSHA256':hashlib.sha256((base/'overrides.json').read_bytes()).hexdigest(),'directedPlanSHA256':hashlib.sha256((base/'directed-parts/plan.json').read_bytes()).hexdigest(),'systemCount':78,'layoutCounts':dict(collections.Counter(x['independentLayout'] for x in expected)),'logicalPrintedBands':603,'generatedRestItems':99,'barsPerPart':314,'omittedSystemItemsPerPart':dict(omitted),'omittedMeasuresPerPart':dict(omittedBars),'partPages':{p['name']:p['outputPages'] for p in manifest['parts']},'sourceDirectionCopies':sum(len(x['sourceMarkings']) for p in manifest['parts'] for x in p['placements']),'systems':expected}
(out/'mapping-verification.json').write_text(json.dumps(summary,indent=2)+'\n');print({k:v for k,v in summary.items() if k!='systems'})
