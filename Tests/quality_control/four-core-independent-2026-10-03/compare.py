#!/usr/bin/env python3
"""Compare immutable source-owned controls; crops never define the oracle."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RUN = ROOT / '.build/brahms-remaining-2026-10-03/four-core-independent'
REPORT = Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

base = json.loads((RUN / 'baseline/results.json').read_text())
candidate = json.loads((RUN / 'candidate/results.json').read_text())
assert len(base) == len(candidate) == 36
images = []
for path in sorted((RUN / 'baseline/sources').glob('*.png')):
    other = RUN / 'candidate/sources' / path.name
    assert digest(path) == digest(other), path.name
    images.append({'name': path.name, 'sha256': digest(path)})
assert len(images) == 60
changes = []
newly_failed = []
worsened = []
for old, new in zip(base, candidate):
    for field in ['id', 'kind', 'damaged', 'scale']:
        assert old[field] == new[field]
    owner_changes = []
    for before, after in zip(old['targets'], new['targets']):
        for field in ['owner', 'sourceEnvelope', 'sourcePixels']:
            assert before[field] == after[field]
        if before != after:
            item = {'id': old['id'], 'scale': old['scale'], 'owner': before['owner'],
                    'before': before, 'after': after}
            owner_changes.append(item)
            if after['lostPixels'] > before['lostPixels']:
                worsened.append(item)
                if before['lostPixels'] == 0:
                    newly_failed.append(item)
    if old != new:
        changes.append({'id': old['id'], 'scale': old['scale'],
                        'ownerChanges': owner_changes,
                        'oldComponents': old['components'],
                        'newComponents': new['components']})

def stats(rows):
    targets = [t for row in rows for t in row['targets']]
    return {'wholeCasesPassing': sum(all(t['lostPixels'] == 0 for t in row['targets']) for row in rows),
            'ownerObservationsPassing': sum(t['lostPixels'] == 0 for t in targets),
            'ownerObservations': len(targets), 'totalLostPixels': sum(t['lostPixels'] for t in targets)}

result = {'cases': 36, 'baseline': stats(base), 'candidate': stats(candidate),
          'sourceImageHashes': images, 'allSourceImagesAndMasksByteIdentical': True,
          'allSourceEnvelopesAndPixelCountsIdentical': True,
          'newlyFailedOwnerObservations': newly_failed,
          'worsenedOwnerObservations': worsened, 'changedCases': changes,
          'boundInputs': {str(p.relative_to(ROOT)): digest(p) for p in
                         [RUN/'controls.swift', RUN/'frozen-protocol.json',
                          RUN/'baseline/results.json', RUN/'candidate/results.json',
                          RUN/'baseline/controls', RUN/'candidate/controls']}}
(REPORT / 'comparison.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps({'baseline': result['baseline'], 'candidate': result['candidate'],
                  'changedCases': len(changes), 'newlyFailedOwners': len(newly_failed),
                  'worsenedOwners': len(worsened)}, indent=2))
