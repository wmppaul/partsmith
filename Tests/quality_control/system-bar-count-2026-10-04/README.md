# System bar-count suggestions

The assignment panel can propose a bar count from a selected complete system. The detector uses the same displayed source raster and staff coordinates as Auto Extract, including rectification when enabled. It changes neither source pixels nor saved assignments.

The focused native test covers:

- Mozart K. 488, printed page 17: systems beginning at bars 144, 150, and 153 have 6, 3, and 4 printed measures respectively. The piano grand staff counts each bar once.
- The Beethoven Fifth scan, original source page 7: the opening system has 13 printed measures. Aligned time-signature numerals are not counted as barlines.
- Synthetic double bars, modest skew, a note stem crossing a complete staff, incomplete closing boundaries, conflicting staves, disconnected interior bars, invalid coordinates, and cancellation.

`tools/test_system_bar_count.sh` runs against production Core sources and the existing tracked PDF fixtures in `Tests/extraction/sources`. Its result report and exact source hashes are retained alongside this note.

Suggestions are deliberately conservative. Boundaries need a majority of selected staves and connecting ink in at least one interstaff gap. Single-staff systems and fully disconnected staff patterns remain manual. This counts printed measures; it does not recognize note durations, establish whether an opening bar is a pickup, or resolve split measures. The editable count must describe the whole selected system before its omitted instruments receive rests.
