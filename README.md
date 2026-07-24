<p align="center">
  <img src="Assets/AppIcon/CodexVault-Transparent-Large.png" width="180" alt="CodexVault app icon">
</p>

# CodexVault

[Deutsch](README.de.md) · [English](README.md)

CodexVault is a local macOS app for creating verified backups of selected work
folders and Codex-related data, then restoring them into new folders without
overwriting existing files. It does not upload data or run silent backups.

## Features

Keep this list current whenever an implemented user-facing feature changes.

- Select multiple project and additional folders for a normal backup.
- Preview file count, size, and excluded sensitive files before creating a
  backup.
- Create portable `.codexvault` packages with a manifest and SHA-256 checks.
- Verify a package before restoring selected sources into a new folder.
- Create a complete local ZIP backup of detected Codex data and configured
  project folders, with progress, verification, a dated copy, and a `latest`
  copy.
- Keep the three newest dated complete backups per source after an explicit
  confirmation; the app never removes older backups silently.
- Inspect local Codex storage by category and project assignment, then
  permanently remove only explicitly selected, unassigned local records after
  confirmation.
- Use four appearances: Liquid Glass, Full Glass, Graphite & Lime, and
  Midnight.
- Keep Dev, Beta, and Final builds separate with distinct bundle identifiers
  and data containers.

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

## Privacy and releases

CodexVault works locally. Normal backups exclude typical secrets and build
artifacts. Complete backups can contain sensitive local Codex data and must be
stored only in a trusted destination.

Dev app bundles are never published. Only a separately authorized Beta or Final
release may be published, and each one must include a completed privacy report
as a separate release attachment. See
[the release privacy-report template](docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md).

## License

CodexVault is licensed under the [GNU GPL v3.0](LICENSE).
