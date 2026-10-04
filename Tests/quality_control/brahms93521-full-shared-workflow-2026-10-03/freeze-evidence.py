from pathlib import Path
import hashlib, json, tarfile, shutil, datetime

root = Path.cwd()
private = root / '.build/brahms93521-full-workflow-draft-2026-10-03'
production = root / '.build/brahms93521-full-production-workflow-draft-2026-10-03'
out = root / 'Tests/quality_control/brahms93521-full-shared-workflow-2026-10-03'
out.mkdir(parents=True, exist_ok=True)
sha = lambda data: hashlib.sha256(data).hexdigest()
def load(p): return json.loads(p.read_text())
def write(p, d): p.write_text(json.dumps(d, indent=2) + '\n')
def artifact(p): return {'path': str(p.relative_to(root)), 'sha256': sha(p.read_bytes()), 'bytes': p.stat().st_size}
def archive(name, files):
    dest = out / name
    records = []
    with tarfile.open(dest, 'w:xz', preset=6) as tar:
        for member, path in sorted(files.items()):
            assert path.is_file()
            tar.add(path, arcname=member, recursive=False)
            records.append({'member': member, **artifact(path)})
    with tarfile.open(dest, 'r:xz') as tar:
        assert sorted(tar.getnames()) == sorted(files)
        for record in records:
            data = tar.extractfile(record['member']).read()
            assert sha(data) == record['sha256'] and len(data) == record['bytes']
    return {**artifact(dest), 'allDecompressedMembersVerified': True, 'members': records}

source = root / 'sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf'
source_sha = '662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a'
assert sha(source.read_bytes()) == source_sha
core_hashes = load(private / 'core-hashes.json')
for name, expected in core_hashes.items():
    assert sha((private / name).read_bytes()) == expected
    assert sha((root / 'Partsmith' / name).read_bytes()) == expected

files = {}
for name in ['replay.swift', 'export_score_plan.swift', 'validate.py', 'core-hashes.json', 'build.log', 'independent-harness-audit.json']:
    files['common/' + name] = private / name
for name in core_hashes:
    files['common/' + name] = private / name
files['common/frozen-raster-bindings.json'] = root / '.build/brahms-source-span-full-replay-2026-10-03/inputs.json'
files['common/make-direction-review.py'] = production / 'make-direction-review.py'
runs = {}
for label, work, folder in [('private95', private, 'private-crop-draft-parts'), ('production9f8', production, 'production-crop-draft-parts')]:
    partdir = work / folder
    inv = load(work / 'inventory-input.json')
    rec = load(work / 'recognized-inventory.json')
    report = load(work / 'workflow-result.json')
    manifest = load(partdir / 'manifest.json')
    validation = load(work / 'output-validation.json')
    projectproof = load(work / 'project-identity-proof.json')
    project = partdir / manifest['project']
    assert len(inv['pages']) == len(rec['pages']) == len(report['pages']) == 39
    assert inv['rectifications'] == rec['rectifications']
    assert report['sourceSHA256'] == inv['sourceSHA256'] == source_sha
    assert report['inputSHA256'] == sha((work / 'inventory-input.json').read_bytes())
    assert report['profileSHA256'] == sha((work / 'profile.json').read_bytes())
    assert not report['issues'] and all(not p['issues'] for p in report['pages'])
    assert validation['editableProjectPageCount'] == projectproof['decodedPageCount'] == 39
    assert validation['editableProjectBands'] == projectproof['decodedBandCount'] == 604
    assert len(validation['cropIdentities']) == len(set(validation['cropIdentities'])) == 604
    assert projectproof['allCropIdentitiesMappedExactlyOnce'] and projectproof['allMainCropFractionsAndSourceMarkingArraysExact']
    assert sha((project / 'source.pdf').read_bytes()) == source_sha
    for name in ['inventory-input.json', 'recognized-inventory.json', 'workflow-result.json', 'profile.json', 'saved-rectifications.json', 'protocol-before-results.json', 'native-run.log', 'export.log', 'output-validation.json', 'project-identity-proof.json', 'decoded-pdf-proof.json']:
        files[label + '/' + name] = work / name
    if (work / 'export-sandbox.log').exists(): files[label + '/export-sandbox.log'] = work / 'export-sandbox.log'
    for name in ['manifest.json', 'plan.json']: files[label + '/export/' + name] = partdir / name
    files[label + '/export/project.json'] = project / 'project.json'
    pdfs = []
    for part in manifest['parts']:
        path = partdir / part['file']
        assert sha(path.read_bytes()) == part['sha256']
        pdfs.append({**artifact(path), 'part': part['name'], 'pages': part['outputPages'], 'bands': part['bandCount'], 'systemsPerPage': part['systemsPerPage']})
    runs[label] = {
        'input': artifact(work / 'inventory-input.json'), 'actualWorkflowResult': artifact(work / 'workflow-result.json'),
        'actualRecognizedInventory': artifact(work / 'recognized-inventory.json'), 'elapsedSeconds': report['elapsedSeconds'],
        'sourcePages': 39, 'eligibleMusicPages': 38, 'autoSkippedPhysicalPages': [p+1 for p in report['autoSkippedPageIndices']],
        'directionIssues': report['issues'], 'headings': sum(len(p['headings']) for p in report['pages']),
        'navigationRecordsIncludingDestination': sum(len(p['navigation']) for p in report['pages']),
        'endingPairs': len(set(i for p in report['pages'] for i in p['endingPairIDs'])),
        'outputBands': validation['outputBands'], 'sourceCopies': validation['sourceCopies'],
        'cropChangesForSourceDirections': validation['cropChangesForSourceDirections'], 'allChangedCropsExpandOnly': validation['allChangedCropsExpandOnly'],
        'pdfs': pdfs, 'outputPages': sum(p['pages'] for p in pdfs), 'outputManifest': artifact(partdir / 'manifest.json'),
        'editableProjectJSON': artifact(project / 'project.json'), 'editableOriginalSource': artifact(project / 'source.pdf'),
        'correctedReviewSource': artifact(partdir / 'rectified-review-source.pdf'),
        'decodedProjectPageCount': projectproof['decodedPageCount'], 'all604ProjectBandsMappedToCropIDs': True,
        'decodedProjectCropFractionsMarkingsPartNamesAndOrderExact': True, 'decodedProjectSavedCorrectionsExact': projectproof['rectificationsExact'],
        'actualDecodedPDFProof': load(work / 'decoded-pdf-proof.json')}

pr = load(private / 'recognized-inventory.json'); sr = load(production / 'recognized-inventory.json')
assert pr['rectifications'] == sr['rectifications']
direction_fields = ['sharedHeadings', 'sharedNavigation', 'sharedEndings']
assert all(all(a.get(k) == b.get(k) for k in direction_fields) for a,b in zip(pr['pages'],sr['pages']))

notes = {
 (2,1): ('Vivace.', 'Complete once in each recipient. First violin retains a clipped printed composer/header fragment in its existing upper crop; neighboring notation remains in lower parts.'),
 (6,3): ('First ending', 'Complete 1. and bracket/hook at the far-right bar in all parts. The copied region also retains the first staff\'s nearby isolated printed rest-count numeral, which appears in addition to lower parts\' own numeral.'),
 (6,4): ('Second ending', 'Complete 2. and bracket/hook at the first bar in all parts. Small adjacent note/stem fragments are included below the copy. Existing upper/lower neighboring music remains.'),
 (16,1): ('Andante.', 'Complete heading once in every part. Existing neighboring notes, slurs, dynamics and printed page/footer fragments remain.'),
 (22,1): ('Agitato. (Allegretto non troppo.)', 'Complete heading including both parentheses and period in every part. Lower-part copies include visibly clipped adjacent con Sord. and other musical fragments below the heading; this is not clean engraving.'),
 (26,2): ('Return destination sign', 'Complete circular/cross destination at the matching source bar in all parts. Copies retain a short horizontal source staff/bar fragment beneath the sign. Corresponding inline sign is retained in the p28 return sentence.'),
 (26,3): ('Trio.', 'Complete heading once in every part. Lower-part copies also include a clipped first-violin beam fragment immediately beneath the heading.'),
 (28,2): ('Da Capo return sentence', 'Complete printed return sentence, inline destination sign and Coda word in all parts, placed below the system at the right-hand source position. No clipped or doubled return sentence observed.'),
 (28,3): ('Coda.', 'Complete heading once in every part. A small underline/staff fragment is retained beneath a copied heading; substantial neighboring low notes/slurs remain in main crops.'),
 (29,1): ('Poco Allegretto con Variazioni.', 'Complete full phrase and period once in each part. Existing first-violin printed page number remains in its crop; neighboring notes/dynamics are present in lower-part margins.'),
 (32,4): ('Paired first/second endings', 'Both complete labels and bracket hooks align with their respective repeat bars in all parts. Copied rectangles retain first-violin slur crowns and partial high noteheads beneath brackets; these fragments remain visibly separate clutter.'),
 (34,3): ('Doppio Movimento.', 'Complete phrase once in every part. Original and saved-corrected source were compared; notes/high slurs/ledger notes and accents visible in the system contexts remain. General neighboring crop fragments persist.'),
 (36,1): ('Paired first/second endings', 'Complete 1./2. and all bracket hooks in all parts. Copied source region also carries first-violin flag/stem/head fragments beneath the first bracket, plus small adjacent dots.'),
 (37,2): ('Paired first/second endings', 'Both labels and bracket hooks complete and at the correct repeat-choice bars in all parts. Neighboring notes, dol. duplicates from adjacent staves and slur fragments remain in main crops.')}
index = load(production / 'direction-review/index.json')
assert len(index) == len(notes) == 14
visual_rows = []
visual_files = {'index.json': production / 'direction-review/index.json', 'make-direction-review.py': production / 'make-direction-review.py'}
for record in index:
    key = (record['sourcePage'], record['system']); label, note = notes[key]
    comparison = root / record['comparison']
    assert sha(comparison.read_bytes()) == record['comparisonSHA256']
    visual_files[comparison.name] = comparison
    outputs = [e for e in record['entries'] if e['kind'] == 'output']; assert len(outputs) == 4
    for entry in record['entries']: assert sha((root / entry['path']).read_bytes()) == entry['sha256']
    visual_rows.append({'sourcePage': key[0], 'system': key[1], 'direction': label, 'actualSourceAndCorrectedContextCompared': True,
        'comparisonFile': comparison.name, 'comparisonSHA256': record['comparisonSHA256'], 'observation': note,
        'recipients': [{'partID': e['partID'], 'outputPage': e['outputPage'], 'renderSHA256': e['sha256'],
            'requiredDirectionGlyphsAndHooksComplete': True, 'horizontalMusicalPositionMatchesSource': True,
            'missingOrClippedRequiredDirectionObserved': False, 'secondCompleteCopyOfSameSharedDirectionObserved': False} for e in outputs]})
visual = {'scope': 'Bounded visual comparison of all recognized shared-direction recipients in the actual production9f8 PDF outputs, against immutable original and saved-corrected source. Not an all-page or all-note preservation certification.',
 'source': artifact(source), 'systemContexts': 14, 'recipientStrips': 56, 'all56RecipientsInspected': True,
 'result': 'All recognized shared directions complete; copied neighboring fragments and crowded original crops remain.',
 'defaultEnabledAssessment': 'Supports enabling this experimental copy option for source preservation on this exact score. Does not certify recognition recall on all scores, clean parts, good page turns or private crop promotion.',
 'limitations': ['Coverage is of detected headings/navigation/endings; it is not an exhaustive search for every unrecognized score instruction.',
   'OCR text in the actual JSON can be misspelled. Exported source glyphs, not OCR transcriptions, were reviewed.',
   'Source context clips do not establish preservation of every remote low dynamic or all notes outside the reviewed systems.',
   'Output clips extend 12 PDF points beyond the placement union and may include a portion of an adjacent output system; those pixels alone are not evidence of overprint.',
   'Comparison PNGs archive the exact viewed composite of original source, corrected source and four output strips. Individual render hashes/clip coordinates remain in index.json; their duplicate PNG files are not archived.'],
 'systems': visual_rows}
write(out / 'production-direction-visual-review.json', visual)
shutil.copyfile(private / 'independent-harness-audit.json', out / 'independent-harness-audit.json')

replay_archive = archive('replay-evidence.tar.xz', files)
visual_archive = archive('production-direction-views.tar.xz', visual_files)
write(out / 'replay-archive-manifest.json', replay_archive)
write(out / 'visual-archive-manifest.json', visual_archive)
root_review = root / 'Tests/quality_control/brahms93521-full-output-root-review-2026-10-03/review.json'
summary = {'recordedAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'scope': 'Two independent complete39-page native shared-direction workflows using immutable frozen crop analyses and identical saved correction metadata, followed by actual full native four-part exports. No staff detection, new transforms or crop promotion.',
 'source': artifact(source), 'productionNativeSHA256': core_hashes['Core/Detection/NativeScorePageAnalyzer.swift'],
 'privateInputAlgorithmSHA256': '95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0',
 'frozenCoreFilesAll25EqualCurrent': len(core_hashes) == 25,
 'sharedCompiledHarness': artifact(private / 'replay'), 'savedCorrectedPhysicalPages': [2,7,17,19,23,28,34,38,39],
 'bothRunDirectionsExactlyEqualOnAll39Pages': True, 'bothSavedCorrectionsExact': True,
 'noOriginalSourceStaffOrComponentEvidenceChangedByDirectionRecognition': True,
 'runs': runs, 'productionVisualReview': artifact(out / 'production-direction-visual-review.json'),
 'private64PageRootReview': artifact(root_review), 'independentHarnessAudit': artifact(out / 'independent-harness-audit.json'),
 'replayArchive': artifact(out / 'replay-evidence.tar.xz'), 'visualArchive': artifact(out / 'production-direction-views.tar.xz'),
 'result': 'Complete draft outputs and editable projects generated. Recognized source directions preserved in the bounded production recipient review. Private crop candidate remains unpromoted; significant neighboring fragments and page-turn defects remain.',
 'executionNotes': ['The private export sandbox attempt failed at saved rectification page2 and did not produce the final set. The preserved sandbox log is followed by the successful native-permission export log.',
   'No stage was retried as a per-page corpus run. Each recognition workflow received all39 analyses together, allowing cross-page ending and navigation relationships.',
   'The quiet successful compilation produced an empty build.log; the exact frozen Core/helper sources and compiled executable hash are recorded. The run logs contain actual native progress and completion.',
   'The original full PDF and eight output PDFs are hash-linked rather than duplicated into this compact replay archive. The actual decoded editable project JSON, all604 identity mappings and full workflow input/results are archived.']}
write(out / 'review.json', summary)
readme = '''# Complete Brahms93521 shared-direction replay

Both frozen corrected inputs were processed through the current native shared-direction workflow independently: production9f8 and private95. Each run uses all39 source pages together, exact saved corrections on physical pages2/7/17/19/23/28/34/38/39, and the fixed quartet profile. Staff detection and correction estimation were not rerun.

Each export contains 604 source bands (151 systems per part) across four parts:17/16/16/15 pages (64 total), plus an editable project with the original39-page PDF. Actual decoded project identities, crop fractions, source copies, part names, ordering and corrections are validated in each archived project-identity-proof.json. Seven headings, one return sentence, one linked destination and four ending pairs were recognized without runtime issues. Both independent runs returned identical direction metadata. Direction handling expands only the p28s2 Cello main crop; it does not contract a source crop.

All56 production direction-recipient strips were visually compared with original and saved-corrected source. Required text/signs/bracket hooks remain complete at the correct musical positions. Copies sometimes include clipped adjacent notation (con Sord., beam, notehead, flag or slur fragments). Existing main crops remain cluttered. Root's linked review of all64 private pages also records whole neighbors and poor repeat page turns. These are complete drafts, not polished outputs or approval to promote the private crop algorithm.

`replay-evidence.tar.xz` contains the exact25 Core sources, harness/export helper, actual full input and recognized JSON, actual workflow reports, per-page issues/OCR strings, manifests/plans/project JSON, all604 project identity mappings, profile/corrections/protocols and actual logs. `replay-archive-manifest.json` binds every decompressed member; all members were read back and verified. Full PDFs are hash-linked, not duplicated. The successful compiler log is empty because compilation was quiet; this is not a fabricated build transcript.

`production-direction-views.tar.xz` contains all14 exact viewed source/output comparison sheets, their detailed index and generator. The per-system/per-recipient visual verdict is separate from automated geometry checks. Root's full private-page review is linked without copying its large image archive.

For replay, rebuild the single executable from common/Core Swift files plus common/replay.swift and common/export_score_plan.swift using Swift and AppKit/PDFKit/Vision/CoreImage/CryptoKit. Pass the extracted run directory containing inventory-input.json and profile.json as the first argument; source paths refer to the hash-bound repository PDF. Export dispatch is `replay export --inventory <recognized-inventory.json> --profile <profile.json> --out <new-directory> --title 'Brahms — String Quartet No.3, Op.67'`. These are replay instructions, not an additional execution claim. Native macOS image/Vision permissions are needed. Do not overwrite the frozen evidence or existing draft folders during a replay.
'''
(out / 'README.md').write_text(readme)
shutil.copyfile(Path(__file__), out / 'freeze-evidence.py')
write(out / 'manifest.json', {'files': [artifact(p) for p in sorted(out.iterdir()) if p.is_file() and p.name != 'manifest.json'], 'sourcePDF': artifact(source)})
print(json.dumps({'directory': str(out.relative_to(root)), 'reviewSHA256': sha((out/'review.json').read_bytes()), 'manifestSHA256': sha((out/'manifest.json').read_bytes()), 'replayArchiveBytes': (out/'replay-evidence.tar.xz').stat().st_size, 'visualArchiveBytes': (out/'production-direction-views.tar.xz').stat().st_size}, indent=2))
