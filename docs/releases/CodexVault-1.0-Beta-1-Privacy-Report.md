# CodexVault release privacy report

## Release

- Channel: `Beta` (never `Dev`)
- Version: `1.0 Beta 1` (`1.0.0`, build `1`)
- Date: 27 July 2026
- Verified by: `Schrotty74`
- Release artifact filename and SHA-256:
  `CodexVault-1.0-Beta-1.zip`
  `e43e96fed97177679db285b5b2dedf959e83f0608f1e3d0966d72c4c3a7d3004`

## Scope checked

- [x] Only the intended Beta artifact is attached; no Dev bundle or Dev data
      container is included.
- [x] The source tree and release material were checked for private user paths,
      personal content, API keys, tokens, credentials, certificates, and backup
      data.
- [x] Build output, local backup packages, `.env` files, caches, Finder
      metadata, and temporary files are not included in the release ZIP.
- [x] Public names and product naming are correct.
- [x] The app's visible backup and restore behavior was reviewed for this
      release; no unannounced network transfer or silent backup was introduced.
- [x] The Beta bundle uses identifier `com.codexvault.beta`, version `1.0.0`,
      build `1`, and minimum system version macOS 26.

## Result

`swift test` completed successfully with 7 passing tests. The Beta app bundle
passed `codesign --verify --deep --strict`; its ZIP archive passed `unzip -t`.
The archive contains only `CodexVault Beta.app` and no absolute user paths or
credential markers were found in the app executable or Info.plist.

The app is ad-hoc signed for this first Beta and is not notarized. macOS
Gatekeeper may therefore require the tester to explicitly approve opening it.
No developer certificate, team, account, or signing setting was changed for
this release.
