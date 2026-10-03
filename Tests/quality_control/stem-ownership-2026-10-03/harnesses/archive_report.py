from pathlib import Path
import shutil,difflib,json,hashlib
r=Path('.build/stem-ownership-2026-10-03');d=Path('Tests/quality_control/stem-ownership-2026-10-03')
(d/'evidence').mkdir(exist_ok=True);(d/'harnesses').mkdir(exist_ok=True);(d/'candidates').mkdir(exist_ok=True)
for f in (r/'diagnostics').glob('*.png'):shutil.copy2(f,d/'evidence'/f.name)
for f in (r/'diagnostics/sources').glob('*.png'):shutil.copy2(f,d/'evidence'/('source-'+f.name))
for f in ['p26-witness-source-detail.png','p26-poppler-context.png']:
 shutil.copy2(r/f,d/'evidence'/f)
for name in ['actual.swift','diagnose297.swift','diagnoseBroken.swift','witness26.swift','build.sh','build-actual.sh','compare-actual.py','make_witness.py','make_witness_v2.py','make_unified_diagnostic.py']:
 shutil.copy2(r/name,d/'harnesses'/name)
for name in ['broken-baseline.json','broken-baseline.page.json','broken-witness.json','broken-witness.page.json','witness26.log','unified-geometry-v1-classification-stages.json','unified-geometry-diagnostic.log']:
 shutil.copy2(r/name,d/name)
base=(r/'baseline/Core/Detection/NativeScorePageAnalyzer.swift').read_text().splitlines(keepends=True)
for name in ['unified-geometry-v1','source-witness-v1','source-witness-v2','source-witness-v3']:
 p=r/(name+'.swift')
 if p.exists():
  (d/'candidates'/(name+'.patch')).write_text(''.join(difflib.unified_diff(base,p.read_text().splitlines(keepends=True),fromfile='baseline/NativeScorePageAnalyzer.swift',tofile=name+'/NativeScorePageAnalyzer.swift')))
 for suffix in ['297.json','336.json','297-comparison.json','336-comparison.json','actual-comparison.json']:
  p=r/(name+'-'+suffix)
  if p.exists():shutil.copy2(p,d/p.name)
print('Archived',len(list(d.rglob('*'))),'entries')
