from pathlib import Path
import json,hashlib,shutil,zipfile
S=Path('.build/system-staff-count-independent-2026-10-03');D=Path('Tests/quality_control/system-staff-count-independent-2026-10-03');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n in ['inputs-before-results.json','protocol-before-results.json','additional-controls-before-fix-results.json','three-staff-systems.png','package_audit.py','package_v2_audit.py','assemble.py']:
 shutil.copy2(S/n,D/n)
for phase in ['before-fix','after-fix']:
 (D/phase).mkdir(exist_ok=True)
 for n in ['tests.swift','run.sh','run.log','build.log','results.json']:
  shutil.copy2(S/phase/n,D/phase/n)
 if (S/phase/'inputs-before-results.json').exists():shutil.copy2(S/phase/'inputs-before-results.json',D/phase/'inputs-before-results.json')
for a,b in [('independent-package-audit.json','package-before-fix-audit.json'),('package-load-commands.txt','package-before-fix-load-commands.txt'),('independent-package-v2-audit.json','package-final-audit.json'),('package-v2-load-commands.txt','package-final-load-commands.txt')]:shutil.copy2(S/a,D/b)
before=json.loads((D/'before-fix/results.json').read_text());after=json.loads((D/'after-fix/results.json').read_text())
assert before['failures']==3 and after['failures']==0
# Assert exact original test code prefix, avoiding nondeterministic dictionary order in two printed labels.
old=(D/'before-fix/tests.swift').read_text().split('  try finish(dir)\n }')[0]
assert (D/'after-fix/tests.swift').read_text().startswith(old)
assert (D/'three-staff-systems.png').read_bytes()==(S/'after-fix/three-staff-systems.png').read_bytes()
records=[]
with zipfile.ZipFile(D/'source-evidence.zip','w',compression=zipfile.ZIP_DEFLATED,compresslevel=6)as z:
 files=[('before-fix-Core/'+str(p.relative_to(S/'Core')),p)for p in sorted((S/'Core').rglob('*.swift'))]
 files += [('after-fix-Core/Detection/ScoreExtractionPlanner.swift',S/'after-fix/Core/Detection/ScoreExtractionPlanner.swift')]
 files += [(p.name,p)for p in [S/'ScoreExtractionView.swift',S/'ScoreSystemTemplatePanel.swift']]
 for name,p in files:z.write(p,name);records.append({'entry':name,'sha256':sha(p),'bytes':p.stat().st_size})
with zipfile.ZipFile(D/'source-evidence.zip')as z:
 for r in records:assert hashlib.sha256(z.read(r['entry'])).hexdigest()==r['sha256']
(D/'archive-payloads.json').write_text(json.dumps(records,indent=2)+'\n')
# Every final Core file is either original byte-for-byte or the reviewed planner replacement.
for p in (S/'after-fix/Core').rglob('*.swift'):
 rel=p.relative_to(S/'after-fix/Core')
 expected=S/'Core'/rel if str(rel)!='Detection/ScoreExtractionPlanner.swift' else p
 assert p.read_bytes()==expected.read_bytes()
(D/'comparison.json').write_text(json.dumps({'before':{'checks':45,'passed':42,'failed':3},'after':{'checks':49,'passed':49,'failed':0},'original45TestCodePrefixPreserved':True,'originalFixtureUnchanged':True,'displayNote':'Swift dictionary order differs in two descriptive log labels; original test code and expectations are exact.','fixedPlannerSHA256':sha(S/'after-fix/Core/Detection/ScoreExtractionPlanner.swift'),'nativeUnchangedSHA256':sha(S/'after-fix/Core/Detection/NativeScorePageAnalyzer.swift'),'originalFailures':[r['name']for r in before['results']if not r['passed']],'scope':'Synthetic API/planner/matcher lifecycle validation. No corpus, app UI events or score output certification. Core source evidence reconstitutes final snapshot by replacing the one planner in the complete prior snapshot. Four-staff upper-bound check tests API validation, not a source-confirmed four-staff system.'},indent=2)+'\n')
print('semantic artifacts ready',len(records),'source payloads')
