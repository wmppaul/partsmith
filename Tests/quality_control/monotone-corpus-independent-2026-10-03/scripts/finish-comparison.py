from pathlib import Path
import json,math,hashlib,collections,gzip
R=Path('.build/monotone-corpus-independent-2026-10-03');read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
a=read(R/'comparison.json');base=read(R/'baseline-binding.json');by={x['id']:x for x in base['rows']};orders=[];anomalies=[]
for row in a['rows']:
 before,after=[read(x['path'])for x in row['files']]
 for pg0,pg1,p0,p1 in zip(before['pages'],after['pages'],before['plan']['pages'],after['plan']['pages']):
  ids0=[x['id']for x in p0['assignments']];ids1=[x['id']for x in p1['assignments']]
  orders.append({'id':row['id'],'page':pg0['pageIndex']+1,'assignmentOrderExactlyEqual':ids0==ids1,'staffOrderExactlyEqual':[s['id']for s in pg0['staves']]==[s['id']for s in pg1['staves']],'bandCount':len(ids1),'unassignedStaffIDs':sorted({s['id']for s in pg1['staves']}-{i for b in p1['assignments']for i in b['candidateIDs']})})
  for side,pg,pp in [('before',pg0,p0),('after',pg1,p1)]:
   for f in ['pageWidth','pageHeight','imageWidth','imageHeight']:
    if not(math.isfinite(pg[f])and pg[f]>0):anomalies.append([row['id'],pg['pageIndex'],side,f,pg[f]])
   for staff in pg['staves']:
    lines=staff['staffLineFractions']
    if not(len(lines)==5 and all(math.isfinite(y)and 0<=y<=1 for y in lines)and all(y<x for y,x in zip(lines,lines[1:]))):anomalies.append([row['id'],pg['pageIndex'],side,'staffLines',staff])
   for band in pp['assignments']:
    vs=[band[f]for f in ['leftFraction','topFraction','rightFraction','bottomFraction']]
    if not(all(math.isfinite(v)and 0<=v<=1 for v in vs)and vs[0]+vs[2]<1 and vs[1]<vs[3]):anomalies.append([row['id'],pg['pageIndex'],side,'cropGeometry',band])
assert all(x['assignmentOrderExactlyEqual']and x['staffOrderExactlyEqual']for x in orders)
(R/'order-and-geometry-validation.json').write_text(json.dumps({'allAssignmentOrdersExactlyEqual':True,'allStaffOrdersExactlyEqual':True,'physicalPages':len(orders),'anomalies':anomalies,'pages':orders},indent=2)+'\n')
# Preserve complete component deltas compactly; provide a human-usable queue with raw inventory links.
queue=read(R/'source-review-queue.json');compact=[];neutral=[];geometryJobs=[]
coverage={(x['id'],x['page']):x for x in read(R/'page-coverage.json')if x['side']=='after'}
rowsBy={x['id']:x for x in a['rows']}
with gzip.GzipFile(filename=str(R/'component-deltas.json.gz'),mode='wb',mtime=0)as f:
 f.write(b'[\n');first=True
 for q in queue:
  ink=q.get('componentChanges');c=coverage[(q['id'],q['page'])]
  d={k:v for k,v in q.items()if k!='componentChanges'};d['inventoryFiles']=rowsBy[q['id']]['files'];d['unassignedStaffIDs']=c['unassignedStaffIDs'];d['requiresChangedCropVisualReview']=any(b.get('geometryChanged')for b in q['changedBands']);d['requiresUnassignedDiagnostic']=bool(c['unassignedStaffIDs'])and ink is not None
  if ink:
   d['componentChanges']={'removedCount':len(ink['removed']),'addedCount':len(ink['added']),'ownershipAtSameGeometryCount':len(ink['ownershipAtSameGeometry']),'fullDeltaLocation':'component-deltas.json.gz keyed by score id and physical page'}
   if not first:f.write(b',\n')
   first=False;f.write(json.dumps({'id':q['id'],'page':q['page'],'componentChanges':ink},separators=(',',':')).encode())
  compact.append(d)
  if d['requiresUnassignedDiagnostic']:neutral.append({'id':q['id'],'page':q['page'],'source':q['source'],'sourceSHA256':q['sourceSHA256'],'files':d['inventoryFiles'],'unassignedStaffIDs':c['unassignedStaffIDs'],'beforeUnresolvedReasons':q['beforeUnresolvedReasons'],'afterUnresolvedReasons':q['afterUnresolvedReasons'],'diagnosticOnly':True,'note':'Neutral one-staff crop comparison would not establish instrument identity, omitted rests, or extraction completion. Not executed in this comparator.'})
  for b in q['changedBands']:
   if b.get('geometryChanged'):geometryJobs.append({'id':q['id'],'source':q['source'],'sourceSHA256':q['sourceSHA256'],'profile':q['profile'],'inventoryFiles':d['inventoryFiles'],**b})
 f.write(b'\n]\n')
for n,data in [('compact-source-review-queue.json',compact),('changed-crop-review-jobs.json',geometryJobs),('unassigned-diagnostic-jobs.json',neutral)]: (R/n).write_text(json.dumps(data,indent=2)+'\n')
summary=dict(a['summary']);summary.update({'allAssignmentOrdersExactlyEqual':True,'allStaffOrdersExactlyEqual':True,'invalidGeometryRecords':len(anomalies),'changedCropReviewJobs':len(geometryJobs),'pagesWithChangedCrops':sum(q['requiresChangedCropVisualReview']for q in compact),'unassignedDiagnosticPages':len(neutral),'sourceReviewStatus':'Pending source review; geometry checks do not establish preservation.','candidateVerdict':'Pending independent real-source review and parent decision; no production approval from this comparator.'})
(R/'independent-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
