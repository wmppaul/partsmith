# Shared score layout — native Inspector review

The Inspector now identifies the scope of scale, gap and margins as **Score Layout** or **Part Override**, with **Customize This Part** and **Use These Settings for All Parts** controls. Balance Page Fill and Use Consistent Scale remain per-part controls.

This harness hosts the production Inspector in an inactive, offscreen AppKit window at 340 points wide. It activates real accessibility controls and native slider actions against a real PartsmithDocument. It does not launch or modify the user's running app or project.

The tests cover inherited display values; shared and local changes for all three sliders; Customize and apply-all actions; immediate scope changes; asymmetric margin display and preservation; explicit margin reset; and independent page balancing. The initial shared screenshot supplies a synthetic 1.25× requested / 1.09× safe scale warning. That synthetic preview metadata is cleared before subsequent screenshots.

Deferred-edit protection was additionally reviewed in source: each slider identity includes part and scope, and each commit closure requires the original scope still to match the current document. Native sendAction commits synchronously in this harness, so the scope tests demonstrate immediate actions and do not claim to simulate a queued keyboard draft.

Full-height captures show all controls; the scrolled capture shows a 340 × 850 viewport. This inactive capture mode renders native accent colors as inactive gray. Production source hashes are recorded in source-hashes.json; every archived file is covered by manifest.json.
