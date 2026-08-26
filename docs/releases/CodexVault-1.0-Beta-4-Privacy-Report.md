# CodexVault 1.0 Beta 4 privacy report

## Release

- Channel: `Beta`
- Version: `1.0 Beta 4` (`1.0.0`)
- Date: 26 August 2026
- Verified by: `Schrotty74`
- Release artifacts and SHA-256:
  - `CodexVault-1.0-Beta-4.dmg`: `517efbc084a7a928194bb57b3e3943ae2f0b1a9c5fa34bdb2991514a2469f595`
  - `CodexVault-1.0-Beta-4.zip`: `c03477c8e0dca45a268dc076855ea55f7314d36797cd263d4491c16bac5f1d18`

## Scope checked

- [x] Only the intended Beta DMG and ZIP are attached; no Dev bundle or Dev
      data container is included.
- [x] The DMG contains `CodexVault Beta.app` and an `Applications` link to
      `/Applications` for drag-and-drop installation.
- [x] The source tree and release material were checked for private user paths,
      personal content, API keys, tokens, credentials, certificates, and backup
      data.
- [x] Build output, local backup packages, `.env` files, caches, and temporary
      files are not included.
- [x] Public names and product naming are correct.
- [x] No user-facing backup or restore code changed in this Beta. The current
      code was tested from a fresh public-repository clone, including an
      isolated empty first start; no unannounced network transfer or silent
      backup was introduced.

## Result

Beta 4 contains the verified DMG and ZIP listed above. It is ad-hoc signed and
not notarized; the documented, app-specific Gatekeeper approval may be needed
on first launch. The release contains no Dev bundle, private path, credential,
backup data, or personal content.
