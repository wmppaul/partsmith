from pathlib import Path
import hashlib,json,shutil,os
r=Path('.build/instrument-pick-flow-release-2026-10-04');q=Path('Tests/quality_control/instrument-pick-flow-release-2026-10-04');peer=Path('Tests/quality_control/instrument-pick-flow-2026-10-04');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();put=lambda p,d:p.write_text(json.dumps(d,indent=2)+'\n')
a=json.loads((r/'private-package-audit.json').read_text());roster=json.loads((r/'source-hashes.json').read_text());assert a['status']=='pass'
assert all(sha(p)==h==sha(r/p) for p,h in roster.items())
for p,h in json.loads((peer/'manifest.json').read_text())['files'].items():assert sha(peer/p)==h
sources=json.loads((peer/'source-hashes.json').read_text())
for p,h in sources.items():assert sha(p)==h
assert {p for p in sources if p.startswith('Partsmith/')}=={p for p in roster if p.endswith('.swift') and p!='Partsmith/App/PartsmithApp.swift'}
assert json.loads((peer/'results.json').read_text())['count']==30
public=Path('artifacts/macos/Partsmith-extraction-preview-macos.zip');private=r/'Partsmith-extraction-preview-macos.zip';assert sha(public)==a['priorPublicZIPSHA256'];assert sha(private)==a['privateArchiveSHA256']
shutil.copyfile(public,r/'previous-public-package.zip');pending=public.with_name('.pending-instrument-pick-flow.zip');shutil.copyfile(private,pending);assert sha(pending)==a['privateArchiveSHA256'];os.replace(pending,public);assert sha(public)==a['privateArchiveSHA256']
put(q/'publication.json',{'status':'Published local app package after focused native interaction and release checks','publicPath':str(public),'publicSHA256':sha(public),'priorPublicSHA256':a['priorPublicZIPSHA256'],'peerManifestSHA256':sha(peer/'manifest.json'),'peerEvidenceFilesVerified':10,'peerCompiledProductionSourcesVerified':34,'compiledAppSourcesPerArchitecture':35,'sourceInputsVerified':45,'rootVisualReview':['setup-empty-narrow.png','setup-populated.png','source-selecting-narrow.png','source-selecting.png'],'visualLimits':'Offscreen native screenshots omit prominent button fills; reviewed geometry and wording, not active-window contrast. Native harness verifies correct focus requests, not OS activation.','runningAppActions':'none'})
(q/'README.md').write_text('''# Guided instrument-name selection release

The direct **Select Instrument Names on Score** button explains the first setup step. A persistent source-side bar shows the selected names, count and reading status without covering the PDF. **Done — Back to Auto Extract** targets this document’s existing setup window and retains the list. An in-flight read disables completion; the existing setup consumes recognition results directly from the published event. Existing lists support adding names and a secondary replacement action. Editor clipping contains highlights within the scrolling score.

Only four UI source files changed. Detection, document data and layout Core remain byte-identical to the preceding released snapshot. The independent [native interaction review](../instrument-pick-flow-2026-10-04/README.md) passes 30 focused checks using the actual SwiftUI controls and numbered Brahms labels. It covers final-pick retention, zero-pick return, pending recognition, two-document ownership and source-close cleanup. Root verified every peer evidence/source hash and inspected the narrow setup, populated list and both final source-bar captures. The harness records actual focus requests without activating the process; screenshots omit inactive prominent-button fills. These limitations are explicit and do not constitute a live user-app walkthrough.

The Release build compiles all 35 app Swift files for Apple Silicon and Intel with macOS14 minimum. The packaged app is ad hoc signed, and its signature validates before and after ZIP extraction. Every extracted file, permission and byte matches the built bundle. All45 source inputs match the frozen snapshot. The52-member build archive preserves those inputs and build/package evidence; `private-package-audit.json` records the checks. `publication.json` binds the replaced local download to the reviewed build. The running app and user documents were not reopened or replaced.
''')
put(q/'manifest.json',{'files':{p.relative_to(q).as_posix():sha(p) for p in sorted(q.rglob('*')) if p.is_file() and p.name!='manifest.json'}})
print('Published',sha(public))
