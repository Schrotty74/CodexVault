<p align="center">
  <img src="Assets/AppIcon/CodexVault-Transparent-Large.png" width="180" alt="CodexVault app icon">
</p>

# CodexVault

[Deutsch](README.de.md) · [English](README.md)

CodexVault is a local macOS app for creating verified backups of selected work
folders and Codex-related data, then restoring them into new folders without
overwriting existing files. It does not upload data or run silent backups.

## Features

- Verified normal backups with source preview, SHA-256 integrity checks, and
  selective restore into a new folder.
- Password-protected normal backup packages; passwords are never stored.
- Complete local ZIP backups for Codex data and selected projects, with progress,
  verification, retention and optional in-app schedule.
- Local project suggestions and ChatGPT-export backup support.
- Persistent Archive and local Codex storage review.
- English and German interface, AI help, and four visual themes: Liquid Glass,
  Full Glass, Graphite & Lime, and Midnight.

## Screenshots

<table>
  <tr>
    <td align="center"><a href="docs/images/overview.png"><img src="docs/images/overview.png" width="360" alt="CodexVault Overview"></a><br><sub>Overview</sub></td>
    <td align="center"><a href="docs/images/backup.png"><img src="docs/images/backup.png" width="360" alt="CodexVault Backup"></a><br><sub>Backup</sub></td>
  </tr>
  <tr>
    <td align="center"><a href="docs/images/restore.png"><img src="docs/images/restore.png" width="360" alt="CodexVault Restore"></a><br><sub>Restore</sub></td>
    <td align="center"><a href="docs/images/archive.png"><img src="docs/images/archive.png" width="360" alt="CodexVault Archive"></a><br><sub>Archive</sub></td>
  </tr>
</table>

Select a preview to open the full-size original.

## Documentation

- [English manual (PDF)](docs/CodexVault-Manual-EN.pdf)
- [Deutsches Handbuch (PDF)](docs/CodexVault-Handbuch-DE.pdf)
- [Project context for new Codex chats](PROJECT_CONTEXT.md)
- [Current development tasks](NEXT_STEPS.md)

## Requirements and local start

CodexVault requires macOS 26. To run the Swift Package locally, use Xcode 26.6
or newer:

```zsh
swift run
```

For local bundles, use the scripts in `Scripts/`:

```zsh
Scripts/build-development.sh
Scripts/build-beta.sh
Scripts/build-final.sh
```

The scripts build locally only. They do not publish an app.

## Gatekeeper notice for Beta and Final builds

CodexVault Beta and Final builds are deliberately ad-hoc signed and not
notarized. macOS may therefore block their first launch. Download the DMG
(recommended) or ZIP only from the official release.
Open the DMG and drag the app onto its included **Applications** link, then use
one of these one-time, app-specific approvals:

1. In Finder, Control-click `CodexVault Beta.app`, choose **Open**, then choose
   **Open** again in the confirmation dialog.
2. If macOS still blocks it, try opening the app once, then open **System
   Settings > Privacy & Security**, scroll to the security message for
   CodexVault, select **Open Anyway**, and confirm with **Open**.

Do not disable Gatekeeper globally. See
[Apple's instructions for safely opening apps](https://support.apple.com/102445).
Each release includes its own privacy report with SHA-256 checksums for both
artifacts.

## Privacy and releases

CodexVault works locally. Normal backups exclude typical secrets and build
artifacts. Complete backups can contain sensitive local Codex data and must be
stored only in a trusted destination.

Dev app bundles are never packaged or published. Each separately authorized
Beta or Final release contains both a DMG (with an **Applications** link) and a
ZIP, plus a completed privacy report with both SHA-256 checksums as a separate
release attachment. See
[the release privacy-report template](docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md).

## License

CodexVault is licensed under the [GNU GPL v3.0](LICENSE).
