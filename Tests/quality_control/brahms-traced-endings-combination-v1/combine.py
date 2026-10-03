"""Combine a confirmed crop inventory with the immutable reviewed direction metadata."""
from pathlib import Path
import argparse, json, hashlib

p=argparse.ArgumentParser();p.add_argument('--inventory',required=True);p.add_argument('--sha256',required=True);p.add_argument('--out',required=True);a=p.parse_args()
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
crop_path=Path(a.inventory);old_path=Path('.build/qc-ending-native-v1/brahms-native-endings-inventory.json')
assert sha(crop_path)==a.sha256,'Crop inventory differs from confirmed snapshot'
assert sha(old_path)=='c7711cd6ef7e3a1886eeccf8fbf2f0911b95a6ee0f2b6f07f55fb2f2bd660d6d','Reviewed ending inventory differs'
new=json.loads(crop_path.read_text());old=json.loads(old_path.read_text())
assert new['sourceSHA256']==old['sourceSHA256']==sha(new['source'])
assert new['rectifications']==old['rectifications']
assert [x['pageIndex'] for x in new['pages']]==[x['pageIndex'] for x in old['pages']]
assert len(new['pages'])==39
changed=[]
for page,before in zip(new['pages'],old['pages']):
 assert [page['pageWidth'],page['pageHeight']]==[before['pageWidth'],before['pageHeight']]
 assert [(s['id'],s['staffLineFractions']) for s in page['staves']]==[(s['id'],s['staffLineFractions']) for s in before['staves']]
 if page.get('sharedHeadings') is not None:
  assert page.get('sharedHeadings')==before.get('sharedHeadings'),'Do not replace different heading recognition silently'
 assert all(n in before.get('sharedNavigation',[]) for n in page.get('sharedNavigation',[])),'Do not replace new/different direction recognition silently'
 for key in ['sharedHeadings','sharedNavigation']:
  if page.get(key)!=before.get(key):changed.append({'pageIndex':page['pageIndex'],'field':key,'oldCount':len(page.get(key) or []),'newCount':len(before.get(key) or [])})
  if key in before:page[key]=before[key]
  else:page.pop(key,None)
assert sum(len(x.get('sharedHeadings') or []) for x in new['pages'])==7
assert sum(len(x.get('sharedNavigation') or []) for x in new['pages'])==7
out=Path(a.out);assert not out.exists();out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(new,indent=2)+'\n')
proof={'cropInventory':{'path':str(crop_path),'sha256':sha(crop_path)},'directionInventory':{'path':str(old_path),'sha256':sha(old_path)},'combinedInventory':{'path':str(out),'sha256':sha(out)},'sourceSHA256':new['sourceSHA256'],'pages':39,'savedRectifications':9,'stavesAndSourceDimensionsIdentical':True,'directionMetadataExactlyPreserved':True,'metadataChangesFromCropInventory':changed,'note':'Narrow reviewed ending copies retained. Rejected blanket-margin experiment is not used.'}
out.with_name(out.stem+'-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps(proof,indent=2))
