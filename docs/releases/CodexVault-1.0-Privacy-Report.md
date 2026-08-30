# CodexVault 1.0 privacy report

## Release

- Channel: Final
- Version: 1.0
- Date: 30 August 2026
- Verified by: Schrotty74
- Release artifacts and SHA-256:
  - `CodexVault-1.0.dmg`: `cf7412d7091c15ad9d3f52aab6d6761e255cff8af4932ce918df73a480a47252`
  - `CodexVault-1.0.zip`: `0cc5da9d148af5925ad7841f48d8bc8d2a66252d268362146080c2f1fc8d7e12`

## Scope checked

- [x] Only the intended Final DMG and ZIP are attached; no Dev bundle or Dev
      data container is included.
- [x] The DMG contains `CodexVault.app` and an `Applications` link to
      `/Applications`.
- [x] The release source and app bundle were checked for private user paths,
      personal content, API keys, tokens, credentials, certificates, and
      backup data. The only matching local-path text is a test assertion that
      verifies this exclusion.
- [x] Build output, local backup packages, `.env` files, caches, and temporary
      files are not included.
- [x] Public names and product naming are correct.
- [x] The visible backup and restore behavior is unchanged from the verified
      Beta 4 release; no unannounced network transfer or silent backup was
      introduced.

## Result

The Final 1.0 DMG and ZIP passed their package integrity checks. The Final app
is ad-hoc signed, has no embedded local project path or credential marker, and
starts with no persisted Final-channel sources, archives, or backup
destination.
