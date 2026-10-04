# Independent clean-matcher cancellation checks

The clean candidate preserves private-v3 patch mathematics and removes all private MatcherProbe hooks. Its added cancellation paths return nil for the entire in-progress page, with the public matcher returning no proposals on cancellation.

The test-only same-file extension exercises actual boundary scans on two connected-staff rasters: a thick rule and a double rule. Both must establish two source-proven patches while keeping original staff IDs, lines and horizontal extents unchanged. Cancellation is then injected at every checkpoint observed in the complete scan, including checkpoints after the first staff result was constructed; every interrupted call must return nil with no partial result.

A public-API check analyzes original Parzen pages2,4,6. The uncancelled case must propose the known page6 system. Cancellation during the second image request, after page2 was fully analyzed, must stop before the third page and return cancelled=true with zero suggestions.

`review.json` binds the candidate, private v3, original input and executable, and records all actual checkpoint counts and results. The archive contains the isolated same-file test, public driver, compiler command, exact combined matcher/test source, log and result. No shipping diagnostic, production edit, app, score PDF, project or source image was changed. Root independently owns clean exact-source24/historical32 replays and release integration.
