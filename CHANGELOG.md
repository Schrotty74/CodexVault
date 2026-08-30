# Changelog

## 1.0 Final — 30 August 2026

### Backup and restore

- Create verified local ZIP backups from one or more explicitly selected project
  folders. Every package has a relative-path manifest and SHA-256 integrity
  information; existing files are never overwritten during restore.
- Review known backup packages in Archive, reveal them in Finder, check their
  integrity, inspect contents, and restore selected sources into a new folder.
- Save reusable local backup profiles, check a destination for availability,
  write access, and free space, and assign a custom name to multi-source
  backups while retaining the date and time.
- Include a selected ChatGPT export as a normal backup source. Password-protect
  normal packages when wanted; passwords are never saved and packages are
  verified before restore.

### Complete Codex backups

- Create local complete ZIP backups for detected Codex app data, an available
  visible Codex workspace, and explicitly configured project folders.
- Offer project discovery after a visible folder selection, progress feedback,
  an optional daily or weekly schedule while CodexVault is open, and confirmed
  retention of older dated backups.
- Provide a local Codex storage overview with grouped session records and a
  controlled removal flow for selected unassigned records.

### Privacy and guidance

- Keep the app local-first: no automatic network activity, no silent backup,
  and no automatic transfer of app data to AI services.
- Show a privacy-clean first start and permanent AI help. ChatGPT, Google
  Gemini, and Claude open only after confirmation and receive only a static,
  language-appropriate getting-started prompt with the public manual link.
- Provide English and German interface and manual support, official GitHub and
  Discord links, and public screenshots without local paths or backup metadata.

### Appearance and packaging

- Offer Liquid Glass, Full Glass, Graphite & Lime, and Midnight themes,
  including the calm animated Full Glass surface and a compact Backup layout.
- Separate Dev, Beta, and Final app identities and local data. Beta and Final
  builds start from cleared channel-specific local settings; Dev data remains
  separate.
- Build and package with macOS and Xcode tools without a Homebrew requirement.
  Final artifacts are ad-hoc signed and include a ZIP plus a DMG with an
  `Applications` link and a separate privacy report.

### Verification

- `swift test`: 15 passing tests.
- Final app build, ZIP, and DMG passed their build, signature, archive, and
  disk-image integrity checks. The DMG contains only `CodexVault.app` and an
  `Applications` link.
- Final builds start without persisted Final-channel sources, archives, or
  backup destinations. The release source and generated app bundle were
  checked for local project paths and credential markers.

## 1.0 Beta 4 — 26 August 2026

### Build portability

- Build and packaging scripts now use the macOS-provided `/bin/bash` instead
  of a Homebrew-specific Bash path.
- The English and German setup instructions now state that Homebrew is not
  required for app builds or packaging; `reportlab` is only needed when
  regenerating the optional PDF manuals.

### Verification

- `swift test`: 15 passing tests.
- Verified Dev and Beta builds, ZIP, and DMG packaging after the portability
  update. The DMG contains `CodexVault Beta.app` and an `Applications` link.
- A fresh public-repository clone was built and started with an isolated empty
  local configuration; generated bundles were scanned for local paths and
  credential markers.

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
