# Security Policy

## Supported versions

Security fixes are applied on the default branch (`main`) for the latest release line.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

Report privately via GitHub Security Advisories on this repository, or contact the maintainer through GitHub.

Include:

- Affected app version / commit
- Yuvomi server version if relevant
- Steps to reproduce
- Impact assessment

## Scope notes

- This app talks only to the **user-configured** Yuvomi server URL.
- There is no Yuvomi vendor cloud backend in this client.
- Secrets (API tokens, session material) are stored in the iOS Keychain.
- Self-signed certificate trust, if enabled by the user, is scoped to that host.
