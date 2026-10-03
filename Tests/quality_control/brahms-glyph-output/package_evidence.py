from pathlib import Path
import json,hashlib,shutil,zipfile
R=Path.cwd(); report=R/'Tests/quality_control/brahms-glyph-output'; build=R/'.build/brahms-glyph-output-2026-10-03'; native=R/'.build/heading-glyph-continuation-2026-10-03'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
inputs=json.loads((report/'input-bindings.json').read_text()); comp=json.loads((report/'comparison.json').read_text()); review=json.loads((report/'output-review.json').read_text())
for p,h in (inputs|comp['bindings']).items():assert sha(R/p)==h,(p,'changed')
assert review['issues']==[]
# Include exact Core, raw native inputs and exported layout records, without executables or duplicate original PDFs.
files=[]
for v in ['baseline','candidate']:files+=list((native/v/'Core').rglob('*.swift'))
for p in (native/'native-worker').rglob('*'):
 if p.is_file() and p.suffix in ['.json','.log','.swift'] and not any(x.startswith('export-') for x in p.relative_to(native/'native-worker').parts[:-1]):files.append(p)
files += [native/'build-export.sh']
for case in ['brahms242312','brahms09200']:
 for prefix in ['', 'baseline-']:
  d=build/(prefix+case+'-parts');files += [d/'manifest.json', d/'plan.json']+list(d.rglob('project.json'))
for p in inputs:
 if p.startswith('Tests/quality_control/profiles/'):files.append(R/p)
files += [R/'Tests/quality_control/accepted-heading-source-review/frozen-initial-A-guards.json']
files=sorted(set(files)); assert all(p.is_file() for p in files)
entries={str(p.relative_to(R)):sha(p) for p in files}
with zipfile.ZipFile(report/'native-evidence.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in files:z.write(p,str(p.relative_to(R)))
 z.writestr('archive-sha256.json',json.dumps(entries,indent=2)+'\n')
with zipfile.ZipFile(report/'native-evidence.zip') as z:
 assert z.testzip() is None
 for p,h in entries.items():assert hashlib.sha256(z.read(p)).hexdigest()==h
write(report/'archive-manifest.json',{'archive':'native-evidence.zip','sha256':sha(report/'native-evidence.zip'),'entries':entries})
shutil.copy2(native/'native-worker/export-brahms242312.log',report/'export-242312.log')
for case,source,profile,total,pages in [
 ('242312','sample_scores/lightly_skewed/10_brahms_string_quartet_no3_op67_imslp_242312.pdf','Tests/quality_control/profiles/lightly-skewed-10-brahms-string-quartet-no3-op67-imslp-242312.json',43,[11,11,10,11]),
 ('09200','sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf','Tests/quality_control/profiles/medium-skewed-05-brahms-string-quartet-no3-op67-imslp-09200.json',41,[11,10,10,10])]:
 src=build/('brahms'+case+'-parts');dst=R/'output/pdf/auto-qc-2026-09-21'/('brahms-quartet-'+case+'-glyph-continuation')
 assert not dst.exists(),f'Refusing overwrite {dst}'
 sourcehashes={str(p.relative_to(src)):sha(p) for p in sorted(src.rglob('*')) if p.is_file()}
 assert len(sourcehashes)==8
 for part in [r for r in review['parts'] if r['case']=='brahms'+case]:assert sourcehashes[part['file']]==part['sha256']
 shutil.copytree(src,dst)
 for f,h in sourcehashes.items():assert sha(dst/f)==h
 extra='The source has 26 physical pages; the final publisher catalogue page was automatically skipped as nonmusic. All 25 music pages are included.' if case=='242312' else 'All 25 source pages are included.'
 limit=' The Violoncello part also retains a pre-existing doubled “Doppio Movimento” around the row boundary on output page 10.' if case=='242312' else ''
 (dst/'README.md').write_text(f'''# Brahms quartet, IMSLP {case} — draft parts\n\nComplete native Auto output: four parts, {total} PDF pages and 480 music strips. Each part has 120 systems. {extra}\n\n| Part | PDF pages |\n| --- | ---: |\n| Violin I | {pages[0]} |\n| Violin II | {pages[1]} |\n| Viola | {pages[2]} |\n| Violoncello | {pages[3]} |\n\nOpen the `.partsmithproject` in Partsmith to edit; it contains the original source PDF. These use the initialized four-instrument profile, typed title/composer, and experimental shared-direction detection. No manual crop overrides or rectification were added.\n\nThe heading-continuation fix restores the initial A of “Agitato” in the Violin II, Viola and Violoncello copies on output page 6. Matching full native baseline runs show every music crop and placement unchanged. Every output page and copied direction row was rendered and visually reviewed. The files here are hash-identical to that reviewed export.\n\n**Draft limitations:** broad neighboring notation and fragments of staves remain in some crops and copied directions. First/second ending pairs on physical source pages 21 (system 3), 23 (system 4) and 24 (system 2) remain undetected.{limit} This review validates the bounded heading repair and output layout; it does not certify every musical symbol, all repeats, or performance-ready page turns.\n\nThe [full review](../../../../Tests/quality_control/brahms-glyph-output/README.md) contains before/after images, all-page checks and native-run evidence. `manifest.json` records source/output placement; `plan.json` records staff assignments. `provenance.json` binds the source, initialized profile, actual native worker inputs and frozen Core. `delivery-hashes.json` checks every delivered file except itself. Earlier drafts are preserved.\n''')
 provenance={'status':'draft; bounded heading repair validated; existing crop and ending limitations remain','case':'brahms'+case,'source':{'path':source,'sha256':sha(R/source)},'profile':{'path':profile,'sha256':sha(R/profile)},'title':'Brahms — String Quartet No. 3, Op. 67','composer':'Johannes Brahms','parts':4,'pages':total,'musicStrips':480,'copies':29,'detectorSHA256':inputs[str((native/'candidate/Core/Detection/ScoreSharedHeadingDetector.swift').relative_to(R))],'nativeWorker':{str((native/'native-worker'/('brahms'+case+'-'+suffix+'.json')).relative_to(R)):sha(native/'native-worker'/('brahms'+case+'-'+suffix+'.json')) for suffix in ['inventory','plan','summary']},'reviewedExport':str(src.relative_to(R)),'reviewedExportFiles':sourcehashes,'report':'Tests/quality_control/brahms-glyph-output/README.md','comparisonSHA256':sha(report/'comparison.json'),'nativeEvidenceSHA256':sha(report/'native-evidence.zip')}
 write(dst/'provenance.json',provenance)
 hashes={str(p.relative_to(dst)):sha(p) for p in sorted(dst.rglob('*')) if p.is_file()}
 write(dst/'delivery-hashes.json',{'algorithm':'SHA-256','files':hashes})
 print(case,total,'pages',sha(dst/'delivery-hashes.json'),str(dst))
