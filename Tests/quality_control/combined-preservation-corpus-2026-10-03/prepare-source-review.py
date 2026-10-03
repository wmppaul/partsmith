#!/usr/bin/env python3
"""Render untouched original source contexts before viewing proposed crops."""
from pathlib import Path
import argparse,hashlib,json
import pymupdf
P=argparse.ArgumentParser();P.add_argument('--scale',type=float,default=4);P.add_argument('--id');P.add_argument('--page',type=int);A=P.parse_args();ROOT=Path(__file__).resolve().parent;OUT=ROOT/'source-review';OUT.mkdir(exist_ok=True)
read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
queue=read(ROOT/'source-review-queue.json');index=[]
for job in queue:
 if A.id and A.id!=job['id']:continue
 if A.page and A.page!=job['page']:continue
 assert sha(job['source'])==job['sourceSHA256']
 doc=pymupdf.open(job['source']);page=doc[job['page']-1];width,height=page.rect.width,page.rect.height
 # Start with full original page. Region selection is a review aid, not a
 # preservation oracle and not a proposed extraction boundary.
 filename=job['id']+f'-p{job["page"]:03d}';directory=OUT/filename;directory.mkdir(exist_ok=True)
 full=page.get_pixmap(matrix=pymupdf.Matrix(2,2),colorspace=pymupdf.csGRAY,alpha=False);fullPath=directory/'original-full-page.png';full.save(fullPath)
 boxes=[]
 if job['componentChanges']:
  for c in job['componentChanges']['removed']+job['componentChanges']['added']:
   x0,y0,x1,y1=c['bounds'];boxes.append([x0*width,y0*height,x1*width,y1*height])
 for band in job['changedBands']:
  for key in ['beforePDFBounds','afterPDFBounds']:
   if key in band:boxes.append(band[key])
 # Connected vertical ranges yield full-width source contexts. Horizontal
 # branches and labels cannot be omitted by a candidate component's narrow box.
 intervals=[]
 for b in sorted(boxes,key=lambda q:q[1]):
  top=max(0,b[1]-20);bottom=min(height,b[3]+20)
  if intervals and top<=intervals[-1][1]:intervals[-1][1]=max(intervals[-1][1],bottom)
  else:intervals.append([top,bottom])
 if not intervals:intervals=[[0,height]]
 regions=[]
 for n,(top,bottom) in enumerate(intervals,1):
  rect=[0,top,width,bottom];pix=page.get_pixmap(matrix=pymupdf.Matrix(A.scale,A.scale),clip=pymupdf.Rect(rect),colorspace=pymupdf.csGRAY,alpha=False);path=directory/f'original-context-{n:02d}.png';pix.save(path)
  regions.append({'pdfBounds':rect,'pixelsPerPoint':A.scale,'pixelOrigin':[pix.x,pix.y],'path':str(path),'sha256':sha(path)})
 index.append({'key':job['key'],'source':job['source'],'sourceSHA256':job['sourceSHA256'],'page':job['page'],'fullSourceImage':{'path':str(fullPath),'sha256':sha(fullPath),'pixelsPerPoint':2},'contexts':regions,'reviewStatus':'not yet visually reviewed','instrumentIdentityMustNotBeInferred':job['instrumentIdentityMustNotBeInferred']})
(ROOT/'source-review-render-index.json').write_text(json.dumps(index,indent=2)+'\n');print('Prepared',len(index),'source-first review pages; no candidate images have been substituted for originals.')
