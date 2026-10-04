from pathlib import Path
import json,hashlib,subprocess,zipfile
r=Path.cwd();base=r/'.build/variable-layout-output-audit-2026-10-03';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
zero=json.loads((base/'raw-zero-profiles.json').read_text());inputs=json.loads((r/'.build/monotone-line-corpus-2026-10-03/inputs.json').read_text());done={x['id'] for x in json.loads((base/'raw-profile-binding.json').read_text())['focusProfiles']}
remaining=[]
for z in zero:
 if z['id'] in done:continue
 i=next(i for i in inputs if i['id']==z['id']);p=Path(i['source']);assert h(p)==i['sourceSHA256']
 remaining.append({**i,'sourceBytes':p.stat().st_size,'laterSourceEmbeddedProjectsFound':[]})
paths=subprocess.run(['rg','--files','--hidden','.build','output'],capture_output=True,text=True,check=True).stdout.splitlines();sources=[r/p for p in paths if p.endswith('.partsmithproject/source.pdf')];sizes={x['sourceBytes'] for x in remaining};hashed=0
for p in sources:
 if p.stat().st_size not in sizes:continue
 digest=h(p);hashed+=1
 for x in remaining:
  if x['sourceSHA256']==digest:
   project=p.parent/'project.json';d=json.loads(project.read_text())['project'] if project.exists() else {}
   x['laterSourceEmbeddedProjectsFound'].append({'path':str(p.parent.relative_to(r)),'parts':[v['name'] for v in d.get('parts',[])],'bands':len(d.get('bands',[])),'pageCount':d.get('pageCount')})
result={'scope':'Read-only search of loose files returned by rg --files --hidden in output and .build. Matching embedded original source PDFs are content-hash checked. Unopened arbitrary archives are not asserted absent.','sourceEmbeddedProjectsSearched':len(sources),'sizeMatchingSourcesHashed':hashed,'remainingRawProfiles':sorted(remaining,key=lambda x:x['pages']),'candidate':'normal-mendelssohn-verleih-uns-frieden-gnadiglich-cpdl63797-full-score'}
(base/'remaining-output-inventory.json').write_text(json.dumps(result,indent=2)+'\n')
print('source projects searched',len(sources),'size candidates',hashed)
print([(x['id'],len(x['laterSourceEmbeddedProjectsFound'])) for x in remaining])
id=result['candidate'];truth=json.loads((r/'Tests/quality_control/system-template-independent-2026-10-03/frozen/source-truth.json').read_text());score=next(x for x in truth['scores'] if x['id']==id)
with zipfile.ZipFile(r/'Tests/quality_control/system-template-independent-2026-10-03/source-renders.zip') as z:
 for p in score['pages']:
  n=f'{id}/page-{p["pageNumber"]}.png';data=z.read(n);assert hashlib.sha256(data).hexdigest()==p['sourceRenderSHA256'];target=base/'mendelssohn-source'/Path(n).name;target.parent.mkdir(exist_ok=True);target.write_bytes(data)
(base/'mendelssohn-frozen-truth.json').write_text(json.dumps(score,indent=2)+'\n')
print('Reused six source-hash-bound original page renders')
