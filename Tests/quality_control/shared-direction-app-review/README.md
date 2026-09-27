# Independent shared-direction app review

**113 independent checks pass; no remaining blocker in this scoped integration.** Tests compile a frozen copy of Core and run a real document staff-analysis worker with deterministic injected direction recognition. Native Vision availability in the packaged app and live UI smoke are separate root checks.

The suite verifies selected-page scope, off-main recognition/main-thread completion, opt-out equivalence, optional failures, all four progress/cancellation phases, replacement runs, stale source/correction rejection, and all-pages-before-destination sequencing. It also tests copy removal through editing, serialization, apply and undo/redo, plus staff ownership invalidation after part, profile and system changes.

Independent review caught and resolved provenance failures that could erase an existing manual marking or move an old automatic copy after recipient/system reassignment. The final controls include identical source rectangles that are manual for one recipient and automatic for another, both before and after a recipient swap. Explicit override lists supplied before initialization are treated as authoritative reviewed choices; automatic copies materialized during the current review retain separate provenance. The UI was reviewed for nonblocking acceptance, visible source rectangles, removal and reference links; stale orange focus is now cleared on plan changes/new runs.

`review.json` binds the tested source hashes, frozen binary, test result and scope. Reproduce with `bash tools/test_shared_direction_app.sh`. The output remains subject to the existing musical preservation limits: the opt-in does not promise complete endings, rehearsal letters or bar numbers, and these tests are not a full note-by-note output review.
