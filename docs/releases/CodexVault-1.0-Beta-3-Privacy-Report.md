# CodexVault release privacy report

## Release

- Channel: `Beta` (never `Dev`)
- Version: `1.0 Beta 3` (`1.0.0`)
- Date: 14 August 2026
- Verified by: `Schrotty74`
- Release artifacts and SHA-256:
  - `CodexVault-1.0-Beta-3.dmg`
    `92a167932549b8df68594b5ce287fc04aba263f05d33c3a85376bb99362f1878`
  - `CodexVault-1.0-Beta-3.zip`
    `372b790d7fa96b35f9e9255cb60b5fa76967a2876ff070dc9cccf1156194d0da`

## Scope checked

- [x] Only the intended Beta DMG and ZIP are attached; no Dev bundle or data
      container is included.
- [x] The DMG contains only `CodexVault Beta.app` and `Applications` ->
      `/Applications`.
- [x] The source tree, public documentation, screenshots, and release material
      were checked for private user paths, personal backup metadata, API keys,
      tokens, credentials, certificates, and backup data.
- [x] Public screenshots use privacy-clean empty states where the original view
      contained local path or backup metadata.
- [x] Build output, local backup packages, `.env` files, caches, temporary
      files, Finder metadata, and AppleDouble files are not included.
- [x] Product name and public name are correct.
- [x] The app has no automatic network activity or silent backup behavior;
      scheduled full backups run only while CodexVault is open.

## Result

`swift test` completed with 15 passing tests, including encrypted backup round
trip, ChatGPT-export backup, project discovery, storage destination health,
profiles, archive history, and full-backup scheduling. The Beta bundle passed
`codesign --verify --deep --strict`; ZIP and DMG integrity checks passed. The
mounted DMG contains the app and `Applications` link only. The release ZIP was
checked for Finder metadata and AppleDouble files. The Beta is ad-hoc signed and
not notarized, so Gatekeeper approval may be required on first launch.
