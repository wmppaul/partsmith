# Independent review of native rest output

Reviewed `.build/mozart_rest_regression_2026-10-04/unnumbered-output-v2`: all nine PDFs, one page each, rendered and visually compared with the eight original source systems. The fixture deliberately omits optional starting-bar values. Exact PDF hashes are in `output-structure-check.json`.

**The reported Clarinet/Piano behavior is corrected in this output.** Clarinet's opening five bars are replaced by a five-bar rest; Piano's printed five-bar grand staff plus seven assigned silent systems becomes one **39-bar** grand-staff rest. Both retain their initial clefs, time signature, key where applicable, and Allegro/TUTTI source copies. The Piano has two staff rest symbols for its two hands but one duration of39, not78.

| Part | Observed output | Source comparison |
| --- | --- | --- |
| Flute | Opening five printed rests remain; final system35–39 becomes5 | Correct conservative omission; no false replacement |
| Clarinet in A | Opening5 compressed; final35–39 remains printed | Main reported opening defect fixed; later abstention explicit |
| Bassoon | Opening5 compressed; all seven later systems remain | Entry at9, notes38–39 and `a 2.` direction intact |
| French Horn in A | Opening5 and final35–39 each compressed | Intervening sounding systems remain |
| Piano | One row of39, with original two-staff opening context | Exactly5 +5 +6 +5 +4 +4 +5 +5; no duplicated duration |
| Violin I | All eight original strips | No playing strip replaced |
| Violin II | All eight original strips | No playing strip replaced |
| Viola | All eight original strips | No playing strip replaced |
| Cello and Bass | All eight original strips | `Vel.`/`Bassi` directions and sounding notes retained |

The independent source audit identifies **eight musically eligible whole-rest strips**. This run detected **six**, totaling30 bars. Two eligible strips abstained: opening Flute and Page4/System2 Clarinet. The Flute crop includes header material; the latter Clarinet crop visibly includes Bassoon notes below. Retaining ambiguous crops is preferable to erasing unclassified notation. The two omissions are not counted as successful recognitions.

The structural comparison checks all72 original band IDs and source references, exact crop rectangles, source markings, and all seven assigned rest durations. The detector added no rest to any musically ineligible strip. All original source geometry remains editable; the full embedded PDF hash is unchanged.

This is a rest-feature and source-continuity review, **not a performance-ready crop-quality certification**. Historical unmodified crops visibly retain neighboring notes, a clipped composer line above the first Flute staff, and the Mutopia footer below the second Cello/Bass strip. Those pre-existing crop issues are not corrected or hidden by this rest change. No new exhaustive source-edge audit is asserted.

Validation command: `tools/mozart_rest_review_output.py` with the unnumbered fixture and output above, this directory as `--review`, and `--allow-abstentions`. That option records every missing expected detection while still rejecting false positives and requiring the Clarinet/Piano opening fixes. The JSON's visual status remains a machine-created pending field; this separate signed narrative records the completed image inspection.
