from pathlib import Path
import shutil,json,hashlib
r=Path.cwd();q=r/'Tests/quality_control/motets101579-complete-native-2026-10-03';w=r/'.build/brahms-motets101579-complete-native-2026-10-03';dest=r/'output/pdf/auto-qc-2026-10-03/brahms-two-motets-op74-101579-native-draft'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();put=lambda p,d:p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
assert not dest.exists()
for name in ['final-root-receipt.json','verify_final_copies.py']:
 shutil.copyfile(r/'.build/motets101579-root-review-2026-10-03'/name,q/'root-review'/name)
bindings=[]
for name in ['motets101579-upper-source-crop-independent-2026-10-03','motets101579-final-output-independent-2026-10-03']:
 p=r/'Tests/quality_control'/name/'manifest.json';bindings.append({'path':str(p.relative_to(r)),'sha256':sha(p)})
p=r/'Tests/quality_control/delivery-root-verification-2026-10-04/evidence-verification.json';bindings.append({'path':str(p.relative_to(r)),'sha256':sha(p)})
put(q/'independent-review-bindings.json',{'reports':bindings,'rootFinalReceiptSHA256':sha(q/'root-review/final-root-receipt.json')})
shutil.copytree(w/'delivery-stage',dest)
for p in (w/'delivery-stage').rglob('*'):
 if p.is_file():assert sha(p)==sha(dest/p.relative_to(w/'delivery-stage'))
put(q/'delivery-binding.json',{'path':str(dest.relative_to(r)),'deliveryManifestSHA256':sha(dest/'delivery-hashes.json'),'generationManifestSHA256':sha(dest/'manifest.json'),'zipSHA256':sha(next(dest.glob('*.zip'))),'parts':5,'pages':27,'sourceRows':225,'copiedDirections':72})
put(q/'manifest.json',{'status':'Complete assisted draft; neighboring fragments and performance turns remain','files':[{'path':str(p.relative_to(q)),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(q.rglob('*')) if p.is_file() and p.name!='manifest.json']})
print(dest)
