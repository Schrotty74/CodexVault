# CodexVault release privacy report

## Release

- Channel: `Beta` (never `Dev`)
- Version: `1.0 Beta 2` (`1.0.0`)
- Date: 31 July 2026
- Verified by: `Schrotty74`
- Release artifacts and SHA-256:
  - `CodexVault-1.0-Beta-2.dmg`
    `bd988ab83c38b74d8cc4962b96cf7c2c5f499c4d8c82a8fd188c697c0a6b8ca7`
  - `CodexVault-1.0-Beta-2.zip`
    `513b7e877e939ccd6a1cfc59dd80a15a3b1e2f5b6bf86d35eeae64681a11d28c`

## Scope checked

- [x] Only intended Beta DMG and ZIP are attached; no Dev bundle or data is included.
- [x] The DMG contains only `CodexVault Beta.app` and `Applications` -> `/Applications`.
- [x] The release artifacts contain no local project path or credential marker.
- [x] Build output, backups, `.env` files, caches and temporary files are excluded.
- [x] Product name and public name are correct.
- [x] The release has no network upload or background-launch behavior. Scheduled backups run only while CodexVault is open.

## Result

`swift test` completed with 11 passing tests, including the encrypted backup
round trip. The Beta bundle passed `codesign --verify --deep --strict`; ZIP and
DMG integrity checks passed. The mounted DMG contains the app and Applications
link only. The Beta is ad-hoc signed and not notarized, so Gatekeeper approval
may be required on first launch.
