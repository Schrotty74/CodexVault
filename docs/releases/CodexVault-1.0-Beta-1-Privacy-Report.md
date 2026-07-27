# CodexVault release privacy report

## Release

- Channel: `Beta` (never `Dev`)
- Version: `1.0 Beta 1` (`1.0.0`, build `1`)
- Date: 27 July 2026
- Verified by: `Schrotty74`
- Release artifacts and SHA-256:
  - `CodexVault-1.0-Beta-1.dmg`
    `e8be2efb35f6056007c1dfe0744ee31ad8c3ed8c6a253a4363c29ddbf033f5e5`
  - `CodexVault-1.0-Beta-1.zip`
    `925a1a6027038ad5864499ce15c37280c48017b55b7e38ee00b95b179f7761a6`

## Scope checked

- [x] Only the intended Beta artifacts are attached; no Dev bundle or Dev data
      container is included.
- [x] The source tree and release material were checked for private user paths,
      personal content, API keys, tokens, credentials, certificates, and backup
      data.
- [x] Build output, local backup packages, `.env` files, caches, Finder
      metadata, and temporary files are not included in the release ZIP.
- [x] The DMG contains only `CodexVault Beta.app` and an `Applications` link
      to `/Applications`.
- [x] Public names and product naming are correct.
- [x] The app's visible backup and restore behavior was reviewed for this
      release; no unannounced network transfer or silent backup was introduced.
- [x] The Beta bundle uses identifier `com.codexvault.beta`, version `1.0.0`,
      build `1`, and minimum system version macOS 26.

## Result

`swift test` completed successfully with 7 passing tests. The Beta app bundle
passed `codesign --verify --deep --strict`; the ZIP archive passed `unzip -t`
and the DMG passed `hdiutil verify`. The mounted DMG contains only
`CodexVault Beta.app` and an `Applications` link to `/Applications`. No
absolute user paths or credential markers were found in the app executable or
Info.plist.

The app is ad-hoc signed for this first Beta and is not notarized. macOS
Gatekeeper may therefore require the tester to explicitly approve opening it.
No developer certificate, team, account, or signing setting was changed for
this release.
