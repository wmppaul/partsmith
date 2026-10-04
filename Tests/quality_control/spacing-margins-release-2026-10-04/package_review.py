from pathlib import Path
import hashlib,json,shutil,tarfile
r=Path('.build/spacing-margins-release-2026-10-04');q=Path('Tests/quality_control/spacing-margins-release-2026-10-04');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
roster=json.loads((r/'source-hashes.json').read_text());audit=json.loads((r/'private-package-audit.json').read_text());assert audit['status']=='pass'
assert all(sha(r/p)==h==sha(p) for p,h in roster.items())
for n in ['source-hashes.json','snapshot-receipt.json','private-package-audit.json','build.sh','package_and_audit.py']:shutil.copyfile(r/n,q/n)
payloads=[]
paths=[r/p for p in roster]+[r/n for n in ['build.log','load-commands.txt','source-hashes.json','snapshot-receipt.json','private-package-audit.json','build.sh','package_and_audit.py']]
with tarfile.open(q/'build-evidence.tar.gz','w:gz') as t:
 for p in paths:
  name=p.relative_to(r).as_posix();t.add(p,arcname=name);payloads.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p)})
with tarfile.open(q/'build-evidence.tar.gz') as t:
 assert {x.name for x in t.getmembers() if x.isfile()}=={x['path'] for x in payloads}
 for x in payloads:assert hashlib.sha256(t.extractfile(x['path']).read()).hexdigest()==x['sha256']
(q/'archive-members.json').write_text(json.dumps(payloads,indent=2)+'\n')
print('Verified',len(payloads),'release evidence payloads;',sha(q/'build-evidence.tar.gz'))
