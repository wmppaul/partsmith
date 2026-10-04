# Independent numbered-volta heading review

No actionable defect was found in the narrowly scoped detector change. All **30 independent controls passed** against the frozen source snapshot; current production still matched that snapshot when this report was frozen.

The new classification rule requires a complete numbered `volta` instruction followed by an explicitly supported tempo change. Confidence, above-staff placement, nearest-system separation, assignment binding, source geometry and cancellation are unchanged. The original OCR text remains in the metadata. Whitespace and case normalization affect classification only.

The controls cover complete accepted phrases, rejection of incomplete or extra text, adjacent versus distant OCR words, reversed observation order, different baselines, invalid confidence, local staff text, previous-system text and cancellation before OCR. The permanent test diff also adds source-copy and assignment checks; those tests were reviewed here, while the parent owns their execution and the real-score workflow.

This is a code and selector review. It did not rerun Vision, the native staff detector, whole-score extraction, PDF export or pagination. It does not establish actual OCR recall, repair the separate Coda omission, or approve the experimental crop algorithm. Other languages and punctuation may conservatively remain unrecognized.

- `review.json` binds the six compiled Core files, permanent test file and executable hash.
- `results.json`, `test.swift` and the logs contain the 30 independent controls.
- `reviewed-diff.patch` is the exact reviewed change.
- `frozen-test-sources.zip` stores the compiled Core snapshot and reviewed permanent test source, without binaries.
- `run.sh` documents the private harness invocation; recreate its recorded workspace paths to rerun.
