#!/usr/bin/env python3
"""Geometry-first score extraction. Coordinates are top-down PDF points.

analyze produces hypotheses, never instrument assignments. build requires a
reviewable recipe; final output requires a separate, recorded visual review.
"""
import argparse
import contextlib
import hashlib
import io
import json
import math
from pathlib import Path
import re
import shutil
import sys
import tempfile
import uuid
from datetime import datetime, timezone

import numpy as np
from PIL import Image, ImageDraw
import pymupdf as fitz


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + "\n")


def render(page, dpi=144):
    pix = page.get_pixmap(dpi=dpi, colorspace=fitz.csGRAY, alpha=False)
    return Image.frombytes("L", (pix.width, pix.height), pix.samples)


def page_indices(value, count):
    if not value:
        return list(range(count))
    pages = []
    for token in value.split(","):
        bounds = [int(s) for s in token.split("-")]
        pages.extend(range(bounds[0] - 1, bounds[-1]))
    if not pages or len(set(pages)) != len(pages) or any(p < 0 or p >= count for p in pages):
        raise ValueError("Page range must contain unique existing pages (one-based).")
    return sorted(pages)


def detect(image):
    """Five regularly spaced long lines; rotation is analysis-only."""
    small = image.copy()
    small.thumbnail((1100, 1600))
    def response(im):
        a = np.asarray(im) < 210
        return a[:, int(a.shape[1]*.12):int(a.shape[1]*.94)].mean(axis=1)
    angles = np.arange(-2.0, 2.01, .2)
    scores = []
    for angle in angles:
        prof = response(small.rotate(float(angle), resample=Image.Resampling.BILINEAR, fillcolor=255))
        scores.append(float(np.sum(prof[prof > .22] ** 2)))
    angle = float(angles[int(np.argmax(scores))])
    if abs(angle) < .11:
        angle = 0.0
    leveled = image.rotate(angle, resample=Image.Resampling.BILINEAR, fillcolor=255)
    profile = response(leveled)
    active = profile > max(.23, float(profile.max()) * .4)
    # Connected threshold runs merge staff lines when dense beams fill the gap.
    # Keep local maxima instead, collapsing only the thickness of a single line.
    maxima = active.copy()
    for delta in (-2, -1, 1, 2):
        maxima &= profile >= np.roll(profile, delta)
    selected = []
    for y in sorted(np.flatnonzero(maxima), key=lambda y: -profile[y]):
        if all(abs(y-other) > 2 for other in selected):
            selected.append(int(y))
    peaks = sorted(float(y) for y in selected)
    staves = []
    i = 0
    while i + 4 < len(peaks):
        ys = peaks[i:i+5]
        gaps = np.diff(ys)
        gap = float(np.median(gaps))
        if 3 <= gap <= 35 and float(np.max(abs(gaps-gap))) <= max(1.5, gap*.18):
            staves.append({"lines": ys, "spacing": gap})
            i += 5
        else:
            i += 1
    # Envelope for the original sloped staff. Crops always refer to original PDF.
    envelope = abs(math.sin(math.radians(angle))) * image.width / 2
    for i, staff in enumerate(staves):
        lo, hi = staff["lines"][0], staff["lines"][-1]
        pad = staff["spacing"] * 3.2 + envelope
        top = max(0, lo-pad)
        bottom = min(image.height, hi+pad)
        if i:
            top = max(top, (staves[i-1]["lines"][-1]+lo)/2)
        if i+1 < len(staves):
            bottom = min(bottom, (hi+staves[i+1]["lines"][0])/2)
        staff.update(index=i+1, top=top, bottom=bottom)
    return staves, angle


def analyze(args):
    source = Path(args.source).resolve()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(source)
    if doc.needs_pass:
        raise ValueError("Encrypted score needs an unlocked input copy.")
    analysis = {"schemaVersion": 1, "source": str(source), "sourceSHA256": digest(source),
                "pageCount": len(doc), "coordinates": "top-down PDF points", "pages": []}
    for index in page_indices(args.pages, len(doc)):
        page = doc[index]
        im = render(page)
        staves, angle = detect(im)
        factor = page.rect.height / im.height
        annotated = im.convert("RGB")
        draw = ImageDraw.Draw(annotated)
        entries = []
        for s in staves:
            draw.rectangle((0, s["top"], im.width-1, s["bottom"]), outline="#d24b18", width=2)
            draw.text((8, s["lines"][0]), str(s["index"]), fill="#cc0000", stroke_width=1)
            entries.append({"index": s["index"], "lines": [round(y*factor, 3) for y in s["lines"]],
                            "suggestedRect": [0, round(s["top"]*factor,3), round(page.rect.width,3), round(s["bottom"]*factor,3)]})
        filename = f"page-{index+1:03d}.png"
        annotated.save(out/filename)
        analysis["pages"].append({"page":index+1, "width":page.rect.width, "height":page.rect.height,
                                  "analysisRotationDegrees":round(angle,2), "staves":entries,
                                  "reviewImage":filename, "status":"needs_visual_review"})
    save_json(out/"analysis.json", analysis)
    print(json.dumps({"analysis":str(out/"analysis.json"),"staffCounts":{p["page"]:len(p["staves"]) for p in analysis["pages"]}}))


def safe_name(value):
    return re.sub(r"[^\w .()-]", "-", value).strip(" .") or "Part"


def text_box(page, rect, text, fontsize, align=0):
    # Compose off-page first so a failed fit never silently drops a title.
    fontname = "helv"
    if any(ord(c) > 127 for c in text):
        font = fitz.Font("cjk")
        if any(not c.isspace() and not font.has_glyph(ord(c)) for c in text):
            raise ValueError("Header or label contains a character unsupported by the embedded font.")
        fontname = "PartsmithUnicode"
        page.insert_font(fontname=fontname, fontbuffer=font.buffer)
    for size in np.arange(fontsize, 6.9, -0.5):
        shape = page.new_shape()
        if shape.insert_textbox(rect, text, fontname=fontname, fontsize=float(size), align=align) >= 0:
            shape.commit()
            return
    raise ValueError("Header text cannot fit; shorten the title or part name.")


def validate_recipe(recipe, source, doc):
    if recipe.get("schemaVersion") != 1:
        raise ValueError("Recipe schemaVersion must be 1.")
    if recipe.get("sourceSHA256") != digest(source):
        raise ValueError("Source SHA256 mismatch; re-analyze the intended PDF.")
    policy = recipe.get("notationPolicy", "clean-isolation")
    if policy not in ("preserve-target", "clean-isolation"):
        raise ValueError("notationPolicy must be preserve-target or clean-isolation.")
    scope = recipe.get("scopePages", [])
    if not scope or scope != sorted(set(scope)) or any(type(p) is not int or p < 1 or p > len(doc) for p in scope):
        raise ValueError("scopePages must be sorted, unique existing one-based pages.")
    if not recipe.get("parts"):
        raise ValueError("Recipe has no parts.")
    names = set()
    ids = set()
    for part in recipe["parts"]:
        name = safe_name(part["name"]).casefold()
        if name in names:
            raise ValueError("Part names must have unique sanitized filenames.")
        names.add(name)
        accounted = set(part.get("omittedPages", {}).keys())
        for p, reason in part.get("omittedPages", {}).items():
            if int(p) not in scope or not str(reason).strip():
                raise ValueError("Omitted pages need a reason and must be in scope.")
        previous = (0, -1)
        for band in part["bands"]:
            if not isinstance(band.get("label",""),str) or type(band.get("pageBreakBefore",False)) is not bool:
                raise ValueError("A band label must be text and pageBreakBefore must be a JSON boolean.")
            page_number = band["page"]
            if type(page_number) is not int or page_number not in scope:
                raise ValueError("Every band must reference a page in scope.")
            if not isinstance(band.get("id"),str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}",band["id"]) or band["id"] in ids:
                raise ValueError("Every band needs a globally unique id using letters, digits, underscores or hyphens.")
            ids.add(band["id"])
            r = band["rect"]
            bounds = doc[page_number-1].rect
            if len(r) != 4 or not all(isinstance(x,(float,int)) and math.isfinite(x) for x in r) or not (0 <= r[0] < r[2] <= bounds.width and 0 <= r[1] < r[3] <= bounds.height):
                raise ValueError(f"Invalid crop rectangle: {band['id']}")
            order = (page_number, r[1])
            if order < previous:
                raise ValueError("Bands must be in source reading order.")
            previous = order
            if not band.get("system"):
                raise ValueError("Each band needs a source system identifier for coverage review.")
            for mask in band.get("exclusions", []):
                if (len(mask) != 4 or not all(isinstance(x,(float,int)) and math.isfinite(x) for x in mask)
                    or not (r[0] <= mask[0] < mask[2] <= r[2] and r[1] <= mask[1] < mask[3] <= r[3])):
                    raise ValueError(f"Exclusion must be a finite rectangle inside its crop: {band['id']}")
            protected = band.get("protectedRegions", [])
            if not isinstance(protected, list) or (policy == "preserve-target" and not protected):
                raise ValueError(f"Preservation requires reviewed protectedRegions for every band: {band['id']}")
            for region in protected:
                pr = region.get("rect", []) if isinstance(region, dict) else []
                if (len(pr) != 4 or not all(type(x) in (float, int) and math.isfinite(x) for x in pr)
                    or not (r[0] <= pr[0] < pr[2] <= r[2] and r[1] <= pr[1] < pr[3] <= r[3])
                    or not isinstance(region.get("description"), str) or not region["description"].strip()):
                    raise ValueError(f"Protected target region must be described and fully inside its crop: {band['id']}")
                if any(max(pr[0], m[0]) < min(pr[2], m[2]) and max(pr[1], m[1]) < min(pr[3], m[3])
                       for m in band.get("exclusions", [])):
                    raise ValueError(f"Exclusion overlaps protected target notation: {band['id']}")
            accounted.add(str(page_number))
            # Do not silently accept PDF geometry incompatible with the native bridge.
            if doc[page_number-1].rotation or doc[page_number-1].cropbox != doc[page_number-1].mediabox:
                raise ValueError("Rotated/CropBox PDF: normalize a derivative first, keep the original and record the transform.")
        if accounted != {str(p) for p in scope}:
            raise ValueError(f"{part['name']}: each scope page needs bands or an explicit omission reason.")
        if not part["bands"]:
            raise ValueError("Cannot export an empty part.")


def build(args):
    """Publish a complete generation; failures leave the previous result untouched."""
    recipe_path = Path(args.recipe).resolve()
    recipe = json.loads(recipe_path.read_text())
    source = (recipe_path.parent/recipe["source"]).resolve()
    out = Path(args.out).resolve()
    if any((out/(safe_name(p["name"])+".pdf")).resolve() == source for p in recipe["parts"]):
        raise ValueError("Output would overwrite the source PDF; choose another output directory.")
    if out.exists() and (not out.is_dir() or (any(out.iterdir()) and not (out/"manifest.json").is_file())):
        raise ValueError("Nonempty output is not a generated extraction directory; choose a new directory.")
    out.parent.mkdir(parents=True,exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=f".{out.name}-staging-",dir=out.parent))
    backup = None
    try:
        staged_args = argparse.Namespace(recipe=str(recipe_path),out=str(stage))
        with contextlib.redirect_stdout(io.StringIO()):
            _build(staged_args)
        if out.exists():
            backup = out.with_name(f".{out.name}-previous-{uuid.uuid4().hex[:8]}")
            out.rename(backup)
        try:
            stage.rename(out)
        except OSError:
            if backup:
                backup.rename(out)
            raise
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    manifest = json.loads((out/"manifest.json").read_text())
    print(json.dumps({"manifest":str(out/"manifest.json"),
        "project":str(out/(safe_name(recipe["title"])+".partsmithproject")),
        "parts":[p["file"] for p in manifest["parts"]],"previousGeneration":str(backup) if backup else None}))


def _build(args):
    recipe_path = Path(args.recipe).resolve()
    recipe = json.loads(recipe_path.read_text())
    source = (recipe_path.parent/recipe["source"]).resolve()
    doc = fitz.open(source)
    validate_recipe(recipe, source, doc)
    out = Path(args.out)
    if any((out/(safe_name(p["name"])+".pdf")).resolve() == source for p in recipe["parts"]):
        raise ValueError("Output would overwrite the source PDF; choose another output directory.")
    out.mkdir(parents=True, exist_ok=True)
    review = out/"review"
    review.mkdir(exist_ok=True)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    project = {"id":str(uuid.uuid4()), "projectName":recipe["title"], "createdAt":now, "modifiedAt":now,
               "sourceFilename":source.name, "pageCount":len(doc), "parts":[], "bands":[], "pageRectifications":[],
               "projectSettings":{"outputPageSize":"Letter", "margins":{"top":48,"bottom":48,"leading":36,"trailing":36},
                                  "defaultScale":1, "interSystemGap":18, "showTitleBlock":True,
                                  "showPartNameInHeader":True,"headerDisplayMode":"typed", "defaultTitleText":recipe["title"],
                                  "defaultComposerText":recipe.get("composer","")}}
    manifest = {"schemaVersion":1, "sourceSHA256":digest(source), "inputRecipeSHA256":digest(recipe_path),
                "scopePages":recipe["scopePages"], "notationPolicy":recipe.get("notationPolicy", "clean-isolation"),
                "status":"draft_needs_visual_review", "parts":[]}
    palette = [(0.15,0.4,0.85),(.8,.2,.2),(.15,.6,.3),(.7,.3,.7)]
    for pi, part in enumerate(recipe["parts"]):
        pid = str(uuid.uuid4())
        red, green, blue = palette[pi%len(palette)]
        project["parts"].append({"id":pid,"name":part["name"],"createdAt":now,
            "color":{"red":red,"green":green,"blue":blue,"alpha":1},
            "layoutSettings":{"showTitle":True,"titleText":recipe["title"],"composerText":recipe.get("composer",""),"scale":1,"interSystemGap":18,"showPartNameLabel":True}})
        result = fitz.open()
        placements = []
        dest = None
        cursor = 0
        for band in part["bands"]:
            rect = fitz.Rect(band["rect"])
            scale = 540 / rect.width
            height = rect.height * scale
            label = band.get("label", "")
            reserved = 13 if label else 0
            if height+reserved > 618:
                raise ValueError(f"{band['id']}: crop too tall for readable unsplit output; review grouping/layout.")
            if dest is None or cursor+height+reserved > 744 or band.get("pageBreakBefore"):
                dest = result.new_page(width=612,height=792)
                text_box(dest,fitz.Rect(36,24,576,43),part["name"],fontsize=11)
                text_box(dest,fitz.Rect(36,755,576,777),f"{recipe['title']}  |  {len(result)}",fontsize=8,align=1)
                cursor = 55
                if len(result) == 1:
                    text_box(dest,fitz.Rect(36,48,576,92),recipe["title"],fontsize=18,align=1)
                    text_box(dest,fitz.Rect(36,93,576,112),recipe.get("composer",""),fontsize=10,align=1)
                    cursor = 126
            if label:
                text_box(dest,fitz.Rect(36,cursor,576,cursor+13),label,fontsize=8)
                cursor += reserved
            target = fitz.Rect(36,cursor,576,cursor+height)
            dest.show_pdf_page(target,doc,band["page"]-1,clip=rect,keep_proportion=True)
            for mask in band.get("exclusions", []):
                # A coincident PDF clipping edge can leave an antialiased hairline.
                # Bleed into the surrounding blank gap only, never into target notation.
                bleed = .5
                dest.draw_rect(fitz.Rect(36+(mask[0]-rect.x0)*scale-(bleed if mask[0] == rect.x0 else 0),
                                         cursor+(mask[1]-rect.y0)*scale-(bleed if mask[1] == rect.y0 else 0),
                                         36+(mask[2]-rect.x0)*scale+(bleed if mask[2] == rect.x1 else 0),
                                         cursor+(mask[3]-rect.y0)*scale+(bleed if mask[3] == rect.y1 else 0)),
                               color=None, fill=(1,1,1), overlay=True)
            placements.append({"id":band["id"],"sourcePage":band["page"],"system":band["system"],
                               "outputPage":len(result),"sourceRect":list(rect),"destinationRect":list(target),
                               "exclusions":band.get("exclusions",[]), "protectedRegions":band.get("protectedRegions",[])})
            bpage = doc[band["page"]-1]
            project["bands"].append({"id":str(uuid.uuid4()),"pageIndex":band["page"]-1,"partID":pid,
                "topFraction":rect.y0/bpage.rect.height,"bottomFraction":rect.y1/bpage.rect.height,
                "leftFraction":rect.x0/bpage.rect.width,"rightFraction":1-rect.x1/bpage.rect.width,
                "createdAt":now,"excluded":False,"barNumberMode":"hidden",
                "editorialLabel":band.get("label",""),"pageBreakBefore":band.get("pageBreakBefore",False),
                "exclusions":[{"topFraction":m[1]/bpage.rect.height,"bottomFraction":m[3]/bpage.rect.height,
                               "leftFraction":m[0]/bpage.rect.width,"rightFraction":1-m[2]/bpage.rect.width}
                              for m in band.get("exclusions",[])]})
            # A side-by-side crop/output comparison preserves row identity for reviewers.
            src_image = bpage.get_pixmap(matrix=fitz.Matrix(1.5,1.5),clip=rect,alpha=False)
            src_image.save(review/f"{safe_name(part['name'])}-{band['id']}-source.png")
            if recipe.get("notationPolicy") == "preserve-target":
                # Show ink OUTSIDE the crop, too: a tight crop cannot expose its own omissions.
                context = fitz.Rect(rect.x0-24, rect.y0-24, rect.x1+24, rect.y1+24) & bpage.rect
                pix = bpage.get_pixmap(matrix=fitz.Matrix(3,3),clip=context,alpha=False)
                im = Image.frombytes("RGB", (pix.width,pix.height),pix.samples)
                draw = ImageDraw.Draw(im)
                def overlay(region, color):
                    box = [region[0]*3-pix.x,region[1]*3-pix.y,region[2]*3-pix.x,region[3]*3-pix.y]
                    draw.rectangle(box,outline=color,width=2)
                overlay(list(rect),"#cf3c1d")
                for region in band["protectedRegions"]:
                    overlay(region["rect"],"#168340")
                context_file = f"{safe_name(part['name'])}-{band['id']}-context.png"
                im.save(review/context_file)
                placements[-1]["sourceContext"] = {"rect":list(context),"image":"review/"+context_file,
                    "legend":"Red: crop boundary; green: protected target regions. Inspect surrounding source ink for omissions."}
            cursor += height+18
        filename = safe_name(part["name"])+".pdf"
        result.set_metadata({"title":recipe["title"]+" - "+part["name"],"author":recipe.get("composer",""),"creator":"Score Part Extraction"})
        result.save(out/filename,garbage=4,deflate=True)
        for i, page in enumerate(result):
            render(page).save(review/f"{safe_name(part['name'])}-output-{i+1:03d}.png")
        manifest["parts"].append({"name":part["name"],"file":filename,"sha256":digest(out/filename),"outputPages":len(result),"bandCount":len(part["bands"]),"placements":placements})
        result.close()
    package = out/(safe_name(recipe["title"])+".partsmithproject")
    package.mkdir(exist_ok=True)
    if source != (package/"source.pdf").resolve():
        shutil.copyfile(source,package/"source.pdf")
    save_json(package/"project.json",{"project":project})
    save_json(out/"manifest.json",manifest)
    portable_recipe = dict(recipe, source=package.name+"/source.pdf")
    save_json(out/"recipe.json",portable_recipe)
    manifest["recipeSHA256"] = digest(out/"recipe.json")
    save_json(out/"manifest.json",manifest)
    print(json.dumps({"manifest":str(out/"manifest.json"),"project":str(package),"parts":[p["file"] for p in manifest["parts"]]}))


def verify(args):
    out = Path(args.out)
    manifest = json.loads((out/"manifest.json").read_text())
    report = json.loads(Path(args.review).read_text())
    if digest(out/"recipe.json") != manifest["recipeSHA256"]:
        raise ValueError("Recipe changed after build; rebuild before recording review.")
    recipe = json.loads((out/"recipe.json").read_text())
    if digest(out/recipe["source"]) != manifest["sourceSHA256"]:
        raise ValueError("Embedded source changed after build.")
    with fitz.open(out/recipe["source"]) as source_doc:
        validate_recipe(recipe, out/recipe["source"], source_doc)
    expected = {p["file"]:p["sha256"] for p in manifest["parts"]}
    if report.get("outputSHA256") != expected:
        raise ValueError("Review must name the exact hashes of every current output.")
    ids = {b["id"] for p in manifest["parts"] for b in p["placements"]}
    if set(report.get("reviewedBandIDs",[])) != ids:
        raise ValueError("Visual review must account for every band.")
    # A current reinspection supersedes the old verdict, including when it fails.
    # Keep its evidence, but never leave a known failed result labeled reviewed.
    manifest["status"] = "draft_needs_visual_review"
    manifest.pop("review", None)
    manifest["reviewAttempt"] = report
    save_json(out/"manifest.json", manifest)
    policy = recipe.get("notationPolicy", "clean-isolation")
    checks = ["identity", "coverage", "cropEdges", "globalMarkings", "readability", "pageTurns"]
    if policy == "preserve-target":
        if report.get("reviewVersion") != 2 or report.get("notationPolicy") != policy:
            raise ValueError("Preservation review requires reviewVersion 2 and the matching notationPolicy; legacy clean reviews cannot be relabeled.")
        checks[2] = "targetPreservation"
        bands = report.get("bandReviews", [])
        if (not isinstance(bands, list) or len(bands) != len(ids)
            or any(not isinstance(b, dict) for b in bands)
            or {b.get("bandID") for b in bands} != ids):
            raise ValueError("Preservation review requires one observation for every band.")
        if any(b.get("targetPreservation") != "pass" or b.get("neighborNotation") not in ("present", "none")
               or not isinstance(b.get("observations"), str) or not b["observations"].strip() for b in bands):
            raise ValueError("Every band must pass target preservation and disclose neighboring notation with observed evidence.")
    if report.get("issues"):
        raise ValueError("Unresolved issues stay draft; record tolerated neighbor context in band observations.")
    if any(report.get("checks",{}).get(k) != "pass" for k in checks) or not report.get("reviewer") or not report.get("notes"):
        raise ValueError("Review requires reviewer, notes and six passing checks; unresolved issues stay draft.")
    for p in manifest["parts"]:
        if digest(out/p["file"]) != p["sha256"]:
            raise ValueError("Output changed after review.")
        pdf = fitz.open(out/p["file"])
        if len(pdf) != p["outputPages"]:
            raise ValueError("Output page count changed.")
    manifest["status"] = "reviewed"
    manifest["notationPolicy"] = policy
    manifest.pop("reviewAttempt", None)
    manifest["review"] = report
    save_json(out/"manifest.json",manifest)
    print("Reviewed output hashes, band coverage and visual checklist verified.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command",required=True)
    a = sub.add_parser("analyze")
    a.add_argument("source"); a.add_argument("--pages"); a.add_argument("--out",required=True)
    b = sub.add_parser("build")
    b.add_argument("recipe"); b.add_argument("--out",required=True)
    v = sub.add_parser("verify")
    v.add_argument("--out",required=True); v.add_argument("--review",required=True)
    args = parser.parse_args()
    try:
        {"analyze":analyze,"build":build,"verify":verify}[args.command](args)
    except (ValueError, KeyError, OSError) as exc:
        parser.exit(2,f"Extraction stopped: {exc}\n")


if __name__ == "__main__":
    main()
