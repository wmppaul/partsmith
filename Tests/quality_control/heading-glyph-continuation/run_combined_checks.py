#!/usr/bin/env python3
"""Read-only Core validation with fresh outputs; never overwrites the frozen study."""
import argparse,json,os,subprocess,hashlib
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('core',type=Path)
parser.add_argument('output',type=Path)
parser.add_argument('--include-categories',action='store_true')
args=parser.parse_args()
root=Path(__file__).resolve().parents[3]
os.chdir(root)
core=args.core.resolve();out=args.output.resolve()
if out.exists():parser.error('Output already exists; choose a fresh directory to preserve earlier evidence')
out.mkdir(parents=True)
(out/'independent-results').mkdir()
env=dict(os.environ);env.setdefault('DEVELOPER_DIR','/Applications/Xcode.app/Contents/Developer')
lean=[core/'Detection'/f'{x}.swift' for x in ['StaffBandDetector','ScoreExtractionPlanner','ScoreSharedEnding','ScoreSharedEndingDetector','ScoreLocalEndingPreservation','ScoreSharedHeadingDetector']]
independent=root/'Tests/quality_control/heading-glyph-independent/controls.swift'
s=independent.read_text().replace('static let output=URL(fileURLWithPath:"Tests/quality_control/heading-glyph-independent")','static let output=URL(fileURLWithPath:'+json.dumps(str(out/'independent-results'))+')')
assert s!=independent.read_text()
(out/'independent.swift').write_text(s)
cases=[('glyph',lean,[root/'Tests/quality_control/heading-glyph-continuation/controls.swift']),('shared-headings',lean,[root/'tools/test_shared_headings.swift']),('initial-overrides',lean[:-1],[root/'tools/test_heading_overrides.swift']),('independent',lean,[out/'independent.swift'])]
if args.include_categories:
 sources=[p for folder in ['DocumentModel','Detection','Layout','Export'] for p in sorted((core/folder).glob('*.swift'))]
 cases.append(('heading-categories',sources,[root/'tools/test_local_ending_counterparts.swift',root/'tools/test_heading_categories.swift']))
results=[]
for name,sources,tests in cases:
 print('Building',name,flush=True)
 with (out/f'{name}-build.log').open('w') as log:
  subprocess.run(['xcrun','swiftc','-O','-module-cache-path',str(root/'.build/ModuleCache'),*map(str,sources+tests),'-o',str(out/name)],stdout=log,stderr=subprocess.STDOUT,check=True,env=env)
 with (out/f'{name}.log').open('w') as log:
  subprocess.run([str(out/name)],stdout=log,stderr=subprocess.STDOUT,check=True,env=env)
 results.append({'test':name,'passed':True,'binarySHA256':hashlib.sha256((out/name).read_bytes()).hexdigest()})
 print('Passed',name,flush=True)
report={'core':str(core),'coreHashes':{str(p.relative_to(core)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(core.rglob('*.swift'))},'tests':results}
(out/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
