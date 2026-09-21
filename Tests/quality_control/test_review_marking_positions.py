#!/usr/bin/env python3
"""Damage controls for annotation-side and whole-system collision review."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import pymupdf as fitz

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('reviewer', ROOT / 'tools/review_score_output.py')
reviewer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reviewer)

class MarkingPositionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        source = self.directory / 'source.pdf'
        output = self.directory / 'part.pdf'
        with fitz.open() as doc:
            page = doc.new_page(width=612, height=792)
            page.insert_text((100, 70), 'Da Capo')
            page.draw_line((50, 120), (550, 120))
            doc.save(source)
            doc.save(output)
        band = {'id': 'p1-s1-vln', 'sourcePage': 1, 'system': 1, 'candidateIDs': [0],
                'sourceRect': [50, 100, 550, 180], 'destinationRect': [50, 200, 550, 280],
                'outputPage': 1, 'staffLineYs': [[120, 125, 130, 135, 140]],
                'sourceMarkings': [
                    {'sourceRect': [100, 50, 150, 62], 'destinationRect': [100, 180, 150, 192]},
                    {'sourceRect': [100, 50, 150, 62], 'destinationRect': [100, 286, 150, 298], 'isBelow': True}]}
        following = copy.deepcopy(band)
        following.update(id='p1-s2-vln', system=2, destinationRect=[50, 330, 550, 410], sourceMarkings=[])
        self.manifest = {'source': str(source), 'sourceSHA256': reviewer.digest(source),
                         'parts': [{'id': 'vln', 'name': 'Violin', 'file': output.name,
                                    'sha256': reviewer.digest(output), 'outputPages': 1, 'bandCount': 2,
                                    'placements': [band, following]}]}

    def run_review(self):
        (self.directory / 'manifest.json').write_text(json.dumps(self.manifest))
        reviewer.review(self.directory)

    @property
    def bands(self):
        return self.manifest['parts'][0]['placements']

    def test_valid_above_and_below_at_same_bar(self):
        self.run_review()

    def test_below_direction_moved_above_rejected(self):
        self.bands[0]['sourceMarkings'][1]['destinationRect'] = [100, 160, 150, 172]
        with self.assertRaisesRegex(AssertionError, 'precedes target'):
            self.run_review()

    def test_legacy_above_direction_moved_below_rejected(self):
        self.bands[0]['sourceMarkings'][0]['destinationRect'] = [100, 300, 150, 312]
        with self.assertRaisesRegex(AssertionError, 'overlaps target'):
            self.run_review()

    def test_below_direction_crosses_next_music_rejected(self):
        self.bands[0]['sourceMarkings'][1]['destinationRect'] = [100, 325, 150, 337]
        with self.assertRaisesRegex(AssertionError, 'directions overlap'):
            self.run_review()

    def test_above_direction_crosses_previous_music_rejected(self):
        self.bands[1]['sourceMarkings'] = [{'sourceRect': [100, 50, 150, 62],
                                         'destinationRect': [100, 275, 150, 287]}]
        with self.assertRaisesRegex(AssertionError, 'directions overlap'):
            self.run_review()

    def test_two_directions_overprint_rejected(self):
        self.bands[0]['sourceMarkings'].append(copy.deepcopy(self.bands[0]['sourceMarkings'][1]))
        with self.assertRaisesRegex(AssertionError, 'Shared directions overlap'):
            self.run_review()

if __name__ == '__main__':
    unittest.main()
