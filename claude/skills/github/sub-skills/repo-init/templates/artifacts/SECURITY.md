# Security Policy

## Reporting a Vulnerability

Report security issues privately through
[GitHub Security Advisories](../../security/advisories/new) rather than opening a public
issue.

Please include reproduction steps, affected versions, and impact. Expect an initial response
within a few days.

## Supported Versions

The latest released version is supported. Older tags do not receive backported fixes.

## Secrets

This repository runs secret scanning with push protection enabled, and a local
`pre-commit` gitleaks hook. If you believe a secret was committed at any point in history,
treat it as compromised and **rotate it** — removing it from history does not un-leak it.
