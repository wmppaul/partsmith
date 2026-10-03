from pathlib import Path
import json,hashlib
import pymupdf as f
import numpy as np
from PIL import Image,ImageDraw
R=Path('.build/erlkonig-complete-2026-10-03/independent-review');src=Path('sample_scores/normal/03_piano_vocal/schubert_erlkonig_d328_score.pdf');doc=f.open(src);scale=8
# Independently classified source regions contain all intended upper ink while excluding
# previous Piano ink. These regions were recorded from original full-width source views,
# before corrected crop tops were chosen. Only the upper-edge obligation is measured.
cases=[(2,3,374.6516943534627,[[30,363,380,383],[380,368,556,383]],363.5),
 (4,4,668.9494555474926,[[30,657,230,678],[230,665,556,678]],657.5),
 (6,2,220.88938092062682,[[30,209,74,230],[74,213,230,230],[230,215,380,230],[380,217,556,230]],209.375)]
rows=[]
for pn,sn,staff,regs,proposed in cases:
 clip=f.Rect(25,min(r[1] for r in regs)-8,561,staff+12);pix=doc[pn-1].get_pixmap(matrix=f.Matrix(scale,scale),clip=clip,colorspace=f.csGRAY,alpha=False);a=np.frombuffer(pix.samples,dtype=np.uint8).reshape(pix.height,pix.width);mask=np.zeros(a.shape,dtype=bool)
 for r in regs:mask[int(r[1]*scale)-pix.y:int(r[3]*scale)-pix.y,int(r[0]*scale)-pix.x:int(r[2]*scale)-pix.x]=True
 target=mask&(a<250);ys,xs=np.where(target);env=[(xs.min()+pix.x)/scale,(ys.min()+pix.y)/scale,(xs.max()+1+pix.x)/scale,(ys.max()+1+pix.y)/scale]
 out=Image.fromarray(np.repeat(a[:,:,None],3,axis=2));ar=np.array(out);ar[target]=[0,100,20];out=Image.fromarray(ar);d=ImageDraw.Draw(out);d.line((0,proposed*scale-pix.y,out.width,proposed*scale-pix.y),fill='red',width=2);name=f'voice-top-obligation-p{pn}-s{sn}.png';out.save(R/name)
 mp=R/f'voice-top-mask-p{pn}-s{sn}.png';Image.fromarray(np.where(target,255,0).astype('uint8')).save(mp)
 rows.append({'page':pn,'system':sn,'part':'Voice','sourceSelectionPurpose':'Complete upper-edge target ink, including printed numeral, clef/key tops, all note/stem/slur upper reaches. Lower target remains in unchanged baseline crop; this is not a full glyph mask.','sourceRegions':regs,'rasterScale':scale,'pixelThreshold':250,'rasterOrigin':[pix.x,pix.y],'targetUpperInkEnvelope':env,'minimalConservativeCropTop':proposed,'marginAboveFirstTargetInk':env[1]-proposed,'sourceImage':name,'mask':mp.name,'maskSHA256':hashlib.sha256(mp.read_bytes()).hexdigest(),'expectedResidualForeignInk':'Small previous Piano tail/mark tips share target vertical range; full-width crop cannot remove every fragment safely.'})
J={'source':str(src),'sourceSHA256':hashlib.sha256(src.read_bytes()).hexdigest(),'method':'Original source rendered at8pixels/point; selected target upper regions classified visually before proposed rectangle comparison. Music-font typographic boxes are intentionally not treated as ink boxes. All full systems and complete target glyphs were independently viewed.','rows':rows}
(R/'voice-top-source-obligations.json').write_text(json.dumps(J,indent=2)+'\n');print(json.dumps(rows,indent=2))
