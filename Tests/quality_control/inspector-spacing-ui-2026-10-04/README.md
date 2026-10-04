# Inspector spacing and scale UI review — October 4, 2026

Independent native smoke check passed all **10 checks** against the 34 production Core/Feature Swift files recorded in `source-hashes.json`.

The private test process hosts the production `InspectorView` and a real `PartsmithDocument` at **340 points wide**. It verifies that a new part displays **18 pt** side margins, that requested **1.40×** and applied **1.14×** are distinguished, and that the explanation for identical larger scale settings is visible and readable. The scale report is supplied by the harness to exercise the width-limited UI; this check does not measure PDF layout geometry.

The production Preferred System Gap control exposes **4–200 pt** through native accessibility. Sending its actual backing NSSlider action at the maximum updates the real document to **200 pt**. The balancing explanation is visible below it. A second state verifies the alternate Smallest Applied Scale wording when consistent scale is off.

Visual review found no truncated text, overlaps, or horizontal overflow at the tested width. The explanatory text wraps cleanly. The 200-point range creates many closely spaced native tick marks, but the value and thumb remain legible. Screenshots include the full inspector and the controls scrolled into view in both scaling modes.

This isolated process uses prohibited activation and an offscreen window, so it never opens or modifies a user document or steals application focus. Offscreen inactive controls lose some active accent fills in these captures; active-window color contrast is outside this check. Actual control actions and data binding were exercised.

`InspectorSpacingUITests.swift` and `build.sh` preserve the exact harness/build inputs. `run.log` and `results.json` record the final successful run. Screenshots are unaltered native view captures composited over white for opaque output. No production code or existing tests were changed by this reviewer.

The root review normalized trailing whitespace in the accessibility text dump for the repository checkpoint; control values and screenshot bytes are unchanged.
