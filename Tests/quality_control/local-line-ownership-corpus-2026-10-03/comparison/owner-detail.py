"""Enumerate every component geometry and owner-set change, including unresolved pages."""
from pathlib import Path
import collections, gzip, hashlib, json, math
W=Path('.build/local-line-ownership-corpus-2026-10-03');R=W/'comparison'
read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();canon=lambda x:json.dumps(x,sort_keys=True,separators=(',',':'))
comp=read(R/'comparison.json');assert comp['summary']['complete']
base={r['id']:r for r in read(R/'baseline-binding.json')['rows']}
pageRows=[];allChanges=[];scoreRows=[];pdfGeometry=[]
for row in comp['rows']:
 before,after=[read(f['path'])for f in row['files']]
 local=[]
 for pg0,pg1,pp0,pp1 in zip(before['pages'],after['pages'],before['plan']['pages'],after['plan']['pages']):
  def groups(pg):
   g=collections.defaultdict(collections.Counter)
   for c in pg['inkComponents']:g[canon({k:v for k,v in c.items()if k!='staffIDs'})][tuple(c['staffIDs'])]+=1
   return g
  g0,g1=groups(pg0),groups(pg1);geometry0=collections.Counter({k:sum(v.values())for k,v in g0.items()});geometry1=collections.Counter({k:sum(v.values())for k,v in g1.items()})
  assigned={i for b in pp1['assignments']for i in b['candidateIDs']};changes=[]
  for k in sorted(g0.keys()|g1.keys()):
   if g0[k]==g1[k]:continue
   removed=g0[k]-g1[k];added=g1[k]-g0[k]
   old=[list(ids)for ids in sorted(removed)for _ in range(removed[ids])];new=[list(ids)for ids in sorted(added)for _ in range(added[ids])]
   geometry=json.loads(k)
   rec={'scoreID':row['id'],'page':pg0['pageIndex']+1,'geometry':geometry,'beforeOwnerSets':old,'afterOwnerSets':new,'zeroPlanPage':not pp1['assignments'],'unassignedStaffIDs':sorted({s['id']for s in pg1['staves']}-assigned),'beforeUnresolvedReasons':pp0['unresolvedReasons'],'afterUnresolvedReasons':pp1['unresolvedReasons'],'sourceSHA256':base[row['id']]['sourceSHA256']}
   if len(old)==len(new)==1:rec.update(removedOwners=sorted(set(old[0])-set(new[0])),addedOwners=sorted(set(new[0])-set(old[0])),isAlternative=geometry.get('isOwnershipAlternative',False))
   changes.append(rec);allChanges.append(rec)
  record={'scoreID':row['id'],'page':pg0['pageIndex']+1,'geometryMultisetExactlyEqual':geometry0==geometry1,'removedGeometry':[{'geometry':json.loads(k),'count':n}for k,n in (geometry0-geometry1).items()],'addedGeometry':[{'geometry':json.loads(k),'count':n}for k,n in (geometry1-geometry0).items()],'ownershipChangedGroups':len(changes),'beforeComponentCount':len(pg0['inkComponents']),'afterComponentCount':len(pg1['inkComponents']),'zeroPlanPage':not pp1['assignments'],'bandCount':len(pp1['assignments'])}
  pageRows.append(record);local.append(record)
  pdf=base[row['id']]['physicalPDFGeometry'][pg0['pageIndex']];rect=pdf['mediaBox'];expected=[rect[2]-rect[0],rect[3]-rect[1]]
  if pdf['rotation']%180==90:expected.reverse()
  actual=[pg1['pageWidth'],pg1['pageHeight']]
  pdfGeometry.append({'scoreID':row['id'],'page':pg0['pageIndex']+1,'physicalPDFDimensions':expected,'analyzerDimensions':actual,'within0_001pt':all(abs(x-y)<.001 for x,y in zip(actual,expected))})
 scoreRows.append({'id':row['id'],'ownershipChangedPages':sum(bool(p['ownershipChangedGroups'])for p in local),'ownershipChangedGroups':sum(p['ownershipChangedGroups']for p in local),'zeroPlanOwnershipChangedPages':sum(p['zeroPlanPage']and bool(p['ownershipChangedGroups'])for p in local),'geometryDifferentPages':sum(not p['geometryMultisetExactlyEqual']for p in local)})
summary={'scores':len(scoreRows),'pages':len(pageRows),'ownershipChangedGroups':len(allChanges),'ownershipChangedPages':sum(bool(p['ownershipChangedGroups'])for p in pageRows),'geometryDifferentPages':sum(not p['geometryMultisetExactlyEqual']for p in pageRows),'zeroPlanOwnershipChangedPages':sum(p['zeroPlanPage']and bool(p['ownershipChangedGroups'])for p in pageRows),'zeroPlanOwnershipChangedGroups':sum(p['zeroPlanPage']for p in allChanges),'ambiguousDuplicateGeometryGroups':sum(len(p['beforeOwnerSets'])!=1 or len(p['afterOwnerSets'])!=1 for p in allChanges),'groupsAddingOwners':sum(bool(p.get('addedOwners'))for p in allChanges),'groupsRemovingOwners':sum(bool(p.get('removedOwners'))for p in allChanges),'physicalPDFGeometryMismatches':sum(not p['within0_001pt']for p in pdfGeometry),'comparisonSHA256':sha(R/'comparison.json'),'sourceBindingsSHA256':sha(R/'baseline-binding.json'),'scriptSHA256':sha(__file__),'scope':'All original component bounds and ownership labels, including zero-plan pages. Unresolved physical staffs are not silently assigned instruments.'}
for n,v in [('ownership-summary.json',{'summary':summary,'scores':scoreRows}),('component-geometry-validation.json',pageRows),('physical-pdf-geometry.json',pdfGeometry)]: (R/n).write_text(json.dumps(v,indent=2)+'\n')
with gzip.GzipFile(filename=str(R/'all-ownership-changes.json.gz'),mode='wb',mtime=0)as f:f.write(json.dumps(allChanges,sort_keys=True,separators=(',',':')).encode())
print(json.dumps(summary,indent=2))
