#!/usr/bin/env python3
"""Compare protected target regions with an unclipped source-page rendering.

A visual reviewer defines the target regions first. This checks export fidelity
there; it cannot discover unrecorded notes or establish musical completeness.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import pymupdf as fitz


def check(output):
    output = Path(output)
    recipe = json.loads((output / 'recipe.json').read_text())
    manifest = json.loads((output / 'manifest.json').read_text())
    def digest(path):
        return hashlib.sha256(Path(path).read_bytes()).hexdigest()
    if digest(output/'recipe.json') != manifest['recipeSHA256']:
        raise AssertionError('Recipe changed after build')
    if digest(output/recipe['source']) != recipe['sourceSHA256'] or recipe['sourceSHA256'] != manifest['sourceSHA256']:
        raise AssertionError('Source bytes changed')
    def rectangle(value, name):
        if (len(value) != 4 or not all(type(v) in (float,int) and math.isfinite(v) for v in value)
            or value[0] >= value[2] or value[1] >= value[3]):
            raise AssertionError(f'Invalid {name} rectangle')
        return fitz.Rect(value)
    source = fitz.open(output / recipe['source'])
    findings = []
    recipe_parts = {p['name']:p for p in recipe['parts']}
    if {p['name'] for p in manifest['parts']} != set(recipe_parts):
        raise AssertionError('Part coverage differs from recipe')
    for part in manifest['parts']:
        if digest(output/part['file']) != part['sha256']:
            raise AssertionError('Output changed after build')
        bands = {b['id']:b for b in recipe_parts[part['name']]['bands']}
        if len(part['placements']) != len(bands) or {p['id'] for p in part['placements']} != set(bands):
            raise AssertionError('Band coverage differs from recipe')
        final = fitz.open(output / part['file'])
        for placement in part['placements']:
            band = bands[placement['id']]
            if (placement['sourceRect'] != band['rect'] or placement['sourcePage'] != band['page']
                or not placement.get('protectedRegions') or placement['protectedRegions'] != band['protectedRegions']):
                raise AssertionError('Every band must retain its reviewed source and protected regions')
            src = rectangle(placement['sourceRect'],'source')
            dst = rectangle(placement['destinationRect'],'destination')
            if type(placement['outputPage']) is not int or not 1 <= placement['outputPage'] <= len(final):
                raise AssertionError('Output page does not exist')
            page = final[placement['outputPage'] - 1]
            if not page.rect.contains(dst):
                raise AssertionError('Destination must be fully inside output page')
            scale = dst.width / src.width
            source_page = source[placement['sourcePage'] - 1]
            if not source_page.rect.contains(src) or abs(dst.height-src.height*scale) > 0.0001:
                raise AssertionError('Source bounds or aspect ratio invalid')
            # Full source page, no clip and no whiteouts; apply the same placement.
            reference = fitz.open()
            expected = reference.new_page(width=page.rect.width, height=page.rect.height)
            full = fitz.Rect(dst.x0 - src.x0 * scale, dst.y0 - src.y0 * scale,
                             dst.x0 + (source_page.rect.width-src.x0) * scale,
                             dst.y0 + (source_page.rect.height-src.y0) * scale)
            expected.show_pdf_page(full, source, placement['sourcePage'] - 1)
            for protected in placement['protectedRegions']:
                region = rectangle(protected['rect'],'protected')
                if not src.contains(region):
                    raise AssertionError(f"Crop omits protected target: {placement['id']}")
                for mask in placement.get('exclusions', []):
                    if region.intersects(fitz.Rect(mask)):
                        raise AssertionError(f"Whiteout intersects target: {placement['id']}")
                target = fitz.Rect(dst.x0+(region.x0-src.x0)*scale, dst.y0+(region.y0-src.y0)*scale,
                                   dst.x0+(region.x1-src.x0)*scale, dst.y0+(region.y1-src.y0)*scale)
                if not page.rect.contains(target):
                    raise AssertionError('Protected target must be fully inside output page')
                actual = page.get_pixmap(dpi=216, clip=target, colorspace=fitz.csGRAY)
                baseline = expected.get_pixmap(dpi=216, clip=target, colorspace=fitz.csGRAY)
                a = np.frombuffer(actual.samples, dtype=np.uint8)
                b = np.frombuffer(baseline.samples, dtype=np.uint8)
                if not a.size or not b.size or (actual.width,actual.height) != (baseline.width,baseline.height) or a.shape != b.shape:
                    raise AssertionError('Protected-region comparison requires nonempty equal-sized renders')
                difference = int(np.count_nonzero(a != b))
                findings.append({'bandID': placement['id'], 'description': protected['description'],
                                 'differentPixels': difference, 'pixels': int(a.size)})
            reference.close()
        final.close()
    source.close()
    return {'output': output.name, 'regionCount': len(findings),
            'pass': bool(findings) and all(r['differentPixels'] == 0 for r in findings), 'regions': findings}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', nargs='+')
    parser.add_argument('--report')
    args = parser.parse_args()
    results = [check(p) for p in args.output]
    content = json.dumps(results, indent=2) + '\n'
    if args.report:
        Path(args.report).write_text(content)
    print(content)
    raise SystemExit(0 if all(r['pass'] for r in results) else 1)
