from pathlib import Path
import json,hashlib,shutil,gzip,zipfile,difflib
r=Path('.build/source-body-provenance-v2-2026-10-03');out=Path('Tests/quality_control/source-body-provenance-v2-2026-10-03')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
for d in ['logs','results','reproduction','development-review']:(out/d).mkdir(parents=True,exist_ok=True)
for name in ['frozen-inputs.json','design-before-new-holdouts.md','candidate-freeze-before-results.json','comparison180.json','comparison36.json','comparison297.json','comparison336.json','native12-comparison.json','plan-comparison.json','development22-results.json','development-local4-results.json','v1-gate-summary.json','v2-diagnostics.json']:
 shutil.copy2(r/name,out/name)
for p in r.glob('*.log'):shutil.copy2(p,out/'logs'/p.name)
for name in ['results180.json','results36.json','results297.json','results336.json','v1-gate-traces.json','replayed-plans.json','baseline-timed180.json','baseline-timed36.json']:
 (out/'results'/(name+'.gz')).write_bytes(gzip.compress((r/name).read_bytes(),mtime=0))
for name in ['replay-output','baseline-replay-output']:
 (out/'results'/(name+'.json.gz')).write_bytes(gzip.compress((r/name/'witnesses.json').read_bytes(),mtime=0))
for name in ['endpoint-helper.swift','render-development.py','diagnose-v1-gates.swift','v2-diagnostic-probe.swift','development-diagnostic-inputs.json','archive-study.py']:
 shutil.copy2(r/name,out/'reproduction'/name)
for p in (r/'development-review').iterdir():shutil.copy2(p,out/'development-review'/p.name)
old=(r/'baseline/Core/Detection/NativeScorePageAnalyzer.swift').read_text().splitlines(keepends=True)
new=(r/'candidate-v2/Core/Detection/NativeScorePageAnalyzer.swift').read_text().splitlines(keepends=True)
(out/'candidate-v2.patch').write_text(''.join(difflib.unified_diff(old,new,fromfile='baseline/Core/Detection/NativeScorePageAnalyzer.swift',tofile='candidate-v2/Core/Detection/NativeScorePageAnalyzer.swift')))
with zipfile.ZipFile(out/'frozen-core.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for directory in ['baseline/Core','candidate-v2/Core']:
  for p in sorted((r/directory).rglob('*.swift')):z.write(p,str(p.relative_to(r)))
for name in ['v1-diagnostic','v2-diagnostic']:
 p=r/name/'Core/Detection/NativeScorePageAnalyzer.swift';(out/'results'/(name+'-NativeScorePageAnalyzer.swift.gz')).write_bytes(gzip.compress(p.read_bytes(),mtime=0))
harnesses={
 'build.sh':'.build/stem-ownership-2026-10-03/build.sh',
 'controls765.swift':'tools/test_crop_quality.swift',
 'controls297.swift':'Tests/quality_control/stem-ownership-2026-10-03/controls297.swift',
 'expanded336.swift':'Tests/quality_control/stem-ownership-2026-10-03/expanded336.swift',
 'controls180.swift':'Tests/quality_control/terminal-body-independent-2026-10-03/controls.swift',
 'tied36.swift':'Tests/quality_control/terminal-body-independent-2026-10-03/tied-controls.swift',
 'helper-probe.swift':'Tests/quality_control/notehead-provenance-independent-2026-10-03/helper-probe.swift',
 'replay.swift':'Tests/quality_control/notehead-provenance-2026-10-03/reproduction/replay.swift',
 'replay-plans.swift':'Tests/quality_control/notehead-provenance-2026-10-03/reproduction/replay-plans.swift',
}
for dst,src in harnesses.items():shutil.copy2(src,out/'reproduction'/dst)
paths=[
 'Tests/quality_control/notehead-provenance-independent-2026-10-03/holdouts.json',
 'Tests/quality_control/notehead-provenance-independent-2026-10-03/helper-inputs.json',
 'Tests/quality_control/notehead-provenance-independent-2026-10-03/local-line-helper-inputs.json',
 'Tests/quality_control/notehead-provenance-independent-2026-10-03/local-line-source-measurements.json',
 'Tests/quality_control/notehead-provenance-independent-2026-10-03/hashes.json',
 'Tests/quality_control/terminal-body-independent-2026-10-03/frozen-protocol.json',
 'Tests/quality_control/terminal-body-independent-2026-10-03/tied-frozen-protocol.json',
 'Tests/quality_control/terminal-body-independent-2026-10-03/baseline-results.json',
 'Tests/quality_control/terminal-body-independent-2026-10-03/tied-baseline-results.json',
 'Tests/quality_control/terminal-body-independent-2026-10-03/compare.py',
 '.build/ownership-alternatives-2026-10-03/results297.json',
 '.build/ownership-alternatives-2026-10-03/results336.json',
 '.build/terminal-body-continuation-2026-10-03/diagnostic-cases.json',
 'Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json']
paths += [str(r/name) for name in ['helper-probe','controls180','tied36','crop765','controls297','expanded336','replay','baseline-replay','replay-plans','v2-diagnostic-probe','diagnose-v1-gates']]
paths += ['.build/terminal-body-independent-2026-10-03/baseline/'+n for n in ['controls','tied-controls']]
inputs=json.loads(Path(paths[1]).read_text()); paths += list({c['imagePath'] for c in inputs['cases']})
refs={p:sha(p) for p in sorted(set(paths))}
(out/'external-evidence-bindings.json').write_text(json.dumps(refs,indent=2)+'\n')
baseline_names=['Detection/StaffBandDetector.swift','Detection/ScoreExtractionPlanner.swift','Detection/ScoreSharedEnding.swift','Detection/ScoreSharedEndingDetector.swift','Detection/ScoreLocalEndingPreservation.swift','Detection/NativeScorePageAnalyzer.swift']
runtime_source_match={n:sha(r/'baseline/Core'/n)==sha(Path('.build/terminal-body-independent-2026-10-03/baseline/Core')/n) for n in baseline_names}
assert all(runtime_source_match.values())
(out/'runtime-bindings.json').write_text(json.dumps({'singleRunsNotStatisticalBenchmark':True,'timedBaselineBinarySourcesMatchFrozenBaseline':runtime_source_match,'seconds':{'fixed180':{'baselineWall':1.14,'candidateWall':1.45,'baselineUser':1.09,'candidateUser':1.17},'tied36':{'baselineWall':.26,'candidateWall':.66,'baselineUser':.24,'candidateUser':.25},'native12':{'baselineWall':4.17,'candidateWall':4.20,'baselineUser':3.82,'candidateUser':3.87}},'performanceScope':'Small source-controlled runs with launch, raster rendering, PNG emission and concurrent compiler activity. No full-corpus performance claim.'},indent=2)+'\n')
print('Saved durable artifacts',sum(1 for p in out.rglob('*') if p.is_file()))
