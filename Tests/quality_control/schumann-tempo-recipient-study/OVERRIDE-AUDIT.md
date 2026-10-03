# Initial override audit and minimum safe integration proposal

V3 is not ready for production. Its 14 recipient controls exercised automatic assignments only. This separate negative audit exercises initial `ScorePageOverride` values supplied before direction-review binding capture. It does not change the original 30 source obligations or the original V3 candidate.

## Reproduced omission

A valid four-staff/two-system page has a printed Adagio above the first system and two one-staff parts. Automatic planning supplies one copied heading to B. Passing the identical assignments as an initial override, with `sourceMarkings == nil`, produces an applicable plan with **zero copied headings**, no heading/provenance warning, and no preserved Adagio for B. The reviewed planner path calls navigation copying but never heading copying.

An explicit `sourceMarkings: []` correctly prevents automatic replacement of a user-removed copy. A materialized, explicit nonempty list correctly retains its existing copy. These are distinct from an absent list and must stay distinct in a fix.

`initial-override-controls.swift` is a deliberately failing requirement audit, not a green suite. The V3 result is `initial-override-v3.json`; the current production result is `initial-override-production.json`. The source snapshots and their hashes are preserved separately. The failure also predates V3; it is not caused by adding recipient IDs.

## Stale ownership before capture

The same harness moves the recognized source staff or a recipient into another system and changes each to a labeled cue. V3 also tests moving/changing the kind of a recipient whose own locally printed heading originally justified suppressing the shared copy. These requests remain applicable, with no ownership reconsideration or heading warning. They currently do not create a wrongly placed automatic copy because the reviewed path drops all automatic headings. That omission is **not evidence that the source/recipient metadata is safe**: merely wiring heading copying into this path would activate the stale metadata.

The current direction review records bindings only after the initial plan exists. Such a binding cannot retrospectively prove that preexisting recognition belongs to that initial override. Later UI edits do have a separate binding-invalidation path; this negative audit concerns initial overrides.

## Separate proposed fix — not applied

1. Give heading application one common entry point over the complete planned page, used by automatic and reviewed planning. Call it only after assignment validation. Pass the set of bands with an explicitly supplied marking list. Leave those lists, including empty lists, authoritative. For absent lists, recalculate automatic copies.
2. Freeze recognition ownership before overrides: source page/system, anchor and actual source staff, and the relevant music assignments as `(systemIndex, partID, ordered candidateIDs, kind)`. For V3 recipient suppression, also retain each local supplier's actual source staff, original ink bounds and horizontal position. A flat allow-list of part IDs is not sufficient evidence. A whole-page assignment binding is a simpler conservative first implementation; unrelated reassignment can then invalidate all page headings instead of guessing.
3. Compare the recognized binding with the requested assignments **before initial review capture**. If the source or any relied-upon local supplier moves systems, changes part/staff membership, or becomes a cue, invalidate that automatic heading/recipient decision and attach a nonblocking rescan/review notice. Do not move a heading merely because its physical staff ID still exists. Keep ordinary music and explicit user-marking lists usable.
4. Recheck measured local-source containment against each final recipient crop. Crop edits need not change staff identity but can exclude the local glyphs that originally justified suppression. If local supply is no longer complete, preserve/copy the real shared source instruction when its ownership remains valid. Never use matching words at another system/x-position, below the target staff, or incomplete/absent ink evidence.
5. For legacy global headings without the new binding, retain current automatic behavior. For a reviewed initial mapping, derive the expected unchanged automatic grouping with headings cleared and apply only when its relevant identity exactly matches. New V3 explicit recipient metadata without a binding should be considered unverifiable, with a notice; do not silently trust it.

Required regression cases include the no-op nil-list repair, unchanged explicit empty/nonempty lists, source and local supplier moved to another system, source/recipient music-to-cue, swapped instrument IDs, partially clipped local heading after a crop edit, missing/malformed binding, legacy nil metadata, and the prior same-word wrong-position/ink controls. Positive all-page musical evidence remains necessary after implementing such a candidate. This document proposes no production changes and no silent review gate.
