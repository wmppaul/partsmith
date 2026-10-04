from pathlib import Path
import json,hashlib,zipfile,shutil
root=Path.cwd(); work=root/'.build/brahms93521-full-output-review-2026-10-03'; out=root/'Tests/quality_control/brahms93521-full-output-root-review-2026-10-03'; base=root/'.build/brahms93521-full-workflow-draft-2026-10-03/private-crop-draft-parts'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
index=json.loads((work/'render-index.json').read_text());manifest=json.loads((base/'manifest.json').read_text())
assert sum(r['pages'] for r in index)==64 and sum(p['bandCount'] for p in manifest['parts'])==604
issues={
 'violin1':{'pages':17,'observations':['Neighboring staff fragments throughout; complete extra staff at output12 source28 system1.','Output2 ends on first ending and output3 opens on second ending, requiring a page turn across the repeat choice.','Movement starts fall within output7 and output9; automatic pagination does not choose movement boundaries.','No blank or near-empty output pages observed. Last page has nine systems.']},
 'violin2':{'pages':16,'observations':['Neighboring notes, slurs and dynamics above and below nearly every system; many boundaries appear crowded.','Output13 retains complete Violin I staff above source31 system1; output12 source28 system1 also retains substantial unrelated staff context.','Output12 full-page inspection confirms readable complete Da Capo sentence, Coda heading and Poco Allegretto con Variazioni heading; crops still include neighbor fragments.','First and second endings fall on opposite output2/output3 pages. No blank or near-empty pages observed.']},
 'viola':{'pages':16,'observations':['Heavy neighboring music remains throughout; output16 source38 system1 includes Cello staff.','Corrected source34 system4 low f is visible in full output14. Raw-score omission recorded separately is not present here.','Doppio Movimento source copy is readable in full output14; original neighboring dynamics remain.','First and second endings fall on opposite output2/output3 pages. No blank or near-empty pages observed.']},
 'cello':{'pages':15,'observations':['Upper-neighbor fragments remain, with complete neighboring staff at output9 source24 system2 and output15 source38 system1.','Repeated printed publisher plate number7892 appears between several systems; it is source footer clutter.','Return instruction is visible on output11, linked destination on output10 and Coda heading on output11.','No blank or near-empty output pages observed. Last page has ten systems.']}}
review={
 'scope':'Visual final-page layout and conspicuous-neighbor review of the complete private95 corrected Brahms93521 draft; not a complete note-by-note source preservation pass.',
 'source':manifest['source'],'sourceSHA256':manifest['sourceSHA256'],'sourcePages':39,'musicSourcePages':38,
 'nativeCropCandidateSHA256':'95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0',
 'sharedDirectionsEnabled':True,'parts':4,'bands':604,'finalOutputPages':64,
 'allFinalPagesViewedAsContactSheets':True,'contactSheetCount':sum(len(r['sheets']) for r in index),
 'individualFullPagesViewed':[{'part':'viola','page':14},{'part':'violin2','page':12}],
 'additionalSourceViewed':['.build/brahms-source-span-full-replay-2026-10-03/rasters/page-34.png'],
 'partObservations':issues,
 'reviewResult':'draft: material neighboring music and page-turn issues remain',
 'limitations':['Contact sheets establish broad layout/readability observations, not exact preservation of every note or dynamic.','Whole-source target and shared-direction completeness remain separate obligations.','This does not approve private crop candidate promotion or certify all corpus outputs.','Separate source comparisons retain known crop-only instruction losses and unresolved raw-score target omissions.'],
 'pdfBindings':[{'file':str((base/p['file']).relative_to(root)),'sha256':sha(base/p['file']),'pages':p['outputPages'],'bands':p['bandCount']} for p in manifest['parts']],
 'manifestBinding':{'path':str((base/'manifest.json').relative_to(root)),'sha256':sha(base/'manifest.json')},
 'renderIndexSHA256':sha(work/'render-index.json')}
(out/'review.json').write_text(json.dumps(review,indent=2)+'\n')
shutil.copy2(work/'render.py',out/'render.py');shutil.copy2(work/'record.py',out/'record.py');shutil.copy2(work/'render-index.json',out/'render-index.json')
paths=[root/s for r in index for s in r['sheets']]+[work/'viola/page-14.png',work/'violin2/page-12.png']
images={str(p.relative_to(work)):sha(p) for p in paths}
with zipfile.ZipFile(out/'viewed-output-pages.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in paths:z.write(p,str(p.relative_to(work)))
 z.writestr('image-hashes.json',json.dumps(images,indent=2)+'\n')
with zipfile.ZipFile(out/'viewed-output-pages.zip') as z:
 assert z.testzip() is None
 for name,h in images.items():assert hashlib.sha256(z.read(name)).hexdigest()==h
(out/'README.md').write_text('''# Complete Brahms output review\n\nRoot visually inspected all **64 final pages** of the four-part private crop draft (17 Violin I,16 Violin II,16 Viola,15 Cello), using 17 Poppler-rendered contact sheets. Each part contains151 source systems; the complete set has604 bands. Violin II12 and Viola14 were additionally viewed at full-page size, and the corrected source34 page was compared against its Viola passage.\n\nThe final pages are populated and consistently scaled, but this is **still a draft**. Many strips contain distracting neighboring music; five known whole-neighbor relations remain. Publisher numbers repeatedly enter Cello. Several first/second endings fall across a page turn, and movement starts do not consistently begin a new page. Preview crop controls are useful here; the private crop candidate is not promoted.\n\nThe low Viola f at source34 system4 is complete in corrected output14. The separately recorded raw-source f omission is not a defect in this corrected output. Complete Da Capo/Coda and variation-heading copies are readable on the inspected Violin II12 page. These observations do not certify every note, direction or turn throughout the score.\n\n`review.json` records part-specific findings, exact PDF hashes, render scope and limits. `viewed-output-pages.zip` contains every viewed contact sheet and two full-page images with independently checked member hashes. The original draft PDFs and complete native replay are bound by the companion full-workflow evidence.\n''')
(out/'manifest.json').write_text(json.dumps({p.name:sha(p) for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json'},indent=2)+'\n')
print(json.dumps({'review':str(out),'pages':64,'sheets':len(paths)-2,'archiveBytes':(out/'viewed-output-pages.zip').stat().st_size,'manifestSHA256':sha(out/'manifest.json')},indent=2))
