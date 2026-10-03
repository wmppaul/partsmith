import pathlib,json,hashlib
from PIL import Image,ImageDraw
r=pathlib.Path('Tests/quality_control/brahms-reviewed-cleanup-2026-10-03');o=pathlib.Path('.build/brahms-seven-source-review-2026-10-03');source=json.loads((r/'source-context-binding.json').read_text());contexts={x['page']:x for x in source['contexts'] if 'rectified-' in x['image']}
def region(band,name,rect,content):return dict(bandID=band,id=name,rect=rect,content=content)
rows=[
region('p24-s2-viola','p24-viola-low-forte',[301,272,316,281.5],'Detached forte below penultimate bar; belongs to Viola, not Cello.'),
region('p24-s2-cello','p24-cello-low-forte',[300,306,316,315.5],'Cello forte below penultimate bar.'),
region('p28-s1-violin1','p28-violin1-hairpin-forte',[242,54,301,64],'Complete crescendo wedge followed by forte below Violin I; no Violin II core needed.'),
region('p28-s1-violin2','p28-violin2-low-phrase',[242,74,301,98.5],'Fifth-bar lower phrase slur, low flagged ledger note, crescendo wedge and following forte.'),
region('p31-s1-violin2','p31-violin2-piano-and-low-slur',[97,91,134,105.5],'Detached piano dynamic, lower slur and articulation dot after the initial rest bar.'),
region('p38-s1-viola','p38-viola-triplet-and-low-slurs',[70,95,117,132.5],'Opening triplet numeral, dual-voice notes, lower nested slurs and detached tenuto marks.'),
region('p38-s1-viola','p38-viola-final-high-note-arcs',[374,90,390,117],'Last high ledger note and both right-edge phrase arcs above it.'),
region('p38-s1-viola','p38-viola-final-forte',[342,121,358,133],'Viola forte beneath final bar.'),
region('p38-s1-viola','p38-viola-lower-tenutos',[69,128,338,133],'Detached lower tenutos through the first six bars.'),
region('p38-s1-cello','p38-cello-opening-accidental-slurs',[65,145,95,163],'Opening accidental, low ledger note, nested lower slurs and tenuto.'),
region('p38-s1-cello','p38-cello-final-forte',[340,152,358,163],'Cello final forte below hollow note.'),
region('p38-s1-cello','p38-cello-lower-tenutos',[68,158,335,163],'Cello detached tenutos under phrases and low notes.')]
for row in rows:
 p=int(row['bandID'].split('-')[0][1:]);c=contexts[p];img=Image.open(c['image']);s=c['scale'];x0,y0,x1,y1=row['rect'];clip=c['clip'];bounds=[round((x0-clip[0])*s),round((y0-clip[1])*s),round((x1-clip[0])*s),round((y1-clip[1])*s)]
 out=img.crop(bounds);path=o/(row['id']+'.png');out.save(path);row.update(page=p,coordinateSpace='saved-corrected source PDF top-down points',pixelsPerPoint=s,image=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),sourceContextPath=c['image'],sourceContextSHA256=c['imageSHA256'],sourceClip=clip)
 canvas=Image.new('RGB',(max(500,out.width*2),out.height*2+50),'white');canvas.paste(out.resize((out.width*2,out.height*2)),(0,50));ImageDraw.Draw(canvas).text((5,5),row['id']+' '+str(row['rect']),fill='black');canvas.save(o/(row['id']+'-view.png'))
(o/'additional-local-obligations-proposed.json').write_text(json.dumps({'status':'Source-reviewed local obligations supplementing unchanged seven broad target envelopes; every rectangle is within its pre-existing envelope, not a per-pixel ownership mask.','sourceSHA256':source['sourceSHA256'],'correctedSourceSHA256':source['correctedSourceSHA256'],'regions':rows},indent=2)+'\n')
