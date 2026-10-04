import json,hashlib
from pathlib import Path
w=Path('.build/envelope-compatibility-corpus-2026-10-03')
sid='lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922'
notes={
'p1-s3-voice':'Tiny lower contraction removes neighboring piano fragment; intended vocal notation and lyrics remain inside.',
'p2-s1-voice':'Top contraction removes printed source page number (63) 3; no intended song heading, notes, or lyrics observed above the new edge.',
'p5-s4-piano':'Lower contraction retains lowest grand-staff notes, staccato marks, slurs, and its ritard.; removes following voice staff and following ritard.',
'p6-s2-voice':'Tiny lower expansion; Adagio, a tempo, p and lyrics retained. Neighboring piano text remains.',
'p9-s4-voice':'Tiny lower contraction; intended voice notes, lyrics and mf retained.',
'p11-s2-voice':'Top expansion adds previous piano notation; no intended vocal recovery observed.',
'p11-s2-piano':'Lower expansion adds following voice fragment; piano low ledger notes and hairpins retained.',
'p11-s4-voice':'Top expansion adds previous piano fragment; intended vocal triplets and lyrics retained.',
'p13-s1-voice':'Tiny lower expansion retains voice notation and lyrics. Froehlich, innig. is retained; song number 7 remains above unchanged top edge, a pre-existing omission requiring separate shared-header handling.',
'p13-s2-voice':'Tiny lower contraction; intended vocal notation and lyrics remain inside.'}
idx=w/'root-source'/sid/'index.json'; rows=json.loads(idx.read_text());assert {r['band'] for r in rows}==set(notes)
for r in rows:r.update(reviewed=True,newIntendedOmissionObserved=False,observation=notes[r['band']])
review={'scope':'All 10 changed source crop contexts visually inspected by root, not full exported part PDFs. Source ownership visual assessment is separate from geometric comparison. Existing omissions and neighboring fragments are retained in findings.','indexSHA256':hashlib.sha256(idx.read_bytes()).hexdigest(),'rows':rows}
(w/'root-schumann-source-review.json').write_text(json.dumps(review,indent=2)+'\n')
bid='lightly-skewed-10-brahms-string-quartet-no3-op67-imslp-242312';idx=w/'root-source'/bid/'index.json'; rows=json.loads(idx.read_text());wanted={'p1-s1-cello','p2-s2-cello','p16-s5-viola'}
selected=[r for r in rows if r['band'] in wanted];assert len(selected)==3
for r in selected:r.update(reviewed=True,verdict='regression',observation='Top expansion includes the complete neighboring staff above. No intended target notation recovery observed that warrants this expansion.')
review={'scope':'Only these three of 269 changed crops visually reviewed by root. Review stopped after decisive cleanliness regressions. This is not a full score or output PDF review.','indexSHA256':hashlib.sha256(idx.read_bytes()).hexdigest(),'totalChangedCrops':len(rows),'reviewedCrops':len(selected),'rows':selected}
(w/'root-brahms242312-source-regressions.json').write_text(json.dumps(review,indent=2)+'\n')
print('Recorded 10 Schumann reviews and 3 Brahms regressions.')
