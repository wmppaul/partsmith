from pathlib import Path
import json,hashlib
w=Path('.build/brahms-motets101579-complete-native-2026-10-03');o=Path('.build/motets101579-root-review-2026-10-03')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
m=json.loads((w/'final-parts/manifest.json').read_text());d=json.loads((w/'source-directions-final-before-output.json').read_text());idx=json.loads((w/'final-review-details/index.json').read_text())
near=lambda a,b:len(a)==len(b) and all(abs(x-y)<1e-7 for x,y in zip(a,b))
checks=[]
for p in m['parts']:
 assert sha(w/'final-parts'/p['file'])==p['sha256']
 for b in p['placements']:
  src=b['sourceRect'];dst=b['destinationRect'];scale=(dst[2]-dst[0])/(src[2]-src[0])
  assert abs((dst[3]-dst[1])/(src[3]-src[1])-scale)<1e-7
  for mk in b['sourceMarkings']:
   s=mk['sourceRect'];t=mk['destinationRect']
   matching=[a['id'] for a in d['directions'] if a['page']==b['sourcePage'] and a['system']==b['system'] and near(a['rect'],s)]
   if b['id']=='p12-s1-soprano-section' and near(s,[140,69,456,95]):matching=['reviewed complete title; local Versus I / Tempo giusto retained']
   assert matching,(b['id'],s)
   assert near([t[2]-t[0],t[3]-t[1]],[(s[2]-s[0])*scale,(s[3]-s[1])*scale])
   assert abs(t[0]-(dst[0]+(s[0]-src[0])*scale))<1e-7
   assert 0<=t[0]<t[2]<=612 and 0<=t[1]<t[3]<=792
   assert t[3]<=dst[1]-3.99999
   checks.append({'row':b['id'],'direction':matching,'sourceRect':s,'destinationRect':t,'outputPage':b['outputPage']})
assert len(checks)==72
for row in idx['rows']:
 for x in row['details']: assert sha(x['image'])==x['sha256']
 if 'sourceContext' in row:assert sha(row['sourceContext']['path'])==row['sourceContext']['sha256']
assert len(idx['rows'])==15
report={'sourceSHA256':m['sourceSHA256'],'finalManifestSHA256':sha(w/'final-parts/manifest.json'),'finalComparisonSHA256':sha(w/'final-comparison.json'),'finalDirectionPolicySHA256':sha(w/'source-directions-final-before-output.json'),'copiesVerified':72,'copyChecks':checks,'initialRootSourceCropReview':{'path':str(o/'initial-source-crop-review.json'),'sha256':sha(o/'initial-source-crop-review.json'),'individualRowsViewed':90},'visualReview':{'all18OriginalSourcePagesPreviouslyViewed':True,'all18UniqueDirectionSourceRegionsAndSharedHeaderViewed':True,'all15FinalChangedRowDetailsViewed':True,'detailsIndexSHA256':sha(w/'final-review-details/index.json'),'rows':[r['id'] for r in idx['rows']],'nineCropRepairsAccepted':True,'observations':'Shared Alto/Bass lyrics, Bass mf ascender, Piano footnotes and pedal retained; unwanted B removed and next Choral reduced. Opening/title duplication removed without losing own Versus I/Tempo. Expanded Wenig block retains full f descender.'},'limitations':['Neighboring lyric, note, clef/staff and direction fragments remain; not clean re-engraving.','Page-turn convenience is not certified.','Root final visual review covers15 changed row details; independent agent covers all27 finished PDF pages.','No certification is transferred from the other scanned Motets edition.']}
(o/'final-root-receipt.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
print('Verified all72 copied-region geometry mappings and15 changed-detail identities.',sha(o/'final-root-receipt.json'))
