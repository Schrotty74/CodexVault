# CodexVault source publication privacy report

## Scope

- Publication: initial public source-code upload
- Date: 24 July 2026
- Verified by: `Schrotty74`
- Included material: Swift source, tests, build scripts, packaging resources,
  app-icon source assets, and project documentation
- Not a Beta or Final app release; no app bundle is attached

## Checks completed

- [x] Reviewed the publishable file list after `.gitignore` rules were applied.
- [x] Excluded build output, Swift build state, Finder metadata, portable backup
      packages, ZIP files, and restore output.
- [x] Scanned text sources and documentation for absolute user paths, API keys,
      tokens, credentials, certificates, and private-key markers.
- [x] Removed a machine-specific backup destination and machine-specific project
      folder preference from the source before publication.
- [x] Confirmed the repository contains no local backup contents or test data
      from a user account.
- [x] Confirmed no Dev app bundle is included or published.

## Result

The checked source publication contains application code and reusable project
resources only. It contains no known private user content, secrets, backup
packages, build output, or absolute user paths.

## Screenshot update – 24 July 2026

- Added four public README screenshots for Overview, Backup, Restore, and
  Archive.
- Replaced the machine-specific full-backup destination visible in the Backup
  screenshot with the generic text `Not configured` before adding it.
- Checked all four committed PNG files for absolute user paths and CleanShot or
  C2PA provenance metadata; none are included.
- The README previews link only to the repository's own full-size PNG files.
