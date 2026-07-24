# CodexVault manual

[Deutsch](MANUAL.de.md) · [English](MANUAL.en.md)

CodexVault is a local macOS backup and restore tool. The current app interface
is English. This manual describes the functionality that is implemented now; it
does not describe planned features as if they already existed.

## Before you begin

- CodexVault requires macOS 26.
- Select sources and destinations explicitly. The app does not begin a normal
  backup automatically.
- Keep complete backups only in a trusted local destination: they can contain
  sensitive local Codex data.
- A normal backup and a complete backup have different exclusion rules. Read
  the relevant section before choosing one.

## Navigation

The sidebar contains five sections:

| Section | Purpose |
| --- | --- |
| Overview | Starting point and current placeholder status cards. |
| Backup | Normal backups, complete ZIP backups, and local Codex storage review. |
| Restore | Validation and selective restoration of a normal backup package. |
| Archive | Backups created during the current app session. |
| Settings | Appearance, privacy status, and build-channel information. |

The **Start setup** button on Overview opens Backup.

## Normal backup

Use a normal backup when you want a portable package for exactly the folders you
choose.

1. Open **Backup**.
2. In **Sources**, click **Add project** for a project folder or **Add folder**
   for any additional folder. You can add more than one source.
3. Wait for the preview. It shows the number of included files and estimated
   size for each source. Use the remove button beside a source to remove it
   from this pending selection.
4. In **Backup destination**, click **Choose destination** and select a writable
   folder. Use **Change** to choose another destination.
5. Review the summary at the bottom. **Create verified backup** becomes
   available only when at least one source and a destination are selected.
6. Click **Create verified backup** and wait for the success message.

### What is created

CodexVault creates a new folder with the `.codexvault` extension inside the
chosen destination. It includes:

- `manifest.json` with the package schema, logical source names, relative file
  paths, exclusion counts, and SHA-256 checksums.
- The selected source folders directly at the package root. There is no
  technical `payload` folder.

The app verifies the package after creation. Existing files in the destination
are not replaced.

### Normal-backup exclusions

The preview and normal backup exclude typical sensitive or generated material,
including `.env` variants, file names containing token, secret, or credential,
common certificate/key formats, Git metadata, build folders, dependency folders,
and common cache folders. A visible warning reports the count of sensitive files
excluded from the preview.

This is name-based protection, not a guarantee that every possible secret is
detected. Review your selected source before sharing a package.

## Complete ZIP backup

Use **CodexVault full backup** when you want a recurring local ZIP copy of
automatically detected Codex app data and your configured project folders.

1. Open **Backup** and find **CodexVault full backup**.
2. Click **Configure project folders** and select every project folder that
   should be included in future complete backups.
3. Click **Change destination** and choose the trusted local folder where the
   ZIP files should be stored.
4. Confirm the displayed project-folder list and destination.
5. Click **Create complete ZIP backup**. The progress bar and message show the
   current phase.

The folder choices and destination are stored locally for the current macOS
user. Codex app data is detected automatically; an existing visible Codex
folder in Documents is also added to the configured project roots when found.
No external backup script must be selected.

### Files, verification, and retention

For every available source, CodexVault creates a dated ZIP and updates a
separate `latest` ZIP copy. It verifies each new ZIP with the system ZIP
validator before reporting success.

After a successful run, CodexVault may offer to remove dated backups beyond the
newest three per source. The dialog lists a destructive option and **Keep all**.
Nothing is deleted until you choose the destructive option.

### Complete-backup exclusions

Complete backups are designed for continuity and therefore are more inclusive
than normal backups. For Codex data, temporary data and IPC files are excluded.
For configured project folders, common build and dependency folders are
excluded. The resulting ZIPs can still contain sensitive work and Codex data;
do not treat them as safe to share publicly.

## Codex storage overview and local-record cleanup

The **Codex storage overview** helps you understand local Codex disk use before
you remove anything.

1. In Backup, click **Check storage**.
2. Review the total local records and size, then the storage categories.
3. Review **Local records grouped by project**. A record can be associated with
   a current project, earlier local work, or have no current project assignment.
4. Use **Collapse** to hide the existing result. In the current app session,
   **Check storage** reopens the same preview; restart the app to create a new
   analysis.

If **Unassigned local records** are shown, select only records you no longer
need. Click **Remove selected local records**, then explicitly choose
**Remove permanently** in the confirmation dialog. This removes only selected
local session-record files that are not currently assigned. It cannot be undone.

The storage overview itself is read-only. It does not remove records unless you
select them and confirm the destructive action.

## Restore a normal backup

Restore works with a verified `.codexvault` package.

1. Open **Restore**.
2. Click **Choose Backup** and select a backup package.
3. Wait for validation. If it fails, the package is not available for restore.
4. Under **Verified contents**, select the logical sources to restore. They are
   selected initially after successful validation.
5. Select a **Restore destination**.
6. Click **Restore selected** and wait for verification to finish.

CodexVault creates a new restore folder below the selected destination and
verifies restored files against the package checksums. It never overwrites
existing destination files. Packages with schema versions 1, 2, and 3 are
accepted when they pass validation.

## Archive

Archive lists normal backup packages created during the current app session and
shows their verification state, file count, and size. It is not a disk browser:
after restarting the app, it does not automatically rediscover earlier packages
from a destination folder.

## Settings

### Appearance

**Preview theme** changes only the current app appearance. It does not change
selected sources, backup contents, security decisions, or an existing package.

| Theme | Appearance |
| --- | --- |
| Liquid Glass | Native glass treatment on the left navigation panel. |
| Full Glass | Native glass treatment across the full window. |
| Graphite & Lime | Dark graphite interface with lime accents. |
| Midnight | Dark blue/indigo interface. |

The selected theme is currently a session setting; it is not documented as a
persisted preference.

### Privacy

The Privacy section displays that network activity is disabled and that the app
does not keep a private content catalog. File permissions are always requested
through explicit folder choices. The locally saved complete-backup setup stores
only the configured folder and destination references needed to run that
feature, not a backup-content catalog.

### Build channel

The section shows the running build channel. Dev, Beta, and Final use separate
bundle identifiers and separate sandbox containers. Data is not migrated between
them.

## Errors and safe next steps

| Message or situation | What to do |
| --- | --- |
| No source or destination selected | Add at least one source and choose a writable destination. |
| Package could not be verified | Do not restore it; choose another package or create a new verified backup. |
| Complete ZIP backup failed | Check that the destination is writable and sources are available, then retry. |
| Older complete backups are offered for removal | Choose **Keep all** unless you have reviewed the retention decision. |
| Unassigned records are listed | Do not delete by size alone; select only records you recognise as no longer needed. |

## Feature documentation rule

When a user-facing feature changes, update the feature lists in both READMEs
and the matching sections of both manuals in the same change.
