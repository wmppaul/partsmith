# Publishing a Mac release

Releases distribute an already reviewed universal Mac archive. GitHub Actions verifies the archive and the app/build source hashes; it does not rebuild or notarize the app.

1. Build and review the app locally. Update `artifacts/macos/Partsmith-extraction-preview-macos.zip` and its release review directory, including `source-hashes.json` and `publication.json`.
2. Add `docs/releases/VERSION.md` with release notes and `VERSION.json` with `reviewDirectory` and the archive's `sha256`. Use a new version such as `v0.1.0-alpha.4`.
3. Update the download links and current documentation. Run `python3 tools/prepare_github_release.py VERSION --output .build/release-check` to verify the recorded app and stage a versioned ZIP plus checksum.
4. Commit the app, review records, notes and documentation; push the commit. Create and push an annotated version tag pointing to it.
5. The **Publish reviewed Mac release** workflow creates a draft, uploads both files, and publishes only after those steps succeed. Tags with a suffix such as `-alpha.4` become prereleases. Confirm the run succeeded, download the published asset and verify its checksum.

The workflow uses the repository's `GITHUB_TOKEN` with release-writing permission; no personal token is needed. A failed draft can be retried using **Run workflow** with the same tag selected. Published assets are not overwritten: use a new version for a correction.

The source check covers every Swift file and the project, scheme and Info.plist. Local Xcode user state and Finder metadata in historical build receipts are not required in a GitHub checkout. Use the release tag/archive name to identify alpha builds while the internal bundle version remains 0.1/build 1.
