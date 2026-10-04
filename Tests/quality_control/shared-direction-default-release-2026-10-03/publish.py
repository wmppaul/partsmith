from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,os,shutil,tempfile,zipfile,sys
root=Path(__file__).resolve().parents[3]; out=Path(__file__).resolve().parent
work=root/'.build/shared-direction-default-release-2026-10-03'; public=root/'artifacts/macos/Partsmith-extraction-preview-macos.zip'; package=work/public.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
workflow=Path(sys.argv[1]).resolve(); assert workflow.is_relative_to(root/'Tests/quality_control')
assert (workflow/'manifest.json').is_file()
audit=json.loads((out/'independent-package-audit.json').read_text()); assert audit['result']=='pass'
assert sha(package)==audit['package']['sha256']
inputs=json.loads((work/'source-hashes.json').read_text())
prior=json.loads((root/'Tests/quality_control/numbered-volta-release-2026-10-03/source-hashes.json').read_text())
for name,h in inputs.items(): assert sha(root/name)==sha(work/name)==h,name
assert set(inputs)==set(prior)
assert [n for n in inputs if prior[n]!=inputs[n]]==['Partsmith/Features/Project/ScoreExtractionView.swift']
assert inputs['Partsmith/Core/Detection/NativeScorePageAnalyzer.swift']=='9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01'
assert 'private var copyDirections = true' in (work/'Partsmith/Features/Project/ScoreExtractionView.swift').read_text()
assert '** BUILD SUCCEEDED **' in (work/'build.log').read_text()
rawBindings=[]
for directory in ['brahms93521-full-workflow-draft-2026-10-03','brahms93521-full-production-workflow-draft-2026-10-03']:
 p=root/'.build'/directory/'workflow-result.json'; rawBindings.append({'path':str(p.relative_to(root)),'sha256':sha(p)})
review=root/'Tests/quality_control/brahms93521-full-output-root-review-2026-10-03/review.json'
assert json.loads(review.read_text())['finalOutputPages']==64
with zipfile.ZipFile(package) as z:
 assert z.testzip() is None
 assert hashlib.sha256(z.read('Partsmith.app/Contents/MacOS/Partsmith')).hexdigest()==audit['executable']['sha256']
previous=sha(public);assert previous=='e57f392652eed0d051b3e47f95bf2633ee834683818405c9acadd913ed716f08'
backup=work/f'previous-public-{previous}.zip';shutil.copy2(public,backup);assert sha(backup)==previous
with tempfile.NamedTemporaryFile(dir=public.parent,prefix='.shared-direction-default-',suffix='.zip',delete=False) as f:
 replacement=Path(f.name);f.write(package.read_bytes());f.flush();os.fsync(f.fileno())
assert sha(replacement)==sha(package) and sha(public)==previous
os.chmod(replacement,0o644);os.replace(replacement,public);assert sha(public)==audit['package']['sha256']
shutil.copy2(work/'source-hashes.json',out/'source-hashes.json')
with zipfile.ZipFile(out/'build-log.zip','w',zipfile.ZIP_DEFLATED) as z:z.write(work/'build.log','build.log')
record={
 'publishedAtUTC':datetime.now(timezone.utc).isoformat(),
 'change':'Enable detected shared tempos, navigation and paired endings by default for new fixed-layout Auto setups; preserve existing saved preference. Includes previously shipped direct Preview crop controls.',
 'artifact':str(public.relative_to(root)),'artifactSHA256':sha(public),'artifactBytes':public.stat().st_size,'executableSHA256':audit['executable']['sha256'],
 'previousArtifactSHA256':previous,'previousArtifactBackup':str(backup.relative_to(root)),
 'architectures':['arm64','x86_64'],'minimumMacOS':'14.0','signing':'Strictly verified ad hoc signature; not notarized.',
 'existingPreferenceKeyUnchanged':'copySharedDirectionsInAuto','existingExplicitOptOutPreserved':True,'variableInstrumentLayoutsStillDisabled':True,
 'nativeCropDetectorUnchanged':True,'privateMonotoneCandidateIncluded':False,
 'validation':{'freshUniversalReleaseBuild':True,'independentBuiltAndExtractedPackageAudit':str((out/'independent-package-audit.json').relative_to(root)),
 'completeScoreSourcePages':39,'completeScoreParts':4,'completeScoreBands':604,'completeScoreOutputPagesPerRun':64,
 'independentActualWorkflows':2,'rawWorkflowBindings':rawBindings,
 'workflowEvidence':{'path':str(workflow.relative_to(root)),'manifestSHA256':sha(workflow/'manifest.json')},
 'privateFinalPageVisualReview':{'path':str(review.relative_to(root)),'sha256':sha(review)},
 'existingHeadingAndDirectionChecks':'87 heading and113 app-direction checks from previous release; every Core file is byte-identical. No new detector or direction algorithm is introduced.'},
 'knownLimitations':['Direction recognition remains experimental and cannot find every shared marking.','Rehearsal letters, bar numbers and unsupported endings still need source review.','Large neighboring fragments, duplicate source text and awkward page turns remain in the complete Brahms drafts.','This release does not promote the private crop candidate or certify all sample outputs.'],
 'runningAppOrUserDocumentModified':False,'publication':'Verified same-directory atomic ZIP replacement only.'}
(out/'release.json').write_text(json.dumps(record,indent=2)+'\n')
(out/'README.md').write_text('''# Shared directions enabled for new Auto setups\n\nNew fixed-layout setups enable copying of detected tempos, repeat navigation and supported paired endings. Existing saved choices are preserved, including an explicit off setting. Changing-instrument layouts still require reviewed direction copies. The direct Preview crop controls from the previous release remain included.\n\nThe complete 39-page Brahms93521 source was processed through the actual direction workflow twice, with frozen production and private crop plans separately. Both native sets contain604 bands across four parts and64 output pages. The independent production review checked56 direction recipients against the source; required glyphs were complete in that bounded set. Root inspected all64 private final pages for layout. These remain drafts: neighboring notation, duplicated context and difficult turns persist. The private crop algorithm is not included in the app.\n\nThe only application-source change from the preceding release is the existing saved preference's default value. All45 frozen build inputs were checked against the current tree; both architectures compile the exact35 Swift inputs. The ZIP matches the built app and both built/extracted apps pass strict ad-hoc signature checks, with macOS14 minimum. This is not a Developer ID or notarized release.\n\nThe public ZIP was replaced atomically after keeping the previous one. The running app and user documents were not modified. `release.json` binds the package, source snapshot, complete native workflow evidence and visual review.\n''')
(out/'manifest.json').write_text(json.dumps({p.name:sha(p) for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json'},indent=2)+'\n')
print(json.dumps({'published':str(public),'sha256':sha(public),'bytes':public.stat().st_size,'releaseReceipt':str(out/'release.json')},indent=2))
