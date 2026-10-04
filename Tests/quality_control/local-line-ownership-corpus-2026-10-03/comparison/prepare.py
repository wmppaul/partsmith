from pathlib import Path
import json,hashlib
ROOT=Path.cwd();W=ROOT/'.build/local-line-ownership-corpus-2026-10-03';R=W/'comparison';OLD=ROOT/'.build/monotone-corpus-independent-2026-10-03'
read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
prior=read(OLD/'baseline-binding.json');by={r['id']:r for r in prior['rows']};rows=[]
for inp in read(W/'inputs.json'):
 old=by[inp['id']]
 for k in ['source','sourceSHA256','profile','profileSHA256','pages']:assert inp[k]==old[k]
 assert inp['baseline']==old['replannedBaseline'] and inp['baselineSHA256']==old['replannedBaselineSHA256']
 for p,h in [('source','sourceSHA256'),('profile','profileSHA256'),('baseline','baselineSHA256')]:assert sha(inp[p])==inp[h]
 rows.append({**old,**inp})
base={**prior,'rows':rows,'candidateBuildBindingSHA256':sha(W/'build-binding.json'),'priorVerifiedBaselineBindingSHA256':sha(OLD/'baseline-binding.json')}
(R/'baseline-binding.json').write_text(json.dumps(base,indent=2)+'\n')
for n in ['compare.py','finish-comparison.py']:
 text=(OLD/n).read_text().replace('.build/monotone-corpus-independent-2026-10-03','.build/local-line-ownership-corpus-2026-10-03/comparison').replace('.build/monotone-line-corpus-2026-10-03','.build/local-line-ownership-corpus-2026-10-03')
 (R/n).write_text(text)
protocol={'scope':'Read-only canonical comparison; original production9f8 baseline with planner772 versus unchanged V2 locally evidenced ownership. All36 sources,1477 physical pages, including all zero-plan variable scores. No native baseline rerun.','invariants':'Exact original source/profile/hash bindings, staff geometry and order, component geometry multiset, assignment identities and order, unresolved reasons. Record all deltas even if unexpected; source losses not waived because previous owners already failed.','ownership':'Every changed component owner set recorded by page and source bounds. Zero-plan and unassigned pages remain explicit; owner changes are not accepted from crop-only coverage.','crop':'Every changed edge and per-band foreign core relation, expansions and contractions separately. Foreign-core geometry is a diagnostic, not source musical ownership proof.','next':'Only after canonical full diff, source review of changed edges; no production promotion.','baselineBindingSHA256':sha(R/'baseline-binding.json'),'buildBindingSHA256':sha(W/'build-binding.json'),'comparisonScripts':{n:sha(R/n)for n in ['compare.py','finish-comparison.py']}}
(R/'protocol-before-comparison.json').write_text(json.dumps(protocol,indent=2)+'\n')
print(json.dumps({'sources':len(rows),'pages':sum(r['pages']for r in rows),'protocolSHA256':sha(R/'protocol-before-comparison.json')},indent=2))
