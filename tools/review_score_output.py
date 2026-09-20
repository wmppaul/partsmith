#!/usr/bin/env python3
"""Render every native output page and assert structural export invariants.

This is review preparation, not a substitute for reading the score. The optional
independent source map checks expected systems and physical staff coverage.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile

import pymupdf as fitz
import numpy as np
from PIL import Image, ImageDraw


# Standalone reference: Foundation/CoreGraphics only; no Partsmith modules,
# detector, layout engine, crop selection, masks, or exported page content.
CORE_GRAPHICS_REFERENCE = r'''
import Foundation
import CoreGraphics
struct Placement: Decodable {
    let sourcePage: Int
    let sourceRect: [Double]
    let destinationRect: [Double]
    let outputWidth: Double
    let outputHeight: Double
    let sharedFragment: Bool
}
struct Request: Decodable { let source: String; let placements: [Placement] }
let request = try JSONDecoder().decode(Request.self,
    from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
guard let source = CGPDFDocument(URL(fileURLWithPath: request.source) as CFURL),
      let consumer = CGDataConsumer(url: URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL)
else { fatalError("Cannot open source/reference PDF") }
var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
guard let context = CGContext(consumer: consumer, mediaBox: &defaultBox, nil)
else { fatalError("Cannot create independent reference context") }
for p in request.placements {
    guard let page = source.page(at: p.sourcePage) else { fatalError("Missing source page") }
    precondition(page.rotationAngle == 0, "Reference requires unrotated source pages")
    let s = p.sourceRect, d = p.destinationRect
    let bounds = page.getBoxRect(.mediaBox)
    var pageBox = CGRect(x: 0, y: 0, width: p.outputWidth, height: p.outputHeight)
    let info = [kCGPDFContextMediaBox as String:
        NSData(bytes: &pageBox, length: MemoryLayout<CGRect>.size)] as CFDictionary
    context.beginPDFPage(info)
    if p.sharedFragment {
        context.clip(to: CGRect(x: d[0], y: p.outputHeight-d[3],
                              width: d[2]-d[0], height: d[3]-d[1]))
    }
    let sx = (d[2]-d[0])/(s[2]-s[0]), sy = (d[3]-d[1])/(s[3]-s[1])
    context.translateBy(x: d[0]-(bounds.minX+s[0])*sx,
        y: (p.outputHeight-d[3])-(bounds.maxY-s[3])*sy)
    context.scaleBy(x: sx, y: sy)
    context.drawPDFPage(page)
    context.endPDFPage()
}
context.closePDF()
'''


def vector_references(directory, manifest, source):
    """Normalize vector PDF serialization without altering source ink geometry.

    CoreGraphics rewrites vector path/glyph transforms at export precision. A
    direct MuPDF rendering can consequently differ along anti-aliased edges.
    Independently serialize the FULL original page at the checked placement;
    never use any native output content as the reference. Raw MuPDF differences
    remain in the report. Raster source pages use the direct source oracle.
    """
    vector_pages = {i for i, page in enumerate(source) if not page.get_images()}
    jobs, lookup = [], {}
    for part in manifest["parts"]:
        with fitz.open(directory / part["file"]) as output:
            for p in part["placements"]:
                if p["sourcePage"] - 1 not in vector_pages:
                    continue
                page = output[p["outputPage"] - 1]
                placements = [(p["sourceRect"], p["destinationRect"], False)]
                placements += [(m["sourceRect"], m["destinationRect"], True) for m in p["sourceMarkings"]]
                for index, (src, dst, shared) in enumerate(placements):
                    lookup[(part["id"], p["id"], index - 1)] = len(jobs)
                    jobs.append({"sourcePage": p["sourcePage"], "sourceRect": src,
                                 "destinationRect": dst, "outputWidth": page.rect.width,
                                 "outputHeight": page.rect.height, "sharedFragment": shared})
    if not jobs:
        return None, None, lookup
    compiler = shutil.which("swiftc")
    assert compiler, "Exact vector serialization reference requires macOS swiftc/CoreGraphics"
    temporary = tempfile.TemporaryDirectory(prefix="partsmith-pixel-reference-")
    work = Path(temporary.name)
    (work / "reference.swift").write_text(CORE_GRAPHICS_REFERENCE)
    (work / "request.json").write_text(json.dumps({"source": str(Path(manifest["source"]).resolve()),
                                                  "placements": jobs}))
    subprocess.run([compiler, "-module-cache-path", str(work / "module-cache"),
                    str(work / "reference.swift"), "-o", str(work / "reference")], check=True)
    subprocess.run([str(work / "reference"), str(work / "request.json"), str(work / "reference.pdf")], check=True)
    return temporary, fitz.open(work / "reference.pdf"), lookup


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def normalized_manifest_digest(manifest):
    """Bind reviewed metadata while allowing the finalizer's review-state stamp."""
    reviewed = {key: value for key, value in manifest.items() if key not in {"status", "reviewRecord"}}
    canonical = json.dumps(reviewed, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def rect(values):
    assert len(values) == 4 and all(math.isfinite(v) for v in values)
    value = fitz.Rect(values)
    assert not value.is_empty and not value.is_infinite
    return value


def source_reference(output_page, source, source_index, source_rect, destination_rect, scale,
                     shared_fragment=False):
    """Place the untrimmed original at the independently specified transform.

    show_pdf_page serializes its wrapper matrix with only five decimal places.
    For example, 516/595.2 becomes .86694, moving a 7009-pixel bitonal image
    enough to change its downsampling phase. That produces many false pixel
    differences even though native output retained every source image sample.
    Keep the original PDF content and image dictionaries untouched, and replace
    only this *reference* wrapper's placement matrix at adequate precision.
    """
    source_page = source[source_index]
    # This oracle maps the same unrotated, axis-aligned source coordinates used
    # by the native manifest. Do not silently approximate unsupported rotation.
    assert source_page.rotation == 0, "Pixel reference requires unrotated source pages"
    reference = fitz.open()
    baseline_page = reference.new_page(width=output_page.rect.width, height=output_page.rect.height)
    destination = fitz.Rect(
        destination_rect.x0 - source_rect.x0 * scale,
        destination_rect.y0 - source_rect.y0 * scale,
        destination_rect.x0 + (source_page.rect.width - source_rect.x0) * scale,
        destination_rect.y0 + (source_page.rect.height - source_rect.y0) * scale)
    baseline_page.show_pdf_page(destination, source, source_index)
    wrappers = [item[0] for item in baseline_page.get_xobjects() if item[2] == 0]
    assert len(wrappers) == 1, "Ambiguous source reference wrapper"
    # The outer form uses the source crop box in PDF bottom-up coordinates.
    # Respect its origin rather than assuming that it starts at (0, 0).
    kind, value = reference.xref_get_key(wrappers[0], "BBox")
    assert kind == "array"
    bounds = rect([float(v) for v in value.strip("[]").split()])
    tx = destination.x0 - bounds.x0 * scale
    ty = output_page.rect.height - destination.y1 - bounds.y0 * scale
    reference.xref_set_key(wrappers[0], "Matrix",
                           f"[{scale:.12f} 0 0 {scale:.12f} {tx:.12f} {ty:.12f}]")
    if shared_fragment:
        # A shared cue is the independently reviewed source rectangle itself.
        # Match that rectangle's clip: MuPDF's bitonal resampling phase depends
        # on the visible image extent, even when its image transform is equal.
        # Main staff guards deliberately keep the untrimmed reference instead.
        streams = baseline_page.get_contents()
        assert len(streams) == 1
        clip = (f"q {destination_rect.x0:.12f} "
                f"{output_page.rect.height - destination_rect.y1:.12f} "
                f"{destination_rect.width:.12f} {destination_rect.height:.12f} re W n ").encode()
        reference.update_stream(streams[0], clip + baseline_page.read_contents() + b" Q")
    return reference, baseline_page


def review(directory, map_path=None, pixels=False):
    directory = Path(directory)
    manifest = json.loads((directory / "manifest.json").read_text())
    map_bytes = Path(map_path).read_bytes() if map_path else None
    mapping = json.loads(map_bytes) if map_bytes is not None else None
    bindings = {"sourceMapSHA256": hashlib.sha256(map_bytes).hexdigest() if map_bytes is not None else None,
                "normalizedManifestSHA256": normalized_manifest_digest(manifest)}
    assert digest(manifest["source"]) == manifest["sourceSHA256"]
    source = fitz.open(manifest["source"])
    out = directory / "review"
    out.mkdir(exist_ok=True)
    report = {"status": "geometry_pass_visual_review_pending", "sourceSHA256": manifest["sourceSHA256"],
              **bindings, "parts": []}
    protected = {}
    if mapping:
        for page in mapping["pages"]:
            for system in page.get("systems", []):
                for band in system["bands"]:
                    protected[(page["pageIndex"] + 1, system["systemIndex"] + 1, band["partID"])] = band.get("protectedRegions", [])
    pixel_results = []
    vector_work, vector_pdf, vector_lookup = vector_references(directory, manifest, source) if pixels else (None, None, {})
    for part in manifest["parts"]:
        assert digest(directory / part["file"]) == part["sha256"]
        pdf = fitz.open(directory / part["file"])
        assert len(pdf) == part["outputPages"] and len(part["placements"]) == part["bandCount"]
        identities = [(p["sourcePage"], p["system"]) for p in part["placements"]]
        assert identities == sorted(set(identities)), (part["name"], "Duplicate/reordered source system")
        if mapping:
            expected = [(p["pageIndex"] + 1, s + 1) for p in mapping["pages"] for s in range(p["expectedSystems"])]
            assert identities == expected, (part["name"], "Missing or extra source systems")
        by_page = {}
        heights = []
        for p in part["placements"]:
            src, dst = rect(p["sourceRect"]), rect(p["destinationRect"])
            assert (source[p["sourcePage"] - 1].rect + (-0.0001, -0.0001, 0.0001, 0.0001)).contains(src)
            assert pdf[p["outputPage"] - 1].rect.contains(dst)
            scale = dst.width / src.width
            assert abs(dst.height / src.height - scale) < 1e-6
            for lines in p["staffLineYs"]:
                assert len(lines) == 5 and src.y0 <= min(lines) < max(lines) <= src.y1
                heights.append((max(lines) - min(lines)) * scale)
            previous = by_page.get(p["outputPage"])
            if previous:
                assert previous.y1 <= dst.y0, "Music strips overlap"
            by_page[p["outputPage"]] = dst
            for marking in p["sourceMarkings"]:
                ms, md = rect(marking["sourceRect"]), rect(marking["destinationRect"])
                assert pdf[p["outputPage"] - 1].rect.contains(md)
                assert md.y1 <= dst.y0, "Shared direction overlaps target music"
                assert abs(md.width / ms.width - scale) < 1e-6
                assert abs(md.height / ms.height - scale) < 1e-6
            if pixels:
                guards = protected.get((p["sourcePage"], p["system"], part["id"]), [])
                assert guards, f"No independent protected regions for {p['id']}"
                compare = [(g["rect"], src, dst, g["description"], False, -1) for g in guards]
                compare += [(m["sourceRect"], rect(m["sourceRect"]), rect(m["destinationRect"]), "Verified shared source direction", True, index)
                            for index, m in enumerate(p["sourceMarkings"])]
                for values, source_rect, destination_rect, description, shared_fragment, fragment_index in compare:
                    region = rect(values)
                    assert (source_rect + (-0.0001, -0.0001, 0.0001, 0.0001)).contains(region), f"Crop cuts protected target: {p['id']}: {description}"
                    output_page = pdf[p["outputPage"] - 1]
                    reference, baseline_page = source_reference(
                        output_page, source, p["sourcePage"] - 1, source_rect, destination_rect, scale, shared_fragment)
                    target = fitz.Rect(destination_rect.x0 + (region.x0-source_rect.x0)*scale,
                                       destination_rect.y0 + (region.y0-source_rect.y0)*scale,
                                       destination_rect.x0 + (region.x1-source_rect.x0)*scale,
                                       destination_rect.y0 + (region.y1-source_rect.y0)*scale)
                    a = output_page.get_pixmap(dpi=216, clip=target, colorspace=fitz.csGRAY)
                    b = baseline_page.get_pixmap(dpi=216, clip=target, colorspace=fitz.csGRAY)
                    aa, bb = np.frombuffer(a.samples, dtype=np.uint8), np.frombuffer(b.samples, dtype=np.uint8)
                    assert aa.size > 0 and (a.width, a.height) == (b.width, b.height) and aa.shape == bb.shape
                    raw_difference = difference = int(np.count_nonzero(aa != bb))
                    normalization = "none"
                    vector_index = vector_lookup.get((part["id"], p["id"], fragment_index))
                    if vector_index is not None:
                        canonical = vector_pdf[vector_index].get_pixmap(dpi=216, clip=target, colorspace=fitz.csGRAY)
                        cc = np.frombuffer(canonical.samples, dtype=np.uint8)
                        assert (canonical.width, canonical.height) == (a.width, a.height) and cc.shape == aa.shape
                        difference = int(np.count_nonzero(aa != cc))
                        normalization = "independent_full_source_CoreGraphics_vector_serialization"
                    pixel_results.append({"bandID": p["id"], "description": description,
                                          "referenceExtent": "reviewed_shared_fragment" if shared_fragment else "untrimmed_source",
                                          "normalization": normalization, "rawDifferentPixels": raw_difference,
                                          "pixels": int(aa.size), "differentPixels": difference})
                    reference.close()
        images = []
        for i, page in enumerate(pdf):
            filename = f"{part['id']}-{i+1:03}.png"
            page.get_pixmap(dpi=120, alpha=False).save(out / filename)
            with Image.open(out / filename) as image:
                thumb = image.convert("RGB")
                thumb.thumbnail((510, 690))
                images.append(thumb.copy())
        for start in range(0, len(images), 4):
            selected = images[start:start+4]
            sheet = Image.new("RGB", (1040, 1450 if len(selected) > 2 else 730), "#eeeeee")
            draw = ImageDraw.Draw(sheet)
            for index, image in enumerate(selected):
                x, y = (index % 2) * 520, (index // 2) * 725
                draw.text((x + 10, y + 5), f"{part['name']} / output page {start+index+1}", fill="black")
                sheet.paste(image, (x + 5, y + 25))
            sheet.save(out / f"{part['id']}-contact-{start//4+1:02}.jpg", quality=92)
        report["parts"].append({"id": part["id"], "sha256": part["sha256"], "outputPages": len(pdf),
                                "systems": len(identities), "staffHeightPoints": [min(heights), max(heights)]})
        print(part["name"], len(pdf), "pages;", len(identities), "systems; staff heights", round(min(heights), 2), "to", round(max(heights), 2), "pt")
    (out / "geometry.json").write_text(json.dumps(report, indent=2) + "\n")
    if pixels:
        pixel_report = {"sourceSHA256": manifest["sourceSHA256"], **bindings,
                        "outputs": {p["file"]: p["sha256"] for p in manifest["parts"]},
                        "method": "exact_216dpi_grayscale_source_comparison; 12_digit_reference_transform; independent_CoreGraphics_serialization_for_vector_sources",
                        "tolerance": 0, "sourceContentOrImageDictionariesModified": False,
                        "status": "pass" if all(p["differentPixels"] == 0 for p in pixel_results) else "fail", "regions": pixel_results}
        (out / "pixel-fidelity.json").write_text(json.dumps(pixel_report, indent=2) + "\n")
        if vector_pdf is not None:
            vector_pdf.close()
            vector_work.cleanup()
        assert pixel_report["status"] == "pass", "Native output differs from untrimmed source in protected regions; inspect pixel-fidelity.json"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory")
    parser.add_argument("--map")
    parser.add_argument("--pixels", action="store_true", help="Compare every independently protected region against an untrimmed source rendering")
    args = parser.parse_args()
    review(args.directory, args.map, args.pixels)
