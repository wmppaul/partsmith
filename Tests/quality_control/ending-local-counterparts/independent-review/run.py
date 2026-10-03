#!/usr/bin/env python3
"""Rebuild frozen independent assertions against initial or current production Core."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
D=Path(__file__).resolve().parent;ROOT=D.parents[3]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=['initial','production']);p.add_argument('--out',type=Path);p.add_argument('--with-categories',action='store_true');a=p.parse_args()
W=(a.out or ROOT/'.build'/('ending-local-independent-'+a.mode)).resolve();W.mkdir(parents=True,exist_ok=True)
sha=lambda x:hashlib.sha256(x.read_bytes()).hexdigest()
for name,h in json.loads((D/'input-hashes.json').read_text()).items():
 path=Path(name) if Path(name).is_absolute() else ROOT/name
 if not path.exists() or sha(path)!=h:raise SystemExit('Input changed or missing: '+str(path))
core=(D/'initial-Core') if a.mode=='initial' else ROOT/'Partsmith/Core'
if (W/'Core').exists():raise SystemExit('Choose a fresh --out directory; existing source snapshot is preserved.')
shutil.copytree(core,W/'Core')
sources=sorted((W/'Core').rglob('*.swift'))
(W/'source-hashes.json').write_text(json.dumps({str(x.relative_to(W)):sha(x) for x in sources},indent=2)+'\n')
# Only the output path is rewritten. All fixture definitions and requirements
# are the unchanged independent audit source.
s=(D/'audit.swift').read_text().replace('.build/ending-local-independent-review/results.json',str(W/'results.json'))
extras=[]
if a.with_categories:
 s=s.replace('@main enum IndependentLocalEndingAudit','enum IndependentLocalEndingAudit')
 (W/'categories.swift').write_text((D/'categories.swift').read_text().replace('@main enum CounterpartCategoryAudit','enum CounterpartCategoryAudit'))
 (W/'main.swift').write_text('import Foundation\n@main enum CombinedAudit { static func main()throws {try IndependentLocalEndingAudit.main();try CounterpartCategoryAudit.main()} }\n')
 extras=[str(W/'categories.swift'),str(W/'main.swift')]
(W/'audit.swift').write_text(s)
env=os.environ.copy();env.setdefault('DEVELOPER_DIR','/Applications/Xcode.app/Contents/Developer')
with (W/'build.log').open('w') as f:
 subprocess.run(['xcrun','swiftc','-parse-as-library','-O','-module-cache-path',str(ROOT/'.build/ModuleCache'),*map(str,sources),str(D/'original-controls.swift'),str(W/'audit.swift'),*extras,'-o',str(W/'audit')],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
with (W/'run.log').open('w') as f:r=subprocess.run([str(W/'audit'),str(W/'category-results.json')],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT)
print(f'Exit {r.returncode}; evidence: {W}')
if (W/'results.json').exists():
 data=json.loads((W/'results.json').read_text());print(f"{len(data['tests'])} independent checks, {data['failures']} failures")
if (W/'category-results.json').exists():
 data=json.loads((W/'category-results.json').read_text());print(f"{len(data)} category checks, {sum(not x['passed'] for x in data)} failures")
sys.exit(r.returncode)
