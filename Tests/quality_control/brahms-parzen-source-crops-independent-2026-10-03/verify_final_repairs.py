from pathlib import Path
import json,hashlib,copy
root=Path.cwd();work=root/'.build/brahms-parzen109041-complete-native-2026-10-03';own=root/'.build/brahms-parzen-source-crops-independent-2026-10-03'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
pre=work/'dedup-stage';post=work/'final-reviewed-stage';a=read(pre/'parts/manifest.json');b=read(post/'parts/manifest.json')
assert sha(post/'parts/manifest.json')=='45dd2c2236c77a886aeb0df309e9f0d8f119d2189dcf78f670e87a3bbe2b395d'
assert a['sourceSHA256']==b['sourceSHA256']==sha(Path(b['source']))
assert [p['id'] for p in a['parts']]==[p['id'] for p in b['parts']]
def flatten(d):return {r['id']:r for p in d['parts'] for r in p['placements']}
aa,bb=flatten(a),flatten(b);assert len(aa)==len(bb)==520 and aa.keys()==bb.keys()
def norm(x):
 if isinstance(x,dict):return {k:norm(v) for k,v in x.items() if k not in ['destinationRect','sourceRect']}
 if isinstance(x,list):return [norm(v) for v in x]
 return x
# Every identity, page, staff and bar field remains exact. Source boxes checked separately.
assert all(norm(aa[k])==norm(bb[k]) for k in aa)
changes=[k for k in aa if aa[k]['sourceRect']!=bb[k]['sourceRect']]
assert set(changes)=={'p21-s1-horns12','p24-s1-trombones12'}
assert bb['p21-s1-horns12']['sourceRect']==[0,177.25,595.2,224.17207547169812]
assert bb['p24-s1-trombones12']['sourceRect']==[0,299.8172169811321,595.2,346.5]
# All copies retain source page via parent and source rectangles; output positions may move with rows.
assert all([m['sourceRect'] for m in aa[k]['sourceMarkings']]==[m['sourceRect'] for m in bb[k]['sourceMarkings']] for k in aa)
copycount=sum(len(r['sourceMarkings']) for r in bb.values());assert copycount==183
assert sum(len(r['candidateIDs']) for r in bb.values())==568
pdfs=[];images=[];same=[];changed=[]
for pa,pb in zip(a['parts'],b['parts']):
 assert pa['outputPages']==pb['outputPages']
 assert sha(pre/'parts'/pa['file'])==pa['sha256']
 assert sha(post/'parts'/pb['file'])==pb['sha256']
 pdfs.append({'partID':pb['id'],'beforePath':str((pre/'parts'/pa['file']).relative_to(root)),'beforeSHA256':pa['sha256'],'afterPath':str((post/'parts'/pb['file']).relative_to(root)),'afterSHA256':pb['sha256']})
 for page in range(1,pb['outputPages']+1):
  x=pre/'output-review'/pb['id']/f'page-{page:02}.png';y=post/'output-review'/pb['id']/f'page-{page:02}.png';sx,sy=sha(x),sha(y)
  rec={'partID':pb['id'],'page':page,'beforePath':str(x.relative_to(root)),'afterPath':str(y.relative_to(root)),'beforeSHA256':sx,'afterSHA256':sy}
  (same if sx==sy else changed).append(rec)
assert len(same)==60 and {(r['partID'],r['page']) for r in changed}=={('horns12',3),('trombones12',3)}
details=read(post/'repair-output-details/index.json')
for d in details:
 assert sha(root/d['outputDetail'])==d['sha256']
 part=next(p for p in (a if d['stage']=='dedup-stage' else b)['parts'] if d['bandID'].endswith('-'+p['id']))
 assert part['sha256']==d['outputPDFSHA256']
 assert flatten(a if d['stage']=='dedup-stage' else b)[d['bandID']]['sourceRect']==d['sourceRect']
assert bb['p21-s1-horns12']['sourceRect'][1]<=read(own/'p21-horns12-slur-source-obligation.json')['requiredUpperGuard']
assert bb['p24-s1-trombones12']['sourceRect'][3]>=read(own/'p24-trombones12-dim-source-obligation.json')['requiredConservativeTextEnvelope'][3]
out={'verdict':'Two local additive repairs pass independent source-envelope, actual-row and full-page visual review.','scope':'Repaired source 21 Horn I/II and source 24 Trombone I/II, both output page 3. Previous 312 source review remains separate; full 520 final musical completeness is not inferred from metadata.','sourceSHA256':b['sourceSHA256'],'beforeManifestSHA256':sha(pre/'parts/manifest.json'),'finalManifestSHA256':sha(post/'parts/manifest.json'),'finalProject':{'path':str((post/'parts'/b['project']).relative_to(root)),'members':{str(f.relative_to(post/'parts'/b['project'])):sha(f) for f in sorted((post/'parts'/b['project']).rglob('*')) if f.is_file()}},'verified':{'parts':20,'pages':62,'uniqueRows':520,'staffReferences':568,'identityStaffBarAndPageMetadataExact':True,'sourceCopyShapesExact':183,'unchangedMainCrops':518,'samePagePNGs':60,'changedPagePNGs':2,'bothFrozenSourceGuardsContained':True},'sourceCropChanges':[{'id':k,'before':aa[k]['sourceRect'],'after':bb[k]['sourceRect']} for k in changes],'directVisualViews':{'allFourBeforeAfterRowStrips':details,'allFourBeforeAfterFullPagePNGs':changed,'findings':[{'id':'p21-s1-horns12','finding':'Upper slur crest complete; own notes, lower slur, pp/dim and meter change retained. Neighbor Horn III/IV fragments remain.'},{'id':'p24-s1-trombones12','finding':'Complete dim. lower letter strokes and period retained. Own tied chords, hairpins and pp remain complete. Additional neighboring Tuba line fragments are visible.'}],'layout':'No new row overlap, page collision or pagination change observed on either changed final page; shifted following rows remain clear.'},'unchangedPagePNGBindings':same,'pdfBindings':pdfs,'limits':['Existing whole-neighbor rows, foreign technique/direction carryovers and fragments recorded in initial 312 receipt are not resolved by these two repairs.','PDF rows/pages were viewed from exporter-created hash-bound renders; this reviewer did not rerender or re-export.','No production code or crop was edited by this reviewer.']}
f=own/'final-repair-review.json';f.write_text(json.dumps(out,indent=2)+'\n');print(str(f.relative_to(root)),sha(f))
