from pathlib import Path
import hashlib, json, shutil, zipfile

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
work = root / '.build/divisi-assignment-release-v2-2026-10-03'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
inputs = json.loads((work / 'source-hashes.json').read_text())
previous = json.loads((root / 'Tests/quality_control/matcher-connection-release-2026-10-03/source-hashes.json').read_text())
for name, digest in inputs.items():
    assert sha(root / name) == sha(work / name) == digest, name
assert inputs['Partsmith/Core/Detection/NativeScorePageAnalyzer.swift'] == '9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01'
independent = root / 'Tests/quality_control/system-staff-count-independent-2026-10-03'
audit = json.loads((independent / 'package-final-audit.json').read_text())
assert audit['passed']
results = json.loads((independent / 'after-fix/results.json').read_text())
assert results['checks'] == 49 and results['failures'] == 0
legacy = json.loads((work / 'challenges/results-assessment.json').read_text())
assert legacy['total'] == 32 and legacy['passed'] == 31
assert [x['id'] for x in legacy['rows'] if not x['passed']] == ['notte-changed-profile-count']
shutil.copy2(work / 'source-hashes.json', out / 'source-hashes.json')
shutil.copy2(independent / 'package-final-audit.json', out / 'independent-package-audit.json')
for name in ['protocol-before-results.json', 'results.json', 'results-assessment.json', 'prior-release-comparison.json', 'run.log', 'build.log']:
    target = out / 'historical-challenges' / name
    target.parent.mkdir(exist_ok=True)
    shutil.copy2(work / 'challenges' / name, target)
for name in ['divisi-planner-v2-tests-2026-10-03.log', 'divisi-batch-v2-tests-2026-10-03.log']:
    shutil.copy2(root / '.build' / name, out / name)
with zipfile.ZipFile(out / 'build-log.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    z.write(work / 'build.log', 'build.log')
record = {
    'status': 'verified-private-package-not-yet-published',
    'change': 'Per-system staff counts for divided sections, with exact grouping in reused layouts and physical source-order validation.',
    'packageSHA256': sha(work / 'Partsmith-extraction-preview-macos.zip'),
    'executableSHA256': sha(work / 'DerivedData/Build/Products/Release/Partsmith.app/Contents/MacOS/Partsmith'),
    'changedApplicationFiles': [n for n in inputs if inputs[n] != previous[n]],
    'validation': {'plannerChecks': 111, 'batchChecks': 46, 'independentChecks': 49, 'uiStateChecks': 18,
                   'historicalMatcherCases': 32, 'historicalExpectationsSatisfied': 31,
                   'intentionalExpectationChange': 'A reviewed two-staff piano layout remains valid when the global default is three.',
                   'assignmentOutcomesUnchanged': 31, 'entireSerializedResultsUnchanged': 30,
                   'otherDifference': 'One still-rejected incomplete Mendelssohn subgroup has a more specific diagnostic.'},
    'independentEvidence': {str(p.relative_to(root)): sha(p) for p in [independent / 'manifest.json',
        root / 'Tests/quality_control/divisi-ui-independent-2026-10-03/manifest.json']},
    'limits': ['Reviewed grouping does not identify unseen instruments or infer bar counts.',
               'The original numeric-ID validation failures remain in the independent evidence.',
               'UI state tests do not claim live window interaction.',
               'Production crop detection is unchanged; ownership experiments stay private.'],
    'runningAppOrUserDocumentModified': False
}
assert record['packageSHA256'] == 'db824e17bcb11f909110273a8dba68f4fd1693bf7f517b72a182fdad3ac2eba0'
(out / 'release.json').write_text(json.dumps(record, indent=2) + '\n')
(out / 'manifest.json').write_text(json.dumps({str(p.relative_to(out)): {'sha256': sha(p), 'bytes': p.stat().st_size}
    for p in sorted(out.rglob('*')) if p.is_file() and p.name != 'manifest.json'}, indent=2) + '\n')
print('Assembled verified private release evidence; no publication performed.')
