from pathlib import Path
import json,collections,hashlib
W=Path('.build/local-line-ownership-corpus-2026-10-03');R=W/'fresh-production-40163';read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();canon=lambda x:json.dumps(x,sort_keys=True,separators=(',',':'))
row=next(r for r in read(W/'inputs.json')if '40163' in r['id']);old=read(row['baseline']);fresh=read(R/'inventory.json');new=read(W/'candidate'/(row['id']+'.json'))
assert sha(row['source'])==row['sourceSHA256'] and sha(row['profile'])==row['profileSHA256']
records=[]
for a,b,c in zip(old['pages'],fresh['pages'],new['pages']):
 def plain(pg):return {k:v for k,v in pg.items()if k!='inkComponents'}
 def geometries(pg):return collections.Counter(canon({k:v for k,v in item.items()if k!='staffIDs'})for item in pg['inkComponents'])
 def groups(pg):
  g=collections.defaultdict(collections.Counter)
  for item in pg['inkComponents']:g[canon({k:v for k,v in item.items()if k!='staffIDs'})][tuple(item['staffIDs'])]+=1
  return g
 bg,cg=groups(b),groups(c);changes=[]
 for k in sorted(bg.keys()|cg.keys()):
  removed=bg[k]-cg[k];added=cg[k]-bg[k]
  if removed or added:changes.append({'geometry':json.loads(k),'beforeOwners':[list(x)for x in removed.elements()],'afterOwners':[list(x)for x in added.elements()]})
 records.append({'page':a['pageIndex']+1,'historicalVsFreshNonInkExactlyEqual':plain(a)==plain(b),'freshVsCandidateNonInkExactlyEqual':plain(b)==plain(c),'freshVsCandidateGeometryMultisetExactlyEqual':geometries(b)==geometries(c),'historicalVsFreshGeometryExactlyEqual':geometries(a)==geometries(b),'ownerChanges':changes,'freshComponentCount':len(b['inkComponents']),'candidateComponentCount':len(c['inkComponents'])})
out={'scoreID':row['id'],'source':row['source'],'sourceSHA256':row['sourceSHA256'],'profileSHA256':row['profileSHA256'],'historicalBaselineSHA256':sha(row['baseline']),'freshBaselineSHA256':sha(R/'inventory.json'),'candidateSHA256':sha(W/'candidate'/(row['id']+'.json')),'freshBaselineBinarySHA256':sha(R/'runner'),'scriptSHA256':sha(__file__),'pages':records,'allFreshVsCandidateStaffAndNonInkFieldsExactlyEqual':all(x['freshVsCandidateNonInkExactlyEqual']for x in records),'allFreshVsCandidateComponentGeometryExactlyEqual':all(x['freshVsCandidateGeometryMultisetExactlyEqual']for x in records),'planExactlyEqual':fresh['plan']==new['plan'],'freshVsCandidateOwnerChangedGroups':sum(len(x['ownerChanges'])for x in records),'scope':'Focused fresh9f8 reanalysis, no fixture edits. Historical full36 comparison remains unchanged. Native-output equality establishes attribution only; it does not prove decoded raster pixels identical or explain renderer/platform history.'}
(R/'comparison.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items()if k!='pages'},indent=2))
