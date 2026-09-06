# Security Policy

[Deutsch](SECURITY.de.md)

## Supported Versions

Security reports are accepted for the current CodexVault release.

## Reporting a Vulnerability

Please do not publish sensitive vulnerability details in a public GitHub issue. Contact the repository owner privately. Include the CodexVault and macOS versions, reproduction steps and sanitized logs or screenshots. Never attach real Codex data, ChatGPT exports, project source containing secrets, backup passwords or complete backup archives.

## Scope

Relevant reports include project and Codex-data backup, ZIP creation and extraction, SHA-256 verification, password-protected backup packages, selective restore, destination and path handling, retention/cleanup operations, scheduled backups while CodexVault is open, and handling of ChatGPT export files.

CodexVault works locally and does not upload backup contents. Complete backups can contain sensitive local Codex and project data, so unintended disclosure, overwrite, archive traversal, incomplete exclusion of secrets or integrity-check failures are especially important to report.

Restores are designed to use new destinations rather than silently overwrite existing files.

Thank you for helping keep CodexVault and its users secure.
