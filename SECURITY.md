# Security Policy

<p>
  <a href="SECURITY.md">English</a> ·
  <a href="SECURITY.ja.md">日本語</a>
</p>

Prismo reads pull request diffs from the GitHub API with your token and keeps everything on your Mac.
A security bug in this app is therefore a bug in how your code under review and your credentials are
handled. Please report privately so we can fix it before disclosure.

## Supported Versions

| Version | Supported |
|---|---|
| Latest [release](https://github.com/akidon0000/Prismo/releases) | ✅ |
| Anything older | ❌ (please update first) |

Fixes ship in the next release. We do not backport to old versions.

## How to Report a Vulnerability

**Do not open a public issue.** Use GitHub's private reporting instead.

**[→ Report a vulnerability](https://github.com/akidon0000/Prismo/security/advisories/new)**
(also reachable from the repository's **Security** tab)

Include what you know:

- Prismo version and macOS version
- What an attacker gains and what they need to get it
- Reproduction steps (a crafted PR / patch, network conditions, commands you ran)
- Any patch or workaround you already found

This is a small personal project, so expect a first response within about a week rather than hours.
Unless you prefer otherwise, you will be credited in the advisory and release notes.

## What Counts as a Vulnerability Here

Prismo's security boils down to two promises: "code under review and tokens never leave your Mac
except to your configured GitHub host" and "reading a hostile PR is harmless". Anything that breaks
either is in scope.

- **Data exfiltration**: any network call other than the active account's GitHub API (and
  user-initiated `git clone` / `git fetch` to the same host), or review data / tokens leaking into
  such calls, logs, or crash output.
- **Token handling**: tokens stored anywhere other than the Keychain, or exposed to other processes.
- **Code execution**: a crafted PR (patch content, file paths, branch names) causing command
  execution during checkout, IDE jump, or diff parsing.
- **Local state**: Prismo's own state (settings, review notes) being readable or writable by
  something that shouldn't have access.
- **Distribution**: a way to ship modified builds to users (tampering with release artifacts or the
  release workflow).

## Out of Scope

- **Gatekeeper warnings on ad-hoc-signed builds**: local builds without Developer ID secrets fall
  back to ad-hoc signing; the resulting warning is expected behavior, not a vulnerability.
- **Bugs in GitHub's API or `gh` CLI**: report those upstream. If Prismo *calls* them unsafely,
  that part is ours.
- **Attacks that require an already-compromised user account**: Prismo reads what the user can
  already read, so the attacker gains nothing new.
- **Non-security bugs and crashes**: please file a normal
  [bug report](https://github.com/akidon0000/Prismo/issues/new?template=bug-report.md).
