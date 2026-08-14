# Changelog

## 1.0 Beta 3 — 14 August 2026

### New and improved

- Save and reuse local backup profiles for selected sources and destinations;
  passwords are never included in a profile.
- Check normal-backup destinations for reachability, write access, and available
  space before a backup can start.
- Name multi-source backups explicitly when needed while retaining the date and
  time in every generated ZIP name.
- Review archived packages with Finder, integrity-check, and direct-restore
  actions; reveal successful backup and restore destinations in Finder.
- Use compact Backup layout, project discovery, an automatic full-backup
  schedule with a preferred time, and expanded local storage information.
- Updated English and German manuals with dark CodexVault styling and six
  privacy-clean UI screenshots; the README now has compact, clickable previews.

### Privacy and packaging

- Public screenshots replace local backup metadata and local paths with neutral
  empty states.
- Release bundles now remove Finder metadata and AppleDouble files before ZIP
  and DMG verification.
- The AI-help prompt now accurately identifies normal backup packages as
  `.codexvault.zip` files.

### Verification

- `swift test`: 15 passing tests.
- Beta DMG and ZIP validated; the DMG contains `CodexVault Beta.app` and an
  `Applications` link only.
