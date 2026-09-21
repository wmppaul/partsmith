#!/usr/bin/env python3
"""Damage checks for complete native export provenance, not musical quality."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import run_corpus as runner


class ExportBindingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        package = self.root / "score.partsmithproject"
        package.mkdir()
        (package / "source.pdf").write_bytes(b"immutable source fixture")
        self.score = {"sha256": runner.digest(package / "source.pdf"), "pageCount": 1}
        self.profile = {"parts": [{"id": "violin1", "name": "Violin I"},
                                  {"id": "violin2", "name": "Violin II"}]}
        self.project = {"pageCount": 1, "parts": copy.deepcopy(self.profile["parts"]), "bands": []}
        self.plan = {"pages": [{"assignments": []}]}
        parts = []
        for index, part in enumerate(self.profile["parts"]):
            bands, placements = [], []
            for system in range(2):
                band = {"id": f"p1-s{system+1}-{part['id']}", "partID": part["id"],
                        "pageIndex": 0, "systemIndex": system, "candidateIDs": [index + 2 * system],
                        "topFraction": 0.1 + system * 0.3, "bottomFraction": 0.2 + system * 0.3}
                bands.append(band)
                self.project["bands"].append(copy.deepcopy(band))
                placements.append({"id": band["id"], "sourcePage": 1, "system": system + 1,
                                   "candidateIDs": band["candidateIDs"]})
            self.plan["pages"][0]["assignments"].extend(bands)
            file = f"{part['id']}.pdf"
            (self.root / file).write_bytes(part["id"].encode())
            parts.append({"id": part["id"], "placements": placements, "bandCount": 2,
                          "outputPages": 1, "file": file, "sha256": runner.digest(self.root / file)})
        self.manifest = {"sourceSHA256": self.score["sha256"], "profile": self.profile,
                         "parts": parts, "project": package.name, "rectifications": [],
                         "reviewedOverrides": []}

    def validate(self):
        (self.root / "manifest.json").write_text(json.dumps(self.manifest))
        (self.root / "score.partsmithproject" / "project.json").write_text(json.dumps({"project": self.project}))
        return runner.validate_exports(self.root, self.score, self.profile, self.plan)

    def test_complete_ensemble_is_accepted(self):
        self.assertEqual(len(self.validate()["parts"]), 2)

    def test_missing_duplicated_or_reordered_instrument_is_rejected(self):
        original = copy.deepcopy(self.manifest["parts"])
        for parts in (original[:1], [original[0], original[0]], original[::-1]):
            with self.subTest(parts=[p["id"] for p in parts]):
                self.manifest["parts"] = parts
                with self.assertRaises(ValueError):
                    self.validate()

    def test_missing_reordered_or_wrong_source_band_is_rejected(self):
        original = copy.deepcopy(self.manifest["parts"][0]["placements"])
        wrong_page = copy.deepcopy(original)
        wrong_page[0]["sourcePage"] = 2
        wrong_staff = copy.deepcopy(original)
        wrong_staff[0]["candidateIDs"] = [99]
        for placements in (original[:1], original[::-1], wrong_page, wrong_staff):
            with self.subTest(placements=placements):
                self.manifest["parts"][0]["placements"] = placements
                with self.assertRaises(ValueError):
                    self.validate()

    def test_source_profile_and_geometry_workflow_changes_are_rejected(self):
        for key, value in (("sourceSHA256", "changed"), ("profile", {"parts": []}),
                           ("rectifications", [{"page": 1}]), ("reviewedOverrides", [{"page": 1}])):
            with self.subTest(key=key):
                original = self.manifest[key]
                self.manifest[key] = value
                with self.assertRaises(ValueError):
                    self.validate()
                self.manifest[key] = original

    def test_changed_pdf_is_rejected(self):
        (self.root / "violin2.pdf").write_bytes(b"stale or damaged PDF")
        with self.assertRaises(ValueError):
            self.validate()

    def test_changed_embedded_source_is_rejected(self):
        (self.root / "score.partsmithproject" / "source.pdf").write_bytes(b"other edition")
        with self.assertRaises(ValueError):
            self.validate()

    def test_damaged_editable_project_is_rejected(self):
        original = copy.deepcopy(self.project)
        missing = copy.deepcopy(original)
        missing["bands"].pop()
        wrong_part = copy.deepcopy(original)
        wrong_part["bands"][0]["partID"] = "violin2"
        wrong_crop = copy.deepcopy(original)
        wrong_crop["bands"][0]["topFraction"] += 0.1
        excluded = copy.deepcopy(original)
        excluded["bands"][0]["excluded"] = True
        for project in (missing, wrong_part, wrong_crop, excluded):
            with self.subTest(project=project):
                self.project = project
                with self.assertRaises(ValueError):
                    self.validate()

    def test_live_exporter_is_not_restarted_as_inventory(self):
        progress = self.root / "progress.json"
        progress.write_text(json.dumps({"processID": 123, "sourceSHA256": self.score["sha256"],
                                        "phase": "export"}))
        with mock.patch.object(runner.os, "kill"), mock.patch.object(
                runner.subprocess, "check_output", return_value="/frozen/exporter --out parts"):
            self.assertIsNotNone(runner.live_native_process(progress, Path("/frozen/analyzer"),
                                                            self.score, Path("/frozen/exporter")))
            self.assertIsNone(runner.live_native_process(progress, Path("/frozen/analyzer"),
                                                         self.score, Path("/different/exporter")))


if __name__ == "__main__":
    unittest.main()
