#!/usr/bin/env python3
"""Regenerate metadata-only native overrides from reviewed cues and current crops.

No detector identities or native crop rectangles are replaced. Re-run after changing
native compact settings: a verified source fragment is copied only when that
part's main crop does not completely contain it.
"""
import argparse
import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def contains(outer, inner):
    return all((outer[i] <= inner[i] + 1e-6 if i < 2 else outer[i] >= inner[i] - 1e-6) for i in range(4))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--map', type=Path, default=REPO / 'Tests/full_scores/brahms-quartet-tight-map.json')
    args = parser.parse_args()
    score = json.loads(args.map.read_text())
    manifest = json.loads(args.manifest.read_text())
    if manifest.get('sourceSHA256') != score.get('sourceSHA256'):
        raise ValueError('The native manifest and reviewed source map refer to different PDFs')
    expected_parts = {p['id'] for p in score['profile']['parts']}
    if {p['id'] for p in manifest['parts']} != expected_parts:
        raise ValueError('Native manifest instrument identities do not match the reviewed quartet')
    placements = {(p['sourcePage'] - 1, p['system'] - 1, part['id']): p
                  for part in manifest['parts'] for p in part['placements'] if p['kind'] == 'music'}
    cues = {}
    for cue in score['sharedMarkings']:
        cues.setdefault((cue['pageIndex'], cue['systemIndex']), []).append(cue)
    output, copied, retained = [], [], []
    for page in score['pages']:
        systems = []
        for system in page['systems']:
            bands = []
            for band in system['bands']:
                key = (page['pageIndex'], system['systemIndex'], band['partID'])
                if key not in placements:
                    raise ValueError(f'Missing native placement for {key}')
                crop = placements[key]['sourceRect']
                fragments = []
                for cue in cues.get(key[:2], []):
                    if band['partID'] not in cue['targetPartIDs']:
                        continue
                    entry = {'pageIndex': key[0], 'systemIndex': key[1], 'partID': key[2],
                             'text': cue['text'], 'rect': cue['rect']}
                    if contains(crop, cue['rect']):
                        retained.append(entry)
                    elif cue['rect'] not in fragments:
                        fragments.append(cue['rect'])
                        copied.append(entry)
                item = {'partID': band['partID'], 'candidateIDs': band['candidateIDs'], 'sourceMarkings': fragments}
                if band.get('pageBreakBefore'):
                    item['pageBreakBefore'] = True
                bands.append(item)
            item = {'systemIndex': system['systemIndex'], 'bands': bands, 'omittedParts': system.get('omittedParts', [])}
            if system.get('movementLabel'):
                item['movementLabel'] = system['movementLabel']
            systems.append(item)
        output.append({'pageIndex': page['pageIndex'],
                       'reason': 'Reviewed source instrument identities, movement boundaries and original common directions/printed measure-gutter labels. Native detector and compact crop rectangles are unchanged. Source fragments copied only where the current crop omits their complete rectangle.',
                       'systems': systems})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2) + '\n')
    record = {'sourceMapSHA256': hashlib.sha256(args.map.read_bytes()).hexdigest(),
              'manifestSHA256': hashlib.sha256(args.manifest.read_bytes()).hexdigest(),
              'copiedFragmentCount': len(copied), 'retainedInMainCount': len(retained),
              'copiedFragments': copied, 'retainedInMain': retained,
              'note': 'Re-run whenever native crops change. No geometry override or image cleanup is introduced.'}
    record_path = args.output.with_suffix('.evidence.json')
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'overrideFile': str(args.output), 'evidenceFile': str(record_path),
                      'copiedFragments': len(copied), 'retainedInMain': len(retained)}, indent=2))


if __name__ == '__main__':
    main()
