# Manual instrument naming: native UI review

The final production code passed **56 native interaction checks** on a fixed first-page excerpt of the user's Beethoven Symphony No. 5, second-movement score. An independent agent inspected the five screenshots. No production correction was needed by this review.

Run from the repository root:

```sh
bash tools/test_manual_instrument_pick_flow.sh
```

The test requires macOS AppKit, PDFKit, and native Vision/graphics access. It creates its own offscreen windows and transient document; it never automates the user's running Partsmith app. The 93 KB `source-page-1.pdf` is committed so the suite does not depend on the user's untracked sample directory. `source-provenance.json` records the unchanged full source hash and native PDFKit page extraction.

The test sends mouse-down/drag/up events to the production `BandOverlayView`, waits for actual local OCR to return no printed name, and uses the production manual field, staff stepper, Add/Cancel, Done and Auto controls. It verifies:

- Original drag rectangle remains visible as an amber pending selection.
- Empty and whitespace names cannot be added; typed names are committed using Add or Return.
- Separate areas named Violin remain separate Violin and Violin 2 entries.
- An entered two-staff instrument remains two staves after returning to Auto.
- Cancel and Escape remove only the unfinished name.
- Pending names disable Done and Auto; Auto explains the next action and is available again after Add/Cancel.
- Done targets the owning Auto window, all names survive in order, and closing the source clears pending state.
- The source PDF and complete project remain unchanged throughout setup.

The manually typed test names are deliberate UI inputs, not an automatic classification of every instrument in the source. This is a name-setup regression, not a full-score extraction or crop-quality review.

`results.json` lists each passing assertion; `native-flow.log` contains the final compile/run. Production and test hashes accompany `verification.json`; `manifest.json` covers every evidence file. The production roster was identical before and after the final run.

The inactive offscreen native capture omits some prominent button backgrounds. Actual enabled states and actions are checked directly. Focus requests are recorded and forwarded; this test does not claim OS foreground/key-window behavior. The native stepper is exercised via its value/action, since accessibility increment does not operate in this offscreen host. Text input, Return and Escape use the real field editor.
