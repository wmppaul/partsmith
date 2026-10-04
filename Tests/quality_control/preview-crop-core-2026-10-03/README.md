# Preview crop Core support

The PDF exporter now returns the exact `PartRenderPlan` used to draw its output. `PartPreviewRenderer` publishes PDF, plan and rendered snapshot through one internal state value; replacing, cancelling or clearing a preview cannot leave mismatched drag geometry. The existing cancellation/generation checks still reject superseded work.

`PartPreviewCropGeometry.cropEdges(for:placement:sourcePageBounds:edge:outputDeltaY:)` converts an output-PDF drag into source-page fractions using the placement's actual vertical scale. Positive PDF-coordinate delta moves upward. It preserves the opposite edge, clamps to the page and the model's 0.002 minimum height, rejects nonfinite/stale geometry, and disables generated/replaced/joined rest rows. Source/output origins and horizontal whitespace trimming do not alter the vertical conversion.

`PartsmithDocument.updateBand` now intersects existing whiteouts with the normalized new crop in its existing Undo transaction. Retained whiteouts keep their IDs and original source positions; empty intersections are dropped. Nonfinite crop edits are rejected. The source and Preview therefore use the same crop/whiteout behavior.

Validation:

- **110** new checks in `tools/test_preview_crop.sh`: actual placement mapping, scale above/below one, nonzero PDF origins, edge direction, page and minimum-height clamps, disabled rest/stale inputs, synchronous observation of asynchronous render publication, superseded/cancelled renders, source failure, direct crop API, partial/full whiteout intersections, Undo/Redo, saved project roundtrip, and actual native PDF export.
- **5,389** existing layout assertions, including 80 varied layouts and a saved project.
- **169** existing native crop/export checks, including persisted geometry and rasterized notation.

The expected invalid-PDF test prints a CoreGraphics diagnostic. An earlier compile was interrupted by the newly requested document change and correctly rejected a modified source input; the successful run was rebuilt after Core edits stabilized. No successful assertion was bypassed. This report covers Core geometry/state/document behavior; the interactive overlay and its event tests are owned separately by root.

Source hashes, test executables, logs and generated roundtrip evidence are bound in `bindings.json`. The archive includes the three changed Core source snapshots, test constructors/scripts, and the synthetic saved project/PDF. No original score PDF or user document was changed.
