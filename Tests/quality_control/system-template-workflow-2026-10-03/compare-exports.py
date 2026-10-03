import json,pathlib,hashlib,collections
import pymupdf as fitz
from PIL import Image,ImageOps,ImageDraw
root=pathlib.Path.cwd();base=root/'.build/system-template-workflow-2026-10-03';report=root/'Tests/quality_control/system-template-workflow-2026-10-03';old=root/'.build/erlkonig-complete-2026-10-03'
def read(p):return json.load(open(p))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
new=read(base/'parts/manifest.json');references={'nativeBaseline':read(old/'parts/manifest.json'),'manuallyCorrectedDraft':read(old/'reviewed-parts/manifest.json')}
results={}
for label,reference in references.items():
 before={b['id']:b for p in reference['parts'] for b in p['placements']};after={b['id']:b for p in new['parts'] for b in p['placements']};changes=[]
 assert before.keys()==after.keys()
 for k,a in after.items():
  b=before[k];assert a['candidateIDs']==b['candidateIDs'] and a['sourcePage']==b['sourcePage'] and a['system']==b['system'] and a['kind']==b['kind'] and a.get('generatedRest')==b.get('generatedRest')
  diff={field:{'before':b[field],'after':a[field]} for field in ['sourceRect','sourceMarkings'] if b[field]!=a[field]}
  if diff:changes.append({'id':k,'changes':diff})
 results[label]={'all96ItemIDsAndStaffIdentitiesAndRestCountsExact':True,'changedSourceRows':changes,'unchangedSourceRows':96-len(changes),'pageCountsBefore':{p['id']:p['outputPages'] for p in reference['parts']},'pageCountsAfter':{p['id']:p['outputPages'] for p in new['parts']}}
sourceMap=read(old/'source-reviewed-map.json');bars={(x['page'],x['system']):(x['firstBar'],x['firstBar']+x['barCount']-1) for x in sourceMap['systems']}
pageTurns=[];payloads=[]
render=base/'rendered';render.mkdir(exist_ok=True)
for part in new['parts']:
 pdf=base/'parts'/part['file'];assert sha(pdf)==part['sha256'];document=fitz.open(pdf);assert len(document)==part['outputPages'];pages=[]
 for pi,page in enumerate(document):
  imagePath=render/f"{part['id']}-{pi+1:02}.png";page.get_pixmap(matrix=fitz.Matrix(1.1,1.1)).save(imagePath);pages.append(imagePath)
 for op in range(1,part['outputPages']):
  a=[x for x in part['placements'] if x['outputPage']==op][-1];b=[x for x in part['placements'] if x['outputPage']==op+1][0]
  pageTurns.append({'partID':part['id'],'afterOutputPage':op,'outgoingSourceItem':a['id'],'incomingSourceItem':b['id'],'outgoingLastBarFromIndependentSourceMap':bars[(a['sourcePage'],a['system'])][1],'incomingFirstBarFromIndependentSourceMap':bars[(b['sourcePage'],b['system'])][0]})
 payloads.append({'path':str(pdf.relative_to(root)),'sha256':sha(pdf),'pages':len(document)})
 for chunk in range(0,len(pages),4):
  sheet=Image.new('RGB',(1020,1440),'#ccc');draw=ImageDraw.Draw(sheet)
  for ix,path in enumerate(pages[chunk:chunk+4]):
   image=Image.open(path);image.thumbnail((500,680));x=(ix%2)*510;y=(ix//2)*720;sheet.paste(image,(x,y+25));draw.text((x+8,y+6),path.stem,fill='black')
  sheet.save(report/f"{part['id']}-pages-{chunk+1:02}-{min(chunk+4,len(pages)):02}.png")
source=fitz.open(root/new['source']);piano=next(p for p in new['parts'] if p['id']=='piano');row=next(r for r in piano['placements'] if r['id']=='p4-s4-piano');hairpin=read(old/'independent-review/hairpin-source-obligation.json')
# A full original source context, independent of any proposed crop.
source[3].get_pixmap(matrix=fitz.Matrix(2,2),clip=fitz.Rect(10,708,585,820)).save(report/'p4-s4-source-hairpin-context.png')
pdf=fitz.open(base/'parts'/piano['file']);rect=fitz.Rect(row['destinationRect']);pdf[row['outputPage']-1].get_pixmap(matrix=fitz.Matrix(2,2),clip=fitz.Rect(rect.x0,rect.y0-3,rect.x1,rect.y1+3)).save(report/'p4-s4-workflow-piano-strip.png')
voice=next(p for p in new['parts'] if p['id']=='voice');pianoFirst=base/'rendered/piano-01.png';voiceFirst=base/'rendered/voice-01.png'
summary={'comparisons':results,'outputPDFs':payloads,'pageTurns':pageTurns,'knownHairpinDefect':{'sourceItem':row['id'],'workflowCrop':row['sourceRect'],'independentInkBottom':814.9606159627438,'containsIndependentHairpin':row['sourceRect'][3]>=814.9606159627438,'status':'Known native defect remains. Manual correction exists in separately reviewed draft; not applied by identity matching.'},'allExportedSourceSHA256':new['sourceSHA256'],'workflowManifestSHA256':sha(base/'parts/manifest.json'),'acceptedPlanSHA256':sha(base/'batch-plan.json'),'exportedPlanSHA256':sha(base/'parts/plan.json')}
(report/'export-comparison.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:{'unchanged':v['unchangedSourceRows'],'changed':[x['id'] for x in v['changedSourceRows']]} for k,v in results.items()},indent=2));print('page turns',pageTurns)
