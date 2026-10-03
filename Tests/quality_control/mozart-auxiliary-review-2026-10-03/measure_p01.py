from pathlib import Path
import pymupdf as fitz,numpy as np,json,hashlib
base=Path('Tests/quality_control/mozart-auxiliary-review-2026-10-03')
a=json.loads((base/'p01-frozen-source-obligations.json').read_text());cmp=json.loads((base/'p01-initial-output-comparison.json').read_text());p=fitz.open(a['source'])[0]
for o,old in zip(a['obligations'],cmp['localObligations']):
 r=fitz.Rect(o['rect']);s=8;pix=p.get_pixmap(matrix=fitz.Matrix(s,s),colorspace=fitz.csGRAY,clip=r)
 im=np.frombuffer(pix.samples,np.uint8).reshape(pix.height,pix.width);ys,xs=np.nonzero(im<255)
 b=[(pix.x+xs.min())/s,(pix.y+ys.min())/s,(pix.x+xs.max()+1)/s,(pix.y+ys.max()+1)/s]
 darkys,_=np.nonzero(im<128)
 below=int(np.sum((pix.y+darkys+.5)/s>=cmp['band']['sourceRect'][3]))
 assert b==old['measuredNonwhiteBounds'] and below==old['darkPixelsBelowCurrentCrop'],(o['id'],b,below,old)
 print(o['id'],b,below)
