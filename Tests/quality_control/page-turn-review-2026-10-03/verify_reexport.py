from pathlib import Path
import hashlib
import json
import pymupdf as fitz

root = Path.cwd()
work = root / '.build/page-turn-review-2026-10-03'
report = root / 'Tests/quality_control/page-turn-review-2026-10-03'
original = work / 'final-alternative'
reopened = work / 'reexported'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = json.loads((original / 'manifest.json').read_text())
again = json.loads((reopened / 'reexport.json').read_text())
assert again['packageRoundtripExact'] and again['explicitBreaks'] == 6
assert again['sourceSHA256'] == manifest['sourceSHA256']
assert again['projectSHA256'] == sha(original / manifest['project'] / 'project.json')
parts = []
total_strips = total_copies = 0
for before, after in zip(manifest['parts'], again['parts']):
    assert before['name'] == after['name']
    assert before['outputPages'] == after['pages']
    assert len(before['placements']) == len(after['placements']) == 151
    for a, b in zip(before['placements'], after['placements']):
        for key in ['sourcePage', 'outputPage', 'sourceRect', 'destinationRect']:
            assert a[key] == b[key], (before['name'], a['id'], key)
        assert len(a['sourceMarkings']) == len(b['sourceMarkings'])
        for x, y in zip(a['sourceMarkings'], b['sourceMarkings']):
            assert x['sourceRect'] == y['sourceRect']
            assert x['destinationRect'] == y['destinationRect']
        total_strips += 1
        total_copies += len(a['sourceMarkings'])
    source_pdf = original / before['file']
    reopened_pdf = reopened / after['file']
    a, b = fitz.open(source_pdf), fitz.open(reopened_pdf)
    assert len(a) == len(b)
    pixel_hashes = []
    for n in range(len(a)):
        ap = a[n].get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
        bp = b[n].get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
        assert (ap.width, ap.height) == (bp.width, bp.height)
        assert ap.samples == bp.samples, (before['name'], n + 1)
        pixel_hashes.append(hashlib.sha256(ap.samples).hexdigest())
    parts.append({'name': before['name'], 'pages': len(a),
                  'originalSHA256': sha(source_pdf), 'reexportSHA256': sha(reopened_pdf),
                  'placementsExactlyEqual': True, 'allPagePixelsEqualAtDPI': 144,
                  'pagePixelSHA256': pixel_hashes})
assert total_strips == 604 and total_copies == 42
result = {'verdict': 'PASS', 'sourceSHA256': again['sourceSHA256'],
          'projectSHA256': again['projectSHA256'], 'projectJSONRoundtripExact': True,
          'persistedExplicitBreaks': 6, 'musicPlacementsExactlyEqual': total_strips,
          'directionPlacementsExactlyEqual': total_copies, 'totalPages': 67,
          'pdfByteHashesMayDiffer': 'Native PDF metadata is regenerated; compare rendered pixels and placements.',
          'parts': parts}
(report / 'reexport-verification.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k != 'parts'}, indent=2))
