# Layout control review — 2026-10-04

Independent review passes: **5,443 layout assertions and 302 native export checks, zero failures**.

The gap range reaches 200 points through the slider, document setter, and new-part inheritance. Large gaps survive Undo/Redo and save/reopen. With balancing disabled the measured gap is exactly 200 points; the existing balanced-page policy still reduces spacing when needed to avoid extra pages.

New projects have 18-point left/right margins and retain 48-point top/bottom margins. Explicit margins in saved projects and per-part overrides remain unchanged. Historical fixture margins are explicitly 48 points so their original geometry checks remain useful.

Requests of 1.30× and 1.40× still share the same actual size after the width limit is reached. The separate applied-scale readout explains that plateau. Reducing side margins enlarges physical notation without changing the safe relative multiplier or discarding source ink.

The reviewed three-strip Beethoven image is visibly wider at 18 points, and is pixel-identical to a reference drawing the complete original crops through the same transform. It is a preservation fixture, not a complete extracted part; its existing crop edges and neighboring fragments are unchanged. The full export suite also covers tiny edge ink, copied markings, rectification, scanned notation, caches, and background preview responsiveness.

`review.json` records results and scope, `source-hashes.json` maps 28 production/test paths to SHA-256 values, and both run logs are included. No user app windows or documents were changed. Inspector control/screenshot review is recorded separately.
