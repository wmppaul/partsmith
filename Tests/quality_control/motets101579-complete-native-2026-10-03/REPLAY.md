# Replaying the native assisted extraction

The evidence archive preserves the 25-file production Core snapshot, native worker source, inventory, profile, source map, explicit assignments, original and final overrides, source-copy rectangles, and review images. Restore archive chunks in their numbered order according to `archive-parts.json`; the assembled stream is a gzip-compressed tar archive.

The worker is specific to this complete reviewed source map. It uses existing frozen native page analyses, calls the native per-system staff-count assignment helper and review/apply path, saves and reopens the project, then uses the native layout and PDF exporter. It does not rerun detection, synthesize notation, generate rests, or substitute a separate PDF layout engine. PyMuPDF renders original source and exported PDFs for review only.

From the repository root, restore the working evidence under `.build/brahms-motets101579-complete-native-2026-10-03`. The source PDF must have SHA256 `6287050ea4af566daded58d9a6059045bcdfd6d537a94e09dd18f1d0e5c324a3`. The saved `inventory.json` may contain an absolute source path; relocate that path only, keeping the source bytes and all page data unchanged. The original native inventory’s 18 page objects are copied exactly; a separate binding records that equality.

Compile `export.swift` with the archived Core Swift files using the macOS SDK and Swift compiler. The final call is:

```text
exporter-final --inventory .build/brahms-motets101579-complete-native-2026-10-03/inventory.json --profile .build/brahms-motets101579-complete-native-2026-10-03/profile.json --overrides .build/brahms-motets101579-complete-native-2026-10-03/final-overrides.json --directions source-directions-final-before-output.json --title "Brahms — Two Motets, Op. 74" --composer "Johannes Brahms" --out NEW_OUTPUT_DIRECTORY
```

Use a new output directory. The worker can replace a named output directory after preserving it temporarily; reproduction must not overwrite the reviewed delivery. Initial output omits `--overrides` and uses `source-directions-v2-before-output.json`. Project UUIDs and timestamps can differ in a replay; compare source-order identities, exact crop/copy geometry and rendered output, not serialization UUIDs or PDF container bytes across new runs.

`verify_final.py` compares the recorded initial/final manifests and directly decodes the final project. `render_outputs.py`, `render_source_contexts.py` and `render_final_details.py` produce review images and geometry checks. No broad native tests were rerun solely for these reversible explicit crop choices; this task verifies actual source preservation, native save/reopen, all 225 assigned identities, all output placements and actual PDFs.
