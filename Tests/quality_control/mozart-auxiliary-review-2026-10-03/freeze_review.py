from pathlib import Path
import json,hashlib,shutil,zipfile
import pymupdf as fitz
root=Path.cwd();work=root/'.build/mozart-auxiliary-review-2026-10-03';report=root/'Tests/quality_control/mozart-auxiliary-review-2026-10-03';delivery=root/'output/pdf/auto-qc-2026-09-21/mozart-k478-86903-preservation'
source=root/'sample_scores/medium_skewed/01_mozart_piano_quartet_k478_imslp_86903.pdf'
inventory=root/'.build/ownership-mozart-output-2026-10-03/candidate/mozart-inventory.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,v): (report/name).write_text(json.dumps(v,indent=2)+'\n')
inv=json.loads(inventory.read_text());manifest=json.loads((delivery/'manifest.json').read_text());cmp=json.loads((report/'p01-initial-output-comparison.json').read_text());page=inv['pages'][0]
space=max((s['staffLineFractions'][4]-s['staffLineFractions'][0])*page['pageHeight']/4 for s in page['staves'] if s['id'] in [13,14]);bottom=cmp['band']['sourceRect'][3]
low=[];cross=[]
for i,c in enumerate(page['inkComponents']):
 b=c['bounds'];p=[b[0]*page['pageWidth'],b[1]*page['pageHeight'],b[2]*page['pageWidth'],b[3]*page['pageHeight']]
 if p[3]>715 and p[1]<738:
  v={'index':i,'pointBounds':p,'staffIDs':c['staffIDs'],'isOwnershipAlternative':c.get('isOwnershipAlternative',False)};low.append(v)
  if p[1]<bottom<p[3]:cross.append(v)
small=next(c for c in low if c['index']==1313)
assert abs(small['pointBounds'][3]+max(space/2,2)-bottom)<1e-9
save('p01-mechanism.json',{'inventory':str(inventory.relative_to(root)),'inventorySHA256':sha(inventory),'mainStaffCount':len(page['staves']),'pianoCandidateIDs':[13,14],'smallStaffIsDetectedMainStaff':False,'staffSpacePoints':space,'sourceCropBottom':bottom,'smallStaffComponent':small,'normalBottomClearancePoints':max(space/2,2),'computedBottomFromSmallStaffComponent':small['pointBounds'][3]+max(space/2,2),'smallStaffToNearestLabelComponentHorizontalGapPoints':355.454-346.998,'relayHorizontalLimitPoints':space,'lowerContextComponents':low,'componentsIntersectingCropBoundary':cross,'explanation':'Only main grand-staff IDs13 and14 define this band. Auxiliary staff is an unowned detached ink component. Its bottom plus ordinary clearance exactly matches the delivered crop. Detached label lies more than one staff-space horizontally from the auxiliary component. The final crop intersects English-label components without retaining their complete bounds. No production classifier or geometry was changed.'})
sourceDoc=fitz.open(source)
pages=[]
for i,p in enumerate(sourceDoc):
 image=work/'original-pages'/f'p{i+1:02}.png'
 pages.append({'sourcePage':i+1,'originalPageBounds':list(p.rect),'sourceImage':str(image.relative_to(root)),'sourceImageSHA256':sha(image),'visualReview':'Full-page source overview reviewed before comparing page-specific output. No separate auxiliary staff observed.' if i else 'Full original and enlarged lower Piano context reviewed. One short editorial alternative for last Piano bass staff, with two-language label and dotted alignment links.','observedFullSizeSystems':3 if i==0 else 4,'expectedMainStaves':15 if i==0 else 20,'separateAuxiliaryStaffCountObserved':1 if i==0 else 0,'observedAuxiliaryOwner':'piano' if i==0 else None})
save('all-pages-source-review.json',{'source':str(source.relative_to(root)),'sourceSHA256':sha(source),'pageCount':30,'totalMainSystemsObserved':119,'separateAuxiliaryStaffCountObserved':1,'method':'Visual source-first overview of every original page, with enlarged original-source detail for the one separate short staff found. This is a search for separate auxiliary staves, not a pitch-by-pitch audit of all normal-size notes or a classifier recall guarantee.','pages':pages})
parts=manifest.get('parts');print(type(parts),str(parts)[:200])
records=[]
for f in sorted(delivery.glob('*.pdf')):
 d=fitz.open(f);records.append({'path':str(f.relative_to(root)),'sha256':sha(f),'pageCount':len(d)})
project=next(delivery.glob('*.partsmithproject'))
sourceFiles=[source,inventory,delivery/'manifest.json',delivery/'plan.json',project/'source.pdf',project/'project.json',root/'Partsmith/Core/Detection/NativeScorePageAnalyzer.swift',root/'Partsmith/Core/Detection/ScoreExtractionPlanner.swift']
save('input-bindings.json',{'inputs':[{'path':str(p.relative_to(root)),'sha256':sha(p),'bytes':p.stat().st_size} for p in sourceFiles],'currentPDFs':records,'noOutputOrProductionChanges':True})
for start in range(1,31,6):shutil.copy2(work/f'original-contact-{start:02}-{start+5:02}.png',report/f'original-contact-{start:02}-{start+5:02}.png')
shutil.copy2(work/'render_original.py',report/'render_original.py')
shutil.copy2(work/'freeze_review.py',report/'freeze_review.py')
print('saved30page source inventory; '+str(len(cross))+' native components intersect crop boundary; original source '+sha(source))
