from pathlib import Path
import hashlib,json
import pymupdf as fitz
root=Path('.build/ending-auto-native-full-2026-10-03')
report={'scope':'Fresh app direction workflow exports versus the separately reviewed full-score drafts; exact geometry and complete-page pixels. Existing musical defects remain.', 'renderDPI':144,'scores':[], 'changedPages':[], 'placementDifferences':[]}
for name,old_dir in [('brahms','output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-traced-lines'),('kv498','output/pdf/auto-qc-2026-09-21/mozart-kv498-directions')]:
    old_dir=Path(old_dir);new_dir=root/name/'parts'
    old=json.loads((old_dir/'manifest.json').read_text());new=json.loads((new_dir/'manifest.json').read_text())
    rec={'score':name,'sourceSHA256':new['sourceSHA256'],'parts':[]}
    for key in ['sourceSHA256','profile','rectifications','reviewedOverrides']:
        assert old[key]==new[key],(name,key)
    assert len(old['parts'])==len(new['parts'])
    copies=0;bands=0
    for a,b in zip(old['parts'],new['parts']):
        for key in ['id','name','outputPages','bandCount','systemsPerPage']:
            assert a[key]==b[key],(name,a['id'],key)
        assert len(a['placements'])==len(b['placements'])
        for before,after in zip(a['placements'],b['placements']):
            for key in ['id','sourcePage','system','candidateIDs','sourceRect','staffLineYs','kind','outputPage']:
                assert before[key]==after[key],(name,a['id'],before['id'],key)
            differences={k:[before.get(k),after.get(k)] for k in sorted(set(before)|set(after)) if before.get(k)!=after.get(k)}
            if differences: report['placementDifferences'].append({'score':name,'part':b['id'],'band':before['id'],'differences':differences})
        pa=fitz.open(old_dir/a['file']);pb=fitz.open(new_dir/b['file'])
        assert len(pa)==len(pb)==b['outputPages']
        identical=[]
        for n,(aa,bb) in enumerate(zip(pa,pb)):
            xa=aa.get_pixmap(matrix=fitz.Matrix(2,2),alpha=False)
            xb=bb.get_pixmap(matrix=fitz.Matrix(2,2),alpha=False)
            same=(xa.width,xa.height,xa.samples)==(xb.width,xb.height,xb.samples)
            identical.append(same)
            if not same:
                report['changedPages'].append({'score':name,'part':b['id'],'page':n+1})
                mismatch=root/'changed-pages';mismatch.mkdir(exist_ok=True)
                xa.save(str(mismatch/f'{name}-{b["id"]}-{n+1}-before.png'))
                xb.save(str(mismatch/f'{name}-{b["id"]}-{n+1}-after.png'))
        bands+=b['bandCount'];copies+=sum(len(p['sourceMarkings']) for p in b['placements'])
        rec['parts'].append({'id':b['id'],'file':b['file'],'pages':len(pb),'bands':b['bandCount'],
            'exactPlacements':a['placements']==b['placements'],'pagesPixelIdentical':identical,'sha256':hashlib.sha256((new_dir/b['file']).read_bytes()).hexdigest()})
    source=(new_dir/new['project']/'source.pdf').read_bytes()
    assert hashlib.sha256(source).hexdigest()==new['sourceSHA256']
    project=json.loads((new_dir/new['project']/'project.json').read_text())['project']
    assert len(project['bands'])==bands and len(project['parts'])==len(new['parts'])
    assert project.get('pageRectifications',[])==new['rectifications']
    rec.update({'bands':bands,'copiedRows':copies,'pages':sum(x['pages'] for x in rec['parts']),
                'savedProjectContainsAllPartsAndBands':True,'embeddedSourceHashVerified':True})
    report['scores'].append(rec)
out=Path('Tests/quality_control/ending-auto-native-2026-10-03/export-comparison.json')
out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'scores':[{k:v for k,v in s.items() if k!='parts'} for s in report['scores']], 'changedPages':report['changedPages']},indent=2))
if report['changedPages']:
    print('Changed pages remain explicit and require source review; this is not an exact output pass.')
