The frozen native exporter consumes the saved 18-page analysis, reviewed per-system staff groups, and original score PDF. It does not detect staves again or estimate rectifications. Source identification and counts were derived independently twice before comparison. Source headings and eight final crop repairs were assisted choices.

The successful build used the Xcode toolchain explicitly after the default toolchain failed with incompatible Swift SDK modules. `build.log` is the successful compiler output (empty); the preceding failed output is retained separately. A reproducible build command from the repository root is:

```zsh
work=.build/brahms-motets-complete-native-2026-10-03
swift_sources=(${(f)$(rg --files "$work/Core" -g '*.swift')})
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O -module-cache-path .build/ModuleCache "${swift_sources[@]}" "$work/export.swift" -o "$work/exporter"
```

The exact final invocation was:

```zsh
.build/brahms-motets-complete-native-2026-10-03/exporter --inventory .build/brahms-motets-complete-native-2026-10-03/inventory.json --profile .build/brahms-motets-complete-native-2026-10-03/profile.json --overrides .build/brahms-motets-complete-native-2026-10-03/final-overrides.json --title 'Brahms — Two Motets Op. 74' --composer 'Johannes Brahms' --out .build/brahms-motets-complete-native-2026-10-03/final-parts
```

The initial invocation was identical without `--overrides` and wrote `parts` instead of `final-parts`. An earlier initial attempt rejected overlapping source-title selections; its log and original selections are preserved. The successful initial used the combined source-title box. Final overrides replaced that with two adjacent source selections sharing the original top edge and a blank interword seam; no pixels were erased.

`export.swift` is the actual compiled source. `make_worker.py` records derivation from an earlier harness, but the checked final Swift file is authoritative (including the corrected void-return page-break API call). Inputs, source snapshots, result JSON, successful/failure logs and helper scripts are in the evidence archive. The immutable original PDF is hash-bound and embedded once in the delivered editable project. Final PDFs/project are in the delivery folder, rather than duplicated inside this evidence archive.

The native exporter applied the plan, saved/reopened the project through the native codec, checked canonical re-encoding, and exported each part. `verify_final.py` then independently decoded the actual project JSON and compared every one of the 225 saved crop/copy geometries, source references and measure metadata with the final manifest.
