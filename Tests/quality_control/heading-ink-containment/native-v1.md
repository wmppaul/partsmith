# Native source-ink containment for duplicate headings

The KV498 Clarinet output repeated **Rondo. Allegretto.** because the padded copy begins at28.6374pt while the existing music crop begins at28.9715pt. Both complete printed words already lie inside the original crop.

The native recognizer now measures the original source raster inside each padded heading rectangle. It composites transparency on white, includes every nonwhite8-bit pixel, and adds a one-pixel guard bounded by the existing copy rectangle. The planner suppresses a copy only when this valid same-source evidence lies completely inside the existing crop. Missing, invalid or legacy evidence preserves the copy. Cancellation discards completed measurements. OCR word bounds are never the containment evidence.

Complete native regressions cover Ave Verum, KV498, and the Brahms93521 Quartet with its recorded nine page corrections: **15parts,111pages,1,073 unchanged main source crops**. Only the KV498 Clarinet output6 changes; the other110 pages are independently pixel-identical at144dpi. The changed page preserves both full heading words once. Remaining source copies and page counts stay unchanged. Automated layout checks pass for every page, and independent source guards retain all64 Ave envelopes and15 KV498 heading obligations. This is a delta-preservation result, not a full musical-quality pass.

`bash tools/test_shared_headings.sh` passes59checks. All14independent checks also pass against the merged production files. Independent tests cover raster axes, alpha compositing, detached gray254 ink, invalid and disjoint metadata, legacy decode, owner-only suppression and unchanged main geometry. The durable Brahms p22 negative shows an actual A cap1,207 dark pixels above an OCR-based hypothetical crop boundary; this must retain its padded copy. See the adjacent fixture and independent review directory.

A broader repeated-word experiment is excluded. Ave’s Basso crop contains a neighboring Adagio below its own staff, which cannot replace an above-staff tempo. Future matching must also establish musical horizontal alignment and inspect surrounding letters. Native Ave remains unchanged. No whiteouts, source guards, crop edges, or repeated-glyph matching were promoted.

The JSON companion binds source, native binaries, inventories, manifests, final code, independent reviews and test results. Production promotion retains the separately tested navigation-override authority change. No commit was made by this subagent.
