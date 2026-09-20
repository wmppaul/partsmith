# Crop refinement evidence

The delivered settings and independent reviews are in `Tests/full_scores/ave-compact-*` and `quartet-compact-*`. These use 8 and 321 explicit reviewed geometry corrections, respectively. They are not unattended Auto outputs.

- `*-broad-context.json`: original delivered broad crops.
- `*-current-compact-context.json`: final frozen Auto proposals before local corrections.
- `*-final-context.json`: delivered revised native PDFs after disclosed corrections.
- `first`, `second` and unqualified `compact-context` reports: historical rejected iterations, not current acceptance.
- Profiles/overrides in this directory reproduce Auto proposals; use the full_scores compact overrides to reproduce final reviewed geometry.
- `check_geometry.py`: checks every independent source guard and reports every violation. It is not a musical evaluator.
- `finalizer-project-negative.json` and `shared-cue-negative-control.json`: negative-control results that must reject damaged or incomplete metadata.

Neighboring line counts use detected line centers, not complete pixel ownership. They supplement the source and final-page reviews.
