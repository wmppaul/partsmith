from pathlib import Path
import hashlib,json,shutil,datetime,subprocess
import pymupdf as fitz
root=Path.cwd();work=root/'.build/ownership-mozart-output-2026-10-03';report=root/'Tests/quality_control/ownership-mozart-output-2026-10-03'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
comparison=load(report/'output-comparison.json');native=load(report/'worker-comparison.json')
assert comparison['totalPagesAfter']==comparison['totalPagesBefore']==43
assert comparison['totalChangedPages']==2 and not comparison['movedBands']
assert native['directionCopies']==6 and not native['staffAndDirectionMetadataChanges'] and not native['otherBandChanges']
for v in ['baseline','candidate']:
 d=work/v
 for rec in load(d/'source-hashes.json'):
  assert sha(root/rec['path'])==rec['sha256'],rec['path']
 for p in (d/'Core').rglob('*.swift'):
  if v=='baseline':assert p.read_bytes()==subprocess.check_output(['git','show','82b606e:Partsmith/Core/'+str(p.relative_to(d/'Core'))])
 manifest=load(d/'parts/manifest.json')
 assert manifest['reviewedOverrides']==manifest['rectifications']==[]
 for part in manifest['parts']:
  assert sha(d/'parts'/part['file'])==part['sha256']
  text=fitz.open(d/'parts'/part['file'])[0].get_text()
  assert 'Piano Quartet, K. 478' in text and 'A...' not in text,text
 evidence=report/'evidence'/v;evidence.mkdir(parents=True,exist_ok=True)
 shutil.copytree(d/'Core',evidence/'Core',dirs_exist_ok=True)
 for name in ['config.json','source-hashes.json','native_worker.swift','export_breaks.swift','build.sh','compile-worker.log','compile-export.log','worker.log','export.log','export-titlefit.log','mozart-summary.json','mozart-inventory.json','mozart-plan.json']:
  shutil.copy2(d/name,evidence/name)
 for name in ['manifest.json','plan.json','layout-page-breaks.json']:
  shutil.copy2(d/'parts'/name,evidence/('export-'+name))
 shutil.copy2(d/'parts'/manifest['project']/'project.json',evidence/'project.json')
 for name in ['native_worker','export_breaks']:
  (evidence/(name+'-binary-sha256.txt')).write_text(sha(d/name)+'\n')
for part in ['violin','viola']:
 shutil.copy2(work/'rendered'/part/'page-07.png',report/f'final-{part}-page07.png')
shutil.copy2(work/'rendered/piano/page-01.png',report/'final-piano-page01.png')
review={'reviewer':'ending_delivery','completedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sourceFirst':True,'sourcePage':25,'changedOutputPages':[{'part':'Violin','page':7},{'part':'Viola','page':7}],'noNewTargetLossObservedInChangedRows':True,'noNewLayoutCollisionObserved':True,'finalShorterTitleFitsAllFourPDFs':True,'sourceObligations':['Violin opening low sharped note and stem, rests, p, entrance accidental, beam groups, high slurs and final right-edge figure retained.','Viola opening low sharped note and stem, p, accidentals, sustained chords and both long ties/slurs retained.'],'copyRowsViewed':['p1-s1-viola','p12-s1-viola','p1-s1-cello','p12-s1-cello','p1-s1-piano','p12-s1-piano'],'limitations':['Neighbor fragments remain throughout the draft.','Original scan ends inside ongoing notation at its right edge, including source p25.','Piano source p1 Allegro and p12 Andante already exist locally and are duplicated by the automatic copy; Cello crops include those neighboring Piano headings too. Both conditions are identical in the baseline.','No full-score musical recall or performance page-turn certification. No claim that initialized instrument names were automatically recognized.'],'independentReview':{'reviewer':'root','sourceFirst':True,'images':'Both complete changed pages and both exported p25 rows, with prior original-source inspection.','verdict':'No new target note/slur/dynamic clipping or layout collision observed. Neighbor fragments and original clipped right edge remain.','headerOnlyFollowup':'Final shorter typed title changes no source crop, source copy, output placement or page count. All 476 placements and 6 copied rectangles equal the reviewed earlier-title export.'}}
(report/'visual-review.json').write_text(json.dumps(review,indent=2)+'\n')
parts=work/'candidate/parts';manifest=load(parts/'manifest.json')
provenance={'status':'draft; source-bound changed-region review complete','source':manifest['source'],'sourceSHA256':manifest['sourceSHA256'],'baselineCommit':'82b606e','candidateAnalyzerSHA256':sha(work/'candidate/Core/Detection/NativeScorePageAnalyzer.swift'),'candidatePlannerSHA256':sha(work/'candidate/Core/Detection/ScoreExtractionPlanner.swift'),'nativeWorkerInventorySHA256':sha(work/'candidate/mozart-inventory.json'),'profileSHA256':sha(root/'Tests/quality_control/profiles/medium-skewed-01-mozart-piano-quartet-k478-imslp-86903.json'),'rectifications':[],'manualAssignmentOverrides':[],'manualPageBreaks':[],'autoDocumentRun':True,'instrumentInitialization':'Predefined four-part profile: Violin, Viola, Violoncello, two-staff Piano.','musicalStrips':476,'directionCopies':6,'pdfPages':43,'savedReopenedBeforeExport':True,'originalEmbeddedSourceHashVerified':True,'report':'Tests/quality_control/ownership-mozart-output-2026-10-03/README.md','parts':[{'file':p['file'],'pages':p['outputPages'],'strips':p['bandCount'],'sha256':p['sha256']} for p in manifest['parts']]}
(parts/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
(parts/'README.md').write_text('''# Mozart K. 478 — complete Auto draft\n\nFour parts from the complete 30-page IMSLP86903 score: Violin8 pages, Viola8, Violoncello9, Piano18;43 pages total. Each part contains119 systems. Open the `.partsmithproject` to edit; it embeds the unchanged original PDF.\n\nGenerated through the actual Partsmith Auto document workflow with the supplied four-instrument profile, then saved, reopened and exported by the native layout engine. No manual staff assignments, deskew corrections or page breaks were added. The candidate retains all476 musical strips and6 copied directions.\n\nPage25 now separates Violin and Viola from their whole neighboring staffs. Both changed output pages were source-reviewed by two reviewers; no new target-note, slur, dynamic or layout clipping was observed. Pagination remains43 pages.\n\nThis remains a draft. Neighbor fragments remain. The original scan itself cuts some notation at the right edge. Piano repeats the locally printed Allegro/Andante after automatic heading copies; Cello crops include those neighboring Piano headings too. These are unchanged issues. The entire score has not been certified note by note or for performance page turns.\n\nReview: `Tests/quality_control/ownership-mozart-output-2026-10-03/README.md`. `manifest.json` records every source/output rectangle; `provenance.json` and `delivery-hashes.json` bind the reviewed files.\n''')
files=[{'path':str(p.relative_to(parts)),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(parts.rglob('*')) if p.is_file() and p.name!='delivery-hashes.json']
(parts/'delivery-hashes.json').write_text(json.dumps(files,indent=2)+'\n')
(report/'delivery-hashes.json').write_bytes((parts/'delivery-hashes.json').read_bytes())
print('Final part hashes:')
for p in provenance['parts']:print(p['file'],p['pages'],p['sha256'])
