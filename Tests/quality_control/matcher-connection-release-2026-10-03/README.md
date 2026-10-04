# Printed system connections in scanned scores

The updated universal Mac app includes direct cropping in the part Preview: select a system and drag a blue edge; score, saving and export use the same edited band. That feature was already shipped and remains unchanged.

This release improves Find Similar Systems. It checks actual continuous original ink even when brackets cause detected staff starts to differ. All source-ink thresholds, missing-staff checks, complete-system checks, ambiguity handling, count requirements and explicit acceptance remain.

On the complete ten-page Hear My Prayer scan, two reviewed examples now produce26 correct further system proposals (19 source-supported,7 needing review), compared with none before. Six systems remain manual. Independent source review agreed on every proposed staff identity and roster. The existing32 challenge cases pass with exactly unchanged result semantics. This is an assistive improvement, not automatic instrument recognition or a duration counter.

Only ScoreSystemTemplateMatcher.swift differs from the preceding published source snapshot. The native crop analyzer and private crop candidates are unchanged/excluded. All45 inputs and35 Swift compile files were independently checked; both architectures target macOS14. Built and extracted bundles pass strict ad-hoc signature checks. This is not a notarized Developer ID release.

Publication atomically replaced only the download ZIP, retaining its predecessor. The running app and user documents were not touched.
