from pathlib import Path
from collections import Counter
import json,hashlib
ROOT=Path.cwd(); HERE=Path(__file__).resolve().parent; AGG=json.loads((ROOT/'.build/auto-qc/connector8-harmonic/corpus/aggregate.json').read_text())
def load(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def bands(d):return {b['id']:b for p in d['pages'] for b in p['assignments']}
def geometry(b):return {k:b[k] for k in ['pageIndex','systemIndex','partID','candidateIDs','kind','topFraction','bottomFraction','leftFraction','rightFraction','sourceMarkings'] if k in b}
def components(p):return Counter((tuple(c['bounds']),tuple(c['staffIDs']))for c in p.get('inkComponents',[]))
report={'candidate':'Analysis staff-line minimum thickness zero; one row rather than three below 5.56px spacing','source':'36-score 1477-page corpus; original source/profile hashes checked before each run','rows':[]}
for row in AGG['scores']:
 nf=HERE/'corpus-single-row'/(row['id']+'.json');of=HERE/'corpus-baseline'/(row['id']+'.json')
 if not nf.exists() or not of.exists():continue
 new=load(nf); old=load(of)
 assert len(old['pages'])==len(new['pages'])==row['pageCount']; a,b=bands(old['plan']),bands(new['plan']);fields=['staves','pageWidth','pageHeight','imageWidth','imageHeight','analysisSkewDegrees']; changes=[]
 for k in a.keys()&b.keys():
  if geometry(a[k])!=geometry(b[k]):changes.append({'id':k,'before':geometry(a[k]),'after':geometry(b[k])})
 changes.sort(key=lambda x:(x['after']['pageIndex'],x['after']['systemIndex'],x['after']['partID']))
 r={'id':row['id'],'pageCount':row['pageCount'],'sourceSHA256':row['sourceSHA256'],'profileSHA256':row['profileSHA256'],'baselineSHA256':sha(of),'candidateSHA256':sha(nf),'staffOrRasterChanges':[], 'inkChanges':[],'beforeBands':len(a),'afterBands':len(b),'addedBands':sorted(b.keys()-a.keys()),'removedBands':sorted(a.keys()-b.keys()),'changedBands':changes,'lowSpacingPages':[]}
 for pa,pb in zip(old['pages'],new['pages']):
  assert pa['pageIndex']==pb['pageIndex']; changed=[f for f in fields if pa.get(f)!=pb.get(f)]
  if changed:r['staffOrRasterChanges'].append({'page':pa['pageIndex']+1,'fields':changed})
  spaces=[(s['staffLineFractions'][-1]-s['staffLineFractions'][0])*pa['imageHeight']/4 for s in pa['staves']]
  if spaces and min(spaces)*.09<.5:r['lowSpacingPages'].append({'page':pa['pageIndex']+1,'minStaffSpacingPixels':min(spaces)})
  ca,cb=components(pa),components(pb)
  if ca!=cb:r['inkChanges'].append({'page':pa['pageIndex']+1,'before':sum(ca.values()),'after':sum(cb.values()),'removedOrReshaped':sum((ca-cb).values()),'addedOrReshaped':sum((cb-ca).values())})
 report['rows'].append(r)
report['summary']={'inputPDFs':len(report['rows']),'inputPages':sum(r['pageCount']for r in report['rows']),'staffOrRasterChangedPages':sum(len(r['staffOrRasterChanges'])for r in report['rows']),'inkChangedPages':sum(len(r['inkChanges'])for r in report['rows']),'changedCrops':sum(len(r['changedBands'])for r in report['rows']),'addedBands':sum(len(r['addedBands'])for r in report['rows']),'removedBands':sum(len(r['removedBands'])for r in report['rows']),'lowSpacingPages':sum(len(r['lowSpacingPages'])for r in report['rows'])}
(HERE/'corpus-comparison.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report['summary'],indent=2))
for r in report['rows']:
 if r['inkChanges']or r['staffOrRasterChanges']or r['changedBands']:print(r['id'], 'ink',[x['page']for x in r['inkChanges']], 'crops',[x['id']for x in r['changedBands']], 'staff',r['staffOrRasterChanges'])
