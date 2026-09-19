"""Run with the skill's Python environment: python -m unittest discover -s Tests/extraction."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import types
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("extract", ROOT/"skills/score-part-extraction/scripts/extract.py")
extract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extract)


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root/"source.pdf"
        pdf = extract.fitz.open()
        page = pdf.new_page(width=612,height=792)
        page.insert_text((55,110),"Selected source notation",fontsize=10)
        page.insert_text((55,220),"Neighbor must remain outside visible crop",fontsize=10)
        for y in [120,126,132,138,144]:
            page.draw_line((50,y),(570,y))
        pdf.save(self.source)
        pdf.close()
        self.recipe = {"schemaVersion":1,"source":"source.pdf","sourceSHA256":extract.digest(self.source),
            "title":"Pipeline test", "composer":"Test composer", "scopePages":[1],
            "parts":[{"name":"Part", "bands":[{"id":"p1s1","page":1,"system":"1","rect":[45,95,575,160]}]}]}

    def validate(self, recipe=None):
        with extract.fitz.open(self.source) as pdf:
            extract.validate_recipe(recipe or self.recipe,self.source,pdf)

    def build(self):
        self.recipe_path = self.root/"input.json"
        extract.save_json(self.recipe_path,self.recipe)
        self.output = self.root/"output"
        with contextlib.redirect_stdout(io.StringIO()):
            extract.build(types.SimpleNamespace(recipe=str(self.recipe_path),out=str(self.output)))
        return json.loads((self.output/"manifest.json").read_text())

    def test_source_and_native_coordinates_preserved(self):
        before = self.source.read_bytes()
        manifest = self.build()
        self.assertEqual(self.source.read_bytes(),before)
        bundle = next(self.output.glob("*.partsmithproject"))
        self.assertEqual((bundle/"source.pdf").read_bytes(),before)
        p = json.loads((bundle/"project.json").read_text())["project"]
        b = p["bands"][0]
        self.assertEqual(b["pageIndex"],0)
        self.assertAlmostEqual(b["rightFraction"],1-575/612)
        self.assertAlmostEqual(b["topFraction"],95/792)
        self.assertEqual(manifest["status"],"draft_needs_visual_review")
        pdf = extract.fitz.open(self.output/"Part.pdf")
        # Source is embedded as vector content, not flattened to an image.
        self.assertEqual(pdf[0].get_images(),[])
        self.assertGreater(len(pdf[0].get_drawings()),0)
        self.assertIn("Selected source notation",pdf[0].get_text())
        placement = manifest["parts"][0]["placements"][0]
        r = placement["destinationRect"]
        self.assertGreaterEqual(r[0],36)
        self.assertLessEqual(r[2],576)
        self.assertLessEqual(r[3],744)

    def test_delivered_recipe_is_portable(self):
        self.build()
        r = json.loads((self.output/"recipe.json").read_text())
        self.assertTrue((self.output/r["source"]).is_file())
        with contextlib.redirect_stdout(io.StringIO()):
            extract.build(types.SimpleNamespace(recipe=str(self.output/"recipe.json"),out=str(self.root/"rebuilt")))
        self.assertTrue((self.root/"rebuilt/Part.pdf").is_file())

    def test_wrong_source_fails(self):
        self.recipe["sourceSHA256"] = "wrong"
        with self.assertRaisesRegex(ValueError,"SHA256"):
            self.validate()

    def test_bad_crop_fails(self):
        for rect in ([50,100,40,150],[0,-1,570,150],[0,0,700,150],[0,0,float("nan"),150]):
            with self.subTest(rect=rect):
                r = copy.deepcopy(self.recipe)
                r["parts"][0]["bands"][0]["rect"] = rect
                with self.assertRaisesRegex(ValueError,"rectangle"):
                    self.validate(r)

    def test_duplicate_ids_and_unsafe_name_collisions_fail(self):
        self.recipe["parts"].append(copy.deepcopy(self.recipe["parts"][0]))
        self.recipe["parts"][1]["name"]="Different"
        with self.assertRaisesRegex(ValueError,"unique id"):
            self.validate()
        self.recipe["parts"][1]["name"]="PART"
        with self.assertRaisesRegex(ValueError,"filenames"):
            self.validate()

    def test_coverage_and_order_fail_closed(self):
        self.recipe["parts"][0]["bands"] = []
        with self.assertRaisesRegex(ValueError,"each scope page"):
            self.validate()
        self.recipe["parts"][0]["omittedPages"]={"1":""}
        with self.assertRaisesRegex(ValueError,"reason"):
            self.validate()

    def test_rotated_page_rejected_for_native_bridge(self):
        p = extract.fitz.open(self.source)
        p[0].set_rotation(90)
        p.save(self.root/"rotated.pdf")
        p.close()
        self.source = self.root/"rotated.pdf"
        self.recipe["sourceSHA256"] = extract.digest(self.source)
        with self.assertRaisesRegex(ValueError,"Rotated/CropBox"):
            self.validate()

    def test_exclusions_preserve_coordinates_and_reject_outside_crop(self):
        self.recipe["parts"][0]["bands"][0]["exclusions"]=[[400,95,500,102]]
        self.build()
        package=next(self.output.glob("*.partsmithproject"))
        band=json.loads((package/"project.json").read_text())["project"]["bands"][0]
        self.assertAlmostEqual(band["exclusions"][0]["topFraction"],95/792)
        self.assertAlmostEqual(band["exclusions"][0]["rightFraction"],1-500/612)
        self.recipe["parts"][0]["bands"][0]["exclusions"]=[[400,94,500,102]]
        with self.assertRaisesRegex(ValueError,"Exclusion"):
            self.validate()

    def test_unicode_musical_names_and_native_label_fields(self):
        self.recipe["parts"][0]["name"]="Clarinet in B♭"
        b=self.recipe["parts"][0]["bands"][0]
        b["label"]="Allegro — rehearsal A"
        b["pageBreakBefore"]=True
        self.build()
        pdf=extract.fitz.open(self.output/"Clarinet in B-.pdf")
        text=pdf[0].get_text()
        self.assertIn("Clarinet in B♭",text)
        self.assertIn("Allegro — rehearsal A",text)
        package=next(self.output.glob("*.partsmithproject"))
        band=json.loads((package/"project.json").read_text())["project"]["bands"][0]
        self.assertEqual(band["editorialLabel"],b["label"])
        self.assertTrue(band["pageBreakBefore"])

    def test_rebuild_is_atomic_and_removes_obsolete_parts_from_current_generation(self):
        extra=copy.deepcopy(self.recipe["parts"][0])
        extra["name"]="Obsolete"
        extra["bands"][0]["id"]="other-p1s1"
        self.recipe["parts"].append(extra)
        self.build()
        before={p.name:extract.digest(p) for p in self.output.glob("*.pdf")}
        before_manifest=(self.output/"manifest.json").read_bytes()
        self.recipe["parts"][0]["bands"][0]["label"]="Changed"
        self.recipe["parts"][1]["bands"][0]["rect"]=[0,0,20,792]
        with self.assertRaisesRegex(ValueError,"too tall"):
            self.build()
        self.assertEqual(before,{p.name:extract.digest(p) for p in self.output.glob("*.pdf")})
        self.assertEqual(before_manifest,(self.output/"manifest.json").read_bytes())
        self.recipe["parts"].pop()
        self.build()
        self.assertEqual([p.name for p in self.output.glob("*.pdf")],["Part.pdf"])
        backup=next(self.root.glob(".output-previous-*"))
        self.assertTrue((backup/"Obsolete.pdf").is_file())

    def test_output_cannot_replace_source_and_band_ids_are_paths_safe(self):
        self.recipe["parts"][0]["name"]="source"
        path=self.root/"input.json"
        extract.save_json(path,self.recipe)
        with self.assertRaisesRegex(ValueError,"overwrite"):
            extract.build(types.SimpleNamespace(recipe=str(path),out=str(self.root)))
        self.recipe["parts"][0]["bands"][0]["id"]="../../escape"
        with self.assertRaisesRegex(ValueError,"unique id"):
            self.validate()

    def test_review_requires_current_hashes_and_all_bands(self):
        m = self.build()
        report={"reviewer":"test", "outputSHA256":{p["file"]:p["sha256"] for p in m["parts"]},
            "reviewedBandIDs":["p1s1"],"checks":dict.fromkeys(["identity","coverage","cropEdges","globalMarkings","readability","pageTurns"],"pass"),
            "notes":"Synthetic test inspection record; not musical certification."}
        path=self.root/"review.json"
        extract.save_json(path,report)
        with contextlib.redirect_stdout(io.StringIO()):
            extract.verify(types.SimpleNamespace(out=str(self.output),review=str(path)))
        self.assertEqual(json.loads((self.output/"manifest.json").read_text())["status"],"reviewed")
        report["reviewedBandIDs"]=[]
        extract.save_json(path,report)
        with self.assertRaisesRegex(ValueError,"every band"):
            extract.verify(types.SimpleNamespace(out=str(self.output),review=str(path)))
        report["reviewedBandIDs"]=["p1s1"]
        extract.save_json(path,report)
        with (self.output/"Part.pdf").open("ab") as f:
            f.write(b"\n% changed after inspection\n")
        with self.assertRaisesRegex(ValueError,"changed"):
            extract.verify(types.SimpleNamespace(out=str(self.output),review=str(path)))


class DetectionBenchmarks(unittest.TestCase):
    def test_blank_page_has_no_staves(self):
        self.assertEqual(extract.detect(extract.Image.new("L",(900,1200),255))[0],[])

    def test_every_page_of_short_scores_and_scan_excerpt(self):
        cases=[("normal/04_choir/mozart_ave_verum_corpus_kv618_cpdl18715_complete_score.pdf",[16,16,16,16]),
               ("normal/03_piano_vocal/mozart_notte_e_giorno_don_giovanni_score.pdf",[13,15,15,15]),
               ("medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf",[16,20,20])]
        for filename,counts in cases:
            with extract.fitz.open(ROOT/"sample_scores"/filename) as pdf:
                for i,count in enumerate(counts):
                    with self.subTest(score=filename,page=i+1):
                        staves,_=extract.detect(extract.render(pdf[i]))
                        self.assertEqual(len(staves),count)


if __name__ == "__main__":
    unittest.main()
