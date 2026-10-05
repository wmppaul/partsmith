# Mozart K488 rest recognition regression

The user's opening Clarinet in A contains five whole-bar rests but was rejected while the adjacent Bassoon was accepted. On a keyless transposing staff, LilyPond leaves the shared key-signature column blank before the common-time C. The detector's contiguous-prefix rule mistook that normal gap for unexplained first-bar notation. The piano opening was rejected both by the single-staff restriction and by the brace being mistaken for the staff's left edge.

The detector now recognizes the specific open-right common-time shape across that signature gap, requires horizontal continuation when locating staff edges, and checks the two hands of a grand staff independently. Both hands must contain only whole-measure rests and agree on every measure boundary. Prefixes retain printed clefs, keys, meters, and the piano brace. The ending remains copied from the source. A normal single closing bar with no trailing instruction is separately identified for continuation through later inserted rests.

Run `bash tools/test_mozart_rest_detection.sh`. The fixture is a source-preserving excerpt of the exact user-supplied public-domain Mutopia PDF, with source hashes in `source.json`. The test creates actual native compact Auto crops using the reviewed instrument order of the first system, with no manual crop tightening. Scope is this one system, not a whole-concerto correctness claim.

Checks include:

- Clarinet, Bassoon, Horn, and both piano hands each recognize five bars.
- The piano count is five, with ten retained staff lines; it is not ten bars.
- Playing string crops remain unchanged. Flute intentionally abstains because its Auto crop also includes header/composer fragments at the right.
- 81 whole-note/up-stem/down-stem mutations span all staff lines/spaces, both inside the formerly failing signature gap and after it. Every sounding case declines compression.
- Either piano hand playing, internal meter changes, and fermatas decline.
- Conflicting bar positions across piano hands decline despite equal bar counts.
- Closing double bars and trailing instructions remain source material and block continuation into a following rest run.
- Cancellation returns no rest claim.

The existing detector suite also passes 250 checks and 34 real-score fixtures, including scanned Beethoven and Brahms rests, hollow notes, ledger notes, repeat dots, half rests, missing barlines, and prefix-note controls. See the stored logs and results. `source-hashes.json` identifies the implementation and tests used.

Visual inspection compared `auto-Clarinet.png` and `auto-Piano.png` against `source-page-1.pdf`: five printed rest measures, complete respective clefs and C meters, both piano key signatures and brace are present. The saved one-hand-playing images verify that the negative controls actually add a sounding note in the lower/upper hand. These are detector/source-crop checks; the parent integration review separately checks the final app's combined rest rendering and totals.
