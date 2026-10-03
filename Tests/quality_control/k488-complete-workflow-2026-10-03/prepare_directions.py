from pathlib import Path
import copy,json
import pymupdf as fitz
ROOT=Path(__file__).resolve().parent
mapping=json.load(open(ROOT/'source-reviewed-map.json'))
overrides=json.load(open(ROOT/'overrides.json'))
manifest=json.load(open(ROOT/'baseline-parts/manifest.json'))
placements={(p['id'],v['sourcePage'],v['system']):v for p in manifest['parts'] for v in p['placements']}
source=fitz.open(mapping['source'])
headings=[]; omitted=[]
for pi,page in enumerate(source):
    systems=[s for s in mapping['systems'] if s['page']==pi+1]
    for block in page.get_text('dict')['blocks']:
        for line in block.get('lines',[]):
            for span in line['spans']:
                if span['text'] not in ('Allegro','SOLO','TUTTI'):continue
                x0,y0,x1,y1=span['bbox']
                system=min(systems,key=lambda s:abs(s['top']+28-y1))
                assert abs(system['top']+28-y1)<38
                bounds=[x0-1.5,y0-1.5,x1+1.5,y1+1.0]
                h={'page':pi+1,'system':system['system'],'text':span['text'],'sourceRect':bounds,'recipients':[]}
                spec=overrides[pi]['systems'][system['system']-1]
                for band in spec['bands']:
                    placement=placements[band['partID'],pi+1,system['system']]
                    r=placement['sourceRect']
                    contained=all([r[0]<=bounds[0],r[1]<=bounds[1],r[2]>=bounds[2],r[3]>=bounds[3]])
                    if not contained:
                        band.setdefault('sourceMarkings',[]).append(bounds)
                    h['recipients'].append({'partID':band['partID'],'mode':'retained in crop' if contained else 'reviewed source copy'})
                for absence in spec['omittedParts']:
                    omitted.append({'partID':absence['partID'],'page':pi+1,'system':system['system'],'firstBar':system['firstBar'],'barCount':system['barCount'],'direction':span['text'],'sourceRect':bounds,'status':'Counted silence preserves duration; shared direction within compressed span needs explicit placement review.'})
                headings.append(h)
for page in overrides:
    for system in page['systems']:
        for band in system['bands']:
            rects=band.get('sourceMarkings',[])
            changed=True
            while changed:
                changed=False
                for i,a in enumerate(rects):
                    for j,b in enumerate(rects[i+1:],i+1):
                        if min(a[2],b[2])>max(a[0],b[0]):
                            rects[i]=[min(a[0],b[0]),min(a[1],b[1]),max(a[2],b[2]),max(a[3],b[3])]
                            rects.pop(j);changed=True;break
                    if changed:break
(ROOT/'overrides-with-directions.json').write_text(json.dumps(overrides,indent=2))
(ROOT/'source-shared-directions.json').write_text(json.dumps({'status':'Source text and system inventory; copied-image and final-output review pending','headings':headings,'generatedRestDirectionsPending':omitted},indent=2))
print(len(headings),'shared printed directions;',sum(len(b.get('sourceMarkings',[])) for p in overrides for s in p['systems'] for b in s['bands']),'source copy rectangles;',len(omitted),'direction occurrences in omitted parts require review')
