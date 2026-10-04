from pathlib import Path
import json,hashlib,collections
W=Path('.build/local-line-ownership-corpus-2026-10-03');S=W/'source-review';read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
queue=read(W/'comparison/changed-crop-review-jobs.json');indices={}
for d in S.iterdir():
 if d.is_dir()and(d/'index.json').exists():
  for r in read(d/'index.json'):indices[(r['id'],r['bandID'])]=r
assert len(indices)==len(queue)==65
partNames={'violin':'Violin','violin1':'Violin I','violin2':'Violin II','viola':'Viola','cello':'Cello','clarinet':'Clarinet'}
rows=[]
for row in queue:
 r=indices[(row['id'],row['bandID'])];id=row['id'];bid=row['bandID'];part=row['after']['partID'];edges=row['edgeChangesPT'];classification='neighbor_fragments_or_edge_clearance';recovery='none demonstrated';remaining=[]
 if part=='clarinet':neighborBelow='Cello';neighborAbove='previous-system Piano'
 elif 'mozart-piano-quartet' in id:
  neighborBelow={'violin':'Viola','viola':'Cello','cello':'Piano'}[part];neighborAbove={'violin':'previous-system Piano','viola':'Violin','cello':'Viola'}[part]
 else:
  neighborBelow={'violin1':'Violin II','violin2':'Viola','viola':'Cello','cello':'next-system Violin I'}[part];neighborAbove={'violin1':'previous-system Cello','violin2':'Violin I','viola':'Violin II','cello':'Viola'}[part]
 notes=[]
 if edges[1]<0:notes.append(f'Upper expansion includes additional {neighborAbove} staff-line/music fragments; no additional own mark recovery demonstrated in that strip.')
 if edges[3]>0:notes.append(f'Lower expansion includes additional {neighborBelow} staff-line/music fragments or their edge clearance; no additional own mark recovery demonstrated in that strip.')
 if edges[1]>0:notes.append(f'Inward upper edge removes only {neighborAbove} staff-line fragments, above the intended staff notation. No target ink loss observed.')
 if '86903' in id and bid=='p22-s3-viola':
  classification='neighbor_fragment_removed';notes=['The 0.6041 pt upper contraction trims the upper Violin line. Viola fermata, notes, flats, forte and lower ties remain below this edge and complete at the changed boundary.']
 if '09200' in id and bid=='p8-s5-viola':notes=['The 2.95462 pt downward row shift removes upper Violin II line fragments and adds lower Cello-line fragments. Viola opening slur/chord/p and rests remain intact.']
 if '93521' in id and bid=='p34-s4-viola':
  classification='complete_own_mark_recovery_with_neighbor_fragment';recovery='complete previously clipped forte, confirmed by immutable 372-pixel source oracle';notes=['The lower extension recovers the entire own forte hook while adding Cello staff/beam fragments. The existing independently frozen 372-pixel source oracle is fully contained.']
 if '93521' in id and bid=='p8-s2-viola':
  classification='partial_own_mark_recovery_with_remaining_omission';recovery='partial in tempo letters and p descender';remaining=['Own in tempo p foot still clipped; newly frozen source-foot oracle requires minimum bottom 283.402858 pt, candidate ends 282.428130 pt.']
  notes=['The lower extension recovers bottoms of in tempo but not the complete p descender, which crosses the Cello top line. This corrects earlier real12 prose; it is not a complete preservation pass. See p8-in-tempo/source-landmark.json and production output page 3.']
 if '93521' in id and bid=='p39-s2-viola':notes.append('Closer source-edge inspection distinguishes the lower Cello slur from the own Viola slur above it; the own slur is not newly cut or recovered.')
 if '93521' in id and bid=='p36-s3-viola':notes.append('The lowest own Viola beam/tie stays above the old edge; the large new strip adds the upper Cello staff/beam, not missing Viola ink.')
 if '93521' in id and bid=='p17-s1-violin2':notes.append('The own cresc. remains above the old boundary; the newly included rising stems/slurs belong to Viola below.')
 rows.append({'scoreID':id,'bandID':bid,'page':row['page'],'partID':part,'source':row['source'],'sourceSHA256':row['sourceSHA256'],'inventoryFiles':row['inventoryFiles'],'beforePDFBounds':row['beforePDFBounds'],'afterPDFBounds':row['afterPDFBounds'],'edgeChangesPT':edges,'candidateIDs':row['after']['candidateIDs'],'context':r['context'],'contextSHA256':r['contextSHA256'],'sourceRaster':r['sourceRaster'],'sourceRasterSHA256':r['sourceRasterSHA256'],'originalSourceOverviewThenFullWidthContextViewed':True,'classification':classification,'ownNotationRecovery':recovery,'newTargetOmissionObserved':False,'newSharedInstructionRemovalObserved':False,'newWholeForeignStaffIDs':row['newWholeNeighbors'],'notes':notes,'remainingLimitations':remaining})
summary={'scope':'All 65 changed raw crop areas viewed, original PDF full-page renders/contact overviews before full-width old/new source contexts. This is changed-edge review, not full-score certification, exported layout review or shared-direction recognition.','scores':len(set(r['scoreID']for r in rows)),'physicalPages':len(set((r['scoreID'],r['page'])for r in rows)),'reviewedRows':len(rows),'classifications':dict(collections.Counter(r['classification']for r in rows)),'newTargetOmissionsObserved':0,'newSharedInstructionRemovalsObserved':0,'newWholeForeignRelations':sum(len(r['newWholeForeignStaffIDs'])for r in rows),'explicitRemainingOmission':'93521 p8s2Viola own in tempo p foot remains clipped; partial recovery is not a pass.','unreviewedScope':'139 zero-plan pages contain 729 genuine owner-label removals and no initialized assignments. Those effects remain unfinished; all 19 zero-band profiles and 15,712 unassigned staves remain unresolved. Existing old crop omissions, seven whole-neighbor Brahms cases and direction-stage limitations are not waived.','rawScope':'No corrections or optional headings/navigation/ending recognition in this corpus run. Existing original PDFs unchanged.','queueSHA256':sha(W/'comparison/changed-crop-review-jobs.json'),'sourceOracleSHA256':sha(S/'p8-in-tempo/source-landmark.json'),'reviewer':'ending_delivery','productionPromotion':False}
(S/'per-band-review.json').write_text(json.dumps(rows,indent=2)+'\n');(S/'review-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
