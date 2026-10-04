from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
D=Path('.build/motets-source-equivalence-2026-10-03');read=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();scores=read(D/'native-pages.json');assert len(scores)==2 and scores[0]['pageCount']==scores[1]['pageCount']==18
rows=[]
for a,b in zip(scores[0]['pages'],scores[1]['pages']):
 A=np.array(Image.open(a['path']).convert('RGBA'));B=np.array(Image.open(b['path']).convert('RGBA'));assert A.shape==B.shape
 diff=A!=B;pixel=diff.any(axis=2);n=int(pixel.sum());ys,xs=np.where(pixel)
 delta=np.abs(A.astype(np.int16)-B.astype(np.int16));grayA=A[:,:,:3].mean(axis=2);grayB=B[:,:,:3].mean(axis=2)
 rows.append({'physicalPage':a['physicalPage'],'pageGeometryExact':a['boxes']==b['boxes']and a['rotation']==b['rotation'],'boxes':a['boxes'],'rotation':a['rotation'],'dimensions':[a['imageWidth'],a['imageHeight']],'decodedMode':'RGBA8, row-major, top down','decodedPixelSHA256':[hashlib.sha256(A.tobytes()).hexdigest(),hashlib.sha256(B.tobytes()).hexdigest()],'decodedPixelsExact':n==0,'differentPixels':n,'totalPixels':int(pixel.size),'differentPixelFraction':n/pixel.size,'changedBoundsHalfOpen':None if not n else[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],'meanAbsoluteChannelDifference':float(delta.mean()),'maximumChannelDifference':int(delta.max()),'under190MaskXorPixels':int(np.count_nonzero((grayA<190)!=(grayB<190))),'renders':[{'path':a['path'],'sha256':sha(Path(a['path']))},{'path':b['path'],'sha256':sha(Path(b['path']))}]})
result={'sourcePaths':[s['source']for s in scores],'sourceSHA256':[sha(Path(s['source']))for s in scores],'pageCounts':[s['pageCount']for s in scores],'allPageGeometryExact':all(r['pageGeometryExact']for r in rows),'exactDecodedPages':[r['physicalPage']for r in rows if r['decodedPixelsExact']],'differentDecodedPages':[r['physicalPage']for r in rows if not r['decodedPixelsExact']],'sourceMapTransferSupported':all(r['pageGeometryExact']and r['decodedPixelsExact']for r in rows),'scope':'Original physical page geometry and exact native render equivalence only. No detector replay, assignment or project mutation.','rows':rows,'rendererBinarySHA256':sha(D/'render')}
(D/'comparison.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k!='rows'},indent=2))
print([(r['physicalPage'],r['differentPixels'],r['under190MaskXorPixels'])for r in rows])
