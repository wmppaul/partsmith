from pathlib import Path
import json,hashlib,tarfile,io,zipfile
base=Path('Tests/quality_control'); sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();h=lambda b:hashlib.sha256(b).hexdigest();results=[]
def load(q):return json.loads(q.read_text())
def files(q,rows):
 if isinstance(rows,dict):rows=[{'path':k,'sha256':v if isinstance(v,str) else v['sha256']} for k,v in rows.items()]
 for r in rows:assert sha(q/r['path'])==r['sha256'],str(q/r['path'])
def archive(q,path,expected):
 by={r['path']:r['sha256'] for r in expected}
 with tarfile.open(fileobj=io.BytesIO(path) if isinstance(path,bytes) else None,name=None if isinstance(path,bytes) else str(q/path),mode='r:gz') as t:
  actual={x.name for x in t.getmembers() if x.isfile()};assert actual==set(by),(len(actual),len(by))
  for name,hs in by.items():assert h(t.extractfile(name).read())==hs,name
 return len(by)
for name in ['motets101579-upper-source-crop-independent-2026-10-03','motets101579-final-output-independent-2026-10-03','p31-structural-gap-certificate-2026-10-03','brahms-residual-source-separation-2026-10-03']:
 q=base/name;m=load(q/'manifest.json')
 if 'files' in m:files(q,m['files'])
 if 'reviewFiles' in m:files(q,m['reviewFiles'])
 if 'archive' in m:
  a=m['archive'];assert sha(q/a['path'])==a['sha256']
  expected=a['members'] if isinstance(a['members'],list) else [{'path':k,'sha256':v} for k,v in m['files'].items()]
  n=archive(q,a['path'],expected)
 else:
  p=next(q.glob('*.tar.gz'));n=archive(q,p.name,load(q/'archive-members.json'))
 results.append({'folder':str(q),'manifestSHA256':sha(q/'manifest.json'),'payloadsVerified':n})
q=base/'motets101579-complete-native-2026-10-03';m=load(q/'archive-parts.json');files(q,m['chunks']);data=b''.join((q/r['path']).read_bytes() for r in m['chunks']);assert len(data)==m['assembledSize'] and h(data)==m['assembledSHA256'];n=archive(q,data,load(q/'archive-payloads.json'));assert n==461
results.append({'folder':str(q),'chunkManifestSHA256':sha(q/'archive-parts.json'),'assembledSHA256':h(data),'payloadsVerified':n});del data
s=Path('.build/brahms-motets101579-complete-native-2026-10-03/delivery-stage');m=load(s/'delivery-hashes.json');files(s,m['files']);z=next(s.glob('*.zip'))
with zipfile.ZipFile(z) as a:
 assert a.testzip() is None
 for p in s.rglob('*'):
  if p.is_file() and p!=z:assert h(a.read(p.relative_to(s).as_posix()))==sha(p)
results.append({'deliveryStage':str(s),'receiptSHA256':sha(s/'delivery-hashes.json'),'zipSHA256':sha(z),'allDeliveryFilesAndZIPMembersExact':True})
out=base/'delivery-root-verification-2026-10-04'/'evidence-verification.json';out.write_text(json.dumps({'results':results,'scope':'Byte and evidence-binding verification; musical findings remain in individual visual reviews.'},indent=2)+'\n');print(json.dumps(results,indent=2))
