import json
from pathlib import Path
import pymupdf as fitz
import numpy as np
import argparse
parser=argparse.ArgumentParser(description='Check reviewed piano mask edges and preserve target clef, slur and chord.')
parser.add_argument('output', type=Path)
args=parser.parse_args()
out=args.output
r=json.loads((out/'recipe.json').read_text());m=json.loads((out/'manifest.json').read_text())
source=fitz.open(out/r['source']);actual=fitz.open(out/'Piano.pdf')
placements={b['id']:b for b in m['parts'][0]['placements']}
probes={'piano-p2-s3':[30,400,51,435], 'piano-p2-s4':[235,555,335,570], 'piano-p3-s1':[516,90,541,116]}
results={'edgeChecks':[],'preservationChecks':[]}
def pixels(page,rect):
 pix=page.get_pixmap(matrix=fitz.Matrix(4,4),clip=rect,colorspace=fitz.csGRAY,alpha=False)
 return np.frombuffer(pix.samples,dtype=np.uint8).reshape(pix.height,pix.width)
for band in r['parts'][0]['bands']:
 if not band.get('exclusions'): continue
 pl=placements[band['id']];sr=fitz.Rect(band['rect']);dr=fitz.Rect(pl['destinationRect']);scale=dr.width/sr.width
 def mapped(v):
  return fitz.Rect(dr.x0+(v[0]-sr.x0)*scale,dr.y0+(v[1]-sr.y0)*scale,dr.x0+(v[2]-sr.x0)*scale,dr.y0+(v[3]-sr.y0)*scale)
 page=actual[pl['outputPage']-1]
 for j,mask in enumerate(band['exclusions']):
  # Crucially includes the crop-top edge where the old overlay leaked dark ink.
  region=mapped([mask[0]+1,mask[1],mask[2]-1,mask[1]+.6])
  a=pixels(page,region);black=int((a<220).sum());assert black==0,(band['id'],j,black)
  results['edgeChecks'].append({'band':band['id'],'mask':j+1,'darkPixelsAtCropEdge':black})
 if band['id'] in probes:
  ref=fitz.open();rp=ref.new_page(width=612,height=792);rp.show_pdf_page(dr,source,band['page']-1,clip=sr,keep_proportion=True)
  region=mapped(probes[band['id']]);ap=pixels(page,region);bp=pixels(rp,region)
  assert ap.shape==bp.shape
  maxdiff=int(np.abs(ap.astype(int)-bp.astype(int)).max());ink=int((bp<200).sum());assert ink>20 and maxdiff==0,(band['id'],ink,maxdiff)
  results['preservationChecks'].append({'band':band['id'],'sourceROI':probes[band['id']],'referenceInkPixels':ink,'maximumPixelDifference':maxdiff})
print(json.dumps(results,indent=2))
