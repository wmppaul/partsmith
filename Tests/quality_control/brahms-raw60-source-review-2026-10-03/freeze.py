from pathlib import Path
import json,hashlib,tarfile,shutil,collections
root=Path.cwd(); work=root/'.build/brahms-raw60-source-review-2026-10-03'; sid='medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521'; ctx=work/sid
out=root/'Tests/quality_control/brahms-raw60-source-review-2026-10-03';out.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,x):p.write_text(json.dumps(x,indent=2,ensure_ascii=False)+'\n')
rows=json.loads((ctx/'index.json').read_text()); notes=json.loads((work/'notes.json').read_text());assert len(rows)==len(notes)==60
queue=Path('Tests/quality_control/brahms-raw-corrected-review-reuse-2026-10-03/remaining-pending-bands.json'); frozen=json.loads(queue.read_text());assert {r['bandID'] for r in rows}==set(notes)
for r,q in zip(rows,frozen):
 for k,v in q.items():assert r[k]==v,(r['bandID'],k)
 assert sha(Path(r['context']))==r['contextSHA256'];assert sha(Path(r['sourceRaster']))==r['sourceRasterSHA256']
for r in rows[0]['inventoryFiles']:assert sha(Path(r['path']))==r['sha256']
assert sha(Path(rows[0]['source']))==rows[0]['sourceSHA256']
existing=['p34-s4-viola']
review=[]
for r in rows:
 review.append({'id':sid,'bandID':r['bandID'],'page':r['page'],'verdict':'No newly lost own-staff note, local mark or shared instruction observed in this changed source area.','newOwnStaffNoteLossObserved':False,'newLocalMarkLossObserved':False,'newSharedInstructionLossObserved':False,'existingOwnDynamicOmission':r['bandID'] in existing,'sourceInterpretation':notes[r['bandID']],'fullSourceViewed':True,'contextViewed':True,'sourceSHA256':r['sourceSHA256'],'beforePDFBounds':r['beforePDFBounds'],'afterPDFBounds':r['afterPDFBounds'],'candidateIDs':r['after']['candidateIDs'],'beforeWholeNeighbors':r['beforeWholeNeighbors'],'afterWholeNeighbors':r['afterWholeNeighbors'],'context':r['context'],'contextSHA256':r['contextSHA256'],'sourceRaster':r['sourceRaster'],'sourceRasterSHA256':r['sourceRasterSHA256']})
inward=[r for r in rows if r['after']['topFraction']>r['before']['topFraction']+1e-10 or r['after']['bottomFraction']<r['before']['bottomFraction']-1e-10]
summary={'scope':'Visual source review of the exact 60 previously pending raw Brahms 93521 changed crop areas, from original uncorrected PDF.','reviewVersion':1,'candidateNativeSHA256':'95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0','reviewedCrops':60,'sourcePhysicalPages':sorted({r['page'] for r in rows}),'inwardEdgeChanges':len(inward),'outwardOnlyChanges':60-len(inward),'sourceReviewQueueSHA256':sha(queue),'sourceSHA256':rows[0]['sourceSHA256'],'newOwnStaffNoteLossObserved':0,'newLocalMarkLossObserved':0,'newSharedInstructionLossObserved':0,'wholeForeignRelationsBefore':sum(len(r['beforeWholeNeighbors']) for r in rows),'wholeForeignRelationsAfter':sum(len(r['afterWholeNeighbors']) for r in rows),'newWholeForeignRelations':sum(len(set(r['afterWholeNeighbors'])-set(r['beforeWholeNeighbors'])) for r in rows),'existingOwnDynamicDefect':{'bandID':'p34-s4-viola','text':'f','observation':'The lower portion of the own-staff forte is cut by the identical baseline/candidate bottom edge. Source detail preserves this defect; it is not counted as a newly introduced loss.','followup':'Original/corrected counterpart investigation assigned separately; no old guard changed.'},'otherLimits':['Conspicuous neighboring notes, slurs, dynamics and staff fragments remain in most crops.','Rehearsal/tempo labels outside both baseline and candidate lower-part crops remain existing raw-plan omissions; examples E on page 7, B on page 17, D on page 19, Coda on page 28, Doppio Movimento on page 34.','The optional shared-direction workflow was not run here; no stage coverage is inferred.','Three whole-neighbor removals on page 28 do not establish overall crop cleanliness.','Visual inspection is not an exhaustive note-level pixel oracle or certification of all 604 bands.','No parts exported, pagination checked, or production code changed.','Other corpus instruction-loss failures still block crop promotion.'],'nativeAnalysisRun':False,'sourceRectified':False,'algorithmsChanged':False,'sourceGuardsChanged':False,'outputApproved':False}
dump(out/'per-band-review.json',review);dump(out/'summary.json',summary)
for p in ['protocol-before-review.json','generate.py','notes.json','p34-s4-viola-existing-f-binding.json']:
 shutil.copy2(work/p,out/p)
for p in ['index.json','bindings.json','sheets.json','priority.json']:shutil.copy2(ctx/p,out/p)
# Store source pages and individual contexts once; sheets are deterministic composites
# whose hashes/ordered rows are retained in sheets.json and generator.
files={Path(r['context']) for r in rows}|{Path(r['sourceRaster']) for r in rows}|{work/'p34-s4-viola-existing-f-source.png'}
archive=out/'source-contexts.tar.gz';members=[]
with tarfile.open(archive,'w:gz') as tf:
 for p in sorted(files):
  name=str(p.relative_to(work)) if p.is_absolute() else str(p.resolve().relative_to(work))
  tf.add(p,arcname=name,recursive=False);members.append({'path':name,'sha256':sha(p),'bytes':p.stat().st_size})
dump(out/'archive-members.json',members)
with tarfile.open(archive) as tf:
 for r in members:assert hashlib.sha256(tf.extractfile(r['path']).read()).hexdigest()==r['sha256']
(out/'README.md').write_text('''# Remaining raw Brahms 93521 crop review

All **60 remaining changed crop areas** were inspected against the nine original, uncorrected source pages. No newly lost own-staff note, local mark or shared instruction was observed in this subset. Three complete neighboring-staff relations are removed on page 28. Most crops still retain conspicuous neighboring fragments.

This is not a clean-output or preservation pass. **Page 34, system 4, Viola already clips the lower portion of its own `f` dynamic.** The baseline and candidate share the same bottom edge. The isolated original-source detail and exact crop coordinates preserve this defect; it remains a required preservation fix, not an accepted omission. A separate follow-up checks its corrected-page counterpart.

Other existing limitations remain. Shared rehearsal/tempo instructions can lie outside both raw lower-part crops, including E, B, D, Coda and Doppio Movimento at the page/system positions described per band. No optional shared-direction recognition was run here, so its coverage is not assumed. Foreign dynamics can also appear beside the target, and page numbers or plate numbers remain in some strips.

The input is the original PDF, SHA256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. The candidate analyzer hash is `95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0`. Both frozen raw inventories and all 60 queue records were verified before rendering. No corrected raster was used, no detector was rerun, and no algorithm, guard, project or prior output was changed.

`per-band-review.json` records all 60 source judgments and original/candidate bounds. `index.json` preserves complete source and assignment bindings plus context-to-source coordinates. `source-contexts.tar.gz` stores the nine unmodified full-page renders, 60 individual annotated contexts and the isolated existing-dynamic detail once; `archive-members.json` binds every image. The 15 inspected overview sheets are reproducible from the ordered list in `sheets.json` and the saved rendering script.

This bounded visual review does not certify all 604 bands, note-level pixel completeness, final part layout or page turns. Other corpus instruction-loss failures remain blockers to cleanup promotion.
''')
shutil.copy2(__file__,out/'freeze.py')
manifest={str(p.relative_to(out)):{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json'};dump(out/'manifest.json',manifest)
for n,r in manifest.items():assert sha(out/n)==r['sha256']
print(json.dumps({'summary':summary,'report':str(out),'manifestSHA256':sha(out/'manifest.json'),'README_SHA256':sha(out/'README.md'),'archivedImages':len(members)},indent=2))
