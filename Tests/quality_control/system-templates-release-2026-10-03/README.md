# Layout-reuse release verification

The final universal macOS app is built from a frozen copy of all 35 production Swift files plus project/resources (42 inputs). Both arm64 and x86_64 slices require macOS 14.0. Every frozen input matches production; every app file matches the ZIP. The public ZIP was replaced atomically only after those checks, and the previous ZIP remains in a private backup. No running app, user document or other app copy was changed.

The build record is `../macos-build-2026-10-03-system-templates.json`. Independent source, batch, corrected-image and scroll reviews plus the complete native export and actual panel-event test are bound in `report-bindings.json`. Root regression logs retain 27 batch, 111 planner and 139 document checks. Native staff/crop detection is unchanged; no whole-corpus musical-quality claim is added by this release.

`verify_and_publish.py` verifies the existing frozen build and package. Its first attempt stopped before publication because Xcode startup warnings on stderr were parsed as architecture names. The validator now uses the successful tool's stdout for that field, retaining both output streams in evidence. The two expected architectures and minimum OS are still checked exactly. The initial tool logs remain. Original build-log bytes are zipped; the readable log strips trailing whitespace only.

The production panel was driven in its own native window through finding 46 systems, showing one, and accepting 43 full-roster assignments. It leaves three systems with omitted instruments pending their independent rest counts. The offscreen capture does not fully paint the results footer, so the panel report does not certify full app-window rendering. Separate real viewport measurements verify the enlarged-score scroll anchor. All proposals remain explicitly accepted choices; the three-score study leaves 18 systems unresolved.

Existing hairpin/meter omissions, neighboring notation and page-turn defects are documented in the complete workflow. Its scratch PDFs are validation outputs, not a replacement for the separately delivered corrected draft. The broader extraction goal remains unfinished.
