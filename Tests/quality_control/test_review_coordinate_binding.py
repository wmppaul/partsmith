#!/usr/bin/env python3
"""Ensure raw/rectified score guards cannot silently validate the wrong image."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

import pymupdf as fitz

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("reviewer", ROOT / "tools/review_score_output.py")
reviewer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reviewer)


class CoordinateBindingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        self.source = self.directory / "original.pdf"
        self.corrected = self.directory / "corrected.pdf"
        self.make_pdf(self.source, 2)
        self.make_pdf(self.corrected, 2)
        self.corrections = [{"pageIndex": 0, "rotationDegrees": 1.25}]
        self.manifest = {"source": str(self.source), "sourceSHA256": reviewer.digest(self.source),
                         "rectifications": self.corrections,
                         "reviewSourceFile": self.corrected.name,
                         "reviewSourceSHA256": reviewer.digest(self.corrected)}
        self.mapping = {"sourceSHA256": self.manifest["sourceSHA256"],
                        "rectifications": self.corrections}

    @staticmethod
    def make_pdf(path, count, width=612):
        with fitz.open() as doc:
            for i in range(count):
                page = doc.new_page(width=width, height=792)
                page.insert_text((72, 72), f"Coordinate binding fixture {i}")
            doc.save(path)

    def check(self, manifest=None, mapping=None):
        return reviewer.review_source_path(self.directory, manifest or self.manifest,
                                           self.mapping if mapping is None else mapping)

    def test_matching_corrected_coordinates(self):
        self.assertEqual(self.check(), self.corrected)

    def test_legacy_raw_coordinates(self):
        manifest = {k: v for k, v in self.manifest.items() if k in {"source", "sourceSHA256"}}
        self.assertEqual(self.check(manifest, {"sourceSHA256": manifest["sourceSHA256"]}), self.source)

    def test_raw_guards_reject_corrected_output(self):
        with self.assertRaisesRegex(AssertionError, "page corrections"):
            self.check(mapping={"sourceSHA256": self.mapping["sourceSHA256"]})

    def test_corrected_guards_reject_raw_output(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["rectifications"] = []
        with self.assertRaisesRegex(AssertionError, "page corrections"):
            self.check(manifest)

    def test_different_correction_rejected(self):
        mapping = copy.deepcopy(self.mapping)
        mapping["rectifications"][0]["rotationDegrees"] += 0.01
        with self.assertRaisesRegex(AssertionError, "page corrections"):
            self.check(mapping=mapping)

    def test_unrelated_source_map_rejected(self):
        mapping = dict(self.mapping, sourceSHA256="0" * 64)
        with self.assertRaisesRegex(AssertionError, "different score"):
            self.check(mapping=mapping)

    def test_missing_corrected_source_rejected(self):
        manifest = copy.deepcopy(self.manifest)
        del manifest["reviewSourceFile"]
        with self.assertRaisesRegex(AssertionError, "hashed, full-page"):
            self.check(manifest)

    def test_changed_corrected_source_rejected(self):
        with self.corrected.open("ab") as stream:
            stream.write(b"\n% altered\n")
        with self.assertRaisesRegex(AssertionError, "hash differs"):
            self.check()

    def test_corrected_source_cannot_drop_pages(self):
        self.corrected.unlink()
        self.make_pdf(self.corrected, 1)
        self.manifest["reviewSourceSHA256"] = reviewer.digest(self.corrected)
        with self.assertRaisesRegex(AssertionError, "every source page"):
            self.check()

    def test_corrected_source_cannot_resize_pages(self):
        self.corrected.unlink()
        self.make_pdf(self.corrected, 2, width=595)
        self.manifest["reviewSourceSHA256"] = reviewer.digest(self.corrected)
        with self.assertRaisesRegex(AssertionError, "page dimensions"):
            self.check()


if __name__ == "__main__":
    unittest.main()
