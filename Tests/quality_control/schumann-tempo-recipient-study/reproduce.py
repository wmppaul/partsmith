#!/usr/bin/env python3
"""Frozen study runner. Creates new scratch outputs; never edits production."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys
D=Path(__file__).resolve().parent
ROOT=D.parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('mode',choices=['verify','controls','overrides','full'],nargs='?',default='verify')
parser.add_argument('--out',type=Path,default=ROOT/'.build/schumann-tempo-recipient-reproduction')
parser.add_argument('--python',type=Path,default=ROOT/'.build/extraction-venv/bin/python')
a=parser.parse_args(); W=a.out.resolve()
if W==D or D in W.parents or W==ROOT/'.build/schumann-directions':
 raise SystemExit('Choose a new scratch directory, not the archive or original study.')
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def check(p,h):
 if not p.exists():raise SystemExit(f'Required artifact missing: {p}')
 if sha(p)!=h:raise SystemExit(f'Hash mismatch: {p}')
for name,h in json.loads((D/'archive-sha256.json').read_text()).items():check(D/name,h)
print('Durable archive hashes verified.',flush=True)
if a.mode=='verify':sys.exit(0)
W.mkdir(parents=True,exist_ok=True)
ENV=os.environ.copy();ENV.setdefault('DEVELOPER_DIR','/Applications/Xcode.app/Contents/Developer')
def run(args,log,expected=0):
 print('Running '+Path(str(args[0])).name+' → '+log,flush=True)
 with (W/log).open('w') as f:
  result=subprocess.run([str(x) for x in args],cwd=ROOT,env=ENV,stdout=f,stderr=subprocess.STDOUT)
 if result.returncode!=expected:raise SystemExit(f'Unexpected exit {result.returncode}; see {W/log}')
def compile(name,sources,extra=()):
 run(['xcrun','swiftc','-O','-module-cache-path',W/'ModuleCache',*extra,*sources,'-o',W/name],name+'-build.log')
 return W/name
common=[D/x for x in ['StaffBandDetector.swift','ScoreExtractionPlanner.swift','ScoreSharedHeadingDetector.swift','candidate-v3.swift']]
def override_audit():
 v3=compile('initial-overrides-v3',common+[D/'initial-override-controls.swift'],['-D','V3'])
 run([v3],'initial-override-v3.json',1)
 core=D/'production-override-audit-Core'
 prod=compile('initial-overrides-production',sorted(core.rglob('*.swift'))+[D/'initial-override-controls.swift'])
 run([prod],'initial-override-production.json',1)
 for name,count in [('v3',7),('production',5)]:
  data=json.loads((W/f'initial-override-{name}.json').read_text())
  if data['failedExpectedRequirements']!=count:raise SystemExit(f'{name}: negative audit changed; inspect failures, do not treat as a pass')
 print('Negative audit reproduced: V3 7 failed requirements; production 5. Two explicit-list controls pass in each.',flush=True)
if a.mode=='overrides':override_audit();sys.exit(0)
for name,source in [('heading-controls','heading-controls-v3.swift'),('independent-ink','independent-heading-controls-v3.swift'),('recipient-controls','recipient-controls.swift')]:
 binary=compile(name,common+[D/source]);run([binary],name+'.log')
override_audit()
if a.mode=='controls':sys.exit(0)
# Full native reproduction requires retained input inventories/source PDFs. Large
# output PDFs and old binaries are hash-bound but not needed for rebuilding.
external=json.loads((D/'external-artifacts.json').read_text())
for name,row in external.items():
 if row.get('requiredInput'):check(Path(name) if Path(name).is_absolute() else ROOT/name,row['sha256'])
shutil.copy2(ROOT/'.build/schumann-directions/inventory.json',W/'inventory.json')
for name in ['profile.json','holdout-inputs.json','frozen-obligations.json']:shutil.copy2(D/name,W/name)
original='.build/auto-qc/connector8-harmonic/corpus/lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922/parts/manifest.json'
def harness(name):
 text=(D/name).read_text().replace('.build/schumann-directions',str(W)).replace(original,str(D/'original-music-manifest.json'))
 p=W/name;p.write_text(text);return p
native=common+[D/'NativeScorePageAnalyzer.swift']
baseline=compile('baseline-probe',native+[harness('probe.swift')])
candidate=compile('candidate-probe',native+[harness('candidate-probe.swift')])
holdouts=compile('holdout-probe',native+[harness('holdout-probe-v3.swift')])
exporter=compile('export-score-plan',sorted((D/'export-Core').rglob('*.swift'))+[D/'export_score_plan.swift'])
verify=compile('verify-output',[harness('verify-output.swift')],['-parse-as-library'])
for variant,probe in [('baseline',baseline),('candidate-v3',candidate)]:
 folder=W/variant;folder.mkdir(exist_ok=True)
 run([probe,folder],variant+'-native.log')
 run([exporter,'--inventory',folder/'inventory.json','--profile',W/'profile.json','--title','Schumann Directions Candidate','--out',folder/'parts'],variant+'-export.log')
 run([a.python,harness('evaluate.py'),variant],variant+'-evaluation.log')
 run([verify,folder],variant+'-source-pixels.log')
run([holdouts],'holdouts.log')
run([a.python,harness('render-review.py'),'candidate-v3'],'render-review.log')
print(f'Full fresh evidence saved to {W}. Native OCR may vary by macOS; inspect numerical and visual differences. Strict expected result is 14/15 tempo regions and 0/15 song indices, not an all-pass claim.',flush=True)
