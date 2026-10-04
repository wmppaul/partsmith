import json,hashlib
from pathlib import Path
w=Path('.build/brahms-parzen-source-crops-independent-2026-10-03');i=Path('.build/brahms-parzen109041-complete-native-2026-10-03/source-context-index.json')
d=json.loads(i.read_text());rows=d['rows'];alloc=json.loads((w/'expanded-78-allocation-before-review.json').read_text());ids=set(alloc['rowIDs'])
notes={
2:'Opening instrument names, meter, active notes, lower dynamics, ledger notes and ties retained.',
3:'Lower dynamics, hairpins, triplets, detached articulation and ties retained.',
4:'Quiet brass rows remain with rests; Timpani roll attacks and p retained.',
5:'Quiet brass rests and active Timpani roll figures with low hairpin retained.',
6:'Quiet brass and active Timpani f/p/hairpins retained; adjacent Soprano expression fragments remain.',
7:'Low brass ledger notes, ff and articulations, Timpani roll and sf retained.',
8:'Held brass chords/dynamics and quiet Timpani rests retained; Soprano expression fragments remain in Timpani.',
9:'All quiet source staves retained with complete rests/clefs/keys.',
10:'Brass sf accents, ties and low notes retained; Timpani rests retained amid foreign expressions.',
11:'Brass accidentals, articulation and ties retained; quiet Timpani rests retained amid foreign expressions.',
12:'Quiet brass/Timpani rests retained; neighboring Soprano dynamics remain.',
13:'Quiet brass/Timpani rests retained; neighboring Soprano hairpins remain.',
14:'Brass f and ties retained; quiet Timpani rests retained.',
15:'Brass accented entrance retained; Timpani rests retained with foreign Soprano sempre piu f below.',
16:'Brass key change and Tuba low ledger notes, f and molto marc. retained; quiet Timpani rests retained with foreign text above.',
17:'Brass accents and detached-note marks retained; quiet Timpani rests retained.',
18:'Quiet brass/Timpani rests and printed key changes retained.',
19:'Brass pp/ties and Timpani rolls, dim., p/pp and hairpin retained; foreign Soprano p sotto voce below Timpani.',
20:'Quiet brass and active Timpani rolls/poco cresc./hairpins retained; foreign Soprano cresc. and dynamics remain.',
21:'Quiet rests and mid-system meter/key transitions retained; Soprano Sehr weich und gebunden is a foreign complete instruction in the Timpani lower margin.',
22:'Brass pp/low ties retained; quiet Timpani rests retained; foreign Soprano hairpins remain.',
23:'Brass entry pp, dim. and slurs retained; quiet Timpani rests retained.',
24:'Brass tied chords and lower hairpins retained except the separately documented Trombone I/II dim. clipping; quiet Timpani rests retained with foreign Soprano p espress. and dim. below.',
25:'Brass accidentals/ties and final common-time/key changes retained; quiet Timpani rests retained with foreign Soprano pp sempre below.',
26:'Quiet brass/Timpani rests retained.',
27:'Final brass paired held notes, dynamics, hairpins and fermatas retained; Timpani final roll, low ppp/p/pp and fermata retained.'}
out=[]
for r in rows:
 if r['id'] not in ids:continue
 fail=r['id']=='p24-s1-trombones12'
 out.append({'id':r['id'],'physicalPage':r['physicalPage'],'partID':r['partID'],'sourceContextSHA256':r['sha256'],'cropRect':r['cropRect'],'viewed':True,'verdict':'own-expression-clipped' if fail else 'no-own-ink-omission-observed','sourceInterpretation':notes[r['physicalPage']],'finding': 'p24-trombones12-dim-source-obligation.json' if fail else None})
assert len(out)==78 and len({r['id'] for r in out})==78
result={'scope':'78 additional source crop contexts directly viewed in 21 sheets after allocation freeze; original234 receipt remains unchanged. Source preservation review, not a clean extraction or final PDF approval.','allocationSHA256':hashlib.sha256((w/'expanded-78-allocation-before-review.json').read_bytes()).hexdigest(),'sourceContextIndexSHA256':hashlib.sha256(i.read_bytes()).hexdigest(),'reviewedCount':78,'ownOmissionCount':1,'rows':out,'sheetEvidence':json.loads((w/'extra-review-sheet-index.json').read_text()),'extraIndividualViews':['p24-s1-trombones12','source-details/p24-trombones12-dim-original.png'],'foreignDirectionExamples':[{'id':'p21-s1-timpani','text':'Sehr weich und gebunden','sourceOwner':'Soprano/choir','status':'complete foreign instruction in quiet Timpani crop'},{'id':'p16-s1-timpani','text':'molto marc.','sourceOwner':'Trombone III/Tuba','status':'foreign instruction above quiet Timpani crop'}]}
p=w/'extra-78-crop-review.json';p.write_text(json.dumps(result,indent=2)+'\n');print(p,hashlib.sha256(p.read_bytes()).hexdigest())
