#!/usr/bin/env python3
"""Read-only release/package identity verification; writes only independent evidence."""
from pathlib import Path
import datetime,hashlib,json,plistlib,re,subprocess,zipfile
r=Path('Tests/quality_control/residual9-boundary-independent')
recordPath=Path('Tests/quality_control/macos-build-2026-10-03-continuation.json')
priorPath=Path('Tests/quality_control/macos-build-2026-10-03-heading-blocks.json')
record=json.loads(recordPath.read_text());prior=json.loads(priorPath.read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def shab(data):return hashlib.sha256(data).hexdigest()
def canonical(x):return json.dumps(x,sort_keys=True,separators=(',',':')).encode()
def run(args):
 p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,check=True);return p.stdout
assert len(record['productionSources'])==len(prior['productionSources'])==34
assert set(record['productionSources'])==set(prior['productionSources'])
checks=[];deltas=[]
for f,digest in record['productionSources'].items():
 actual=sha(f);assert actual==digest,f
 checks.append({'path':f,'sha256':actual})
 if actual!=prior['productionSources'][f]:deltas.append({'path':f,'before':prior['productionSources'][f],'after':actual})
expected=['Partsmith/Core/Detection/NativeScorePageAnalyzer.swift','Partsmith/Core/Detection/ScoreSharedHeadingDetector.swift']
assert [x['path'] for x in deltas]==record['changedProductionSources']==expected
assert {str(p) for p in Path('Partsmith').rglob('*.swift')}=={p for p in record['productionSources'] if p.endswith('.swift')}
core=Path('.build/brahms-continuation-release-2026-10-03/candidate')
manifest=json.loads((core/'source-hashes.json').read_text())
for rel,digest in manifest.items():assert sha(core/rel)==digest,rel
coreChecks=[]
for p in (core/'Core').rglob('*.swift'):
 prod=Path('Partsmith/Core')/p.relative_to(core/'Core');assert p.read_bytes()==prod.read_bytes()
 coreChecks.append({'snapshot':str(p),'production':str(prod),'sha256':sha(p)})
assert len(coreChecks)==23
archive=Path(record['archive']);archiveHash=sha(archive)
assert archiveHash==record['archiveSHA256']=='93563a97b8559f72a37d840617500186b35273d711b1dcfa8543b2809aebb440'
scratch=Path('.build/residual9-boundary-independent/release-identity');scratch.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 names=z.namelist();exeNames=[n for n in names if n.endswith('.app/Contents/MacOS/Partsmith')];assert len(exeNames)==1
 data=z.read(exeNames[0]);exeHash=shab(data)
 assert exeHash==record['executableSHA256']=='5c28a3e2aa9e9d282d925c7213fdfe1294cbbb56a433b0de5fd94ae42cc9efd5'
 extracted=scratch/'Partsmith';extracted.write_bytes(data)
 plistNames=[n for n in names if n.endswith('.app/Contents/Info.plist')];assert len(plistNames)==1
 plist=plistlib.loads(z.read(plistNames[0]));assert plist['LSMinimumSystemVersion']=='14.0'
 signatureEntries=[n for n in names if '/_CodeSignature/' in n];assert not signatureEntries
built=Path('.build/DirectionFlowDerivedData/Build/Products/Release/Partsmith.app/Contents/MacOS/Partsmith');assert sha(built)==exeHash
archOutput=run(['xcrun','lipo','-archs',str(extracted)]);archs=archOutput.split();assert set(archs)==set(record['architectures'])=={'arm64','x86_64'}
buildInfo=run(['xcrun','vtool','-show-build',str(extracted)]);minima=re.findall(r'^\s*minos\s+(\S+)',buildInfo,re.M);assert minima==['14.0','14.0'];assert buildInfo.count('platform MACOS')==2
signature=run(['codesign','--display','--verbose=2',str(extracted)]);assert 'Signature=adhoc' in signature and 'TeamIdentifier=not set' in signature and 'Sealed Resources=none' in signature
logPath=Path(record['buildLog']);log=logPath.read_text();assert log.count('** BUILD SUCCEEDED **')==1 and '** BUILD FAILED **' not in log
assert '-configuration Release' in log and 'ARCHS=arm64 x86_64' in log and 'CODE_SIGNING_ALLOWED=NO' in log
previous=Path(record['previousArchive']);assert sha(previous)==record['previousArchiveSHA256']==prior['archiveSHA256']
identityKeys=['configuration','archive','archiveSHA256','executableSHA256','architectures','previousArchive','previousArchiveSHA256','buildLog','productionSources','changedProductionSources']
result={
 'verdict':'PASS: package, reviewed production sources, frozen combined Core and completed universal Release product agree.',
 'verifiedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'buildRecord':str(recordPath),'buildRecordSHA256AtVerification':sha(recordPath),
 'buildRecordStableIdentityProjectionSHA256':shab(canonical({k:record[k] for k in identityKeys})),
 'stableIdentityKeys':identityKeys,'outputReviewAtVerification':record.get('outputReview'),
 'recordFinalizationConfirmedByParent':True,
 'metadataScopeNote':'Final PDF-output metadata was appended by the parent. This independent check verifies package/source identity; PDF-quality statements retain their parent-owned review scope.',
 'priorBuildRecord':str(priorPath),'priorBuildRecordSHA256':sha(priorPath),
 'archive':str(archive),'archiveSHA256':archiveHash,'archiveCRCValid':True,'archiveEntryCount':len(names),
 'executableMember':exeNames[0],'executableSHA256':exeHash,'matchesCompletedBuildProduct':True,
 'architectures':archs,'minimumOSByArchitecture':{a:'14.0' for a in archs},'infoPlistMinimumOS':plist['LSMinimumSystemVersion'],
 'signing':'Linker ad-hoc executable signature; no developer team, sealed resources or archive _CodeSignature entries. Not a notarization or public-signing verification.',
 'architectureToolOutput':archOutput,'buildVersionToolOutput':buildInfo,'signatureToolOutput':signature,
 'buildLog':str(logPath),'buildLogSHA256':sha(logPath),'successfulReleaseBuild':True,
 'productionSourceCount':len(checks),'productionSources':checks,'expectedOnlyTwoProductionDeltas':deltas,
 'frozenCoreManifest':str(core/'source-hashes.json'),'frozenCoreManifestSHA256':sha(core/'source-hashes.json'),'frozenCoreSourceCount':len(coreChecks),'frozenCoreMatchesProduction':coreChecks,
 'priorArchiveSHA256':sha(previous),'runningUserAppAccessed':False,'originalScoresEdited':False,
 'verificationScriptSHA256':sha(__file__)
}
(r/'release-identity.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['verdict','archiveSHA256','executableSHA256','architectures','productionSourceCount','frozenCoreSourceCount']},indent=2))
