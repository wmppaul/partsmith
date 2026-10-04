from pathlib import Path
import json,hashlib,subprocess,zipfile,plistlib,re
D=Path('.build/system-staff-count-independent-2026-10-03');R=Path('.build/divisi-assignment-release-v2-2026-10-03');old=Path('.build/matcher-connection-release-2026-10-03')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def run(args):
 r=subprocess.run(args,text=True,capture_output=True);return {'args':args,'code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
roster=json.loads((R/'source-hashes.json').read_text());assert len(roster)==45
source=[]
for rel,h in roster.items():
 assert sha(R/rel)==h and sha(Path(rel))==h
 source.append({'path':rel,'sha256':h,'snapshotAndCurrentEqual':True})
lists=[]
for p in R.rglob('*.SwiftFileList'):
 paths=[Path(x.strip().strip('"'))for x in p.read_text().splitlines() if x.strip()]
 assert len(paths)==35
 rels=[str(x.relative_to(R.resolve()))for x in paths]
 assert all(x in roster and x.endswith('.swift')for x in rels)
 lists.append({'path':str(p),'sha256':sha(p),'compiledSources':rels})
assert len(lists)==2 and lists[0]['compiledSources']==lists[1]['compiledSources']
differ=[rel for rel in roster if rel.endswith('.swift') and (not(old/rel).exists() or sha(old/rel)!=roster[rel])]
assert len(differ)==5,differ
native='Partsmith/Core/Detection/NativeScorePageAnalyzer.swift';assert roster[native]=='9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01'
archive=R/'Partsmith-extraction-preview-macos.zip';app=R/'DerivedData/Build/Products/Release/Partsmith.app'
entries=[]
with zipfile.ZipFile(archive)as z:
 for name in z.namelist():
  if name.startswith('Partsmith.app/')and not name.endswith('/'):
   rel=name[len('Partsmith.app/'):];data=z.read(name);assert hashlib.sha256(data).hexdigest()==sha(app/rel)
   entries.append({'path':rel,'sha256':sha(app/rel),'bytes':len(data)})
 assert {x['path']for x in entries}=={str(x.relative_to(app))for x in app.rglob('*')if x.is_file()}
extract=D/'package-v2-extracted';extract.mkdir(exist_ok=True)
a=run(['/usr/bin/ditto','-x','-k',str(archive),str(extract)]);assert a['code']==0,a
ex=extract/'Partsmith.app';binpath=ex/'Contents/MacOS/Partsmith'
commands=[run(['/usr/bin/lipo','-archs',str(binpath)]),run(['/usr/bin/codesign','--verify','--deep','--strict','--verbose=2',str(ex)]),run(['/usr/bin/codesign','-d','--verbose=4',str(ex)]),run(['/usr/bin/otool','-arch','all','-l',str(binpath)])]
assert all(c['code']==0 for c in commands)
assert set(commands[0]['stdout'].split())=={'arm64','x86_64'}
assert 'Signature=adhoc' in commands[2]['stderr']
load=commands[3].pop('stdout');(D/'package-v2-load-commands.txt').write_text(load)
mins=re.findall(r'\bminos\s+(\S+)',load);assert mins==['14.0','14.0'],mins
plist=plistlib.loads((ex/'Contents/Info.plist').read_bytes());assert plist['LSMinimumSystemVersion']=='14.0'
assert '** BUILD SUCCEEDED **'in(R/'build.log').read_text()
result={'scope':'Read-only private package/source audit. Extracted ZIP privately; no app launch, detector run, signature change or publication.','passed':True,'sourcePathsVerified':len(source),'compiledSourcesPerArchitecture':35,'sourceFiles':source,'compileLists':lists,'priorSnapshot':str(old),'productionDifferences':differ,'nativeSHA256':roster[native],'archive':str(archive),'archiveSHA256':sha(archive),'binarySHA256':sha(binpath),'appEntries':entries,'commands':commands,'minOSPerArchitecture':mins,'plistMinimumSystemVersion':plist['LSMinimumSystemVersion'],'sourceRosterSHA256':sha(R/'source-hashes.json'),'releaseBuildLogSHA256':sha(R/'build.log')}
(D/'independent-package-v2-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k]for k in ['passed','sourcePathsVerified','compiledSourcesPerArchitecture','productionDifferences','archiveSHA256','binarySHA256']}))
