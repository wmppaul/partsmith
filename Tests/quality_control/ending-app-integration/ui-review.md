# Independent ending UI and review inspection

Reviewed the root integration in `Partsmith/Features/Project/ScoreExtractionView.swift`, `ScoreSharedEnding.swift`, and `ScoreSharedDirectionReview.swift`. No blocking issue found in the inspected change. Exact reviewed file hashes are in `verification.json`.

The copied-direction label matches ending metadata by the current analysis page, the recipient band's system and source rectangle. Existing heading precedence remains, ending labels precede the empty-navigation “Printed repeat symbol” fallback, and navigation/destination records stay separate.

Each ending copy exposes both member links with their first/second role and one-based physical source page. The actions use the corresponding member's normalized source bounds, preserving the existing `focusDirection` path for source selection, highlight and zoom. Same-system unions retain individual member bounds, while cross-page pairs retain both physical source pages. The metadata factory requires both pages before publishing any pair.

“Remove Copy” still resolves the current band and exact current source marking before calling `removeSourceMarking`. It removes only that recipient's selected copy. The existing explicit override list preserves removal through reset/replan and application; paired metadata remains available to the other copies. Reassignment invalidation is distinct: it clears automatic copies linked to either changed source page while keeping partner headings/navigation/destination references, unrelated pairs and manual rectangles.

The experimental option now names paired endings and its help retains limitations. Direction notes remain optional and Add Parts gains no new acceptance requirement. The underlying fixed-layout restriction remains.

This is source-code review supported by permanent Core behavior tests. It is **not** a claim that the visible packaged-app controls have been exercised; root's native workflow and packaged-app checks remain separate.
