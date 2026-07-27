# CodexVault release privacy report

Use this template for every Beta or Final GitHub release. Create a new, versioned
copy for the actual release and attach that completed Markdown file to the
GitHub release together with both corresponding Beta or Final app artifacts.

## Release

- Channel: `Beta` or `Final` (never `Dev`)
- Version:
- Date:
- Verified by: `Schrotty74`
- Release artifacts and SHA-256:
  - DMG filename and SHA-256:
  - ZIP filename and SHA-256:

## Scope checked

- [ ] Only the intended Beta or Final DMG and ZIP are attached; no Dev bundle
      or Dev data container is included.
- [ ] The DMG contains the intended app and an `Applications` link to
      `/Applications`, so the app can be dragged there in Finder.
- [ ] The source tree and release material were checked for private user paths,
      personal content, API keys, tokens, credentials, certificates, and backup
      data.
- [ ] Build output, local backup packages, `.env` files, caches, and temporary
      files are not included.
- [ ] Public names and product naming are correct.
- [ ] The app's visible backup and restore behavior was reviewed for this
      release; no unannounced network transfer or silent backup was introduced.

## Result

State the concrete result of the checks above. Record only release-relevant
facts. Do not place private paths, keys, user data, or backup contents in this
report.
