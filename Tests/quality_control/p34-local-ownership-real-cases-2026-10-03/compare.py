from pathlib import Path
import json, collections, hashlib, math
from PIL import Image, ImageDraw, ImageFont

W=Path('.build/p34-local-ownership-real-cases-2026-10-03')
load=lambda p:json.loads(Path(p).read_text())
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def dump(n,v): (W/n).write_text(json.dumps(v,indent=2)+'\n')
protocol=load(W/'protocol-before-results.json')
baseline=load(W/'baseline/result.json');candidate=load(W/'candidate/result.json')
ref=load(protocol['baselineInventory']['path'])
reference={p['pageIndex']:p for p in ref['pages']}
counter=lambda xs:collections.Counter(json.dumps(x,sort_keys=True) for x in xs)
before={};after={};geometry_changes=[];all_fields=[];page_records=[]
for b,c,bp,cp in zip(baseline['pages'],candidate['pages'],baseline['plan']['pages'],candidate['plan']['pages']):
    r=reference[b['pageIndex']]
    assert counter(b['inkComponents'])==counter(r['inkComponents'])
    for k in set(b)|set(c)|set(r):
        if k in ['inkComponents','sharedHeadings','sharedNavigation','sharedEndings']:continue
        assert b.get(k)==c.get(k)==r.get(k),(b['pageIndex'],k)
    assert bp['pageIndex']==cp['pageIndex']==b['pageIndex']
    assert bp['unresolvedReasons']==cp['unresolvedReasons']
    bm={x['id']:x for x in bp['assignments']};cm={x['id']:x for x in cp['assignments']}
    assert list(bm)==list(cm)
    def rect(x):return [x['leftFraction']*b['pageWidth'],x['topFraction']*b['pageHeight'],(1-x['rightFraction'])*b['pageWidth'],x['bottomFraction']*b['pageHeight']]
    def foreign(x):return sorted(s['id'] for s in b['staves'] if s['id'] not in x['candidateIDs'] and x['topFraction']<=s['staffLineFractions'][0] and x['bottomFraction']>=s['staffLineFractions'][4])
    for bid,x in bm.items():
        y=cm[bid]
        for k in set(x)|set(y):
            if k not in ['leftFraction','rightFraction','topFraction','bottomFraction','warnings']:assert x.get(k)==y.get(k),(bid,k)
        rb,rc=rect(x),rect(y);before[bid]=rb;after[bid]=rc
        record={'bandID':bid,'page':b['pageIndex']+1,'beforePDFBounds':rb,'afterPDFBounds':rc,'candidateIDs':x['candidateIDs'],
            'beforeWholeNeighbors':foreign(x),'afterWholeNeighbors':foreign(y),'beforeWarnings':x.get('warnings',[]),'afterWarnings':y.get('warnings',[])}
        if x!=y:all_fields.append(record)
        if rb!=rc:
            record['hasInwardEdge']=rc[0]>rb[0]+1e-9 or rc[1]>rb[1]+1e-9 or rc[2]<rb[2]-1e-9 or rc[3]<rb[3]-1e-9
            geometry_changes.append(record)
    component_bounds=lambda p:collections.Counter((tuple(x['bounds']),bool(x.get('isOwnershipAlternative'))) for x in p['inkComponents'])
    page_records.append({'page':b['pageIndex']+1,'baselineComponents':len(b['inkComponents']),'candidateComponents':len(c['inkComponents']),
        'componentBoundsMultisetExact':component_bounds(b)==component_bounds(c),'removedComponentRecords':[json.loads(x) for x in (counter(b['inkComponents'])-counter(c['inkComponents'])).elements()],
        'addedComponentRecords':[json.loads(x) for x in (counter(c['inkComponents'])-counter(b['inkComponents'])).elements()]})
assert len(before)==len(after)==192

guards_path=Path('Tests/quality_control/residual7-source-2026-10-03/source-guards.json')
assert sha(guards_path)=='e097a2b80032e18b85606f4f02c13e24870162857a02bf95f6b58786f2cdbe0c'
contains=lambda crop,rect:crop[0]<=rect[0]+1e-9 and crop[1]<=rect[1]+1e-9 and crop[2]>=rect[2]-1e-9 and crop[3]>=rect[3]-1e-9
guards=[]
for g in load(guards_path)['guards']:
    bid=g['bandID'];assert bid in before
    guards.append({**g,'baselineCrop':before[bid],'candidateCrop':after[bid],'baselineContains':contains(before[bid],g['rect']),'candidateContains':contains(after[bid],g['rect'])})
local_path=Path('Tests/quality_control/residual7-source-2026-10-03/source-oracle.json')
local=[]
for g in load(local_path)['protectedMusicalRegions']:
    sys=2 if g['page']==24 else 1
    part={'Violin I':'violin1','Violin II':'violin2','Viola':'viola','Cello':'cello'}[g['owner']]
    bid=f'p{g["page"]}-s{sys}-{part}';assert bid in before
    local.append({'bandID':bid,'content':g['content'],'coordinateSpace':g['coordinateSpace'],'sourceGuard':g['observedInkBounds'],
        'baselineContains':contains(before[bid],g['observedInkBounds']),'candidateContains':contains(after[bid],g['observedInkBounds'])})

timings=[]
for b,c in zip(baseline['timings'],candidate['timings']):
    assert b['physicalPage']==c['physicalPage']
    timings.append({'page':b['physicalPage'],'baselineSeconds':b['analysisSeconds'],'candidateSeconds':c['analysisSeconds'],'deltaSeconds':c['analysisSeconds']-b['analysisSeconds']})
summary={'pages':12,'bands':192,'baselineSemanticAnalysisMatchesFrozenReference':True,'staffGeometryAssignmentIDsAndOrderExact':True,
    'changedCropCount':len(geometry_changes),'inwardChangedCrops':sum(x['hasInwardEdge'] for x in geometry_changes),
    'newWholeNeighborRelations':[{'bandID':x['bandID'],'staffIDs':sorted(set(x['afterWholeNeighbors'])-set(x['beforeWholeNeighbors']))} for x in all_fields if set(x['afterWholeNeighbors'])-set(x['beforeWholeNeighbors'])],
    'newFullGuardFailures':[g['bandID'] for g in guards if g['baselineContains'] and not g['candidateContains']],
    'existingFullGuardFailures':[g['bandID'] for g in guards if not g['baselineContains']],
    'newLocalGuardFailures':[g for g in local if g['baselineContains'] and not g['candidateContains']],
    'existingLocalGuardFailures':[g for g in local if not g['baselineContains']],
    'baselineAnalysisSeconds':sum(x['baselineSeconds'] for x in timings),'candidateAnalysisSeconds':sum(x['candidateSeconds'] for x in timings),
    'baselinePlanningSeconds':baseline['planningSeconds'],'candidatePlanningSeconds':candidate['planningSeconds'],
    'timingScope':'One sequential batch per version, same saved images; no universal performance guarantee.',
    'visualSourceReviewComplete':False,'promotionApproved':False}
dump('comparison.json',{'summary':summary,'changedCrops':geometry_changes,'allChangedAssignments':all_fields,'pages':page_records,'fullGuards':guards,'localGuards':local,'timings':timings})

folder=W/'contexts';folder.mkdir(exist_ok=True)
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',20)
index=[]
raster_map={r['physicalPage']:r for r in protocol['sourceRasters']}
for row in geometry_changes:
    src=raster_map[row['page']];assert sha(src['raster'])==src['sha256']
    im=Image.open(src['raster']).convert('RGB');a=reference[row['page']-1];scale=im.height/a['pageHeight']
    y0=max(0,math.floor(min(row['beforePDFBounds'][1],row['afterPDFBounds'][1])*scale-18*scale))
    y1=min(im.height,math.ceil(max(row['beforePDFBounds'][3],row['afterPDFBounds'][3])*scale+18*scale))
    img=Image.new('RGB',(im.width,y1-y0+45),'white');img.paste(im.crop((0,y0,im.width,y1)),(0,45));d=ImageDraw.Draw(img)
    d.text((10,9),row['bandID']+' — production red / private V2 blue',(0,0,0),font=font)
    for field,color,offset in [('beforePDFBounds',(220,0,30),-1),('afterPDFBounds',(0,80,240),1)]:
        for pt in [row[field][1],row[field][3]]:
            y=pt*scale-y0+45+offset
            for x in range(0,im.width,32):d.line((x,y,min(im.width-1,x+21),y),fill=color,width=2)
    p=folder/(row['bandID']+'.png');img.save(p)
    index.append({**row,'path':str(p),'sha256':sha(p),'sourceRaster':src['raster'],'sourceRasterSHA256':src['sha256'],'sourceImageSize':list(im.size),'sourcePixelYRange':[y0,y1]})
dump('context-index.json',index)
print(json.dumps(summary,indent=2))
