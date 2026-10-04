# Literal scale and system gap UI review — October 4, 2026

Independent native smoke check passed all **13 checks** against the 34 production Core/Feature Swift files recorded in `source-hashes.json`.

The isolated test hosts the production `InspectorView` and a real `PartsmithDocument` at **340 points wide**. The warning distinguishes requested **1.40×** from **Fits Within Margins 1.09×**. It says the chosen scale is applied and warns that music can extend into margins or be cut off at the paper edge. The old clamped Applied Scale row is absent. The same warning works with consistent scaling turned off and clears when the request fits. The scale report is supplied by the harness to exercise UI states; this check does not measure PDF geometry.

New parts still display **18 pt** side margins. The renamed **System Gap** control exposes **4–200 pt** through native accessibility. Sending its actual backing NSSlider action at the maximum updates the real document to **200 pt**. Visible text says the chosen spacing is preserved, and Balance Page Fill help explicitly says both scale and gap are kept.

Visual review found the orange warning and icon, values, captions, and controls readable without truncation, horizontal overflow, or overlapping text at the tested width. Native slider tick marks are closely spaced at a 2-point step over the extended range, but the value and thumb remain legible.

Static review of the production diff found no blocking issues: the shared horizontal frame subtracts each PDF page-box origin, requested scale is no longer clamped to fit width, and gap reduction during balanced pagination is removed. When enlarged music extends into the left margin, its bar number gets a separate row before pagination; very short crops receive the same protection. Right-only overflow does not conflict with a left-margin number. Flexible generated rests retain their deliberate fit behavior. Exceptionally tall individual crops retain their existing vertical fit; the scale-info comment identifies that exception.

This process uses prohibited activation and an offscreen window. It never opens or changes a user document or steals application focus. Some active accent fills are absent in these inactive captures, so active-window color contrast is outside this check. Actual gap control actions and model binding were exercised.

The exact harness and build command are preserved in `LiteralLayoutUITests.swift` and `build.sh`. `run.log` and `results.json` record the successful run. The build has one test-only deprecation warning for the macOS accessibility activation helper. Screenshots are unaltered native view captures composited over white. No production code or existing tests were changed by this reviewer.

Root normalized trailing whitespace in the captured accessibility text for the repository checkpoint; control values, screenshots and compiled sources are unchanged.
