<h1 align="center">Prismo</h1>

<p align="center">
  <strong>See the shape of a PR before you read it.</strong>
</p>

<p align="center">
  A macOS app for reviewing pull requests in call order — not file-name order.<br/>
  Assigned reviews surface first. Open a PR and walk the call graph;<br/>
  checkout the branch and jump into Xcode or Android Studio when you need to.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1B1B1F?style=flat-square&logo=apple"/>
  <a href="https://github.com/akidon0000/Prismo/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/akidon0000/Prismo/actions/workflows/ci.yml/badge.svg"/></a>
</p>

<p align="center">
  <a href="README.md"><strong>English</strong></a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

## Features

- **Assigned first** — Open the app and see PRs waiting for *your* review, with everything else still reachable.
- **Call-graph file columns** — Changed symbols are ordered by how they call each other (callers before callees), then grouped into file columns. Not alphabetical.
- **Checkout + IDE jump** — Bring down the PR branch and open the right tool (Xcode / Android Studio) when a glance isn't enough.
- **Swift · Kotlin · Dart** — Mobile-stack languages first.

Inspired by [rinkaku](https://github.com/hiro-o918/rinkaku)'s “see the shape before you read” idea, built as a native macOS window app in the spirit of [Tokfuel](https://github.com/Tokfuel/Tokfuel).

## Status

Working slice:

- **Inbox** via GitHub search (`review-requested` / `assignee` / `involves`), falling back to demo data when unauthenticated
- **Token** from Keychain, or `gh auth token` when empty
- **Call-graph columns** from PR file patches (import + symbol-name reference heuristics for Swift · Kotlin · Dart)
- **Checkout** of `refs/pull/N/head` + open Xcode / Android Studio (reuses `~/ghq/...` when present)
- **In-app diff pane** — select a symbol to see its patch hunk
- **Code jump** — open `file:line` in Xcode / Android Studio / VS Code after checkout
- **Review notes** — attach notes to symbols, copy Markdown, or post a batched GitHub COMMENT review (persisted locally); shows existing GitHub line comments
- **Blast radius** — 1-hop callers / callees for the selected symbol
- **Keyboard** — ⌘R refresh, ⌘J/⌘K next/prev symbol, ⌘⇧J jump, ⌘⇧N note
- **Inbox filter** — search + Swift/Kotlin/Dart language picker

Still ahead: tree-sitter-grade symbol graphs.

## Install (from source)

```bash
git clone git@github.com:akidon0000/Prismo.git
cd Prismo
bash scripts/setup.sh          # git hooks
swift assets/make-icon.swift   # optional AppIcon.icns
bash scripts/build.sh          # release → /Applications/Prismo.app
# or:
bash scripts/build.sh --debug
```

Requirements: macOS 14+, Xcode with Swift 6 toolchain.

## Development

```bash
swift test
swift build -c release
```

Sources live under [`Prismo/Sources/`](Prismo/Sources/). See [`AGENTS.md`](AGENTS.md) for working agreements.

## License

MIT © akidon0000
