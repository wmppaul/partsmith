from pathlib import Path
import json,pymupdf as fitz,numpy as np,hashlib,datetime
r=Path('Tests/quality_control/heading-local-ownership-2026-10-03');source=Path('sample_scores/medium_skewed/01_mozart_piano_quartet_k478_imslp_86903.pdf');pdf=fitz.open(source)
inv=json.load(open('.build/ownership-mozart-output-2026-10-03/candidate/mozart-inventory.json'));plan=json.load(open('.build/ownership-mozart-output-2026-10-03/candidate/mozart-plan.json'));records=[]
for page,word,globalroi,localroi in [(1,'Allegro.',[110,146,180,161],[110,238,186,259]),(12,'Andante.',[65,38,112,51],[65,114,126,128])]:
 boxes={}
 for role,roi in [('global',globalroi),('piano-local',localroi)]:
  pix=pdf[page-1].get_pixmap(matrix=fitz.Matrix(4,4),clip=fitz.Rect(roi),alpha=False);img=np.frombuffer(pix.samples,np.uint8).reshape(pix.height,pix.width,3);ys,xs=np.nonzero(img.min(axis=2)<255);assert len(xs)
  bounds=list(map(float,[(pix.x+xs.min()-1)/4,(pix.y+ys.min()-1)/4,(pix.x+xs.max()+2)/4,(pix.y+ys.max()+2)/4]));path=r/f'original-mozart-p{page:02}-{role}-word.png';pix.save(path)
  boxes[role]={'reviewedROI':roi,'nonwhiteGuard':bounds,'image':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 pg=inv['pages'][page-1];bands=[b for p in plan['pages'] if p['pageIndex']==page-1 for b in p['assignments'] if b['systemIndex']==0];expected=[]
 for b in bands:
  rect=[b['leftFraction']*pg['pageWidth'],b['topFraction']*pg['pageHeight'],(1-b['rightFraction'])*pg['pageWidth'],b['bottomFraction']*pg['pageHeight']];guard=boxes['global' if b['partID']=='violin' else 'piano-local']['nonwhiteGuard']
  contains=bool(rect[0]<=guard[0] and rect[1]<=guard[1] and rect[2]>=guard[2] and rect[3]>=guard[3])
  expected.append({'bandID':b['id'],'partID':b['partID'],'staffIDs':b['candidateIDs'],'sourceCrop':rect,'containsComparedWordGuard':contains,'expectedAutoCopy':b['partID'] in ['viola','cello'],'rationale':{'violin':'Own original global heading retained above first staff.','viola':'No own local heading; keep global copy.','cello':'No own local heading; incidental Piano heading below Cello cannot substitute.','piano':'Complete equivalent local heading above own first staff at same opening position; suppress only the automatic duplicate.'}[b['partID']]})
 records.append({'sourcePage':page,'system':1,'word':word,'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'anchors':{'globalStaffID':0,'pianoStaffID':3},'words':boxes,'recipients':expected})
out={'frozenAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'candidateNotInspected':True,'sourceFirst':True,'coordinateSystem':'top-down original PDF points; source pages and systems one-based','guardRule':'Every nonwhite pixel inside manually source-selected whole-word ROI, plus one 4x-render pixel; nearby scanned ink remains included. ROIs are source-review envelopes, not proposed copy bounds. Any conservative guard failure remains explicit.','records':records};(r/'mozart-recipient-obligations.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(records,indent=2))
