from pathlib import Path
import json,hashlib,tarfile,shutil
w=Path('.build/brahms93521-reviewed-overlap-trim-2026-10-03');q=Path('Tests/quality_control/brahms-seven-trims-native-2026-10-04');q.mkdir(exist_ok=True);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();put=lambda p,d:p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
for n in ['proposed-edits-before-output.json','native-proof.json','output-comparison.json','root-review.json','source-hashes.json','proposed-context-index.json','trim.swift','freeze_edits.py','compare_outputs.py','verify_geometry.py','package_review.py']:
 shutil.copyfile(w/n,q/n)
rows=[];paths=[]
for folder in ['Core','output-review']:paths+=list((w/folder).rglob('*'))
paths+=list(w.glob('*-proposed-context.png'))
with tarfile.open(q/'native-review-evidence.tar.gz','w:gz') as t:
 for p in sorted(paths):
  if not p.is_file():continue
  name=p.relative_to(w).as_posix();t.add(p,arcname=name);rows.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p)})
 for tag,p in [('final-project.json',next((w/'parts').glob('*.partsmithproject'))/'project.json'),('final-manifest.json',w/'parts/manifest.json'),('parent-project.json',next(Path('output/pdf/auto-qc-2026-10-03/brahms-quartet-93521-viola-in-tempo-repair').glob('*.partsmithproject'))/'project.json')]:
  t.add(p,arcname=tag);rows.append({'path':tag,'bytes':p.stat().st_size,'sha256':sha(p)})
with tarfile.open(q/'native-review-evidence.tar.gz') as t:
 for x in rows:assert hashlib.sha256(t.extractfile(x['path']).read()).hexdigest()==x['sha256']
put(q/'archive-members.json',rows)
(q/'README.md').write_text('''# Brahms Quartet IMSLP93521 — seven manual crop trims

This assisted alternative tightens seven broad crops in the complete quartet while preserving all 604 source bands, 42 copied directions, nine saved page corrections and the earlier Viola “in tempo” repair. Native save/reopen/export produces the same 64-page total: Violin I 17, Violin II 16, Viola 16 and Cello 15. No detector code or app build changed for this draft.

Before editing, root viewed the original/corrected source systems and froze each proposed single-edge change with its source obligation. The unedited opposite edge and all other settings remain. Native project equality permits only those seven fractions and the modification date to change. Final source-copy shapes, source identities and reading order are preserved. All 604 output groups fit within their pages without overlap. Twenty-nine page renders are pixel-identical to the reviewed parent; all 35 changed layouts and all seven final crop details received independent visual review. Root separately viewed all seven final details.

Whole neighboring staff bodies are removed in these seven rows, but overlapping note, slur, lyric/direction and staff fragments remain. Unchanged crops elsewhere can still contain conspicuous fragments. Movement openings may occur near page bottoms or midpage, and active-phrase turns are not performance-certified. These are source-reviewed manual corrections, not an automatic algorithm result or clean re-engraving.

`proposed-edits-before-output.json` contains the exact seven changes. `native-proof.json`, `output-comparison.json` and `root-review.json` bind the native output and checks. `native-review-evidence.tar.gz` retains the frozen Core files, source proposal images, 35 changed page images, 14 before/after output details and project/manifest snapshots. `archive-members.json` binds every payload. The independent review and final delivery are bound in `publication.json`.

To reproduce, retain the immutable parent delivery named by the worker, copy the archived Core and supplied Swift worker into its declared private working path, compile against the local macOS SDK, and run the native worker with macOS graphics access. It refuses an existing `parts` output. Then run the comparison and geometry scripts. The successful native run used the existing production Core; a sandbox-only attempt stopped during PDF rectification and its incomplete output remains isolated outside the delivery.
''')
print('Archived',len(rows),'verified payloads;', (q/'native-review-evidence.tar.gz').stat().st_size,'bytes')
