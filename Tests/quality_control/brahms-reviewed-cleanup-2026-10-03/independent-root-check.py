from pathlib import Path
import json,hashlib
import pymupdf as fitz
from PIL import Image,ImageDraw
repo=Path('/Users/will/Documents/git/partsmith')
old=repo/'output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-preservation'
new=repo/'.build/brahms-reviewed-cleanup-2026-10-03/manual-parts'
report=repo/'.build/brahms-review-root-2026-10-03/export-review';report.mkdir(exist_ok=True)
A=json.loads((old/'manifest.json').read_text());B=json.loads((new/'manifest.json').read_text())
P=json.loads((repo/'Tests/quality_control/brahms-reviewed-cleanup-2026-10-03/manual-proposals-v1.json').read_text())
proposals={x['bandID']:x['proposedRect'] for x in P['proposals']}
changes=[]; pages=[]; partcounts=[]
def source_fields(d):
 if isinstance(d,list): return [source_fields(x) for x in d]
 if isinstance(d,dict): return {k:source_fields(v) for k,v in d.items() if k not in ['destinationRect','outputPage']}
 return d
assert A['sourceSHA256']==B['sourceSHA256']
for a,b in zip(A['parts'],B['parts']):
 assert a['id']==b['id'] and a['bandCount']==b['bandCount']==151
 aa={x['id']:x for x in a['placements']};bb={x['id']:x for x in b['placements']};assert aa.keys()==bb.keys()
 for key in aa:
  u,v=aa[key],bb[key]
  # All source identity and semantic fields, including every copied marking.
  assert source_fields({k:q for k,q in u.items() if k not in ['sourceRect','provenance']})==source_fields({k:q for k,q in v.items() if k not in ['sourceRect','provenance']}),key
  assert v['provenance']==('manual-source-reviewed-crop' if key in proposals else u['provenance']),key
  if u['sourceRect']!=v['sourceRect']:
   assert key in proposals and all(abs(x-y)<1e-8 for x,y in zip(v['sourceRect'],proposals[key])),key
   changes.append(key)
 da=fitz.open(old/a['file']);db=fitz.open(new/b['file']);assert len(da)==len(db)==b['outputPages']
 partcounts.append({'part':b['name'],'pages':len(db),'systems':b['bandCount']})
 for i in range(len(db)):
  pa=da[i].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
  pb=db[i].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
  same=pa.width==pb.width and pa.height==pb.height and pa.samples==pb.samples
  item={'part':b['id'],'page':i+1,'identicalPixels':same,'candidatePixelSHA256':hashlib.sha256(pb.samples).hexdigest()}
  if not same:
   name=f"{b['id']}-{i+1:02d}.png"; pb.save(report/name)
   imA=Image.frombytes('RGB',[pa.width,pa.height],pa.samples);imB=Image.frombytes('RGB',[pb.width,pb.height],pb.samples)
   panel=Image.new('RGB',(pa.width+pb.width,max(pa.height,pb.height)+26),'#dddddd');panel.paste(imA,(0,26));panel.paste(imB,(pa.width,26))
   d=ImageDraw.Draw(panel);d.text((8,5),f"Auto / {b['name']} / {i+1}",fill='black');d.text((pa.width+8,5),f"Manually reviewed / {b['name']} / {i+1}",fill='black');panel.save(report/f'compare-{name}')
   item['candidateImage']=str(report/name); item['comparisonImage']=str(report/f'compare-{name}')
  pages.append(item)
assert set(changes)==set(proposals) and len(changes)==7
summary={'method':'Independent parent manifest comparison and PyMuPDF108dpi comparison against published Auto PDFs','sevenSourceChangesExact':True,'otherSourceAndSemanticFieldsExact':True,'provenanceChanges':'exact manual-source-reviewed-crop on seven reviewed rows only','parts':partcounts,'changedSourceBands':changes,'totalPages':len(pages),'unchangedPages':sum(x['identicalPixels'] for x in pages),'pages':pages}
(report/'results.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='pages'},indent=2));print('changed pages',[(x['part'],x['page']) for x in pages if not x['identicalPixels']])
