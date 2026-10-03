from pathlib import Path
import json, hashlib
import pymupdf as fitz

ROOT = Path(__file__).resolve().parent
evidence = json.load(open(ROOT/'source-system-proposal.json'))
raw_path = Path('.build/combined-corpus-2026-10-03/candidate/rest-detection-mozart-piano-concerto-no23-kv488-mvt1-mutopia2229.json')
raw = json.load(open(raw_path))
parts = [('flute','Flute',1),('clarinet','Clarinet in A',1),('bassoon','Bassoon',1),('horn','French Horn in A',1),('piano','Piano',2),('violin-1','Violin I',1),('violin-2','Violin II',1),('viola','Viola',1),('cello-bass','Cello and Bass',1)]
profile = {'parts':[{'id':i,'name':n,'staffCount':c} for i,n,c in parts], 'cropMode':'compact', 'requiresSystemAssignment':True,'leftTrimPoints':0,'rightTrimPoints':0}
# Explicitly transcribed after inspecting every original source page. These are
# source-specific reviewed assignments, not a staff-count or clef-only classifier.
page_layouts = [
 'A O','O O','O O','O O','O O','O O','O O','A PS PS','A A','PS PS A','WP P A','A A',
 'A A','A A','A A','A O','PS P A','A A','A A','WP A','A A','A A','WP A','A A',
 'A A','PS A','WP P A','A A','PS A PS','A WP','WP A','A A','A A','O O','A O','O O'
]
layouts = {'A':parts,'O':[p for p in parts if p[0]!='piano'],'PS':parts[4:],'WP':parts[:5],'P':[parts[4]]}
overrides=[]
for pi, codes in enumerate(page_layouts):
    source_systems=[s for s in evidence['systems'] if s['page']==pi+1]
    assert len(codes.split())==len(source_systems)
    systems=[]
    for source, code in zip(source_systems,codes.split()):
        present=layouts[code]; ids=source['candidateIDs'];cursor=0;bands=[]
        for identifier,name,count in present:
            bands.append({'partID':identifier,'candidateIDs':ids[cursor:cursor+count]})
            cursor+=count
        assert cursor==len(ids)
        count=source['sourceBarlineCount']
        assert count==source['barCountFromNextStart'] or source is evidence['systems'][-1]
        source['reviewedLayout']=code
        source['instrumentAssignments']=bands
        source['barCount']=count
        source['identityEvidence']='Original source labels on opening system; per-system group braces, clefs, key signatures and continuing parts inspected across every page. Piano clef changes do not change its identity.'
        omissions=[{'partID':i,'reason':f'Original system at bar {source["firstBar"]} omits this silent part; {count} measures verified against printed barlines and neighboring system numbers.'} for i,n,c in parts if i not in [p[0] for p in present]]
        systems.append({'systemIndex':source['system']-1,'startBarNumber':source['firstBar'],'barCount':count,'bands':bands,'omittedParts':omissions})
    overrides.append({'pageIndex':pi,'reason':'Source-reviewed changing instrumentation and measure spans; automatic crop edges retained.', 'systems':systems})
inventory={'schemaVersion':2,'source':evidence['source'],'sourceSHA256':evidence['sourceSHA256'],'coordinateSystem':'Native unrectified top-down page fractions','analysisConfiguration':'source-bound production native inventory at d2a43e1; no analyzer changes since then','pages':raw['pages'],'rectifications':[]}
evidence['status']='Root source review complete for instrument/system identities and counts; independent review pending. Does not establish crop completeness.'
evidence['nativeInventorySHA256']=hashlib.sha256(raw_path.read_bytes()).hexdigest()
evidence['finalBar']=evidence['systems'][-1]['firstBar']+evidence['systems'][-1]['barCount']-1
for name,data in [('inventory.json',inventory),('profile.json',profile),('overrides.json',overrides),('source-reviewed-map.json',evidence)]:
    (ROOT/name).write_text(json.dumps(data,indent=2))
print('Mapped',len(evidence['systems']),'systems;',evidence['finalBar'],'bars;',sum(len(s['omittedParts']) for p in overrides for s in p['systems']),'generated rest items')
