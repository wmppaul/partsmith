# Continuous-staff change through the native app worker

The October 3 run used current production Core, native Vision, the full immutable 39-page Brahms score and its exact nine saved corrections. All 604 main crop geometries match the newly delivered traced-line project. Only the expected p24 viola and cello edges change from the prior app worker; all 27 app-recognized copies, headings, navigation, staff identities and corrections remain unchanged. The separate 15 prototype ending rows are not part of app recognition.

The worker completed in 71.39 seconds of awake time with no recognition issues. All observed progress and completion callbacks ran on the main thread; the longest interval of its 50 ms main-loop heartbeat was 76.8 ms. The source/project stayed unchanged until acceptance and progress cleared. This is native worker evidence, not live SwiftUI interaction or a complete musical certificate.

`review.json` binds the frozen sources, worker binary, inventories, plans and delivered geometry. `native_worker.swift`, source hashes, phase log and summary retain reproduction evidence. The harness was compiled against the copied Core files under `.build/qc-native-continuous-worker/Core` and run with normal Mac Vision access under `caffeinate -i`. The prior worker and output evidence remain intact.
