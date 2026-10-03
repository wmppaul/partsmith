import pathlib,json,hashlib
r=pathlib.Path(__file__).parent;b=pathlib.Path('output/pdf/auto-qc-2026-10-03/erlkonig-reviewed-draft');c=pathlib.Path('.build/erlkonig-rest-finish-2026-10-03/parts')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();old=json.loads((r/'baseline-project.json').read_text())['project'];new=json.loads((c/'Erlkonig-rest-layout.partsmithproject/project.json').read_text())['project'];expected=json.loads(json.dumps(old));rest=[x for x in expected['bands'] if x.get('generatedRest')];assert [x['generatedRest']['startBarNumber'] for x in rest]==[1,4,7,10]
for x in rest[1:]:x['generatedRest']['joinWithPrevious']=True
rest[0]['editorialLabel']='[4/4]';expected['modifiedAt']=new['modifiedAt'];assert expected==new,'Unexpected project edit'
source=c/'Erlkonig-rest-layout.partsmithproject/source.pdf';assert source.read_bytes()==(r/'source.pdf').read_bytes()
placements=json.loads((c/'placements.json').read_text());print('sample',placements[0]['rows'][1]);parts=[]
for part in new['parts']:
 rows=next(x for x in placements if x['name']==part['name'])['rows'];stored=[x for x in new['bands'] if x['partID']==part['id'] and not x['excluded']];ids=[i for x in rows for i in x['sourceBandIDs']];assert len(ids)==len(stored) and sorted(ids)==sorted(x['id'] for x in stored)
 merged=[x for x in rows if len(x['sourceBandIDs'])>1];assert len(merged)==(1 if part['name']=='Voice' else 0)
 if merged:assert merged[0]['sourceBandIDs']==[x['id'] for x in rest] and merged[0]['rest']['barCount']==12 and merged[0]['rest']['startBarNumber']==1 and merged[0]['label']=='[4/4]'
 parts.append({'name':part['name'],'storedOriginalBands':len(stored),'outputRows':len(rows),'everyOriginalReferenceOccursExactlyOnce':True,'mergedRows':len(merged),'pages':next(x for x in placements if x['name']==part['name'])['pages']})
out={'projectChangesExactlyRequested':True,'originalSourcePayloadExact':True,'parts':parts,'expectedChangedFields':['joinWithPrevious true only on introductory omitted Voice rests starting4,7,10','editorialLabel [4/4] only on opening omitted Voice rest','project modifiedAt'],'originalRestRecordsStillPresent':[{'id':x['id'],**x['generatedRest']} for x in new['bands'] if x.get('generatedRest')],'files':{str(p):sha(p) for p in [r/'baseline-project.json',r/'source.pdf',c/'Erlkonig-rest-layout.partsmithproject/project.json',source,c/'placements.json',b/'Voice.pdf',b/'Piano.pdf',c/'Voice.pdf',c/'Piano.pdf']}}
(r/'export-metadata-comparison.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(parts))
