from pathlib import Path
import json, hashlib, shutil
import pymupdf as fitz

work = Path('.build/hear-my-prayer-complete-native-2026-10-03')
out = Path('.build/hear-my-prayer-independent-output-review-2026-10-03')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text())
source_map_path = Path('.build/hear-my-prayer-independent-map-2026-10-03/source-counts-before-comparison.json')
source_map = read(source_map_path)

def check(label, directory, render_name):
    dest = work / directory
    manifest = read(dest / 'manifest.json')
    plan = read(dest / 'plan.json')
    render = read(work / render_name)
    assignments = [a for p in plan['pages'] for a in p['assignments']]
    byid = {a['id']: a for a in assignments}
    assert len(byid) == len(assignments) == 204
    references, parts = [], []
    for part in manifest['parts']:
        next_bar, rows = 1, []
        for row in part['placements']:
            assert row['startBarNumber'] == next_bar
            count = row['barCount']
            next_bar += count
            ids = row['sourceBandIDs']
            references.extend(ids)
            assert sum(byid[k]['barCount'] for k in ids) == count
            assert all(byid[k]['partID'] == part['id'] for k in ids)
            starts = [byid[k]['startBarNumber'] for k in ids]
            assert starts == sorted(starts)
            rows.append(dict(id=row['id'], startBar=row['startBarNumber'], endBar=next_bar-1,
                             count=count, kind=row['kind'], sourceBandIDs=ids, outputPage=row['outputPage']))
        assert next_bar == 233
        pdf = dest / part['file']
        assert len(fitz.open(pdf)) == part['outputPages']
        parts.append(dict(id=part['id'], pdfSHA256=sha(pdf), outputPages=part['outputPages'], rows=rows,
                          musicRows=sum(r['kind']=='music' for r in rows),
                          restRows=sum(r['kind']=='generated-rest' for r in rows)))
    assert set(references) == set(byid) and len(references) == len(set(references)) == 204
    assert sum(p['musicRows'] for p in parts) == 152
    project_dir = dest / manifest['project']
    project = read(project_dir / 'project.json')['project']
    assert project['pageCount'] == 10 and len(project['bands']) == 204
    assert not project['pageRectifications']
    assert sha(project_dir/'source.pdf') == manifest['sourceSHA256'] == source_map['source']['sha256']
    assert len(fitz.open(project_dir/'source.pdf')) == 10
    names = {p['id']: p['name'] for p in project['parts']}
    ids = {p['name']: p['id'] for p in manifest['parts']}
    lookup = {(a['partID'],a['pageIndex'],a['startBarNumber']): a for a in assignments}
    for band in project['bands']:
        a = lookup[(ids[names[band['partID']]],band['pageIndex'],band['barNumberValue'])]
        for key in ['topFraction','bottomFraction','leftFraction','rightFraction']:
            assert a[key] == band[key], (a['id'],key)
        assert a.get('sourceMarkings',[]) == band.get('sourceMarkings',[])
        if a.get('generatedRest'):
            assert a['generatedRest']['barCount'] == band['generatedRest']['barCount']
        assert not band['excluded']
    assert len(render['outputPages']) == sum(p['outputPages'] for p in parts) == 16
    for item in render['outputPages']: assert sha(Path(item['path'])) == item['sha256']
    result = dict(sourceSHA256=manifest['sourceSHA256'], independentSourceMapSHA256=sha(source_map_path),
                  manifestSHA256=sha(dest/'manifest.json'), planSHA256=sha(dest/'plan.json'),
                  renderIndexSHA256=sha(work/render_name), parts=parts,
                  all204OriginalReferencesExactlyOnce=True, all152PrintedMusicRowsRemain=True,
                  eachPartTimeline1Through232=True,
                  decodedProject=dict(pageCount=10,bandCount=204,sourceSHA256=sha(project_dir/'source.pdf'),
                    allCropCoordinatesSourceMarkingsAndOriginalRestCountsEqualPlan=True,
                    sourceCorrectionCount=0,projectJSONSHA256=sha(project_dir/'project.json'),
                    joinedRestChildCount=sum(bool(b.get('generatedRest',{}).get('joinWithPrevious')) for b in project['bands'])),
                  outputPageBindings=render['outputPages'])
    (out/f'{label}-identity-proof.json').write_text(json.dumps(result,indent=2)+'\n')
    for src,name in [(dest/'manifest.json','manifest'),(dest/'plan.json','plan'),(work/render_name,'render-index')]:
        shutil.copy2(src,out/f'{label}-{name}.json')
    print(label, len(references), 'references,', sum(p['musicRows'] for p in parts), 'music rows, 232 bars each,', len(render['outputPages']), 'PDF pages')
    return manifest,plan

old, old_plan = check('initial','parts','render-index.json')
new, new_plan = check('final','final-parts','final-render-index.json')
old_assignments = {a['id']:a for p in old_plan['pages'] for a in p['assignments']}
new_assignments = {a['id']:a for p in new_plan['pages'] for a in p['assignments']}
assert old_assignments.keys() == new_assignments.keys()
diff = []
for key,a in old_assignments.items():
    b = new_assignments[key]
    changed = {k:dict(before=a.get(k),after=b.get(k)) for k in a.keys()|b.keys() if a.get(k)!=b.get(k)}
    if changed: diff.append(dict(id=key,changes=changed))
assert len(diff)==9
assert all(set(x['changes']) <= {'topFraction','bottomFraction','warnings'} for x in diff)
warning_changes = [x for x in diff if 'warnings' in x['changes']]
assert {x['id'] for x in warning_changes} == {'p10-s3-alto','p10-s3-tenor'}
assert all(x['changes']['warnings']['after'] == [] for x in warning_changes)
(out/'exact-plan-differences.json').write_text(json.dumps(diff,indent=2)+'\n')
print('Nine source rectangles changed; two resolved connection warnings removed. Source copies, IDs, bar counts and rest references unchanged.')
