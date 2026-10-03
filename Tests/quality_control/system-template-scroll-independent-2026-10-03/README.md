# Independent source-scroll integration test

The original marker `.frame(width: 1, height: 1).position(...).id("matched-system")` does not bring the selected system into view. Its positional wrapper supplies a page-sized scroll target, so `scrollTo(..., anchor: .center)` centers the page regardless of the requested system. Adding `onChange(initial: true)` does not correct this.

A one-point marker placed in actual vertical layout succeeds. Both with and without the initial callback, all four tested targets are visible and centered within 0.5 points. The tested replacement is:

```swift
VStack(spacing: 0) {
    Color.clear.frame(height: height * (bounds[1] + bounds[3]) / 2)
    Color.clear.frame(height: 1).id("matched-system")
    Spacer(minLength: 0)
}
.frame(width: 1, height: height)
.offset(x: width / 2)
.allowsHitTesting(false)
```

The final scenario retains `.onChange(of: templateFocusID, initial: true)` and `ScrollViewReader.id(selectedPage)`. Page changes use the production pattern: save a pending selection, change selected page, clear old focus while updating the page, then apply the pending selection in `onChange(selectedPage)`.

## Physical measurements

The isolated page is 1200 × 2400 points with 28 points of leading padding inside a 620 × 500 bidirectional viewport. An AppKit probe at the independently positioned target supplies its actual rectangle in the scroll document. Measurements use `NSScrollView.contentView.bounds` and `documentView.visibleRect`, not merely evidence that a callback ran.

| Target | Original position marker: viewport y | Original visible? | VStack + initial callback: viewport y | Fixed visible? |
|---|---:|---|---:|---|
| Same page, lower (82%) | 950 | No | 1718 | Yes |
| Same page, upper (20%) | 950 | No | 230 | Yes |
| New page, lower (82%) | 950 | No | 1718 | Yes |
| New page, subsequent target (65%) | 950 | No | 1310 | Yes |

The original callback fires for all four events in this reproduction, including the deferred new-page event. Its frame, rather than missed event delivery, causes the demonstrated failure. Moving `.id` before `.position` also fails all four targets. A one-point `.offset` marker alone stays at the document origin and fails all four. The fixed vertical-layout marker succeeds with both callback variants. `summary.json` and the six complete result files retain every rectangle, callback event, target visibility result and center error.

## Isolation and limitations

The test creates only its own temporary `NSWindow` and `NSHostingView`, with application activation prohibited. The window is ordered offscreen; its recorded frame is `[0, -532, 620, 532]`, outside the visible screen. It is ordered out before process exit. No existing user application, app copy, score document, production source or window was manipulated. Sandbox Launch Services connection warnings are preserved in the logs; SwiftUI/AppKit layout and real scroll offsets were available and verified.

This tests scrolling/layout behavior on the recorded macOS host, not complete score rendering, extraction quality, VoiceOver, or every window size. The target is represented by a one-point native probe and synthetic page content, not a production score PDF. Both axes scroll in the test; the fixed horizontal offset also keeps the target visible.

Reproduction from the repository root:

```sh
xcrun swiftc -parse-as-library -O -module-cache-path .build/ModuleCache \
  Tests/quality_control/system-template-scroll-independent-2026-10-03/harness.swift \
  -o /tmp/partsmith-scroll-harness
/tmp/partsmith-scroll-harness position noinitial /tmp/scroll-before.json
/tmp/partsmith-scroll-harness stack initial /tmp/scroll-after.json
```

The retained harness supports `position`, `idBeforePosition`, `offset` and `stack`, followed by `initial` or `noinitial` and an output JSON path. The executable remains private in scratch and is hash-bound in `summary.json`. No tests or production sources were edited for this evaluation.
