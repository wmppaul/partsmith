import json, hashlib
from pathlib import Path
import numpy as np
from PIL import Image
repo = Path('/Users/will/Documents/git/partsmith')
fixed = repo/'Tests/quality_control/terminal-body-independent-2026-10-03'
run = repo/'.build/notehead-provenance-2026-10-03'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
known=json.loads((fixed/'hashes.json').read_text())
observations=[]
seen=set()
for label,filename,source_subdir in [('original','results180.json','sources'),('tied','results36.json','tied-sources')]:
    results=json.loads((run/filename).read_text())
    for case in results:
        source=Path(case['sourceImage'])
        expected=fixed/source_subdir/source.name
        assert sha(source)==sha(expected)==known[f'{source_subdir}/{source.name}'],source
        image=np.array(Image.open(source).convert('L'))
        for t,mask_path in zip(case['targets'],case['ownerMasks']):
            mask_path=Path(mask_path); expected=fixed/source_subdir/mask_path.name
            assert sha(mask_path)==sha(expected)==known[f'{source_subdir}/{mask_path.name}'],mask_path
            seen.update([str(source.relative_to(run)), str(mask_path.relative_to(run))])
            mask=np.array(Image.open(mask_path).convert('L'))<128
            assert np.all(image[mask]<128),mask_path
            y,x=np.nonzero(mask)
            envelope=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
            l,top,r,b=t['crop']; eps=1e-9
            lost=int(np.count_nonzero((x<l-eps)|(y<top-eps)|(x+1>r+eps)|(y+1>b+eps)))
            assert envelope==t['envelope'],(case['name'],envelope,t['envelope'])
            assert len(x)==t['sourcePixelCount'] and lost==t['sourcePixelsOutsideCrop']
            assert (lost==0)==t['preserved']
            observations.append(dict(set=label,case=case['name'],owner=t['owner'],pixels=len(x),lost=lost))
summary={'method':'Parent PIL/NumPy recomputation from immutable 720x600 source owner masks; complete unit pixel containment, no detector-derived mask', 'observations':len(observations),'sourceAndMaskFilesVerified':len(seen),'knownManifestSHA256':sha(fixed/'hashes.json'),'originalCandidateSHA256':sha(run/'results180.json'),'tiedCandidateSHA256':sha(run/'results36.json'),'allClaimsMatch':True,'results':observations}
out=repo/'.build/brahms-review-root-2026-10-03/notehead-independent-mask-check.json'
out.write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='results'},indent=2))
