from pathlib import Path
import json,hashlib,argparse
p=argparse.ArgumentParser();p.add_argument('variant');args=p.parse_args()
root=Path('Tests/quality_control/residual7-source-2026-10-03');out=root/args.variant;out.mkdir(exist_ok=True)
baseline=Path('.build/residual9-boundary-2026-10-03/candidate-v2/actual.json');candidate=Path('.build/residual7-geometry-2026-10-03')/args.variant/'actual.json'
a=json.load(open(baseline));b=json.load(open(candidate));assert a['sourceSHA256']==b['sourceSHA256'] and a['rectifications']==b['rectifications']
flat=lambda j:{x['id']:x for p in j['plan']['pages'] for x in p['assignments']}
aa,bb=flat(a),flat(b);assert aa.keys()==bb.keys() and len(bb)==604
for x,y in zip(a['pages'],b['pages']):
 for field in ['pageIndex','pageWidth','pageHeight','imageWidth','imageHeight','analysisSkewDegrees','staves']:assert x[field]==y[field]
def rect(band):
 page=b['pages'][band['pageIndex']]
 return [band['leftFraction']*page['pageWidth'],band['topFraction']*page['pageHeight'],(1-band['rightFraction'])*page['pageWidth'],band['bottomFraction']*page['pageHeight']]
def neighbors(v,j):
 return [s['id'] for s in j['pages'][v['pageIndex']]['staves'] if s['id'] not in v['candidateIDs'] and v['topFraction']<=min(s['staffLineFractions']) and v['bottomFraction']>=max(s['staffLineFractions'])]
def contains(outer,inner):return outer[0]<=inner[0] and outer[1]<=inner[1] and outer[2]>=inner[2] and outer[3]>=inner[3]
changes=[{'id':k,'before':rect(aa[k]),'after':rect(v),'fields':[f for f in v if v[f]!=aa[k][f]],'beforeNeighbors':neighbors(aa[k],a),'afterNeighbors':neighbors(v,b),'candidateContainsWholePreviousCrop':contains(rect(v),rect(aa[k]))} for k,v in bb.items() if v!=aa[k]]
guards=json.load(open(root/'source-guards.json'))['guards'];checks=[{'id':g['bandID'],'guard':g['rect'],'crop':rect(bb[g['bandID']]),'contains':contains(rect(bb[g['bandID']]),g['rect'])} for g in guards]
local=[]
for g in json.load(open(root/'source-oracle.json'))['protectedMusicalRegions']:
 pid={'Violin I':'violin1','Violin II':'violin2','Viola':'viola','Cello':'cello'}[g['owner']];sid=2 if g['page']==24 else 1;band=bb[f'p{g["page"]}-s{sid}-{pid}']
 local.append({'page':g['page'],'owner':g['owner'],'content':g['content'],'box':g['pdfBounds'],'crop':rect(band),'contains':contains(rect(band),g['pdfBounds'])})
canonical=lambda x:sorted(json.dumps(q,sort_keys=True) for q in x)
inkChanged=[x['pageIndex']+1 for x,y in zip(a['pages'],b['pages']) if canonical(x['inkComponents'])!=canonical(y['inkComponents'])]
result={'inputs':[{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [baseline,candidate,root/'source-guards.json',root/'source-oracle.json']],'sourceSHA256':a['sourceSHA256'],'savedRectificationsEqual':True,'staffGeometryEqual':True,'bands':604,'changes':changes,'semanticInkChangedPages':inkChanged,'wholeNeighborsBefore':sum(len(neighbors(v,a)) for v in aa.values()),'wholeNeighborsAfter':sum(len(neighbors(v,b)) for v in bb.values()),'unchangedFullTargetGuards':checks,'additionalLocalObligations':local}
(out/'source-comparison.json').write_text(json.dumps(result,indent=2)+'\n');print(args.variant,len(changes),'changed rows',result['wholeNeighborsBefore'],'→',result['wholeNeighborsAfter'],'whole neighbors; ink',inkChanged)
