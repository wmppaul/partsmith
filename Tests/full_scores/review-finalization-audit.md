# Current finalization audit — September 20 crop revision

The revised preflight validates all 19 parts, 1,131 bands and 156 pages before writing any review status. It accepts the disclosed 8 Ave and 321 Quartet crop overrides only when their rectangles match the delivered placement manifest. The other three sets have zero explicit rectangle corrections. Each stored project band is now compared with its PDF manifest/plan for source page, crop, editorial label, source fragments and section break.

An isolated-copy negative control first passed with unchanged reviewed data, then rejected a changed native project crop with `Editable project crop differs from PDF manifest`. `--validate-only` made no publication writes. Exact result and finalizer hash: `Tests/tight_crops/finalizer-project-negative.json`. Existing map/manifest/PDF/visual-review bindings still apply. The finalization code does not substitute for musical review.

The earlier audit below describes the broader 184-page generation and the initial stale-review fixes. Its padding defaults, counts and source-code hash are historical.

---

# Review finalization audit

Reviewer: `offline_detection`. Scope: the current complete-score sections of `EXTRACTION_WORKFLOW.md`, `skills/score-part-extraction/SKILL.md`, `references/native-auto.md`, and the corpus finalization script. No production code or delivered PDFs were changed by this audit.

## Documentation

The documented native UI labels, manual instrument setup, seven-space padding defaults and per-part overrides, explicit page corrections, shared-direction limitations, commands, and output counts match the inspected implementation and manifests. The delivered totals are 19 parts, 184 pages and 1,131 bands. The five fidelity reports contain 1,326 regions and 382,119,104 grayscale pixels. The earlier excerpt section is explicitly historical. No additional documentation defect was found.

All five retained `generation-manifest.json` files were compared with their finalized manifests after removing only `status` and `reviewRecord`; all musical content and placement metadata match. The actual metadata-only finalization therefore preserves the visual review binding.

## Findings and fixed regressions

Two initial validation gaps were demonstrated in isolated temporary copies:

1. A changed source map could be bound to an older passing fidelity report. Replacing Ave's first protected rectangle with `[-100, -100, 10000, 10000]` still published `pass` against that changed map hash.
2. A stale Schumann visual-manifest hash was checked after earlier score statuses and the Schumann manifest had already been written. The script rejected the stale binding but left partially finalized metadata.

The revised reports bind the exact source-map SHA256 and normalized manifest SHA256. Normalization removes only status and reviewRecord. Finalization validates those bindings, retained generation equality, visual-review status and hashes, and complete-corpus totals during preflight.

The independent rerun used fresh temporary copies of all five manifests, review reports and review fixtures, with unchanged source/PDF/project files referenced read-only. Each rejection compared a before/after SHA256 inventory of every regular output file and required exact equality, including absence of new evidence files.

| Scenario | Observed result |
|---|---|
| Unmodified copied corpus | Finalizes successfully |
| Ave protected rectangle changed to an off-page rectangle | Rejected: `Stale reviewed source map`; no output writes |
| Schumann visual review manifest hash changed to `stale` | Rejected: `Stale visual manifest binding`; no output writes |
| Quartet first band's source top shifted by 1 point | Rejected: `Stale placement review`; no output writes |

This audit checks review consistency and publication ordering. It does not replace musical source comparison, and it makes no new claim that geometry or pixel checks identify all target notes.

Audited finalizer SHA256: `4ecbba42e735608994fb211987aec7c8fbc976cd1eae6084d0f33d9749490267`.
